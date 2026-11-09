// Ported from vscode src/vs/editor/standalone/browser/standaloneServices.ts
// (StandaloneConfigurationService, updateConfigurationService) and
// src/vs/editor/common/config/editorConfigurationSchema.ts (isEditorConfigurationKey)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.standalone;

import cityscape.base.common.Event;
import cityscape.common.config.EditorOptions;
import cityscape.platform.configuration.common.Configuration;

/**
 * Monaco's `StandaloneConfigurationService`: the settings of a `Cityscape`
 * context, in memory. The editors write their options there
 * (`updateConfigurationService`), and the model service reads the `editor`
 * section to create the models and update their options.
 *
 * Monaco's configuration also holds the defaults of every registered
 * setting (`editor.tabSize` is 4 when nothing set it); here `getValue`
 * returns only the values set, and the readers apply the same defaults when
 * a value is missing (`ModelService._readModelOptions`), which gives the
 * same options. No resource or language overrides (the standalone editor
 * sets none).
 */
class StandaloneConfigurationService implements IConfigurationService {

    final _values:Map<String, Any> = new Map();
    final _keys:Array<String> = [];

    final _onDidChangeConfiguration = new Emitter<ConfigurationChangeEvent>();
    public var onDidChangeConfiguration(get, never):Event<ConfigurationChangeEvent>;
    function get_onDidChangeConfiguration():Event<ConfigurationChangeEvent> {
        return _onDidChangeConfiguration.event;
    }

    public function new() {}

    public function getValue(section:String):Any {
        if (_values.exists(section)) {
            return _values.get(section);
        }
        final prefix = section + '.';
        var result:Null<Dynamic> = null;
        for (key in _keys) {
            if (!StringTools.startsWith(key, prefix)) {
                continue;
            }
            if (result == null) {
                result = {};
            }
            // `editor.semanticHighlighting.enabled` under `editor`:
            // {semanticHighlighting: {enabled: value}}
            final parts = key.substr(prefix.length).split('.');
            var target:Dynamic = result;
            for (i in 0...parts.length - 1) {
                var next:Dynamic = Reflect.field(target, parts[i]);
                if (next == null || !Reflect.isObject(next) || Std.isOfType(next, std.String)) {
                    next = {};
                    Reflect.setField(target, parts[i], next);
                }
                target = next;
            }
            Reflect.setField(target, parts[parts.length - 1], _values.get(key));
        }
        return result;
    }

    public function updateValues(values:Array<ConfigurationValue>):Void {
        final changedKeys:Array<String> = [];
        for (entry in values) {
            final key = entry.key;
            final value = entry.value;
            if (_values.exists(key) && (_values.get(key) : Dynamic) == (value : Dynamic)) {
                continue;
            }
            if (!_values.exists(key)) {
                _keys.push(key);
            }
            _values.set(key, value);
            changedKeys.push(key);
        }
        if (changedKeys.length > 0) {
            _onDidChangeConfiguration.fire(new ConfigurationChangeEvent(changedKeys));
        }
    }

    public function dispose():Void {
        _onDidChangeConfiguration.dispose();
    }

}

/**
 * `updateConfigurationService` and `isEditorConfigurationKey`.
 */
class StandaloneConfiguration {

    /**
     * The settings of editorConfigurationSchema.ts that are not editor
     * options (`editor.tabSize`, `editor.insertSpaces`...).
     */
    static final SCHEMA_KEYS = [
        'tabSize',
        'indentSize',
        'insertSpaces',
        'detectIndentation',
        'trimAutoWhitespace',
        'largeFileOptimizations',
        'wordBasedSuggestions',
        'stablePeek',
        'maxTokenizationLineLength',
        // Semantic tokens (step 7, cs7-rest-sem): Monaco's global editor
        // option `'semanticHighlighting.enabled'` (`true`, `false` or
        // `'configuredByTheme'`), and its object form
        // `semanticHighlighting: {enabled: ...}` (a Haxe structure cannot
        // have a dotted field)
        'semanticHighlighting.enabled',
        'semanticHighlighting'
    ];

    /**
     * Editor options whose schema has several settings
     * (`editor.bracketPairColorization.enabled`...): their own name is not
     * a configuration key in Monaco, so `updateConfigurationService` does
     * not write them. Only the ones a reader of the configuration uses are
     * listed.
     */
    static final NESTED_SCHEMA_OPTIONS = ['bracketPairColorization'];

    static var _keys:Null<Map<String, Bool>> = null;

    /**
     * Whether `editor.<key>` is a setting (Monaco's
     * `isEditorConfigurationKey`).
     */
    public static function isEditorConfigurationKey(key:String):Bool {
        var keys = _keys;
        if (keys == null) {
            keys = new Map();
            for (option in EditorOptions.editorOptionsRegistry) {
                if (option != null && NESTED_SCHEMA_OPTIONS.indexOf(option.name) == -1) {
                    keys.set(option.name, true);
                }
            }
            for (name in SCHEMA_KEYS) {
                keys.set(name, true);
            }
            _keys = keys;
        }
        return keys.exists(key);
    }

    /**
     * Writes the editor options of `source` to the configuration as
     * `editor.<name>` (Monaco's `updateConfigurationService`, called when a
     * standalone editor is created and by its `updateOptions`): the models
     * created afterwards take their tab size, indentation and other model
     * options from there, and the existing ones are updated.
     */
    public static function updateConfigurationService(configurationService:Null<IConfigurationService>, source:Any, isDiffEditor:Bool):Void {
        if (source == null || configurationService == null) {
            return;
        }
        final toUpdate:Array<ConfigurationValue> = [];
        for (key in Reflect.fields(source)) {
            if (isEditorConfigurationKey(key)) {
                final value:Any = Reflect.field(source, key);
                if (value == null) {
                    // Haxe's null is JavaScript's undefined here (an option
                    // left out)
                    continue;
                }
                toUpdate.push({key: 'editor.' + key, value: value});
            }
        }
        if (toUpdate.length > 0) {
            configurationService.updateValues(toUpdate);
        }
    }

}

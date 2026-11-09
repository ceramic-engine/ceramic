// Ported from vscode src/vs/editor/browser/config/migrateOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.config;

import cityscape.base.common.JsValues;

typedef ISettingsReader = (key:String) -> Any;

typedef ISettingsWriter = (key:String, value:Any) -> Void;

class EditorSettingMigration {

    public static var items(get, never):Array<EditorSettingMigration>;
    static var _items:Null<Array<EditorSettingMigration>> = null;
    static function get_items():Array<EditorSettingMigration> {
        if (_items == null) {
            _items = [];
            MigrateOptions.registerMigrations();
        }
        return _items;
    }

    public final key:String;

    public final migrate:(value:Any, read:ISettingsReader, write:ISettingsWriter) -> Void;

    public function new(key:String, migrate:(value:Any, read:ISettingsReader, write:ISettingsWriter) -> Void) {
        this.key = key;
        this.migrate = migrate;
    }

    public function apply(options:Any):Void {
        final value = EditorSettingMigration._read(options, this.key);
        final read = (key:String) -> EditorSettingMigration._read(options, key);
        final write = (key:String, value:Any) -> EditorSettingMigration._write(options, key, value);
        this.migrate(value, read, write);
    }

    static function _read(source:Any, key:String):Any {
        if (JsValues.isUndefined(source)) {
            return null;
        }

        final firstDotIndex = key.indexOf('.');
        if (firstDotIndex >= 0) {
            final firstSegment = key.substring(0, firstDotIndex);
            return _read(JsValues.field(source, firstSegment), key.substring(firstDotIndex + 1));
        }
        return JsValues.field(source, key);
    }

    static function _write(target:Any, key:String, value:Any):Void {
        final firstDotIndex = key.indexOf('.');
        if (firstDotIndex >= 0) {
            final firstSegment = key.substring(0, firstDotIndex);
            var segment = Reflect.field(target, firstSegment);
            if (!JsValues.truthy(segment)) {
                segment = {};
                Reflect.setField(target, firstSegment, segment);
            }
            _write(segment, key.substring(firstDotIndex + 1), value);
            return;
        }
        Reflect.setField(target, key, value);
    }

    @:allow(cityscape.view.config.MigrateOptions)
    static function add(migration:EditorSettingMigration):Void {
        _items.push(migration);
    }

}

/**
 * Compatibility with the option values of older Monaco versions (booleans
 * that became strings...). The migrations are registered on first use. An
 * option written `undefined` by Monaco is set to null here (Haxe has no
 * `undefined`); validation treats both the same.
 */
class MigrateOptions {

    /**
     * Compatibility with old options
     */
    public static function migrateOptions(options:Any):Void {
        for (migration in EditorSettingMigration.items) {
            migration.apply(options);
        }
    }

    static function registerEditorSettingMigration(key:String, migrate:(value:Any, read:ISettingsReader, write:ISettingsWriter) -> Void):Void {
        EditorSettingMigration.add(new EditorSettingMigration(key, migrate));
    }

    static function registerSimpleEditorSettingMigration(key:String, values:Array<Array<Any>>):Void {
        registerEditorSettingMigration(key, (value, read, write) -> {
            if (!JsValues.isUndefined(value)) {
                for (pair in values) {
                    final oldValue = pair[0];
                    final newValue = pair[1];
                    if (strictEquals(value, oldValue)) {
                        write(key, newValue);
                        return;
                    }
                }
            }
        });
    }

    static function strictEquals(a:Any, b:Any):Bool {
        if (JsValues.isBoolean(a) && JsValues.isBoolean(b)) {
            return (a : Bool) == (b : Bool);
        }
        if (JsValues.isString(a) && JsValues.isString(b)) {
            return (a : String) == (b : String);
        }
        return false;
    }

    static final suggestFilteredTypesMapping:Array<Array<String>> = [
        ['method', 'showMethods'],
        ['function', 'showFunctions'],
        ['constructor', 'showConstructors'],
        ['deprecated', 'showDeprecated'],
        ['field', 'showFields'],
        ['variable', 'showVariables'],
        ['class', 'showClasses'],
        ['struct', 'showStructs'],
        ['interface', 'showInterfaces'],
        ['module', 'showModules'],
        ['property', 'showProperties'],
        ['event', 'showEvents'],
        ['operator', 'showOperators'],
        ['unit', 'showUnits'],
        ['value', 'showValues'],
        ['constant', 'showConstants'],
        ['enum', 'showEnums'],
        ['enumMember', 'showEnumMembers'],
        ['keyword', 'showKeywords'],
        ['text', 'showWords'],
        ['color', 'showColors'],
        ['file', 'showFiles'],
        ['reference', 'showReferences'],
        ['folder', 'showFolders'],
        ['typeParameter', 'showTypeParameters'],
        ['snippet', 'showSnippets'],
    ];

    /**
     * Registers the migrations, in Monaco's order.
     */
    @:allow(cityscape.view.config.EditorSettingMigration)
    static function registerMigrations():Void {
        registerSimpleEditorSettingMigration('wordWrap', [[true, 'on'], [false, 'off']]);
        registerSimpleEditorSettingMigration('lineNumbers', [[true, 'on'], [false, 'off']]);
        registerSimpleEditorSettingMigration('cursorBlinking', [['visible', 'solid']]);
        registerSimpleEditorSettingMigration('renderWhitespace', [[true, 'boundary'], [false, 'none']]);
        registerSimpleEditorSettingMigration('renderLineHighlight', [[true, 'line'], [false, 'none']]);
        registerSimpleEditorSettingMigration('acceptSuggestionOnEnter', [[true, 'on'], [false, 'off']]);
        registerSimpleEditorSettingMigration('tabCompletion', [[false, 'off'], [true, 'onlySnippets']]);
        registerSimpleEditorSettingMigration('hover', [[true, {enabled: true}], [false, {enabled: false}]]);
        registerSimpleEditorSettingMigration('parameterHints', [[true, {enabled: true}], [false, {enabled: false}]]);
        registerSimpleEditorSettingMigration('autoIndent', [[false, 'advanced'], [true, 'full']]);
        registerSimpleEditorSettingMigration('matchBrackets', [[true, 'always'], [false, 'never']]);
        registerSimpleEditorSettingMigration('renderFinalNewline', [[true, 'on'], [false, 'off']]);
        registerSimpleEditorSettingMigration('cursorSmoothCaretAnimation', [[true, 'on'], [false, 'off']]);
        registerSimpleEditorSettingMigration('occurrencesHighlight', [[true, 'singleFile'], [false, 'off']]);
        registerSimpleEditorSettingMigration('wordBasedSuggestions', [[true, 'matchingDocuments'], [false, 'off']]);

        registerEditorSettingMigration('autoClosingBrackets', (value, read, write) -> {
            if (JsValues.isBoolean(value) && (value : Bool) == false) {
                write('autoClosingBrackets', 'never');
                if (JsValues.isUndefined(read('autoClosingQuotes'))) {
                    write('autoClosingQuotes', 'never');
                }
                if (JsValues.isUndefined(read('autoSurround'))) {
                    write('autoSurround', 'never');
                }
            }
        });

        registerEditorSettingMigration('renderIndentGuides', (value, read, write) -> {
            if (!JsValues.isUndefined(value)) {
                write('renderIndentGuides', null);
                if (JsValues.isUndefined(read('guides.indentation'))) {
                    write('guides.indentation', JsValues.truthy(value));
                }
            }
        });

        registerEditorSettingMigration('highlightActiveIndentGuide', (value, read, write) -> {
            if (!JsValues.isUndefined(value)) {
                write('highlightActiveIndentGuide', null);
                if (JsValues.isUndefined(read('guides.highlightActiveIndentation'))) {
                    write('guides.highlightActiveIndentation', JsValues.truthy(value));
                }
            }
        });

        registerEditorSettingMigration('suggest.filteredTypes', (value, read, write) -> {
            if (JsValues.truthy(value) && JsValues.isObject(value)) {
                for (entry in suggestFilteredTypesMapping) {
                    final v = JsValues.field(value, entry[0]);
                    if (JsValues.isBoolean(v) && (v : Bool) == false) {
                        if (JsValues.isUndefined(read('suggest.' + entry[1]))) {
                            write('suggest.' + entry[1], false);
                        }
                    }
                }
                write('suggest.filteredTypes', null);
            }
        });

        registerEditorSettingMigration('quickSuggestions', (input, read, write) -> {
            if (JsValues.isBoolean(input)) {
                final value = (input : Bool) ? 'on' : 'off';
                final newValue = {comments: value, strings: value, other: value};
                write('quickSuggestions', newValue);
            }
        });

        // Sticky Scroll
        registerEditorSettingMigration('experimental.stickyScroll.enabled', (value, read, write) -> {
            if (JsValues.isBoolean(value)) {
                write('experimental.stickyScroll.enabled', null);
                if (JsValues.isUndefined(read('stickyScroll.enabled'))) {
                    write('stickyScroll.enabled', value);
                }
            }
        });

        registerEditorSettingMigration('experimental.stickyScroll.maxLineCount', (value, read, write) -> {
            if (JsValues.isNumber(value)) {
                write('experimental.stickyScroll.maxLineCount', null);
                if (JsValues.isUndefined(read('stickyScroll.maxLineCount'))) {
                    write('stickyScroll.maxLineCount', value);
                }
            }
        });

        // Code Actions on Save
        registerEditorSettingMigration('codeActionsOnSave', (value, read, write) -> {
            if (JsValues.truthy(value) && JsValues.isObject(value)) {
                var toBeModified = false;
                final newValue = {};
                for (key in Reflect.fields(value)) {
                    final entryValue = Reflect.field(value, key);
                    if (JsValues.isBoolean(entryValue)) {
                        toBeModified = true;
                        Reflect.setField(newValue, key, (entryValue : Bool) ? 'explicit' : 'never');
                    }
                    else {
                        Reflect.setField(newValue, key, entryValue);
                    }
                }
                if (toBeModified) {
                    write('codeActionsOnSave', newValue);
                }
            }
        });

        // Migrate Quick Fix Settings
        registerEditorSettingMigration('codeActionWidget.includeNearbyQuickfixes', (value, read, write) -> {
            if (JsValues.isBoolean(value)) {
                write('codeActionWidget.includeNearbyQuickfixes', null);
                if (JsValues.isUndefined(read('codeActionWidget.includeNearbyQuickFixes'))) {
                    write('codeActionWidget.includeNearbyQuickFixes', value);
                }
            }
        });

        // Migrate the lightbulb settings
        registerEditorSettingMigration('lightbulb.enabled', (value, read, write) -> {
            if (JsValues.isBoolean(value)) {
                write('lightbulb.enabled', (value : Bool) ? null : 'off');
            }
        });
    }

}

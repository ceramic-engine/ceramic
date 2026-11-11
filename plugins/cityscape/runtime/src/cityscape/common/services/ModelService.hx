// Ported from vscode src/vs/editor/common/services/modelService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Platform;
import cityscape.base.common.Uri;
import cityscape.common.Model.ITextBufferFactory;
import cityscape.common.Model.ITextModel;
import cityscape.common.languages.Language.ILanguageSelection;
import cityscape.common.model.TextModel;
import haxe.extern.EitherType;
import cityscape.common.Model.BracketPairColorizationOptions;
import cityscape.common.Model.DefaultEndOfLine;
import cityscape.common.Model.ITextModelCreationOptions;
import cityscape.common.Model.IndentSize;
import cityscape.common.core.TextModelDefaults;
import cityscape.common.Model.EndOfLineSequence;
import cityscape.platform.configuration.common.Configuration;

/**
 * The model options of the settings (`editor.tabSize`, `editor.insertSpaces`...),
 * as Monaco reads them: untyped values validated like JavaScript would.
 */
typedef IRawEditorConfig = {
    @:optional var tabSize:Any;
    @:optional var indentSize:Any;
    @:optional var insertSpaces:Any;
    @:optional var detectIndentation:Any;
    @:optional var trimAutoWhitespace:Any;
    @:optional var creationOptions:Any;
    @:optional var largeFileOptimizations:Any;
    @:optional var bracketPairColorization:Any;
}

typedef IRawConfig = {
    @:optional var eol:Any;
    @:optional var editor:IRawEditorConfig;
}

/**
 * The models of a `Cityscape` context by uri (Monaco's model service):
 * `createModel`, `getModel`, `getModels`, `destroyModel`, and the events of
 * models added and removed. A model leaves the service when it is disposed.
 *
 * The creation options of a model come from the `editor` settings of the
 * configuration of the context (`Cityscape.configurationService`), where the
 * editors write their options (`tabSize`, `insertSpaces`,
 * `detectIndentation`...) like Monaco's standalone editor; a change of these
 * settings updates the options of the models (`_updateModelOptions`).
 *
 * The undo/redo snapshots of disposed models are not ported.
 */
class ModelService {

    final _context:Null<Cityscape>;
    final _models:Map<String, {model:TextModel, listener:IDisposable}> = new Map();
    final _order:Array<String> = [];

    final _onModelAdded = new Emitter<ITextModel>();
    public final onModelAdded:Event<ITextModel>;

    final _onModelRemoved = new Emitter<ITextModel>();
    public final onModelRemoved:Event<ITextModel>;

    final _configurationService:Null<IConfigurationService>;
    var _configurationListener:Null<IDisposable> = null;
    var _modelCreationOptionsByLanguageAndResource:Map<String, ITextModelCreationOptions> = new Map();

    public function new(?context:Cityscape, ?configurationService:IConfigurationService) {
        this._context = context;
        onModelAdded = _onModelAdded.event;
        onModelRemoved = _onModelRemoved.event;
        this._configurationService = configurationService;
        if (configurationService != null) {
            _configurationListener = configurationService.onDidChangeConfiguration(e -> this._updateModelOptions(e));
        }
        this._updateModelOptions(null);
    }

    function _getEOL(resource:Null<Uri>, language:String):String {
        // Monaco's StandaloneResourcePropertiesService: `files.eol`, else
        // the platform's
        final eol:Any = _configurationService != null ? _configurationService.getValue('files.eol') : null;
        if (eol != null && JsValues.isString(eol) && (eol : String) != '' && (eol : String) != 'auto') {
            return eol;
        }
        return (Platform.isLinux || Platform.isMacintosh) ? '\n' : '\r\n';
    }

    /**
     * The creation options of a model of this language and uri, from the
     * configuration (cached until the configuration changes).
     */
    public function getCreationOptions(languageIdOrSelection:EitherType<String, ILanguageSelection>, resource:Null<Uri>, isForSimpleWidget:Bool):ITextModelCreationOptions {
        final language = JsValues.isString(languageIdOrSelection) ? (languageIdOrSelection : String) : (languageIdOrSelection : ILanguageSelection).languageId;
        final cacheKey = language + (resource != null ? resource.toString() : 'undefined');
        var creationOptions = _modelCreationOptionsByLanguageAndResource.get(cacheKey);
        if (creationOptions == null) {
            final editor:Null<IRawEditorConfig> = _configurationService != null ? _configurationService.getValue('editor') : null;
            final eol = this._getEOL(resource, language);
            creationOptions = ModelService._readModelOptions({editor: editor, eol: eol}, isForSimpleWidget);
            _modelCreationOptionsByLanguageAndResource.set(cacheKey, creationOptions);
        }
        return creationOptions;
    }

    function _updateModelOptions(e:Null<ConfigurationChangeEvent>):Void {
        final oldOptionsByLanguageAndResource = _modelCreationOptionsByLanguageAndResource;
        _modelCreationOptionsByLanguageAndResource = new Map();

        // Update options on all models
        for (key in _order) {
            final modelData = _models.get(key);
            final model = modelData.model;
            final language = model.getLanguageId();
            final uri = model.uri;

            if (e != null && !e.affectsConfiguration('editor') && !e.affectsConfiguration('files.eol')) {
                continue; // perf: skip if this model is not affected by configuration change
            }

            final oldOptions = oldOptionsByLanguageAndResource.get(language + uri.toString());
            final newOptions = this.getCreationOptions(language, uri, model.isForSimpleWidget);
            ModelService._setModelOptionsForModel(model, newOptions, oldOptions);
        }
    }

    static function _setModelOptionsForModel(model:TextModel, newOptions:ITextModelCreationOptions, currentOptions:Null<ITextModelCreationOptions>):Void {
        if (currentOptions != null && currentOptions.defaultEOL != newOptions.defaultEOL && model.getLineCount() == 1) {
            model.setEOL(newOptions.defaultEOL == DefaultEndOfLine.LF ? EndOfLineSequence.LF : EndOfLineSequence.CRLF);
        }

        if (currentOptions != null
            && (currentOptions.detectIndentation == newOptions.detectIndentation)
            && (currentOptions.insertSpaces == newOptions.insertSpaces)
            && (currentOptions.tabSize == newOptions.tabSize)
            && (currentOptions.indentSize == newOptions.indentSize)
            && (currentOptions.trimAutoWhitespace == newOptions.trimAutoWhitespace)
            && sameBracketPairColorizationOptions(currentOptions.bracketPairColorizationOptions, newOptions.bracketPairColorizationOptions)
        ) {
            // Same indent opts, no need to touch the model
            return;
        }

        // Cityscape: the bracket pair colorization of the configuration is
        // given only when it changed. An editor also gives its own option to
        // its model (`CodeEditorWidget._applyBracketPairColorization`, where
        // Monaco reads the configuration only): another model option of the
        // configuration changing (the tab size of an editor) does not undo it.
        // In Monaco the configuration is the only source, so this is its
        // behaviour.
        final bracketColorizationOptions = currentOptions != null && sameBracketPairColorizationOptions(currentOptions.bracketPairColorizationOptions, newOptions.bracketPairColorizationOptions)
            ? null
            : newOptions.bracketPairColorizationOptions;
        if (newOptions.detectIndentation) {
            model.detectIndentation(newOptions.insertSpaces, newOptions.tabSize);
            model.updateOptions({
                trimAutoWhitespace: newOptions.trimAutoWhitespace,
                bracketColorizationOptions: bracketColorizationOptions
            });
        }
        else {
            model.updateOptions({
                insertSpaces: newOptions.insertSpaces,
                tabSize: newOptions.tabSize,
                indentSize: newOptions.indentSize,
                trimAutoWhitespace: newOptions.trimAutoWhitespace,
                bracketColorizationOptions: bracketColorizationOptions
            });
        }
    }

    static function sameBracketPairColorizationOptions(a:BracketPairColorizationOptions, b:BracketPairColorizationOptions):Bool {
        // Monaco's `equals` (objects.ts): deep equality
        if (a == b) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        return a.enabled == b.enabled && a.independentColorPoolPerBracketType == b.independentColorPoolPerBracketType;
    }

    /**
     * Creates a model. `languageIdOrSelection` is a language id or an
     * `ILanguageSelection` (plain text when null); `resource` its uri
     * (`inmemory://model/N` when null). Throws when a model with this uri
     * exists.
     */
    public function createModel(value:EitherType<String, ITextBufferFactory>, languageIdOrSelection:Null<EitherType<String, ILanguageSelection>>, ?resource:Uri, isForSimpleWidget:Bool = false):TextModel {
        if (resource != null && _models.exists(resource.toString())) {
            throw 'ModelService: Cannot add model because it already exists!';
        }
        final languageId:EitherType<String, ILanguageSelection> = languageIdOrSelection != null ? languageIdOrSelection : 'plaintext';
        final options = this.getCreationOptions(languageId, resource, isForSimpleWidget);
        final model = new TextModel(value, languageId, options, resource, _context);
        final key = model.uri.toString();
        if (_models.exists(key)) {
            model.dispose();
            throw 'ModelService: Cannot add model because it already exists!';
        }
        final listener = model.onWillDispose(() -> this._onWillDispose(model));
        _models.set(key, {model: model, listener: listener});
        _order.push(key);
        _onModelAdded.fire(model);
        return model;
    }

    function _onWillDispose(model:TextModel):Void {
        final key = model.uri.toString();
        final data = _models.get(key);
        if (data == null || data.model != model) {
            return;
        }
        data.listener.dispose();
        _models.remove(key);
        _order.remove(key);
        _onModelRemoved.fire(model);
    }

    /**
     * Disposes the model of `resource` (it leaves the service).
     */
    public function destroyModel(resource:Uri):Void {
        final data = _models.get(resource.toString());
        if (data != null) {
            data.model.dispose();
        }
    }

    public function getModel(resource:Uri):Null<ITextModel> {
        final data = _models.get(resource.toString());
        return data != null ? data.model : null;
    }

    /**
     * The models, in creation order.
     */
    public function getModels():Array<ITextModel> {
        return [for (key in _order) _models.get(key).model];
    }

    public function dispose():Void {
        for (key in _order.copy()) {
            final data = _models.get(key);
            if (data != null) {
                data.listener.dispose();
            }
        }
        _models.clear();
        _order.resize(0);
        if (_configurationListener != null) {
            _configurationListener.dispose();
            _configurationListener = null;
        }
        _onModelAdded.dispose();
        _onModelRemoved.dispose();
    }

    static var DEFAULT_EOL(get, never):DefaultEndOfLine;
    static function get_DEFAULT_EOL():DefaultEndOfLine {
        return (Platform.isLinux || Platform.isMacintosh) ? DefaultEndOfLine.LF : DefaultEndOfLine.CRLF;
    }

    static function readBoolean(value:Any):Bool {
        return (JsValues.isString(value) && (value : String) == 'false') ? false : JsValues.truthy(value);
    }

    public static function _readModelOptions(config:IRawConfig, isForSimpleWidget:Bool):ITextModelCreationOptions {
        final defaults = TextModelDefaults.EDITOR_MODEL_DEFAULTS;
        final editor = config.editor;

        var tabSize = defaults.tabSize;
        if (editor != null && !JsValues.isUndefined(editor.tabSize)) {
            final parsedTabSize = JsValues.parseInt(editor.tabSize);
            if (!Math.isNaN(parsedTabSize)) {
                tabSize = Std.int(parsedTabSize);
            }
            if (tabSize < 1) {
                tabSize = 1;
            }
        }

        var indentSize:IndentSize = 'tabSize';
        if (editor != null && !JsValues.isUndefined(editor.indentSize) && !(JsValues.isString(editor.indentSize) && (editor.indentSize : String) == 'tabSize')) {
            final parsedIndentSize = JsValues.parseInt(editor.indentSize);
            if (!Math.isNaN(parsedIndentSize)) {
                indentSize = Std.int(Math.max(parsedIndentSize, 1));
            }
        }

        var insertSpaces = defaults.insertSpaces;
        if (editor != null && !JsValues.isUndefined(editor.insertSpaces)) {
            insertSpaces = readBoolean(editor.insertSpaces);
        }

        var newDefaultEOL = DEFAULT_EOL;
        final eol = config.eol;
        if (JsValues.isString(eol) && (eol : String) == '\r\n') {
            newDefaultEOL = DefaultEndOfLine.CRLF;
        }
        else if (JsValues.isString(eol) && (eol : String) == '\n') {
            newDefaultEOL = DefaultEndOfLine.LF;
        }

        var trimAutoWhitespace = defaults.trimAutoWhitespace;
        if (editor != null && !JsValues.isUndefined(editor.trimAutoWhitespace)) {
            trimAutoWhitespace = readBoolean(editor.trimAutoWhitespace);
        }

        var detectIndentation = defaults.detectIndentation;
        if (editor != null && !JsValues.isUndefined(editor.detectIndentation)) {
            detectIndentation = readBoolean(editor.detectIndentation);
        }

        var largeFileOptimizations = defaults.largeFileOptimizations;
        if (editor != null && !JsValues.isUndefined(editor.largeFileOptimizations)) {
            largeFileOptimizations = readBoolean(editor.largeFileOptimizations);
        }
        var bracketPairColorizationOptions:BracketPairColorizationOptions = defaults.bracketPairColorizationOptions;
        if (editor != null && JsValues.truthy(editor.bracketPairColorization) && JsValues.isObject(editor.bracketPairColorization)) {
            bracketPairColorizationOptions = {
                enabled: JsValues.truthy(JsValues.field(editor.bracketPairColorization, 'enabled')),
                independentColorPoolPerBracketType: JsValues.truthy(JsValues.field(editor.bracketPairColorization, 'independentColorPoolPerBracketType'))
            };
        }

        return {
            isForSimpleWidget: isForSimpleWidget,
            tabSize: tabSize,
            indentSize: indentSize,
            insertSpaces: insertSpaces,
            detectIndentation: detectIndentation,
            defaultEOL: newDefaultEOL,
            trimAutoWhitespace: trimAutoWhitespace,
            largeFileOptimizations: largeFileOptimizations,
            bracketPairColorizationOptions: bracketPairColorizationOptions
        };
    }

}

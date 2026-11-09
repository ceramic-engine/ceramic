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
 * The undo/redo snapshots of disposed models and the configuration service
 * (the creation options come from the defaults, Monaco's
 * `_readModelOptions` of an empty configuration) are not ported.
 */
class ModelService {

    final _context:Null<Cityscape>;
    final _models:Map<String, {model:TextModel, listener:IDisposable}> = new Map();
    final _order:Array<String> = [];

    final _onModelAdded = new Emitter<ITextModel>();
    public final onModelAdded:Event<ITextModel>;

    final _onModelRemoved = new Emitter<ITextModel>();
    public final onModelRemoved:Event<ITextModel>;

    public function new(?context:Cityscape) {
        this._context = context;
        onModelAdded = _onModelAdded.event;
        onModelRemoved = _onModelRemoved.event;
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
        final options = ModelService._readModelOptions({}, isForSimpleWidget);
        final model = new TextModel(value, languageIdOrSelection != null ? languageIdOrSelection : 'plaintext', options, resource, _context);
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

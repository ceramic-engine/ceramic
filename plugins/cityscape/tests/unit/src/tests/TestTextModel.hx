// Ported from vscode src/vs/editor/test/common/testTextModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Uri;
import cityscape.common.Model;
import cityscape.common.model.TextModel;
import haxe.extern.EitherType;

typedef IRelaxedTextModelCreationOptions = {
    @:optional var tabSize:Int;
    @:optional var indentSize:IndentSize;
    @:optional var insertSpaces:Bool;
    @:optional var detectIndentation:Bool;
    @:optional var trimAutoWhitespace:Bool;
    @:optional var defaultEOL:DefaultEndOfLine;
    @:optional var isForSimpleWidget:Bool;
    @:optional var largeFileOptimizations:Bool;
    @:optional var bracketColorizationOptions:BracketPairColorizationOptions;
}

/**
 * vscode's test models, without dependency injection: each model gets a new
 * `Cityscape` context (its own undo/redo service, like the services vscode
 * creates for each test model).
 *
 * The language id defaults to `'plaintext'` (`PLAINTEXT_LANGUAGE_ID`).
 */
class TestTextModel extends TextModel {

    public function registerDisposable(disposable:IDisposable):Void {
        this._register(disposable);
    }

    public static function withEditorModel(text:Array<String>, callback:(model:TextModel) -> Void):Void {
        final model = createTextModel(text.join('\n'));
        callback(model);
        model.dispose();
    }

    static function resolveOptions(_options:IRelaxedTextModelCreationOptions):ITextModelCreationOptions {
        final defaultOptions = TextModel.DEFAULT_CREATION_OPTIONS;
        return {
            tabSize: (_options.tabSize == null ? defaultOptions.tabSize : _options.tabSize),
            indentSize: (_options.indentSize == null ? defaultOptions.indentSize : _options.indentSize),
            insertSpaces: (_options.insertSpaces == null ? defaultOptions.insertSpaces : _options.insertSpaces),
            detectIndentation: (_options.detectIndentation == null ? defaultOptions.detectIndentation : _options.detectIndentation),
            trimAutoWhitespace: (_options.trimAutoWhitespace == null ? defaultOptions.trimAutoWhitespace : _options.trimAutoWhitespace),
            defaultEOL: (_options.defaultEOL == null ? defaultOptions.defaultEOL : _options.defaultEOL),
            isForSimpleWidget: (_options.isForSimpleWidget == null ? defaultOptions.isForSimpleWidget : _options.isForSimpleWidget),
            largeFileOptimizations: (_options.largeFileOptimizations == null ? defaultOptions.largeFileOptimizations : _options.largeFileOptimizations),
            bracketPairColorizationOptions: (_options.bracketColorizationOptions == null ? defaultOptions.bracketPairColorizationOptions : _options.bracketColorizationOptions),
        };
    }

    /**
     * `text` is a string or an `ITextBufferFactory`.
     */
    public static function createTextModel(text:EitherType<String, ITextBufferFactory>, ?languageId:String, ?options:IRelaxedTextModelCreationOptions, ?uri:Uri):TextModel {
        return instantiateTextModel(new Cityscape(), text, languageId, options, uri);
    }

    public static function instantiateTextModel(context:Cityscape, text:EitherType<String, ITextBufferFactory>, ?languageId:String, ?_options:IRelaxedTextModelCreationOptions, ?uri:Uri):TestTextModel {
        final options = resolveOptions(_options != null ? _options : cast TextModel.DEFAULT_CREATION_OPTIONS);
        return new TestTextModel(text, languageId != null ? languageId : 'plaintext', options, uri, context);
    }

}

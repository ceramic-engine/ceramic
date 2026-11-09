// Ported from vscode src/vs/editor/common/languages/autoIndent.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.common.Model.ITextModel;
import cityscape.common.tokens.LineTokens.IViewLineTokens;

/**
 * The tokenization part of an `IVirtualModel`.
 *
 * Monaco's `forceTokenization` is optional: here it is required, and an
 * implementation without it does nothing.
 */
interface IVirtualModelTokenization {
    function getLineTokens(lineNumber:Int):IViewLineTokens;
    function getLanguageId():String;
    function getLanguageIdAtPosition(lineNumber:Int, column:Int):String;
    function forceTokenization(lineNumber:Int):Void;
}

/**
 * A model as auto indentation sees it (Monaco's structural type, which an
 * `ITextModel` satisfies; `TextModelVirtualModel` adapts an `ITextModel`).
 */
interface IVirtualModel {
    var tokenization(get, never):IVirtualModelTokenization;
    function getLineContent(lineNumber:Int):String;
}

/**
 * An `ITextModel` seen as an `IVirtualModel` (Monaco passes the text model
 * itself, structurally typed).
 */
class TextModelVirtualModel implements IVirtualModel implements IVirtualModelTokenization {

    final model:ITextModel;

    public function new(model:ITextModel) {
        this.model = model;
    }

    public var tokenization(get, never):IVirtualModelTokenization;
    inline function get_tokenization():IVirtualModelTokenization {
        return this;
    }

    public function getLineContent(lineNumber:Int):String {
        return model.getLineContent(lineNumber);
    }

    public function getLineTokens(lineNumber:Int):IViewLineTokens {
        return model.tokenization.getLineTokens(lineNumber);
    }

    public function getLanguageId():String {
        return model.tokenization.getLanguageId();
    }

    public function getLanguageIdAtPosition(lineNumber:Int, column:Int):String {
        return model.tokenization.getLanguageIdAtPosition(lineNumber, column);
    }

    public function forceTokenization(lineNumber:Int):Void {
        model.tokenization.forceTokenization(lineNumber);
    }

}

/**
 * Module functions of autoIndent.ts.
 *
 * TODO(step 3): `getGoodIndentForLine`, `getIndentForEnter`,
 * `getIndentActionForType`, `getIndentMetadata`, `getInheritIndentForLine`
 * and the rest of autoIndent.ts come with the cursor and the commands.
 */
class AutoIndent {}

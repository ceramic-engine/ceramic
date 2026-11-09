// Ported from vscode src/vs/editor/common/tokenizationTextModelPart.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.core.Position.IPosition;
import cityscape.common.core.Range;
import cityscape.common.tokens.LineTokens;
import cityscape.common.tokens.SparseMultilineTokens;

/**
 * Provides tokenization related functionality of the text model.
 */
interface ITokenizationTextModelPart {

    var hasTokens(get, never):Bool;

    /**
     * Replaces all semantic tokens with the provided `tokens`.
     * @internal
     */
    function setSemanticTokens(tokens:Null<Array<SparseMultilineTokens>>, isComplete:Bool):Void;

    /**
     * Merges the provided semantic tokens into existing semantic tokens.
     * @internal
     */
    function setPartialSemanticTokens(range:Range, tokens:Array<SparseMultilineTokens>):Void;

    /**
     * @internal
     */
    function hasCompleteSemanticTokens():Bool;

    /**
     * @internal
     */
    function hasSomeSemanticTokens():Bool;

    /**
     * Flush all tokenization state.
     * @internal
     */
    function resetTokenization():Void;

    /**
     * Force tokenization information for `lineNumber` to be accurate.
     * @internal
     */
    function forceTokenization(lineNumber:Int):Void;

    /**
     * If it is cheap, force tokenization information for `lineNumber` to be accurate.
     * This is based on a heuristic.
     * @internal
     */
    function tokenizeIfCheap(lineNumber:Int):Void;

    /**
     * Check if tokenization information is accurate for `lineNumber`.
     * @internal
     */
    function hasAccurateTokensForLine(lineNumber:Int):Bool;

    /**
     * Check if calling `forceTokenization` for this `lineNumber` will be cheap (time-wise).
     * This is based on a heuristic.
     * @internal
     */
    function isCheapToTokenize(lineNumber:Int):Bool;

    /**
     * Get the tokens for the line `lineNumber`.
     * The tokens might be inaccurate. Use `forceTokenization` to ensure accurate tokens.
     * @internal
     */
    function getLineTokens(lineNumber:Int):LineTokens;

    /**
     * Returns the standard token type for a character if the character were to be inserted at
     * the given position. If the result cannot be accurate, it returns null.
     * @internal
     */
    function getTokenTypeIfInsertingCharacter(lineNumber:Int, column:Int, character:String):StandardTokenType;

    /**
     * @internal
     */
    function tokenizeLineWithEdit(position:IPosition, length:Int, newText:String):Null<LineTokens>;

    function getLanguageId():String;

    function getLanguageIdAtPosition(lineNumber:Int, column:Int):String;

    function setLanguageId(languageId:String, ?source:String):Void;

    var backgroundTokenizationState(get, never):BackgroundTokenizationState;

}

enum abstract BackgroundTokenizationState(Int) from Int to Int {
    var InProgress = 1;
    var Completed = 2;
}

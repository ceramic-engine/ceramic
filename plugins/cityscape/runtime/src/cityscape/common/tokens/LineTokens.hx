// Ported from vscode src/vs/editor/common/tokens/lineTokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.tokens;

import cityscape.common.EncodedTokenAttributes.ColorId;
import cityscape.common.EncodedTokenAttributes.ITokenPresentation;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Languages.ILanguageIdCodec;

/**
 * The tokens of a line, as the view sees them.
 *
 * TODO(step 1): `LineTokens` (the implementation) is ported with the
 * tokenization.
 */
interface IViewLineTokens {
    var languageIdCodec(get, never):ILanguageIdCodec;
    function equals(other:IViewLineTokens):Bool;
    function getCount():Int;
    function getStandardTokenType(tokenIndex:Int):StandardTokenType;
    function getForeground(tokenIndex:Int):ColorId;
    function getEndOffset(tokenIndex:Int):Int;
    function getClassName(tokenIndex:Int):String;
    function getInlineStyle(tokenIndex:Int, colorMap:Array<String>):String;
    function getPresentation(tokenIndex:Int):ITokenPresentation;
    function findTokenIndexAtOffset(offset:Int):Int;
    function getLineContent():String;
    function getMetadata(tokenIndex:Int):Int;
    function getLanguageId(tokenIndex:Int):String;
    function getTokenText(tokenIndex:Int):String;
    function forEach(callback:(tokenIndex:Int) -> Void):Void;
}

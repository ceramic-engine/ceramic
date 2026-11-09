// Ported from vscode src/vs/editor/test/common/core/testLineToken.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package testing;

import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.tokens.LineTokens.IViewLineTokens;

/**
 * A token on a line.
 */
class TestLineToken {

    /**
     * last char index of this token (not inclusive).
     */
    public final endIndex:Int;
    final _metadata:Int;

    public function new(endIndex:Int, metadata:Int) {
        this.endIndex = endIndex;
        this._metadata = metadata;
    }

    public function getStandardTokenType():StandardTokenType {
        return TokenMetadata.getTokenType(this._metadata);
    }

    public function getForeground():ColorId {
        return TokenMetadata.getForeground(this._metadata);
    }

    public function getType():String {
        return TokenMetadata.getClassNameFromMetadata(this._metadata);
    }

    public function getInlineStyle(colorMap:Array<String>):String {
        return TokenMetadata.getInlineStyleFromMetadata(this._metadata, colorMap);
    }

    public function getPresentation():ITokenPresentation {
        return TokenMetadata.getPresentationFromMetadata(this._metadata);
    }

    static function _equals(a:TestLineToken, b:TestLineToken):Bool {
        return (
            a.endIndex == b.endIndex
            && a._metadata == b._metadata
        );
    }

    public static function equalsArr(a:Array<TestLineToken>, b:Array<TestLineToken>):Bool {
        final aLen = a.length;
        final bLen = b.length;
        if (aLen != bLen) {
            return false;
        }
        for (i in 0...aLen) {
            if (!_equals(a[i], b[i])) {
                return false;
            }
        }
        return true;
    }

}

class TestLineTokens implements IViewLineTokens {

    final _actual:Array<TestLineToken>;

    public function new(actual:Array<TestLineToken>) {
        this._actual = actual;
    }

    public function equals(other:IViewLineTokens):Bool {
        if (Std.isOfType(other, TestLineTokens)) {
            return TestLineToken.equalsArr(this._actual, (cast other : TestLineTokens)._actual);
        }
        return false;
    }

    public function getCount():Int {
        return this._actual.length;
    }

    public function getStandardTokenType(tokenIndex:Int):StandardTokenType {
        return this._actual[tokenIndex].getStandardTokenType();
    }

    public function getForeground(tokenIndex:Int):ColorId {
        return this._actual[tokenIndex].getForeground();
    }

    public function getEndOffset(tokenIndex:Int):Int {
        return this._actual[tokenIndex].endIndex;
    }

    public function getClassName(tokenIndex:Int):String {
        return this._actual[tokenIndex].getType();
    }

    public function getInlineStyle(tokenIndex:Int, colorMap:Array<String>):String {
        return this._actual[tokenIndex].getInlineStyle(colorMap);
    }

    public function getPresentation(tokenIndex:Int):ITokenPresentation {
        return this._actual[tokenIndex].getPresentation();
    }

    public function findTokenIndexAtOffset(offset:Int):Int {
        throw 'Not implemented';
    }

    public function getLineContent():String {
        throw 'Not implemented';
    }

    public function getMetadata(tokenIndex:Int):Int {
        throw 'Method not implemented.';
    }

    public function getLanguageId(tokenIndex:Int):String {
        throw 'Method not implemented.';
    }

    public function getTokenText(tokenIndex:Int):String {
        throw 'Method not implemented.';
    }

    public function forEach(callback:(tokenIndex:Int) -> Void):Void {
        throw 'Not implemented';
    }

    public var languageIdCodec(get, never):ILanguageIdCodec;
    function get_languageIdCodec():ILanguageIdCodec {
        throw 'Not implemented';
    }

}

// Ported from vscode src/vs/editor/common/languages/supports.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.tokens.LineTokens;

/**
 * Module functions of supports.ts.
 */
class Supports {

    public static function createScopedLineTokens(context:LineTokens, offset:Int):ScopedLineTokens {
        final tokenCount = context.getCount();
        final tokenIndex = context.findTokenIndexAtOffset(offset);
        final desiredLanguageId = context.getLanguageId(tokenIndex);

        var lastTokenIndex = tokenIndex;
        while (lastTokenIndex + 1 < tokenCount && context.getLanguageId(lastTokenIndex + 1) == desiredLanguageId) {
            lastTokenIndex++;
        }

        var firstTokenIndex = tokenIndex;
        while (firstTokenIndex > 0 && context.getLanguageId(firstTokenIndex - 1) == desiredLanguageId) {
            firstTokenIndex--;
        }

        return new ScopedLineTokens(
            context,
            desiredLanguageId,
            firstTokenIndex,
            lastTokenIndex + 1,
            context.getStartOffset(firstTokenIndex),
            context.getEndOffset(lastTokenIndex)
        );
    }

    /**
     * `IgnoreBracketsInTokens.value` of supports.ts.
     */
    static inline final IgnoreBracketsInTokens_value:Int = StandardTokenType.Comment | StandardTokenType.String | StandardTokenType.RegEx;

    public static inline function ignoreBracketsInToken(standardTokenType:StandardTokenType):Bool {
        return (standardTokenType & IgnoreBracketsInTokens_value) != 0;
    }

}

class ScopedLineTokens {

    public final languageIdCodec:ILanguageIdCodec;
    public final languageId:String;
    final _actual:LineTokens;
    final _firstTokenIndex:Int;
    final _lastTokenIndex:Int;
    public final firstCharOffset:Int;
    final _lastCharOffset:Int;

    public function new(
        actual:LineTokens,
        languageId:String,
        firstTokenIndex:Int,
        lastTokenIndex:Int,
        firstCharOffset:Int,
        lastCharOffset:Int
    ) {
        _actual = actual;
        this.languageId = languageId;
        _firstTokenIndex = firstTokenIndex;
        _lastTokenIndex = lastTokenIndex;
        this.firstCharOffset = firstCharOffset;
        _lastCharOffset = lastCharOffset;
        this.languageIdCodec = actual.languageIdCodec;
    }

    public function getLineContent():String {
        final actualLineContent = _actual.getLineContent();
        return actualLineContent.substring(firstCharOffset, _lastCharOffset);
    }

    public function getLineLength():Int {
        return _lastCharOffset - firstCharOffset;
    }

    public function getActualLineContentBefore(offset:Int):String {
        final actualLineContent = _actual.getLineContent();
        return actualLineContent.substring(0, firstCharOffset + offset);
    }

    public function getTokenCount():Int {
        return _lastTokenIndex - _firstTokenIndex;
    }

    public function findTokenIndexAtOffset(offset:Int):Int {
        return _actual.findTokenIndexAtOffset(offset + firstCharOffset) - _firstTokenIndex;
    }

    public function getStandardTokenType(tokenIndex:Int):StandardTokenType {
        return _actual.getStandardTokenType(tokenIndex + _firstTokenIndex);
    }

    public function toIViewLineTokens():IViewLineTokens {
        return _actual.sliceAndInflate(firstCharOffset, _lastCharOffset, 0);
    }

}

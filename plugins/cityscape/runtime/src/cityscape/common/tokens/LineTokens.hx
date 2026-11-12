// Ported from vscode src/vs/editor/common/tokens/lineTokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.tokens;

import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position.IPosition;
import haxe.io.UInt32Array;

/**
 * The tokens of a line, as the view sees them.
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

/**
 * The text of a line with its tokens: `_tokens[2 * i]` is the end offset of
 * token i (UTF-16 units), `_tokens[2 * i + 1]` its metadata
 * (`EncodedTokenAttributes`).
 */
class LineTokens implements IViewLineTokens {

    final _tokens:UInt32Array;

    final _tokensCount:Int;

    final _text:String;

    final _languageIdCodec:ILanguageIdCodec;

    public var languageIdCodec(get, never):ILanguageIdCodec;
    inline function get_languageIdCodec():ILanguageIdCodec {
        return _languageIdCodec;
    }

    public static final defaultTokenMetadata:Int = (
        (FontStyle.None << MetadataConsts.FONT_STYLE_OFFSET)
        | (ColorId.DefaultForeground << MetadataConsts.FOREGROUND_OFFSET)
        | (ColorId.DefaultBackground << MetadataConsts.BACKGROUND_OFFSET)
    );

    public static function createEmpty(lineContent:String, decoder:ILanguageIdCodec):LineTokens {
        final defaultMetadata = LineTokens.defaultTokenMetadata;

        final tokens = new UInt32Array(2);
        tokens[0] = lineContent.length;
        tokens[1] = defaultMetadata;

        return new LineTokens(tokens, lineContent, decoder);
    }

    public static function createFromTextAndMetadata(data:Array<{text:String, metadata:Int}>, decoder:ILanguageIdCodec):LineTokens {
        var offset = 0;
        var fullText = '';
        final tokens = new Array<Int>();
        for (d in data) {
            tokens.push(offset + d.text.length);
            tokens.push(d.metadata);
            offset += d.text.length;
            fullText += d.text;
        }
        return new LineTokens(UInt32Arrays.fromInts(tokens), fullText, decoder);
    }

    public function new(tokens:UInt32Array, text:String, decoder:ILanguageIdCodec) {
        _tokens = tokens;
        _tokensCount = (tokens.length >>> 1);
        _text = text;
        _languageIdCodec = decoder;
    }

    public function equals(other:IViewLineTokens):Bool {
        if (Std.isOfType(other, LineTokens)) {
            return slicedEquals(cast other, 0, _tokensCount);
        }
        return false;
    }

    public function slicedEquals(other:LineTokens, sliceFromTokenIndex:Int, sliceTokenCount:Int):Bool {
        if (_text != other._text) {
            return false;
        }
        if (_tokensCount != other._tokensCount) {
            return false;
        }
        final from = (sliceFromTokenIndex << 1);
        final to = from + (sliceTokenCount << 1);
        for (i in from...to) {
            if (_tokens[i] != other._tokens[i]) {
                return false;
            }
        }
        return true;
    }

    public function getLineContent():String {
        return _text;
    }

    public function getCount():Int {
        return _tokensCount;
    }

    public function getStartOffset(tokenIndex:Int):Int {
        if (tokenIndex > 0) {
            return _tokens[(tokenIndex - 1) << 1];
        }
        return 0;
    }

    /**
     * The metadata of a token, 0 past the last one. JavaScript reads
     * `undefined` past the end of the Uint32Array, which the bit operations
     * on the metadata read as 0 (`IndentationLineProcessor.getProcessedTokens`
     * asks for the language of token 0 of an empty slice); a typed array
     * read out of bounds throws on C# and is undefined on hxcpp.
     */
    inline function metadataAt(tokenIndex:Int):Int {
        final index = (tokenIndex << 1) + 1;
        return (index >= 0 && index < _tokens.length) ? _tokens[index] : 0;
    }

    public function getMetadata(tokenIndex:Int):Int {
        final metadata:Int = metadataAt(tokenIndex);
        return metadata;
    }

    public function getLanguageId(tokenIndex:Int):String {
        final metadata:Int = metadataAt(tokenIndex);
        final languageId = TokenMetadata.getLanguageId(metadata);
        return _languageIdCodec.decodeLanguageId(languageId);
    }

    public function getStandardTokenType(tokenIndex:Int):StandardTokenType {
        final metadata:Int = metadataAt(tokenIndex);
        return TokenMetadata.getTokenType(metadata);
    }

    public function getForeground(tokenIndex:Int):ColorId {
        final metadata:Int = metadataAt(tokenIndex);
        return TokenMetadata.getForeground(metadata);
    }

    public function getClassName(tokenIndex:Int):String {
        final metadata:Int = metadataAt(tokenIndex);
        return TokenMetadata.getClassNameFromMetadata(metadata);
    }

    public function getInlineStyle(tokenIndex:Int, colorMap:Array<String>):String {
        final metadata:Int = metadataAt(tokenIndex);
        return TokenMetadata.getInlineStyleFromMetadata(metadata, colorMap);
    }

    public function getPresentation(tokenIndex:Int):ITokenPresentation {
        final metadata:Int = metadataAt(tokenIndex);
        return TokenMetadata.getPresentationFromMetadata(metadata);
    }

    public function getEndOffset(tokenIndex:Int):Int {
        return _tokens[tokenIndex << 1];
    }

    /**
     * Find the token containing offset `offset`.
     * @param offset The search offset
     * @return The index of the token containing the offset.
     */
    public function findTokenIndexAtOffset(offset:Int):Int {
        return LineTokens.findIndexInTokensArray(_tokens, offset);
    }

    public function inflate():IViewLineTokens {
        return this;
    }

    public function sliceAndInflate(startOffset:Int, endOffset:Int, deltaOffset:Int):IViewLineTokens {
        return new SliceLineTokens(this, startOffset, endOffset, deltaOffset);
    }

    public static function convertToEndOffset(tokens:UInt32Array, lineTextLength:Int):Void {
        final tokenCount = (tokens.length >>> 1);
        final lastTokenIndex = tokenCount - 1;
        if (lastTokenIndex < 0) {
            // Monaco writes `tokens[-2]` here, a no-op on a JavaScript typed
            // array but out of bounds on native targets.
            return;
        }
        for (tokenIndex in 0...lastTokenIndex) {
            tokens[tokenIndex << 1] = tokens[(tokenIndex + 1) << 1];
        }
        tokens[lastTokenIndex << 1] = lineTextLength;
    }

    public static function findIndexInTokensArray(tokens:UInt32Array, desiredIndex:Int):Int {
        if (tokens.length <= 2) {
            return 0;
        }

        var low = 0;
        var high = (tokens.length >>> 1) - 1;

        while (low < high) {

            final mid = low + ((high - low) >> 1);
            final endOffset:Int = tokens[(mid << 1)];

            if (endOffset == desiredIndex) {
                return mid + 1;
            }
            else if (endOffset < desiredIndex) {
                low = mid + 1;
            }
            else if (endOffset > desiredIndex) {
                high = mid;
            }
        }

        return low;
    }

    /**
     * @pure
     * @param insertTokens Must be sorted by offset.
     */
    public function withInserted(insertTokens:Array<{offset:Int, text:String, tokenMetadata:Int}>):LineTokens {
        if (insertTokens.length == 0) {
            return this;
        }

        var nextOriginalTokenIdx = 0;
        var nextInsertTokenIdx = 0;
        var text = '';
        final newTokens = new Array<Int>();

        var originalEndOffset = 0;
        while (true) {
            final nextOriginalTokenEndOffset:Int = nextOriginalTokenIdx < _tokensCount ? _tokens[nextOriginalTokenIdx << 1] : -1;
            final nextInsertToken = nextInsertTokenIdx < insertTokens.length ? insertTokens[nextInsertTokenIdx] : null;

            if (nextOriginalTokenEndOffset != -1 && (nextInsertToken == null || nextOriginalTokenEndOffset <= nextInsertToken.offset)) {
                // original token ends before next insert token
                text += _text.substring(originalEndOffset, nextOriginalTokenEndOffset);
                final metadata:Int = _tokens[(nextOriginalTokenIdx << 1) + 1];
                newTokens.push(text.length);
                newTokens.push(metadata);
                nextOriginalTokenIdx++;
                originalEndOffset = nextOriginalTokenEndOffset;

            }
            else if (nextInsertToken != null) {
                if (nextInsertToken.offset > originalEndOffset) {
                    // insert token is in the middle of the next token.
                    text += _text.substring(originalEndOffset, nextInsertToken.offset);
                    final metadata:Int = _tokens[(nextOriginalTokenIdx << 1) + 1];
                    newTokens.push(text.length);
                    newTokens.push(metadata);
                    originalEndOffset = nextInsertToken.offset;
                }

                text += nextInsertToken.text;
                newTokens.push(text.length);
                newTokens.push(nextInsertToken.tokenMetadata);
                nextInsertTokenIdx++;
            }
            else {
                break;
            }
        }

        return new LineTokens(UInt32Arrays.fromInts(newTokens), text, _languageIdCodec);
    }

    public function getTokenText(tokenIndex:Int):String {
        final startOffset = getStartOffset(tokenIndex);
        final endOffset = getEndOffset(tokenIndex);
        final text = _text.substring(startOffset, endOffset);
        return text;
    }

    public function forEach(callback:(tokenIndex:Int) -> Void):Void {
        final tokenCount = getCount();
        for (tokenIndex in 0...tokenCount) {
            callback(tokenIndex);
        }
    }

    /**
     * `getStandardTokenTypeAtPosition` of lineTokens.ts; -1 for Monaco's `undefined`.
     */
    public static function getStandardTokenTypeAtPosition(model:ITextModel, position:IPosition):Int {
        final lineNumber = position.lineNumber;
        if (!model.tokenization.isCheapToTokenize(lineNumber)) {
            return -1;
        }
        model.tokenization.forceTokenization(lineNumber);
        final lineTokens = model.tokenization.getLineTokens(lineNumber);
        final tokenIndex = lineTokens.findTokenIndexAtOffset(position.column - 1);
        final tokenType = lineTokens.getStandardTokenType(tokenIndex);
        return tokenType;
    }

}

class SliceLineTokens implements IViewLineTokens {

    final _source:LineTokens;
    final _startOffset:Int;
    final _endOffset:Int;
    final _deltaOffset:Int;

    final _firstTokenIndex:Int;
    final _tokensCount:Int;

    public var languageIdCodec(get, never):ILanguageIdCodec;
    inline function get_languageIdCodec():ILanguageIdCodec {
        return _source.languageIdCodec;
    }

    public function new(source:LineTokens, startOffset:Int, endOffset:Int, deltaOffset:Int) {
        _source = source;
        _startOffset = startOffset;
        _endOffset = endOffset;
        _deltaOffset = deltaOffset;
        _firstTokenIndex = source.findTokenIndexAtOffset(startOffset);

        var count = 0;
        for (i in _firstTokenIndex...source.getCount()) {
            final tokenStartOffset = source.getStartOffset(i);
            if (tokenStartOffset >= endOffset) {
                break;
            }
            count++;
        }
        _tokensCount = count;
    }

    public function getMetadata(tokenIndex:Int):Int {
        return _source.getMetadata(_firstTokenIndex + tokenIndex);
    }

    public function getLanguageId(tokenIndex:Int):String {
        return _source.getLanguageId(_firstTokenIndex + tokenIndex);
    }

    public function getLineContent():String {
        return _source.getLineContent().substring(_startOffset, _endOffset);
    }

    public function equals(other:IViewLineTokens):Bool {
        if (Std.isOfType(other, SliceLineTokens)) {
            final o:SliceLineTokens = cast other;
            return (
                _startOffset == o._startOffset
                && _endOffset == o._endOffset
                && _deltaOffset == o._deltaOffset
                && _source.slicedEquals(o._source, _firstTokenIndex, _tokensCount)
            );
        }
        return false;
    }

    public function getCount():Int {
        return _tokensCount;
    }

    public function getStandardTokenType(tokenIndex:Int):StandardTokenType {
        return _source.getStandardTokenType(_firstTokenIndex + tokenIndex);
    }

    public function getForeground(tokenIndex:Int):ColorId {
        return _source.getForeground(_firstTokenIndex + tokenIndex);
    }

    public function getEndOffset(tokenIndex:Int):Int {
        final tokenEndOffset = _source.getEndOffset(_firstTokenIndex + tokenIndex);
        return (_endOffset < tokenEndOffset ? _endOffset : tokenEndOffset) - _startOffset + _deltaOffset;
    }

    public function getClassName(tokenIndex:Int):String {
        return _source.getClassName(_firstTokenIndex + tokenIndex);
    }

    public function getInlineStyle(tokenIndex:Int, colorMap:Array<String>):String {
        return _source.getInlineStyle(_firstTokenIndex + tokenIndex, colorMap);
    }

    public function getPresentation(tokenIndex:Int):ITokenPresentation {
        return _source.getPresentation(_firstTokenIndex + tokenIndex);
    }

    public function findTokenIndexAtOffset(offset:Int):Int {
        return _source.findTokenIndexAtOffset(offset + _startOffset - _deltaOffset) - _firstTokenIndex;
    }

    public function getTokenText(tokenIndex:Int):String {
        final adjustedTokenIndex = _firstTokenIndex + tokenIndex;
        final tokenStartOffset = _source.getStartOffset(adjustedTokenIndex);
        final tokenEndOffset = _source.getEndOffset(adjustedTokenIndex);
        var text = _source.getTokenText(adjustedTokenIndex);
        if (tokenStartOffset < _startOffset) {
            text = text.substring(_startOffset - tokenStartOffset);
        }
        if (tokenEndOffset > _endOffset) {
            text = text.substring(0, text.length - (tokenEndOffset - _endOffset));
        }
        return text;
    }

    public function forEach(callback:(tokenIndex:Int) -> Void):Void {
        for (tokenIndex in 0...getCount()) {
            callback(tokenIndex);
        }
    }

}

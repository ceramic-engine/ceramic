// Ported from vscode src/vs/editor/common/tokens/contiguousTokensStore.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.tokens;

import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range.IRange;
import cityscape.common.tokens.ContiguousTokensEditing.EMPTY_LINE_TOKENS;
import haxe.io.UInt32Array;

typedef ILineNumberRange = {
    final fromLineNumber:Int;
    final toLineNumber:Int;
}

/**
 * Represents contiguous tokens in a text model.
 */
class ContiguousTokensStore {

    var _lineTokens:Array<Null<UInt32Array>>;

    var _len:Int;

    final _languageIdCodec:ILanguageIdCodec;

    public function new(languageIdCodec:ILanguageIdCodec) {
        _lineTokens = [];
        _len = 0;
        _languageIdCodec = languageIdCodec;
    }

    public function flush():Void {
        _lineTokens = [];
        _len = 0;
    }

    public var hasTokens(get, never):Bool;
    inline function get_hasTokens():Bool {
        return _lineTokens.length > 0;
    }

    public function getTokens(topLevelLanguageId:String, lineIndex:Int, lineText:String):LineTokens {
        var rawLineTokens:Null<UInt32Array> = null;
        if (lineIndex < _len) {
            rawLineTokens = _lineTokens[lineIndex];
        }

        if (rawLineTokens != null && rawLineTokens != EMPTY_LINE_TOKENS) {
            return new LineTokens(rawLineTokens, lineText, _languageIdCodec);
        }

        final lineTokens = new UInt32Array(2);
        lineTokens[0] = lineText.length;
        lineTokens[1] = getDefaultMetadata(_languageIdCodec.encodeLanguageId(topLevelLanguageId));
        return new LineTokens(lineTokens, lineText, _languageIdCodec);
    }

    static function _massageTokens(topLevelLanguageId:LanguageId, lineTextLength:Int, _tokens:Null<UInt32Array>):UInt32Array {

        final tokens = _tokens;

        if (lineTextLength == 0) {
            var hasDifferentLanguageId = false;
            if (tokens != null && tokens.length > 1) {
                hasDifferentLanguageId = ((TokenMetadata.getLanguageId(tokens[1]) : Int) != (topLevelLanguageId : Int));
            }

            if (!hasDifferentLanguageId) {
                return EMPTY_LINE_TOKENS;
            }
        }

        if (tokens == null || tokens.length == 0) {
            final tokens = new UInt32Array(2);
            tokens[0] = lineTextLength;
            tokens[1] = getDefaultMetadata(topLevelLanguageId);
            return tokens;
        }

        // Ensure the last token covers the end of the text
        tokens[tokens.length - 2] = lineTextLength;

        return tokens;
    }

    function _ensureLine(lineIndex:Int):Void {
        while (lineIndex >= _len) {
            _lineTokens[_len] = null;
            _len++;
        }
    }

    function _deleteLines(start:Int, deleteCount:Int):Void {
        if (deleteCount == 0) {
            return;
        }
        if (start + deleteCount > _len) {
            deleteCount = _len - start;
        }
        _lineTokens.splice(start, deleteCount);
        _len -= deleteCount;
    }

    function _insertLines(insertIndex:Int, insertCount:Int):Void {
        if (insertCount == 0) {
            return;
        }
        final lineTokens:Array<Null<UInt32Array>> = [];
        for (i in 0...insertCount) {
            lineTokens[i] = null;
        }
        _lineTokens = cityscape.base.common.Arrays.arrayInsert(_lineTokens, insertIndex, lineTokens);
        _len += insertCount;
    }

    public function setTokens(topLevelLanguageId:String, lineIndex:Int, lineTextLength:Int, _tokens:Null<UInt32Array>, checkEquality:Bool):Bool {
        final tokens = _massageTokens(_languageIdCodec.encodeLanguageId(topLevelLanguageId), lineTextLength, _tokens);
        _ensureLine(lineIndex);
        final oldTokens = _lineTokens[lineIndex];
        _lineTokens[lineIndex] = tokens;

        if (checkEquality) {
            return !_equals(oldTokens, tokens);
        }
        return false;
    }

    static function _equals(a:Null<UInt32Array>, b:Null<UInt32Array>):Bool {
        if (a == null || b == null) {
            return a == null && b == null;
        }

        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    //#region Editing

    public function acceptEdit(range:IRange, eolCount:Int, firstLineLength:Int):Void {
        _acceptDeleteRange(range);
        _acceptInsertText(new Position(range.startLineNumber, range.startColumn), eolCount, firstLineLength);
    }

    function _acceptDeleteRange(range:IRange):Void {

        final firstLineIndex = range.startLineNumber - 1;
        if (firstLineIndex >= _len) {
            return;
        }

        if (range.startLineNumber == range.endLineNumber) {
            if (range.startColumn == range.endColumn) {
                // Nothing to delete
                return;
            }

            _lineTokens[firstLineIndex] = ContiguousTokensEditing.delete(_lineTokens[firstLineIndex], range.startColumn - 1, range.endColumn - 1);
            return;
        }

        _lineTokens[firstLineIndex] = ContiguousTokensEditing.deleteEnding(_lineTokens[firstLineIndex], range.startColumn - 1);

        final lastLineIndex = range.endLineNumber - 1;
        var lastLineTokens:Null<UInt32Array> = null;
        if (lastLineIndex < _len) {
            lastLineTokens = ContiguousTokensEditing.deleteBeginning(_lineTokens[lastLineIndex], range.endColumn - 1);
        }

        // Take remaining text on last line and append it to remaining text on first line
        _lineTokens[firstLineIndex] = ContiguousTokensEditing.append(_lineTokens[firstLineIndex], lastLineTokens);

        // Delete middle lines
        _deleteLines(range.startLineNumber, range.endLineNumber - range.startLineNumber);
    }

    function _acceptInsertText(position:Position, eolCount:Int, firstLineLength:Int):Void {

        if (eolCount == 0 && firstLineLength == 0) {
            // Nothing to insert
            return;
        }

        final lineIndex = position.lineNumber - 1;
        if (lineIndex >= _len) {
            return;
        }

        if (eolCount == 0) {
            // Inserting text on one line
            _lineTokens[lineIndex] = ContiguousTokensEditing.insert(_lineTokens[lineIndex], position.column - 1, firstLineLength);
            return;
        }

        _lineTokens[lineIndex] = ContiguousTokensEditing.deleteEnding(_lineTokens[lineIndex], position.column - 1);
        _lineTokens[lineIndex] = ContiguousTokensEditing.insert(_lineTokens[lineIndex], position.column - 1, firstLineLength);

        _insertLines(position.lineNumber, eolCount);
    }

    //#endregion

    public function setMultilineTokens(tokens:Array<ContiguousMultilineTokens>, textModel:ITextModel):{changes:Array<ILineNumberRange>} {
        if (tokens.length == 0) {
            return {changes: []};
        }

        final ranges:Array<ILineNumberRange> = [];

        final languageId = textModel.getLanguageId();
        for (i in 0...tokens.length) {
            final element = tokens[i];
            var minChangedLineNumber = 0;
            var maxChangedLineNumber = 0;
            var hasChange = false;
            for (lineNumber in element.startLineNumber...(element.endLineNumber + 1)) {
                if (hasChange) {
                    setTokens(languageId, lineNumber - 1, textModel.getLineLength(lineNumber), element.getLineTokens(lineNumber), false);
                    maxChangedLineNumber = lineNumber;
                }
                else {
                    final lineHasChange = setTokens(languageId, lineNumber - 1, textModel.getLineLength(lineNumber), element.getLineTokens(lineNumber), true);
                    if (lineHasChange) {
                        hasChange = true;
                        minChangedLineNumber = lineNumber;
                        maxChangedLineNumber = lineNumber;
                    }
                }
            }
            if (hasChange) {
                ranges.push({fromLineNumber: minChangedLineNumber, toLineNumber: maxChangedLineNumber});
            }
        }

        return {changes: ranges};
    }

    static function getDefaultMetadata(topLevelLanguageId:LanguageId):Int {
        return (
            ((topLevelLanguageId : Int) << MetadataConsts.LANGUAGEID_OFFSET)
            | (StandardTokenType.Other << MetadataConsts.TOKEN_TYPE_OFFSET)
            | (FontStyle.None << MetadataConsts.FONT_STYLE_OFFSET)
            | (ColorId.DefaultForeground << MetadataConsts.FOREGROUND_OFFSET)
            | (ColorId.DefaultBackground << MetadataConsts.BACKGROUND_OFFSET)
            // If there is no grammar, we just take a guess and try to match brackets.
            | (MetadataConsts.BALANCED_BRACKETS_MASK)
        );
    }

}

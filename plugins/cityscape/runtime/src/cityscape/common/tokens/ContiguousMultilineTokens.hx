// Ported from vscode src/vs/editor/common/tokens/contiguousMultilineTokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.tokens;

import cityscape.common.core.EolCounter;
import cityscape.common.core.LineRange;
import cityscape.common.core.Position;
import cityscape.common.core.Range.IRange;
import haxe.io.UInt32Array;

/**
 * Represents contiguous tokens over a contiguous range of lines.
 *
 * The binary serialization of Monaco (`serialize`, `deserialize`, used to
 * send tokens from a web worker) is not ported.
 */
class ContiguousMultilineTokens {

    /**
     * The start line number for this block of tokens.
     */
    var _startLineNumber:Int;

    /**
     * The tokens are stored in a binary format. There is an element for each line,
     * so `tokens[index]` contains all tokens on line `startLineNumber + index`.
     *
     * On a specific line, each token occupies two array indices. For token i:
     *  - at offset 2*i => endOffset
     *  - at offset 2*i + 1 => metadata
     */
    var _tokens:Array<Null<UInt32Array>>;

    /**
     * (Inclusive) start line number for these tokens.
     */
    public var startLineNumber(get, never):Int;
    inline function get_startLineNumber():Int {
        return _startLineNumber;
    }

    /**
     * (Inclusive) end line number for these tokens.
     */
    public var endLineNumber(get, never):Int;
    inline function get_endLineNumber():Int {
        return _startLineNumber + _tokens.length - 1;
    }

    public function new(startLineNumber:Int, tokens:Array<Null<UInt32Array>>) {
        _startLineNumber = startLineNumber;
        _tokens = tokens;
    }

    public function getLineRange():LineRange {
        return new LineRange(_startLineNumber, _startLineNumber + _tokens.length);
    }

    /**
     * @see `_tokens`
     */
    public function getLineTokens(lineNumber:Int):Null<UInt32Array> {
        return _tokens[lineNumber - _startLineNumber];
    }

    public function appendLineTokens(lineTokens:UInt32Array):Void {
        _tokens.push(lineTokens);
    }

    public function applyEdit(range:IRange, text:String):Void {
        final eol = EolCounter.countEOL(text);
        _acceptDeleteRange(range);
        _acceptInsertText(new Position(range.startLineNumber, range.startColumn), eol.eolCount, eol.firstLineLength);
    }

    function _acceptDeleteRange(range:IRange):Void {
        if (range.startLineNumber == range.endLineNumber && range.startColumn == range.endColumn) {
            // Nothing to delete
            return;
        }

        final firstLineIndex = range.startLineNumber - _startLineNumber;
        final lastLineIndex = range.endLineNumber - _startLineNumber;

        if (lastLineIndex < 0) {
            // this deletion occurs entirely before this block, so we only need to adjust line numbers
            final deletedLinesCount = lastLineIndex - firstLineIndex;
            _startLineNumber -= deletedLinesCount;
            return;
        }

        if (firstLineIndex >= _tokens.length) {
            // this deletion occurs entirely after this block, so there is nothing to do
            return;
        }

        if (firstLineIndex < 0 && lastLineIndex >= _tokens.length) {
            // this deletion completely encompasses this block
            _startLineNumber = 0;
            _tokens = [];
            return;
        }

        if (firstLineIndex == lastLineIndex) {
            // a delete on a single line
            _tokens[firstLineIndex] = ContiguousTokensEditing.delete(_tokens[firstLineIndex], range.startColumn - 1, range.endColumn - 1);
            return;
        }

        if (firstLineIndex >= 0) {
            // The first line survives
            _tokens[firstLineIndex] = ContiguousTokensEditing.deleteEnding(_tokens[firstLineIndex], range.startColumn - 1);

            if (lastLineIndex < _tokens.length) {
                // The last line survives
                final lastLineTokens = ContiguousTokensEditing.deleteBeginning(_tokens[lastLineIndex], range.endColumn - 1);

                // Take remaining text on last line and append it to remaining text on first line
                _tokens[firstLineIndex] = ContiguousTokensEditing.append(_tokens[firstLineIndex], lastLineTokens);

                // Delete middle lines
                _tokens.splice(firstLineIndex + 1, lastLineIndex - firstLineIndex);
            }
            else {
                // The last line does not survive

                // Take remaining text on last line and append it to remaining text on first line
                _tokens[firstLineIndex] = ContiguousTokensEditing.append(_tokens[firstLineIndex], null);

                // Delete lines
                _tokens = _tokens.slice(0, firstLineIndex + 1);
            }
        }
        else {
            // The first line does not survive

            final deletedBefore = -firstLineIndex;
            _startLineNumber -= deletedBefore;

            // Remove beginning from last line
            _tokens[lastLineIndex] = ContiguousTokensEditing.deleteBeginning(_tokens[lastLineIndex], range.endColumn - 1);

            // Delete lines
            _tokens = _tokens.slice(lastLineIndex);
        }
    }

    function _acceptInsertText(position:Position, eolCount:Int, firstLineLength:Int):Void {

        if (eolCount == 0 && firstLineLength == 0) {
            // Nothing to insert
            return;
        }

        final lineIndex = position.lineNumber - _startLineNumber;

        if (lineIndex < 0) {
            // this insertion occurs before this block, so we only need to adjust line numbers
            _startLineNumber += eolCount;
            return;
        }

        if (lineIndex >= _tokens.length) {
            // this insertion occurs after this block, so there is nothing to do
            return;
        }

        if (eolCount == 0) {
            // Inserting text on one line
            _tokens[lineIndex] = ContiguousTokensEditing.insert(_tokens[lineIndex], position.column - 1, firstLineLength);
            return;
        }

        _tokens[lineIndex] = ContiguousTokensEditing.deleteEnding(_tokens[lineIndex], position.column - 1);
        _tokens[lineIndex] = ContiguousTokensEditing.insert(_tokens[lineIndex], position.column - 1, firstLineLength);

        _insertLines(position.lineNumber, eolCount);
    }

    function _insertLines(insertIndex:Int, insertCount:Int):Void {
        if (insertCount == 0) {
            return;
        }
        final lineTokens:Array<Null<UInt32Array>> = [];
        for (i in 0...insertCount) {
            lineTokens[i] = null;
        }
        _tokens = cityscape.base.common.Arrays.arrayInsert(_tokens, insertIndex, lineTokens);
    }

}

// Ported from vscode src/vs/editor/common/tokens/sparseMultilineTokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.tokens;

import cityscape.base.common.CharCode;
import cityscape.common.core.EolCounter;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import haxe.io.UInt32Array;

/**
 * The result of `SparseMultilineTokens.split` (Monaco returns a tuple `[a, b]`).
 */
class SparseMultilineTokensSplit {

    /**
     * All the tokens before the range.
     */
    public final a:SparseMultilineTokens;

    /**
     * All the tokens after the range.
     */
    public final b:SparseMultilineTokens;

    public function new(a:SparseMultilineTokens, b:SparseMultilineTokens) {
        this.a = a;
        this.b = b;
    }

}

/**
 * Represents sparse tokens over a contiguous range of lines.
 */
class SparseMultilineTokens {

    public static function create(startLineNumber:Int, tokens:UInt32Array):SparseMultilineTokens {
        return new SparseMultilineTokens(startLineNumber, new SparseMultilineTokensStorage(tokens));
    }

    var _startLineNumber:Int;

    var _endLineNumber:Int;

    final _tokens:SparseMultilineTokensStorage;

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
        return _endLineNumber;
    }

    function new(startLineNumber:Int, tokens:SparseMultilineTokensStorage) {
        _startLineNumber = startLineNumber;
        _tokens = tokens;
        _endLineNumber = _startLineNumber + _tokens.getMaxDeltaLine();
    }

    public function toString():String {
        return _tokens.toString(_startLineNumber);
    }

    function _updateEndLineNumber():Void {
        _endLineNumber = _startLineNumber + _tokens.getMaxDeltaLine();
    }

    public function isEmpty():Bool {
        return _tokens.isEmpty();
    }

    public function getLineTokens(lineNumber:Int):Null<SparseLineTokens> {
        if (_startLineNumber <= lineNumber && lineNumber <= _endLineNumber) {
            return _tokens.getLineTokens(lineNumber - _startLineNumber);
        }
        return null;
    }

    public function getRange():Null<Range> {
        final deltaRange = _tokens.getRange();
        if (deltaRange == null) {
            return deltaRange;
        }
        return new Range(_startLineNumber + deltaRange.startLineNumber, deltaRange.startColumn, _startLineNumber + deltaRange.endLineNumber, deltaRange.endColumn);
    }

    public function removeTokens(range:Range):Void {
        final startLineIndex = range.startLineNumber - _startLineNumber;
        final endLineIndex = range.endLineNumber - _startLineNumber;

        _startLineNumber += _tokens.removeTokens(startLineIndex, range.startColumn - 1, endLineIndex, range.endColumn - 1);
        _updateEndLineNumber();
    }

    public function split(range:Range):SparseMultilineTokensSplit {
        // split tokens to two:
        // a) all the tokens before `range`
        // b) all the tokens after `range`
        final startLineIndex = range.startLineNumber - _startLineNumber;
        final endLineIndex = range.endLineNumber - _startLineNumber;

        final result = _tokens.split(startLineIndex, range.startColumn - 1, endLineIndex, range.endColumn - 1);
        return new SparseMultilineTokensSplit(
            new SparseMultilineTokens(_startLineNumber, result.a),
            new SparseMultilineTokens(_startLineNumber + result.bDeltaLine, result.b)
        );
    }

    public function applyEdit(range:IRange, text:String):Void {
        final eol = EolCounter.countEOL(text);
        acceptEdit(range, eol.eolCount, eol.firstLineLength, eol.lastLineLength, text.length > 0 ? StringTools.fastCodeAt(text, 0) : CharCode.Null);
    }

    public function acceptEdit(range:IRange, eolCount:Int, firstLineLength:Int, lastLineLength:Int, firstCharCode:Int):Void {
        _acceptDeleteRange(range);
        _acceptInsertText(new Position(range.startLineNumber, range.startColumn), eolCount, firstLineLength, lastLineLength, firstCharCode);
        _updateEndLineNumber();
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

        final tokenMaxDeltaLine = _tokens.getMaxDeltaLine();

        if (firstLineIndex >= tokenMaxDeltaLine + 1) {
            // this deletion occurs entirely after this block, so there is nothing to do
            return;
        }

        if (firstLineIndex < 0 && lastLineIndex >= tokenMaxDeltaLine + 1) {
            // this deletion completely encompasses this block
            _startLineNumber = 0;
            _tokens.clear();
            return;
        }

        if (firstLineIndex < 0) {
            final deletedBefore = -firstLineIndex;
            _startLineNumber -= deletedBefore;

            _tokens.acceptDeleteRange(range.startColumn - 1, 0, 0, lastLineIndex, range.endColumn - 1);
        }
        else {
            _tokens.acceptDeleteRange(0, firstLineIndex, range.startColumn - 1, lastLineIndex, range.endColumn - 1);
        }
    }

    function _acceptInsertText(position:Position, eolCount:Int, firstLineLength:Int, lastLineLength:Int, firstCharCode:Int):Void {

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

        final tokenMaxDeltaLine = _tokens.getMaxDeltaLine();

        if (lineIndex >= tokenMaxDeltaLine + 1) {
            // this insertion occurs after this block, so there is nothing to do
            return;
        }

        _tokens.acceptInsertText(lineIndex, position.column - 1, eolCount, firstLineLength, lastLineLength, firstCharCode);
    }

}

/**
 * The result of `SparseMultilineTokensStorage.split` (Monaco returns a tuple
 * `[a, b, bDeltaLine]`).
 */
private class SparseMultilineTokensStorageSplit {

    public final a:SparseMultilineTokensStorage;

    public final b:SparseMultilineTokensStorage;

    public final bDeltaLine:Int;

    public function new(a:SparseMultilineTokensStorage, b:SparseMultilineTokensStorage, bDeltaLine:Int) {
        this.a = a;
        this.b = b;
        this.bDeltaLine = bDeltaLine;
    }

}

/**
 * Not exported in Monaco.
 */
private class SparseMultilineTokensStorage {

    /**
     * The encoding of tokens is:
     *  4*i    deltaLine (from `startLineNumber`)
     *  4*i+1  startCharacter (from the line start)
     *  4*i+2  endCharacter (from the line start)
     *  4*i+3  metadata
     */
    final _tokens:UInt32Array;

    var _tokenCount:Int;

    public function new(tokens:UInt32Array) {
        _tokens = tokens;
        _tokenCount = Std.int(tokens.length / 4);
    }

    public function toString(startLineNumber:Int):String {
        final pieces:Array<String> = [];
        for (i in 0..._tokenCount) {
            pieces.push('(${_getDeltaLine(i) + startLineNumber},${_getStartCharacter(i)}-${_getEndCharacter(i)})');
        }
        return '[${pieces.join(',')}]';
    }

    public function getMaxDeltaLine():Int {
        final tokenCount = _getTokenCount();
        if (tokenCount == 0) {
            return -1;
        }
        return _getDeltaLine(tokenCount - 1);
    }

    public function getRange():Null<Range> {
        final tokenCount = _getTokenCount();
        if (tokenCount == 0) {
            return null;
        }
        final startChar = _getStartCharacter(0);
        final maxDeltaLine = _getDeltaLine(tokenCount - 1);
        final endChar = _getEndCharacter(tokenCount - 1);
        return new Range(0, startChar + 1, maxDeltaLine, endChar + 1);
    }

    inline function _getTokenCount():Int {
        return _tokenCount;
    }

    inline function _getDeltaLine(tokenIndex:Int):Int {
        return _tokens[4 * tokenIndex];
    }

    inline function _getStartCharacter(tokenIndex:Int):Int {
        return _tokens[4 * tokenIndex + 1];
    }

    inline function _getEndCharacter(tokenIndex:Int):Int {
        return _tokens[4 * tokenIndex + 2];
    }

    public function isEmpty():Bool {
        return (_getTokenCount() == 0);
    }

    public function getLineTokens(deltaLine:Int):Null<SparseLineTokens> {
        var low = 0;
        var high = _getTokenCount() - 1;

        while (low < high) {
            final mid = low + Std.int((high - low) / 2);
            final midDeltaLine = _getDeltaLine(mid);

            if (midDeltaLine < deltaLine) {
                low = mid + 1;
            }
            else if (midDeltaLine > deltaLine) {
                high = mid - 1;
            }
            else {
                var min = mid;
                while (min > low && _getDeltaLine(min - 1) == deltaLine) {
                    min--;
                }
                var max = mid;
                while (max < high && _getDeltaLine(max + 1) == deltaLine) {
                    max++;
                }
                return new SparseLineTokens(_tokens.subarray(4 * min, 4 * max + 4));
            }
        }

        // Monaco reads `this._tokens[4 * low]` even when the count is 0 (or
        // after `clear()`): it reads a stale value or `undefined`. Reading
        // past the end of a typed array is not safe on every Haxe target,
        // and with no token the line can have no token anyway.
        if (low < _getTokenCount() && _getDeltaLine(low) == deltaLine) {
            return new SparseLineTokens(_tokens.subarray(4 * low, 4 * low + 4));
        }

        return null;
    }

    public function clear():Void {
        _tokenCount = 0;
    }

    public function removeTokens(startDeltaLine:Int, startChar:Int, endDeltaLine:Int, endChar:Int):Int {
        final tokens = _tokens;
        final tokenCount = _tokenCount;
        var newTokenCount = 0;
        var hasDeletedTokens = false;
        var firstDeltaLine = 0;
        for (i in 0...tokenCount) {
            final srcOffset = 4 * i;
            final tokenDeltaLine:Int = tokens[srcOffset];
            final tokenStartCharacter:Int = tokens[srcOffset + 1];
            final tokenEndCharacter:Int = tokens[srcOffset + 2];
            final tokenMetadata:Int = tokens[srcOffset + 3];

            if (
                (tokenDeltaLine > startDeltaLine || (tokenDeltaLine == startDeltaLine && tokenEndCharacter >= startChar))
                && (tokenDeltaLine < endDeltaLine || (tokenDeltaLine == endDeltaLine && tokenStartCharacter <= endChar))
            ) {
                hasDeletedTokens = true;
            }
            else {
                if (newTokenCount == 0) {
                    firstDeltaLine = tokenDeltaLine;
                }
                if (hasDeletedTokens) {
                    // must move the token to the left
                    final destOffset = 4 * newTokenCount;
                    tokens[destOffset] = tokenDeltaLine - firstDeltaLine;
                    tokens[destOffset + 1] = tokenStartCharacter;
                    tokens[destOffset + 2] = tokenEndCharacter;
                    tokens[destOffset + 3] = tokenMetadata;
                }
                newTokenCount++;
            }
        }

        _tokenCount = newTokenCount;

        return firstDeltaLine;
    }

    public function split(startDeltaLine:Int, startChar:Int, endDeltaLine:Int, endChar:Int):SparseMultilineTokensStorageSplit {
        final tokens = _tokens;
        final tokenCount = _tokenCount;
        final aTokens:Array<Int> = [];
        final bTokens:Array<Int> = [];
        var destTokens:Array<Int> = aTokens;
        var destOffset = 0;
        var destFirstDeltaLine:Int = 0;
        for (i in 0...tokenCount) {
            final srcOffset = 4 * i;
            final tokenDeltaLine:Int = tokens[srcOffset];
            final tokenStartCharacter:Int = tokens[srcOffset + 1];
            final tokenEndCharacter:Int = tokens[srcOffset + 2];
            final tokenMetadata:Int = tokens[srcOffset + 3];

            if ((tokenDeltaLine > startDeltaLine || (tokenDeltaLine == startDeltaLine && tokenEndCharacter >= startChar))) {
                if ((tokenDeltaLine < endDeltaLine || (tokenDeltaLine == endDeltaLine && tokenStartCharacter <= endChar))) {
                    // this token is touching the range
                    continue;
                }
                else {
                    // this token is after the range
                    if (destTokens != bTokens) {
                        // this token is the first token after the range
                        destTokens = bTokens;
                        destOffset = 0;
                        destFirstDeltaLine = tokenDeltaLine;
                    }
                }
            }

            destTokens[destOffset++] = tokenDeltaLine - destFirstDeltaLine;
            destTokens[destOffset++] = tokenStartCharacter;
            destTokens[destOffset++] = tokenEndCharacter;
            destTokens[destOffset++] = tokenMetadata;
        }

        return new SparseMultilineTokensStorageSplit(
            new SparseMultilineTokensStorage(UInt32Arrays.fromInts(aTokens)),
            new SparseMultilineTokensStorage(UInt32Arrays.fromInts(bTokens)),
            destFirstDeltaLine
        );
    }

    public function acceptDeleteRange(horizontalShiftForFirstLineTokens:Int, startDeltaLine:Int, startCharacter:Int, endDeltaLine:Int, endCharacter:Int):Void {
        // This is a bit complex, here are the cases I used to think about this:
        //
        // 1. The token starts before the deletion range
        // 1a. The token is completely before the deletion range
        //               -----------
        //                          xxxxxxxxxxx
        // 1b. The token starts before, the deletion range ends after the token
        //               -----------
        //                      xxxxxxxxxxx
        // 1c. The token starts before, the deletion range ends precisely with the token
        //               ---------------
        //                      xxxxxxxx
        // 1d. The token starts before, the deletion range is inside the token
        //               ---------------
        //                    xxxxx
        //
        // 2. The token starts at the same position with the deletion range
        // 2a. The token starts at the same position, and ends inside the deletion range
        //               -------
        //               xxxxxxxxxxx
        // 2b. The token starts at the same position, and ends at the same position as the deletion range
        //               ----------
        //               xxxxxxxxxx
        // 2c. The token starts at the same position, and ends after the deletion range
        //               -------------
        //               xxxxxxx
        //
        // 3. The token starts inside the deletion range
        // 3a. The token is inside the deletion range
        //                -------
        //             xxxxxxxxxxxxx
        // 3b. The token starts inside the deletion range, and ends at the same position as the deletion range
        //                ----------
        //             xxxxxxxxxxxxx
        // 3c. The token starts inside the deletion range, and ends after the deletion range
        //                ------------
        //             xxxxxxxxxxx
        //
        // 4. The token starts after the deletion range
        //                  -----------
        //          xxxxxxxx
        //
        final tokens = _tokens;
        final tokenCount = _tokenCount;
        final deletedLineCount = (endDeltaLine - startDeltaLine);
        var newTokenCount = 0;
        var hasDeletedTokens = false;
        for (i in 0...tokenCount) {
            final srcOffset = 4 * i;
            var tokenDeltaLine:Int = tokens[srcOffset];
            var tokenStartCharacter:Int = tokens[srcOffset + 1];
            var tokenEndCharacter:Int = tokens[srcOffset + 2];
            final tokenMetadata:Int = tokens[srcOffset + 3];

            if (tokenDeltaLine < startDeltaLine || (tokenDeltaLine == startDeltaLine && tokenEndCharacter <= startCharacter)) {
                // 1a. The token is completely before the deletion range
                // => nothing to do
                newTokenCount++;
                continue;
            }
            else if (tokenDeltaLine == startDeltaLine && tokenStartCharacter < startCharacter) {
                // 1b, 1c, 1d
                // => the token survives, but it needs to shrink
                if (tokenDeltaLine == endDeltaLine && tokenEndCharacter > endCharacter) {
                    // 1d. The token starts before, the deletion range is inside the token
                    // => the token shrinks by the deletion character count
                    tokenEndCharacter -= (endCharacter - startCharacter);
                }
                else {
                    // 1b. The token starts before, the deletion range ends after the token
                    // 1c. The token starts before, the deletion range ends precisely with the token
                    // => the token shrinks its ending to the deletion start
                    tokenEndCharacter = startCharacter;
                }
            }
            else if (tokenDeltaLine == startDeltaLine && tokenStartCharacter == startCharacter) {
                // 2a, 2b, 2c
                if (tokenDeltaLine == endDeltaLine && tokenEndCharacter > endCharacter) {
                    // 2c. The token starts at the same position, and ends after the deletion range
                    // => the token shrinks by the deletion character count
                    tokenEndCharacter -= (endCharacter - startCharacter);
                }
                else {
                    // 2a. The token starts at the same position, and ends inside the deletion range
                    // 2b. The token starts at the same position, and ends at the same position as the deletion range
                    // => the token is deleted
                    hasDeletedTokens = true;
                    continue;
                }
            }
            else if (tokenDeltaLine < endDeltaLine || (tokenDeltaLine == endDeltaLine && tokenStartCharacter < endCharacter)) {
                // 3a, 3b, 3c
                if (tokenDeltaLine == endDeltaLine && tokenEndCharacter > endCharacter) {
                    // 3c. The token starts inside the deletion range, and ends after the deletion range
                    // => the token moves to continue right after the deletion
                    tokenDeltaLine = startDeltaLine;
                    tokenStartCharacter = startCharacter;
                    tokenEndCharacter = tokenStartCharacter + (tokenEndCharacter - endCharacter);
                }
                else {
                    // 3a. The token is inside the deletion range
                    // 3b. The token starts inside the deletion range, and ends at the same position as the deletion range
                    // => the token is deleted
                    hasDeletedTokens = true;
                    continue;
                }
            }
            else if (tokenDeltaLine > endDeltaLine) {
                // 4. (partial) The token starts after the deletion range, on a line below...
                if (deletedLineCount == 0 && !hasDeletedTokens) {
                    // early stop, there is no need to walk all the tokens and do nothing...
                    newTokenCount = tokenCount;
                    break;
                }
                tokenDeltaLine -= deletedLineCount;
            }
            else if (tokenDeltaLine == endDeltaLine && tokenStartCharacter >= endCharacter) {
                // 4. (continued) The token starts after the deletion range, on the last line where a deletion occurs
                if (horizontalShiftForFirstLineTokens != 0 && tokenDeltaLine == 0) {
                    tokenStartCharacter += horizontalShiftForFirstLineTokens;
                    tokenEndCharacter += horizontalShiftForFirstLineTokens;
                }
                tokenDeltaLine -= deletedLineCount;
                tokenStartCharacter -= (endCharacter - startCharacter);
                tokenEndCharacter -= (endCharacter - startCharacter);
            }
            else {
                throw new haxe.Exception('Not possible!');
            }

            final destOffset = 4 * newTokenCount;
            tokens[destOffset] = tokenDeltaLine;
            tokens[destOffset + 1] = tokenStartCharacter;
            tokens[destOffset + 2] = tokenEndCharacter;
            tokens[destOffset + 3] = tokenMetadata;
            newTokenCount++;
        }

        _tokenCount = newTokenCount;
    }

    public function acceptInsertText(deltaLine:Int, character:Int, eolCount:Int, firstLineLength:Int, lastLineLength:Int, firstCharCode:Int):Void {
        // Here are the cases I used to think about this:
        //
        // 1. The token is completely before the insertion point
        //            -----------   |
        // 2. The token ends precisely at the insertion point
        //            -----------|
        // 3. The token contains the insertion point
        //            -----|------
        // 4. The token starts precisely at the insertion point
        //            |-----------
        // 5. The token is completely after the insertion point
        //            |   -----------
        //
        final isInsertingPreciselyOneWordCharacter = (
            eolCount == 0
            && firstLineLength == 1
            && (
                (firstCharCode >= (CharCode.Digit0 : Int) && firstCharCode <= (CharCode.Digit9 : Int))
                || (firstCharCode >= (CharCode.A : Int) && firstCharCode <= (CharCode.Z : Int))
                || (firstCharCode >= (CharCode.a : Int) && firstCharCode <= (CharCode.z : Int))
            )
        );
        final tokens = _tokens;
        final tokenCount = _tokenCount;
        for (i in 0...tokenCount) {
            final offset = 4 * i;
            var tokenDeltaLine:Int = tokens[offset];
            var tokenStartCharacter:Int = tokens[offset + 1];
            var tokenEndCharacter:Int = tokens[offset + 2];

            if (tokenDeltaLine < deltaLine || (tokenDeltaLine == deltaLine && tokenEndCharacter < character)) {
                // 1. The token is completely before the insertion point
                // => nothing to do
                continue;
            }
            else if (tokenDeltaLine == deltaLine && tokenEndCharacter == character) {
                // 2. The token ends precisely at the insertion point
                // => expand the end character only if inserting precisely one character that is a word character
                if (isInsertingPreciselyOneWordCharacter) {
                    tokenEndCharacter += 1;
                }
                else {
                    continue;
                }
            }
            else if (tokenDeltaLine == deltaLine && tokenStartCharacter < character && character < tokenEndCharacter) {
                // 3. The token contains the insertion point
                if (eolCount == 0) {
                    // => just expand the end character
                    tokenEndCharacter += firstLineLength;
                }
                else {
                    // => cut off the token
                    tokenEndCharacter = character;
                }
            }
            else {
                // 4. or 5.
                if (tokenDeltaLine == deltaLine && tokenStartCharacter == character) {
                    // 4. The token starts precisely at the insertion point
                    // => grow the token (by keeping its start constant) only if inserting precisely one character that is a word character
                    // => otherwise behave as in case 5.
                    if (isInsertingPreciselyOneWordCharacter) {
                        continue;
                    }
                }
                // => the token must move and keep its size constant
                if (tokenDeltaLine == deltaLine) {
                    tokenDeltaLine += eolCount;
                    // this token is on the line where the insertion is taking place
                    if (eolCount == 0) {
                        tokenStartCharacter += firstLineLength;
                        tokenEndCharacter += firstLineLength;
                    }
                    else {
                        final tokenLength = tokenEndCharacter - tokenStartCharacter;
                        tokenStartCharacter = lastLineLength + (tokenStartCharacter - character);
                        tokenEndCharacter = tokenStartCharacter + tokenLength;
                    }
                }
                else {
                    tokenDeltaLine += eolCount;
                }
            }

            tokens[offset] = tokenDeltaLine;
            tokens[offset + 1] = tokenStartCharacter;
            tokens[offset + 2] = tokenEndCharacter;
        }
    }

}

class SparseLineTokens {

    final _tokens:UInt32Array;

    public function new(tokens:UInt32Array) {
        _tokens = tokens;
    }

    public function getCount():Int {
        return Std.int(_tokens.length / 4);
    }

    public function getStartCharacter(tokenIndex:Int):Int {
        return _tokens[4 * tokenIndex + 1];
    }

    public function getEndCharacter(tokenIndex:Int):Int {
        return _tokens[4 * tokenIndex + 2];
    }

    public function getMetadata(tokenIndex:Int):Int {
        return _tokens[4 * tokenIndex + 3];
    }

}

// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/linesSliceCharSequence.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer;

import cityscape.base.common.Arrays;
import cityscape.base.common.CharCode;
import cityscape.common.core.OffsetRange;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.diff.defaultLinesDiffComputer.Utils.isSpace;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DiffAlgorithm.ISequence;

class LinesSliceCharSequence implements ISequence {

    final elements:Array<Int> = [];
    final firstElementOffsetByLineIdx:Array<Int> = [];
    final lineStartOffsets:Array<Int> = [];
    final trimmedWsLengthsByLineIdx:Array<Int> = [];

    public final lines:Array<String>;
    final range:Range;
    public final considerWhitespaceChanges:Bool;

    public function new(lines:Array<String>, range:Range, considerWhitespaceChanges:Bool) {
        this.lines = lines;
        this.range = range;
        this.considerWhitespaceChanges = considerWhitespaceChanges;

        this.firstElementOffsetByLineIdx.push(0);
        for (lineNumber in this.range.startLineNumber...this.range.endLineNumber + 1) {
            var line = lines[lineNumber - 1];
            var lineStartOffset = 0;
            if (lineNumber == this.range.startLineNumber && this.range.startColumn > 1) {
                lineStartOffset = this.range.startColumn - 1;
                line = line.substring(lineStartOffset);
            }
            this.lineStartOffsets.push(lineStartOffset);

            var trimmedWsLength = 0;
            if (!considerWhitespaceChanges) {
                final trimmedStartLine = Utils.jsTrimStart(line);
                trimmedWsLength = line.length - trimmedStartLine.length;
                line = Utils.jsTrimEnd(trimmedStartLine);
            }
            this.trimmedWsLengthsByLineIdx.push(trimmedWsLength);

            final lineLength = lineNumber == this.range.endLineNumber ? Std.int(Math.min(this.range.endColumn - 1 - lineStartOffset - trimmedWsLength, line.length)) : line.length;
            for (i in 0...lineLength) {
                this.elements.push(StringTools.fastCodeAt(line, i));
            }

            if (lineNumber < this.range.endLineNumber) {
                this.elements.push('\n'.code);
                this.firstElementOffsetByLineIdx.push(this.elements.length);
            }
        }
    }

    public function toString():String {
        return 'Slice: "' + this.text + '"';
    }

    public var text(get, never):String;
    function get_text():String {
        return this.getText(new OffsetRange(0, this.length));
    }

    public function getText(range:OffsetRange):String {
        return Utils.fromCharCodes(this.elements, range.start, range.endExclusive);
    }

    public function getElement(offset:Int):Int {
        return this.elements[offset];
    }

    public var length(get, never):Int;
    function get_length():Int {
        return this.elements.length;
    }

    public function getBoundaryScore(length:Int):Int {
        //   a   b   c   ,           d   e   f
        // 11  0   0   12  15  6   13  0   0   11

        final prevCategory = getCategory(length > 0 ? this.elements[length - 1] : -1);
        final nextCategory = getCategory(length < this.elements.length ? this.elements[length] : -1);

        if (prevCategory == CharBoundaryCategory.LineBreakCR && nextCategory == CharBoundaryCategory.LineBreakLF) {
            // don't break between \r and \n
            return 0;
        }
        if (prevCategory == CharBoundaryCategory.LineBreakLF) {
            // prefer the linebreak before the change
            return 150;
        }

        var score = 0;
        if (prevCategory != nextCategory) {
            score += 10;
            if (prevCategory == CharBoundaryCategory.WordLower && nextCategory == CharBoundaryCategory.WordUpper) {
                score += 1;
            }
        }

        score += getCategoryBoundaryScore(prevCategory);
        score += getCategoryBoundaryScore(nextCategory);

        return score;
    }

    /**
     * `preference` is `'left'` or `'right'` (the default).
     */
    public function translateOffset(offset:Int, preference:String = 'right'):Position {
        // find smallest i, so that lineBreakOffsets[i] <= offset using binary search
        final i = Arrays.findLastIdxMonotonous(this.firstElementOffsetByLineIdx, (value) -> value <= offset);
        final lineOffset = offset - this.firstElementOffsetByLineIdx[i];
        return new Position(
            this.range.startLineNumber + i,
            1 + this.lineStartOffsets[i] + lineOffset + ((lineOffset == 0 && preference == 'left') ? 0 : this.trimmedWsLengthsByLineIdx[i])
        );
    }

    public function translateRange(range:OffsetRange):Range {
        final pos1 = this.translateOffset(range.start, 'right');
        final pos2 = this.translateOffset(range.endExclusive, 'left');
        if (pos2.isBefore(pos1)) {
            return Range.fromPositions(pos2, pos2);
        }
        return Range.fromPositions(pos1, pos2);
    }

    /**
     * Finds the word that contains the character at the given offset
     */
    public function findWordContaining(offset:Int):Null<OffsetRange> {
        if (offset < 0 || offset >= this.elements.length) {
            return null;
        }

        if (!isWordChar(this.elements[offset])) {
            return null;
        }

        // find start
        var start = offset;
        while (start > 0 && isWordChar(this.elements[start - 1])) {
            start--;
        }

        // find end
        var end = offset;
        while (end < this.elements.length && isWordChar(this.elements[end])) {
            end++;
        }

        return new OffsetRange(start, end);
    }

    public function countLinesIn(range:OffsetRange):Int {
        return this.translateOffset(range.endExclusive).lineNumber - this.translateOffset(range.start).lineNumber;
    }

    public function isStronglyEqual(offset1:Int, offset2:Int):Bool {
        return this.elements[offset1] == this.elements[offset2];
    }

    public function extendToFullLines(range:OffsetRange):OffsetRange {
        final startValue = Arrays.findLastMonotonous(this.firstElementOffsetByLineIdx, x -> x <= range.start);
        final start:Int = startValue != null ? startValue : 0;
        final endValue = Arrays.findFirstMonotonous(this.firstElementOffsetByLineIdx, x -> range.endExclusive <= x);
        final end:Int = endValue != null ? endValue : this.elements.length;
        return new OffsetRange(start, end);
    }

    static function isWordChar(charCode:Int):Bool {
        return charCode >= "a".code && charCode <= "z".code
            || charCode >= "A".code && charCode <= "Z".code
            || charCode >= "0".code && charCode <= "9".code;
    }

    static function getCategoryBoundaryScore(category:CharBoundaryCategory):Int {
        return switch category {
            case WordLower: 0;
            case WordUpper: 0;
            case WordNumber: 0;
            case End: 10;
            case Other: 2;
            case Separator: 30;
            case Space: 3;
            case LineBreakCR: 10;
            case LineBreakLF: 10;
            case _: 0;
        }
    }

    static function getCategory(charCode:Int):CharBoundaryCategory {
        if (charCode == CharCode.LineFeed) {
            return CharBoundaryCategory.LineBreakLF;
        }
        else if (charCode == CharCode.CarriageReturn) {
            return CharBoundaryCategory.LineBreakCR;
        }
        else if (isSpace(charCode)) {
            return CharBoundaryCategory.Space;
        }
        else if (charCode >= "a".code && charCode <= "z".code) {
            return CharBoundaryCategory.WordLower;
        }
        else if (charCode >= "A".code && charCode <= "Z".code) {
            return CharBoundaryCategory.WordUpper;
        }
        else if (charCode >= "0".code && charCode <= "9".code) {
            return CharBoundaryCategory.WordNumber;
        }
        else if (charCode == -1) {
            return CharBoundaryCategory.End;
        }
        else if (charCode == CharCode.Comma || charCode == CharCode.Semicolon) {
            return CharBoundaryCategory.Separator;
        }
        else {
            return CharBoundaryCategory.Other;
        }
    }

}

enum abstract CharBoundaryCategory(Int) from Int to Int {
    var WordLower = 0;
    var WordUpper = 1;
    var WordNumber = 2;
    var End = 3;
    var Other = 4;
    var Separator = 5;
    var Space = 6;
    var LineBreakCR = 7;
    var LineBreakLF = 8;
}

// Ported from vscode src/vs/editor/common/core/textLength.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

/**
 * Represents a non-negative length of text in terms of line and column count.
 */
class TextLength {

    public static final zero = new TextLength(0, 0);

    public static function lengthDiffNonNegative(start:TextLength, end:TextLength):TextLength {
        if (end.isLessThan(start)) {
            return TextLength.zero;
        }
        if (start.lineCount == end.lineCount) {
            return new TextLength(0, end.columnCount - start.columnCount);
        }
        else {
            return new TextLength(end.lineCount - start.lineCount, end.columnCount);
        }
    }

    public static function betweenPositions(position1:Position, position2:Position):TextLength {
        if (position1.lineNumber == position2.lineNumber) {
            return new TextLength(0, position2.column - position1.column);
        }
        else {
            return new TextLength(position2.lineNumber - position1.lineNumber, position2.column - 1);
        }
    }

    public static function ofRange(range:Range):TextLength {
        return TextLength.betweenPositions(range.getStartPosition(), range.getEndPosition());
    }

    /**
     * Like Monaco, counts code points (`for (const c of text)`) in the last line.
     */
    public static function ofText(text:String):TextLength {
        var line = 0;
        var column = 0;
        var i = 0;
        final len = text.length;
        while (i < len) {
            final c = StringTools.fastCodeAt(text, i);
            if (c == '\n'.code) {
                line++;
                column = 0;
            }
            else {
                column++;
                if (c >= 0xD800 && c <= 0xDBFF && i + 1 < len) {
                    final next = StringTools.fastCodeAt(text, i + 1);
                    if (next >= 0xDC00 && next <= 0xDFFF) {
                        i++;
                    }
                }
            }
            i++;
        }
        return new TextLength(line, column);
    }

    public final lineCount:Int;
    public final columnCount:Int;

    public function new(lineCount:Int, columnCount:Int) {
        this.lineCount = lineCount;
        this.columnCount = columnCount;
    }

    public function isZero():Bool {
        return lineCount == 0 && columnCount == 0;
    }

    public function isLessThan(other:TextLength):Bool {
        if (lineCount != other.lineCount) {
            return lineCount < other.lineCount;
        }
        return columnCount < other.columnCount;
    }

    public function isGreaterThan(other:TextLength):Bool {
        if (lineCount != other.lineCount) {
            return lineCount > other.lineCount;
        }
        return columnCount > other.columnCount;
    }

    public function isGreaterThanOrEqualTo(other:TextLength):Bool {
        if (lineCount != other.lineCount) {
            return lineCount > other.lineCount;
        }
        return columnCount >= other.columnCount;
    }

    public function equals(other:TextLength):Bool {
        return lineCount == other.lineCount && columnCount == other.columnCount;
    }

    public function compare(other:TextLength):Int {
        if (lineCount != other.lineCount) {
            return lineCount - other.lineCount;
        }
        return columnCount - other.columnCount;
    }

    public function add(other:TextLength):TextLength {
        if (other.lineCount == 0) {
            return new TextLength(lineCount, columnCount + other.columnCount);
        }
        else {
            return new TextLength(lineCount + other.lineCount, other.columnCount);
        }
    }

    public function createRange(startPosition:Position):Range {
        if (lineCount == 0) {
            return new Range(startPosition.lineNumber, startPosition.column, startPosition.lineNumber, startPosition.column + columnCount);
        }
        else {
            return new Range(startPosition.lineNumber, startPosition.column, startPosition.lineNumber + lineCount, columnCount + 1);
        }
    }

    public function toRange():Range {
        return new Range(1, 1, lineCount + 1, columnCount + 1);
    }

    public function addToPosition(position:Position):Position {
        if (lineCount == 0) {
            return new Position(position.lineNumber, position.column + columnCount);
        }
        else {
            return new Position(position.lineNumber + lineCount, columnCount + 1);
        }
    }

    public function toString():String {
        return lineCount + ',' + columnCount;
    }

}

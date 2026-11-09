// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/length.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.base.common.Strings;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.TextLength;

/**
 * Represents a non-negative length in terms of line and column count.
 * Does not allocate.
 *
 * We have 52 bits available in a JS number (a `Float` here, a double on
 * every target).
 * We use the upper 26 bits to store the line and the lower 26 bits to store the column.
 *
 * The module functions of length.ts are the static functions of this type.
 */
abstract Length(Float) {

    inline function new(value:Float) {
        this = value;
    }

    inline function raw():Float {
        return this;
    }

    static inline final factor:Float = 67108864.0; // 2 ** 26

    public static var lengthZero(get, never):Length;
    static inline function get_lengthZero():Length {
        return new Length(0);
    }

    /**
     * The end must be greater than or equal to the start.
     */
    public static inline function lengthDiff(startLineCount:Int, startColumnCount:Int, endLineCount:Int, endColumnCount:Int):Length {
        return (startLineCount != endLineCount)
            ? toLength(endLineCount - startLineCount, endColumnCount)
            : toLength(0, endColumnCount - startColumnCount);
    }

    public static inline function lengthIsZero(length:Length):Bool {
        return length.raw() == 0;
    }

    public static inline function toLength(lineCount:Int, columnCount:Int):Length {
        // llllllllllllllllllllllllllcccccccccccccccccccccccccc (52 bits)
        //       line count (26 bits)    column count (26 bits)

        // If there is no overflow (all values/sums below 2^26 = 67108864),
        // we have `toLength(lns1, cols1) + toLength(lns2, cols2) = toLength(lns1 + lns2, cols1 + cols2)`.

        return new Length(lineCount * factor + columnCount);
    }

    public static function lengthToObj(length:Length):TextLength {
        final l = length.raw();
        final lineCount = Math.ffloor(l / factor);
        final columnCount = l - lineCount * factor;
        return new TextLength(Std.int(lineCount), Std.int(columnCount));
    }

    public static inline function lengthGetLineCount(length:Length):Int {
        return Std.int(Math.ffloor(length.raw() / factor));
    }

    /**
     * Returns the amount of columns of the given length, assuming that it does not span any line.
     */
    public static inline function lengthGetColumnCountIfZeroLineCount(length:Length):Int {
        return Std.int(length.raw());
    }

    // [10 lines, 5 cols] + [ 0 lines, 3 cols] = [10 lines, 8 cols]
    // [10 lines, 5 cols] + [20 lines, 3 cols] = [30 lines, 3 cols]
    public static inline function lengthAdd(length1:Length, length2:Length):Length {
        final l1 = length1.raw();
        final l2 = length2.raw();
        var r = l1 + l2;
        if (l2 >= factor) {
            r = r - (l1 % factor);
        }
        return new Length(r);
    }

    public static function sumLengths<T>(items:Array<T>, lengthFn:(item:T) -> Length):Length {
        var result = lengthZero;
        for (item in items) {
            result = lengthAdd(result, lengthFn(item));
        }
        return result;
    }

    public static inline function lengthEquals(length1:Length, length2:Length):Bool {
        return length1.raw() == length2.raw();
    }

    /**
     * Returns a non negative length `result` such that `lengthAdd(length1, result) = length2`, or zero if such length does not exist.
     */
    public static function lengthDiffNonNegative(length1:Length, length2:Length):Length {
        final l1 = length1.raw();
        final l2 = length2.raw();

        final diff = l2 - l1;
        if (diff <= 0) {
            // line-count of length1 is higher than line-count of length2
            // or they are equal and column-count of length1 is higher than column-count of length2
            return lengthZero;
        }

        final lineCount1 = Math.ffloor(l1 / factor);
        final lineCount2 = Math.ffloor(l2 / factor);

        final colCount2 = l2 - lineCount2 * factor;

        if (lineCount1 == lineCount2) {
            final colCount1 = l1 - lineCount1 * factor;
            return new Length(colCount2 - colCount1);
        }
        else {
            return new Length((lineCount2 - lineCount1) * factor + colCount2);
        }
    }

    public static inline function lengthLessThan(length1:Length, length2:Length):Bool {
        // First, compare line counts, then column counts.
        return length1.raw() < length2.raw();
    }

    public static inline function lengthLessThanEqual(length1:Length, length2:Length):Bool {
        return length1.raw() <= length2.raw();
    }

    public static inline function lengthGreaterThanEqual(length1:Length, length2:Length):Bool {
        return length1.raw() >= length2.raw();
    }

    public static function lengthToPosition(length:Length):Position {
        final l = length.raw();
        final lineCount = Math.ffloor(l / factor);
        final colCount = l - lineCount * factor;
        return new Position(Std.int(lineCount) + 1, Std.int(colCount) + 1);
    }

    public static inline function positionToLength(position:Position):Length {
        return toLength(position.lineNumber - 1, position.column - 1);
    }

    public static function lengthsToRange(lengthStart:Length, lengthEnd:Length):Range {
        final l = lengthStart.raw();
        final lineCount = Math.ffloor(l / factor);
        final colCount = l - lineCount * factor;

        final l2 = lengthEnd.raw();
        final lineCount2 = Math.ffloor(l2 / factor);
        final colCount2 = l2 - lineCount2 * factor;

        return new Range(Std.int(lineCount) + 1, Std.int(colCount) + 1, Std.int(lineCount2) + 1, Std.int(colCount2) + 1);
    }

    public static function lengthOfRange(range:Range):TextLength {
        if (range.startLineNumber == range.endLineNumber) {
            return new TextLength(0, range.endColumn - range.startColumn);
        }
        else {
            return new TextLength(range.endLineNumber - range.startLineNumber, range.endColumn - 1);
        }
    }

    /**
     * The sign of the result is the order of the lengths (Monaco returns the
     * difference of the two numbers).
     */
    public static inline function lengthCompare(length1:Length, length2:Length):Int {
        final l1 = length1.raw();
        final l2 = length2.raw();
        return l1 < l2 ? -1 : (l1 > l2 ? 1 : 0);
    }

    public static function lengthOfString(str:String):Length {
        final lines = Strings.splitLines(str);
        return toLength(lines.length - 1, lines[lines.length - 1].length);
    }

    public static function lengthOfStringObj(str:String):TextLength {
        final lines = Strings.splitLines(str);
        return new TextLength(lines.length - 1, lines[lines.length - 1].length);
    }

    /**
     * Computes a numeric hash of the given length.
     */
    public static inline function lengthHash(length:Length):Float {
        return length.raw();
    }

    public static inline function lengthMax(length1:Length, length2:Length):Length {
        return length1.raw() > length2.raw() ? length1 : length2;
    }

}

// Ported from vscode src/vs/editor/common/core/range.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.JsValues;
import cityscape.common.core.Position.IPosition;

/**
 * A range in the editor. This interface is suitable for serialization.
 */
typedef IRange = {
    /**
     * Line number on which the range starts (starts at 1).
     */
    final startLineNumber:Int;
    /**
     * Column on which the range starts in line `startLineNumber` (starts at 1).
     */
    final startColumn:Int;
    /**
     * Line number on which the range ends.
     */
    final endLineNumber:Int;
    /**
     * Column on which the range ends in line `endLineNumber`.
     */
    final endColumn:Int;
}

/**
 * A range in the editor. (startLineNumber,startColumn) is <= (endLineNumber,endColumn)
 *
 * Static functions that have an instance method of the same name in Monaco
 * (`Range.isEmpty(range)` and `range.isEmpty()`) take the suffix `Static`
 * here (`Range.isEmptyStatic(range)`): Haxe does not allow both.
 */
class Range {

    /**
     * Line number on which the range starts (starts at 1).
     */
    public final startLineNumber:Int;

    /**
     * Column on which the range starts in line `startLineNumber` (starts at 1).
     */
    public final startColumn:Int;

    /**
     * Line number on which the range ends.
     */
    public final endLineNumber:Int;

    /**
     * Column on which the range ends in line `endLineNumber`.
     */
    public final endColumn:Int;

    public function new(startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int) {
        if ((startLineNumber > endLineNumber) || (startLineNumber == endLineNumber && startColumn > endColumn)) {
            this.startLineNumber = endLineNumber;
            this.startColumn = endColumn;
            this.endLineNumber = startLineNumber;
            this.endColumn = startColumn;
        }
        else {
            this.startLineNumber = startLineNumber;
            this.startColumn = startColumn;
            this.endLineNumber = endLineNumber;
            this.endColumn = endColumn;
        }
    }

    /**
     * Test if this range is empty.
     */
    public function isEmpty():Bool {
        return (this.startLineNumber == this.endLineNumber && this.startColumn == this.endColumn);
    }

    /**
     * Test if `range` is empty.
     */
    public static function isEmptyStatic(range:IRange):Bool {
        return (range.startLineNumber == range.endLineNumber && range.startColumn == range.endColumn);
    }

    /**
     * Test if position is in this range. If the position is at the edges, will return true.
     */
    public function containsPosition(position:IPosition):Bool {
        final lineNumber = position.lineNumber;
        final column = position.column;
        if (lineNumber < this.startLineNumber || lineNumber > this.endLineNumber) {
            return false;
        }
        if (lineNumber == this.startLineNumber && column < this.startColumn) {
            return false;
        }
        if (lineNumber == this.endLineNumber && column > this.endColumn) {
            return false;
        }
        return true;
    }

    /**
     * Test if `position` is in `range`. If the position is at the edges, will return true.
     */
    public static function containsPositionStatic(range:IRange, position:IPosition):Bool {
        if (position.lineNumber < range.startLineNumber || position.lineNumber > range.endLineNumber) {
            return false;
        }
        if (position.lineNumber == range.startLineNumber && position.column < range.startColumn) {
            return false;
        }
        if (position.lineNumber == range.endLineNumber && position.column > range.endColumn) {
            return false;
        }
        return true;
    }

    /**
     * Test if `position` is in `range`. If the position is at the edges, will return false.
     * @internal
     */
    public static function strictContainsPosition(range:IRange, position:IPosition):Bool {
        if (position.lineNumber < range.startLineNumber || position.lineNumber > range.endLineNumber) {
            return false;
        }
        if (position.lineNumber == range.startLineNumber && position.column <= range.startColumn) {
            return false;
        }
        if (position.lineNumber == range.endLineNumber && position.column >= range.endColumn) {
            return false;
        }
        return true;
    }

    /**
     * Test if range is in this range. If the range is equal to this range, will return true.
     */
    public function containsRange(range:IRange):Bool {
        return containsRangeStatic(this, range);
    }

    /**
     * Test if `otherRange` is in `range`. If the ranges are equal, will return true.
     */
    public static function containsRangeStatic(range:IRange, otherRange:IRange):Bool {
        if (otherRange.startLineNumber < range.startLineNumber || otherRange.endLineNumber < range.startLineNumber) {
            return false;
        }
        if (otherRange.startLineNumber > range.endLineNumber || otherRange.endLineNumber > range.endLineNumber) {
            return false;
        }
        if (otherRange.startLineNumber == range.startLineNumber && otherRange.startColumn < range.startColumn) {
            return false;
        }
        if (otherRange.endLineNumber == range.endLineNumber && otherRange.endColumn > range.endColumn) {
            return false;
        }
        return true;
    }

    /**
     * Test if `range` is strictly in this range. `range` must start after and end before this range for the result to be true.
     */
    public function strictContainsRange(range:IRange):Bool {
        return strictContainsRangeStatic(this, range);
    }

    /**
     * Test if `otherRange` is strictly in `range` (must start after, and end before). If the ranges are equal, will return false.
     */
    public static function strictContainsRangeStatic(range:IRange, otherRange:IRange):Bool {
        if (otherRange.startLineNumber < range.startLineNumber || otherRange.endLineNumber < range.startLineNumber) {
            return false;
        }
        if (otherRange.startLineNumber > range.endLineNumber || otherRange.endLineNumber > range.endLineNumber) {
            return false;
        }
        if (otherRange.startLineNumber == range.startLineNumber && otherRange.startColumn <= range.startColumn) {
            return false;
        }
        if (otherRange.endLineNumber == range.endLineNumber && otherRange.endColumn >= range.endColumn) {
            return false;
        }
        return true;
    }

    /**
     * A reunion of the two ranges.
     * The smallest position will be used as the start point, and the largest one as the end point.
     */
    public function plusRange(range:IRange):Range {
        return plusRangeStatic(this, range);
    }

    /**
     * A reunion of the two ranges.
     * The smallest position will be used as the start point, and the largest one as the end point.
     */
    public static function plusRangeStatic(a:IRange, b:IRange):Range {
        var startLineNumber:Int;
        var startColumn:Int;
        var endLineNumber:Int;
        var endColumn:Int;

        if (b.startLineNumber < a.startLineNumber) {
            startLineNumber = b.startLineNumber;
            startColumn = b.startColumn;
        }
        else if (b.startLineNumber == a.startLineNumber) {
            startLineNumber = b.startLineNumber;
            startColumn = b.startColumn < a.startColumn ? b.startColumn : a.startColumn;
        }
        else {
            startLineNumber = a.startLineNumber;
            startColumn = a.startColumn;
        }

        if (b.endLineNumber > a.endLineNumber) {
            endLineNumber = b.endLineNumber;
            endColumn = b.endColumn;
        }
        else if (b.endLineNumber == a.endLineNumber) {
            endLineNumber = b.endLineNumber;
            endColumn = b.endColumn > a.endColumn ? b.endColumn : a.endColumn;
        }
        else {
            endLineNumber = a.endLineNumber;
            endColumn = a.endColumn;
        }

        return new Range(startLineNumber, startColumn, endLineNumber, endColumn);
    }

    /**
     * A intersection of the two ranges.
     */
    public function intersectRanges(range:IRange):Null<Range> {
        return intersectRangesStatic(this, range);
    }

    /**
     * A intersection of the two ranges.
     */
    public static function intersectRangesStatic(a:IRange, b:IRange):Null<Range> {
        var resultStartLineNumber = a.startLineNumber;
        var resultStartColumn = a.startColumn;
        var resultEndLineNumber = a.endLineNumber;
        var resultEndColumn = a.endColumn;
        final otherStartLineNumber = b.startLineNumber;
        final otherStartColumn = b.startColumn;
        final otherEndLineNumber = b.endLineNumber;
        final otherEndColumn = b.endColumn;

        if (resultStartLineNumber < otherStartLineNumber) {
            resultStartLineNumber = otherStartLineNumber;
            resultStartColumn = otherStartColumn;
        }
        else if (resultStartLineNumber == otherStartLineNumber) {
            resultStartColumn = resultStartColumn > otherStartColumn ? resultStartColumn : otherStartColumn;
        }

        if (resultEndLineNumber > otherEndLineNumber) {
            resultEndLineNumber = otherEndLineNumber;
            resultEndColumn = otherEndColumn;
        }
        else if (resultEndLineNumber == otherEndLineNumber) {
            resultEndColumn = resultEndColumn < otherEndColumn ? resultEndColumn : otherEndColumn;
        }

        // Check if selection is now empty
        if (resultStartLineNumber > resultEndLineNumber) {
            return null;
        }
        if (resultStartLineNumber == resultEndLineNumber && resultStartColumn > resultEndColumn) {
            return null;
        }
        return new Range(resultStartLineNumber, resultStartColumn, resultEndLineNumber, resultEndColumn);
    }

    /**
     * Test if this range equals other.
     */
    public function equalsRange(other:Null<IRange>):Bool {
        return (
            other != null &&
            this.startLineNumber == other.startLineNumber &&
            this.startColumn == other.startColumn &&
            this.endLineNumber == other.endLineNumber &&
            this.endColumn == other.endColumn
        );
    }

    /**
     * Test if range `a` equals `b`.
     */
    public static function equalsRangeStatic(a:Null<IRange>, b:Null<IRange>):Bool {
        if (a == null && b == null) {
            return true;
        }
        return (
            a != null &&
            b != null &&
            a.startLineNumber == b.startLineNumber &&
            a.startColumn == b.startColumn &&
            a.endLineNumber == b.endLineNumber &&
            a.endColumn == b.endColumn
        );
    }

    /**
     * Return the end position (which will be after or equal to the start position)
     */
    public function getEndPosition():Position {
        return new Position(this.endLineNumber, this.endColumn);
    }

    /**
     * Return the end position (which will be after or equal to the start position)
     */
    public static function getEndPositionStatic(range:IRange):Position {
        return new Position(range.endLineNumber, range.endColumn);
    }

    /**
     * Return the start position (which will be before or equal to the end position)
     */
    public function getStartPosition():Position {
        return new Position(this.startLineNumber, this.startColumn);
    }

    /**
     * Return the start position (which will be before or equal to the end position)
     */
    public static function getStartPositionStatic(range:IRange):Position {
        return new Position(range.startLineNumber, range.startColumn);
    }

    /**
     * Transform to a user presentable string representation.
     */
    public function toString():String {
        return '[' + this.startLineNumber + ',' + this.startColumn + ' -> ' + this.endLineNumber + ',' + this.endColumn + ']';
    }

    /**
     * Create a new range using this range's start position, and using endLineNumber and endColumn as the end position.
     */
    public function setEndPosition(endLineNumber:Int, endColumn:Int):Range {
        return new Range(this.startLineNumber, this.startColumn, endLineNumber, endColumn);
    }

    /**
     * Create a new range using this range's end position, and using startLineNumber and startColumn as the start position.
     */
    public function setStartPosition(startLineNumber:Int, startColumn:Int):Range {
        return new Range(startLineNumber, startColumn, this.endLineNumber, this.endColumn);
    }

    /**
     * Create a new empty range using this range's start position.
     */
    public function collapseToStart():Range {
        return new Range(this.startLineNumber, this.startColumn, this.startLineNumber, this.startColumn);
    }

    /**
     * Create a new empty range using this range's start position.
     */
    public static function collapseToStartStatic(range:IRange):Range {
        return new Range(range.startLineNumber, range.startColumn, range.startLineNumber, range.startColumn);
    }

    /**
     * Create a new empty range using this range's end position.
     */
    public function collapseToEnd():Range {
        return new Range(this.endLineNumber, this.endColumn, this.endLineNumber, this.endColumn);
    }

    /**
     * Create a new empty range using this range's end position.
     */
    public static function collapseToEndStatic(range:IRange):Range {
        return new Range(range.endLineNumber, range.endColumn, range.endLineNumber, range.endColumn);
    }

    /**
     * Moves the range by the given amount of lines.
     */
    public function delta(lineCount:Int):Range {
        return new Range(this.startLineNumber + lineCount, this.startColumn, this.endLineNumber + lineCount, this.endColumn);
    }

    // ---

    public static function fromPositions(start:IPosition, ?end:IPosition):Range {
        if (end == null)
            end = start;
        return new Range(start.lineNumber, start.column, end.lineNumber, end.column);
    }

    /**
     * Create a `Range` from an `IRange` (null when `range` is null).
     */
    public static function lift(range:Null<IRange>):Null<Range> {
        if (range == null) {
            return null;
        }
        return new Range(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn);
    }

    /**
     * Test if `obj` is an `IRange`.
     */
    public static function isIRange(obj:Any):Bool {
        return (
            JsValues.truthy(obj)
            && JsValues.isNumber(JsValues.field(obj, 'startLineNumber'))
            && JsValues.isNumber(JsValues.field(obj, 'startColumn'))
            && JsValues.isNumber(JsValues.field(obj, 'endLineNumber'))
            && JsValues.isNumber(JsValues.field(obj, 'endColumn'))
        );
    }

    /**
     * Test if the two ranges are touching in any way.
     */
    public static function areIntersectingOrTouching(a:IRange, b:IRange):Bool {
        // Check if `a` is before `b`
        if (a.endLineNumber < b.startLineNumber || (a.endLineNumber == b.startLineNumber && a.endColumn < b.startColumn)) {
            return false;
        }

        // Check if `b` is before `a`
        if (b.endLineNumber < a.startLineNumber || (b.endLineNumber == a.startLineNumber && b.endColumn < a.startColumn)) {
            return false;
        }

        // These ranges must intersect
        return true;
    }

    /**
     * Test if the two ranges are intersecting. If the ranges are touching it returns true.
     */
    public static function areIntersecting(a:IRange, b:IRange):Bool {
        // Check if `a` is before `b`
        if (a.endLineNumber < b.startLineNumber || (a.endLineNumber == b.startLineNumber && a.endColumn <= b.startColumn)) {
            return false;
        }

        // Check if `b` is before `a`
        if (b.endLineNumber < a.startLineNumber || (b.endLineNumber == a.startLineNumber && b.endColumn <= a.startColumn)) {
            return false;
        }

        // These ranges must intersect
        return true;
    }

    /**
     * A function that compares ranges, useful for sorting ranges
     * It will first compare ranges on the startPosition and then on the endPosition
     */
    public static function compareRangesUsingStarts(a:Null<IRange>, b:Null<IRange>):Int {
        if (a != null && b != null) {
            final aStartLineNumber = a.startLineNumber;
            final bStartLineNumber = b.startLineNumber;
            if (aStartLineNumber == bStartLineNumber) {
                final aStartColumn = a.startColumn;
                final bStartColumn = b.startColumn;
                if (aStartColumn == bStartColumn) {
                    final aEndLineNumber = a.endLineNumber;
                    final bEndLineNumber = b.endLineNumber;
                    if (aEndLineNumber == bEndLineNumber) {
                        final aEndColumn = a.endColumn;
                        final bEndColumn = b.endColumn;
                        return aEndColumn - bEndColumn;
                    }
                    return aEndLineNumber - bEndLineNumber;
                }
                return aStartColumn - bStartColumn;
            }
            return aStartLineNumber - bStartLineNumber;
        }
        final aExists = (a != null ? 1 : 0);
        final bExists = (b != null ? 1 : 0);
        return aExists - bExists;
    }

    /**
     * A function that compares ranges, useful for sorting ranges
     * It will first compare ranges on the endPosition and then on the startPosition
     */
    public static function compareRangesUsingEnds(a:IRange, b:IRange):Int {
        if (a.endLineNumber == b.endLineNumber) {
            if (a.endColumn == b.endColumn) {
                if (a.startLineNumber == b.startLineNumber) {
                    return a.startColumn - b.startColumn;
                }
                return a.startLineNumber - b.startLineNumber;
            }
            return a.endColumn - b.endColumn;
        }
        return a.endLineNumber - b.endLineNumber;
    }

    /**
     * Test if the range spans multiple lines.
     */
    public static function spansMultipleLines(range:IRange):Bool {
        return range.endLineNumber > range.startLineNumber;
    }

    public function toJSON():IRange {
        return this;
    }

}

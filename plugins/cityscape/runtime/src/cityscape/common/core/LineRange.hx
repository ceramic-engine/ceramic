// Ported from vscode src/vs/editor/common/core/lineRange.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.Arrays;
import cityscape.base.common.Errors.BugIndicatingError;

/**
 * A range of lines (1-based).
 */
class LineRange {

    public static function fromRange(range:Range):LineRange {
        return new LineRange(range.startLineNumber, range.endLineNumber);
    }

    public static function fromRangeInclusive(range:Range):LineRange {
        return new LineRange(range.startLineNumber, range.endLineNumber + 1);
    }

    public static function subtract(a:LineRange, b:Null<LineRange>):Array<LineRange> {
        if (b == null) {
            return [a];
        }
        if (a.startLineNumber < b.startLineNumber && b.endLineNumberExclusive < a.endLineNumberExclusive) {
            return [
                new LineRange(a.startLineNumber, b.startLineNumber),
                new LineRange(b.endLineNumberExclusive, a.endLineNumberExclusive)
            ];
        }
        else if (b.startLineNumber <= a.startLineNumber && a.endLineNumberExclusive <= b.endLineNumberExclusive) {
            return [];
        }
        else if (b.endLineNumberExclusive < a.endLineNumberExclusive) {
            return [new LineRange(Std.int(Math.max(b.endLineNumberExclusive, a.startLineNumber)), a.endLineNumberExclusive)];
        }
        else {
            return [new LineRange(a.startLineNumber, Std.int(Math.min(b.startLineNumber, a.endLineNumberExclusive)))];
        }
    }

    /**
     * @param lineRanges An array of sorted line ranges.
     */
    public static function joinMany(lineRanges:Array<Array<LineRange>>):Array<LineRange> {
        if (lineRanges.length == 0) {
            return [];
        }
        var result = new LineRangeSet(lineRanges[0].copy());
        for (i in 1...lineRanges.length) {
            result = result.getUnion(new LineRangeSet(lineRanges[i].copy()));
        }
        return result.ranges;
    }

    /**
     * Monaco's static `LineRange.join` (renamed: Haxe forbids a static and an instance field with the same name).
     */
    public static function joinStatic(lineRanges:Array<LineRange>):LineRange {
        if (lineRanges.length == 0) {
            throw new BugIndicatingError('lineRanges cannot be empty');
        }
        var startLineNumber = lineRanges[0].startLineNumber;
        var endLineNumberExclusive = lineRanges[0].endLineNumberExclusive;
        for (i in 1...lineRanges.length) {
            startLineNumber = Std.int(Math.min(startLineNumber, lineRanges[i].startLineNumber));
            endLineNumberExclusive = Std.int(Math.max(endLineNumberExclusive, lineRanges[i].endLineNumberExclusive));
        }
        return new LineRange(startLineNumber, endLineNumberExclusive);
    }

    public static function ofLength(startLineNumber:Int, length:Int):LineRange {
        return new LineRange(startLineNumber, startLineNumber + length);
    }

    /**
     * The start line number.
     */
    public final startLineNumber:Int;

    /**
     * The end line number (exclusive).
     */
    public final endLineNumberExclusive:Int;

    public function new(startLineNumber:Int, endLineNumberExclusive:Int) {
        if (startLineNumber > endLineNumberExclusive) {
            throw new BugIndicatingError('startLineNumber $startLineNumber cannot be after endLineNumberExclusive $endLineNumberExclusive');
        }
        this.startLineNumber = startLineNumber;
        this.endLineNumberExclusive = endLineNumberExclusive;
    }

    /**
     * Indicates if this line range contains the given line number.
     */
    public function contains(lineNumber:Int):Bool {
        return startLineNumber <= lineNumber && lineNumber < endLineNumberExclusive;
    }

    /**
     * Indicates if this line range is empty.
     */
    public var isEmpty(get, never):Bool;
    inline function get_isEmpty():Bool {
        return startLineNumber == endLineNumberExclusive;
    }

    /**
     * Moves this line range by the given offset of line numbers.
     */
    public function delta(offset:Int):LineRange {
        return new LineRange(startLineNumber + offset, endLineNumberExclusive + offset);
    }

    public function deltaLength(offset:Int):LineRange {
        return new LineRange(startLineNumber, endLineNumberExclusive + offset);
    }

    /**
     * The number of lines this line range spans.
     */
    public var length(get, never):Int;
    inline function get_length():Int {
        return endLineNumberExclusive - startLineNumber;
    }

    /**
     * Creates a line range that combines this and the given line range.
     */
    public function join(other:LineRange):LineRange {
        return new LineRange(
            Std.int(Math.min(startLineNumber, other.startLineNumber)),
            Std.int(Math.max(endLineNumberExclusive, other.endLineNumberExclusive))
        );
    }

    public function toString():String {
        return '[' + startLineNumber + ',' + endLineNumberExclusive + ')';
    }

    /**
     * The resulting range is empty if the ranges do not intersect, but touch.
     * If the ranges don't even touch, the result is null.
     */
    public function intersect(other:LineRange):Null<LineRange> {
        final s = Std.int(Math.max(startLineNumber, other.startLineNumber));
        final e = Std.int(Math.min(endLineNumberExclusive, other.endLineNumberExclusive));
        if (s <= e) {
            return new LineRange(s, e);
        }
        return null;
    }

    public function intersectsStrict(other:LineRange):Bool {
        return startLineNumber < other.endLineNumberExclusive && other.startLineNumber < endLineNumberExclusive;
    }

    public function overlapOrTouch(other:LineRange):Bool {
        return startLineNumber <= other.endLineNumberExclusive && other.startLineNumber <= endLineNumberExclusive;
    }

    public function equals(b:LineRange):Bool {
        return startLineNumber == b.startLineNumber && endLineNumberExclusive == b.endLineNumberExclusive;
    }

    public function toInclusiveRange():Null<Range> {
        if (isEmpty) {
            return null;
        }
        return new Range(startLineNumber, 1, endLineNumberExclusive - 1, 0x7FFFFFFF);
    }

    /**
     * @deprecated Using this function is discouraged because it might lead to bugs: The end position is not guaranteed to be a valid position!
     */
    public function toExclusiveRange():Range {
        return new Range(startLineNumber, 1, endLineNumberExclusive, 1);
    }

    public function mapToLineArray<T>(f:(lineNumber:Int) -> T):Array<T> {
        final result:Array<T> = [];
        for (lineNumber in startLineNumber...endLineNumberExclusive) {
            result.push(f(lineNumber));
        }
        return result;
    }

    public function forEach(f:(lineNumber:Int) -> Void):Void {
        for (lineNumber in startLineNumber...endLineNumberExclusive) {
            f(lineNumber);
        }
    }

    public function includes(lineNumber:Int):Bool {
        return startLineNumber <= lineNumber && lineNumber < endLineNumberExclusive;
    }

    /**
     * Converts this 1-based line range to a 0-based offset range (subtracts 1!).
     */
    public function toOffsetRange():OffsetRange {
        return new OffsetRange(startLineNumber - 1, endLineNumberExclusive - 1);
    }

}

class LineRangeSet {

    /**
     * Sorted by start line number.
     * No two line ranges are touching or intersecting.
     */
    final _normalizedRanges:Array<LineRange>;

    public function new(?normalizedRanges:Array<LineRange>) {
        _normalizedRanges = normalizedRanges != null ? normalizedRanges : [];
    }

    public var ranges(get, never):Array<LineRange>;
    inline function get_ranges():Array<LineRange> {
        return _normalizedRanges;
    }

    public function addRange(range:LineRange):Void {
        if (range.length == 0) {
            return;
        }

        // idx of first element that touches range or that is after range
        final joinRangeStartIdx = Arrays.findFirstIdxMonotonousOrArrLen(_normalizedRanges, r -> r.endLineNumberExclusive >= range.startLineNumber);
        // idx of element after { last element that touches range or that is before range }
        final joinRangeEndIdxExclusive = Arrays.findLastIdxMonotonous(_normalizedRanges, r -> r.startLineNumber <= range.endLineNumberExclusive) + 1;

        if (joinRangeStartIdx == joinRangeEndIdxExclusive) {
            // If there is no element that touches range, then joinRangeStartIdx === joinRangeEndIdxExclusive and that value is the index of the element after range
            _normalizedRanges.insert(joinRangeStartIdx, range);
        }
        else if (joinRangeStartIdx == joinRangeEndIdxExclusive - 1) {
            // Else, there is an element that touches range and in this case it is both the first and last element. Thus we can replace it
            final joinRange = _normalizedRanges[joinRangeStartIdx];
            _normalizedRanges[joinRangeStartIdx] = joinRange.join(range);
        }
        else {
            // First and last element are different - we need to replace the entire range
            final joinRange = _normalizedRanges[joinRangeStartIdx].join(_normalizedRanges[joinRangeEndIdxExclusive - 1]).join(range);
            _normalizedRanges.splice(joinRangeStartIdx, joinRangeEndIdxExclusive - joinRangeStartIdx);
            _normalizedRanges.insert(joinRangeStartIdx, joinRange);
        }
    }

    public function contains(lineNumber:Int):Bool {
        final rangeThatStartsBeforeEnd = Arrays.findLastMonotonous(_normalizedRanges, r -> r.startLineNumber <= lineNumber);
        return rangeThatStartsBeforeEnd != null && rangeThatStartsBeforeEnd.endLineNumberExclusive > lineNumber;
    }

    public function intersects(range:LineRange):Bool {
        final rangeThatStartsBeforeEnd = Arrays.findLastMonotonous(_normalizedRanges, r -> r.startLineNumber < range.endLineNumberExclusive);
        return rangeThatStartsBeforeEnd != null && rangeThatStartsBeforeEnd.endLineNumberExclusive > range.startLineNumber;
    }

    public function getUnion(other:LineRangeSet):LineRangeSet {
        if (_normalizedRanges.length == 0) {
            return other;
        }
        if (other._normalizedRanges.length == 0) {
            return this;
        }

        final result:Array<LineRange> = [];
        var i1 = 0;
        var i2 = 0;
        var current:Null<LineRange> = null;
        while (i1 < _normalizedRanges.length || i2 < other._normalizedRanges.length) {
            var next:LineRange;
            if (i1 < _normalizedRanges.length && i2 < other._normalizedRanges.length) {
                final lineRange1 = _normalizedRanges[i1];
                final lineRange2 = other._normalizedRanges[i2];
                if (lineRange1.startLineNumber < lineRange2.startLineNumber) {
                    next = lineRange1;
                    i1++;
                }
                else {
                    next = lineRange2;
                    i2++;
                }
            }
            else if (i1 < _normalizedRanges.length) {
                next = _normalizedRanges[i1];
                i1++;
            }
            else {
                next = other._normalizedRanges[i2];
                i2++;
            }

            if (current == null) {
                current = next;
            }
            else {
                if (current.endLineNumberExclusive >= next.startLineNumber) {
                    // merge
                    current = new LineRange(current.startLineNumber, Std.int(Math.max(current.endLineNumberExclusive, next.endLineNumberExclusive)));
                }
                else {
                    // push
                    result.push(current);
                    current = next;
                }
            }
        }
        if (current != null) {
            result.push(current);
        }
        return new LineRangeSet(result);
    }

    /**
     * Subtracts all ranges in this set from `range` and returns the result.
     */
    public function subtractFrom(range:LineRange):LineRangeSet {
        final joinRangeStartIdx = Arrays.findFirstIdxMonotonousOrArrLen(_normalizedRanges, r -> r.endLineNumberExclusive >= range.startLineNumber);
        final joinRangeEndIdxExclusive = Arrays.findLastIdxMonotonous(_normalizedRanges, r -> r.startLineNumber <= range.endLineNumberExclusive) + 1;

        if (joinRangeStartIdx == joinRangeEndIdxExclusive) {
            return new LineRangeSet([range]);
        }

        final result:Array<LineRange> = [];
        var startLineNumber = range.startLineNumber;
        for (i in joinRangeStartIdx...joinRangeEndIdxExclusive) {
            final r = _normalizedRanges[i];
            if (r.startLineNumber > startLineNumber) {
                result.push(new LineRange(startLineNumber, r.startLineNumber));
            }
            startLineNumber = r.endLineNumberExclusive;
        }
        if (startLineNumber < range.endLineNumberExclusive) {
            result.push(new LineRange(startLineNumber, range.endLineNumberExclusive));
        }

        return new LineRangeSet(result);
    }

    public function toString():String {
        return [for (r in _normalizedRanges) r.toString()].join(', ');
    }

    public function getIntersection(other:LineRangeSet):LineRangeSet {
        final result:Array<LineRange> = [];

        var i1 = 0;
        var i2 = 0;
        while (i1 < _normalizedRanges.length && i2 < other._normalizedRanges.length) {
            final r1 = _normalizedRanges[i1];
            final r2 = other._normalizedRanges[i2];

            final i = r1.intersect(r2);
            if (i != null && !i.isEmpty) {
                result.push(i);
            }

            if (r1.endLineNumberExclusive < r2.endLineNumberExclusive) {
                i1++;
            }
            else {
                i2++;
            }
        }

        return new LineRangeSet(result);
    }

    public function getWithDelta(value:Int):LineRangeSet {
        return new LineRangeSet([for (r in _normalizedRanges) r.delta(value)]);
    }

}

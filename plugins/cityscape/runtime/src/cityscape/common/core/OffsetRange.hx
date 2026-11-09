// Ported from vscode src/vs/editor/common/core/offsetRange.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.Errors.BugIndicatingError;

typedef IOffsetRange = {
    final start:Int;
    final endExclusive:Int;
}

/**
 * A range of offsets (0-based).
 */
class OffsetRange {

    public static function addRange(range:OffsetRange, sortedRanges:Array<OffsetRange>):Void {
        var i = 0;
        while (i < sortedRanges.length && sortedRanges[i].endExclusive < range.start) {
            i++;
        }
        var j = i;
        while (j < sortedRanges.length && sortedRanges[j].start <= range.endExclusive) {
            j++;
        }
        if (i == j) {
            sortedRanges.insert(i, range);
        }
        else {
            final start = Std.int(Math.min(range.start, sortedRanges[i].start));
            final end = Std.int(Math.max(range.endExclusive, sortedRanges[j - 1].endExclusive));
            sortedRanges.splice(i, j - i);
            sortedRanges.insert(i, new OffsetRange(start, end));
        }
    }

    public static function tryCreate(start:Int, endExclusive:Int):Null<OffsetRange> {
        if (start > endExclusive) {
            return null;
        }
        return new OffsetRange(start, endExclusive);
    }

    public static function ofLength(length:Int):OffsetRange {
        return new OffsetRange(0, length);
    }

    public static function ofStartAndLength(start:Int, length:Int):OffsetRange {
        return new OffsetRange(start, start + length);
    }

    public final start:Int;

    public final endExclusive:Int;

    public function new(start:Int, endExclusive:Int) {
        this.start = start;
        this.endExclusive = endExclusive;
        if (start > endExclusive) {
            throw new BugIndicatingError('Invalid range: ' + toString());
        }
    }

    public var isEmpty(get, never):Bool;
    inline function get_isEmpty():Bool {
        return start == endExclusive;
    }

    public function delta(offset:Int):OffsetRange {
        return new OffsetRange(start + offset, endExclusive + offset);
    }

    public function deltaStart(offset:Int):OffsetRange {
        return new OffsetRange(start + offset, endExclusive);
    }

    public function deltaEnd(offset:Int):OffsetRange {
        return new OffsetRange(start, endExclusive + offset);
    }

    public var length(get, never):Int;
    inline function get_length():Int {
        return endExclusive - start;
    }

    public function toString():String {
        return '[' + start + ', ' + endExclusive + ')';
    }

    public function equals(other:OffsetRange):Bool {
        return start == other.start && endExclusive == other.endExclusive;
    }

    public function containsRange(other:OffsetRange):Bool {
        return start <= other.start && other.endExclusive <= endExclusive;
    }

    public function contains(offset:Int):Bool {
        return start <= offset && offset < endExclusive;
    }

    /**
     * for all numbers n: range1.contains(n) or range2.contains(n) => range1.join(range2).contains(n)
     * The joined range is the smallest range that contains both ranges.
     */
    public function join(other:OffsetRange):OffsetRange {
        return new OffsetRange(Std.int(Math.min(start, other.start)), Std.int(Math.max(endExclusive, other.endExclusive)));
    }

    /**
     * The resulting range is empty if the ranges do not intersect, but touch.
     * If the ranges don't even touch, the result is null.
     */
    public function intersect(other:OffsetRange):Null<OffsetRange> {
        final s = Std.int(Math.max(start, other.start));
        final e = Std.int(Math.min(endExclusive, other.endExclusive));
        if (s <= e) {
            return new OffsetRange(s, e);
        }
        return null;
    }

    public function intersects(other:OffsetRange):Bool {
        final s = Std.int(Math.max(start, other.start));
        final e = Std.int(Math.min(endExclusive, other.endExclusive));
        return s < e;
    }

    public function intersectsOrTouches(other:OffsetRange):Bool {
        final s = Std.int(Math.max(start, other.start));
        final e = Std.int(Math.min(endExclusive, other.endExclusive));
        return s <= e;
    }

    public function isBefore(other:OffsetRange):Bool {
        return endExclusive <= other.start;
    }

    public function isAfter(other:OffsetRange):Bool {
        return start >= other.endExclusive;
    }

    public function slice<T>(arr:Array<T>):Array<T> {
        return arr.slice(start, endExclusive);
    }

    public function substring(str:String):String {
        return str.substring(start, endExclusive);
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/input/base/cursor.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;

/**
 * A selection in the text, represented by start and end byte indices.
 * Mutable, like the Rust `Copy` struct: use `copy()` where Rust copies it.
 */
class Selection {

    public var start:Int;

    public var end:Int;

    public inline function new(start:Int = 0, end:Int = 0) {
        this.start = start;
        this.end = end;
    }

    public inline function len():Int {
        return end > start ? end - start : 0;
    }

    public inline function isEmpty():Bool {
        return start == end;
    }

    /** Clears the selection, setting start and end to 0. */
    public inline function clear():Void {
        start = 0;
        end = 0;
    }

    /** Checks if the given offset is within the selection range. */
    public inline function contains(offset:Int):Bool {
        return offset >= start && offset < end;
    }

    public inline function copy():Selection {
        return new Selection(start, end);
    }

    public function equals(other:Null<Selection>):Bool {
        return other != null && other.start == start && other.end == end;
    }

    /** `From<Range<usize>> for Selection`. */
    public static inline function fromRange(range:Range):Selection {
        return new Selection(range.start, range.end);
    }

    /** `From<Selection> for Range<usize>`. */
    public inline function toRange():Range {
        return new Range(start, end);
    }

    public function toString():String {
        return 'Selection { start: ' + start + ', end: ' + end + ' }';
    }

}

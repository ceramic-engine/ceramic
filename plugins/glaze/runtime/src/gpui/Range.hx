// New code for the Haxe port of GPUI: Rust's `std::ops::Range<usize>`, as used
// by the text input APIs of gpui-pre 0.3.10 (src/platform.rs, src/input.rs,
// Zed Industries, Apache-2.0). See NOTICE.md.
package gpui;

/**
 * A half open range of offsets, `start..end` (Rust `Range<usize>`).
 * Immutable, compare with `equals()`.
 *
 * Text input APIs (`InputHandler`, `EntityInputHandler`) use ranges of UTF-16
 * code units; the rest of GPUI uses UTF-8 byte offsets.
 */
class Range {

    public final start:Int;

    public final end:Int;

    public inline function new(start:Int, end:Int) {
        this.start = start;
        this.end = end;
    }

    /** True if the range contains no offset (`start >= end`). */
    public inline function isEmpty():Bool {
        return start >= end;
    }

    /** Number of offsets in the range (0 when empty). */
    public inline function len():Int {
        return end > start ? end - start : 0;
    }

    /** True if `offset` is in the range. */
    public inline function contains(offset:Int):Bool {
        return offset >= start && offset < end;
    }

    public function equals(other:Null<Range>):Bool {
        return other != null && other.start == start && other.end == end;
    }

    /** `start..end`, like Rust's `Debug` */
    public function toString():String {
        return start + '..' + end;
    }

    /** `start..end`, or `None` for a null range */
    public static function describe(range:Null<Range>):String {
        return range != null ? range.toString() : 'None';
    }

}

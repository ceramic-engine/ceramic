// New code for the Haxe port of gpui-kit: Rust's `std::ops::Range<Pixels>`, as used by
// crates/base/src/resizable (Longbridge, Apache-2.0). See NOTICE.md.
package glaze.kit.base.resizable;

import glaze.Pixels;

/**
 * A range of pixels, `start..end` (Rust `Range<Pixels>`, the size range of a
 * resizable panel). Immutable, compare with `equals()`.
 */
class PixelsRange {

    public final start:Float;

    public final end:Float;

    public inline function new(start:Pixels, end:Pixels) {
        this.start = start;
        this.end = end;
    }

    public function equals(other:Null<PixelsRange>):Bool {
        return other != null && (other.start : Float) == (start : Float) && (other.end : Float) == (end : Float);
    }

    public function toString():String {
        return '$start..$end';
    }

}

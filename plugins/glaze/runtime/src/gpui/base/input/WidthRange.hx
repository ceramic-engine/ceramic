// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper/wrap_width.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Pixels;
import haxe.Int64;
import haxe.io.FPHelper;

/**
 * Conservative width intervals reuse the original Unicode wrapping decisions
 * without approximating glyphs.
 *
 * All comparisons that chose the current line breaks must retain their truth value.
 *
 * Rust's `WidthRange` is `Copy`: `copy()` stands for the implicit copy.
 * The port measures in double precision (like the rest of its text system),
 * so the bounds are rounded inward with the `f64` `next_up` / `next_down`
 * instead of the `f32` ones: the interval keeps the same meaning (every
 * width inside it gives the same fit decisions).
 */
class WidthRange {

    /** Inclusive lower bound in logical pixels, rounded inward for floating point subtraction. */
    public var minimum(default, null):Float;

    /** Exclusive upper bound in logical pixels, also rounded inward. */
    public var maximum(default, null):Float;

    inline function new(minimum:Float, maximum:Float) {
        this.minimum = minimum;
        this.maximum = maximum;
    }

    /** An empty line imposes no width constraint until a glyph measurement narrows it. */
    public static inline function all():WidthRange {
        return new WidthRange(Pixels.MIN, Pixels.MAX);
    }

    /** Unknown measurement semantics (notably inline elements) must always take the original path. */
    public static inline function empty():WidthRange {
        return new WidthRange(0.0, 0.0);
    }

    public inline function copy():WidthRange {
        return new WidthRange(minimum, maximum);
    }

    /**
     * Report the original fit predicate and retain a safe interval for the enclosing viewport.
     * `indent` is subtracted from its width to obtain `available` on continuation rows.
     */
    public function fits(measured:Float, available:Float, indent:Float):Bool {
        final fits = measured <= available;
        final boundary = measured + indent;
        if (fits) {
            minimum = fmax(minimum, nextUp(boundary));
        }
        else {
            maximum = fmin(maximum, nextDown(boundary));
        }
        return fits;
    }

    /** Combine line/substring constraints; an empty intersection simply disables reuse. */
    public function intersect(other:WidthRange):Void {
        minimum = fmax(minimum, other.minimum);
        maximum = fmin(maximum, other.maximum);
    }

    /** Rust `f32::max`: a NaN operand is ignored. */
    static inline function fmax(a:Float, b:Float):Float {
        return (b > a || a != a) ? b : a;
    }

    /** Rust `f32::min`: a NaN operand is ignored. */
    static inline function fmin(a:Float, b:Float):Float {
        return (b < a || a != a) ? b : a;
    }

    /** NaN and threshold boundaries fail closed, allowing the original measurer to decide. */
    public inline function contains(width:Float):Bool {
        return width >= minimum && width < maximum;
    }

    public function toString():String {
        return 'WidthRange { minimum: $minimum, maximum: $maximum }';
    }

    /** Rust `f64::next_up`. */
    public static function nextUp(value:Float):Float {
        if (value != value || value == Math.POSITIVE_INFINITY)
            return value;
        if (value == 0.0)
            return FPHelper.i64ToDouble(1, 0);
        final bits = FPHelper.doubleToI64(value);
        final next = value > 0 ? Int64.add(bits, 1) : Int64.sub(bits, 1);
        return FPHelper.i64ToDouble(next.low, next.high);
    }

    /** Rust `f64::next_down`. */
    public static function nextDown(value:Float):Float {
        return -nextUp(-value);
    }

}

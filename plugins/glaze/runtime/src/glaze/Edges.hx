// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * The edges of a box in a 2D space, such as padding, margin or border widths.
 *
 * Stands for Rust's `Edges<Pixels>`, `Edges<ScaledPixels>` and `Edges<f32>`.
 * Use `EdgesOf<T>` for non numeric values (`Edges<Length>`...).
 *
 * Immutable: every operation returns a new instance.
 */
class Edges {

    /**
     * The size of the top edge.
     */
    public final top:Float;

    /**
     * The size of the right edge.
     */
    public final right:Float;

    /**
     * The size of the bottom edge.
     */
    public final bottom:Float;

    /**
     * The size of the left edge.
     */
    public final left:Float;

    public inline function new(top:Float = 0, right:Float = 0, bottom:Float = 0, left:Float = 0) {

        this.top = top;
        this.right = right;
        this.bottom = bottom;
        this.left = left;

    }

    /**
     * Edges where all sides are set to the same value
     * (also `From<Pixels> for Edges<Pixels>`).
     */
    public static inline function all(value:Float):Edges {

        return new Edges(value, value, value, value);

    }

    /**
     * Returns new edges with `f` applied to each side.
     */
    public inline function map(f:(Float) -> Float):Edges {

        return new Edges(f(top), f(right), f(bottom), f(left));

    }

    /**
     * Returns generic edges with `f` applied to each side.
     */
    public inline function mapOf<U>(f:(Float) -> U):EdgesOf<U> {

        return new EdgesOf<U>(f(top), f(right), f(bottom), f(left));

    }

    /**
     * Checks if any of the sides satisfies the given predicate.
     */
    public inline function any(predicate:(Float) -> Bool):Bool {

        return predicate(top) || predicate(right) || predicate(bottom) || predicate(left);

    }

    /**
     * Rust `Edges * Edges`: multiplies each side by the matching side of `rhs`.
     */
    public inline function mul(rhs:Edges):Edges {

        return new Edges(top * rhs.top, right * rhs.right, bottom * rhs.bottom, left * rhs.left);

    }

    /**
     * Scales every side by a given factor (`Edges<Pixels>` to `Edges<ScaledPixels>`,
     * also used for Rust's `edges *= scalar`).
     */
    public inline function scale(factor:Float):Edges {

        return new Edges(top * factor, right * factor, bottom * factor, left * factor);

    }

    /**
     * The maximum value of any side.
     */
    public inline function max():Float {

        final a = top >= right ? top : right;
        final b = a >= bottom ? a : bottom;
        return b >= left ? b : left;

    }

    /**
     * Structural equality.
     */
    public inline function equals(other:Edges):Bool {

        return other != null && top == other.top && right == other.right && bottom == other.bottom && left == other.left;

    }

    public function toString():String {

        return 'Edges(top: $top, right: $right, bottom: $bottom, left: $left)';

    }

}

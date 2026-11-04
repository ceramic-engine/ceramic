// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * The corners of a box in a 2D space, such as border radii.
 *
 * Stands for Rust's `Corners<Pixels>`, `Corners<ScaledPixels>` and `Corners<f32>`.
 * Use `CornersOf<T>` for non numeric values (`Corners<AbsoluteLength>`...).
 *
 * Immutable: every operation returns a new instance.
 */
class Corners {

    /**
     * The value associated with the top left corner.
     */
    public final topLeft:Float;

    /**
     * The value associated with the top right corner.
     */
    public final topRight:Float;

    /**
     * The value associated with the bottom right corner.
     */
    public final bottomRight:Float;

    /**
     * The value associated with the bottom left corner.
     */
    public final bottomLeft:Float;

    public inline function new(topLeft:Float = 0, topRight:Float = 0, bottomRight:Float = 0, bottomLeft:Float = 0) {

        this.topLeft = topLeft;
        this.topRight = topRight;
        this.bottomRight = bottomRight;
        this.bottomLeft = bottomLeft;

    }

    /**
     * Corners where all values are the same
     * (also `From<Pixels> for Corners<Pixels>`).
     */
    public static inline function all(value:Float):Corners {

        return new Corners(value, value, value, value);

    }

    /**
     * Returns the value for the given anchor. Center anchors give the
     * average of the two adjacent corners.
     */
    public function corner(corner:Anchor):Float {

        return switch corner {
            case TopLeft: topLeft;
            case TopRight: topRight;
            case BottomLeft: bottomLeft;
            case BottomRight: bottomRight;
            case TopCenter: (topLeft + topRight) / 2.0;
            case BottomCenter: (bottomLeft + bottomRight) / 2.0;
            case LeftCenter: (topLeft + bottomLeft) / 2.0;
            case RightCenter: (topRight + bottomRight) / 2.0;
        }

    }

    /**
     * Scales every value by a given factor (`Corners<Pixels>` to `Corners<ScaledPixels>`,
     * also used for Rust's `corners *= scalar`).
     */
    public inline function scale(factor:Float):Corners {

        return new Corners(topLeft * factor, topRight * factor, bottomRight * factor, bottomLeft * factor);

    }

    /**
     * The maximum value of any corner.
     */
    public inline function max():Float {

        final a = topLeft >= topRight ? topLeft : topRight;
        final b = a >= bottomRight ? a : bottomRight;
        return b >= bottomLeft ? b : bottomLeft;

    }

    /**
     * Clamps corner radii to be less than or equal to half the shortest side of a quad.
     */
    public inline function clampRadiiForQuadSize(size:Size):Corners {

        final max = (size.width <= size.height ? size.width : size.height) / 2.0;
        return new Corners(
            topLeft <= max ? topLeft : max,
            topRight <= max ? topRight : max,
            bottomRight <= max ? bottomRight : max,
            bottomLeft <= max ? bottomLeft : max
        );

    }

    /**
     * Returns new corners with `f` applied to each value.
     */
    public inline function map(f:(Float) -> Float):Corners {

        return new Corners(f(topLeft), f(topRight), f(bottomRight), f(bottomLeft));

    }

    /**
     * Returns generic corners with `f` applied to each value.
     */
    public inline function mapOf<U>(f:(Float) -> U):CornersOf<U> {

        return new CornersOf<U>(f(topLeft), f(topRight), f(bottomRight), f(bottomLeft));

    }

    /**
     * Rust `Corners * Corners`: multiplies each value by the matching value of `rhs`.
     */
    public inline function mul(rhs:Corners):Corners {

        return new Corners(topLeft * rhs.topLeft, topRight * rhs.topRight, bottomRight * rhs.bottomRight, bottomLeft * rhs.bottomLeft);

    }

    /**
     * Whether all values are zero (Rust trait `IsZero`).
     */
    public inline function isZero():Bool {

        return topLeft == 0 && topRight == 0 && bottomRight == 0 && bottomLeft == 0;

    }

    /**
     * Structural equality.
     */
    public inline function equals(other:Corners):Bool {

        return other != null
            && topLeft == other.topLeft
            && topRight == other.topRight
            && bottomRight == other.bottomRight
            && bottomLeft == other.bottomLeft;

    }

    public function toString():String {

        return 'Corners(topLeft: $topLeft, topRight: $topRight, bottomRight: $bottomRight, bottomLeft: $bottomLeft)';

    }

}

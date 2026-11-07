// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Generic version of `Corners`, for non numeric values (`Corners<AbsoluteLength>`...).
 *
 * Methods that Rust defines on `Corners<AbsoluteLength>` live in
 * `CornersOfAbsoluteLength` and are attached with `@:using`.
 *
 * Immutable: every operation returns a new instance.
 */
@:using(glaze.CornersOfAbsoluteLength)
class CornersOf<T> {

    /**
     * The value associated with the top left corner.
     */
    public final topLeft:T;

    /**
     * The value associated with the top right corner.
     */
    public final topRight:T;

    /**
     * The value associated with the bottom right corner.
     */
    public final bottomRight:T;

    /**
     * The value associated with the bottom left corner.
     */
    public final bottomLeft:T;

    public inline function new(topLeft:T, topRight:T, bottomRight:T, bottomLeft:T) {

        this.topLeft = topLeft;
        this.topRight = topRight;
        this.bottomRight = bottomRight;
        this.bottomLeft = bottomLeft;

    }

    /**
     * Corners where all values are the same.
     */
    public static inline function all<T>(value:T):CornersOf<T> {

        return new CornersOf<T>(value, value, value, value);

    }

    /**
     * Returns new corners with `f` applied to each value.
     */
    public inline function map<U>(f:(T) -> U):CornersOf<U> {

        return new CornersOf<U>(f(topLeft), f(topRight), f(bottomRight), f(bottomLeft));

    }

    /**
     * Returns numeric corners with `f` applied to each value.
     */
    public inline function mapToCorners(f:(T) -> Float):Corners {

        return new Corners(f(topLeft), f(topRight), f(bottomRight), f(bottomLeft));

    }

    /**
     * Structural equality. `eq` compares two values (default: `==`).
     */
    public function equals(other:CornersOf<T>, ?eq:(T, T) -> Bool):Bool {

        if (other == null) return false;
        if (eq == null) {
            return topLeft == other.topLeft && topRight == other.topRight
                && bottomRight == other.bottomRight && bottomLeft == other.bottomLeft;
        }
        return eq(topLeft, other.topLeft) && eq(topRight, other.topRight)
            && eq(bottomRight, other.bottomRight) && eq(bottomLeft, other.bottomLeft);

    }

    public function toString():String {

        return 'Corners(topLeft: $topLeft, topRight: $topRight, bottomRight: $bottomRight, bottomLeft: $bottomLeft)';

    }

}

// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Generic version of `Point`, for non numeric coordinates.
 *
 * Immutable: every operation returns a new instance.
 */
class PointOf<T> {

    /**
     * The x coordinate of the point.
     */
    public final x:T;

    /**
     * The y coordinate of the point.
     */
    public final y:T;

    public inline function new(x:T, y:T) {

        this.x = x;
        this.y = y;

    }

    /**
     * Returns a new point with `f` applied to both coordinates.
     */
    public inline function map<U>(f:(T) -> U):PointOf<U> {

        return new PointOf<U>(f(x), f(y));

    }

    /**
     * Returns a numeric point with `f` applied to both coordinates.
     */
    public inline function mapToPoint(f:(T) -> Float):Point {

        return new Point(f(x), f(y));

    }

    /**
     * Returns the coordinate along the given axis (Rust trait `Along`).
     */
    public inline function along(axis:Axis):T {

        return axis == Horizontal ? x : y;

    }

    /**
     * Returns a new point with `f` applied to the coordinate along the given axis (Rust trait `Along`).
     */
    public inline function applyAlong(axis:Axis, f:(T) -> T):PointOf<T> {

        return axis == Horizontal ? new PointOf<T>(f(x), y) : new PointOf<T>(x, f(y));

    }

    /**
     * Structural equality. `eq` compares two values (default: `==`).
     */
    public function equals(other:PointOf<T>, ?eq:(T, T) -> Bool):Bool {

        if (other == null) return false;
        if (eq == null) return x == other.x && y == other.y;
        return eq(x, other.x) && eq(y, other.y);

    }

    public function toString():String {

        return '($x, $y)';

    }

}

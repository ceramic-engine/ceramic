// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * A location in a 2D cartesian space.
 *
 * Stands for Rust's `Point<Pixels>`, `Point<ScaledPixels>`, `Point<DevicePixels>`
 * and `Point<f32>`. Use `PointOf<T>` for non numeric coordinates.
 *
 * Immutable: every operation returns a new instance.
 */
class Point {

    /**
     * The x coordinate of the point.
     */
    public final x:Float;

    /**
     * The y coordinate of the point.
     */
    public final y:Float;

    public inline function new(x:Float = 0, y:Float = 0) {

        this.x = x;
        this.y = y;

    }

    /**
     * Returns a new point with `f` applied to both coordinates.
     */
    public inline function map(f:(Float) -> Float):Point {

        return new Point(f(x), f(y));

    }

    /**
     * Returns a generic point with `f` applied to both coordinates.
     */
    public inline function mapOf<U>(f:(Float) -> U):PointOf<U> {

        return new PointOf<U>(f(x), f(y));

    }

    /**
     * Returns the coordinate along the given axis (Rust trait `Along`).
     */
    public inline function along(axis:Axis):Float {

        return axis == Horizontal ? x : y;

    }

    /**
     * Returns a new point with `f` applied to the coordinate along the given axis (Rust trait `Along`).
     */
    public inline function applyAlong(axis:Axis, f:(Float) -> Float):Point {

        return axis == Horizontal ? new Point(f(x), y) : new Point(x, f(y));

    }

    /**
     * Scales the point by a given factor, typically the display scale factor
     * (`Point<Pixels>` to `Point<ScaledPixels>`).
     */
    public inline function scale(factor:Float):Point {

        return new Point(x * factor, y * factor);

    }

    /**
     * Euclidean distance from the origin (0, 0) to this point.
     */
    public inline function magnitude():Float {

        return Math.sqrt(x * x + y * y);

    }

    /**
     * Position of this point, relative to the given origin.
     */
    public inline function relativeTo(origin:Point):Point {

        return new Point(x - origin.x, y - origin.y);

    }

    /**
     * Rust `Point + Point`.
     */
    public inline function add(other:Point):Point {

        return new Point(x + other.x, y + other.y);

    }

    /**
     * Rust `Point - Point`.
     */
    public inline function sub(other:Point):Point {

        return new Point(x - other.x, y - other.y);

    }

    /**
     * Rust `Point * scalar`.
     */
    public inline function mul(rhs:Float):Point {

        return new Point(x * rhs, y * rhs);

    }

    /**
     * Rust `Point / scalar`.
     */
    public inline function div(rhs:Float):Point {

        return new Point(x / rhs, y / rhs);

    }

    /**
     * Rust `-Point`.
     */
    public inline function neg():Point {

        return new Point(-x, -y);

    }

    /**
     * Returns a new point with the maximum values of each dimension from `this` and `other`.
     */
    public inline function max(other:Point):Point {

        return new Point(
            // `Pixels` compare with `f32::total_cmp` in GPUI: -0 < +0
            MathUtil.totalLess(other.x, x) ? x : other.x,
            MathUtil.totalLess(other.y, y) ? y : other.y
        );

    }

    /**
     * Returns a new point with the minimum values of each dimension from `this` and `other`.
     */
    public inline function min(other:Point):Point {

        return new Point(
            !MathUtil.totalLess(other.x, x) ? x : other.x,
            !MathUtil.totalLess(other.y, y) ? y : other.y
        );

    }

    /**
     * Clamps the point between `min` and `max`.
     */
    public inline function clamp(min:Point, max:Point):Point {

        return this.max(min).min(max);

    }

    /**
     * Rounds both coordinates (Rust `f32::round`: half-way cases away from zero).
     */
    public inline function round():Point {

        return new Point(MathUtil.round(x), MathUtil.round(y));

    }

    /**
     * Floors both coordinates.
     */
    public inline function floor():Point {

        return new Point(Math.ffloor(x), Math.ffloor(y));

    }

    /**
     * Ceils both coordinates.
     */
    public inline function ceil():Point {

        return new Point(Math.fceil(x), Math.fceil(y));

    }

    /**
     * Converts a logical point to device pixels (whole values).
     */
    public inline function toDevicePixels(scaleFactor:Float):Point {

        return new Point(
            MathUtil.toI32(MathUtil.round(x * scaleFactor)),
            MathUtil.toI32(MathUtil.round(y * scaleFactor))
        );

    }

    /**
     * Converts a device point to logical pixels.
     */
    public inline function toPixels(scaleFactor:Float):Point {

        return new Point(x / scaleFactor, y / scaleFactor);

    }

    /**
     * Converts to a size (`From<Point<T>> for Size<T>`).
     */
    public inline function toSize():Size {

        return new Size(x, y);

    }

    /**
     * Whether both coordinates are zero (Rust trait `IsZero`).
     */
    public inline function isZero():Bool {

        return x == 0 && y == 0;

    }

    /**
     * Structural equality.
     */
    public inline function equals(other:Point):Bool {

        return other != null && x == other.x && y == other.y;

    }

    public function toString():String {

        return '($x, $y)';

    }

}

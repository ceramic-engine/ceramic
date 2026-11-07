// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * A two-dimensional size with width and height.
 *
 * Stands for Rust's `Size<Pixels>`, `Size<ScaledPixels>`, `Size<DevicePixels>`
 * and `Size<f32>`. Use `SizeOf<T>` for non numeric values (`Size<Length>`...).
 *
 * Immutable: every operation returns a new instance.
 */
class Size {

    /**
     * The width component of the size.
     */
    public final width:Float;

    /**
     * The height component of the size.
     */
    public final height:Float;

    public inline function new(width:Float = 0, height:Float = 0) {

        this.width = width;
        this.height = height;

    }

    /**
     * Returns a new size with `f` applied to the width and height.
     */
    public inline function map(f:(Float) -> Float):Size {

        return new Size(f(width), f(height));

    }

    /**
     * Returns a generic size with `f` applied to the width and height.
     */
    public inline function mapOf<U>(f:(Float) -> U):SizeOf<U> {

        return new SizeOf<U>(f(width), f(height));

    }

    /**
     * The center point of the size.
     */
    public inline function center():Point {

        return new Point(width / 2.0, height / 2.0);

    }

    /**
     * Scales the size by a given factor (`Size<Pixels>` to `Size<ScaledPixels>`).
     */
    public inline function scale(factor:Float):Size {

        return new Size(width * factor, height * factor);

    }

    /**
     * Returns the value along the given axis (Rust trait `Along`).
     */
    public inline function along(axis:Axis):Float {

        return axis == Horizontal ? width : height;

    }

    /**
     * Returns a new size with `f` applied to the value along the given axis (Rust trait `Along`).
     */
    public inline function applyAlong(axis:Axis, f:(Float) -> Float):Size {

        return axis == Horizontal ? new Size(f(width), height) : new Size(width, f(height));

    }

    /**
     * Returns a new size with the maximum width and height from `this` and `other`.
     */
    public inline function max(other:Size):Size {

        return new Size(
            // `Pixels` compare with `f32::total_cmp` in GPUI: -0 < +0
            !MathUtil.totalLess(width, other.width) ? width : other.width,
            !MathUtil.totalLess(height, other.height) ? height : other.height
        );

    }

    /**
     * Returns a new size with the minimum width and height from `this` and `other`.
     */
    public inline function min(other:Size):Size {

        return new Size(
            !MathUtil.totalLess(width, other.width) ? other.width : width,
            !MathUtil.totalLess(height, other.height) ? other.height : height
        );

    }

    /**
     * Rust `Size + Size`.
     */
    public inline function add(other:Size):Size {

        return new Size(width + other.width, height + other.height);

    }

    /**
     * Rust `Size - Size`.
     */
    public inline function sub(other:Size):Size {

        return new Size(width - other.width, height - other.height);

    }

    /**
     * Rust `Size * scalar`.
     */
    public inline function mul(rhs:Float):Size {

        return new Size(width * rhs, height * rhs);

    }

    /**
     * Rust `Size / scalar`.
     */
    public inline function div(rhs:Float):Size {

        return new Size(width / rhs, height / rhs);

    }

    /**
     * Rust `-Size`.
     */
    public inline function neg():Size {

        return new Size(-width, -height);

    }

    /**
     * Converts the size from physical to logical pixels (`Size<DevicePixels>::to_pixels`).
     */
    public inline function toPixels(scaleFactor:Float):Size {

        return new Size(width / scaleFactor, height / scaleFactor);

    }

    /**
     * Converts the size from logical to physical pixels, as whole values
     * (`Size<Pixels>::to_device_pixels`).
     */
    public inline function toDevicePixels(scaleFactor:Float):Size {

        return new Size(
            MathUtil.toI32(MathUtil.round(width * scaleFactor)),
            MathUtil.toI32(MathUtil.round(height * scaleFactor))
        );

    }

    /**
     * Converts to a point (`From<Size<T>> for Point<T>`).
     */
    public inline function toPoint():Point {

        return new Point(width, height);

    }

    /**
     * Converts pixel values to a `SizeOf<DefiniteLength>` (`From<Size<Pixels>> for Size<DefiniteLength>`).
     */
    public inline function toDefiniteLength():SizeOf<DefiniteLength> {

        return new SizeOf<DefiniteLength>(
            DefiniteLength.Absolute(AbsoluteLength.Pixels(width)),
            DefiniteLength.Absolute(AbsoluteLength.Pixels(height))
        );

    }

    /**
     * Converts pixel values to a `SizeOf<AbsoluteLength>` (`From<Size<Pixels>> for Size<AbsoluteLength>`).
     */
    public inline function toAbsoluteLength():SizeOf<AbsoluteLength> {

        return new SizeOf<AbsoluteLength>(
            AbsoluteLength.Pixels(width),
            AbsoluteLength.Pixels(height)
        );

    }

    /**
     * Whether the width or the height is zero (Rust trait `IsZero`).
     */
    public inline function isZero():Bool {

        return width == 0 || height == 0;

    }

    /**
     * Structural equality.
     */
    public inline function equals(other:Size):Bool {

        return other != null && width == other.width && height == other.height;

    }

    public function toString():String {

        return '$width × $height';

    }

}

// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * Pixels scaled by the device scale factor: logical `Pixels` multiplied
 * by the window scale factor, before rounding to `DevicePixels`.
 */
abstract ScaledPixels(Float) from Float to Float {

    public inline function new(value:Float) {

        this = value;

    }

    @:op(A + B) inline function add(rhs:ScaledPixels):ScaledPixels {

        return this + (rhs:Float);

    }

    @:op(A - B) inline function sub(rhs:ScaledPixels):ScaledPixels {

        return this - (rhs:Float);

    }

    @:op(A * B) inline function mul(rhs:Float):ScaledPixels {

        return this * rhs;

    }

    @:op(A / B) inline function div(rhs:Float):ScaledPixels {

        return this / rhs;

    }

    @:op(A % B) inline function rem(rhs:Float):ScaledPixels {

        return this % rhs;

    }

    @:op(-A) inline function neg():ScaledPixels {

        return -this;

    }

    @:op(A < B) static inline function lt(a:ScaledPixels, b:ScaledPixels):Bool {

        return (a:Float) < (b:Float);

    }

    @:op(A <= B) static inline function lte(a:ScaledPixels, b:ScaledPixels):Bool {

        return (a:Float) <= (b:Float);

    }

    @:op(A > B) static inline function gt(a:ScaledPixels, b:ScaledPixels):Bool {

        return (a:Float) > (b:Float);

    }

    @:op(A >= B) static inline function gte(a:ScaledPixels, b:ScaledPixels):Bool {

        return (a:Float) >= (b:Float);

    }

    /**
     * Returns the raw value.
     */
    public inline function asF32():Float {

        return this;

    }

    /**
     * Floors the value to the nearest whole number.
     */
    public inline function floor():ScaledPixels {

        return Math.ffloor(this);

    }

    /**
     * Rounds the value to the nearest whole number (half-way cases away from zero).
     */
    public inline function round():ScaledPixels {

        return MathUtil.round(this);

    }

    /**
     * Returns the ceiling of the value.
     */
    public inline function ceil():ScaledPixels {

        return Math.fceil(this);

    }

    /**
     * Returns the greater of the two values.
     */
    public inline function max(other:ScaledPixels):ScaledPixels {

        return this >= (other:Float) ? this : other;

    }

    /**
     * Returns the lesser of the two values.
     */
    public inline function min(other:ScaledPixels):ScaledPixels {

        return this <= (other:Float) ? this : other;

    }

    /**
     * Converts to device pixels, rounding up (`From<ScaledPixels> for DevicePixels`).
     */
    public inline function toDevicePixels():DevicePixels {

        return MathUtil.toI32(Math.fceil(this));

    }

    /**
     * Half of this value (Rust trait `Half`).
     */
    public inline function half():ScaledPixels {

        return this / 2.0;

    }

    /**
     * Whether this value is zero (Rust trait `IsZero`).
     */
    public inline function isZero():Bool {

        return this == 0.0;

    }

    public inline function toString():String {

        return this + 'px (scaled)';

    }

}

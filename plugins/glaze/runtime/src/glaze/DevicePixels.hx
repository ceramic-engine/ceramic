// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * Physical pixels on the display.
 *
 * Note: the geometry classes (`Point`, `Size`, `Bounds`...) store device
 * pixels as whole `Float` values. This abstract is used for single values.
 */
abstract DevicePixels(Int) from Int to Int {

    public inline function new(value:Int) {

        this = value;

    }

    @:op(A + B) inline function add(rhs:DevicePixels):DevicePixels {

        return this + (rhs:Int);

    }

    @:op(A - B) inline function sub(rhs:DevicePixels):DevicePixels {

        return this - (rhs:Int);

    }

    /**
     * Integer division, truncated toward zero like Rust's `i32` division.
     */
    @:op(A / B) inline function div(rhs:Int):DevicePixels {

        return Std.int(this / rhs);

    }

    @:op(A < B) static inline function lt(a:DevicePixels, b:DevicePixels):Bool {

        return (a:Int) < (b:Int);

    }

    @:op(A <= B) static inline function lte(a:DevicePixels, b:DevicePixels):Bool {

        return (a:Int) <= (b:Int);

    }

    @:op(A > B) static inline function gt(a:DevicePixels, b:DevicePixels):Bool {

        return (a:Int) > (b:Int);

    }

    @:op(A >= B) static inline function gte(a:DevicePixels, b:DevicePixels):Bool {

        return (a:Int) >= (b:Int);

    }

    /**
     * Number of bytes needed to store this many pixels with the given
     * number of bytes per pixel.
     */
    public inline function toBytes(bytesPerPixel:Int):Int {

        return this * bytesPerPixel;

    }

    /**
     * Converts to `ScaledPixels` (`From<DevicePixels> for ScaledPixels`).
     */
    public inline function toScaledPixels():ScaledPixels {

        return (this:Float);

    }

    /**
     * Half of this value, truncated (Rust trait `Half`).
     */
    public inline function half():DevicePixels {

        return Std.int(this / 2);

    }

    /**
     * Whether this value is zero (Rust trait `IsZero`).
     */
    public inline function isZero():Bool {

        return this == 0;

    }

    public inline function toString():String {

        return this + ' px (device)';

    }

}

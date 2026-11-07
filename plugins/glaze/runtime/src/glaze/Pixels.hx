// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * A length in logical pixels, the base unit of measurement in GPUI.
 *
 * Logical pixels are independent of the display density: they are converted
 * to physical pixels with the window scale factor (see `scale()`).
 */
abstract Pixels(Float) from Float to Float {

    /**
     * Zero pixels.
     */
    public static inline final ZERO:Pixels = 0.0;

    /**
     * The maximum value that can be represented by `Pixels` (`f32::MAX`).
     */
    public static inline final MAX:Pixels = MathUtil.F32_MAX;

    /**
     * The minimum value that can be represented by `Pixels` (`f32::MIN`).
     */
    public static inline final MIN:Pixels = -MathUtil.F32_MAX;

    public inline function new(value:Float) {

        this = value;

    }

    @:op(A + B) inline function add(rhs:Pixels):Pixels {

        return this + (rhs:Float);

    }

    @:op(A - B) inline function sub(rhs:Pixels):Pixels {

        return this - (rhs:Float);

    }

    @:op(A * B) inline function mul(rhs:Float):Pixels {

        return this * rhs;

    }

    /**
     * Note: in Rust, `Pixels / Pixels` gives a bare `f32`. Here both divisions
     * give `Pixels`, which converts implicitly to `Float`.
     */
    @:op(A / B) inline function div(rhs:Float):Pixels {

        return this / rhs;

    }

    @:op(A % B) inline function rem(rhs:Float):Pixels {

        return this % rhs;

    }

    @:op(-A) inline function neg():Pixels {

        return -this;

    }

    @:op(A < B) static inline function lt(a:Pixels, b:Pixels):Bool {

        return (a:Float) < (b:Float);

    }

    @:op(A <= B) static inline function lte(a:Pixels, b:Pixels):Bool {

        return (a:Float) <= (b:Float);

    }

    @:op(A > B) static inline function gt(a:Pixels, b:Pixels):Bool {

        return (a:Float) > (b:Float);

    }

    @:op(A >= B) static inline function gte(a:Pixels, b:Pixels):Bool {

        return (a:Float) >= (b:Float);

    }

    /**
     * Returns the raw value of this `Pixels`.
     */
    public inline function asF32():Float {

        return this;

    }

    /**
     * Returns the raw value of this `Pixels`.
     */
    public inline function toF64():Float {

        return this;

    }

    /**
     * Floors the value to the nearest whole number.
     */
    public inline function floor():Pixels {

        return Math.ffloor(this);

    }

    /**
     * Rounds the value to the nearest whole number (half-way cases away from zero).
     */
    public inline function round():Pixels {

        return MathUtil.round(this);

    }

    /**
     * Returns the ceiling of the value.
     */
    public inline function ceil():Pixels {

        return Math.fceil(this);

    }

    /**
     * Scales the value by a given factor, producing `ScaledPixels`.
     */
    public inline function scale(factor:Float):ScaledPixels {

        return this * factor;

    }

    /**
     * Raises the value to a given power.
     */
    public inline function pow(exponent:Float):Pixels {

        return Math.pow(this, exponent);

    }

    /**
     * Returns the absolute value.
     */
    public inline function abs():Pixels {

        return Math.abs(this);

    }

    /**
     * Returns the sign of the value (`1.0`, `-1.0` or NaN).
     */
    public inline function signum():Float {

        return MathUtil.signum(this);

    }

    /**
     * Returns the greater of the two values (`Ord::max`).
     */
    public inline function max(other:Pixels):Pixels {

        // Ord::max returns `other` unless `self` is greater (total order: -0 < +0)
        return MathUtil.totalLess(other, this) ? this : other;

    }

    /**
     * Returns the lesser of the two values (`Ord::min`).
     */
    public inline function min(other:Pixels):Pixels {

        // Ord::min returns `self` unless `other` is less (total order: -0 < +0)
        return MathUtil.totalLess(other, this) ? other : this;

    }

    /**
     * Restricts the value to the given range (`Ord::clamp`).
     */
    public inline function clamp(min:Pixels, max:Pixels):Pixels {

        // Total order like `f32::total_cmp`: -0 < +0
        return MathUtil.totalLess(this, min) ? min : (MathUtil.totalLess(max, this) ? max : this);

    }

    /**
     * Half of this value (Rust trait `Half`).
     */
    public inline function half():Pixels {

        return this / 2.0;

    }

    /**
     * Whether this value is zero (Rust trait `IsZero`).
     */
    public inline function isZero():Bool {

        return this == 0.0;

    }

    /**
     * Converts to an `AbsoluteLength` (`From<Pixels> for AbsoluteLength`).
     */
    public inline function toAbsoluteLength():AbsoluteLength {

        return AbsoluteLength.Pixels(this);

    }

    /**
     * Converts to a `DefiniteLength` (`From<Pixels> for DefiniteLength`).
     */
    public inline function toDefiniteLength():DefiniteLength {

        return DefiniteLength.Absolute(AbsoluteLength.Pixels(this));

    }

    /**
     * Converts to a `Length` (`From<Pixels> for Length`).
     */
    public inline function toLength():Length {

        return Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(this)));

    }

    /**
     * Sums the given values (`std::iter::Sum`).
     */
    public static function sum(values:Array<Pixels>):Pixels {

        var result = 0.0;
        for (value in values) {
            result += (value:Float);
        }
        return result;

    }

    /**
     * Parses a string like `"12.5px"` (`TryFrom<&str> for Pixels`).
     * Throws when the string is not valid.
     */
    public static function parse(value:String):Pixels {

        final result = tryParse(value);
        if (result == null) {
            throw 'invalid Pixels \'$value\', expected \'px\' suffix';
        }
        return result;

    }

    /**
     * Same as `parse()` but returns `null` instead of throwing.
     */
    public static function tryParse(value:String):Null<Pixels> {

        if (value == null || !StringTools.endsWith(value, 'px')) return null;
        final number = MathUtil.parseFloat(value.substr(0, value.length - 2));
        return number != null ? (number:Pixels) : null;

    }

    public inline function toString():String {

        return this + 'px';

    }

}

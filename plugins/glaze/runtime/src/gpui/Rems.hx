// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * A length in rems, relative to the window's rem size (its base font size).
 */
abstract Rems(Float) from Float to Float {

    /**
     * A length of zero.
     */
    public static inline final ZERO:Rems = 0.0;

    public inline function new(value:Float) {

        this = value;

    }

    @:op(A + B) inline function add(rhs:Rems):Rems {

        return this + (rhs:Float);

    }

    @:op(A - B) inline function sub(rhs:Rems):Rems {

        return this - (rhs:Float);

    }

    /**
     * Note: Rust also has `Rems * Pixels -> Pixels`. Use `toPixels()` for that.
     */
    @:op(A * B) inline function mul(rhs:Float):Rems {

        return this * rhs;

    }

    @:op(A / B) inline function div(rhs:Float):Rems {

        return this / rhs;

    }

    @:op(-A) inline function neg():Rems {

        return -this;

    }

    /**
     * Converts this value to pixels.
     */
    public inline function toPixels(remSize:Pixels):Pixels {

        return this * (remSize:Float);

    }

    /**
     * Half of this value (Rust trait `Half`).
     */
    public inline function half():Rems {

        return this / 2.0;

    }

    /**
     * Whether this value is zero (Rust trait `IsZero`).
     */
    public inline function isZero():Bool {

        return this == 0.0;

    }

    /**
     * Converts to an `AbsoluteLength` (`From<Rems> for AbsoluteLength`).
     */
    public inline function toAbsoluteLength():AbsoluteLength {

        return AbsoluteLength.Rems(this);

    }

    /**
     * Converts to a `DefiniteLength` (`From<Rems> for DefiniteLength`).
     */
    public inline function toDefiniteLength():DefiniteLength {

        return DefiniteLength.Absolute(AbsoluteLength.Rems(this));

    }

    /**
     * Converts to a `Length` (`From<Rems> for Length`).
     */
    public inline function toLength():Length {

        return Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Rems(this)));

    }

    /**
     * Parses a string like `"1.5rem"` (`TryFrom<&str> for Rems`).
     * Throws when the string is not valid.
     */
    public static function parse(value:String):Rems {

        final result = tryParse(value);
        if (result == null) {
            throw 'invalid Rems \'$value\', expected \'rem\' suffix';
        }
        return result;

    }

    /**
     * Same as `parse()` but returns `null` instead of throwing.
     */
    public static function tryParse(value:String):Null<Rems> {

        if (value == null || !StringTools.endsWith(value, 'rem')) return null;
        final number = MathUtil.parseFloat(value.substr(0, value.length - 3));
        return number != null ? (number:Rems) : null;

    }

    public inline function toString():String {

        return this + 'rem';

    }

}

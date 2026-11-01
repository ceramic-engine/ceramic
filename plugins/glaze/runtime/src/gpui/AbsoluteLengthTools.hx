// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * Methods of `AbsoluteLength`.
 */
class AbsoluteLengthTools {

    /**
     * The default value: zero pixels.
     */
    public static inline function defaultValue():AbsoluteLength {

        return AbsoluteLength.Pixels(0.0);

    }

    /**
     * Checks if the absolute length is zero.
     */
    public static function isZero(self:AbsoluteLength):Bool {

        return switch self {
            case Pixels(px): (px:Float) == 0.0;
            case Rems(rems): (rems:Float) == 0.0;
        }

    }

    /**
     * Converts to `Pixels` based on a given `remSize`.
     */
    public static function toPixels(self:AbsoluteLength, remSize:gpui.Pixels):gpui.Pixels {

        return switch self {
            case Pixels(pixels): pixels;
            case Rems(rems): rems.toPixels(remSize);
        }

    }

    /**
     * Converts to `Rems` based on a given `remSize`.
     */
    public static function toRems(self:AbsoluteLength, remSize:gpui.Pixels):gpui.Rems {

        return switch self {
            case Pixels(pixels): (pixels:Float) / (remSize:Float);
            case Rems(rems): rems;
        }

    }

    /**
     * Negates the length (Rust `Neg`).
     */
    public static function neg(self:AbsoluteLength):AbsoluteLength {

        return switch self {
            case Pixels(pixels): AbsoluteLength.Pixels(-pixels);
            case Rems(rems): AbsoluteLength.Rems(-rems);
        }

    }

    /**
     * Converts to a `DefiniteLength`.
     */
    public static inline function toDefiniteLength(self:AbsoluteLength):DefiniteLength {

        return DefiniteLength.Absolute(self);

    }

    /**
     * Converts to a `Length`.
     */
    public static inline function toLength(self:AbsoluteLength):Length {

        return Length.Definite(DefiniteLength.Absolute(self));

    }

    /**
     * Structural equality.
     */
    public static function equals(self:AbsoluteLength, other:AbsoluteLength):Bool {

        return switch [self, other] {
            case [Pixels(a), Pixels(b)]: (a:Float) == (b:Float);
            case [Rems(a), Rems(b)]: (a:Float) == (b:Float);
            case _: false;
        }

    }

    /**
     * Formats the length like `"12px"` or `"1.5rem"`.
     */
    public static function toString(self:AbsoluteLength):String {

        return switch self {
            case Pixels(pixels): pixels.toString();
            case Rems(rems): rems.toString();
        }

    }

    /**
     * Parses a number with a `px` or `rem` suffix (`TryFrom<&str>`).
     * Throws when the string is not valid.
     */
    public static function parse(value:String):AbsoluteLength {

        final result = tryParse(value);
        if (result == null) {
            throw 'invalid AbsoluteLength \'$value\', expected number with \'px\' or \'rem\' suffix';
        }
        return result;

    }

    /**
     * Same as `parse()` but returns `null` instead of throwing.
     */
    public static function tryParse(value:String):Null<AbsoluteLength> {

        final pixels = gpui.Pixels.tryParse(value);
        if (pixels != null) return AbsoluteLength.Pixels(pixels);
        final rems = gpui.Rems.tryParse(value);
        if (rems != null) return AbsoluteLength.Rems(rems);
        return null;

    }

}

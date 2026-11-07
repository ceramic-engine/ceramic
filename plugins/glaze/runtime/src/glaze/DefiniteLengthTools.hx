// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

import glaze.util.MathUtil;

/**
 * Methods of `DefiniteLength`.
 */
class DefiniteLengthTools {

    /**
     * The default value: zero pixels.
     */
    public static inline function defaultValue():DefiniteLength {

        return DefiniteLength.Absolute(AbsoluteLength.Pixels(0.0));

    }

    /**
     * Converts to `Pixels` based on a given `baseSize` (used by fractions)
     * and `remSize`.
     */
    public static function toPixels(self:DefiniteLength, baseSize:AbsoluteLength, remSize:Pixels):Pixels {

        return switch self {
            case Absolute(size): size.toPixels(remSize);
            case Fraction(fraction): switch baseSize {
                case Pixels(px): px * fraction;
                case Rems(rems): rems.toPixels(remSize) * fraction;
            }
        }

    }

    /**
     * `toPixels(AbsoluteLength.Pixels(basePixels), remSize)` without the
     * `AbsoluteLength` (an enum value allocated per call).
     */
    public static function toPixelsOf(self:DefiniteLength, basePixels:Pixels, remSize:Pixels):Pixels {

        return switch self {
            case Absolute(size): size.toPixels(remSize);
            case Fraction(fraction): basePixels * fraction;
        }

    }

    /**
     * Checks if the length is zero (Rust trait `IsZero`).
     */
    public static function isZero(self:DefiniteLength):Bool {

        return switch self {
            case Absolute(length): length.isZero();
            case Fraction(fraction): fraction == 0.0;
        }

    }

    /**
     * Negates the length (Rust `Neg`).
     */
    public static function neg(self:DefiniteLength):DefiniteLength {

        return switch self {
            case Absolute(length): DefiniteLength.Absolute(length.neg());
            case Fraction(fraction): DefiniteLength.Fraction(-fraction);
        }

    }

    /**
     * Converts to a `Length`.
     */
    public static inline function toLength(self:DefiniteLength):Length {

        return Length.Definite(self);

    }

    /**
     * Structural equality.
     */
    public static function equals(self:DefiniteLength, other:DefiniteLength):Bool {

        return switch [self, other] {
            case [Absolute(a), Absolute(b)]: a.equals(b);
            case [Fraction(a), Fraction(b)]: a == b;
            case _: false;
        }

    }

    /**
     * Formats the length like `"12px"`, `"1.5rem"` or `"50%"`.
     */
    public static function toString(self:DefiniteLength):String {

        return switch self {
            case Absolute(length): length.toString();
            case Fraction(fraction): MathUtil.toI32(fraction * 100.0) + '%';
        }

    }

    /**
     * Parses a number with a `px`, `rem` or `%` suffix (`TryFrom<&str>`).
     * Throws when the string is not valid.
     */
    public static function parse(value:String):DefiniteLength {

        final result = tryParse(value);
        if (result == null) {
            throw 'invalid DefiniteLength \'$value\', expected number with \'px\', \'rem\', or \'%\' suffix';
        }
        return result;

    }

    /**
     * Same as `parse()` but returns `null` instead of throwing.
     */
    public static function tryParse(value:String):Null<DefiniteLength> {

        if (value == null) return null;
        if (StringTools.endsWith(value, '%')) {
            final percentage = MathUtil.parseFloat(value.substr(0, value.length - 1));
            return percentage != null ? DefiniteLength.Fraction(percentage / 100.0) : null;
        }
        final absolute = AbsoluteLengthTools.tryParse(value);
        return absolute != null ? DefiniteLength.Absolute(absolute) : null;

    }

}

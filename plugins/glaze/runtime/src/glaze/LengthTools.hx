// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Methods of `Length`.
 */
class LengthTools {

    /**
     * The default value: zero pixels.
     */
    public static inline function defaultValue():Length {

        return Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(0.0)));

    }

    /**
     * Checks if the length is zero (Rust trait `IsZero`). `Auto` is never zero.
     */
    public static function isZero(self:Length):Bool {

        return switch self {
            case Definite(length): length.isZero();
            case Auto: false;
        }

    }

    /**
     * Structural equality.
     */
    public static function equals(self:Length, other:Length):Bool {

        return switch [self, other] {
            case [Definite(a), Definite(b)]: a.equals(b);
            case [Auto, Auto]: true;
            case _: false;
        }

    }

    /**
     * Formats the length like `"12px"`, `"50%"` or `"auto"`.
     */
    public static function toString(self:Length):String {

        return switch self {
            case Definite(length): length.toString();
            case Auto: 'auto';
        }

    }

    /**
     * Parses `"auto"` or a number with a `px`, `rem` or `%` suffix (`TryFrom<&str>`).
     * Throws when the string is not valid.
     */
    public static function parse(value:String):Length {

        final result = tryParse(value);
        if (result == null) {
            throw 'invalid Length \'$value\', expected \'auto\' or number with \'px\', \'rem\', or \'%\' suffix';
        }
        return result;

    }

    /**
     * Same as `parse()` but returns `null` instead of throwing.
     */
    public static function tryParse(value:String):Null<Length> {

        if (value == 'auto') return Length.Auto;
        final definite = DefiniteLengthTools.tryParse(value);
        return definite != null ? Length.Definite(definite) : null;

    }

}

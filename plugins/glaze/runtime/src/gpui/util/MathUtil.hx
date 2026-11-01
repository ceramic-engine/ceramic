package gpui.util;

/**
 * Float helpers that reproduce the semantics of Rust's `f32` methods
 * where they differ from Haxe's `Math`.
 */
class MathUtil {

    /**
     * Largest finite `f32` value (`f32::MAX`).
     */
    public static inline final F32_MAX:Float = 3.4028234663852886e38;

    /**
     * Rounds half-way cases away from zero, like Rust's `f32::round`
     * (Haxe's `Math.fround` rounds them toward positive infinity).
     */
    public static function round(value:Float):Float {

        if (value < 0) {
            return -roundPositive(-value);
        }
        return roundPositive(value);

    }

    static inline function roundPositive(value:Float):Float {

        var result = Math.ffloor(value);
        if (value - result >= 0.5) {
            result += 1;
        }
        return result;

    }

    /**
     * Rust's `f32::clamp`: NaN stays NaN.
     */
    public static inline function clamp(value:Float, min:Float, max:Float):Float {

        return value < min ? min : (value > max ? max : value);

    }

    /**
     * Rust's `f32::rem_euclid`: the result is always positive or zero.
     */
    public static inline function remEuclid(a:Float, b:Float):Float {

        final r = a % b;
        return r < 0 ? r + Math.abs(b) : r;

    }

    /**
     * Rust's `f32::signum`: `1.0` for positive values and `+0.0`,
     * `-1.0` for negative values and `-0.0`, NaN for NaN.
     */
    public static function signum(value:Float):Float {

        if (Math.isNaN(value)) return value;
        if (value > 0) return 1.0;
        if (value < 0) return -1.0;
        // Zero: check the sign bit through division
        return (1.0 / value) < 0 ? -1.0 : 1.0;

    }

    /**
     * `a < b` under Rust's `f32::total_cmp` ordering (the one of `impl Ord
     * for Pixels`): like `<`, except that `-0.0` is less than `+0.0` and
     * NaN is greater than every number (the sign of NaN is not tracked).
     */
    public static inline function totalLess(a:Float, b:Float):Bool {

        return a < b
            || (a == 0 && b == 0 && 1.0 / a < 0 && 1.0 / b > 0)
            || (b != b && a == a);

    }

    /**
     * Rust's `f32::copysign`: the magnitude of `magnitude` with the sign
     * bit of `sign` (so `-0.0` counts as negative and `+0.0` as positive).
     */
    public static inline function copysign(magnitude:Float, sign:Float):Float {

        final m = Math.abs(magnitude);
        return sign < 0 || (sign == 0 && 1.0 / sign < 0) ? -m : m;

    }

    /**
     * Rust's `f32::max`: when one value is NaN, the other one is returned.
     */
    public static inline function max(a:Float, b:Float):Float {

        return Math.isNaN(a) ? b : (Math.isNaN(b) ? a : (a > b ? a : b));

    }

    /**
     * Rust's `f32::min`: when one value is NaN, the other one is returned.
     */
    public static inline function min(a:Float, b:Float):Float {

        return Math.isNaN(a) ? b : (Math.isNaN(b) ? a : (a < b ? a : b));

    }

    /**
     * Rust's float to integer cast (`value as i32`): truncates toward zero,
     * saturates at the bounds and maps NaN to zero.
     */
    public static function toI32(value:Float):Int {

        if (Math.isNaN(value)) return 0;
        if (value >= 2147483647.0) return 2147483647;
        if (value <= -2147483648.0) return -2147483648;
        return Std.int(value);

    }

    /**
     * Rust's float to `u8` cast (`value as u8`): truncates toward zero
     * and saturates to the `0..=255` range.
     */
    public static function toU8(value:Float):Int {

        if (Math.isNaN(value) || value <= 0) return 0;
        if (value >= 255) return 255;
        return Std.int(value);

    }

    /**
     * Parses a float the way Rust's `str::parse::<f32>` does: the whole
     * string must be a number (no surrounding spaces, no trailing garbage).
     * Returns `null` when the string is not a valid number.
     */
    public static function parseFloat(value:String):Null<Float> {

        if (value == null || value.length == 0) return null;

        final lower = value.toLowerCase();
        var sign = 1.0;
        var body = lower;
        if (body.charCodeAt(0) == '+'.code) {
            body = body.substr(1);
        }
        else if (body.charCodeAt(0) == '-'.code) {
            sign = -1.0;
            body = body.substr(1);
        }

        if (body == 'inf' || body == 'infinity') return sign * Math.POSITIVE_INFINITY;
        if (body == 'nan') return Math.NaN;

        if (!FLOAT_PATTERN.match(body)) return null;

        return sign * Std.parseFloat(body);

    }

    static final FLOAT_PATTERN = ~/^([0-9]+\.?[0-9]*|\.[0-9]+)(e[+-]?[0-9]+)?$/;

}

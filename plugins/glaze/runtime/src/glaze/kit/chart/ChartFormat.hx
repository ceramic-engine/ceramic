// Ported from gpui-kit 0.8.1: the number formatting the charts of crates/component/src/chart do
// with Rust's `format!` (`{}`, `{:.N}` of `f64` and `f32`).
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.chart;

import gpui.SpringMath;

/**
 * Rust's float formatting, as the charts use it for tick labels and tooltip
 * values: `fixed` is `format!("{:.N}")` (exact decimal value, ties to even),
 * `display64` and `display32` are `format!("{}")` of an `f64` and an `f32`
 * (the shortest digits that read back as the same value, never an exponent).
 *
 * Integers beyond 2^53 and values below 1e-17 are written with Haxe's own
 * conversion (the charts never format such values).
 */
class ChartFormat {

    /**
     * Rust `format!("{:.digits$}", value)`.
     */
    public static function fixed(value:Float, digits:Int):String {
        if (Math.isNaN(value)) return 'NaN';
        if (!Math.isFinite(value)) return value > 0 ? 'inf' : '-inf';
        final negative = value < 0 || (value == 0 && 1 / value < 0);
        final abs = Math.abs(value);
        final scale = Math.pow(10, digits);
        // The exact product `abs * scale` as `hi + lo` (Dekker).
        final hi = abs * scale;
        final lo = twoProductError(abs, scale, hi);
        var n = Math.ffloor(hi);
        final d = (hi - n) - 0.5;
        final dir = d != 0 ? (d > 0 ? 1 : -1) : (lo > 0 ? 1 : (lo < 0 ? -1 : 0));
        if (dir > 0 || (dir == 0 && n % 2 != 0)) n += 1;
        var text = integerString(n);
        if (digits > 0) {
            while (text.length < digits + 1) text = '0' + text;
            text = text.substr(0, text.length - digits) + '.' + text.substr(text.length - digits);
        }
        return negative ? '-' + text : text;
    }

    /**
     * Rust `format!("{}", value)` of an `f64`.
     */
    public static function display64(value:Float):String {
        return display(value, false);
    }

    /**
     * Rust `format!("{}", value)` of an `f32`.
     */
    public static function display32(value:Float):String {
        return display(SpringMath.f32(value), true);
    }

    static function display(value:Float, single:Bool):String {
        if (Math.isNaN(value)) return 'NaN';
        if (!Math.isFinite(value)) return value > 0 ? 'inf' : '-inf';
        final negative = value < 0 || (value == 0 && 1 / value < 0);
        final abs = Math.abs(value);
        if (abs == Math.ffloor(abs) && abs < 9007199254740992.) {
            return (negative ? '-' : '') + integerString(abs);
        }
        for (digits in 1...21) {
            final text = fixed(value, digits);
            final back = Std.parseFloat(text);
            if ((single ? SpringMath.f32(back) : back) == value) {
                return text;
            }
        }
        return Std.string(value);
    }

    /** The digits of a whole number below 2^53. */
    static function integerString(value:Float):String {
        if (value < 2147483648.) {
            return Std.string(Std.int(value));
        }
        final digits:Array<Int> = [];
        var rest = value;
        while (rest >= 1) {
            final q = Math.ffloor(rest / 10);
            digits.push(Std.int(rest - q * 10));
            rest = q;
        }
        final buf = new StringBuf();
        var i = digits.length - 1;
        while (i >= 0) {
            buf.add(digits[i]);
            i--;
        }
        return buf.toString();
    }

    /** The rounding error of `p = a * b` (Dekker's product with Veltkamp splits). */
    static function twoProductError(a:Float, b:Float, p:Float):Float {
        final split = 134217729.0;
        final ca = split * a;
        final ah = ca - (ca - a);
        final al = a - ah;
        final cb = split * b;
        final bh = cb - (cb - b);
        final bl = b - bh;
        return ((ah * bh - p) + ah * bl + al * bh) + al * bl;
    }

}

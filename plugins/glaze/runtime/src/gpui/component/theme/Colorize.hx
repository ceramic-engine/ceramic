// Ported from gpui-kit 0.8.1: crates/component/src/theme/color.rs (Colorize for Hsla)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

import gpui.Hsla;
import gpui.Rgba;
import gpui.util.MathUtil;

/**
 * Color helpers on `Hsla`, as a static extension: `using gpui.component.theme.Colorize;`.
 *
 * `opacity` is not repeated here: `Hsla.opacity` already does exactly what
 * the trait method does (the alpha multiplied by the clamped factor).
 */
class Colorize {

    /**
     * Returns a new color with the alpha set to `divisor` (sic: the Rust
     * implementation replaces the alpha).
     */
    public static inline function divide(color:Hsla, divisor:Float):Hsla {

        return new Hsla(color.h, color.s, color.l, divisor);

    }

    /**
     * Return inverted color.
     */
    public static inline function invert(color:Hsla):Hsla {

        return new Hsla(1.0 - color.h, 1.0 - color.s, 1.0 - color.l, color.a);

    }

    /**
     * Return inverted lightness.
     */
    public static inline function invertL(color:Hsla):Hsla {

        return new Hsla(color.h, color.s, 1.0 - color.l, color.a);

    }

    /**
     * Return a new color with the lightness increased by the given factor (0.0 .. 1.0).
     */
    public static inline function lighten(color:Hsla, factor:Float):Hsla {

        final l = color.l * (1.0 + MathUtil.clamp(factor, 0.0, 1.0));
        return new Hsla(color.h, color.s, l, color.a);

    }

    /**
     * Return a new color with the darkness increased by the given factor (0.0 .. 1.0).
     */
    public static inline function darken(color:Hsla, factor:Float):Hsla {

        final l = color.l * (1.0 - MathUtil.clamp(factor, 0.0, 1.0));
        return new Hsla(color.h, color.s, l, color.a);

    }

    /**
     * Return a new color with the same lightness and alpha but the hue and
     * saturation of `newColor`.
     */
    public static inline function apply(color:Hsla, newColor:Hsla):Hsla {

        return new Hsla(newColor.h, newColor.s, color.l, color.a);

    }

    static function lerpHue(a:Float, b:Float, t:Float):Float {

        // In f32 like Rust: for two opposite hues the direction of the
        // interpolation is decided by the rounding of `b - a + 180`.
        final diff = f32(f32(MathUtil.remEuclid(f32(f32(b - a) + 180.0), 360.)) - 180.);
        return MathUtil.remEuclid(a + diff * t, 360.0);

    }

    /**
     * Mix two colors together, the `factor` is a value between 0.0 and 1.0 for first color.
     *
     * Reference:
     * https://github.com/bevyengine/bevy/blob/85eceb022da0326b47ac2b0d9202c9c9f01835bb/crates/bevy_color/src/hsla.rs#L112
     */
    public static function mix(color:Hsla, other:Hsla, factor:Float):Hsla {

        final factor = MathUtil.clamp(factor, 0.0, 1.0);
        final inv = 1.0 - factor;

        return new Hsla(
            lerpHue(f32(f32(color.h) * 360.), f32(f32(other.h) * 360.), factor) / 360.,
            color.s * factor + other.s * inv,
            color.l * factor + other.l * inv,
            color.a * factor + other.a * inv
        );

    }

    /**
     * Mix two colors together in Oklab color space, the `factor` is a value
     * between 0.0 and 1.0 for first color.
     *
     * This is similar to CSS `color-mix(in oklab, color1 factor%, color2)`.
     */
    public static function mixOklab(color:Hsla, other:Hsla, factor:Float):Hsla {

        // Computed in f32 at every step, like Rust: the result feeds colors that
        // are compared with gpui-kit's exactly (a hue of 1.0 or 0.0 for a red
        // depends on the sign of a rounding error).
        final factor = f32(MathUtil.clamp(factor, 0.0, 1.0));
        final inv = f32(1.0 - factor);

        // Interpolate alpha first
        final resultAlpha = f32(f32(f32(color.a) * factor) + f32(f32(other.a) * inv));

        // Handle the case where result alpha is zero
        if (resultAlpha == 0.0) {
            return new Hsla(0.0, 0.0, 0.0, 0.0);
        }

        // Convert both colors to RGB, then to Oklab color space
        final lab1 = rgbToOklabF32(toRgbF32(color));
        final lab2 = rgbToOklabF32(toRgbF32(other));

        // Premultiply alpha in Oklab space (this matches CSS color-mix behavior)
        final alpha1 = f32(color.a);
        final alpha2 = f32(other.a);

        // Interpolate premultiplied values, then unpremultiply
        final L = f32(f32(f32(f32(lab1[0] * alpha1) * factor) + f32(f32(lab2[0] * alpha2) * inv)) / resultAlpha);
        final a = f32(f32(f32(f32(lab1[1] * alpha1) * factor) + f32(f32(lab2[1] * alpha2) * inv)) / resultAlpha);
        final b = f32(f32(f32(f32(lab1[2] * alpha1) * factor) + f32(f32(lab2[2] * alpha2) * inv)) / resultAlpha);

        // Convert back to RGB, then to HSLA
        return hslaFromRgbF32(oklabToRgbF32(L, a, b), resultAlpha);

    }

    static inline function sum3(x:Float, y:Float, z:Float):Float {

        return f32(f32(x + y) + z);

    }

    static function toLinearF32(c:Float):Float {

        return c <= f32(0.04045) ? f32(c / f32(12.92)) : f32(Math.pow(f32(f32(c + f32(0.055)) / f32(1.055)), f32(2.4)));

    }

    static function fromLinearF32(c:Float):Float {

        return c <= f32(0.0031308) ? f32(c * f32(12.92)) : f32(f32(f32(1.055) * f32(Math.pow(c, f32(f32(1.0) / f32(2.4))))) - f32(0.055));

    }

    static function cbrtF32(x:Float):Float {

        return f32(x < 0 ? -Math.pow(-x, 1.0 / 3.0) : Math.pow(x, 1.0 / 3.0));

    }

    static inline function m(k:Float, v:Float):Float {

        return f32(f32(k) * v);

    }

    static function rgbToOklabF32(rgb:Rgba):Array<Float> {

        final lr = toLinearF32(rgb.r);
        final lg = toLinearF32(rgb.g);
        final lb = toLinearF32(rgb.b);

        final l = sum3(m(0.4122214708, lr), m(0.5363325363, lg), m(0.0514459929, lb));
        final mm = sum3(m(0.2119034982, lr), m(0.6806995451, lg), m(0.1073969566, lb));
        final s = sum3(m(0.0883024619, lr), m(0.2817188376, lg), m(0.6299787005, lb));

        final l_ = cbrtF32(l);
        final m_ = cbrtF32(mm);
        final s_ = cbrtF32(s);

        return [
            f32(f32(m(0.2104542553, l_) + m(0.7936177850, m_)) - m(0.0040720468, s_)),
            f32(f32(m(1.9779984951, l_) - m(2.4285922050, m_)) + m(0.4505937099, s_)),
            f32(f32(m(0.0259040371, l_) + m(0.7827717662, m_)) - m(0.8086757660, s_))
        ];

    }

    static function oklabToRgbF32(L:Float, a:Float, b:Float):Rgba {

        final l_ = f32(f32(L + m(0.3963377774, a)) + m(0.2158037573, b));
        final m_ = f32(f32(L - m(0.1055613458, a)) - m(0.0638541728, b));
        final s_ = f32(f32(L - m(0.0894841775, a)) - m(1.2914855480, b));

        final l = f32(f32(l_ * l_) * l_);
        final mm = f32(f32(m_ * m_) * m_);
        final s = f32(f32(s_ * s_) * s_);

        final lr = f32(f32(m(4.0767416621, l) - m(3.3077115913, mm)) + m(0.2309699292, s));
        final lg = f32(f32(m(-1.2684380046, l) + m(2.6097574011, mm)) - m(0.3413193965, s));
        final lb = f32(f32(m(-0.0041960863, l) - m(0.7034186147, mm)) + m(1.7076147010, s));

        return new Rgba(
            MathUtil.clamp(fromLinearF32(lr), 0.0, 1.0),
            MathUtil.clamp(fromLinearF32(lg), 0.0, 1.0),
            MathUtil.clamp(fromLinearF32(lb), 0.0, 1.0),
            1.0
        );

    }

    /**
     * GPUI's `Hsla::from(Rgba)` in f32.
     */
    static function hslaFromRgbF32(color:Rgba, alpha:Float):Hsla {

        final r = color.r;
        final g = color.g;
        final b = color.b;
        final max = Math.max(r, Math.max(g, b));
        final min = Math.min(r, Math.min(g, b));
        final delta = f32(max - min);
        final l = f32(f32(max + min) / 2.0);
        final s = if (l == 0.0 || l == 1.0) {
            0.0;
        }
        else if (l < 0.5) {
            f32(delta / f32(2.0 * l));
        }
        else {
            f32(delta / f32(2.0 - f32(2.0 * l)));
        }
        final h = if (delta == 0.0) {
            0.0;
        }
        else if (max == r) {
            final q = f32(f32(g - b) / delta);
            var e = f32(q % 6.0);
            if (e < 0) e = f32(e + 6.0);
            f32(e / 6.0);
        }
        else if (max == g) {
            f32(f32(f32(f32(b - r) / delta) + 2.0) / 6.0);
        }
        else {
            f32(f32(f32(f32(r - g) / delta) + 4.0) / 6.0);
        }
        return new Hsla(h, s, l, alpha);

    }

    /**
     * Change the hue of the color to the given value in range 0.0 .. 1.0.
     */
    public static inline function hue(color:Hsla, hue:Float):Hsla {

        return new Hsla(MathUtil.clamp(hue, 0., 1.), color.s, color.l, color.a);

    }

    /**
     * Change the saturation of the color to the given value in range 0.0 .. 1.0.
     */
    public static inline function saturation(color:Hsla, saturation:Float):Hsla {

        return new Hsla(color.h, MathUtil.clamp(saturation, 0., 1.), color.l, color.a);

    }

    /**
     * Change the lightness of the color to the given value in range 0.0 .. 1.0.
     */
    public static inline function lightness(color:Hsla, lightness:Float):Hsla {

        return new Hsla(color.h, color.s, MathUtil.clamp(lightness, 0., 1.), color.a);

    }

    /**
     * Rounds to the nearest f32 (Rust computes colors in f32).
     */
    static inline function f32(value:Float):Float {

        return haxe.io.FPHelper.i32ToFloat(haxe.io.FPHelper.floatToI32(value));

    }

    static inline function hex2(value:Float):String {

        return StringTools.hex(MathUtil.toU8(f32(value * 255.)), 2);

    }

    /**
     * `Rgba::from(Hsla)` computed with f32 rounding at every step, like Rust:
     * `toHex` truncates the channels, so a channel at `3.9999999` in f64 and
     * `4.0` in f32 would give another digit.
     */
    static function toRgbF32(color:Hsla):Rgba {

        final h = f32(color.h);
        final s = f32(color.s);
        final l = f32(color.l);

        final c = f32(f32(1.0 - Math.abs(f32(f32(2.0 * l) - 1.0))) * s);
        final h6 = f32(h * 6.0);
        final x = f32(c * f32(1.0 - Math.abs(f32(f32(h6 % 2.0) - 1.0))));
        final m = f32(l - f32(c / 2.0));
        final cm = f32(c + m);
        final xm = f32(x + m);

        var r:Float;
        var g:Float;
        var b:Float;
        switch MathUtil.toI32(Math.ffloor(h6)) {
            case 0 | 6:
                r = cm; g = xm; b = m;
            case 1:
                r = xm; g = cm; b = m;
            case 2:
                r = m; g = cm; b = xm;
            case 3:
                r = m; g = xm; b = cm;
            case 4:
                r = xm; g = m; b = cm;
            case _:
                r = cm; g = m; b = xm;
        }

        return new Rgba(
            MathUtil.clamp(r, 0.0, 1.0),
            MathUtil.clamp(g, 0.0, 1.0),
            MathUtil.clamp(b, 0.0, 1.0),
            f32(color.a)
        );

    }

    /**
     * Convert the color to a hex string. For example, "#F8FAFC".
     */
    public static function toHex(color:Hsla):String {

        final rgb = toRgbF32(color);

        if (rgb.a < 1.) {
            return '#' + hex2(rgb.r) + hex2(rgb.g) + hex2(rgb.b) + hex2(color.a);
        }

        return '#' + hex2(rgb.r) + hex2(rgb.g) + hex2(rgb.b);

    }

    static function parseHexByte(value:String):Null<Int> {

        // Rust `u8::from_str_radix(.., 16)`: an optional `+`, then hex digits
        var start = 0;
        if (value.length > 0 && value.charCodeAt(0) == '+'.code) start = 1;
        if (start >= value.length) return null;
        var result = 0;
        for (i in start...value.length) {
            final c = value.charCodeAt(i);
            final digit = if (c >= '0'.code && c <= '9'.code) c - '0'.code
                else if (c >= 'a'.code && c <= 'f'.code) c - 'a'.code + 10
                else if (c >= 'A'.code && c <= 'F'.code) c - 'A'.code + 10
                else -1;
            if (digit < 0) return null;
            result = result * 16 + digit;
        }
        return result;

    }

    /**
     * Parse a hex string (`#RRGGBB` or `#RRGGBBAA`, leading `#` optional) to
     * a color. `null` when invalid.
     */
    public static function parseHex(hex:String):Null<Hsla> {

        while (StringTools.startsWith(hex, '#')) hex = hex.substring(1);
        final len = hex.length;
        if (len != 6 && len != 8) {
            return null;
        }

        final r = parseHexByte(hex.substring(0, 2));
        final g = parseHexByte(hex.substring(2, 4));
        final b = parseHexByte(hex.substring(4, 6));
        final a = len == 8 ? parseHexByte(hex.substring(6, 8)) : 255;
        if (r == null || g == null || b == null || a == null) return null;

        return Hsla.fromRgba(new Rgba(r / 255., g / 255., b / 255., len == 8 ? a / 255. : 1.));

    }

}

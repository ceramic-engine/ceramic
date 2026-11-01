// Ported from gpui-pre 0.3.10: src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * An HSLA color, with every component in the range 0.0 to 1.0
 * (the hue is a fraction of a full turn).
 *
 * Immutable: every operation returns a new instance.
 */
class Hsla {

    /**
     * Hue, in a range from 0 to 1.
     */
    public final h:Float;

    /**
     * Saturation, in a range from 0 to 1.
     */
    public final s:Float;

    /**
     * Lightness, in a range from 0 to 1.
     */
    public final l:Float;

    /**
     * Alpha, in a range from 0 to 1.
     */
    public final a:Float;

    /**
     * Creates a color from raw values, without clamping
     * (use `hsla()` from `Prelude` to clamp).
     */
    public inline function new(h:Float = 0, s:Float = 0, l:Float = 0, a:Float = 0) {

        this.h = h;
        this.s = s;
        this.l = l;
        this.a = a;

    }

    /**
     * Converts an RGBA color to HSLA (`From<Rgba> for Hsla`).
     */
    public static function fromRgba(color:Rgba):Hsla {

        final r = color.r;
        final g = color.g;
        final b = color.b;

        final max = MathUtil.max(r, MathUtil.max(g, b));
        final min = MathUtil.min(r, MathUtil.min(g, b));
        final delta = max - min;

        final l = (max + min) / 2.0;
        final s = if (l == 0.0 || l == 1.0) {
            0.0;
        }
        else if (l < 0.5) {
            delta / (2.0 * l);
        }
        else {
            delta / (2.0 - 2.0 * l);
        }

        final h = if (delta == 0.0) {
            0.0;
        }
        else if (max == r) {
            MathUtil.remEuclid((g - b) / delta, 6.0) / 6.0;
        }
        else if (max == g) {
            ((b - r) / delta + 2.0) / 6.0;
        }
        else {
            ((r - g) / delta + 4.0) / 6.0;
        }

        return new Hsla(h, s, l, color.a);

    }

    /**
     * Parses a hex color (`#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa`)
     * and converts it to HSLA. Throws when invalid.
     */
    public static function parse(value:String):Hsla {

        return fromRgba(Rgba.parse(value));

    }

    /**
     * The color red.
     */
    public static inline function red():Hsla {

        return new Hsla(0.0, 1.0, 0.5, 1.0);

    }

    /**
     * The color green.
     */
    public static inline function green():Hsla {

        return new Hsla(0.3333333333, 1.0, 0.25, 1.0);

    }

    /**
     * The color blue.
     */
    public static inline function blue():Hsla {

        return new Hsla(0.6666666667, 1.0, 0.5, 1.0);

    }

    /**
     * The color yellow.
     */
    public static inline function yellow():Hsla {

        return new Hsla(0.1666666667, 1.0, 0.5, 1.0);

    }

    /**
     * The color black.
     */
    public static inline function black():Hsla {

        return new Hsla(0.0, 0.0, 0.0, 1.0);

    }

    /**
     * The color white.
     */
    public static inline function white():Hsla {

        return new Hsla(0.0, 0.0, 1.0, 1.0);

    }

    /**
     * Transparent black.
     */
    public static inline function transparentBlack():Hsla {

        return new Hsla(0.0, 0.0, 0.0, 0.0);

    }

    /**
     * Transparent white.
     */
    public static inline function transparentWhite():Hsla {

        return new Hsla(0.0, 0.0, 1.0, 0.0);

    }

    /**
     * Opaque grey (despite its name, the opacity is configurable).
     * Values are clamped to the range 0 to 1.
     */
    public static inline function opaqueGrey(lightness:Float, opacity:Float):Hsla {

        return new Hsla(0.0, 0.0, MathUtil.clamp(lightness, 0.0, 1.0), MathUtil.clamp(opacity, 0.0, 1.0));

    }

    /**
     * Converts this color to RGBA.
     */
    public inline function toRgb():Rgba {

        return Rgba.fromHsla(this);

    }

    /**
     * Whether the color is fully transparent.
     */
    public inline function isTransparent():Bool {

        return a == 0.0;

    }

    /**
     * Whether the color is fully opaque.
     */
    public inline function isOpaque():Bool {

        return a == 1.0;

    }

    /**
     * Blends `other` on top of this color, based on `other`'s alpha.
     * The blending is done in RGB space.
     */
    public function blend(other:Hsla):Hsla {

        final alpha = other.a;

        if (alpha >= 1.0) {
            return other;
        }
        else if (alpha <= 0.0) {
            return this;
        }
        else {
            final convertedSelf = Rgba.fromHsla(this);
            final convertedOther = Rgba.fromHsla(other);
            final blendedRgb = convertedSelf.blend(convertedOther);
            return fromRgba(blendedRgb);
        }

    }

    /**
     * Returns a new color with the same hue, lightness and alpha, but no saturation.
     */
    public inline function grayscale():Hsla {

        return new Hsla(h, 0.0, l, a);

    }

    /**
     * Fades out the color by a given factor between 0.0 (unchanged)
     * and 1.0 (fully transparent).
     *
     * Note: mutates in place in Rust; returns a new color here.
     */
    public inline function fadeOut(factor:Float):Hsla {

        return new Hsla(h, s, l, a * (1.0 - MathUtil.clamp(factor, 0.0, 1.0)));

    }

    /**
     * Returns a new color with the alpha multiplied by `factor`
     * (clamped to 0.0 to 1.0).
     */
    public inline function opacity(factor:Float):Hsla {

        return new Hsla(h, s, l, a * MathUtil.clamp(factor, 0.0, 1.0));

    }

    /**
     * Returns a new color with the given alpha (clamped to 0.0 to 1.0).
     */
    public inline function alpha(a:Float):Hsla {

        return new Hsla(h, s, l, MathUtil.clamp(a, 0.0, 1.0));

    }

    /**
     * Structural equality. Like Rust's `total_cmp` based implementation,
     * NaN components are equal to each other.
     */
    public function equals(other:Hsla):Bool {

        return other != null && compare(other) == 0;

    }

    /**
     * Total ordering by hue, then saturation, lightness and alpha (Rust `Ord`).
     */
    public function compare(other:Hsla):Int {

        var result = totalCmp(h, other.h);
        if (result != 0) return result;
        result = totalCmp(s, other.s);
        if (result != 0) return result;
        result = totalCmp(l, other.l);
        if (result != 0) return result;
        return totalCmp(a, other.a);

    }

    static function totalCmp(x:Float, y:Float):Int {

        final xNaN = Math.isNaN(x);
        final yNaN = Math.isNaN(y);
        if (xNaN || yNaN) {
            return xNaN == yNaN ? 0 : (xNaN ? 1 : -1);
        }
        return x < y ? -1 : (x > y ? 1 : 0);

    }

    public function toString():String {

        return 'hsla(' + fixed2(h * 360.0) + ', ' + fixed2(s * 100.0) + '%, ' + fixed2(l * 100.0) + '%, ' + fixed2(a) + ')';

    }

    static function fixed2(value:Float):String {

        if (Math.isNaN(value) || !Math.isFinite(value)) return Std.string(value);
        final negative = value < 0;
        final hundredths = MathUtil.round(Math.abs(value) * 100.0);
        final whole = Math.ffloor(hundredths / 100.0);
        final frac = Std.int(hundredths - whole * 100.0);
        return (negative && hundredths != 0 ? '-' : '') + Std.string(whole) + '.' + (frac < 10 ? '0' : '') + frac;

    }

}

// Ported from gpui-pre 0.3.10: src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * An RGBA color, with components in the range 0.0 to 1.0.
 *
 * Immutable: every operation returns a new instance.
 */
class Rgba {

    /**
     * The red component of the color, in the range 0.0 to 1.0.
     */
    public final r:Float;

    /**
     * The green component of the color, in the range 0.0 to 1.0.
     */
    public final g:Float;

    /**
     * The blue component of the color, in the range 0.0 to 1.0.
     */
    public final b:Float;

    /**
     * The alpha component of the color, in the range 0.0 to 1.0.
     */
    public final a:Float;

    public inline function new(r:Float = 0, g:Float = 0, b:Float = 0, a:Float = 0) {

        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;

    }

    /**
     * Creates a color from a `0xRRGGBB` number, fully opaque.
     */
    public static inline function fromRgbHex(hex:Int):Rgba {

        return new Rgba(
            ((hex >>> 16) & 0xFF) / 255.0,
            ((hex >>> 8) & 0xFF) / 255.0,
            (hex & 0xFF) / 255.0,
            1.0
        );

    }

    /**
     * Creates a color from a `0xRRGGBBAA` number.
     */
    public static inline function fromRgbaHex(hex:Int):Rgba {

        return new Rgba(
            ((hex >>> 24) & 0xFF) / 255.0,
            ((hex >>> 16) & 0xFF) / 255.0,
            ((hex >>> 8) & 0xFF) / 255.0,
            (hex & 0xFF) / 255.0
        );

    }

    /**
     * Converts an HSLA color to RGBA (`From<Hsla> for Rgba`).
     */
    public static function fromHsla(color:Hsla):Rgba {

        final h = color.h;
        final s = color.s;
        final l = color.l;

        final c = (1.0 - Math.abs(2.0 * l - 1.0)) * s;
        final x = c * (1.0 - Math.abs((h * 6.0) % 2.0 - 1.0));
        final m = l - c / 2.0;
        final cm = c + m;
        final xm = x + m;

        var r:Float;
        var g:Float;
        var b:Float;
        switch MathUtil.toI32(Math.ffloor(h * 6.0)) {
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
            color.a
        );

    }

    /**
     * Blends `other` on top of this color, based on `other`'s alpha.
     * The alpha of the result is the alpha of `this`.
     */
    public function blend(other:Rgba):Rgba {

        if (other.a >= 1.0) {
            return other;
        }
        else if (other.a <= 0.0) {
            return this;
        }
        else {
            return new Rgba(
                (r * (1.0 - other.a)) + (other.r * other.a),
                (g * (1.0 - other.a)) + (other.g * other.a),
                (b * (1.0 - other.a)) + (other.b * other.a),
                a
            );
        }

    }

    /**
     * Returns a new color with the same red, green and blue channels,
     * but with the given alpha (clamped to 0.0 to 1.0).
     */
    public inline function alpha(a:Float):Rgba {

        return new Rgba(r, g, b, MathUtil.clamp(a, 0.0, 1.0));

    }

    /**
     * Returns a new color with the alpha multiplied by `factor`
     * (clamped to 0.0 to 1.0).
     */
    public inline function opacity(factor:Float):Rgba {

        return new Rgba(r, g, b, a * MathUtil.clamp(factor, 0.0, 1.0));

    }

    /**
     * Converts to HSLA (`From<Rgba> for Hsla`).
     */
    public inline function toHsla():Hsla {

        return Hsla.fromRgba(this);

    }

    /**
     * Packs the color into a `0xRRGGBBAA` number (`From<Rgba> for u32`).
     * Components are truncated, not rounded, like in Rust.
     *
     * Note: the result is a 32 bit `Int`, negative when red is 128 or more.
     */
    public function toU32():Int {

        final r = MathUtil.toU8(r * 255.0);
        final g = MathUtil.toU8(g * 255.0);
        final b = MathUtil.toU8(b * 255.0);
        final a = MathUtil.toU8(a * 255.0);
        return (r << 24) | (g << 16) | (b << 8) | a;

    }

    /**
     * Formats the color as `#rrggbbaa`, with rounded components
     * (the format used by Rust's `Serialize`).
     */
    public function toHexString():String {

        return '#'
            + StringTools.hex(MathUtil.toU8(MathUtil.round(r * 255.0)), 2).toLowerCase()
            + StringTools.hex(MathUtil.toU8(MathUtil.round(g * 255.0)), 2).toLowerCase()
            + StringTools.hex(MathUtil.toU8(MathUtil.round(b * 255.0)), 2).toLowerCase()
            + StringTools.hex(MathUtil.toU8(MathUtil.round(a * 255.0)), 2).toLowerCase();

    }

    /**
     * Parses a hex color: `#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa`
     * (case insensitive, surrounding whitespace ignored). Throws when invalid
     * (`TryFrom<&str> for Rgba`).
     */
    public static function parse(value:String):Rgba {

        final result = tryParse(value);
        if (result == null) {
            throw 'invalid RGBA hex color: \'$value\'. Expected #rgb, #rgba, #rrggbb, or #rrggbbaa';
        }
        return result;

    }

    /**
     * Same as `parse()` but returns `null` instead of throwing.
     */
    public static function tryParse(value:String):Null<Rgba> {

        if (value == null) return null;

        final trimmed = StringTools.trim(value);
        if (trimmed.length == 0 || trimmed.charCodeAt(0) != '#'.code) return null;
        final hex = trimmed.substr(1);

        var r:Int;
        var g:Int;
        var b:Int;
        var a:Int;

        switch hex.length {
            case 3 | 4:
                r = hexDigit(hex, 0);
                g = hexDigit(hex, 1);
                b = hexDigit(hex, 2);
                a = hex.length == 4 ? hexDigit(hex, 3) : 0xF;
                if (r < 0 || g < 0 || b < 0 || a < 0) return null;
                // Duplicate each hex digit
                r = (r << 4) | r;
                g = (g << 4) | g;
                b = (b << 4) | b;
                a = (a << 4) | a;
            case 6 | 8:
                r = hexByte(hex, 0);
                g = hexByte(hex, 2);
                b = hexByte(hex, 4);
                a = hex.length == 8 ? hexByte(hex, 6) : 0xFF;
                if (r < 0 || g < 0 || b < 0 || a < 0) return null;
            case _:
                return null;
        }

        return new Rgba(r / 255.0, g / 255.0, b / 255.0, a / 255.0);

    }

    static function hexDigit(str:String, index:Int):Int {

        final c = str.charCodeAt(index);
        if (c >= '0'.code && c <= '9'.code) return c - '0'.code;
        if (c >= 'a'.code && c <= 'f'.code) return c - 'a'.code + 10;
        if (c >= 'A'.code && c <= 'F'.code) return c - 'A'.code + 10;
        return -1;

    }

    static function hexByte(str:String, index:Int):Int {

        final high = hexDigit(str, index);
        final low = hexDigit(str, index + 1);
        if (high < 0 || low < 0) return -1;
        return (high << 4) | low;

    }

    /**
     * Structural equality.
     */
    public inline function equals(other:Rgba):Bool {

        return other != null && r == other.r && g == other.g && b == other.b && a == other.a;

    }

    public function toString():String {

        return 'rgba(0x' + StringTools.hex(toU32(), 8).toLowerCase() + ')';

    }

}

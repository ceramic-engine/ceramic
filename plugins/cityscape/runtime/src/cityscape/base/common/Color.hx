// Ported from vscode src/vs/base/common/color.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import haxe.extern.EitherType;

class RGBA {

    /**
     * Red: integer in [0-255]
     */
    public final r:Int;

    /**
     * Green: integer in [0-255]
     */
    public final g:Int;

    /**
     * Blue: integer in [0-255]
     */
    public final b:Int;

    /**
     * Alpha: float in [0-1]
     */
    public final a:Float;

    public function new(r:Float, g:Float, b:Float, a:Float = 1) {
        this.r = Std.int(Math.min(255, Math.max(0, r)));
        this.g = Std.int(Math.min(255, Math.max(0, g)));
        this.b = Std.int(Math.min(255, Math.max(0, b)));
        this.a = ColorHelpers.roundFloat(Math.max(Math.min(1, a), 0), 3);
    }

    /**
     * `RGBA.equals(a, b)` in Monaco.
     */
    public static function equalsStatic(a:RGBA, b:RGBA):Bool {
        return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
    }

}

class HSLA {

    /**
     * Hue: integer in [0, 360]
     */
    public final h:Int;

    /**
     * Saturation: float in [0, 1]
     */
    public final s:Float;

    /**
     * Luminosity: float in [0, 1]
     */
    public final l:Float;

    /**
     * Alpha: float in [0, 1]
     */
    public final a:Float;

    public function new(h:Float, s:Float, l:Float, a:Float) {
        this.h = Std.int(Math.max(Math.min(360, h), 0));
        this.s = ColorHelpers.roundFloat(Math.max(Math.min(1, s), 0), 3);
        this.l = ColorHelpers.roundFloat(Math.max(Math.min(1, l), 0), 3);
        this.a = ColorHelpers.roundFloat(Math.max(Math.min(1, a), 0), 3);
    }

    /**
     * `HSLA.equals(a, b)` in Monaco.
     */
    public static function equalsStatic(a:HSLA, b:HSLA):Bool {
        return a.h == b.h && a.s == b.s && a.l == b.l && a.a == b.a;
    }

    /**
     * Converts an RGB color value to HSL. Conversion formula
     * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
     * Assumes r, g, and b are contained in the set [0, 255] and
     * returns h in the set [0, 360], s, and l in the set [0, 1].
     */
    public static function fromRGBA(rgba:RGBA):HSLA {
        final r = rgba.r / 255;
        final g = rgba.g / 255;
        final b = rgba.b / 255;
        final a = rgba.a;

        final max = Math.max(Math.max(r, g), b);
        final min = Math.min(Math.min(r, g), b);
        var h:Float = 0;
        var s:Float = 0;
        final l = (min + max) / 2;
        final chroma = max - min;

        if (chroma > 0) {
            s = Math.min((l <= 0.5 ? chroma / (2 * l) : chroma / (2 - (2 * l))), 1);

            if (max == r) {
                h = (g - b) / chroma + (g < b ? 6 : 0);
            }
            else if (max == g) {
                h = (b - r) / chroma + 2;
            }
            else if (max == b) {
                h = (r - g) / chroma + 4;
            }

            h *= 60;
            h = Math.fround(h);
        }
        return new HSLA(h, s, l, a);
    }

    static function _hue2rgb(p:Float, q:Float, t:Float):Float {
        if (t < 0) {
            t += 1;
        }
        if (t > 1) {
            t -= 1;
        }
        if (t < 1 / 6) {
            return p + (q - p) * 6 * t;
        }
        if (t < 1 / 2) {
            return q;
        }
        if (t < 2 / 3) {
            return p + (q - p) * (2 / 3 - t) * 6;
        }
        return p;
    }

    /**
     * Converts an HSL color value to RGB. Conversion formula
     * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
     * Assumes h in the set [0, 360] s, and l are contained in the set [0, 1] and
     * returns r, g, and b in the set [0, 255].
     */
    public static function toRGBA(hsla:HSLA):RGBA {
        final h = hsla.h / 360;
        final s = hsla.s;
        final l = hsla.l;
        final a = hsla.a;
        var r:Float;
        var g:Float;
        var b:Float;

        if (s == 0) {
            r = g = b = l; // achromatic
        }
        else {
            final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            final p = 2 * l - q;
            r = _hue2rgb(p, q, h + 1 / 3);
            g = _hue2rgb(p, q, h);
            b = _hue2rgb(p, q, h - 1 / 3);
        }

        return new RGBA(Math.fround(r * 255), Math.fround(g * 255), Math.fround(b * 255), a);
    }

}

class HSVA {

    /**
     * Hue: integer in [0, 360]
     */
    public final h:Int;

    /**
     * Saturation: float in [0, 1]
     */
    public final s:Float;

    /**
     * Value: float in [0, 1]
     */
    public final v:Float;

    /**
     * Alpha: float in [0, 1]
     */
    public final a:Float;

    public function new(h:Float, s:Float, v:Float, a:Float) {
        this.h = Std.int(Math.max(Math.min(360, h), 0));
        this.s = ColorHelpers.roundFloat(Math.max(Math.min(1, s), 0), 3);
        this.v = ColorHelpers.roundFloat(Math.max(Math.min(1, v), 0), 3);
        this.a = ColorHelpers.roundFloat(Math.max(Math.min(1, a), 0), 3);
    }

    /**
     * `HSVA.equals(a, b)` in Monaco.
     */
    public static function equalsStatic(a:HSVA, b:HSVA):Bool {
        return a.h == b.h && a.s == b.s && a.v == b.v && a.a == b.a;
    }

    // from http://www.rapidtables.com/convert/color/rgb-to-hsv.htm
    public static function fromRGBA(rgba:RGBA):HSVA {
        final r = rgba.r / 255;
        final g = rgba.g / 255;
        final b = rgba.b / 255;
        final cmax = Math.max(Math.max(r, g), b);
        final cmin = Math.min(Math.min(r, g), b);
        final delta = cmax - cmin;
        final s = cmax == 0 ? 0 : (delta / cmax);
        var m:Float;

        if (delta == 0) {
            m = 0;
        }
        else if (cmax == r) {
            m = ((((g - b) / delta) % 6) + 6) % 6;
        }
        else if (cmax == g) {
            m = ((b - r) / delta) + 2;
        }
        else {
            m = ((r - g) / delta) + 4;
        }

        return new HSVA(Math.fround(m * 60), s, cmax, rgba.a);
    }

    // from http://www.rapidtables.com/convert/color/hsv-to-rgb.htm
    public static function toRGBA(hsva:HSVA):RGBA {
        final h = hsva.h;
        final s = hsva.s;
        final v = hsva.v;
        final a = hsva.a;
        final c = v * s;
        final x = c * (1 - Math.abs((h / 60) % 2 - 1));
        final m = v - c;
        var r:Float = 0;
        var g:Float = 0;
        var b:Float = 0;

        if (h < 60) {
            r = c;
            g = x;
        }
        else if (h < 120) {
            r = x;
            g = c;
        }
        else if (h < 180) {
            g = c;
            b = x;
        }
        else if (h < 240) {
            g = x;
            b = c;
        }
        else if (h < 300) {
            r = x;
            b = c;
        }
        else if (h <= 360) {
            r = c;
            b = x;
        }

        r = Math.fround((r + m) * 255);
        g = Math.fround((g + m) * 255);
        b = Math.fround((b + m) * 255);

        return new RGBA(r, g, b, a);
    }

}

class Color {

    public static function fromHex(hex:String):Color {
        final color = ColorFormatCSS.parseHex(hex);
        return color != null ? color : Color.red;
    }

    /**
     * `Color.equals(a, b)` in Monaco.
     */
    public static function equalsStatic(a:Null<Color>, b:Null<Color>):Bool {
        if (a == null && b == null) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        return a.equals(b);
    }

    public final rgba:RGBA;

    var _hsla:Null<HSLA> = null;

    public var hsla(get, never):HSLA;

    function get_hsla():HSLA {
        if (_hsla != null) {
            return _hsla;
        }
        else {
            return HSLA.fromRGBA(this.rgba);
        }
    }

    var _hsva:Null<HSVA> = null;

    public var hsva(get, never):HSVA;

    function get_hsva():HSVA {
        if (_hsva != null) {
            return _hsva;
        }
        return HSVA.fromRGBA(this.rgba);
    }

    /**
     * `arg` is an `RGBA`, an `HSLA` or an `HSVA`.
     */
    public function new(arg:EitherType<RGBA, EitherType<HSLA, HSVA>>) {
        if (arg == null) {
            throw 'Color needs a value';
        }
        else if (Std.isOfType(arg, RGBA)) {
            this.rgba = (arg : RGBA);
        }
        else if (Std.isOfType(arg, HSLA)) {
            this._hsla = (arg : HSLA);
            this.rgba = HSLA.toRGBA((arg : HSLA));
        }
        else if (Std.isOfType(arg, HSVA)) {
            this._hsva = (arg : HSVA);
            this.rgba = HSVA.toRGBA((arg : HSVA));
        }
        else {
            throw 'Invalid color ctor argument';
        }
    }

    public function equals(other:Null<Color>):Bool {
        return other != null && RGBA.equalsStatic(this.rgba, other.rgba) && HSLA.equalsStatic(this.hsla, other.hsla) && HSVA.equalsStatic(this.hsva, other.hsva);
    }

    /**
     * http://www.w3.org/TR/WCAG20/#relativeluminancedef
     * Returns the number in the set [0, 1]. O => Darkest Black. 1 => Lightest white.
     */
    public function getRelativeLuminance():Float {
        final R = Color._relativeLuminanceForComponent(this.rgba.r);
        final G = Color._relativeLuminanceForComponent(this.rgba.g);
        final B = Color._relativeLuminanceForComponent(this.rgba.b);
        final luminance = 0.2126 * R + 0.7152 * G + 0.0722 * B;

        return ColorHelpers.roundFloat(luminance, 4);
    }

    static function _relativeLuminanceForComponent(color:Float):Float {
        final c = color / 255;
        return (c <= 0.03928) ? c / 12.92 : Math.pow(((c + 0.055) / 1.055), 2.4);
    }

    /**
     * http://www.w3.org/TR/WCAG20/#contrast-ratiodef
     * Returns the contrast ration number in the set [1, 21].
     */
    public function getContrastRatio(another:Color):Float {
        final lum1 = this.getRelativeLuminance();
        final lum2 = another.getRelativeLuminance();
        return lum1 > lum2 ? (lum1 + 0.05) / (lum2 + 0.05) : (lum2 + 0.05) / (lum1 + 0.05);
    }

    /**
     * http://24ways.org/2010/calculating-color-contrast
     * Return 'true' if darker color otherwise 'false'
     */
    public function isDarker():Bool {
        final yiq = (this.rgba.r * 299 + this.rgba.g * 587 + this.rgba.b * 114) / 1000;
        return yiq < 128;
    }

    /**
     * http://24ways.org/2010/calculating-color-contrast
     * Return 'true' if lighter color otherwise 'false'
     */
    public function isLighter():Bool {
        final yiq = (this.rgba.r * 299 + this.rgba.g * 587 + this.rgba.b * 114) / 1000;
        return yiq >= 128;
    }

    public function isLighterThan(another:Color):Bool {
        final lum1 = this.getRelativeLuminance();
        final lum2 = another.getRelativeLuminance();
        return lum1 > lum2;
    }

    public function isDarkerThan(another:Color):Bool {
        final lum1 = this.getRelativeLuminance();
        final lum2 = another.getRelativeLuminance();
        return lum1 < lum2;
    }

    public function lighten(factor:Float):Color {
        final hsla = this.hsla;
        return new Color(new HSLA(hsla.h, hsla.s, hsla.l + hsla.l * factor, hsla.a));
    }

    public function darken(factor:Float):Color {
        final hsla = this.hsla;
        return new Color(new HSLA(hsla.h, hsla.s, hsla.l - hsla.l * factor, hsla.a));
    }

    public function transparent(factor:Float):Color {
        final rgba = this.rgba;
        return new Color(new RGBA(rgba.r, rgba.g, rgba.b, rgba.a * factor));
    }

    public function isTransparent():Bool {
        return this.rgba.a == 0;
    }

    public function isOpaque():Bool {
        return this.rgba.a == 1;
    }

    public function opposite():Color {
        return new Color(new RGBA(255 - this.rgba.r, 255 - this.rgba.g, 255 - this.rgba.b, this.rgba.a));
    }

    public function blend(c:Color):Color {
        final rgba = c.rgba;

        // Convert to 0..1 opacity
        final thisA = this.rgba.a;
        final colorA = rgba.a;

        final a = thisA + colorA * (1 - thisA);
        if (a < 1e-6) {
            return Color.transparentStatic;
        }

        final r = this.rgba.r * thisA / a + rgba.r * colorA * (1 - thisA) / a;
        final g = this.rgba.g * thisA / a + rgba.g * colorA * (1 - thisA) / a;
        final b = this.rgba.b * thisA / a + rgba.b * colorA * (1 - thisA) / a;

        return new Color(new RGBA(r, g, b, a));
    }

    public function makeOpaque(opaqueBackground:Color):Color {
        if (this.isOpaque() || opaqueBackground.rgba.a != 1) {
            // only allow to blend onto a non-opaque color onto a opaque color
            return this;
        }

        final r = this.rgba.r;
        final g = this.rgba.g;
        final b = this.rgba.b;
        final a = this.rgba.a;

        // https://stackoverflow.com/questions/12228548/finding-equivalent-color-with-opacity
        return new Color(new RGBA(
            opaqueBackground.rgba.r - a * (opaqueBackground.rgba.r - r),
            opaqueBackground.rgba.g - a * (opaqueBackground.rgba.g - g),
            opaqueBackground.rgba.b - a * (opaqueBackground.rgba.b - b),
            1
        ));
    }

    public function flatten(backgrounds:haxe.Rest<Color>):Color {
        // backgrounds.reduceRight((accumulator, color) => Color._flatten(color, accumulator))
        if (backgrounds.length == 0) {
            throw 'Reduce of empty array with no initial value';
        }
        var background = backgrounds[backgrounds.length - 1];
        var i = backgrounds.length - 2;
        while (i >= 0) {
            background = Color._flatten(backgrounds[i], background);
            i--;
        }
        return Color._flatten(this, background);
    }

    static function _flatten(foreground:Color, background:Color):Color {
        final backgroundAlpha = 1 - foreground.rgba.a;
        return new Color(new RGBA(
            backgroundAlpha * background.rgba.r + foreground.rgba.a * foreground.rgba.r,
            backgroundAlpha * background.rgba.g + foreground.rgba.a * foreground.rgba.g,
            backgroundAlpha * background.rgba.b + foreground.rgba.a * foreground.rgba.b
        ));
    }

    var _toString:Null<String> = null;

    public function toString():String {
        if (_toString == null) {
            _toString = ColorFormatCSS.format(this);
        }
        return _toString;
    }

    public static function getLighterColor(of:Color, relative:Color, ?factor:Float):Color {
        if (of.isLighterThan(relative)) {
            return of;
        }
        var f:Float = (factor != null && factor != 0) ? factor : 0.5;
        final lum1 = of.getRelativeLuminance();
        final lum2 = relative.getRelativeLuminance();
        f = f * (lum2 - lum1) / lum2;
        return of.lighten(f);
    }

    public static function getDarkerColor(of:Color, relative:Color, ?factor:Float):Color {
        if (of.isDarkerThan(relative)) {
            return of;
        }
        var f:Float = (factor != null && factor != 0) ? factor : 0.5;
        final lum1 = of.getRelativeLuminance();
        final lum2 = relative.getRelativeLuminance();
        f = f * (lum1 - lum2) / lum1;
        return of.darken(f);
    }

    public static final white = new Color(new RGBA(255, 255, 255, 1));
    public static final black = new Color(new RGBA(0, 0, 0, 1));
    public static final red = new Color(new RGBA(255, 0, 0, 1));
    public static final blue = new Color(new RGBA(0, 0, 255, 1));
    public static final green = new Color(new RGBA(0, 255, 0, 1));
    public static final cyan = new Color(new RGBA(0, 255, 255, 1));
    public static final lightgrey = new Color(new RGBA(211, 211, 211, 1));

    /**
     * `Color.transparent` in Monaco (renamed: the instance method
     * `transparent(factor)` has the same name).
     */
    public static final transparentStatic = new Color(new RGBA(0, 0, 0, 0));

}

/**
 * `Color.Format.CSS` in Monaco.
 */
class ColorFormatCSS {

    public static function formatRGB(color:Color):String {
        if (color.rgba.a == 1) {
            return 'rgb(${color.rgba.r}, ${color.rgba.g}, ${color.rgba.b})';
        }

        return ColorFormatCSS.formatRGBA(color);
    }

    public static function formatRGBA(color:Color):String {
        // `+(a).toFixed(2)`
        return 'rgba(${color.rgba.r}, ${color.rgba.g}, ${color.rgba.b}, ' + JsValues.numberToString(Math.fround(color.rgba.a * 100) / 100) + ')';
    }

    public static function formatHSL(color:Color):String {
        final hsla = color.hsla;
        if (hsla.a == 1) {
            return 'hsl(${hsla.h}, ' + ColorHelpers.toFixed(hsla.s * 100, 2) + '%, ' + ColorHelpers.toFixed(hsla.l * 100, 2) + '%)';
        }

        return ColorFormatCSS.formatHSLA(color);
    }

    public static function formatHSLA(color:Color):String {
        final hsla = color.hsla;
        return 'hsla(${hsla.h}, ' + ColorHelpers.toFixed(hsla.s * 100, 2) + '%, ' + ColorHelpers.toFixed(hsla.l * 100, 2) + '%, ' + ColorHelpers.toFixed(hsla.a, 2) + ')';
    }

    static function _toTwoDigitHex(n:Int):String {
        final r = StringTools.hex(n).toLowerCase();
        return r.length != 2 ? '0' + r : r;
    }

    /**
     * Formats the color as #RRGGBB
     */
    public static function formatHex(color:Color):String {
        return '#' + _toTwoDigitHex(color.rgba.r) + _toTwoDigitHex(color.rgba.g) + _toTwoDigitHex(color.rgba.b);
    }

    /**
     * Formats the color as #RRGGBBAA
     * If 'compact' is set, colors without transparancy will be printed as #RRGGBB
     */
    public static function formatHexA(color:Color, compact:Bool = false):String {
        if (compact && color.rgba.a == 1) {
            return ColorFormatCSS.formatHex(color);
        }

        return '#' + _toTwoDigitHex(color.rgba.r) + _toTwoDigitHex(color.rgba.g) + _toTwoDigitHex(color.rgba.b) + _toTwoDigitHex(Math.round(color.rgba.a * 255));
    }

    /**
     * The default format will use HEX if opaque and RGBA otherwise.
     */
    public static function format(color:Color):String {
        if (color.isOpaque()) {
            return ColorFormatCSS.formatHex(color);
        }

        return ColorFormatCSS.formatRGBA(color);
    }

    /**
     * Converts an Hex color value to a Color.
     * returns r, g, and b are contained in the set [0, 255]
     * @param hex string (#RGB, #RGBA, #RRGGBB or #RRGGBBAA).
     */
    public static function parseHex(hex:String):Null<Color> {
        final length = hex.length;

        if (length == 0) {
            // Invalid color
            return null;
        }

        if (StringTools.fastCodeAt(hex, 0) != CharCode.Hash) {
            // Does not begin with a #
            return null;
        }

        if (length == 7) {
            // #RRGGBB format
            final r = 16 * _parseHexDigit(StringTools.fastCodeAt(hex, 1)) + _parseHexDigit(StringTools.fastCodeAt(hex, 2));
            final g = 16 * _parseHexDigit(StringTools.fastCodeAt(hex, 3)) + _parseHexDigit(StringTools.fastCodeAt(hex, 4));
            final b = 16 * _parseHexDigit(StringTools.fastCodeAt(hex, 5)) + _parseHexDigit(StringTools.fastCodeAt(hex, 6));
            return new Color(new RGBA(r, g, b, 1));
        }

        if (length == 9) {
            // #RRGGBBAA format
            final r = 16 * _parseHexDigit(StringTools.fastCodeAt(hex, 1)) + _parseHexDigit(StringTools.fastCodeAt(hex, 2));
            final g = 16 * _parseHexDigit(StringTools.fastCodeAt(hex, 3)) + _parseHexDigit(StringTools.fastCodeAt(hex, 4));
            final b = 16 * _parseHexDigit(StringTools.fastCodeAt(hex, 5)) + _parseHexDigit(StringTools.fastCodeAt(hex, 6));
            final a = 16 * _parseHexDigit(StringTools.fastCodeAt(hex, 7)) + _parseHexDigit(StringTools.fastCodeAt(hex, 8));
            return new Color(new RGBA(r, g, b, a / 255));
        }

        if (length == 4) {
            // #RGB format
            final r = _parseHexDigit(StringTools.fastCodeAt(hex, 1));
            final g = _parseHexDigit(StringTools.fastCodeAt(hex, 2));
            final b = _parseHexDigit(StringTools.fastCodeAt(hex, 3));
            return new Color(new RGBA(16 * r + r, 16 * g + g, 16 * b + b));
        }

        if (length == 5) {
            // #RGBA format
            final r = _parseHexDigit(StringTools.fastCodeAt(hex, 1));
            final g = _parseHexDigit(StringTools.fastCodeAt(hex, 2));
            final b = _parseHexDigit(StringTools.fastCodeAt(hex, 3));
            final a = _parseHexDigit(StringTools.fastCodeAt(hex, 4));
            return new Color(new RGBA(16 * r + r, 16 * g + g, 16 * b + b, (16 * a + a) / 255));
        }

        // Invalid color
        return null;
    }

    static function _parseHexDigit(charCode:Int):Int {
        final digit0:Int = CharCode.Digit0;
        final lowerA:Int = CharCode.a;
        final upperA:Int = CharCode.A;
        if (charCode >= digit0 && charCode <= digit0 + 9) {
            return charCode - digit0;
        }
        if (charCode >= lowerA && charCode <= lowerA + 5) {
            return charCode - lowerA + 10;
        }
        if (charCode >= upperA && charCode <= upperA + 5) {
            return charCode - upperA + 10;
        }
        return 0;
    }

}

/**
 * Module helpers of color.ts (`roundFloat`) and the `Number.prototype.toFixed`
 * the CSS formats use.
 */
@:allow(cityscape.base.common)
private class ColorHelpers {

    static function roundFloat(number:Float, decimalPoints:Int):Float {
        final decimal = Math.pow(10, decimalPoints);
        return Math.fround(number * decimal) / decimal;
    }

    /**
     * `value.toFixed(digits)` for the small non-negative values of the CSS
     * formats (rounds half up on the binary value, like most cases of
     * JavaScript's exact decimal rounding).
     */
    static function toFixed(value:Float, digits:Int):String {
        final negative = value < 0;
        final p = Math.pow(10, digits);
        final n = Math.fround(Math.abs(value) * p);
        final intPart = Math.ffloor(n / p);
        var frac = Std.string(Std.int(n - intPart * p));
        while (frac.length < digits) {
            frac = '0' + frac;
        }
        final s = JsValues.numberToString(intPart) + (digits > 0 ? '.' + frac : '');
        return negative && n != 0 ? '-' + s : s;
    }

}

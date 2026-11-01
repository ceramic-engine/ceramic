// Ported from gpui-kit 0.8.1: crates/component/src/theme/color.rs (free functions, oklab, shadcn palette, color and background parsing)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

import gpui.Background;
import gpui.Hsla;
import gpui.LinearColorStop;
import gpui.Rgba;
import gpui.util.MathUtil;

/**
 * The free functions of gpui-kit's `theme/color.rs`: `hsl`, `oklch`, the
 * shadcn palette (`red500()`, `blue(600)`...), and the parsers of theme
 * values (`tryParseColor`, `tryParseBackground`).
 *
 * Use with `import gpui.component.theme.Color.*;`. Rust functions returning
 * `Result` return `null` on error here.
 */
class Color {

    /**
     * Create a `gpui.Hsla` color.
     *
     * - h: 0..360.0
     * - s: 0.0..100.0
     * - l: 0.0..100.0
     */
    public static inline function hsl(h:Float, s:Float, l:Float):Hsla {

        return gpui.Prelude.hsla(h / 360., s / 100.0, l / 100.0, 1.0);

    }

    // Helper functions for Oklab color space conversions (Rust: `mod oklab`)

    /**
     * Convert sRGB component to linear RGB.
     */
    static inline function toLinear(c:Float):Float {

        return if (c <= 0.04045) {
            c / 12.92;
        }
        else {
            Math.pow((c + 0.055) / 1.055, 2.4);
        }

    }

    /**
     * Convert linear RGB component to sRGB.
     */
    static inline function fromLinear(c:Float):Float {

        return if (c <= 0.0031308) {
            c * 12.92;
        }
        else {
            1.055 * Math.pow(c, 1.0 / 2.4) - 0.055;
        }

    }

    static inline function cbrt(x:Float):Float {

        return x < 0 ? -Math.pow(-x, 1.0 / 3.0) : Math.pow(x, 1.0 / 3.0);

    }

    /**
     * Convert RGB to Oklab color space, as `[L, a, b]`.
     */
    @:allow(gpui.component.theme)
    static function rgbToOklab(rgb:Rgba):Array<Float> {

        // sRGB to linear RGB
        final lr = toLinear(rgb.r);
        final lg = toLinear(rgb.g);
        final lb = toLinear(rgb.b);

        // Linear RGB to LMS
        final l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb;
        final m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb;
        final s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb;

        // LMS to Oklab (using cube root)
        final l_ = cbrt(l);
        final m_ = cbrt(m);
        final s_ = cbrt(s);

        return [
            0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        ];

    }

    /**
     * Convert Oklab to RGB color space (alpha 1).
     */
    @:allow(gpui.component.theme)
    static function oklabToRgb(L:Float, a:Float, b:Float, alpha:Float = 1.0):Rgba {

        // Oklab to LMS
        final l_ = L + 0.3963377774 * a + 0.2158037573 * b;
        final m_ = L - 0.1055613458 * a - 0.0638541728 * b;
        final s_ = L - 0.0894841775 * a - 1.2914855480 * b;

        final l = l_ * l_ * l_;
        final m = m_ * m_ * m_;
        final s = s_ * s_ * s_;

        // LMS to Linear RGB
        final lr = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
        final lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
        final lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

        // Linear RGB to sRGB
        return new Rgba(
            MathUtil.clamp(fromLinear(lr), 0.0, 1.0),
            MathUtil.clamp(fromLinear(lg), 0.0, 1.0),
            MathUtil.clamp(fromLinear(lb), 0.0, 1.0),
            alpha
        );

    }

    /**
     * Builds a color from OkLCH, the cylindrical form of the perceptually
     * uniform Oklab color space.
     *
     * `lightness` is `0.0 .. 1.0`, `chroma` is an absolute Oklab distance
     * (roughly `0.0 .. 0.37`), and `hue` is in degrees. A request outside the
     * sRGB gamut is clipped per channel, which costs a little chroma but not the hue.
     */
    public static function oklch(lightness:Float, chroma:Float, hue:Float):Hsla {

        final hue = hue * (Math.PI / 180.0);
        final rgb = oklabToRgb(lightness, chroma * Math.cos(hue), chroma * Math.sin(hue));
        return Hsla.fromRgba(rgb);

    }

    // Shadcn palette (Rust: DEFAULT_COLORS, parsed from default-colors.json)

    static var defaultColors:Null<ShadcnColors> = null;

    @:allow(gpui.component.theme)
    static function shadcnColors():ShadcnColors {

        if (defaultColors == null) {
            defaultColors = ShadcnColors.parse(haxe.Json.parse(ThemeMacro.defaultColorsJson()));
        }
        return defaultColors;

    }

    public static function black():Hsla {

        return shadcnColors().black;

    }

    public static function white():Hsla {

        return shadcnColors().white;

    }

    /**
     * The palette color `name` at `scale`, black when the scale is not found
     * (Rust: the functions generated by `color_methods!`).
     */
    @:allow(gpui.component.theme)
    static function paletteColor(name:String, scale:Int):Hsla {

        final color = shadcnColors().scales.get(name).get(scale);
        return color != null ? color : black();

    }

    // Parsing

    /**
     * Parses an unsigned integer like Rust's `str::parse::<usize>` (an
     * optional `+`, then decimal digits only). `null` when invalid.
     */
    static function parseUsize(value:String):Null<Int> {

        var start = 0;
        if (value.length > 0 && value.charCodeAt(0) == '+'.code) start = 1;
        if (start >= value.length) return null;
        var result = 0;
        for (i in start...value.length) {
            final c = value.charCodeAt(i);
            if (c < '0'.code || c > '9'.code) return null;
            result = result * 10 + (c - '0'.code);
        }
        return result;

    }

    /**
     * Try to parse the color, HEX or [Tailwind Color](https://tailwindcss.com/docs/colors) expression.
     *
     * - `#RRGGBB` - The HEX color string.
     * - `#RRGGBBAA` - The HEX color string with alpha.
     *
     * Or the Tailwind Color format:
     *
     * - `name` - The color name `black`, `white`, or any other `ColorName`.
     * - `name-scale` - The color name with scale.
     * - `name/opacity` - The color name with opacity, `opacity` should be an integer between 0 and 100.
     * - `name-scale/opacity` - The color name with scale and opacity.
     *
     * Returns `null` when invalid.
     */
    public static function tryParseColor(color:String):Null<Hsla> {

        if (StringTools.startsWith(color, '#')) {
            final rgba = Rgba.tryParse(color);
            return rgba != null ? Hsla.fromRgba(rgba) : null;
        }

        var name = '';
        var scale:Null<Int> = null;
        var opacity:Null<Float> = null;
        // 0: name, 1: scale, 2: opacity
        var state = 0;
        var part = new StringBuf();

        for (c in new haxe.iterators.StringIteratorUnicode(color)) {
            if (c == '-'.code && state == 0) {
                name = part.toString();
                part = new StringBuf();
                state = 1;
            }
            else if (c == '/'.code && state <= 1) {
                if (state == 0) {
                    name = part.toString();
                    part = new StringBuf();
                }
                else if (state == 1) {
                    scale = parseUsize(part.toString());
                    part = new StringBuf();
                }
                state = 2;
            }
            else {
                part.addChar(c);
            }
        }

        switch state {
            case 0: name = part.toString();
            case 1: scale = parseUsize(part.toString());
            case 2: opacity = MathUtil.parseFloat(part.toString());
            case _:
        }

        if (name.length == 0) {
            return null;
        }

        var hsla = switch name {
            case 'black': black();
            case 'white': white();
            case _:
                final colorName = ColorName.tryFrom(name);
                if (colorName == null) return null;
                if (scale != null) {
                    colorName.scale(scale);
                }
                else {
                    colorName.scale(500);
                }
        }

        if (opacity != null) {
            if (opacity > 100.) {
                return null;
            }
            hsla = hsla.opacity(opacity / 100.);
        }

        return hsla;

    }

    /**
     * Try to parse a theme background value: any value accepted by
     * `tryParseColor`, or a CSS-style two-stop `linear-gradient(...)`.
     */
    public static function tryParseBackground(background:String):Null<Background> {

        final color = tryParseColor(background);
        if (color != null) {
            return Background.fromHsla(color);
        }

        final gradient = parseLinearGradient(background);
        if (gradient == null) return null;
        return gpui.Prelude.linearGradient(gradient.angle, gradient.from, gradient.to);

    }

    /**
     * Parse a background, clamping every color stop's alpha to at most `max`.
     *
     * Unlike `Background.opacity`, which scales all stops by a single factor,
     * this caps each gradient stop independently.
     */
    @:allow(gpui.component.theme)
    static function tryParseBackgroundClamped(background:String, max:Float):Null<Background> {

        final color = tryParseColor(background);
        if (color != null) {
            return Background.fromHsla(color.alpha(Math.min(color.a, max)));
        }

        final gradient = parseLinearGradient(background);
        if (gradient == null) return null;
        final clamp = (stop:LinearColorStop) -> new LinearColorStop(stop.color.alpha(Math.min(stop.color.a, max)), stop.percentage);
        return gpui.Prelude.linearGradient(gradient.angle, clamp(gradient.from), clamp(gradient.to));

    }

    @:allow(gpui.component.theme)
    static function tryParseThemeColor(color:String):Null<Hsla> {

        final parsed = tryParseColor(color);
        if (parsed != null) {
            return parsed;
        }

        final gradient = parseLinearGradient(color);
        return gradient != null ? gradient.from.color : null;

    }

    static function parseLinearGradient(background:String):Null<ParsedLinearGradient> {

        final PREFIX = 'linear-gradient(';

        final background = StringTools.trim(background);
        if (!StringTools.startsWith(background.toLowerCase(), PREFIX) || !StringTools.endsWith(background, ')')) {
            return null;
        }

        final inner = background.substring(PREFIX.length, background.length - 1);
        final parts = splitTopLevelCommas(inner);
        if (parts.length == 2) {
            final from = parseLinearColorStop(parts[0], 0.);
            final to = parseLinearColorStop(parts[1], 1.);
            if (from == null || to == null) return null;
            return {angle: 180., from: from, to: to};
        }
        else if (parts.length == 3) {
            final angle = parseLinearGradientAngle(parts[0]);
            if (angle == null) return null;
            final from = parseLinearColorStop(parts[1], 0.);
            final to = parseLinearColorStop(parts[2], 1.);
            if (from == null || to == null) return null;
            return {angle: angle, from: from, to: to};
        }
        else {
            // Expected linear-gradient with two color stops, e.g. linear-gradient(135deg, #000, #fff)
            return null;
        }

    }

    static function splitTopLevelCommas(value:String):Array<String> {

        final parts = [];
        var depth = 0;
        var start = 0;

        for (ix in 0...value.length) {
            switch value.charCodeAt(ix) {
                case '('.code: depth += 1;
                case ')'.code: depth = depth > 0 ? depth - 1 : 0;
                case ','.code if (depth == 0):
                    parts.push(StringTools.trim(value.substring(start, ix)));
                    start = ix + 1;
                case _:
            }
        }

        parts.push(StringTools.trim(value.substring(start)));
        return parts;

    }

    static function parseLinearGradientAngle(angle:String):Null<Float> {

        final angle = StringTools.trim(angle).toLowerCase();

        if (StringTools.endsWith(angle, 'deg')) {
            final degrees = MathUtil.parseFloat(StringTools.trim(angle.substring(0, angle.length - 3)));
            return degrees != null ? MathUtil.remEuclid(degrees, 360.) : null;
        }

        if (StringTools.startsWith(angle, 'to ')) {
            return parseLinearGradientDirection(angle.substring(3));
        }

        // Unsupported linear-gradient angle
        return null;

    }

    static function splitWhitespace(value:String):Array<String> {

        return [for (part in ~/\s+/g.split(StringTools.trim(value))) if (part.length > 0) part];

    }

    static function parseLinearGradientDirection(direction:String):Null<Float> {

        var top = false;
        var right = false;
        var bottom = false;
        var left = false;

        for (part in splitWhitespace(direction)) {
            switch part {
                case 'top': top = true;
                case 'right': right = true;
                case 'bottom': bottom = true;
                case 'left': left = true;
                case _: return null;
            }
        }

        return switch [top, right, bottom, left] {
            case [true, false, false, false]: 0.;
            case [false, true, false, false]: 90.;
            case [false, false, true, false]: 180.;
            case [false, false, false, true]: 270.;
            case [true, true, false, false]: 45.;
            case [false, true, true, false]: 135.;
            case [false, false, true, true]: 225.;
            case [true, false, false, true]: 315.;
            case _: null;
        }

    }

    static function parseLinearColorStop(stop:String, defaultPercentage:Float):Null<LinearColorStop> {

        final stop = StringTools.trim(stop);
        final parts = splitWhitespace(stop);
        var percentage = defaultPercentage;
        if (parts.length > 0) {
            final last = parts[parts.length - 1];
            if (StringTools.endsWith(last, '%')) {
                final value = MathUtil.parseFloat(last.substring(0, last.length - 1));
                if (value == null) return null;
                percentage = value / 100.;
            }
        }

        if (StringTools.endsWith(stop, '%')) {
            parts.pop();
        }

        final color = parts.join(' ');
        if (color.length == 0) {
            // Expected color in linear-gradient color stop
            return null;
        }

        final parsed = tryParseColor(color);
        if (parsed == null) return null;
        return new LinearColorStop(parsed, MathUtil.clamp(percentage, 0., 1.));

    }

    // Palette functions (Rust: `color_methods!`)

    /**
     * Get slate by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function slate(scale:Int):Hsla {

        return paletteColor('slate', scale);

    }

    public static inline function slate50():Hsla return paletteColor('slate', 50);
    public static inline function slate100():Hsla return paletteColor('slate', 100);
    public static inline function slate200():Hsla return paletteColor('slate', 200);
    public static inline function slate300():Hsla return paletteColor('slate', 300);
    public static inline function slate400():Hsla return paletteColor('slate', 400);
    public static inline function slate500():Hsla return paletteColor('slate', 500);
    public static inline function slate600():Hsla return paletteColor('slate', 600);
    public static inline function slate700():Hsla return paletteColor('slate', 700);
    public static inline function slate800():Hsla return paletteColor('slate', 800);
    public static inline function slate900():Hsla return paletteColor('slate', 900);
    public static inline function slate950():Hsla return paletteColor('slate', 950);

    /**
     * Get gray by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function gray(scale:Int):Hsla {

        return paletteColor('gray', scale);

    }

    public static inline function gray50():Hsla return paletteColor('gray', 50);
    public static inline function gray100():Hsla return paletteColor('gray', 100);
    public static inline function gray200():Hsla return paletteColor('gray', 200);
    public static inline function gray300():Hsla return paletteColor('gray', 300);
    public static inline function gray400():Hsla return paletteColor('gray', 400);
    public static inline function gray500():Hsla return paletteColor('gray', 500);
    public static inline function gray600():Hsla return paletteColor('gray', 600);
    public static inline function gray700():Hsla return paletteColor('gray', 700);
    public static inline function gray800():Hsla return paletteColor('gray', 800);
    public static inline function gray900():Hsla return paletteColor('gray', 900);
    public static inline function gray950():Hsla return paletteColor('gray', 950);

    /**
     * Get zinc by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function zinc(scale:Int):Hsla {

        return paletteColor('zinc', scale);

    }

    public static inline function zinc50():Hsla return paletteColor('zinc', 50);
    public static inline function zinc100():Hsla return paletteColor('zinc', 100);
    public static inline function zinc200():Hsla return paletteColor('zinc', 200);
    public static inline function zinc300():Hsla return paletteColor('zinc', 300);
    public static inline function zinc400():Hsla return paletteColor('zinc', 400);
    public static inline function zinc500():Hsla return paletteColor('zinc', 500);
    public static inline function zinc600():Hsla return paletteColor('zinc', 600);
    public static inline function zinc700():Hsla return paletteColor('zinc', 700);
    public static inline function zinc800():Hsla return paletteColor('zinc', 800);
    public static inline function zinc900():Hsla return paletteColor('zinc', 900);
    public static inline function zinc950():Hsla return paletteColor('zinc', 950);

    /**
     * Get neutral by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function neutral(scale:Int):Hsla {

        return paletteColor('neutral', scale);

    }

    public static inline function neutral50():Hsla return paletteColor('neutral', 50);
    public static inline function neutral100():Hsla return paletteColor('neutral', 100);
    public static inline function neutral200():Hsla return paletteColor('neutral', 200);
    public static inline function neutral300():Hsla return paletteColor('neutral', 300);
    public static inline function neutral400():Hsla return paletteColor('neutral', 400);
    public static inline function neutral500():Hsla return paletteColor('neutral', 500);
    public static inline function neutral600():Hsla return paletteColor('neutral', 600);
    public static inline function neutral700():Hsla return paletteColor('neutral', 700);
    public static inline function neutral800():Hsla return paletteColor('neutral', 800);
    public static inline function neutral900():Hsla return paletteColor('neutral', 900);
    public static inline function neutral950():Hsla return paletteColor('neutral', 950);

    /**
     * Get stone by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function stone(scale:Int):Hsla {

        return paletteColor('stone', scale);

    }

    public static inline function stone50():Hsla return paletteColor('stone', 50);
    public static inline function stone100():Hsla return paletteColor('stone', 100);
    public static inline function stone200():Hsla return paletteColor('stone', 200);
    public static inline function stone300():Hsla return paletteColor('stone', 300);
    public static inline function stone400():Hsla return paletteColor('stone', 400);
    public static inline function stone500():Hsla return paletteColor('stone', 500);
    public static inline function stone600():Hsla return paletteColor('stone', 600);
    public static inline function stone700():Hsla return paletteColor('stone', 700);
    public static inline function stone800():Hsla return paletteColor('stone', 800);
    public static inline function stone900():Hsla return paletteColor('stone', 900);
    public static inline function stone950():Hsla return paletteColor('stone', 950);

    /**
     * Get red by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function red(scale:Int):Hsla {

        return paletteColor('red', scale);

    }

    public static inline function red50():Hsla return paletteColor('red', 50);
    public static inline function red100():Hsla return paletteColor('red', 100);
    public static inline function red200():Hsla return paletteColor('red', 200);
    public static inline function red300():Hsla return paletteColor('red', 300);
    public static inline function red400():Hsla return paletteColor('red', 400);
    public static inline function red500():Hsla return paletteColor('red', 500);
    public static inline function red600():Hsla return paletteColor('red', 600);
    public static inline function red700():Hsla return paletteColor('red', 700);
    public static inline function red800():Hsla return paletteColor('red', 800);
    public static inline function red900():Hsla return paletteColor('red', 900);
    public static inline function red950():Hsla return paletteColor('red', 950);

    /**
     * Get orange by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function orange(scale:Int):Hsla {

        return paletteColor('orange', scale);

    }

    public static inline function orange50():Hsla return paletteColor('orange', 50);
    public static inline function orange100():Hsla return paletteColor('orange', 100);
    public static inline function orange200():Hsla return paletteColor('orange', 200);
    public static inline function orange300():Hsla return paletteColor('orange', 300);
    public static inline function orange400():Hsla return paletteColor('orange', 400);
    public static inline function orange500():Hsla return paletteColor('orange', 500);
    public static inline function orange600():Hsla return paletteColor('orange', 600);
    public static inline function orange700():Hsla return paletteColor('orange', 700);
    public static inline function orange800():Hsla return paletteColor('orange', 800);
    public static inline function orange900():Hsla return paletteColor('orange', 900);
    public static inline function orange950():Hsla return paletteColor('orange', 950);

    /**
     * Get amber by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function amber(scale:Int):Hsla {

        return paletteColor('amber', scale);

    }

    public static inline function amber50():Hsla return paletteColor('amber', 50);
    public static inline function amber100():Hsla return paletteColor('amber', 100);
    public static inline function amber200():Hsla return paletteColor('amber', 200);
    public static inline function amber300():Hsla return paletteColor('amber', 300);
    public static inline function amber400():Hsla return paletteColor('amber', 400);
    public static inline function amber500():Hsla return paletteColor('amber', 500);
    public static inline function amber600():Hsla return paletteColor('amber', 600);
    public static inline function amber700():Hsla return paletteColor('amber', 700);
    public static inline function amber800():Hsla return paletteColor('amber', 800);
    public static inline function amber900():Hsla return paletteColor('amber', 900);
    public static inline function amber950():Hsla return paletteColor('amber', 950);

    /**
     * Get yellow by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function yellow(scale:Int):Hsla {

        return paletteColor('yellow', scale);

    }

    public static inline function yellow50():Hsla return paletteColor('yellow', 50);
    public static inline function yellow100():Hsla return paletteColor('yellow', 100);
    public static inline function yellow200():Hsla return paletteColor('yellow', 200);
    public static inline function yellow300():Hsla return paletteColor('yellow', 300);
    public static inline function yellow400():Hsla return paletteColor('yellow', 400);
    public static inline function yellow500():Hsla return paletteColor('yellow', 500);
    public static inline function yellow600():Hsla return paletteColor('yellow', 600);
    public static inline function yellow700():Hsla return paletteColor('yellow', 700);
    public static inline function yellow800():Hsla return paletteColor('yellow', 800);
    public static inline function yellow900():Hsla return paletteColor('yellow', 900);
    public static inline function yellow950():Hsla return paletteColor('yellow', 950);

    /**
     * Get lime by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function lime(scale:Int):Hsla {

        return paletteColor('lime', scale);

    }

    public static inline function lime50():Hsla return paletteColor('lime', 50);
    public static inline function lime100():Hsla return paletteColor('lime', 100);
    public static inline function lime200():Hsla return paletteColor('lime', 200);
    public static inline function lime300():Hsla return paletteColor('lime', 300);
    public static inline function lime400():Hsla return paletteColor('lime', 400);
    public static inline function lime500():Hsla return paletteColor('lime', 500);
    public static inline function lime600():Hsla return paletteColor('lime', 600);
    public static inline function lime700():Hsla return paletteColor('lime', 700);
    public static inline function lime800():Hsla return paletteColor('lime', 800);
    public static inline function lime900():Hsla return paletteColor('lime', 900);
    public static inline function lime950():Hsla return paletteColor('lime', 950);

    /**
     * Get green by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function green(scale:Int):Hsla {

        return paletteColor('green', scale);

    }

    public static inline function green50():Hsla return paletteColor('green', 50);
    public static inline function green100():Hsla return paletteColor('green', 100);
    public static inline function green200():Hsla return paletteColor('green', 200);
    public static inline function green300():Hsla return paletteColor('green', 300);
    public static inline function green400():Hsla return paletteColor('green', 400);
    public static inline function green500():Hsla return paletteColor('green', 500);
    public static inline function green600():Hsla return paletteColor('green', 600);
    public static inline function green700():Hsla return paletteColor('green', 700);
    public static inline function green800():Hsla return paletteColor('green', 800);
    public static inline function green900():Hsla return paletteColor('green', 900);
    public static inline function green950():Hsla return paletteColor('green', 950);

    /**
     * Get emerald by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function emerald(scale:Int):Hsla {

        return paletteColor('emerald', scale);

    }

    public static inline function emerald50():Hsla return paletteColor('emerald', 50);
    public static inline function emerald100():Hsla return paletteColor('emerald', 100);
    public static inline function emerald200():Hsla return paletteColor('emerald', 200);
    public static inline function emerald300():Hsla return paletteColor('emerald', 300);
    public static inline function emerald400():Hsla return paletteColor('emerald', 400);
    public static inline function emerald500():Hsla return paletteColor('emerald', 500);
    public static inline function emerald600():Hsla return paletteColor('emerald', 600);
    public static inline function emerald700():Hsla return paletteColor('emerald', 700);
    public static inline function emerald800():Hsla return paletteColor('emerald', 800);
    public static inline function emerald900():Hsla return paletteColor('emerald', 900);
    public static inline function emerald950():Hsla return paletteColor('emerald', 950);

    /**
     * Get teal by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function teal(scale:Int):Hsla {

        return paletteColor('teal', scale);

    }

    public static inline function teal50():Hsla return paletteColor('teal', 50);
    public static inline function teal100():Hsla return paletteColor('teal', 100);
    public static inline function teal200():Hsla return paletteColor('teal', 200);
    public static inline function teal300():Hsla return paletteColor('teal', 300);
    public static inline function teal400():Hsla return paletteColor('teal', 400);
    public static inline function teal500():Hsla return paletteColor('teal', 500);
    public static inline function teal600():Hsla return paletteColor('teal', 600);
    public static inline function teal700():Hsla return paletteColor('teal', 700);
    public static inline function teal800():Hsla return paletteColor('teal', 800);
    public static inline function teal900():Hsla return paletteColor('teal', 900);
    public static inline function teal950():Hsla return paletteColor('teal', 950);

    /**
     * Get cyan by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function cyan(scale:Int):Hsla {

        return paletteColor('cyan', scale);

    }

    public static inline function cyan50():Hsla return paletteColor('cyan', 50);
    public static inline function cyan100():Hsla return paletteColor('cyan', 100);
    public static inline function cyan200():Hsla return paletteColor('cyan', 200);
    public static inline function cyan300():Hsla return paletteColor('cyan', 300);
    public static inline function cyan400():Hsla return paletteColor('cyan', 400);
    public static inline function cyan500():Hsla return paletteColor('cyan', 500);
    public static inline function cyan600():Hsla return paletteColor('cyan', 600);
    public static inline function cyan700():Hsla return paletteColor('cyan', 700);
    public static inline function cyan800():Hsla return paletteColor('cyan', 800);
    public static inline function cyan900():Hsla return paletteColor('cyan', 900);
    public static inline function cyan950():Hsla return paletteColor('cyan', 950);

    /**
     * Get sky by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function sky(scale:Int):Hsla {

        return paletteColor('sky', scale);

    }

    public static inline function sky50():Hsla return paletteColor('sky', 50);
    public static inline function sky100():Hsla return paletteColor('sky', 100);
    public static inline function sky200():Hsla return paletteColor('sky', 200);
    public static inline function sky300():Hsla return paletteColor('sky', 300);
    public static inline function sky400():Hsla return paletteColor('sky', 400);
    public static inline function sky500():Hsla return paletteColor('sky', 500);
    public static inline function sky600():Hsla return paletteColor('sky', 600);
    public static inline function sky700():Hsla return paletteColor('sky', 700);
    public static inline function sky800():Hsla return paletteColor('sky', 800);
    public static inline function sky900():Hsla return paletteColor('sky', 900);
    public static inline function sky950():Hsla return paletteColor('sky', 950);

    /**
     * Get blue by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function blue(scale:Int):Hsla {

        return paletteColor('blue', scale);

    }

    public static inline function blue50():Hsla return paletteColor('blue', 50);
    public static inline function blue100():Hsla return paletteColor('blue', 100);
    public static inline function blue200():Hsla return paletteColor('blue', 200);
    public static inline function blue300():Hsla return paletteColor('blue', 300);
    public static inline function blue400():Hsla return paletteColor('blue', 400);
    public static inline function blue500():Hsla return paletteColor('blue', 500);
    public static inline function blue600():Hsla return paletteColor('blue', 600);
    public static inline function blue700():Hsla return paletteColor('blue', 700);
    public static inline function blue800():Hsla return paletteColor('blue', 800);
    public static inline function blue900():Hsla return paletteColor('blue', 900);
    public static inline function blue950():Hsla return paletteColor('blue', 950);

    /**
     * Get indigo by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function indigo(scale:Int):Hsla {

        return paletteColor('indigo', scale);

    }

    public static inline function indigo50():Hsla return paletteColor('indigo', 50);
    public static inline function indigo100():Hsla return paletteColor('indigo', 100);
    public static inline function indigo200():Hsla return paletteColor('indigo', 200);
    public static inline function indigo300():Hsla return paletteColor('indigo', 300);
    public static inline function indigo400():Hsla return paletteColor('indigo', 400);
    public static inline function indigo500():Hsla return paletteColor('indigo', 500);
    public static inline function indigo600():Hsla return paletteColor('indigo', 600);
    public static inline function indigo700():Hsla return paletteColor('indigo', 700);
    public static inline function indigo800():Hsla return paletteColor('indigo', 800);
    public static inline function indigo900():Hsla return paletteColor('indigo', 900);
    public static inline function indigo950():Hsla return paletteColor('indigo', 950);

    /**
     * Get violet by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function violet(scale:Int):Hsla {

        return paletteColor('violet', scale);

    }

    public static inline function violet50():Hsla return paletteColor('violet', 50);
    public static inline function violet100():Hsla return paletteColor('violet', 100);
    public static inline function violet200():Hsla return paletteColor('violet', 200);
    public static inline function violet300():Hsla return paletteColor('violet', 300);
    public static inline function violet400():Hsla return paletteColor('violet', 400);
    public static inline function violet500():Hsla return paletteColor('violet', 500);
    public static inline function violet600():Hsla return paletteColor('violet', 600);
    public static inline function violet700():Hsla return paletteColor('violet', 700);
    public static inline function violet800():Hsla return paletteColor('violet', 800);
    public static inline function violet900():Hsla return paletteColor('violet', 900);
    public static inline function violet950():Hsla return paletteColor('violet', 950);

    /**
     * Get purple by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function purple(scale:Int):Hsla {

        return paletteColor('purple', scale);

    }

    public static inline function purple50():Hsla return paletteColor('purple', 50);
    public static inline function purple100():Hsla return paletteColor('purple', 100);
    public static inline function purple200():Hsla return paletteColor('purple', 200);
    public static inline function purple300():Hsla return paletteColor('purple', 300);
    public static inline function purple400():Hsla return paletteColor('purple', 400);
    public static inline function purple500():Hsla return paletteColor('purple', 500);
    public static inline function purple600():Hsla return paletteColor('purple', 600);
    public static inline function purple700():Hsla return paletteColor('purple', 700);
    public static inline function purple800():Hsla return paletteColor('purple', 800);
    public static inline function purple900():Hsla return paletteColor('purple', 900);
    public static inline function purple950():Hsla return paletteColor('purple', 950);

    /**
     * Get fuchsia by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function fuchsia(scale:Int):Hsla {

        return paletteColor('fuchsia', scale);

    }

    public static inline function fuchsia50():Hsla return paletteColor('fuchsia', 50);
    public static inline function fuchsia100():Hsla return paletteColor('fuchsia', 100);
    public static inline function fuchsia200():Hsla return paletteColor('fuchsia', 200);
    public static inline function fuchsia300():Hsla return paletteColor('fuchsia', 300);
    public static inline function fuchsia400():Hsla return paletteColor('fuchsia', 400);
    public static inline function fuchsia500():Hsla return paletteColor('fuchsia', 500);
    public static inline function fuchsia600():Hsla return paletteColor('fuchsia', 600);
    public static inline function fuchsia700():Hsla return paletteColor('fuchsia', 700);
    public static inline function fuchsia800():Hsla return paletteColor('fuchsia', 800);
    public static inline function fuchsia900():Hsla return paletteColor('fuchsia', 900);
    public static inline function fuchsia950():Hsla return paletteColor('fuchsia', 950);

    /**
     * Get pink by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function pink(scale:Int):Hsla {

        return paletteColor('pink', scale);

    }

    public static inline function pink50():Hsla return paletteColor('pink', 50);
    public static inline function pink100():Hsla return paletteColor('pink', 100);
    public static inline function pink200():Hsla return paletteColor('pink', 200);
    public static inline function pink300():Hsla return paletteColor('pink', 300);
    public static inline function pink400():Hsla return paletteColor('pink', 400);
    public static inline function pink500():Hsla return paletteColor('pink', 500);
    public static inline function pink600():Hsla return paletteColor('pink', 600);
    public static inline function pink700():Hsla return paletteColor('pink', 700);
    public static inline function pink800():Hsla return paletteColor('pink', 800);
    public static inline function pink900():Hsla return paletteColor('pink', 900);
    public static inline function pink950():Hsla return paletteColor('pink', 950);

    /**
     * Get rose by scale number (50, 100, 200, ..., 900, 950); black if the
     * scale is not found.
     */
    public static inline function rose(scale:Int):Hsla {

        return paletteColor('rose', scale);

    }

    public static inline function rose50():Hsla return paletteColor('rose', 50);
    public static inline function rose100():Hsla return paletteColor('rose', 100);
    public static inline function rose200():Hsla return paletteColor('rose', 200);
    public static inline function rose300():Hsla return paletteColor('rose', 300);
    public static inline function rose400():Hsla return paletteColor('rose', 400);
    public static inline function rose500():Hsla return paletteColor('rose', 500);
    public static inline function rose600():Hsla return paletteColor('rose', 600);
    public static inline function rose700():Hsla return paletteColor('rose', 700);
    public static inline function rose800():Hsla return paletteColor('rose', 800);
    public static inline function rose900():Hsla return paletteColor('rose', 900);
    public static inline function rose950():Hsla return paletteColor('rose', 950);

}

private typedef ParsedLinearGradient = {
    var angle:Float;
    var from:LinearColorStop;
    var to:LinearColorStop;
}

package tests;

import gpui.Background;
import gpui.Hsla;
import gpui.Prelude.*;
import gpui.component.theme.Color;
import gpui.component.theme.Color.*;
import gpui.component.theme.ColorName;
import testing.TestCase;

using gpui.component.theme.Colorize;

/**
 * Tests of gpui-kit's color helpers (crates/component/src/theme/color.rs): the
 * Rust unit tests, and every helper compared with the values dumped from the
 * original by `reference/examples/theme_dump.rs`.
 */
class ColorHelpersTest extends TestCase {

    /**
     * Rust computes in f32, the port in f64.
     */
    public static inline final EPSILON:Float = 1e-5;

    static function close(expected:Dynamic, actual:Float):Bool {
        if (expected == null) return Math.isNaN(actual) || !Math.isFinite(actual);
        return Math.abs((expected:Float) - actual) <= EPSILON;
    }

    /**
     * The difference between a dumped `[h, s, l, a]` and a color: the
     * smaller of the HSLA difference and the RGBA difference.
     *
     * HSLA is ill-conditioned near gray, black and white: there the f32
     * rounding noise of Rust gives a color a saturation of 1e-7 and any hue
     * (an OkLCH gray), or a saturation of 0.67 instead of 1 for a lightness of
     * 0.9999998. Both describe the same RGBA color, which is what is painted.
     * The hue is compared on the circle (0 and 1 are the same hue).
     */
    public static function colorError(expected:Array<Dynamic>, actual:Hsla):Float {
        if (actual == null) return Math.POSITIVE_INFINITY;
        for (i in 0...4) {
            if (expected[i] == null) return Math.POSITIVE_INFINITY;
        }
        final e = new Hsla(expected[0], expected[1], expected[2], expected[3]);
        var dh = Math.abs(e.h - actual.h);
        dh = Math.min(dh, Math.abs(1.0 - dh));
        var hsla = Math.max(dh, Math.max(Math.abs(e.s - actual.s), Math.max(Math.abs(e.l - actual.l), Math.abs(e.a - actual.a))));
        final er = e.toRgb();
        final ar = actual.toRgb();
        final rgba = Math.max(Math.abs(er.r - ar.r), Math.max(Math.abs(er.g - ar.g), Math.max(Math.abs(er.b - ar.b), Math.abs(er.a - ar.a))));
        final error = Math.min(hsla, rgba);
        return Math.isNaN(error) ? Math.POSITIVE_INFINITY : error;
    }

    /**
     * The largest difference between a dumped background and a background.
     */
    public static function backgroundError(expected:Dynamic, actual:Background):Float {
        if (actual == null) return Math.POSITIVE_INFINITY;
        final tag:String = expected.tag;
        if (expected.color_space != 'Srgb' || actual.colorSpace != Srgb) return Math.POSITIVE_INFINITY;
        switch tag {
            case 'Solid':
                if (actual.tag != Solid) return Math.POSITIVE_INFINITY;
                return colorError(expected.solid, actual.solid);
            case 'LinearGradient':
                if (actual.tag != LinearGradient) return Math.POSITIVE_INFINITY;
                final stops:Array<Array<Dynamic>> = expected.stops;
                var max = Math.abs((expected.angle:Float) - actual.gradientAngleOrPatternHeight);
                max = Math.max(max, colorError(stops[0], actual.colors0.color));
                max = Math.max(max, Math.abs((stops[0][4]:Float) - actual.colors0.percentage));
                max = Math.max(max, colorError(stops[1], actual.colors1.color));
                max = Math.max(max, Math.abs((stops[1][4]:Float) - actual.colors1.percentage));
                return max;
            case _:
                return Math.POSITIVE_INFINITY;
        }
    }

    function assertColor(expected:Array<Dynamic>, actual:Hsla, label:String, ?pos:haxe.PosInfos) {
        final error = colorError(expected, actual);
        assertTrue(error <= EPSILON, '$label: expected $expected but got ${actual == null ? 'null' : '[${actual.h}, ${actual.s}, ${actual.l}, ${actual.a}]'} (error $error)', pos);
    }

    function hslaEq(a:Hsla, b:Hsla):Bool {
        return colorError([b.h, b.s, b.l, b.a], a) <= EPSILON;
    }

    // Rust #[cfg(test)]

    function testDefaultColors() {
        assertTrue(white().equals(hsl(0.0, 0.0, 100.0)));
        assertTrue(black().equals(hsl(0.0, 0.0, 0.0)));

        assertTrue(slate50().equals(hsl(210.0, 40.0, 98.0)));
        assertTrue(slate100().equals(hsl(210.0, 40.0, 96.1)));
        assertTrue(slate900().equals(hsl(222.2, 47.4, 11.2)));

        assertTrue(red50().equals(hsl(0.0, 85.7, 97.3)));
        assertTrue(yellow100().equals(hsl(54.9, 96.7, 88.0)));
        assertTrue(green200().equals(hsl(141.0, 78.9, 85.1)));
        assertTrue(cyan300().equals(hsl(187.0, 92.4, 69.0)));
        assertTrue(blue400().equals(hsl(213.1, 93.9, 67.8)));
        assertTrue(indigo500().equals(hsl(238.7, 83.5, 66.7)));
    }

    function testToHexString() {
        assertEquals('#F8FAFC', Hsla.fromRgba(rgb(0xf8fafc)).toHex());
        assertEquals('#FEF2F2', Hsla.fromRgba(rgb(0xfef2f2)).toHex());
        // `toHex` truncates channels computed in f32. `rgba(0x0413fcaa).into()`
        // is converted in f64 by the port, which puts the green channel at
        // 18.99999 instead of Rust's 19.00000: the check uses the exact f32
        // color Rust gets (dumped by theme_dump.rs, `#0413FCAA` parsed).
        final colors:Array<Array<Float>> = ThemeReference.data().helpers.colors;
        final c = colors[8];
        assertEquals('#0413FCAA', new Hsla(c[0], c[1], c[2], c[3]).toHex());
    }

    function testFromHexString() {
        assertTrue(Colorize.parseHex('#F8FAFC').equals(Hsla.fromRgba(rgb(0xf8fafc))));
        assertTrue(Colorize.parseHex('#FEF2F2').equals(Hsla.fromRgba(rgb(0xfef2f2))));
        assertTrue(Colorize.parseHex('#0413FCAA').equals(Hsla.fromRgba(rgba(0x0413fcaa))));
    }

    function testLighten() {
        var color = hsl(240.0, 5.0, 30.0);
        color = color.lighten(0.5);
        assertFloatEquals(0.45000002, color.l, 1e-7);
        color = color.lighten(0.5);
        assertFloatEquals(0.675, color.l, 1e-7);
        color = color.lighten(0.1);
        assertFloatEquals(0.7425, color.l, 1e-7);
    }

    function testDarken() {
        var color = hsl(240.0, 5.0, 96.0);
        color = color.darken(0.5);
        assertFloatEquals(0.48, color.l, 1e-7);
        color = color.darken(0.5);
        assertFloatEquals(0.24, color.l, 1e-7);
    }

    function testMix() {
        final red = Colorize.parseHex('#FF0000');
        final blue = Colorize.parseHex('#0000FF');
        final green = Colorize.parseHex('#00FF00');
        final yellow = Colorize.parseHex('#FFFF00');

        assertEquals('#FF00FF', red.mix(blue, 0.5).toHex());
        assertEquals('#FFFF00', green.mix(red, 0.5).toHex());
        assertEquals('#0098FF', blue.mix(yellow, 0.2).toHex());
    }

    function testMixOklab() {
        final red = Colorize.parseHex('#FF0000');
        final blue = Colorize.parseHex('#0000FF');
        final transparent = new Hsla(0.0, 0.0, 0.0, 0.0);

        // color-mix(in oklab, red 20%, transparent) should give red with 20% opacity
        final result = red.mixOklab(transparent, 0.2);
        assertTrue(Math.abs(result.a - 0.2) < 0.01);

        // The color should remain red (hue should be preserved)
        final rgbResult = result.toRgb();
        final rgbRed = red.toRgb();
        assertTrue(Math.abs(rgbResult.r - rgbRed.r) < 0.05, 'Red channel should be preserved');
        assertTrue(rgbResult.g < 0.05, 'Green channel should be near 0');
        assertTrue(rgbResult.b < 0.05, 'Blue channel should be near 0');

        // Oklab mixing should produce different results than HSL mixing
        final purple = red.mixOklab(blue, 0.5);
        final purpleHsl = red.mix(blue, 0.5);
        assertTrue(purple.toHex() != purpleHsl.toHex());

        // Test factor boundaries
        final rgb0 = red.mixOklab(blue, 0.0).toRgb();
        final rgbBlue = blue.toRgb();
        assertTrue(Math.abs(rgb0.r - rgbBlue.r) < 0.01);
        assertTrue(Math.abs(rgb0.g - rgbBlue.g) < 0.01);
        assertTrue(Math.abs(rgb0.b - rgbBlue.b) < 0.01);

        final rgb1 = red.mixOklab(blue, 1.0).toRgb();
        assertTrue(Math.abs(rgb1.r - rgbRed.r) < 0.01);
        assertTrue(Math.abs(rgb1.g - rgbRed.g) < 0.01);
        assertTrue(Math.abs(rgb1.b - rgbRed.b) < 0.01);
    }

    function testColorName() {
        assertEquals('Purple', ColorName.Purple.toString());
        assertEquals('Green', ColorName.Green.toString());

        final color = ColorName.Green;
        assertEquals('#21C55E', color.scale(500).toHex());
        assertEquals('#21C55E', color.scale(1500).toHex());

        for (name in ColorName.all()) {
            assertEquals(name, ColorName.tryFrom(name.toString()));
        }
    }

    function testHSL() {
        final color = hsl(260., 94., 80.);
        assertTrue(hslaEq(color.hue(200. / 360.), hsl(200., 94., 80.)));
        assertTrue(hslaEq(color.saturation(74. / 100.), hsl(260., 74., 80.)));
        assertTrue(hslaEq(color.lightness(74. / 100.), hsl(260., 94., 74.)));
    }

    function testTryParseColor() {
        assertTrue(hslaEq(tryParseColor('#F2F200'), hsla(0.16666667, 1., 0.4745098, 1.0)));
        assertTrue(hslaEq(tryParseColor('#00f21888'), hsla(0.34986225, 1.0, 0.4745098, 0.53333336)));
        assertTrue(tryParseColor('black').equals(black()));
        assertTrue(tryParseColor('white-800').equals(white()));
        assertTrue(tryParseColor('red').equals(red500()));
        assertTrue(tryParseColor('blue-600').equals(blue600()));
        assertTrue(tryParseColor('pink/33').equals(pink500().opacity(0.33)));
        assertTrue(tryParseColor('orange-300/66').equals(orange300().opacity(0.66)));
    }

    function testTryParseBackgroundLinearGradient() {
        final from = tryParseColor('#4F46E5');
        final to = tryParseColor('#06B6D4');
        assertTrue(tryParseBackground('linear-gradient(135deg, #4F46E5, #06B6D4)')
            .equals(linearGradient(135., linearColorStop(from, 0.), linearColorStop(to, 1.))));
    }

    function testTryParseBackgroundLinearGradientDirectionAndStops() {
        assertTrue(tryParseBackground('linear-gradient(to right, red-500 25%, blue-600 75%)')
            .equals(linearGradient(90., linearColorStop(red500(), 0.25), linearColorStop(blue600(), 0.75))));
    }

    // Comparison with the values dumped from gpui-kit

    var maxError:Float = 0;

    function check(expected:Array<Dynamic>, actual:Hsla, label:String, ?pos:haxe.PosInfos) {
        final error = colorError(expected, actual);
        if (error > maxError) maxError = error;
        if (error > EPSILON) assertColor(expected, actual, label, pos);
        else assertions++;
    }

    function referenceColors():Array<Hsla> {
        final helpers:Dynamic = ThemeReference.data().helpers;
        final list:Array<Array<Float>> = helpers.colors;
        // The inputs are rebuilt from their dumped components, exactly.
        return [for (c in list) new Hsla(c[0], c[1], c[2], c[3])];
    }

    function testUnaryHelpersMatchGpuiKit() {
        final helpers:Dynamic = ThemeReference.data().helpers;
        final colors = referenceColors();
        final factors:Array<Float> = helpers.factors;
        final ops:Array<{name:String, op:(Hsla, Float) -> Hsla}> = [
            {name: 'opacity', op: (c, k) -> c.opacity(k)},
            {name: 'divide', op: (c, k) -> c.divide(k)},
            {name: 'lighten', op: (c, k) -> c.lighten(k)},
            {name: 'darken', op: (c, k) -> c.darken(k)},
            {name: 'hue', op: (c, k) -> c.hue(k)},
            {name: 'saturation', op: (c, k) -> c.saturation(k)},
            {name: 'lightness', op: (c, k) -> c.lightness(k)},
        ];
        maxError = 0;
        for (entry in ops) {
            final rows:Array<Array<Array<Dynamic>>> = Reflect.field(helpers, entry.name);
            for (i in 0...colors.length) {
                for (j in 0...factors.length) {
                    check(rows[i][j], entry.op(colors[i], factors[j]), '${entry.name}(#$i, ${factors[j]})');
                }
            }
        }
        final invert:Array<Array<Dynamic>> = helpers.invert;
        final invertL:Array<Array<Dynamic>> = helpers.invert_l;
        final toHex:Array<String> = helpers.to_hex;
        for (i in 0...colors.length) {
            check(invert[i], colors[i].invert(), 'invert(#$i)');
            check(invertL[i], colors[i].invertL(), 'invertL(#$i)');
            assertEquals(toHex[i], colors[i].toHex(), 'toHex(#$i)');
        }
        ColorReport.add('unary helpers (opacity, divide, lighten, darken, hue, saturation, lightness, invert)', maxError);
    }

    function testBinaryHelpersMatchGpuiKit() {
        final helpers:Dynamic = ThemeReference.data().helpers;
        final colors = referenceColors();
        final factors:Array<Float> = helpers.mix_factors;
        for (name in ['mix', 'mix_oklab']) {
            maxError = 0;
            final rows:Array<Array<Array<Dynamic>>> = Reflect.field(helpers, name);
            var row = 0;
            for (a in 0...colors.length) {
                for (b in 0...colors.length) {
                    for (k in 0...factors.length) {
                        final actual = name == 'mix' ? colors[a].mix(colors[b], factors[k]) : colors[a].mixOklab(colors[b], factors[k]);
                        check(rows[row][k], actual, '$name(#$a, #$b, ${factors[k]})');
                    }
                    row++;
                }
            }
            ColorReport.add(name, maxError);
        }
        maxError = 0;
        final blend:Array<Array<Array<Dynamic>>> = helpers.blend;
        final apply:Array<Array<Array<Dynamic>>> = helpers.apply;
        for (a in 0...colors.length) {
            for (b in 0...colors.length) {
                check(blend[a][b], colors[a].blend(colors[b]), 'blend(#$a, #$b)');
                check(apply[a][b], colors[a].apply(colors[b]), 'apply(#$a, #$b)');
            }
        }
        ColorReport.add('blend, apply', maxError);
    }

    function testParsersMatchGpuiKit() {
        final helpers:Dynamic = ThemeReference.data().helpers;
        maxError = 0;
        final parseHex:Array<Array<Dynamic>> = helpers.parse_hex;
        for (entry in parseHex) {
            final input:String = entry[0];
            final actual = Colorize.parseHex(input);
            if (entry[1] == null) assertNull(actual, 'parseHex("$input")');
            else check(entry[1], actual, 'parseHex("$input")');
        }
        final parseColor:Array<Array<Dynamic>> = helpers.try_parse_color;
        for (entry in parseColor) {
            final input:String = entry[0];
            final actual = tryParseColor(input);
            if (entry[1] == null) assertNull(actual, 'tryParseColor("$input")');
            else check(entry[1], actual, 'tryParseColor("$input")');
        }
        final parseBackground:Array<Array<Dynamic>> = helpers.try_parse_background;
        for (entry in parseBackground) {
            final input:String = entry[0];
            final actual = tryParseBackground(input);
            if (entry[1] == null) {
                assertNull(actual, 'tryParseBackground("$input")');
            }
            else {
                final error = backgroundError(entry[1], actual);
                if (error > maxError) maxError = error;
                assertTrue(error <= EPSILON, 'tryParseBackground("$input"): expected ${haxe.Json.stringify(entry[1])} but got $actual');
            }
        }
        ColorReport.add('parseHex, tryParseColor, tryParseBackground', maxError);
    }

    function testPaletteMatchesGpuiKit() {
        final helpers:Dynamic = ThemeReference.data().helpers;
        final palette:Dynamic = helpers.palette;
        final scales = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950, 0, 1500];
        maxError = 0;
        check(palette.black, black(), 'black');
        check(palette.white, white(), 'white');
        for (name in gpui.component.theme.ShadcnColors.NAMES) {
            final expected:Array<Array<Dynamic>> = Reflect.field(palette, name);
            for (i in 0...scales.length) {
                check(expected[i], @:privateAccess Color.paletteColor(name, scales[i]), '$name(${scales[i]})');
            }
        }
        // The fixed scale functions are the same lookups
        check(Reflect.field(palette, 'rose')[5], rose500(), 'rose500');
        check(Reflect.field(palette, 'rose')[5], rose(500), 'rose(500)');
        check(Reflect.field(palette, 'slate')[10], slate950(), 'slate950');
        check(Reflect.field(palette, 'zinc')[12], zinc(1500), 'zinc(1500)');

        final names:Array<Dynamic> = helpers.color_names;
        final all = [ColorName.White, ColorName.Black].concat(ColorName.all());
        assertEquals(names.length, all.length);
        for (i in 0...names.length) {
            assertEquals(names[i].name, all[i].toString());
            final expected:Array<Array<Dynamic>> = names[i].scales;
            for (j in 0...scales.length) {
                check(expected[j], all[i].scale(scales[j]), '${all[i]}.scale(${scales[j]})');
            }
        }

        final oklchGrid:Array<Array<Dynamic>> = helpers.oklch;
        for (entry in oklchGrid) {
            check(entry[3], oklch(entry[0], entry[1], entry[2]), 'oklch(${entry[0]}, ${entry[1]}, ${entry[2]})');
        }
        final hslGrid:Array<Array<Dynamic>> = helpers.hsl;
        for (entry in hslGrid) {
            check(entry[3], hsl(entry[0], entry[1], entry[2]), 'hsl(${entry[0]}, ${entry[1]}, ${entry[2]})');
        }
        ColorReport.add('palette, ColorName.scale, oklch, hsl', maxError);
    }

}

/**
 * Collects the largest error of every comparison with gpui-kit, printed once
 * at the end of the theme tests.
 */
class ColorReport {

    public static final lines:Array<String> = [];

    public static function add(label:String, maxError:Float):Void {
        lines.push('  $label: max error ${maxError}');
    }

}

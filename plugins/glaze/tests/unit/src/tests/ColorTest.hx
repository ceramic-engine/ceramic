package tests;

import gpui.*;
import gpui.Prelude.*;
import testing.TestCase;

/**
 * Tests of the color port (src/color.rs, src/colors.rs): the Rust unit tests
 * and extra checks.
 */
class ColorTest extends TestCase {

    // Rust #[cfg(test)]

    function testDeserializeThreeValueHexToRgba() {

        assertTrue(Rgba.parse('#f09').equals(rgba(0xff0099ff)));

    }

    function testDeserializeFourValueHexToRgba() {

        assertTrue(Rgba.parse('#f09f').equals(rgba(0xff0099ff)));

    }

    function testDeserializeSixValueHexToRgba() {

        assertTrue(Rgba.parse('#ff0099').equals(rgba(0xff0099ff)));

    }

    function testDeserializeEightValueHexToRgba() {

        assertTrue(Rgba.parse('#ff0099ff').equals(rgba(0xff0099ff)));

    }

    function testDeserializeEightValueHexWithPaddingToRgba() {

        assertTrue(Rgba.parse(' #f5f5f5ff   ').equals(rgba(0xf5f5f5ff)));

    }

    function testDeserializeEightValueHexWithMixedCaseToRgba() {

        assertTrue(Rgba.parse('#DeAdbEeF').equals(rgba(0xdeadbeef)));

    }

    function testBackgroundSolid() {

        final color = Hsla.fromRgba(rgba(0xff0099ff));
        final background = Background.fromHsla(color);
        assertEquals(BackgroundTag.Solid, background.tag);
        assertTrue(background.solid.equals(color));

        assertTrue(background.opacity(0.5).solid.equals(color.opacity(0.5)));
        assertFalse(background.isTransparent());
        final transparent = new Background(background.tag, background.colorSpace, hsla(0, 0, 0, 0));
        assertTrue(transparent.isTransparent());

    }

    function testBackgroundLinearGradient() {

        final from = linearColorStop(rgba(0xff0099ff), 0.0);
        final to = linearColorStop(rgba(0x00ff99ff), 1.0);
        final background = linearGradient(90.0, from, to);
        assertEquals(BackgroundTag.LinearGradient, background.tag);
        assertTrue(background.colors0.equals(from));
        assertTrue(background.colors1.equals(to));

        assertTrue(background.opacity(0.5).colors0.equals(from.opacity(0.5)));
        assertTrue(background.opacity(0.5).colors1.equals(to.opacity(0.5)));
        assertFalse(background.isTransparent());
        assertTrue(background.opacity(0.0).isTransparent());

    }

    function testRgbaAlpha() {

        final color = new Rgba(0.2, 0.6, 1.0, 0.8);
        assertEquals(0.25, color.alpha(0.25).a);
        assertEquals(1.0, color.alpha(1.5).a);

    }

    function testRgbaOpacity() {

        final color = new Rgba(0.2, 0.6, 1.0, 0.8);
        assertTrue(Math.abs(color.opacity(0.5).a - 0.4) < 1e-6);
        assertEquals(0.8, color.opacity(2.0).a);

    }

    // Extra checks

    function testRgbAndRgbaHelpers() {

        final c = rgb(0x336699);
        assertFloatEquals(0x33 / 255.0, c.r);
        assertFloatEquals(0x66 / 255.0, c.g);
        assertFloatEquals(0x99 / 255.0, c.b);
        assertEquals(1.0, c.a);

        final d = rgba(0x11223344);
        assertFloatEquals(0x11 / 255.0, d.r);
        assertFloatEquals(0x44 / 255.0, d.a);

        assertEquals(0xff0099ff, rgba(0xff0099ff).toU32());
        assertEquals(0x11223344, d.toU32());
        assertEquals('#ff0099ff', rgba(0xff0099ff).toHexString());
        assertEquals('rgba(0xdeadbeef)', rgba(0xdeadbeef).toString());

    }

    function testHexParsingErrors() {

        assertNull(Rgba.tryParse('ff0099'));
        assertNull(Rgba.tryParse('#ff000'));
        assertTrue(Rgba.parse('#ff00').equals(new Rgba(1, 1, 0, 0)));
        assertNull(Rgba.tryParse('#ff00999'));
        assertNull(Rgba.tryParse('#gg0099'));
        assertNull(Rgba.tryParse('#'));
        assertNull(Rgba.tryParse(''));
        assertNull(Rgba.tryParse('x#fff'));
        assertRaises(() -> Rgba.parse('#12'));
        assertTrue(Rgba.parse('#000').equals(new Rgba(0, 0, 0, 1)));
        assertTrue(Rgba.parse('#FFF0').equals(new Rgba(1, 1, 1, 0)));
        assertTrue(Hsla.parse('#ff0000').equals(red()));

    }

    function testHslaToRgba() {

        assertTrue(red().toRgb().equals(new Rgba(1, 0, 0, 1)));
        assertTrue(white().toRgb().equals(new Rgba(1, 1, 1, 1)));
        assertTrue(black().toRgb().equals(new Rgba(0, 0, 0, 1)));
        final blueRgb = blue().toRgb();
        assertFloatEquals(0, blueRgb.r);
        assertFloatEquals(0, blueRgb.g);
        assertFloatEquals(1, blueRgb.b);
        final greenRgb = green().toRgb();
        assertFloatEquals(0, greenRgb.r);
        assertFloatEquals(0.5, greenRgb.g);
        assertFloatEquals(0, greenRgb.b);
        final yellowRgb = yellow().toRgb();
        assertFloatEquals(1, yellowRgb.r);
        assertFloatEquals(1, yellowRgb.g);
        assertFloatEquals(0, yellowRgb.b);

        // Hue 1.0 wraps to red
        final wrapped = hsla(1, 1, 0.5, 1).toRgb();
        assertFloatEquals(1, wrapped.r);
        assertFloatEquals(0, wrapped.g);
        assertFloatEquals(0, wrapped.b);

    }

    function testRgbaToHsla() {

        final hsla = Hsla.fromRgba(rgba(0xff0099ff));
        assertFloatEquals(324.0 / 360.0, hsla.h);
        assertFloatEquals(1.0, hsla.s);
        assertFloatEquals(0.5, hsla.l);
        assertEquals(1.0, hsla.a);

        final grey = Hsla.fromRgba(new Rgba(0.5, 0.5, 0.5, 0.25));
        assertEquals(0.0, grey.h);
        assertEquals(0.0, grey.s);
        assertFloatEquals(0.5, grey.l);
        assertEquals(0.25, grey.a);

        // Negative hue from the red sector wraps around (rem_euclid)
        final magenta = Hsla.fromRgba(new Rgba(1, 0, 0.5, 1));
        assertFloatEquals(330.0 / 360.0, magenta.h);

    }

    function testColorRoundTrips() {

        final samples = [0x000000ff, 0xffffffff, 0xff0099ff, 0x336699ff, 0xdeadbeef, 0x12345678, 0x808080ff, 0x00ff0080, 0x0000ffff, 0xf5f5f5ff];
        for (hex in samples) {
            final original = rgba(hex);
            final back = original.toHsla().toRgb();
            assertFloatEquals(original.r, back.r, 1e-6, 'r of $original');
            assertFloatEquals(original.g, back.g, 1e-6, 'g of $original');
            assertFloatEquals(original.b, back.b, 1e-6, 'b of $original');
            assertEquals(original.a, back.a);
        }

        var h = 0.0;
        while (h < 1.0) {
            final original = hsla(h, 0.7, 0.4, 1);
            final back = original.toRgb().toHsla();
            assertFloatEquals(original.h, back.h, 1e-6, 'h of $original');
            assertFloatEquals(original.s, back.s, 1e-6, 's of $original');
            assertFloatEquals(original.l, back.l, 1e-6, 'l of $original');
            h += 0.05;
        }

    }

    function testHslaHelpers() {

        assertTrue(hsla(-1, 2, 0.5, 3).equals(new Hsla(0, 1, 0.5, 1)));
        assertTrue(transparentBlack().isTransparent());
        assertTrue(transparentWhite().isTransparent());
        assertTrue(white().isOpaque());
        assertTrue(opaqueGrey(2, 0.5).equals(new Hsla(0, 0, 1, 0.5)));

        final color = hsla(0.5, 0.8, 0.4, 0.8);
        assertTrue(color.grayscale().equals(new Hsla(0.5, 0, 0.4, 0.8)));
        assertFloatEquals(0.2, color.fadeOut(0.75).a);
        assertFloatEquals(0.8, color.fadeOut(-1).a);
        assertFloatEquals(0.4, color.opacity(0.5).a);
        assertFloatEquals(0.8, color.opacity(3).a);
        assertEquals(0.3, color.alpha(0.3).a);

        assertTrue(Hsla.red().compare(Hsla.blue()) < 0);
        assertEquals(0, Hsla.red().compare(red()));
        assertTrue(new Hsla(Math.NaN, 0, 0, 0).equals(new Hsla(Math.NaN, 0, 0, 0)));

        assertEquals('hsla(324.00, 100.00%, 50.00%, 1.00)', Hsla.fromRgba(rgba(0xff0099ff)).toString());

    }

    function testBlend() {

        final base = new Rgba(1, 0, 0, 1);
        assertTrue(base.blend(new Rgba(0, 0, 1, 1)).equals(new Rgba(0, 0, 1, 1)));
        assertTrue(base.blend(new Rgba(0, 0, 1, 0)).equals(base));
        final mixed = base.blend(new Rgba(0, 0, 1, 0.25));
        assertFloatEquals(0.75, mixed.r);
        assertFloatEquals(0.25, mixed.b);
        assertEquals(1.0, mixed.a);

        final hslaMixed = red().blend(blue().opacity(0.5));
        final rgbMixed = hslaMixed.toRgb();
        assertFloatEquals(0.5, rgbMixed.r);
        assertFloatEquals(0.0, rgbMixed.g);
        assertFloatEquals(0.5, rgbMixed.b);
        assertTrue(red().blend(transparentBlack()).equals(red()));
        assertTrue(red().blend(blue()).equals(blue()));

    }

    function testBackgrounds() {

        final defaultBackground = new Background();
        assertEquals(BackgroundTag.Solid, defaultBackground.tag);
        assertEquals(ColorSpace.Srgb, defaultBackground.colorSpace);
        assertTrue(defaultBackground.isTransparent());
        assertTrue(defaultBackground.asSolid().equals(new Hsla()));

        final fromRgba = Background.fromRgba(rgb(0xff0000));
        assertTrue(fromRgba.asSolid().equals(red()));

        final solid = solidBackground(rgb(0xff0000));
        assertTrue(solid.equals(fromRgba));

        final gradient = linearGradient(45, linearColorStop(red(), 0), linearColorStop(blue(), 1)).withColorSpace(Oklab);
        assertEquals(ColorSpace.Oklab, gradient.colorSpace);
        assertEquals(45.0, gradient.gradientAngleOrPatternHeight);
        assertNull(gradient.asSolid());
        assertEquals('Oklab', gradient.colorSpace.toString());

        final pattern = patternSlash(red(), 1.0, 2.0);
        assertEquals(BackgroundTag.PatternSlash, pattern.tag);
        assertEquals(255.0 * 0xFFFF + 510.0, pattern.gradientAngleOrPatternHeight);
        // Decoded like the shader does
        assertFloatEquals(1.0, Math.ffloor(pattern.gradientAngleOrPatternHeight / 65535.0) / 255.0);
        assertFloatEquals(2.0, (pattern.gradientAngleOrPatternHeight % 65535.0) / 255.0);

        final board = checkerboard(rgb(0x00ff00), 8);
        assertEquals(BackgroundTag.Checkerboard, board.tag);
        assertEquals(8.0, board.gradientAngleOrPatternHeight);
        assertFalse(board.isTransparent());

        final into:IntoBackground = red();
        assertTrue((into:Background).equals(Background.fromHsla(red())));

    }

    function testColors() {

        final light = Colors.light();
        assertTrue(light.text.equals(rgb(0x252525)));
        assertTrue(light.container.equals(rgb(0xf4f5f5)));
        final dark = Colors.forAppearance(Dark);
        assertTrue(dark.background.equals(rgb(0x222222)));
        assertTrue(dark.selected.equals(rgb(0x2457ca)));
        assertTrue(Colors.defaultValue().border.equals(rgb(0xd9d9d9)));

    }

    function testSwapRgbaPaToBgra() {

        final bytes = haxe.io.Bytes.alloc(8);
        // Premultiplied rgba(100, 50, 25, 128), then a transparent pixel
        bytes.set(0, 50);
        bytes.set(1, 25);
        bytes.set(2, 12);
        bytes.set(3, 128);
        bytes.set(4, 1);
        bytes.set(5, 2);
        bytes.set(6, 3);
        bytes.set(7, 0);
        swapRgbaPaToBgra(bytes, 0);
        swapRgbaPaToBgra(bytes, 4);
        assertEquals(23, bytes.get(0));
        assertEquals(49, bytes.get(1));
        assertEquals(99, bytes.get(2));
        assertEquals(128, bytes.get(3));
        assertEquals(3, bytes.get(4));
        assertEquals(2, bytes.get(5));
        assertEquals(1, bytes.get(6));

    }

}

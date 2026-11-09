package tests;

import glaze.Font;
import glaze.FontSmoothing;
import glaze.FontStyle;
import glaze.Hsla;
import glaze.RenderGlyphParams;
import glaze.platform.CeramicTextSystem;

// Original code for Glaze (not a port): FontSmoothing (Dense, Thin, Auto) and
// the synthetic oblique of Font.synthesizeStyle.

class FontSmoothingTest extends testing.TestCase {

    static function newTextSystem():glaze.TextSystem {
        final ts = new glaze.TextSystem(new CeramicTextSystem('Inter'));
        ts.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        return ts;
    }

    static function ink(ts:glaze.TextSystem, params:RenderGlyphParams):Int {
        final bounds = ts.rasterBounds(params);
        final bytes = ts.platformTextSystem.rasterizeGlyph(params, bounds);
        var sum = 0;
        for (i in 0...bytes.length)
            sum += bytes.get(i);
        return sum;
    }

    function testCompileTimeDefaultOfTheTests() {
        // tests/unit defines glaze_font_smoothing=thin (GPUI's coverage)
        assertEquals(FontSmoothing.Thin, FontSmoothing.compileTimeDefault());
        assertEquals(FontSmoothing.Thin, newTextSystem().fontSmoothing);
    }

    function testDilationCodes() {
        final ts = newTextSystem();
        assertEquals(0, ts.glyphDilationForColor(Hsla.black()));
        assertEquals(0, ts.glyphDilationForColor(Hsla.white()));
        ts.fontSmoothing = Dense;
        // 1 + the luminance level (quarters of the luma, at most 3)
        assertEquals(1, ts.glyphDilationForColor(Hsla.black()));
        assertEquals(4, ts.glyphDilationForColor(Hsla.white()));
        assertEquals(3, ts.glyphDilationForColor(new Hsla(0, 0, 0.5, 1)));
        assertEquals(2, ts.glyphDilationForColor(new Hsla(0, 0, 0.25, 1)));
        // Auto: Dense on macOS only
        ts.fontSmoothing = Auto;
        final mac = FontSmoothing.Auto.resolve() == Dense;
        assertEquals(mac ? 1 : 0, ts.glyphDilationForColor(Hsla.black()));
    }

    function testDenseDilationModel() {
        // 0.0115 px per pixel per em up to 0.64, plus 0.1 per luminance level
        assertFloatEquals(0.253, FontSmoothing.denseDilation(22, 0), 1e-9);
        assertFloatEquals(0.64, FontSmoothing.denseDilation(100, 0), 1e-9);
        assertFloatEquals(0.94, FontSmoothing.denseDilation(100, 3), 1e-9);
    }

    function testDenseGlyphsHaveMoreInk() {
        final ts = newTextSystem();
        final fontId = ts.resolveFont(Font.of('Inter'));
        final glyphId:glaze.GlyphId = ts.platformTextSystem.glyphForChar(fontId, 'l'.code);
        final thin = new RenderGlyphParams(fontId, glyphId, 14, 0, 0, 2.0, false, false, 0);
        final dark = new RenderGlyphParams(fontId, glyphId, 14, 0, 0, 2.0, false, false, 1);
        final light = new RenderGlyphParams(fontId, glyphId, 14, 0, 0, 2.0, false, false, 4);
        final thinInk = ink(ts, thin);
        final darkInk = ink(ts, dark);
        final lightInk = ink(ts, light);
        // 'l' at 28 px per em: about 2 x 20 px of vertical edges, each moved
        // by half the dilation (0.322 and 0.622 px in total)
        assertTrue(darkInk > thinInk, 'dark text is dilated');
        assertTrue(lightInk > darkInk, 'light text more');
        final height = ts.rasterBounds(thin).size.height;
        final stemGrowth = (darkInk - thinInk) / 255 / height;
        assertFloatEquals(0.322, stemGrowth, 0.08);
        // the raster bounds grow with the outline
        assertTrue(ts.rasterBounds(light).size.width >= ts.rasterBounds(thin).size.width);
    }

    function testSyntheticOblique() {
        final ts = newTextSystem();
        // Inter has no italic face: GPUI draws the upright face
        final upright = ts.resolveFont(Font.of('Inter'));
        final italic = ts.resolveFont(Font.of('Inter').italic());
        assertEquals(upright, italic);
        // with style synthesis, a font id of its own drawn slanted
        final synthesized = ts.resolveFont(Font.of('Inter').italic().withStyleSynthesis());
        assertTrue(synthesized != upright);
        // the same face and advances
        final glyphId:glaze.GlyphId = ts.platformTextSystem.glyphForChar(synthesized, 'l'.code);
        assertEquals((ts.platformTextSystem.glyphForChar(upright, 'l'.code) : Int), (glyphId : Int));
        assertFloatEquals(ts.platformTextSystem.advance(upright, glyphId).width, ts.platformTextSystem.advance(synthesized, glyphId).width, 0);
        // upright requests are not affected by the flag
        assertEquals(upright, ts.resolveFont(Font.of('Inter').withStyleSynthesis()));
        // the glyph is sheared by 1/4 around the baseline: its top moves right
        final a = ts.rasterBounds(new RenderGlyphParams(upright, glyphId, 20, 0, 0, 1.0));
        final b = ts.rasterBounds(new RenderGlyphParams(synthesized, glyphId, 20, 0, 0, 1.0));
        final top = -a.origin.y;
        assertTrue(b.size.width > a.size.width, 'slanted glyph is wider');
        assertFloatEquals(a.size.width + top * 0.25, b.size.width, 1.5);
        assertEquals(a.size.height, b.size.height);
        // keys of the fonts
        assertTrue(Font.of('Inter').italic().key() != Font.of('Inter').italic().withStyleSynthesis().key());
        assertFalse(Font.of('Inter').italic().equals(Font.of('Inter').italic().withStyleSynthesis()));
        assertTrue(Font.of('Inter').withStyleSynthesis().clone().synthesizeStyle);
    }

}

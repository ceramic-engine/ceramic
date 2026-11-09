package tests;

import glaze.Font;
import glaze.FontRun;
import glaze.platform.CeramicTextSystem;

// Original code for Glaze (not a port): Font.wholeRunShaping, lines shaped
// whole like a browser instead of word by word like cosmic-text.

class WholeRunShapingTest extends testing.TestCase {

    static function newTextSystem():glaze.TextSystem {
        final ts = new glaze.TextSystem(new CeramicTextSystem('Inter'));
        ts.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        return ts;
    }

    /** The x of each glyph of `text` laid out in one run of `font` at 1000 px */
    static function positions(ts:glaze.TextSystem, font:Font, text:String):Array<Float> {
        final fontId = ts.resolveFont(font);
        final layout = ts.platformTextSystem.layoutLine(text, 1000, [new FontRun(glaze.util.Utf8.byteLength(text), fontId)]);
        final result:Array<Float> = [];
        for (run in layout.runs)
            for (glyph in run.glyphs)
                result.push(glyph.position.x);
        return result;
    }

    function testKerningAcrossALineBreakOpportunity() {
        final ts = newTextSystem();
        // "x-T": a break opportunity after the hyphen. Inter kerns x and the
        // hyphen (546 - 22) and the hyphen and T (460 - 74), HarfBuzz
        // (hb-shape at 1000 units per em, rounded to whole units: within 1)
        // over the whole text.
        final words = positions(ts, Font.of('Inter'), 'x-T');
        assertFloatEquals(524, words[1], 1.0);
        // word by word (GPUI): the pair across the break is not kerned
        assertFloatEquals(524 + 460, words[2], 1.0);
        final whole = Font.of('Inter');
        whole.wholeRunShaping = true;
        final browser = positions(ts, whole, 'x-T');
        assertFloatEquals(524, browser[1], 1.0);
        assertFloatEquals(524 + 386, browser[2], 1.0);
    }

    function testFontIdsAndKeys() {
        final ts = newTextSystem();
        final plain = Font.of('Inter');
        final whole = Font.of('Inter');
        whole.wholeRunShaping = true;
        final plainId = ts.resolveFont(plain);
        final wholeId = ts.resolveFont(whole);
        assertTrue(plainId != wholeId);
        // same face: same glyphs and advances
        final glyphId:glaze.GlyphId = ts.platformTextSystem.glyphForChar(plainId, 'x'.code);
        assertEquals((glyphId : Int), (ts.platformTextSystem.glyphForChar(wholeId, 'x'.code) : Int));
        assertFloatEquals(ts.platformTextSystem.advance(plainId, glyphId).width, ts.platformTextSystem.advance(wholeId, glyphId).width, 0);
        assertTrue(plain.key() != whole.key());
        assertFalse(plain.equals(whole));
        assertTrue(whole.clone().wholeRunShaping);
        // a line mixing whole run and word fonts keeps the words
        final text = 'x-T';
        final len = glaze.util.Utf8.byteLength(text);
        final mixed = ts.platformTextSystem.layoutLine(text, 1000, [new FontRun(2, wholeId), new FontRun(len - 2, plainId)]);
        assertFloatEquals(524 + 460, mixed.runs[mixed.runs.length - 1].glyphs[0].position.x, 1.0);
    }

}

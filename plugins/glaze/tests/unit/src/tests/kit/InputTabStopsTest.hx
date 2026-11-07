// Ported from gpui-kit 0.8.1: crates/base/src/input/base/tab_stops.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.FontId;
import glaze.GlyphId;
import glaze.LineLayout;
import glaze.Point;
import glaze.ShapedGlyph;
import glaze.ShapedRun;
import glaze.kit.base.input.TabStops;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.input.TabStops` (Rust `tab_stops.rs`).
 */
class InputTabStopsTest extends TestCase {

    /**
     * A line where every char is one glyph `advance` wide, except tabs,
     * which are `tabAdvance` wide. Glyph indices are UTF-8 byte offsets.
     */
    static function layout(text:String, advance:Float, tabAdvance:Float):LineLayout {
        var x = 0.;
        var index = 0;
        final glyphs:Array<ShapedGlyph> = [];
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            glyphs.push(new ShapedGlyph(new GlyphId(0), new Point(x, 0.), index, false));
            x += c == '\t'.code ? tabAdvance : advance;
            index += c < 0x80 ? 1 : (c < 0x800 ? 2 : (c < 0x10000 ? 3 : 4));
        }
        return new LineLayout(10., x, 8., 2., [new ShapedRun(new FontId(0), glyphs)], index);
    }

    static function xs(layout:LineLayout):String {
        return [for (glyph in layout.runs[0].glyphs) (glyph.position.x:Float)].join(',');
    }

    static function repeat(s:String, n:Int):String {
        final buf = new StringBuf();
        for (_ in 0...n) buf.add(s);
        return buf.toString();
    }

    function testLeavesLinesWithoutTabsAlone() {
        assertNull(TabStops.expandedLayout(layout("abc", 10., 0.), "abc", 40.));
    }

    function testZeroWidthTabsReachTheNextStop() {
        final text = "\t\tx";
        final expanded = TabStops.expandedLayout(layout(text, 10., 0.), text, 40.);
        assertEquals("0,40,80", xs(expanded));
        assertEquals(90., (expanded.width:Float));
    }

    function testATabAfterTextOnlyFillsUpToTheStop() {
        final text = "ab\tc";
        final expanded = TabStops.expandedLayout(layout(text, 10., 0.), text, 40.);
        assertEquals("0,10,20,40", xs(expanded));
    }

    function testATabOnAStopTakesAWholeStop() {
        final text = "abcd\te";
        final expanded = TabStops.expandedLayout(layout(text, 10., 0.), text, 40.);
        assertEquals(80., (expanded.runs[0].glyphs[5].position.x:Float));
    }

    function testFractionalStopsKeepConsecutiveTabsAdvancing() {
        final text = repeat("\t", 256) + "x";
        for (stop in [14.4, 16.8, 28.8, 33.6]) {
            for (tabAdvance in [0., 28.]) {
                final shaped = layout(text, 10., tabAdvance);
                final expanded = TabStops.expandedLayout(shaped, text, stop);
                final glyphs = expanded.runs[0].glyphs;
                for (index in 0...glyphs.length) {
                    final expected = stop * index;
                    assertTrue(Math.abs((glyphs[index].position.x:Float) - expected) < 0.001,
                        'stop $stop, tab advance $tabAdvance, glyph $index: ${glyphs[index].position.x}');
                }
                assertEquals((expanded.width:Float), (TabStops.expandedWidth(shaped, text, stop):Float));
            }
        }
    }

    function testShaperWidthsForTabsAreReplaced() {
        final text = "\tx";
        final expanded = TabStops.expandedLayout(layout(text, 10., 28.), text, 40.);
        assertEquals("0,40", xs(expanded));
        assertEquals(50., (expanded.width:Float));
    }

    function testATrailingTabWidensTheLine() {
        final text = "a\t";
        assertEquals(40., (TabStops.expandedWidth(layout(text, 10., 0.), text, 40.):Float));
    }

    function testTabStopsCrossShapedRunsAndMultibyteCharacters() {
        final text = "é\t中\t\tz\t";
        final shaped = layout(text, 10., 28.);
        final remaining = shaped.runs[0].glyphs.splice(3, shaped.runs[0].glyphs.length - 3);
        shaped.runs.push(new ShapedRun(new FontId(1), remaining));

        final expanded = TabStops.expandedLayout(shaped, text, 40.);
        final positions = [for (run in expanded.runs) for (glyph in run.glyphs) (glyph.position.x:Float)];
        assertEquals("0,10,40,50,80,120,130", positions.join(','));
        assertEquals(160., (expanded.width:Float));
        assertEquals((expanded.width:Float), (TabStops.expandedWidth(shaped, text, 40.):Float));
        assertEquals((shaped.width:Float), (TabStops.expandedWidth(shaped, text, 0.):Float));
    }

    function testExpandsLongTabSeparatedLines() {
        final count = 16384;
        final text = repeat("\tx", count);
        final shaped = layout(text, 10., 0.);
        final expectedWidth = count * 40. + 10.;
        final expanded = TabStops.expandedLayout(shaped, text, 40.);

        assertEquals(expectedWidth, (expanded.width:Float));
        assertEquals(expectedWidth, (TabStops.expandedWidth(shaped, text, 40.):Float));
        final glyphs = expanded.runs[0].glyphs;
        var ix = 0;
        var ok = true;
        while (ix * 2 + 1 < glyphs.length) {
            final tabStart = ix == 0 ? 0. : ix * 40. + 10.;
            if ((glyphs[ix * 2].position.x:Float) != tabStart || (glyphs[ix * 2 + 1].position.x:Float) != (ix + 1) * 40.) ok = false;
            ix++;
        }
        assertTrue(ok);
    }

}

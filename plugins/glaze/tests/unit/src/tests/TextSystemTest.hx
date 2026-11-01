package tests;

import gpui.Font;
import gpui.FontId;
import gpui.NoopTextSystem;
import gpui.RenderGlyphParams;
import gpui.TextSystem;
import gpui.platform.CeramicTextSystem;
import testing.TestCase;

/**
 * Tests of the text system (gpui-pre 0.3.10: src/text_system.rs) and of
 * `CeramicTextSystem`, compared with the original GPUI text system
 * (`CosmicTextSystem`) loaded with the same fonts (see `TextFixtures`).
 */
class TextSystemTest extends TestCase {

    /** Tolerance on values computed in f32 by GPUI */
    static inline final F32_EPSILON = 1e-4;

    /** Largest differences with GPUI, by category (printed by `testReport`) */
    public static final maxErrors:Map<String, Float> = new Map();

    static function record(category:String, error:Float):Void {
        final current = maxErrors.get(category);
        if (current == null || error > current)
            maxErrors.set(category, error);
    }

    function assertClose(expected:Float, actual:Float, epsilon:Float, category:String, message:String, ?pos:haxe.PosInfos) {
        record(category, Math.abs(expected - actual));
        assertFloatEquals(expected, actual, epsilon, message, pos);
    }

/// Ported #[cfg(test)] tests

    function testCachesResolvedFontFallbacks() {
        final textSystem = new TextSystem(new NoopTextSystem());
        final requested = Font.of('Missing Font').bold().italic();
        final missing = gpui.TextSystem.CachedFont.Missing('missing font');
        textSystem.setCachedFont(requested, missing);
        for (fallback in textSystem.fallbackFontStack) {
            textSystem.setCachedFont(fallback, missing);
        }
        textSystem.setCachedFont(Font.of('Arial'), Direct(42));

        assertEquals(42, (textSystem.resolveFont(requested):Int));
        final font = textSystem.getFontForId(42);
        assertTrue(font != null && font.equals(Font.of('Arial')));

        textSystem.fallbackFontStack = [];
        assertEquals(42, (textSystem.resolveFont(requested):Int));
    }

    function testUnderlineYOffset() {
        // padding_top + ascent + descent * 0.618
        assertFloatEquals((20 - 12 - 4) / 2 + 12 + 4 * 0.618, TextSystem.underlineYOffset(20, 12, 4));
    }

/// Font resolution

    function testFontResolutionMatchesGpui() {
        final ref:Dynamic = TextFixtures.reference();
        final ts = TextFixtures.textSystem();
        assertEquals('Inter', TextFixtures.familyOf(ts.resolveFont(Font.of('Inter'))));
        assertEquals('JetBrains Mono', TextFixtures.familyOf(ts.resolveFont(Font.of('JetBrains Mono'))));
        assertEquals(ref.resolved.system_ui, TextFixtures.familyOf(ts.resolveFont(Font.of('.SystemUIFont'))));
        assertEquals(ref.resolved.inter_bold, TextFixtures.familyOf(ts.resolveFont(Font.of('Inter').bold())));
        // Same descriptor, same id; another descriptor of the same face, another id (like cosmic)
        assertEquals((ts.resolveFont(Font.of('Inter')):Int), (ts.resolveFont(Font.of('Inter')):Int));
        assertTrue((ts.resolveFont(Font.of('.SystemUIFont')):Int) != (ts.resolveFont(Font.of('Inter')):Int));
        // No fallback family is available: GPUI panics, the port throws
        assertRaises(() -> ts.resolveFont(Font.of('Missing Family')));
        assertEquals(['Inter', 'JetBrains Mono'].join(','), ts.allFontNames().join(','));
    }

/// Metrics against GPUI

    function testMetricsMatchGpui() {
        final ref:Dynamic = TextFixtures.reference();
        final ts = TextFixtures.textSystem();
        final fonts:Array<Dynamic> = ref.fonts;
        for (f in fonts) {
            final family:String = f.family;
            final id = ts.resolveFont(Font.of(family));
            final m = ts.platformTextSystem.fontMetrics(id);
            final e:Dynamic = f.metrics;
            assertEquals((e.units_per_em:Int), m.unitsPerEm, '$family units per em');
            assertClose(e.ascent, m.ascent, 0, 'metrics', '$family ascent');
            assertClose(e.descent, m.descent, 0, 'metrics', '$family descent');
            assertClose(e.line_gap, m.lineGap, 0, 'metrics', '$family line gap');
            assertClose(e.underline_position, m.underlinePosition, 0, 'metrics', '$family underline position');
            assertClose(e.underline_thickness, m.underlineThickness, 0, 'metrics', '$family underline thickness');
            assertClose(e.cap_height, m.capHeight, 0, 'metrics', '$family cap height');
            assertClose(e.x_height, m.xHeight, 0, 'metrics', '$family x height');
            final bbox:Array<Float> = e.bounding_box;
            assertClose(bbox[0], m.boundingBox.origin.x, 0, 'metrics', '$family bbox x');
            assertClose(bbox[1], m.boundingBox.origin.y, 0, 'metrics', '$family bbox y');
            assertClose(bbox[2], m.boundingBox.size.width, 0, 'metrics', '$family bbox width');
            assertClose(bbox[3], m.boundingBox.size.height, 0, 'metrics', '$family bbox height');

            final at16:Dynamic = f.at_16;
            assertClose(at16.ascent, ts.ascent(id, 16), F32_EPSILON, 'metrics at size', '$family ascent(16)');
            assertClose(at16.descent, ts.descent(id, 16), F32_EPSILON, 'metrics at size', '$family descent(16)');
            assertClose(at16.cap_height, ts.capHeight(id, 16), F32_EPSILON, 'metrics at size', '$family cap height(16)');
            assertClose(at16.x_height, ts.xHeight(id, 16), F32_EPSILON, 'metrics at size', '$family x height(16)');
            assertClose(at16.baseline_offset_24, ts.baselineOffset(id, 16, 24), F32_EPSILON, 'metrics at size', '$family baseline offset');
            assertClose(at16.em_width, ts.emWidth(id, 16), F32_EPSILON, 'metrics at size', '$family em width');
            assertClose(at16.em_advance, ts.emAdvance(id, 16), F32_EPSILON, 'metrics at size', '$family em advance');
            assertClose(at16.ch_advance, ts.chAdvance(id, 16), F32_EPSILON, 'metrics at size', '$family ch advance');
            final bbox16:Array<Float> = at16.bounding_box;
            final b = ts.boundingBox(id, 16);
            assertClose(bbox16[2], b.size.width, F32_EPSILON, 'metrics at size', '$family bounding box width(16)');
            assertClose(bbox16[3], b.size.height, F32_EPSILON, 'metrics at size', '$family bounding box height(16)');

            final windowTs = new gpui.WindowTextSystem(ts);
            assertClose(at16.em_layout_width, windowTs.emLayoutWidth(id, 16), F32_EPSILON, 'layout width', '$family em layout width');

            final chars:Array<Dynamic> = f.chars;
            for (c in chars) {
                final ch = gpui.util.Utf8.codePointAtByte(c.char, 0);
                final glyph = ts.platformTextSystem.glyphForChar(id, ch);
                assertEquals((c.glyph:Null<Int>), (glyph:Null<Int>), '$family glyph of ${c.char}');
                if (glyph == null)
                    continue;
                final advance = ts.platformTextSystem.advance(id, glyph);
                final expectedAdvance:Array<Float> = c.advance;
                assertClose(expectedAdvance[0], advance.width, 0, 'advance (font units)', '$family advance of ${c.char}');
                assertClose(expectedAdvance[1], advance.height, 0, 'advance (font units)', '$family advance height of ${c.char}');
                final bounds = ts.platformTextSystem.typographicBounds(id, glyph);
                final expectedBounds:Array<Float> = c.typographic_bounds;
                assertClose(expectedBounds[2], bounds.size.width, 0, 'typographic bounds', '$family typographic width of ${c.char}');
                assertClose(expectedBounds[3], bounds.size.height, 0, 'typographic bounds', '$family typographic height of ${c.char}');
                final sizes:Array<Dynamic> = c.sizes;
                for (s in sizes) {
                    final size:Float = s.size;
                    final adv:Array<Float> = s.advance;
                    final a = ts.advance(id, size, ch);
                    assertClose(adv[0], a.width, F32_EPSILON, 'advance (px)', '$family advance of ${c.char} at $size');
                    assertClose(s.layout_width, windowTs.layoutWidth(id, size, ch), F32_EPSILON, 'layout width', '$family layout width of ${c.char} at $size');
                }
            }
        }
    }

/// Glyph rasterization against GPUI

    /**
     * Raster bounds and coverage of glyphs for every subpixel variant and
     * scale factor, exact: the reference rasterizes glyphs without hinting
     * (`reference/src/unhinted_text.rs`, like CoreText on macOS) and the ttf
     * rasterizer is bit exact with swash's unhinted rendering.
     */
    function testRasterBoundsMatchGpui() {
        final ref:Dynamic = TextFixtures.reference();
        final ts = TextFixtures.textSystem();
        final entries:Array<Dynamic> = ref.raster_bounds;
        var maxCoverageError = 0.0;
        var maxErrorX = 0.0;
        var maxErrorY = 0.0;
        for (entry in entries) {
            final id = ts.resolveFont(Font.of(entry.family));
            final params = new RenderGlyphParams(id, entry.glyph, entry.size, entry.variant, 0, entry.scale);
            final bounds = ts.platformTextSystem.glyphRasterBounds(params);
            final expected:Array<Float> = entry.bounds;
            final errorX = Math.max(Math.abs(expected[0] - bounds.origin.x), Math.abs(expected[2] - bounds.size.width));
            final errorY = Math.max(Math.abs(expected[1] - bounds.origin.y), Math.abs(expected[3] - bounds.size.height));
            maxErrorX = Math.max(maxErrorX, errorX);
            maxErrorY = Math.max(maxErrorY, errorY);
            final label = '${entry.family} ${entry.char} size ${entry.size} scale ${entry.scale} variant ${entry.variant}';
            assertTrue(errorX == 0 && errorY == 0, 'raster bounds of $label: expected $expected, got ${bounds.origin.x}, ${bounds.origin.y}, ${bounds.size.width}, ${bounds.size.height}');
            var sum = 0.0;
            if (bounds.size.width > 0 && bounds.size.height > 0) {
                final bytes = ts.platformTextSystem.rasterizeGlyph(params, bounds);
                for (i in 0...bytes.length)
                    sum += bytes.get(i);
            }
            final expectedSum:Float = entry.coverage_sum;
            maxCoverageError = Math.max(maxCoverageError, Math.abs(sum - expectedSum));
            assertEquals(expectedSum, sum, 'coverage sum of $label');
        }
        record('raster bounds x (px)', maxErrorX);
        record('raster bounds y (px)', maxErrorY);
        record('raster coverage sum', maxCoverageError);
        trace('TextSystemTest: raster bounds of ${entries.length} glyph renders: max error x $maxErrorX px, y $maxErrorY px, coverage sum $maxCoverageError');
    }

    function testReport() {
        // Runs the comparisons, then prints the largest differences per category
        testMetricsMatchGpui();
        final keys = [for (k in maxErrors.keys()) k];
        keys.sort((a, b) -> a < b ? -1 : 1);
        for (k in keys)
            trace('TextSystemTest: max difference with GPUI, $k: ${maxErrors.get(k)}');
    }

}

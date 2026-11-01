package tests;

import gpui.Font;
import gpui.FontFallbacks;
import gpui.FontId;
import gpui.FontRun;
import gpui.GlyphId;
import gpui.LineLayout;
import gpui.Point;
import gpui.RenderGlyphParams;
import gpui.ShapedGlyph;
import gpui.ShapedRun;
import gpui.platform.CanvasFallback;
import gpui.platform.CanvasFallbackText;
import gpui.platform.CanvasFontFallback;
import gpui.platform.CanvasGlyphCache;
import gpui.platform.CanvasText;
import gpui.platform.CeramicTextSystem;
import gpui.platform.RunReplacements;
import gpui.platform.RunReplacements.Replacement;
import gpui.platform.CanvasText.CanvasTextBackend;
import gpui.platform.CanvasText.CanvasTextMetrics;
import gpui.platform.CanvasFallbackText.CanvasFont;
import gpui.util.Utf8;
import haxe.io.Bytes;
import testing.TestCase;

/**
 * The Canvas2D font fallback of the web text system (port of gpui-pre-web
 * 0.3.10: canvas_fallback.rs, glyph_cache.rs, run_replacements.rs,
 * canvas_text.rs and text_system.rs), on every target with a fake canvas
 * (`FakeCanvas`): the Rust tests of those files, the classification of every
 * code point and of sequences compared with the original
 * (`test/unit/data/canvas-fallback-reference.json`, dumped by a Rust program
 * that compiles the original canvas_fallback.rs), the CSS fonts, the font and
 * glyph id scheme and the layout replacements.
 */
class CanvasFallbackTest extends TestCase {

/// canvas_fallback.rs tests

    static function fallback(isEmoji:Bool, emojiPresentation:Bool):CanvasFallback {
        return new CanvasFallback(isEmoji, emojiPresentation);
    }

    function testCanvasFontFallbackPolicy() {
        assertEquals(Emoji, new CeramicTextSystem().canvasFontFallback, 'default policy');
        for (entry in [
            {g: "😀", allowed: true},
            {g: "❤️", allowed: true},
            {g: "1️⃣", allowed: true},
            {g: "👨‍👩‍👧‍👦", allowed: true},
            {g: "🕸", allowed: true},
            {g: "🕸\u{FE0E}", allowed: true},
            {g: "🕸\u{FE0F}", allowed: true},
            {g: "©", allowed: true},
            {g: "❤︎", allowed: true},
            {g: "中", allowed: false},
            {g: "か\u{3099}", allowed: false},
            {g: "각", allowed: false},
        ]) {
            final f = CanvasFallback.classify(entry.g);
            assertNotNull(f, 'eligible grapheme ${entry.g}');
            if (f == null)
                continue;
            assertFalse((Disabled:CanvasFontFallback).allows(f.isEmoji));
            assertEquals(entry.allowed, (Emoji:CanvasFontFallback).allows(f.isEmoji), entry.g);
            assertTrue((EmojiAndCjk:CanvasFontFallback).allows(f.isEmoji));
        }
    }

    function testAsciiIsIneligibleButKeycapsArePreserved() {
        for (byte in 0...0x80)
            assertNull(CanvasFallback.classify(String.fromCharCode(byte)), 'byte $byte');
        for (text in ["", "Hello", "0123456789#*", "\r\n"])
            assertNull(CanvasFallback.classify(text), text);
        for (base in "0123456789#*".split('')) {
            for (text in [base + "\u{20E3}", base + "\u{FE0F}\u{20E3}"]) {
                assertTrue(fallback(true, true).equals(CanvasFallback.classify(text)), text);
            }
        }
    }

    function testOrdinaryCjkClusters() {
        for (text in [
            "漢", "𠀀", "﨑", "漢\u{FE00}", "葛\u{E0100}", "葛\u{E01EF}", "あ", "ガ", "か\u{3099}", "ハ\u{309A}",
            "가", "각", "가", "각", "각", "ㄱ", "、", "。", "「", "」", "（", "！", "ー", "々",
        ]) {
            assertTrue(fallback(false, false).equals(CanvasFallback.classify(text)), text);
        }
    }

    function testEmojiPresentationIsPreserved() {
        for (entry in [
            {t: "😀", p: true},
            {t: "🕸", p: false},
            {t: "🕸\u{FE0E}", p: false},
            {t: "🕸\u{FE0F}", p: true},
            {t: "©", p: false},
            {t: "©\u{FE0E}", p: false},
            {t: "©\u{FE0F}", p: true},
            {t: "❤", p: false},
            {t: "❤\u{FE0E}", p: false},
            {t: "❤\u{FE0F}", p: true},
            {t: "😀\u{FE0E}", p: false},
            {t: "👍🏽", p: true},
            {t: "☝🏽", p: true},
            {t: "👍\u{FE0F}🏽", p: true},
            {t: "🇯🇵", p: true},
            {t: "1\u{20E3}", p: true},
            {t: "#\u{FE0F}\u{20E3}", p: true},
            {t: "*\u{FE0F}\u{20E3}", p: true},
            {t: "👩🏽‍💻", p: true},
            {t: "🧑‍⚕️", p: true},
            {t: "👨‍👩‍👧‍👦", p: true},
            {t: "🏳️‍🌈", p: true},
            {t: "🏴\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}", p: true},
            {t: "🏴\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}", p: true},
            {t: "🏴\u{E0067}\u{E0062}\u{E0077}\u{E006C}\u{E0073}\u{E007F}", p: true},
        ]) {
            assertTrue(fallback(true, entry.p).equals(CanvasFallback.classify(entry.t)), entry.t);
        }
    }

    function testUnsupportedScriptsAndCjkFormsStayOnLoadedFonts() {
        for (text in [
            "a", "é", "α", "Ж", "ش", "ש", "क", "क्ष", "ก", "ក", "ᠠ", "ཀ", "\u{0}", "\n", "\r\n", "\u{202E}",
            "\u{200D}", "\u{FDD0}", "\u{10FFFF}", "\u{2A6E0}", "\u{E000}", "\u{3099}", "\u{FE0F}", "\u{E0100}",
            "漢\u{301}", "漢\u{FE03}", "漢\u{FE0F}", "漢\u{E0100}\u{E0101}", "あ\u{3099}", "か\u{309A}",
            "か\u{3099}\u{3099}", "ᄀ", "ᅡ", "ᆨ", "ᄓᅡ", "ᄀᅶ", "가ᇃ", "각ᆨ", "ᄀ가", "\u{3164}", "\u{3165}",
            "⺀", "⼀", "㇀", "㆐", "ㄅ", "㐀\u{200D}", "\u{1B000}", "ｶ", "！\u{301}",
        ]) {
            assertNull(CanvasFallback.classify(text), text);
        }
    }

    function testMalformedOrOutOfPolicyEmojiStayOnLoadedFonts() {
        for (text in [
            "0", "#", "*", "1\u{FE0F}", "#\u{FE0E}", "1\u{FE0E}\u{20E3}", "a\u{20E3}", "🏽", "🇯", "😀🏽", "👍🏽🏽",
            "👍\u{FE0E}🏽", "👍🏽\u{FE0F}", "❤\u{FE0F}\u{FE0F}", "😀\u{301}", "🦰", "😀‍😀", "👩‍", "👩‍💻‍🚀",
            "👩\u{FE0E}‍💻", "🏴\u{E0067}", "🏴\u{E0061}\u{E0062}\u{E007F}", "😀\u{E0067}\u{E007F}",
        ]) {
            assertNull(CanvasFallback.classify(text), text);
        }
    }

    function testAcceptsOnlyOneWholeExtendedGrapheme() {
        for (text in ["", "漢字", "あい", "가나", "😀😀", "🇯🇵🇺", "🇯🇵🇺🇸", " 漢", "漢\n"])
            assertNull(CanvasFallback.classify(text), text);
        final text = "aか\u{3099}👩🏽‍💻漢\u{E0100}";
        final eligible:Array<String> = [];
        final graphemes = unicode_segmentation.UnicodeSegmentation.graphemes(text, true);
        var g = graphemes.next();
        while (g != null) {
            if (CanvasFallback.classify(g) != null)
                eligible.push(g);
            g = graphemes.next();
        }
        assertEquals(["か\u{3099}", "👩🏽‍💻", "漢\u{E0100}"].join('|'), eligible.join('|'));
    }

/// Classification compared with the original (every code point, and sequences)

    static function code(f:Null<CanvasFallback>):Int {
        return f == null ? 0 : (!f.isEmoji ? 1 : (!f.emojiPresentation ? 2 : 3));
    }

    /** Expands `[start, end, code]` ranges into a lookup */
    static function rangeLookup(ranges:Array<Array<Int>>):Int->Int {
        return c -> {
            var lo = 0;
            var hi = ranges.length - 1;
            while (lo <= hi) {
                final mid = (lo + hi) >> 1;
                final r = ranges[mid];
                if (c < r[0])
                    hi = mid - 1;
                else if (c > r[1])
                    lo = mid + 1;
                else
                    return r[2];
            }
            return 0;
        };
    }

    function testEveryCodePointMatchesTheOriginal() {
        final reference:Dynamic = haxe.Json.parse(referenceContent());
        final expected = rangeLookup(reference.single);
        var mismatches = 0;
        var checked = 0;
        for (c in 0...0x110000) {
            if (c >= 0xD800 && c <= 0xDFFF)
                continue;
            final actual = code(CanvasFallback.classify(Utf8.fromCodePoint(c)));
            checked++;
            if (actual != expected(c)) {
                if (mismatches < 10)
                    fail('U+${StringTools.hex(c, 4)}: expected ${expected(c)}, got $actual');
                mismatches++;
            }
        }
        assertEquals(0, mismatches, 'code points that differ from the original ($checked checked)');
    }

    function testSequencesMatchTheOriginal() {
        final reference:Dynamic = haxe.Json.parse(referenceContent());
        final single = rangeLookup(reference.single);
        // Bases that can start a supported sequence: eligible alone, emoji
        // characters or components, leading jamo
        final bases:Array<Int> = [];
        for (c in 0...0x110000) {
            if (c >= 0xD800 && c <= 0xDFFF)
                continue;
            if (single(c) != 0 || gpui.platform.CanvasFallbackTables.emojiStatus(c) != 0 || (c >= 0x1100 && c <= 0x1112))
                bases.push(c);
        }
        final sequences:Array<Dynamic> = reference.sequences;
        var mismatches = 0;
        var accepted = 0;
        for (sequence in sequences) {
            final suffix = [for (c in (sequence.suffix:Array<Int>)) Utf8.fromCodePoint(c)].join('');
            final expected = rangeLookup(sequence.accepted);
            // Every accepted base is one of the bases checked
            var expectedCount = 0;
            for (r in (sequence.accepted:Array<Array<Int>>))
                expectedCount += r[1] - r[0] + 1;
            var found = 0;
            for (c in bases) {
                final want = expected(c);
                final actual = code(CanvasFallback.classify(Utf8.fromCodePoint(c) + suffix));
                if (want != 0)
                    found++;
                if (actual != want) {
                    if (mismatches < 10)
                        fail('U+${StringTools.hex(c, 4)} + ${sequence.suffix}: expected $want, got $actual');
                    mismatches++;
                }
            }
            assertEquals(expectedCount, found, 'accepted bases of ${sequence.suffix} are checked');
            accepted += found;
        }
        assertEquals(0, mismatches, 'sequences that differ from the original');
        assertTrue(accepted > 1000, 'accepted sequences checked ($accepted)');
    }

/// glyph_cache.rs tests

    function testWarmLookupReturnsTheSameGlyph() {
        final cache = new CanvasGlyphCache();
        final fontId:FontId = 1;
        final glyphId = cache.getOrInsert(fontId, "👩‍💻", true);
        final surrounding = "👩‍💻 suffix";
        final borrowed = surrounding.substr(0, surrounding.length - " suffix".length);
        for (_ in 0...100) {
            assertEquals((glyphId:Int), (cache.idFor(fontId, borrowed, true):Int));
            assertEquals((glyphId:Int), (cache.getOrInsert(fontId, borrowed, true):Int));
        }
        assertEquals(1, cache.length);
        assertEquals("👩‍💻", cache.glyph(fontId, glyphId).text);
    }

    function testFontAndPresentationHaveDistinctIds() {
        final cache = new CanvasGlyphCache();
        final firstFont:FontId = 1;
        final secondFont:FontId = 2;
        final text = cache.getOrInsert(firstFont, "❤", false);
        final color = cache.getOrInsert(firstFont, "❤", true);
        final otherFont = cache.getOrInsert(secondFont, "❤", false);
        assertTrue((text:Int) != (color:Int));
        assertTrue((text:Int) != (otherFont:Int));
        assertTrue((color:Int) != (otherFont:Int));
        assertEquals((text:Int), (cache.idFor(firstFont, "❤", false):Int));
        assertEquals((color:Int), (cache.idFor(firstFont, "❤", true):Int));
        assertEquals((otherFont:Int), (cache.idFor(secondFont, "❤", false):Int));
        assertNull(cache.glyph(secondFont, text));
        assertNull(cache.glyph(firstFont, (0xFFFFFFFF:Int)));
        assertEquals(false, cache.glyph(firstFont, text).color);
        assertEquals(true, cache.glyph(firstFont, color).color);
    }

    function testInsertionRechecksAPreviousMiss() {
        final cache = new CanvasGlyphCache();
        final fontId:FontId = 1;
        assertNull(cache.idFor(fontId, "中", false));
        final inserted = cache.getOrInsert(fontId, "中", false);
        assertEquals((inserted:Int), (cache.getOrInsert(fontId, "中", false):Int));
        assertEquals(1, cache.length);
    }

/// run_replacements.rs tests

    static function sourceGlyph(index:Int, x:Float, id:Int, color:Bool):ShapedGlyph {
        return new ShapedGlyph(id, new Point(x, 2.0), index, color);
    }

    static function glyph(index:Int):ShapedGlyph {
        return new ShapedGlyph(index, new Point(index * 10.0, 2.0), index * 2, false);
    }

    static function layout(runLengths:Array<Int>):LineLayout {
        var index = 0;
        final runs:Array<ShapedRun> = [];
        for (font in 0...runLengths.length) {
            final glyphs = [for (i in index...index + runLengths[font]) glyph(i)];
            index += runLengths[font];
            runs.push(new ShapedRun(font, glyphs));
        }
        return new LineLayout(14.0, index * 10.0, 11.0, 3.0, runs, index * 2);
    }

    function testCandidatesCaptureBounds() {
        final text = "中a文 ";
        final l = layout([2, 0, 2]);
        l.width = 50.0;
        l.runs[0].glyphs = [sourceGlyph(0, 0.0, 0, false), sourceGlyph(3, 10.0, 1, false)];
        l.runs[2].glyphs = [sourceGlyph(4, 25.0, 0, false), sourceGlyph(7, 40.0, 3, false)];
        final candidates = RunReplacements.collectCandidates(text, [new FontRun(Utf8.byteLength(text), 7)], l);
        assertEquals(2, candidates.length);
        final first = candidates[0];
        assertEquals(0, first.sourceStart);
        assertEquals(3, first.sourceEnd);
        assertEquals(7, (first.fontId:Int));
        final span = first.glyphs;
        assertEquals(0, span.rangeStart);
        assertEquals(1, span.rangeEnd);
        assertEquals(0.0, span.position.x);
        assertEquals(2.0, span.position.y);
        assertEquals(10.0, span.endX);
        assertTrue(span.contiguous);
        assertTrue(span.missing);
        assertFalse(span.nativeColor);
        final last = candidates[1];
        assertEquals(4, last.sourceStart);
        assertEquals(7, last.sourceEnd);
        assertEquals(2, last.glyphs.rangeStart);
        assertEquals(3, last.glyphs.rangeEnd);
        assertEquals(25.0, last.glyphs.position.x);
        assertEquals(40.0, last.glyphs.endX);
    }

    function testCandidatesKeepGraphemesAcrossSameFontBoundaries() {
        final text = "か\u{3099}";
        final l = layout([1, 1]);
        l.runs[0].glyphs = [sourceGlyph(0, 0.0, 0, false)];
        l.runs[1].glyphs = [sourceGlyph(3, 10.0, 0, false)];
        final fontRuns = [new FontRun(3, 7), new FontRun(3, 7)];
        final candidates = RunReplacements.collectCandidates(text, fontRuns, l);
        assertEquals(1, candidates.length);
        final span = candidates[0].glyphs;
        assertEquals(0, span.rangeStart);
        assertEquals(2, span.rangeEnd);
        assertEquals(0.0, span.position.x);
        assertEquals((l.width:Float), span.endX);
        assertTrue(span.contiguous);

        fontRuns[1].fontId = 8;
        assertEquals(0, RunReplacements.collectCandidates(text, fontRuns, l).length);
    }

    function testCandidatesHandleNonmonotonicAndDisjointSourceIndices() {
        final l = layout([3]);
        l.width = 50.0;
        l.runs[0].glyphs = [sourceGlyph(3, 0.0, 0, false), sourceGlyph(0, 20.0, 0, false), sourceGlyph(3, 30.0, 0, false)];
        final candidates = RunReplacements.collectCandidates("中文", [new FontRun(6, 7)], l);
        final first = candidates[0].glyphs;
        assertEquals(1, first.rangeStart);
        assertEquals(2, first.rangeEnd);
        assertEquals(20.0, first.position.x);
        assertEquals(30.0, first.endX);
        assertTrue(first.contiguous);
        final last = candidates[candidates.length - 1].glyphs;
        assertEquals(0, last.rangeStart);
        assertEquals(3, last.rangeEnd);
        assertEquals(0.0, last.position.x);
        assertEquals(50.0, last.endX);
        assertFalse(last.contiguous);
    }

    function testCandidatesPreserveNativeCoverageAndColor() {
        final l = layout([1]);
        final fontRuns = [new FontRun(Utf8.byteLength("😀"), 7)];
        for (entry in [{id: 0, color: false}, {id: 1, color: false}, {id: 0, color: true}, {id: 1, color: true}]) {
            l.runs[0].glyphs = [sourceGlyph(0, 0.0, entry.id, entry.color)];
            final candidates = RunReplacements.collectCandidates("😀", fontRuns, l);
            final candidate = candidates[0];
            assertTrue(candidate.color);
            assertEquals(entry.id == 0, candidate.glyphs.missing);
            assertEquals(entry.color, candidate.glyphs.nativeColor);
        }
        l.runs[0].glyphs = [];
        assertNull(RunReplacements.collectCandidates("😀", fontRuns, l)[0].glyphs);
    }

    static function replacement(start:Int, end:Int, fontId:Int, delta:Float):Replacement {
        final g = glyph(start);
        return new Replacement(start, end, fontId, new ShapedGlyph(999, new Point(g.position.x + 1.0, 7.0), g.index, true), delta);
    }

    /** The reference algorithm of the Rust tests (flattened stream) */
    static function reference(l:LineLayout, replacements:Array<Replacement>):Void {
        final original = l.runs;
        l.runs = [];
        var next = 0;
        var shift = 0.0;
        var consumedEnd = 0;
        var index = 0;
        for (run in original) {
            for (g in run.glyphs) {
                final i = index++;
                if (i < consumedEnd)
                    continue;
                var glyph = g;
                var fontId:Int = run.fontId;
                if (next < replacements.length && replacements[next].glyphRangeStart == i) {
                    final r = replacements[next++];
                    glyph = new ShapedGlyph(r.glyph.id, new Point(r.glyph.position.x + shift, r.glyph.position.y), r.glyph.index, r.glyph.isEmoji);
                    shift += r.widthDelta;
                    consumedEnd = r.glyphRangeEnd;
                    fontId = r.fontId;
                }
                else {
                    glyph = new ShapedGlyph(g.id, new Point(g.position.x + shift, g.position.y), g.index, g.isEmoji);
                }
                final last = l.runs.length > 0 ? l.runs[l.runs.length - 1] : null;
                if (last != null && (last.fontId:Int) == fontId)
                    last.glyphs.push(glyph);
                else
                    l.runs.push(new ShapedRun(fontId, [glyph]));
            }
        }
        l.width = (l.width:Float) + shift;
    }

    static function flatten(l:LineLayout):String {
        final parts:Array<String> = [];
        for (run in l.runs)
            for (g in run.glyphs)
                parts.push('${(run.fontId:Int)}/${(g.id:Int)}/${g.position.x},${g.position.y}/${g.index}/${g.isEmoji}');
        return parts.join(' ') + ' w=${(l.width:Float)} fs=${(l.fontSize:Float)} a=${(l.ascent:Float)} d=${(l.descent:Float)} len=${l.len}';
    }

    function testNoReplacementsPreservesEvenEmptyRuns() {
        final actual = layout([0, 3, 0]);
        final runs = actual.runs;
        RunReplacements.applyReplacements(actual, []);
        assertEquals(3, actual.runs.length);
        assertTrue(actual.runs == runs);
        assertEquals(flatten(layout([0, 3, 0])), flatten(actual));
        RunReplacements.applyReplacements(layout([]), []);
        RunReplacements.applyReplacements(layout([0, 0]), []);
    }

    function testWholeRunReplacement() {
        final actual = layout([8]);
        RunReplacements.applyReplacements(actual, [replacement(0, 8, 9, -20.0)]);
        assertEquals(1, actual.runs.length);
        assertEquals(9, (actual.runs[0].fontId:Int));
        assertEquals(1, actual.runs[0].glyphs.length);
    }

    function testSplitsKeepRunsAndDropEmptiedOnes() {
        final actual = layout([4, 4, 3]);
        RunReplacements.applyReplacements(actual, [replacement(2, 8, 9, -3.0)]);
        final expected = layout([4, 4, 3]);
        reference(expected, [replacement(2, 8, 9, -3.0)]);
        assertEquals(flatten(expected), flatten(actual));
        // Rust keeps the segments of each source run: [0: g0 g1] [9: r] [2: g8 g9 g10]
        assertEquals('0,9,2', [for (run in actual.runs) (run.fontId:Int)].join(','));
    }

    function testMultipleSplitsAndShifts() {
        final actual = layout([7, 2, 3]);
        final expected = layout([7, 2, 3]);
        final replacements = () -> [replacement(1, 2, 9, 3.0), replacement(3, 5, 8, -7.0), replacement(6, 10, 9, 2.0)];
        RunReplacements.applyReplacements(actual, replacements());
        reference(expected, replacements());
        assertEquals(flatten(expected), flatten(actual));
    }

    function testExhaustiveSmallStreamsMatchReference() {
        // Base-four choices at each original glyph: keep, start a native-font
        // replacement, start a fallback replacement, or extend the previous one.
        for (first in 0...5) {
            for (second in 0...(5 - first)) {
                final lengths = [first, 0, second, 4 - first - second];
                for (choices in 0...256) {
                    final replacements = () -> {
                        final result:Array<Replacement> = [];
                        for (index in 0...4) {
                            switch (choices >> (2 * index)) & 3 {
                                case 0:
                                case 1: result.push(replacement(index, index + 1, 0, 2.0));
                                case 2: result.push(replacement(index, index + 1, 9, -3.0));
                                case _:
                                    if (result.length > 0 && result[result.length - 1].glyphRangeEnd == index) {
                                        final previous = result.pop();
                                        result.push(new Replacement(previous.glyphRangeStart, previous.glyphRangeEnd + 1, previous.fontId, previous.glyph, previous.widthDelta));
                                    }
                            }
                        }
                        result;
                    };
                    final actual = layout(lengths);
                    final expected = layout(lengths);
                    RunReplacements.applyReplacements(actual, replacements());
                    reference(expected, replacements());
                    assertEquals(flatten(expected), flatten(actual), 'lengths $lengths choices $choices');
                }
            }
        }
    }

/// text_system.rs: CSS fonts, ids, metrics, raster bounds and layout

    static function platform(policy:CanvasFontFallback, ?canvas:FakeCanvas):CeramicTextSystem {
        final p = new CeramicTextSystem('Inter');
        p.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        p.canvasFontFallback = policy;
        p.canvasText = canvas != null ? canvas : new FakeCanvas();
        return p;
    }

    function testF32Display() {
        assertEquals('14', CanvasFont.f32Display(14));
        assertEquals('400', CanvasFont.f32Display(400));
        assertEquals('13.5', CanvasFont.f32Display(13.5));
        assertEquals('0.1', CanvasFont.f32Display(0.1));
        assertEquals('13.333333', CanvasFont.f32Display(40 / 3));
        assertEquals('26.666666', CanvasFont.f32Display(80 / 3));
        assertEquals('2048', CanvasFont.f32Display(2048));
        assertEquals('16777216', CanvasFont.f32Display(16777217));
        assertEquals('0.0000001', CanvasFont.f32Display(0.0000001));
    }

    function testQuoteFamily() {
        assertEquals('"Inter"', CanvasFont.quoteFamily('Inter'));
        assertEquals('"A\\"b\\\\c d"', CanvasFont.quoteFamily('A"b\\c\nd'));
    }

    function testCssFonts() {
        final p = platform(EmojiAndCjk);
        final inter = p.fontId(Font.of('Inter'));
        final mono = p.fontId(Font.of('JetBrains Mono'));
        final system = p.fontId(Font.of('.SystemUIFont'));
        final bold = Font.of('Inter');
        bold.weight = gpui.FontWeight.BOLD;
        bold.fallbacks = FontFallbacks.fromFonts(['Noto Sans CJK SC', 'A"b']);
        final boldId = p.fontId(bold);
        inline function css(nativeId:FontId, size:Float, color:Bool):String {
            return p.canvas.canvasFont(p.canvas.canvasFontId(nativeId)).cssFont(size, color);
        }
        assertEquals('normal 400 16px "Inter", sans-serif', css(inter, 16, false));
        assertEquals('normal 400 16px emoji', css(inter, 16, true));
        assertEquals('normal 400 14px "JetBrains Mono", monospace', css(mono, 14, false));
        assertEquals('normal 400 13.5px sans-serif', css(system, 13.5, false));
        // The face resolved for bold Inter is the only Inter face of the fixtures (regular)
        assertEquals('normal 400 32px "Inter", "Noto Sans CJK SC", "A\\"b", sans-serif', css(boldId, 32, false));
        assertEquals('normal 400 32px "Noto Sans CJK SC", "A\\"b", emoji', css(boldId, 32, true));
        assertRaises(() -> css(inter, 0, false));
        assertRaises(() -> css(inter, Math.NaN, false));
    }

    function testCanvasFontAndGlyphIds() {
        final p = platform(EmojiAndCjk);
        final inter = p.fontId(Font.of('Inter'));
        final mono = p.fontId(Font.of('JetBrains Mono'));
        assertFalse(CanvasFallbackText.isCanvasFontId(inter));
        final interCanvas = p.canvas.canvasFontId(inter);
        final monoCanvas = p.canvas.canvasFontId(mono);
        // Top bit of a 32-bit usize (wasm32), then creation order
        assertEquals(1 << 31, (interCanvas:Int));
        assertEquals((1 << 31) | 1, (monoCanvas:Int));
        assertEquals((interCanvas:Int), (p.canvas.canvasFontId(inter):Int));
        assertTrue(CanvasFallbackText.isCanvasFontId(interCanvas));
        assertEquals((inter:Int), (p.canvas.nativeFontId(interCanvas):Int));
        assertEquals((inter:Int), (p.canvas.nativeFontId(inter):Int));
        // Glyph ids: one per font, text and presentation, in insertion order
        assertEquals(0, (p.glyphForChar(interCanvas, '中'.code):Int));
        assertEquals(1, (p.glyphForChar(interCanvas, 0x1F600):Int));
        assertEquals(0, (p.glyphForChar(interCanvas, '中'.code):Int));
        assertEquals(2, (p.glyphForChar(monoCanvas, '中'.code):Int));
        assertEquals(true, p.canvas.glyphs.glyph(interCanvas, 1).color);
        assertEquals(false, p.canvas.glyphs.glyph(interCanvas, 0).color);
        // Canvas font metrics are the native ones
        assertEquals(p.fontMetrics(inter).unitsPerEm, p.fontMetrics(interCanvas).unitsPerEm);
        assertEquals((p.fontMetrics(inter).ascent:Float), (p.fontMetrics(interCanvas).ascent:Float));
        // Atlas keys carry the canvas font id
        final params = new RenderGlyphParams(interCanvas, 1, 16, 0, 0, 2, true);
        assertEquals('-2147483648:1:16:0:0:2:1:0:0', params.key());
    }

    function testMetricsAtUnitsPerEm() {
        final canvas = new FakeCanvas();
        final p = platform(EmojiAndCjk, canvas);
        final inter = p.fontId(Font.of('Inter'));
        final upm = p.fontMetrics(inter).unitsPerEm;
        final c = p.canvas.canvasFontId(inter);
        final g = p.glyphForChar(c, '中'.code);
        final advance = p.advance(c, g);
        assertEquals(upm * 0.75, (advance.width:Float));
        assertEquals(0.0, (advance.height:Float));
        final bounds = p.typographicBounds(c, g);
        assertEquals(upm * 0.0625, bounds.origin.x);
        assertEquals(-upm * 0.75, bounds.origin.y);
        assertEquals(upm * (0.6875 - 0.0625), bounds.size.width);
        assertEquals(upm * (0.75 + 0.125), bounds.size.height);
        assertEquals('normal 400 ${upm}px "Inter", sans-serif', canvas.fonts[canvas.fonts.length - 1]);
        // Cached: no new measurement
        final calls = canvas.measureCalls;
        p.advance(c, g);
        p.typographicBounds(c, g);
        assertEquals(calls, canvas.measureCalls);
    }

    function testRasterBounds() {
        final metrics = new CanvasTextMetrics(12, 0.5, 11.25, 12, 3.5);
        final b = CanvasFallbackText.rasterBoundsOf(metrics, 0.25, 0);
        // floor(0.75) - 1, floor(-12) - 1, ceil(11.5) + 1, ceil(3.5) + 1
        assertEquals(-1.0, b.origin.x);
        assertEquals(-13.0, b.origin.y);
        assertEquals(14.0, b.size.width);
        assertEquals(18.0, b.size.height);
        assertTrue(CanvasFallbackText.rasterBoundsOf(new CanvasTextMetrics(5, 1, 1, 3, 3), 0, 0).isZero());
        assertTrue(CanvasFallbackText.rasterBoundsOf(new CanvasTextMetrics(5, 0, 4, -3, 3), 0, 0).isZero());
        // Subpixel offsets of the web text system: variant / variants, not divided by the scale factor
        final params = new RenderGlyphParams(0, 0, 16, 3, 0, 2);
        assertEquals(0.75, CanvasFallbackText.subpixelOffsetX(params));
        assertEquals(0.0, CanvasFallbackText.subpixelOffsetY(params));
    }

    function testRasterizeMaskAndColor() {
        final canvas = new FakeCanvas();
        final p = platform(EmojiAndCjk, canvas);
        final inter = p.fontId(Font.of('Inter'));
        final c = p.canvas.canvasFontId(inter);
        final text = p.glyphForChar(c, '中'.code);
        final emoji = p.glyphForChar(c, 0x1F600);

        final params = new RenderGlyphParams(c, text, 16, 2, 0, 2);
        final bounds = p.glyphRasterBounds(params);
        // Font size 32 (16 x 2): left 2, right 22, ascent 24, descent 4, offset 0.5
        assertEquals(1.0, bounds.origin.x);
        assertEquals(-25.0, bounds.origin.y);
        assertEquals(23.0, bounds.size.width);
        assertEquals(30.0, bounds.size.height);
        final mask = p.rasterizeGlyph(params, bounds);
        assertEquals(23 * 30, mask.length);
        for (i in 0...mask.length)
            if (mask.get(i) != 200)
                fail('alpha at $i');
        assertEquals('normal 400 32px "Inter", sans-serif', canvas.lastFill.font);
        assertEquals('中', canvas.lastFill.text);
        assertEquals(-1.0 + 0.5, canvas.lastFill.x);
        assertEquals(25.0, canvas.lastFill.y);

        final emojiParams = new RenderGlyphParams(c, emoji, 16, 0, 0, 2, true);
        final emojiBounds = p.glyphRasterBounds(emojiParams);
        final pixels = p.rasterizeGlyph(emojiParams, emojiBounds);
        assertEquals(Std.int(emojiBounds.size.width * emojiBounds.size.height) * 4, pixels.length);
        // RGBA (r = pixel % 256, g = 1, b = 2, a = 200) to BGRA
        assertEquals(2, pixels.get(4));
        assertEquals(1, pixels.get(5));
        assertEquals(1, pixels.get(6));
        assertEquals(200, pixels.get(7));
        assertEquals('normal 400 32px emoji', canvas.lastFill.font);

        // Subpixel (LCD) masks repeat the alpha 4 times
        final lcd = new RenderGlyphParams(c, text, 16, 2, 0, 2, false, true);
        assertEquals(23 * 30 * 4, p.rasterizeGlyph(lcd, bounds).length);

        // Limits of canvas_text::rasterize
        assertEquals(0, CanvasText.rasterize(canvas, 'x', '10px a', new gpui.Bounds(new Point(0, 0), new gpui.Size(0, 5)), 0, 0, false).length);
        assertRaises(() -> CanvasText.rasterize(canvas, 'x', '10px a', new gpui.Bounds(new Point(0, 0), new gpui.Size(4097, 1)), 0, 0, false));
        assertRaises(() -> CanvasText.rasterize(canvas, 'x', '10px a', new gpui.Bounds(new Point(0, 0), new gpui.Size(4096, 1025)), 0, 0, false));
        assertRaises(() -> CanvasText.rasterize(canvas, 'x', '10px a', new gpui.Bounds(new Point(0, 0), new gpui.Size(2, 2)), Math.NaN, 0, false));
        assertRaises(() -> CanvasText.rasterize(canvas, 'x', ' ', new gpui.Bounds(new Point(0, 0), new gpui.Size(2, 2)), 0, 0, false));
    }

    static function lineOf(p:CeramicTextSystem, text:String, family:String = 'Inter', size:Float = 16):LineLayout {
        final fontId = p.fontId(Font.of(family));
        return p.layoutLine(text, size, [new FontRun(Utf8.byteLength(text), fontId)]);
    }

    static function describe(l:LineLayout):Array<String> {
        final result:Array<String> = [];
        for (run in l.runs)
            for (g in run.glyphs)
                result.push('${CanvasFallbackText.isCanvasFontId(run.fontId) ? 'canvas' : 'native'}:${(g.id:Int)}:${g.index}:${g.position.x}:${g.isEmoji}');
        return result;
    }

    function testLayoutWithoutCanvasKeepsMissingGlyphs() {
        final p = new CeramicTextSystem('Inter');
        p.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        final l = lineOf(p, 'a中😀b');
        for (run in l.runs)
            assertFalse(CanvasFallbackText.isCanvasFontId(run.fontId));
        // Same layout with the policy Disabled and a canvas
        assertEquals(describe(l).join(' '), describe(lineOf(platform(Disabled), 'a中😀b')).join(' '));
        assertEquals((l.width:Float), (lineOf(platform(Disabled), 'a中😀b').width:Float));
    }

    function testLayoutEmojiPolicy() {
        final plain = new CeramicTextSystem('Inter');
        plain.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        final native = lineOf(plain, 'a中😀b');
        final nativeGlyphs = describe(native);
        assertEquals(4, nativeGlyphs.length);

        final p = platform(Emoji);
        final l = lineOf(p, 'a中😀b');
        final glyphs = describe(l);
        assertEquals(4, glyphs.length);
        // a and 中 stay native (中 is CJK: not allowed by the Emoji policy)
        assertEquals(nativeGlyphs[0], glyphs[0]);
        assertEquals(nativeGlyphs[1], glyphs[1]);
        // 😀 becomes canvas glyph 0, emoji presentation, at the native position
        assertEquals('canvas:0:4:${flat(native)[2].position.x}:true', glyphs[2]);
        // b moves by the canvas advance minus the notdef advance
        final oldWidth = flat(native)[3].position.x - flat(native)[2].position.x;
        final delta = ttf.shape.Shaper.f32(16 * 0.75 - oldWidth);
        assertEquals(ttf.shape.Shaper.f32(flat(native)[3].position.x + delta), flat(l)[3].position.x);
        assertEquals(ttf.shape.Shaper.f32((native.width:Float) + delta), (l.width:Float));
        // Line metrics stay those of the primary font
        assertEquals((native.ascent:Float), (l.ascent:Float));
        assertEquals((native.descent:Float), (l.descent:Float));
        // Runs: native [a 中], canvas [😀], native [b]
        assertEquals(3, l.runs.length);
        assertEquals((1 << 31), (l.runs[1].fontId:Int));
    }

    static function flat(l:LineLayout):Array<ShapedGlyph> {
        return [for (run in l.runs) for (g in run.glyphs) g];
    }

    function testLayoutEmojiAndCjkPolicy() {
        final canvas = new FakeCanvas();
        final p = platform(EmojiAndCjk, canvas);
        final l = lineOf(p, 'a中😀b');
        final glyphs = describe(l);
        assertEquals(4, glyphs.length);
        assertTrue(StringTools.startsWith(glyphs[0], 'native:'));
        assertTrue(StringTools.startsWith(glyphs[1], 'canvas:0:1:'));
        assertTrue(StringTools.endsWith(glyphs[1], ':false'));
        assertTrue(StringTools.startsWith(glyphs[2], 'canvas:1:4:'));
        assertTrue(StringTools.endsWith(glyphs[2], ':true'));
        assertTrue(StringTools.startsWith(glyphs[3], 'native:'));
        // 中 and 😀 are consecutive canvas glyphs of the same canvas font: one run
        assertEquals(3, l.runs.length);
        assertEquals(2, l.runs[1].glyphs.length);
        // 中 advances by 0.75 em, so 😀 starts 12 px after it
        assertEquals(ttf.shape.Shaper.f32(flat(l)[1].position.x + 12), flat(l)[2].position.x);
        assertEquals(['normal 400 16px "Inter", sans-serif', 'normal 400 16px emoji'].join('|'), canvas.fonts.join('|'));
        // A second layout measures nothing new
        lineOf(p, '中😀');
        assertEquals(2, canvas.measureCalls);
        // ASCII lines are left alone
        lineOf(p, 'Hello');
        assertEquals(2, canvas.measureCalls);
    }

    function testLayoutKeepsCoveredGraphemes() {
        // Inter covers é, ©, and → (text presentation): nothing to replace
        final p = platform(EmojiAndCjk);
        final plain = new CeramicTextSystem('Inter');
        plain.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        assertEquals(describe(lineOf(plain, 'é © →')).join(' '), describe(lineOf(p, 'é © →')).join(' '));
        // An emoji presentation request on a covered symbol has no color glyph: canvas
        final l = lineOf(p, '©\u{FE0F}');
        assertTrue(CanvasFallbackText.isCanvasFontId(l.runs[0].fontId));
        assertTrue(l.runs[0].glyphs[0].isEmoji);
    }

    function testLayoutAcrossCanvasFontRunsUsesNativeFonts() {
        final p = platform(EmojiAndCjk);
        final inter = p.fontId(Font.of('Inter'));
        final c = p.canvas.canvasFontId(inter);
        final text = 'a中';
        final viaCanvas = p.layoutLine(text, 16, [new FontRun(Utf8.byteLength(text), c)]);
        final viaNative = p.layoutLine(text, 16, [new FontRun(Utf8.byteLength(text), inter)]);
        assertEquals(describe(viaNative).join(' '), describe(viaCanvas).join(' '));
    }

    function testDefaultTextSystemHasNoCanvasOnNode() {
        #if (js && !gpui_no_canvas_fallback)
        if (!gpui.platform.CanvasText.BrowserCanvasText.available()) {
            final ts:CeramicTextSystem = cast gpui.App.defaultTextSystem().platformTextSystem;
            assertNull(ts.canvasText);
            assertEquals(Emoji, ts.canvasFontFallback);
        }
        #else
        assertTrue(true);
        #end
    }

    static inline function referenceContent():String {
        return CanvasFallbackReference.content();
    }

}

/**
 * A canvas that measures every grapheme as a box of the font size (advance
 * 0.75 em, ink from 0.0625 to 0.6875 em, ascent 0.75 em, descent 0.125 em)
 * and fills every pixel with (pixel index % 256, 1, 2, 200).
 */
class FakeCanvas implements CanvasTextBackend {

    public final fonts:Array<String> = [];

    public var measureCalls:Int = 0;

    public var lastFill:Null<{text:String, font:String, width:Int, height:Int, x:Float, y:Float}> = null;

    public function new() {}

    static function sizeOf(cssFont:String):Float {
        final re = ~/([0-9.]+)px/;
        if (!re.match(cssFont))
            throw 'no size in $cssFont';
        return Std.parseFloat(re.matched(1));
    }

    public function measureText(text:String, cssFont:String, result:Array<Float>):Void {
        measureCalls++;
        fonts.push(cssFont);
        final s = sizeOf(cssFont);
        result[0] = s * 0.75;
        result[1] = -s * 0.0625;
        result[2] = s * 0.6875;
        result[3] = s * 0.75;
        result[4] = s * 0.125;
    }

    public function fillText(text:String, cssFont:String, width:Int, height:Int, x:Float, y:Float):Bytes {
        lastFill = {text: text, font: cssFont, width: width, height: height, x: x, y: y};
        final bytes = Bytes.alloc(width * height * 4);
        for (p in 0...width * height) {
            bytes.set(p * 4, p % 256);
            bytes.set(p * 4 + 1, 1);
            bytes.set(p * 4 + 2, 2);
            bytes.set(p * 4 + 3, 200);
        }
        return bytes;
    }

}

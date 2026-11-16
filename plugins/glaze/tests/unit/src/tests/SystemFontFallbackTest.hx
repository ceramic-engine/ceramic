package tests;

import glaze.Font;
import glaze.FontRun;
import glaze.LineLayout;
import glaze.RenderGlyphParams;
import glaze.platform.CeramicTextSystem;
import glaze.platform.SystemFontFallback;
import glaze.platform.SystemFontFile;
import glaze.util.Utf8;
import testing.TestCase;

/**
 * Fallback on the fonts of the operating system (`SystemFontFallback`) for
 * characters missing from the added fonts. The tests that need system fonts
 * are skipped where the expected files do not exist (they run on macOS,
 * native or node, since `ceramic.Files` reads files on both).
 */
class SystemFontFallbackTest extends TestCase {

    /** Inter and JetBrains Mono, with or without the system fallback */
    static function platform(withSystemFonts:Bool):CeramicTextSystem {
        final platform = new CeramicTextSystem('Inter');
        platform.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        if (withSystemFonts)
            platform.systemFallback = new SystemFontFallback();
        return platform;
    }

    static function layout(platform:CeramicTextSystem, text:String, family:String = 'Inter'):LineLayout {
        final fontId = platform.fontId(Font.of(family));
        return platform.layoutLine(text, 16, [new FontRun(Utf8.byteLength(text), fontId)]);
    }

    /** Glyph id and font id of the glyph at a byte index */
    static function glyphAt(layout:LineLayout, index:Int):Null<{glyphId:Int, fontId:Int}> {
        for (run in layout.runs)
            for (glyph in run.glyphs)
                if (glyph.index == index)
                    return {glyphId: (glyph.id:Int), fontId: (run.fontId:Int)};
        return null;
    }

    static function hasMacFonts():Bool {
        return ceramic.Files.exists('/System/Library/Fonts/Hiragino Sans GB.ttc')
            && ceramic.Files.exists('/System/Library/Fonts/Apple Symbols.ttf');
    }

    /** Checks every non-ASCII character of `text` gets a real glyph of a system font, with ink */
    function assertSystemGlyphs(platform:CeramicTextSystem, text:String, ?pos:haxe.PosInfos) {
        final line = layout(platform, text);
        final interId = (platform.fontId(Font.of('Inter')):Int);
        final d = new glaze.util.Utf8.Utf8Text(text);
        for (k in 0...d.count) {
            final c = d.codePoints[k];
            final index = d.byteOffsets[k];
            final g = glyphAt(line, index);
            assertNotNull(g, 'glyph at $index', pos);
            if (g == null)
                continue;
            if (c <= 0x7F) {
                assertEquals(interId, g.fontId, 'ASCII stays on Inter', pos);
                continue;
            }
            assertTrue(g.glyphId != 0, 'U+${StringTools.hex(c, 4)} has a glyph', pos);
            final family = platform.ttfFont(g.fontId).familyName;
            assertTrue(family != 'Inter' && family != 'JetBrains Mono', 'U+${StringTools.hex(c, 4)} from a system font ($family)', pos);
            final bounds = platform.glyphRasterBounds(new RenderGlyphParams(g.fontId, g.glyphId, 16, 0, 0, 2));
            assertTrue(bounds.size.width > 0 && bounds.size.height > 0, 'U+${StringTools.hex(c, 4)} has ink', pos);
            final mask = platform.rasterizeGlyph(new RenderGlyphParams(g.fontId, g.glyphId, 16, 0, 0, 2), bounds);
            var sum = 0;
            for (i in 0...mask.length)
                sum += mask.get(i);
            assertTrue(sum > 0, 'U+${StringTools.hex(c, 4)} mask is not empty', pos);
        }
    }

    function testWithoutSystemFallbackCjkIsMissing() {
        final p = platform(false);
        final line = layout(p, 'Hello 世界');
        assertEquals(0, glyphAt(line, 6).glyphId);
        assertEquals(0, glyphAt(line, 9).glyphId);
    }

    function testBundledFontsLackTheTestCharacters() {
        // Preconditions of the tests below: these come from system fonts
        final p = platform(false);
        final inter = p.fontId(Font.of('Inter'));
        final mono = p.fontId(Font.of('JetBrains Mono'));
        for (c in ['世'.code, '，'.code, 'あ'.code, '가'.code, 0x2603, 0x265E, 0x2654]) {
            assertNull(p.glyphForChar(inter, c), 'Inter lacks U+${StringTools.hex(c, 4)}');
            assertNull(p.glyphForChar(mono, c), 'JetBrains Mono lacks U+${StringTools.hex(c, 4)}');
        }
    }

    function testAsciiAndLatinLoadNoSystemFont() {
        final p = platform(true);
        layout(p, 'Hello world, café → ⌘K ─┼─');
        assertEquals(0, p.systemFallback.loadedPaths.length);
    }

    function testCjkFromSystemFonts() {
        if (!hasMacFonts())
            return;
        final p = platform(true);
        assertSystemGlyphs(p, 'Hello 世界，这是 GPUI 组件。重試');
        // Only the font of Han ideographs was read
        assertEquals(1, p.systemFallback.loadedPaths.length);
        assertEquals('/System/Library/Fonts/Hiragino Sans GB.ttc', p.systemFallback.loadedPaths[0]);
        // Kana is in that font too, but kana prefer the kana font of the
        // list (Hiragino Sans, see testKanaPreferTheirOwnFontAfterHan);
        // hangul needs Apple SD Gothic Neo
        assertSystemGlyphs(p, 'あいうえお カタカナ 가나다');
        assertEquals(3, p.systemFallback.loadedPaths.length);
        trace('System fallback: ${p.systemFallback.loadedPaths.join(', ')}: '
            + '${Math.round(p.systemFallback.loadedBytes / 1048576)} MB read in ${Math.round(p.systemFallback.loadTime * 1000)} ms');
    }

    function testSymbolsFromSystemFonts() {
        if (!hasMacFonts())
            return;
        final p = platform(true);
        assertSystemGlyphs(p, 'Snow ☃ chess ♞♔');
        assertTrue(p.systemFallback.loadedPaths.length >= 1);
        // No CJK font was needed for these
        for (path in p.systemFallback.loadedPaths)
            assertTrue(path.indexOf('Hiragino') == -1 && path.indexOf('Heiti') == -1, path);
        trace('System fallback for symbols: ${p.systemFallback.loadedPaths.join(', ')}: '
            + '${Math.round(p.systemFallback.loadedBytes / 1048576)} MB read in ${Math.round(p.systemFallback.loadTime * 1000)} ms');
    }

    function testHalfwidthArrowsFromAppleSymbols() {
        if (!hasMacFonts())
            return;
        // U+FFEB (halfwidth rightwards arrow, measured by code editors for
        // their rendering of control characters) and its neighbours are in
        // no CJK font of macOS: CoreText draws them with Apple Symbols, which
        // comes before Arial Unicode in the list of Han fallbacks
        final p = platform(true);
        assertSystemGlyphs(p, 'a\uFFE9\uFFEA\uFFEB\uFFEC\uFFED\uFFEEb');
        assertEquals(1, p.systemFallback.loadedPaths.length);
        assertEquals('/System/Library/Fonts/Apple Symbols.ttf', p.systemFallback.loadedPaths[0]);
    }

    function testTrueTypeSystemFilesReadOnDemand() {
        if (!hasMacFonts())
            return;
        // TrueType and CFF files of the system are read piece by piece
        // (`SystemFontFile`): the same outlines, advances and variable
        // instances as the whole file, for a fraction of its bytes
        final paths = ['/System/Library/Fonts/Apple Symbols.ttf', '/System/Library/Fonts/SFNS.ttf', '/System/Library/Fonts/Menlo.ttc',
            '/Library/Fonts/Arial Unicode.ttf', '/System/Library/Fonts/Hiragino Sans GB.ttc', '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc'];
        final text = 'Snow \u2603 chess \u265E\u2654 \u03B1\u03B2 \u0416 \u05D0 \u4E16 \u21C4 \u2713 mw0 \uFF4D \u3042\u30A4 \u4E2D\u6587';
        final d = new glaze.util.Utf8.Utf8Text(text);
        for (path in paths) {
            if (!ceramic.Files.exists(path))
                continue;
            final file = SystemFontFile.open(path);
            assertNotNull(file, path);
            assertTrue(file.onDemand, path);
            final bytes = ceramic.Files.getBytes(path);
            for (index in 0...file.faceCount) {
                final whole = ttf.Font.fromBytes(bytes, index);
                final partial = file.face(index);
                final fonts = [[whole, partial]];
                if (whole.isVariable)
                    fonts.push([whole.instanceForWeight(700), partial.instanceForWeight(700)]);
                for (pair in fonts) {
                    for (k in 0...d.count) {
                        final gid = pair[0].glyphForChar(d.codePoints[k]);
                        final label = '$path #$index U+${StringTools.hex(d.codePoints[k], 4)}';
                        assertEquals(gid, pair[1].glyphForChar(d.codePoints[k]), label);
                        assertEquals(pair[0].advance(gid), pair[1].advance(gid), 'advance of $label');
                        assertEquals(outlineOf(pair[0], gid), outlineOf(pair[1], gid), 'outline of $label');
                    }
                }
            }
            assertTrue(file.bytesRead < bytes.length / 2, '$path: ${file.bytesRead} bytes read of ${bytes.length}');
            // First use of a glyph (outline of a glyph never drawn): fresh
            // faces, the same glyphs, whole file in memory against on demand
            final gids = [];
            final firstWhole = ttf.Font.fromBytes(bytes, 0);
            var gid = 1;
            final step = Std.int(Math.max(1, firstWhole.numGlyphs / 200));
            while (gid < firstWhole.numGlyphs) {
                gids.push(gid);
                gid += step;
            }
            final freshFile = SystemFontFile.open(path);
            final firstPartial = freshFile.face(0);
            final readAtLoad = freshFile.bytesRead;
            final sink = new RecordingSink(new StringBuf());
            var t0 = haxe.Timer.stamp();
            for (g in gids)
                firstWhole.outlineScaled(g, 13, sink);
            final wholeTime = haxe.Timer.stamp() - t0;
            t0 = haxe.Timer.stamp();
            for (g in gids)
                firstPartial.outlineScaled(g, 13, sink);
            final partialTime = haxe.Timer.stamp() - t0;
            trace('$path: ${Math.round(file.bytesRead / 1024)} KB read of ${Math.round(bytes.length / 1024)} KB after ${d.count} characters'
                + ' (face 0: ${Math.round(readAtLoad / 1024)} KB at load, ${Math.round(freshFile.bytesRead / 1024)} KB after ${gids.length} more glyphs);'
                + ' first outline of a glyph: ${Math.round(wholeTime / gids.length * 1e7) / 10} us whole, ${Math.round(partialTime / gids.length * 1e7) / 10} us on demand');
        }
    }

    static function outlineOf(font:ttf.Font, gid:Int):String {
        final out = new StringBuf();
        font.outline(gid, new RecordingSink(out));
        final scaled = new StringBuf();
        font.outlineScaled(gid, 13, new RecordingSink(scaled));
        return out.toString() + '|' + scaled.toString();
    }

    function testUnmappedCharacterReadsNoFontFile() {
        if (!hasMacFonts())
            return;
        // U+2E31 (word separator middle dot, measured by code editors for
        // their rendering of white space) is in no font of macOS: the
        // candidate files are probed (character maps only), none is read
        final p = platform(true);
        final line = layout(p, 'a\u2E31b');
        assertEquals(0, glyphAt(line, 1).glyphId);
        assertEquals(0, p.systemFallback.loadedPaths.length);
        assertEquals(0, p.systemFallback.faces.length);
        assertEquals(0.0, p.systemFallback.loadedBytes);
        assertTrue(p.systemFallback.probedBytes > 0, 'character maps were read');
        assertTrue(p.systemFallback.probedBytes < 8 * 1048576, 'probes read ${p.systemFallback.probedBytes} bytes');
        trace('System fallback probes for U+2E31: ${Math.round(p.systemFallback.probedBytes / 1024)} KB of character maps read in '
            + '${Math.round(p.systemFallback.loadTime * 1000)} ms, no file read');
        // The files left unread still serve the next characters
        assertSystemGlyphs(p, 'Snow ☃');
        assertTrue(p.systemFallback.loadedPaths.length >= 1);
    }

    function testProbesGiveTheSameGlyphsAsWholeReads() {
        if (!hasMacFonts())
            return;
        // Reference: every tried file read whole (the behaviour before the
        // probes). The same texts in the same order must get the same
        // glyphs from the same faces, with fewer files read.
        final whole = platform(true);
        whole.systemFallback.probeBeforeLoading = false;
        final probed = platform(true);
        final texts = [
            'a\u2E31b', 'full ｍ width', 'Snow ☃ chess ♞♔', 'Hello 世界，这是', 'あいうえお カタカナ', '가나다',
            'apple \uF8FF logo', 'arrows ⇄ ⟲ ✓ ✗ ★', 'again ｍ ☃ 世 あ 가 \u2E31', 'ελληνικά кириллица עברית'
        ];
        for (family in ['Inter', 'JetBrains Mono']) {
            for (text in texts) {
                final expected = layout(whole, text, family);
                final actual = layout(probed, text, family);
                final d = new glaze.util.Utf8.Utf8Text(text);
                for (k in 0...d.count) {
                    final index = d.byteOffsets[k];
                    final e = glyphAt(expected, index);
                    final a = glyphAt(actual, index);
                    final label = 'U+${StringTools.hex(d.codePoints[k], 4)} of "$text" in $family';
                    assertEquals(e == null, a == null, label);
                    if (e == null || a == null)
                        continue;
                    assertEquals(e.glyphId, a.glyphId, 'glyph of $label');
                    assertEquals(whole.ttfFont(e.fontId).postScriptName, probed.ttfFont(a.fontId).postScriptName, 'face of $label');
                }
                assertEquals(expected.width, actual.width, 'width of "$text" in $family');
            }
        }
        for (path in probed.systemFallback.loadedPaths)
            assertTrue(whole.systemFallback.loadedPaths.indexOf(path) != -1, '$path is also read without probes');
        assertTrue(probed.systemFallback.loadedPaths.length < whole.systemFallback.loadedPaths.length,
            '${probed.systemFallback.loadedPaths.length} files read with probes, ${whole.systemFallback.loadedPaths.length} without');
        assertTrue(probed.systemFallback.loadedBytes < whole.systemFallback.loadedBytes);
        trace('System fallback with probes: ${probed.systemFallback.loadedPaths.length} files, '
            + '${Math.round(probed.systemFallback.loadedBytes / 1048576)} MB read; without: ${whole.systemFallback.loadedPaths.length} files, '
            + '${Math.round(whole.systemFallback.loadedBytes / 1048576)} MB');
    }

    function testCjkInMonospaceText() {
        if (!hasMacFonts())
            return;
        final p = platform(true);
        final line = layout(p, 'let s = "你好";', 'JetBrains Mono');
        final g = glyphAt(line, 9);
        assertTrue(g.glyphId != 0);
        assertEquals('Hiragino Sans GB', p.ttfFont(g.fontId).familyName);
    }

    function testFaceClosestToThePrimaryWeight() {
        if (!hasMacFonts())
            return;
        final p = platform(true);
        // Hiragino Sans GB has W3 and W6 faces: Inter Regular gets W3
        final line = layout(p, '世界');
        final face = p.ttfFont(glyphAt(line, 0).fontId);
        assertEquals('HiraginoSansGB-W3', face.postScriptName);
    }

    function testEmojiStaysMissingWithoutAnEmojiFont() {
        final p = platform(false);
        p.systemFallback = new SystemFontFallback({han: [], kana: [], hangul: [], other: [], emoji: ['/nonexistent/emoji.ttc']});
        final line = layout(p, 'Go 🚀');
        assertEquals(0, glyphAt(line, 3).glyphId);
        assertEquals(0, p.systemFallback.loadedPaths.length);
    }

    static final APPLE_EMOJI = '/System/Library/Fonts/Apple Color Emoji.ttc';

    /** Checks the glyph at `index` is a polychrome glyph of Apple Color Emoji with a colored BGRA tile */
    function assertColorEmoji(p:CeramicTextSystem, line:LineLayout, index:Int, requireColors:Bool = true, ?pos:haxe.PosInfos) {
        var glyph:Null<glaze.ShapedGlyph> = null;
        var fontId = -1;
        // The first glyph of the cluster (a variation selector after it is a
        // hidden glyph of the same cluster, like HarfBuzz's)
        for (run in line.runs)
            for (g in run.glyphs)
                if (g.index == index && glyph == null) {
                    glyph = g;
                    fontId = (run.fontId:Int);
                }
        assertNotNull(glyph, 'glyph at $index', pos);
        if (glyph == null)
            return;
        assertEquals('Apple Color Emoji', p.ttfFont(fontId).familyName, pos);
        assertTrue(glyph.isEmoji, 'polychrome glyph at $index', pos);
        assertTrue((glyph.id:Int) != 0, 'real glyph at $index', pos);
        final params = new RenderGlyphParams(fontId, glyph.id, 16, 0, 0, 2, true);
        final bounds = p.glyphRasterBounds(params);
        // 32 px per em: the 32 px strike, its bottom 4 px (100 font units) below the baseline
        assertEquals(32.0, bounds.size.width, pos);
        assertEquals(32.0, bounds.size.height, pos);
        assertEquals(-28.0, bounds.origin.y, pos);
        final tile = p.rasterizeGlyph(params, bounds);
        assertEquals(32 * 32 * 4, tile.length, pos);
        var opaque = 0;
        var colored = 0;
        var i = 0;
        while (i < tile.length) {
            final b = tile.get(i), g = tile.get(i + 1), r = tile.get(i + 2), a = tile.get(i + 3);
            if (a > 0)
                opaque++;
            if (a > 128 && (Math.abs(r - g) > 40 || Math.abs(g - b) > 40))
                colored++;
            i += 4;
        }
        assertTrue(opaque > 32 * 32 / 4, 'tile has ink ($opaque pixels)', pos);
        // Some emoji are grey (keycaps, the families of Apple Color Emoji)
        if (requireColors)
            assertTrue(colored > 0, 'tile has colors ($colored pixels)', pos);
    }

    function testEmojiFromTheSystemEmojiFont() {
        if (!ceramic.Files.exists(APPLE_EMOJI))
            return;
        final p = platform(true);
        final text = 'Go 🚀 ok';
        final line = layout(p, text);
        assertColorEmoji(p, line, 3);
        // Advances from the font (1 em at 16 px), ASCII stays on Inter
        final interId = (p.fontId(Font.of('Inter')):Int);
        assertEquals(interId, glyphAt(line, 0).fontId);
        assertEquals(interId, glyphAt(line, 8).fontId);
        var rocketX = -1.0, nextX = -1.0;
        for (run in line.runs)
            for (g in run.glyphs) {
                if (g.index == 3) rocketX = g.position.x;
                if (g.index == 7) nextX = g.position.x;
            }
        assertEquals(16.0, nextX - rocketX);
        // Only the emoji font was read, and only its small tables
        assertEquals(1, p.systemFallback.loadedPaths.length);
        assertEquals(APPLE_EMOJI, p.systemFallback.loadedPaths[0]);
        assertTrue(p.systemFallback.loadedBytes < 2 * 1048576, 'read ${p.systemFallback.loadedBytes} bytes');
        trace('Emoji fallback: ${Math.round(p.systemFallback.loadedBytes / 1024)} KB of Apple Color Emoji read in ${Math.round(p.systemFallback.loadTime * 1000)} ms');
    }

    function testEmojiSequencesUseTheEmojiFont() {
        if (!ceramic.Files.exists(APPLE_EMOJI))
            return;
        final p = platform(true);
        // Variation selector 16 on a text default character Inter lacks, a
        // keycap, a skin tone
        final text = 'a ☺️ 1️⃣ 👍🏽';
        final line = layout(p, text);
        assertColorEmoji(p, line, 2);
        assertColorEmoji(p, line, Utf8.byteLength('a ☺️ '), false);
        final thumb = Utf8.byteLength('a ☺️ 1️⃣ ');
        assertColorEmoji(p, line, thumb);
        // Inter maps ❤: like cosmic-text (golden scene kit-emoji-bundled),
        // ❤️ stays on it (variation selector 16 is default ignorable)
        final heart = glyphAt(layout(p, 'a ❤️'), 2);
        assertEquals('Inter', p.ttfFont(heart.fontId).familyName);
        // Sequences are one glyph (morx ligatures): a family, a flag, a skin
        // tone with a profession
        for (sequence in ['👨‍👩‍👧', '🇫🇷', '👩🏽‍💻']) {
            final seqLine = layout(p, 'x' + sequence);
            assertColorEmoji(p, seqLine, 1, sequence != '👨‍👩‍👧');
            var count = 0;
            for (run in seqLine.runs)
                for (g in run.glyphs)
                    if (g.index > 0 && (g.id:Int) != p.ttfFont(run.fontId).glyphForChar(0x20))
                        count++;
            assertEquals(1, count, 'one glyph for $sequence');
        }
        // Variation selector 15 keeps the text presentation
        final plain = layout(p, 'a ❤︎');
        final g = glyphAt(plain, 2);
        assertTrue(p.ttfFont(g.fontId).familyName != 'Apple Color Emoji');
    }

    function testEmojiKeepsTheLineMetricsOfTheText() {
        if (!ceramic.Files.exists(APPLE_EMOJI))
            return;
        final p = platform(true);
        final plain = layout(p, 'Hello world');
        final emoji = layout(p, 'Hello 🌍');
        // GPUI keeps the line height of the style; the layout's own ascent
        // and descent follow the fonts of its glyphs (cosmic-text's max)
        assertTrue(emoji.ascent >= plain.ascent);
        assertEquals(16.0, emoji.fontSize);
    }

    function testLocalePrefersRegionalFaces() {
        if (!ceramic.Files.exists('/System/Library/Fonts/STHeiti Light.ttc'))
            return;
        final p = platform(false);
        final fallback = new SystemFontFallback();
        fallback.cjkLocale = 'zh-TW';
        p.systemFallback = fallback;
        final line = layout(p, '重試');
        final face = p.ttfFont(glyphAt(line, 0).fontId);
        assertEquals('Heiti TC', face.familyName);
    }

    function testCustomCandidatesAndMissingFiles() {
        final p = platform(false);
        p.systemFallback = new SystemFontFallback({han: ['/nonexistent/font.ttc'], kana: [], hangul: [], other: []});
        final line = layout(p, '世');
        assertEquals(0, glyphAt(line, 0).glyphId);
        assertEquals(0, p.systemFallback.loadedPaths.length);
    }

    /**
     * Kana come from the kana font of the system list (Hiragino Sans on
     * macOS) even after Han text loaded Hiragino Sans GB, which maps kana
     * too, like the per script fallbacks of a browser and cosmic-text.
     */
    function testKanaPreferTheirOwnFontAfterHan() {
        if (!hasMacFonts() || !ceramic.Files.exists('/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc'))
            return;
        final p = platform(true);
        final text = '雨が降って';
        final line = layout(p, text);
        assertEquals('Hiragino Sans GB', p.ttfFont(glyphAt(line, 0).fontId).familyName);
        assertEquals('Hiragino Sans', p.ttfFont(glyphAt(line, 3).fontId).familyName);
        assertEquals('Hiragino Sans', p.ttfFont(glyphAt(line, 9).fontId).familyName);
    }

    /**
     * Whole run shaping (`Font.wholeRunShaping`) applies the kerning of the
     * fallback font across the break opportunities between CJK characters:
     * Hiragino Sans kerns `って` by -30 units (HarfBuzz, hb-shape), word by
     * word shaping (GPUI) does not.
     */
    function testWholeRunKerningOfKana() {
        if (!hasMacFonts() || !ceramic.Files.exists('/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc'))
            return;
        final p = platform(true);
        final text = 'って';
        final words = p.layoutLine(text, 1000, [new FontRun(Utf8.byteLength(text), p.fontId(Font.of('Inter')))]);
        assertFloatEquals(1000, words.runs[0].glyphs[1].position.x, 0.5);
        final font = Font.of('Inter');
        font.wholeRunShaping = true;
        final whole = p.layoutLine(text, 1000, [new FontRun(Utf8.byteLength(text), p.fontId(font))]);
        assertFloatEquals(970, whole.runs[0].glyphs[1].position.x, 0.5);
    }

    /** The generic family `monospace` is Menlo on macOS with the system fonts */
    function testGenericMonospaceIsThePlatformFont() {
        if (!ceramic.Files.exists('/System/Library/Fonts/Menlo.ttc'))
            return;
        final os = ceramic.App.app.backend.info.operatingSystem();
        if (os != 'mac' || glaze.platform.SystemFontFamilies.platformDirectories().length == 0)
            return;
        final p = platform(true);
        p.systemFamilies = new glaze.platform.SystemFontFamilies();
        assertEquals('Menlo', p.ttfFont(p.fontId(Font.of('monospace'))).familyName);
        // without the system fonts: the first monospace face added
        final q = platform(false);
        assertEquals('JetBrains Mono', q.ttfFont(q.fontId(Font.of('monospace'))).familyName);
    }
}

private class RecordingSink implements ttf.OutlineSink {

    final out:StringBuf;

    public function new(out:StringBuf) {
        this.out = out;
    }

    public function moveTo(x:Float, y:Float):Void {
        out.add('M$x,$y');
    }

    public function lineTo(x:Float, y:Float):Void {
        out.add('L$x,$y');
    }

    public function quadTo(cx:Float, cy:Float, x:Float, y:Float):Void {
        out.add('Q$cx,$cy,$x,$y');
    }

    public function cubicTo(c1x:Float, c1y:Float, c2x:Float, c2y:Float, x:Float, y:Float):Void {
        out.add('C$c1x,$c1y,$c2x,$c2y,$x,$y');
    }

    public function close():Void {
        out.add('Z');
    }

}

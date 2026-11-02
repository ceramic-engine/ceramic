package tests;

import gpui.Font;
import gpui.FontRun;
import gpui.LineLayout;
import gpui.RenderGlyphParams;
import gpui.platform.CeramicTextSystem;
import gpui.platform.SystemFontFallback;
import gpui.util.Utf8;
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
        final d = new gpui.util.Utf8.Utf8Text(text);
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
        // Kana is in that font too; hangul needs Apple SD Gothic Neo
        assertSystemGlyphs(p, 'あいうえお カタカナ 가나다');
        assertEquals(2, p.systemFallback.loadedPaths.length);
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
        var glyph:Null<gpui.ShapedGlyph> = null;
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
}

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

    function testEmojiStaysMissingAndLoadsNothing() {
        final p = platform(true);
        final line = layout(p, 'Go 🚀');
        assertEquals(0, glyphAt(line, 3).glyphId);
        assertEquals(0, p.systemFallback.loadedPaths.length);
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

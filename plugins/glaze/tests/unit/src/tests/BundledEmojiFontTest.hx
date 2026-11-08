package tests;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#else
import glaze.Font;
import glaze.FontRun;
import glaze.LineLayout;
import glaze.RenderGlyphParams;
import glaze.ShapedGlyph;
import glaze.platform.BundledEmojiFont;
import glaze.platform.CanvasFallbackText;
import glaze.platform.CeramicTextSystem;
import glaze.platform.SystemFontFallback;
import glaze.util.Utf8;
import testing.TestCase;
import tests.CanvasFallbackTest.FakeCanvas;
#end

/**
 * The bundled emoji font (Noto Color Emoji, define `glaze_bundled_emoji`,
 * `glaze.platform.BundledEmojiFont`): read piece by piece from the plugin's
 * asset file, emoji graphemes resolve to it as polychrome glyphs, sequences
 * are single glyphs (`GSUB`), it comes before the system emoji font and the
 * browser canvas, which keep what it lacks. The tests open the plugin's
 * file directly (the unit project does not ship it); with the define, the
 * default text system is checked too.
 */
class BundledEmojiFontTest #if !macro extends TestCase #end {

    #if !macro

    static var cachedFace:Null<ttf.Font> = null;

    /** The bundled face, opened from the plugin's asset file (once) */
    static function face():ttf.Font {
        if (cachedFace == null)
            cachedFace = BundledEmojiFont.openFile(fontPath());
        return cachedFace;
    }

    /** Inter, JetBrains Mono and the bundled emoji font */
    static function platform():CeramicTextSystem {
        final p = new CeramicTextSystem('Inter');
        p.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        p.addBundledEmojiFace(face());
        return p;
    }

    static function layout(p:CeramicTextSystem, text:String, size:Float = 16):LineLayout {
        final fontId = p.fontId(Font.of('Inter'));
        return p.layoutLine(text, size, [new FontRun(Utf8.byteLength(text), fontId)]);
    }

    /** First glyph of the cluster at `index` and its font id */
    static function glyphAt(line:LineLayout, index:Int):Null<{glyph:ShapedGlyph, fontId:Int}> {
        for (run in line.runs)
            for (g in run.glyphs)
                if (g.index == index)
                    return {glyph: g, fontId: (run.fontId:Int)};
        return null;
    }

    /** Glyphs of the cluster at `index` */
    static function clusterSize(line:LineLayout, index:Int):Int {
        var count = 0;
        for (run in line.runs)
            for (g in run.glyphs)
                if (g.index == index)
                    count++;
        return count;
    }

    /** Checks the glyph at `index` is a colored polychrome glyph of the bundled font */
    function assertBundledEmoji(p:CeramicTextSystem, line:LineLayout, index:Int, requireColors:Bool = true, ?pos:haxe.PosInfos) {
        final at = glyphAt(line, index);
        assertNotNull(at, 'glyph at $index', pos);
        if (at == null)
            return;
        assertEquals('Noto Color Emoji', p.ttfFont(at.fontId).familyName, pos);
        assertTrue(at.glyph.isEmoji, 'polychrome glyph at $index', pos);
        assertTrue((at.glyph.id:Int) > 3, 'real glyph at $index', pos);
        final params = new RenderGlyphParams(at.fontId, at.glyph.id, 16, 0, 0, 2, true);
        final bounds = p.glyphRasterBounds(params);
        assertTrue(bounds.size.width > 20 && bounds.size.height > 20, 'raster bounds ${bounds.size.width}x${bounds.size.height}', pos);
        final tile = p.rasterizeGlyph(params, bounds);
        assertEquals(Std.int(bounds.size.width) * Std.int(bounds.size.height) * 4, tile.length, pos);
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
        assertTrue(opaque > tile.length / 4 / 4, 'tile has ink ($opaque pixels)', pos);
        // Some emoji are grey or pale (the families, keycaps)
        if (requireColors)
            assertTrue(colored > 0, 'tile has colors ($colored pixels)', pos);
    }

    function testOpensFromTheAssetFileReadingOnlyItsTables() {
        final f = BundledEmojiFont.openFile(fontPath());
        assertNotNull(f);
        if (f == null)
            return;
        assertEquals('NotoColorEmoji', f.postScriptName);
        assertEquals('Noto Color Emoji', f.familyName);
        assertTrue(f.hasColorGlyphs);
        // 10.7 MB file, about 95 KB of tables read (the CBDT bitmaps stay in the file)
        assertTrue(ceramic.Files.getSize(fontPath()) > 10000000);
        assertTrue(BundledEmojiFont.loadedBytes < 200 * 1024, 'read ${BundledEmojiFont.loadedBytes} bytes');
        trace('Bundled emoji font: ${Math.round(BundledEmojiFont.loadedBytes / 1024)} KB read in ${Math.round(BundledEmojiFont.loadTime * 10000) / 10} ms');
        // Missing or foreign files are refused
        assertNull(BundledEmojiFont.openFile('/nonexistent/NotoColorEmoji.ttf'));
        assertNull(BundledEmojiFont.openBytes(TextFixtures.interBytes()));
        assertNull(BundledEmojiFont.openBytes(null));
    }

    function testWholeFileBytesGiveTheSameFace() {
        // The browser path parses the whole file
        final bytes = ceramic.Files.getBytes(fontPath());
        final whole = BundledEmojiFont.openBytes(bytes);
        assertNotNull(whole);
        if (whole == null)
            return;
        assertEquals(face().numGlyphs, whole.numGlyphs);
        for (c in [0x1F600, 0x1F680, 0x2764, 0x1F1EB])
            assertEquals(face().glyphForChar(c), whole.glyphForChar(c));
    }

    function testEmojiResolveToTheBundledFont() {
        final p = platform();
        final text = 'Go 🚀 ok';
        final line = layout(p, text);
        assertBundledEmoji(p, line, 3);
        final interId = (p.fontId(Font.of('Inter')):Int);
        assertEquals(interId, glyphAt(line, 0).fontId);
        assertEquals(interId, glyphAt(line, 8).fontId);
        // Advance from the font: 2550 / 2048 em at 16 px
        final rocket = glyphAt(line, 3).glyph.position.x;
        final next = glyphAt(line, 7).glyph.position.x;
        final advance = p.ttfFont(glyphAt(line, 3).fontId).advance(glyphAt(line, 3).glyph.id) / 2048;
        assertEquals(ttf.shape.Shaper.f32(16 * ttf.shape.Shaper.f32(advance)), ttf.shape.Shaper.f32(next - rocket));
    }

    function testSequencesAreSingleGlyphs() {
        final p = platform();
        for (sequence in ['👨‍👩‍👧‍👦', '👍🏽', '🇫🇷', '🇯🇵', '1️⃣', '#️⃣', '☺️', '🏳️‍🌈', '🧑🏿‍💻', '✌🏻']) {
            final line = layout(p, 'x' + sequence);
            assertBundledEmoji(p, line, 1, sequence.indexOf('👨') == -1 && sequence.indexOf('\u{20E3}') == -1);
            assertEquals(1, clusterSize(line, 1), 'one glyph for $sequence');
            var others = 0;
            for (run in line.runs)
                for (g in run.glyphs)
                    if (g.index > 1)
                        others++;
            assertEquals(0, others, 'no glyph after the cluster of $sequence');
        }
    }

    function testPrimaryFontKeepsTheClustersItCovers() {
        // cosmic-text keeps a cluster on the first font that shapes it without
        // a notdef glyph: Inter maps ❤, and variation selector 16 is default
        // ignorable, so ❤️ is Inter's monochrome heart in GPUI (golden scene
        // kit-emoji-bundled); ☺ is missing from Inter, so ☺️ is a color emoji
        final p = platform();
        final line = layout(p, 'a ❤️ ☺️ ©');
        final heart = glyphAt(line, 2);
        assertEquals('Inter', p.ttfFont(heart.fontId).familyName);
        assertFalse(heart.glyph.isEmoji);
        assertTrue((heart.glyph.id:Int) != 0);
        assertBundledEmoji(p, line, Utf8.byteLength('a ❤️ '));
        assertEquals('Inter', p.ttfFont(glyphAt(line, Utf8.byteLength('a ❤️ ☺️ ')).fontId).familyName);
        // A keycap: Inter maps the digit but not U+20E3, the cluster goes to the emoji font
        final keycap = layout(p, 'a 1️⃣');
        assertBundledEmoji(p, keycap, 2, false);
    }

    function testEmojiAtSeveralSizes() {
        final p = platform();
        for (size in [12.0, 16.0, 24.0, 40.0]) {
            final line = layout(p, '😀', size);
            final at = glyphAt(line, 0);
            assertTrue(at.glyph.isEmoji);
            final params = new RenderGlyphParams(at.fontId, at.glyph.id, size, 0, 0, 2, true);
            final bounds = p.glyphRasterBounds(params);
            // The 136 px strike scaled to the size (2550 / 2048 em wide)
            assertTrue(Math.abs(bounds.size.width - size * 2 * 2550 / 2048) <= 2, 'width ${bounds.size.width} at $size');
            assertEquals(Std.int(bounds.size.width) * Std.int(bounds.size.height) * 4, p.rasterizeGlyph(params, bounds).length);
        }
    }

    function testTheBundledFontComesBeforeTheSystemEmojiFont() {
        // A system emoji font that maps 😀 too (the COLR test font of ttf)
        final p = platform();
        p.systemFallback = new SystemFontFallback({han: [], kana: [], hangul: [], other: [], emoji: [ttfTestFont('ColrTest.ttf')]});
        final line = layout(p, 'a 😀 b');
        assertBundledEmoji(p, line, 2);
        assertEquals(0, p.systemFallback.loadedPaths.length);
        // What the bundled font lacks (a color A) still loads the system
        // emoji font; Inter maps A and variation selector 16 is ignorable,
        // so the cluster stays on Inter (cosmic-text's rule)
        final other = layout(p, 'A\u{FE0F}');
        assertEquals(1, p.systemFallback.loadedPaths.length);
        assertEquals('Inter', p.ttfFont(glyphAt(other, 0).fontId).familyName);
    }

    /** Time from nothing loaded to the first emoji tile, with the bundled font and with the system emoji font */
    function testTimeToFirstEmoji() {
        function firstEmoji(p:CeramicTextSystem):Float {
            final start = haxe.Timer.stamp();
            final line = layout(p, 'a 😀');
            final at = glyphAt(line, 2);
            final params = new RenderGlyphParams(at.fontId, at.glyph.id, 16, 0, 0, 2, true);
            final tile = p.rasterizeGlyph(params, p.glyphRasterBounds(params));
            assertTrue(tile.length > 0);
            return haxe.Timer.stamp() - start;
        }
        final bundled = new CeramicTextSystem('Inter');
        bundled.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        final start = haxe.Timer.stamp();
        final opened = BundledEmojiFont.openFile(fontPath());
        bundled.addBundledEmojiFace(opened);
        final open = haxe.Timer.stamp() - start;
        final bundledFirst = firstEmoji(bundled);
        var message = 'Time to first emoji: bundled font ${ms(open)} ms to open + ${ms(bundledFirst)} ms to lay out and rasterize';
        // Browsers: the whole file (read here from disk, downloaded there), then parsed
        final readStart = haxe.Timer.stamp();
        final bytes = ceramic.Files.getBytes(fontPath());
        final read = haxe.Timer.stamp() - readStart;
        final whole = new CeramicTextSystem('Inter');
        whole.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        final parseStart = haxe.Timer.stamp();
        whole.addBundledEmojiFace(BundledEmojiFont.openBytes(bytes));
        final parse = haxe.Timer.stamp() - parseStart;
        message += '; whole file ${ms(read)} ms to read + ${ms(parse)} ms to parse + ${ms(firstEmoji(whole))} ms to the first tile';
        final apple = '/System/Library/Fonts/Apple Color Emoji.ttc';
        if (ceramic.Files.exists(apple)) {
            final system = new CeramicTextSystem('Inter');
            system.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
            system.systemFallback = new SystemFontFallback({han: [], kana: [], hangul: [], other: [], emoji: [apple]});
            message += '; system font (Apple Color Emoji) ${ms(firstEmoji(system))} ms including its loading';
        }
        trace(message);
    }

    static function ms(seconds:Float):Float {
        return Math.round(seconds * 10000) / 10;
    }

    function testWithoutTheBundledFontEmojiStayMissing() {
        final p = new CeramicTextSystem('Inter');
        p.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        final line = layout(p, 'a 😀');
        assertEquals(0, (glyphAt(line, 2).glyph.id:Int));
        assertNull(p.bundledEmojiFace);
    }

    function testTheCanvasOnlyDrawsWhatTheBundledFontLacks() {
        final p = platform();
        final canvas = new FakeCanvas();
        p.canvasFontFallback = EmojiAndCjk;
        p.canvasText = canvas;
        final line = layout(p, 'a中😀👨‍👩‍👧b');
        // 中 goes to the canvas (CJK policy), the emoji stay on the bundled font
        final cjk = glyphAt(line, 1);
        assertTrue(CanvasFallbackText.isCanvasFontId(cjk.fontId));
        assertFalse(cjk.glyph.isEmoji);
        assertBundledEmoji(p, line, 4);
        assertBundledEmoji(p, line, 8, false);
        assertEquals(['normal 400 16px "Inter", sans-serif'].join('|'), canvas.fonts.join('|'));
        // With the Emoji policy, nothing goes to the canvas
        final q = platform();
        q.canvasFontFallback = Emoji;
        q.canvasText = new FakeCanvas();
        for (run in layout(q, 'a中😀👨‍👩‍👧b').runs)
            assertFalse(CanvasFallbackText.isCanvasFontId(run.fontId));
    }

    function testVariationSelectorAndSpaceGlyphs() {
        final p = platform();
        // Noto Color Emoji's glyph 3 is its space: GPUI drops it ("HACK:
        // Prevent crash caused by variation selectors"); emoji followed by
        // a redundant variation selector stay one glyph
        final line = layout(p, '😀\u{FE0F}x');
        assertEquals(1, clusterSize(line, 0));
        for (run in line.runs)
            if (p.ttfFont(run.fontId).postScriptName == 'NotoColorEmoji')
                for (g in run.glyphs)
                    assertTrue((g.id:Int) != 3);
    }

    function testDefaultTextSystemWithTheDefine() {
        final ts:CeramicTextSystem = cast glaze.App.defaultTextSystem().platformTextSystem;
        #if glaze_bundled_emoji
        assertTrue(BundledEmojiFont.enabled());
        // Added by the plugin once the default assets are loaded, from the shipped asset
        assertNotNull(ts.bundledEmojiFace);
        if (ts.bundledEmojiFace == null)
            return;
        assertEquals('NotoColorEmoji', ts.bundledEmojiFace.postScriptName);
        final fontId = ts.fontId(Font.of('Inter'));
        final line = ts.layoutLine('a 🚀', 16, [new FontRun(Utf8.byteLength('a 🚀'), fontId)]);
        assertBundledEmoji(ts, line, 2);
        #else
        assertFalse(BundledEmojiFont.enabled());
        assertNull(ts.bundledEmojiFace);
        #end
    }

    static inline function fontPath():String {
        return pluginFontPath();
    }

    static inline function ttfTestFont(name:String):String {
        return ttfTestFontsDir() + '/' + name;
    }

    #end

    /** Absolute path of the plugin's bundled emoji font file */
    static macro function pluginFontPath():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.fullPath(file));
        return macro $v{haxe.io.Path.normalize(dir + '/../../../../resources/emoji-font/assets/glaze/emoji/NotoColorEmoji.ttf.bin')};
    }

    /** Absolute path of the ttf library's test fonts */
    static macro function ttfTestFontsDir():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.fullPath(file));
        return macro $v{haxe.io.Path.normalize(dir + '/../../../../../../git/ttf/test/fonts')};
    }
}

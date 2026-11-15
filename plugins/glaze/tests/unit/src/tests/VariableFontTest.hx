package tests;

import glaze.Font;
import glaze.FontRun;
import glaze.FontStyle;
import glaze.RenderGlyphParams;
import glaze.platform.CeramicTextSystem;
import glaze.platform.SystemFontFamilies;

// Original code for Glaze (not a port): weights, optical sizes and tracking
// of variable fonts through instances (ttf.Font.instance), and the names of
// the variable system fonts of macOS.
//
// The instances themselves are checked against fontTools by the tests of
// the ttf library: here, the text system must use the right instance for
// each font id and font size.

class VariableFontTest extends testing.TestCase {

    static function newTextSystem(families:Null<SystemFontFamilies>, withVariable:Bool = true):glaze.TextSystem {
        final platform = new CeramicTextSystem('Inter');
        platform.systemFamilies = families;
        final ts = new glaze.TextSystem(platform);
        final fonts = [TextFixtures.interBytes(), TextFixtures.monoBytes()];
        if (withVariable)
            fonts.push(TextFixtures.variableBytes());
        ts.addFonts(fonts);
        return ts;
    }

    static inline function platformOf(ts:glaze.TextSystem):CeramicTextSystem {
        return cast ts.platformTextSystem;
    }

    static function width(ts:glaze.TextSystem, text:String, size:Float, fontId:glaze.FontId):Float {
        return platformOf(ts).layoutLine(text, size, [new FontRun(text.length, fontId)]).width;
    }

    function testWeightsOfAVariableFontAreInstances() {
        final ts = newTextSystem(null);
        final platform = platformOf(ts);
        final regular = ts.resolveFont(Font.of('VarTest'));
        final base = platform.ttfFont(regular);
        assertEquals('VarTest', base.familyName);
        assertTrue(base.isVariable);
        assertFalse(base.isInstance);

        final ids:Array<Int> = [regular];
        var previousWidth = width(ts, 'AAAA', 20, regular);
        for (weight in [500.0, 600.0, 700.0, 900.0]) {
            final font = Font.of('VarTest');
            font.weight = weight;
            final id = ts.resolveFont(font);
            // one font id per weight: the glyph atlas and the layout caches key on it
            assertEquals(-1, ids.indexOf(id));
            ids.push(id);
            final again = Font.of('VarTest');
            again.weight = weight;
            assertEquals((id:Int), (platform.fontId(again):Int));
            final face = platform.ttfFont(id);
            assertTrue(face.isInstance);
            assertTrue(face.baseFont == base);
            assertTrue(face == base.instanceForWeight(weight));
            // the advance of 'A' grows with the weight in this font
            assertEquals(face.advance(face.glyphForChar('A'.code)) * 1.0, platform.advance(id, face.glyphForChar('A'.code)).width);
            final w = width(ts, 'AAAA', 20, id);
            assertTrue(w > previousWidth);
            assertFloatEquals(4 * face.advance(face.glyphForChar('A'.code)) * 20 / 1000, w, 0.001);
            previousWidth = w;
        }
        // The named instances of the font give its weights: Medium is wght 520
        final medium = platform.ttfFont(ids[1]);
        assertFloatEquals(520, medium.variationCoords()[medium.axisIndex('wght')], 1e-9);
        // weight 400 is the default instance: the font itself
        final normal = Font.of('VarTest');
        normal.weight = 400;
        assertEquals((regular:Int), (ts.resolveFont(normal):Int));
    }

    function testVariableGlyphsAreRasterizedFromTheInstance() {
        final ts = newTextSystem(null);
        final platform = platformOf(ts);
        final regular = ts.resolveFont(Font.of('VarTest'));
        final boldFont = Font.of('VarTest');
        boldFont.weight = 700;
        final bold = ts.resolveFont(boldFont);
        final face = platform.ttfFont(bold);
        final glyph = face.glyphForChar('A'.code);
        final rasterizer = new ttf.GlyphRasterizer();
        final expected = rasterizer.rasterize(face, glyph, 64, 0, 0);
        final params = new RenderGlyphParams(bold, glyph, 32, 0, 0, 2, false);
        final bounds = platform.glyphRasterBounds(params);
        assertEquals(expected.width * 1.0, bounds.size.width);
        assertEquals(expected.height * 1.0, bounds.size.height);
        assertEquals(expected.left * 1.0, bounds.origin.x);
        final bytes = platform.rasterizeGlyph(params, bounds);
        var same = bytes.length == expected.width * expected.height;
        if (same)
            for (i in 0...bytes.length)
                if (bytes.get(i) != expected.data.get(i))
                    same = false;
        assertTrue(same);
        // and it is not the regular glyph: the bold 'A' of this font is wider
        final regularBounds = platform.glyphRasterBounds(new RenderGlyphParams(regular, glyph, 32, 0, 0, 2, false));
        assertTrue(bounds.size.width > regularBounds.size.width);
    }

    function testVariableFontsCanBeTurnedOff() {
        final ts = newTextSystem(null);
        final platform = platformOf(ts);
        platform.variableFonts = false;
        final regular = platform.fontId(Font.of('VarTest'));
        final boldFont = Font.of('VarTest');
        boldFont.weight = 700;
        assertEquals((regular:Int), (platform.fontId(boldFont):Int));
        assertFalse(platform.ttfFont(regular).isInstance);
    }

    function testStaticFontsAreNotConcerned() {
        final ts = newTextSystem(null);
        final platform = platformOf(ts);
        final regular = ts.resolveFont(Font.of('Inter'));
        final bold = ts.resolveFont(Font.of('Inter').bold());
        // one static face: every weight is that face, as before
        assertEquals((regular:Int), (bold:Int));
        final face = platform.ttfFont(regular);
        assertFalse(face.isVariable);
        assertFalse(face.isInstance);
        final reference = newTextSystem(null, false);
        final referenceId = reference.resolveFont(Font.of('Inter'));
        final text = 'The quick brown fox, AVATAR To';
        assertEquals(width(reference, text, 13, referenceId), width(ts, text, 13, regular));
        final mono = ts.resolveFont(Font.of('JetBrains Mono'));
        assertEquals(width(reference, text, 13, reference.resolveFont(Font.of('JetBrains Mono'))), width(ts, text, 13, mono));
    }

    function testSystemFontNamesWithoutSystemFamilies() {
        // no system families (web, golden, these tests): the names keep their substitutes
        final ts = newTextSystem(null);
        final platform = platformOf(ts);
        for (name in ['system-ui', 'SF Pro', 'SF Pro Text', '.AppleSystemUIFont']) {
            assertFalse(ts.isFamilyAvailable(name));
            assertEquals('Inter', platform.ttfFont(ts.resolveFont(Font.of(name))).familyName);
        }
        assertFalse(ts.isFamilyAvailable('ui-monospace'));
        assertFalse(ts.isFamilyAvailable('-apple-system'));
        assertEquals('JetBrains Mono', platform.ttfFont(ts.resolveFont(Font.of('SF Mono'))).familyName);
    }

    #if sys
    static function hasMacSystemFont():Bool {
        return SystemFontFamilies.platformDirectories().length > 0 && sys.FileSystem.exists('/System/Library/Fonts/SFNS.ttf')
            && sys.FileSystem.exists('/System/Library/Fonts/SFNSMono.ttf');
    }

    function testMacSystemFontNames() {
        if (!hasMacSystemFont()) {
            trace('no macOS system font: skipped');
            return;
        }
        final families = new SystemFontFamilies();
        final ts = newTextSystem(families);
        final platform = platformOf(ts);
        for (name in ['system-ui', '-apple-system', 'BlinkMacSystemFont', '.AppleSystemUIFont', 'System-UI']) {
            assertEquals('System Font', families.aliasFamily(name));
            assertTrue(ts.isFamilyAvailable(name));
            final face = platform.ttfFont(ts.resolveFont(Font.of(name)));
            assertEquals('System Font', face.familyName);
            assertTrue(face.baseFont.isVariable);
        }
        assertEquals('.SF NS Mono', families.aliasFamily('ui-monospace'));
        assertTrue(ts.isFamilyAvailable('ui-monospace'));
        final mono = platform.ttfFont(ts.resolveFont(Font.of('ui-monospace')));
        assertEquals('.SF NS Mono', mono.familyName);
        // every alias is the same face
        assertTrue(platform.ttfFont(ts.resolveFont(Font.of('system-ui'))) == platform.ttfFont(ts.resolveFont(Font.of('-apple-system'))));

        // the existing mappings stay: `.SystemUIFont` is the configured font,
        // the hidden names are not families, the names of fonts that are not
        // installed keep their substitutes (a browser goes on to the next
        // family of its list)
        assertEquals('Inter', platform.ttfFont(ts.resolveFont(Font.of('.SystemUIFont'))).familyName);
        assertFalse(newTextSystem(new SystemFontFamilies()).isFamilyAvailable('.SF NS Mono'));
        assertEquals(null, families.aliasFamily('Menlo'));
        assertEquals(null, families.aliasFamily('monospace'));
        assertEquals('Menlo', platform.ttfFont(ts.resolveFont(Font.of('Menlo'))).familyName);
        if (!families.hasFamily('SF Pro')) {
            assertEquals(null, families.aliasFamily('SF Pro'));
            assertFalse(ts.isFamilyAvailable('SF Pro'));
            assertEquals('Inter', platform.ttfFont(ts.resolveFont(Font.of('SF Pro'))).familyName);
        }
        if (!families.hasFamily('SF Mono')) {
            assertEquals(null, families.aliasFamily('SF Mono'));
            assertFalse(ts.isFamilyAvailable('SF Mono'));
        }
    }

    function testMacAppleFamilyAliasesAreOptIn() {
        if (!hasMacSystemFont()) {
            trace('no macOS system font: skipped');
            return;
        }
        final families = new SystemFontFamilies();
        families.appleFamilyAliases = true;
        final ts = newTextSystem(families);
        final platform = platformOf(ts);
        if (!families.hasFamily('SF Pro')) {
            assertTrue(ts.isFamilyAvailable('SF Pro'));
            assertEquals('System Font', platform.ttfFont(ts.resolveFont(Font.of('SF Pro'))).familyName);
            assertEquals('System Font', platform.ttfFont(ts.resolveFont(Font.of('SF Pro Text'))).familyName);
        }
        if (!families.hasFamily('SF Mono')) {
            assertTrue(ts.isFamilyAvailable('SF Mono'));
            assertEquals('.SF NS Mono', platform.ttfFont(ts.resolveFont(Font.of('SF Mono'))).familyName);
        }
    }

    function testMacSystemFontWeightsItalicAndMono() {
        if (!hasMacSystemFont()) {
            trace('no macOS system font: skipped');
            return;
        }
        final ts = newTextSystem(new SystemFontFamilies());
        final platform = platformOf(ts);
        final text = 'The quick brown fox';
        // the weights are the named instances of the font, like CoreText's
        final expectedWght = [400 => 400.0, 500 => 510.0, 600 => 590.0, 700 => 700.0, 800 => 860.0];
        final ids:Array<Int> = [];
        var previous = 0.0;
        for (weight in [400, 500, 600, 700, 800]) {
            final font = Font.of('system-ui');
            font.weight = weight;
            final id = ts.resolveFont(font);
            assertEquals(-1, ids.indexOf(id));
            ids.push(id);
            final face = platform.ttfFont(id);
            assertFalse(face.italic);
            assertFloatEquals(expectedWght.get(weight), face.variationCoords()[face.axisIndex('wght')], 0.001);
            // heavier text is wider
            final w = width(ts, text, 13, id);
            assertTrue(w > previous);
            previous = w;
        }
        // italic: the italic file of the family, at the weight asked for
        final italicFont = Font.of('system-ui').italic();
        italicFont.weight = 600;
        final italic = platform.ttfFont(ts.resolveFont(italicFont));
        assertTrue(italic.italic);
        assertTrue(italic.isInstance);
        assertTrue(italic.baseFont.postScriptName.indexOf('Italic') != -1);
        assertFloatEquals(590.8, italic.variationCoords()[italic.axisIndex('wght')], 0.001);

        // SF Mono: the Regular instance (the default of the file is Light), a fixed advance at every weight
        final mono = platform.ttfFont(ts.resolveFont(Font.of('ui-monospace')));
        assertTrue(mono.isInstance);
        assertFloatEquals(400, mono.variationCoords()[mono.axisIndex('wght')], 0.001);
        final monoBold = Font.of('ui-monospace').bold();
        final monoBoldId = ts.resolveFont(monoBold);
        assertTrue(platform.ttfFont(monoBoldId) != mono);
        assertFloatEquals(width(ts, 'iiii', 13, ts.resolveFont(Font.of('ui-monospace'))), width(ts, 'MMMM', 13, monoBoldId), 0.001);
        final monoItalic = platform.ttfFont(ts.resolveFont(Font.of('ui-monospace').italic()));
        assertTrue(monoItalic.baseFont.postScriptName.indexOf('Italic') != -1);
    }

    function testMacSystemFontOpticalSizeAndTracking() {
        if (!hasMacSystemFont()) {
            trace('no macOS system font: skipped');
            return;
        }
        final ts = newTextSystem(new SystemFontFamilies());
        final platform = platformOf(ts);
        final id = ts.resolveFont(Font.of('system-ui'));
        final base = platform.ttfFont(id);
        assertFalse(base.isInstance);
        final n = base.glyphForChar('n'.code);
        final text = 'nnnnnnnn';

        // without tracking: the advances of the optical size of the font size
        platform.variableFontTracking = false;
        final small = base.instance(['opsz' => 13]);
        assertTrue(small.isInstance);
        assertTrue(small.advance(n) > base.advance(n));
        assertFloatEquals(8 * small.advance(n) * 13 / 2048, width(ts, text, 13, id), 0.001);
        // 28 is the default optical size of the font: the font itself
        assertFloatEquals(8 * base.advance(n) * 28 / 2048, width(ts, text, 28, id), 0.001);
        final large = base.instance(['opsz' => 40]);
        assertFloatEquals(8 * large.advance(n) * 40 / 2048, width(ts, text, 40, id), 0.001);

        // glyphs are rasterized from the same instance
        final rasterizer = new ttf.GlyphRasterizer();
        final expected = rasterizer.rasterBounds(small, n, 26, 0, 0);
        final bounds = platform.glyphRasterBounds(new RenderGlyphParams(id, n, 13, 0, 0, 2, false));
        assertEquals(expected.width * 1.0, bounds.size.width);
        assertEquals(expected.height * 1.0, bounds.size.height);

        // with tracking (the default): the `trak` value of the size on every glyph
        platform.variableFontTracking = true;
        assertFloatEquals(-12, base.tracking(13), 1e-9);
        assertFloatEquals(8 * (small.advance(n) - 12) * 13 / 2048, width(ts, text, 13, id), 0.001);
        assertFloatEquals(8 * (base.advance(n) + 28) * 28 / 2048, width(ts, text, 28, id), 0.001);
        // between two sizes of the table: interpolated, then truncated toward
        // zero to a whole font unit, as CoreText does: -49 at 16.8 px (-49.6
        // interpolated), -26 at 14.45 px (-26.5), +6 at 11.45 px (6.6)
        assertFloatEquals(-49.6, base.tracking(16.8), 1e-6);
        assertFloatEquals(8 * (small.advance(n) - 49) * 16.8 / 2048, width(ts, text, 16.8, id), 0.001);
        assertFloatEquals(8 * (small.advance(n) - 26) * 14.45 / 2048, width(ts, text, 14.45, id), 0.001);
        assertFloatEquals(8 * (small.advance(n) + 6) * 11.45 / 2048, width(ts, text, 11.45, id), 0.001);

        // as a fallback of another font (the Apple logo, U+F8FF, is in no bundled
        // font), the system font is measured and rasterized at the same optical size
        final logo = base.glyphForChar(0xF8FF);
        if (logo != 0) {
            final inter = ts.resolveFont(Font.of('Inter'));
            final logos = String.fromCharCode(0xF8FF) + String.fromCharCode(0xF8FF);
            final layout = platform.layoutLine(logos, 13, [new FontRun(glaze.util.Utf8.byteLength(logos), inter)]);
            assertFloatEquals(2 * (small.advance(logo) - 12) * 13 / 2048, layout.width, 0.001);
            assertEquals(1, layout.runs.length);
            final fallbackId = layout.runs[0].fontId;
            assertEquals('System Font', platform.ttfFont(fallbackId).familyName);
            final logoBounds = platform.glyphRasterBounds(new RenderGlyphParams(fallbackId, logo, 13, 0, 0, 2, false));
            final logoExpected = rasterizer.rasterBounds(small, logo, 26, 0, 0);
            assertEquals(logoExpected.width * 1.0, logoBounds.size.width);
            assertEquals(logoExpected.height * 1.0, logoBounds.size.height);
        }

        // used by the system fallback only (the family was never asked for by
        // name), the system font keeps its default instance, as before: no
        // optical size, no tracking
        final fallbackOnly = new CeramicTextSystem('Inter');
        fallbackOnly.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        fallbackOnly.systemFallback = new glaze.platform.SystemFontFallback();
        final inter = fallbackOnly.fontId(Font.of('Inter'));
        var checked = 0;
        for (c in [0x2603, 0x265E, 0x2654, 0x2318, 0x21E7, 0xF8FF]) {
            final symbols = String.fromCharCode(c) + String.fromCharCode(c);
            final symbolLayout = fallbackOnly.layoutLine(symbols, 13, [new FontRun(glaze.util.Utf8.byteLength(symbols), inter)]);
            if (symbolLayout.runs.length != 1)
                continue;
            final symbolFace = fallbackOnly.ttfFont(symbolLayout.runs[0].fontId);
            if (!symbolFace.isVariable || symbolFace.axisIndex('opsz') < 0)
                continue;
            checked++;
            assertFalse(symbolFace.isInstance);
            final symbolGlyph = symbolFace.glyphForChar(c);
            assertFloatEquals(2 * symbolFace.advance(symbolGlyph) * 13 / symbolFace.unitsPerEm, symbolLayout.width, 0.001);
            final symbolBounds = fallbackOnly.glyphRasterBounds(new RenderGlyphParams(symbolLayout.runs[0].fontId, symbolGlyph, 13, 0, 0, 2, false));
            final symbolExpected = rasterizer.rasterBounds(symbolFace, symbolGlyph, 26, 0, 0);
            assertEquals(symbolExpected.width * 1.0, symbolBounds.size.width);
            assertEquals(symbolExpected.height * 1.0, symbolBounds.size.height);
        }
        // at least one of these symbols comes from the variable system font
        assertTrue(checked > 0);

        // variable fonts off: the default instance at every weight and size
        final off = newTextSystem(new SystemFontFamilies());
        final offPlatform = platformOf(off);
        offPlatform.variableFonts = false;
        final offId = off.resolveFont(Font.of('system-ui'));
        assertEquals((offId:Int), (off.resolveFont(Font.of('system-ui').bold()):Int));
        assertFloatEquals(8 * base.advance(n) * 13 / 2048, width(off, text, 13, offId), 0.001);
    }
    #end

}

package tests;

import glaze.Font;
import glaze.FontStyle;
import glaze.platform.CeramicTextSystem;
import glaze.platform.SystemFontFamilies;

// Original code for Glaze (not a port): installed font families loaded by name.

class SystemFontFamiliesTest extends testing.TestCase {

    static function newTextSystem(families:Null<SystemFontFamilies>):glaze.TextSystem {
        final platform = new CeramicTextSystem('Inter');
        platform.systemFamilies = families;
        final ts = new glaze.TextSystem(platform);
        ts.addFonts([TextFixtures.interBytes(), TextFixtures.monoBytes()]);
        return ts;
    }

    static function familyOf(ts:glaze.TextSystem, font:Font):String {
        final platform:CeramicTextSystem = cast ts.platformTextSystem;
        return platform.ttfFont(ts.resolveFont(font)).familyName;
    }

    function testWithoutSystemFamiliesWellKnownNamesAreSubstituted() {
        final ts = newTextSystem(null);
        assertEquals('JetBrains Mono', familyOf(ts, Font.of('Menlo')));
        assertFalse(ts.isFamilyAvailable('Menlo'));
        assertTrue(ts.isFamilyAvailable('JetBrains Mono'));
        assertTrue(ts.isFamilyAvailable('.SystemUIFont'));
    }

    function testUnknownFamilyWithFamilies() {
        // a directory without fonts: nothing found, substitutes as before
        final ts = newTextSystem(new SystemFontFamilies(['/nonexistent-glaze-font-dir']));
        assertFalse(ts.isFamilyAvailable('Menlo'));
        assertEquals('JetBrains Mono', familyOf(ts, Font.of('Menlo')));
    }

    #if sys
    function testMacSystemFamilies() {
        if (SystemFontFamilies.platformDirectories().length == 0 || !sys.FileSystem.exists('/System/Library/Fonts/Menlo.ttc')) {
            trace('not macOS: skipped');
            return;
        }
        final families = new SystemFontFamilies();
        assertTrue(families.hasFamily('Menlo'));
        assertTrue(families.hasFamily('menlo'));
        assertFalse(families.hasFamily('No Such Family Glaze'));
        final ts = newTextSystem(families);
        // SF Mono is only in Terminal.app and as the hidden `.SF NS Mono`:
        // like Chromium, a page asking for it gets the next family of its
        // list unless the user installed it (loreline-monaco's recordings
        // measure Menlo's advance, 10.234375 at 17 px)
        if (!families.hasFamily('SF Mono')) {
            assertFalse(ts.isFamilyAvailable('SF Mono'));
            assertFalse(ts.isFamilyAvailable('.SF NS Mono'));
        }
        assertTrue(ts.isFamilyAvailable('Menlo'));
        assertEquals('Menlo', familyOf(ts, Font.of('Menlo')));
        final menlo = ts.resolveFont(Font.of('Menlo'));
        assertFloatEquals(10.234375, ts.advance(menlo, 17, 'm'.code).width, 0.001);
        // all the faces of the family: Menlo Bold and Italic
        final platform:CeramicTextSystem = cast ts.platformTextSystem;
        final bold = platform.ttfFont(ts.resolveFont(Font.of('Menlo').bold()));
        assertTrue(bold.weight >= 700);
        final italic = platform.ttfFont(ts.resolveFont(Font.of('Menlo').italic()));
        assertTrue(italic.italic);
        // the added fonts keep their own name
        assertEquals('JetBrains Mono', familyOf(ts, Font.of('JetBrains Mono')));
        // unknown names still fall back on the substitutes
        assertEquals('JetBrains Mono', familyOf(ts, Font.of('Consolas')));
        trace('system font index: ' + Math.round(families.indexTime * 1000) + ' ms');
    }
    #end

}

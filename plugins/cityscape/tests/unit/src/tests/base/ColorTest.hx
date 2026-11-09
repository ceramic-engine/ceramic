// Ported from vscode src/vs/base/test/common/color.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.base;

import cityscape.base.common.Color;
import haxe.PosInfos;
import testing.TestCase;

/**
 * suite('Color')
 *
 * `assert.deepStrictEqual` on `RGBA`, `HSLA`, `HSVA` and `Color` instances
 * compares their fields (helpers below); on `Color`, the `rgba` and the
 * cached `hsla` / `hsva` (all built from `RGBA` in these tests).
 */
class ColorTest extends TestCase {

    function assertRGBA(expected:RGBA, actual:RGBA, ?pos:PosInfos) {
        assertTrue(RGBA.equalsStatic(expected, actual), 'expected rgba(${expected.r}, ${expected.g}, ${expected.b}, ${expected.a}) but got rgba(${actual.r}, ${actual.g}, ${actual.b}, ${actual.a})', pos);
    }

    function assertHSLA(expected:HSLA, actual:HSLA, ?pos:PosInfos) {
        assertTrue(HSLA.equalsStatic(expected, actual), 'expected hsla(${expected.h}, ${expected.s}, ${expected.l}, ${expected.a}) but got hsla(${actual.h}, ${actual.s}, ${actual.l}, ${actual.a})', pos);
    }

    function assertHSVA(expected:HSVA, actual:HSVA, ?pos:PosInfos) {
        assertTrue(HSVA.equalsStatic(expected, actual), 'expected hsva(${expected.h}, ${expected.s}, ${expected.v}, ${expected.a}) but got hsva(${actual.h}, ${actual.s}, ${actual.v}, ${actual.a})', pos);
    }

    function assertColor(expected:Color, actual:Color, ?pos:PosInfos) {
        final sameCache = @:privateAccess ((expected._hsla == null) == (actual._hsla == null) && (expected._hsva == null) == (actual._hsva == null));
        assertTrue(sameCache, 'different cached values', pos);
        assertRGBA(expected.rgba, actual.rgba, pos);
    }

    function testIsLighterColor() {
        final color1 = new Color(new HSLA(60, 1, 0.5, 1)), color2 = new Color(new HSLA(0, 0, 0.753, 1));

        assertTrue(color1.isLighterThan(color2));

        // Abyss theme
        assertTrue(Color.fromHex('#770811').isLighterThan(Color.fromHex('#000c18')));
    }

    function testGetLighterColor() {
        final color1 = new Color(new HSLA(60, 1, 0.5, 1)), color2 = new Color(new HSLA(0, 0, 0.753, 1));

        assertHSLA(color1.hsla, Color.getLighterColor(color1, color2).hsla);
        assertHSLA(new HSLA(0, 0, 0.916, 1), Color.getLighterColor(color2, color1).hsla);
        assertHSLA(new HSLA(0, 0, 0.851, 1), Color.getLighterColor(color2, color1, 0.3).hsla);
        assertHSLA(new HSLA(0, 0, 0.981, 1), Color.getLighterColor(color2, color1, 0.7).hsla);
        assertHSLA(new HSLA(0, 0, 1, 1), Color.getLighterColor(color2, color1, 1).hsla);
    }

    function testIsDarkerColor() {
        final color1 = new Color(new HSLA(60, 1, 0.5, 1)), color2 = new Color(new HSLA(0, 0, 0.753, 1));

        assertTrue(color2.isDarkerThan(color1));
    }

    function testGetDarkerColor() {
        final color1 = new Color(new HSLA(60, 1, 0.5, 1)), color2 = new Color(new HSLA(0, 0, 0.753, 1));

        assertHSLA(color2.hsla, Color.getDarkerColor(color2, color1).hsla);
        assertHSLA(new HSLA(60, 1, 0.392, 1), Color.getDarkerColor(color1, color2).hsla);
        assertHSLA(new HSLA(60, 1, 0.435, 1), Color.getDarkerColor(color1, color2, 0.3).hsla);
        assertHSLA(new HSLA(60, 1, 0.349, 1), Color.getDarkerColor(color1, color2, 0.7).hsla);
        assertHSLA(new HSLA(60, 1, 0.284, 1), Color.getDarkerColor(color1, color2, 1).hsla);

        // Abyss theme
        assertHSLA(new HSLA(355, 0.874, 0.157, 1), Color.getDarkerColor(Color.fromHex('#770811'), Color.fromHex('#000c18'), 0.4).hsla);
    }

    function testLuminance() {
        assertEquals(0.0, new Color(new RGBA(0, 0, 0, 1)).getRelativeLuminance());
        assertEquals(1.0, new Color(new RGBA(255, 255, 255, 1)).getRelativeLuminance());

        assertEquals(0.2126, new Color(new RGBA(255, 0, 0, 1)).getRelativeLuminance());
        assertEquals(0.7152, new Color(new RGBA(0, 255, 0, 1)).getRelativeLuminance());
        assertEquals(0.0722, new Color(new RGBA(0, 0, 255, 1)).getRelativeLuminance());

        assertEquals(0.9278, new Color(new RGBA(255, 255, 0, 1)).getRelativeLuminance());
        assertEquals(0.7874, new Color(new RGBA(0, 255, 255, 1)).getRelativeLuminance());
        assertEquals(0.2848, new Color(new RGBA(255, 0, 255, 1)).getRelativeLuminance());

        assertEquals(0.5271, new Color(new RGBA(192, 192, 192, 1)).getRelativeLuminance());

        assertEquals(0.2159, new Color(new RGBA(128, 128, 128, 1)).getRelativeLuminance());
        assertEquals(0.0459, new Color(new RGBA(128, 0, 0, 1)).getRelativeLuminance());
        assertEquals(0.2003, new Color(new RGBA(128, 128, 0, 1)).getRelativeLuminance());
        assertEquals(0.1544, new Color(new RGBA(0, 128, 0, 1)).getRelativeLuminance());
        assertEquals(0.0615, new Color(new RGBA(128, 0, 128, 1)).getRelativeLuminance());
        assertEquals(0.17, new Color(new RGBA(0, 128, 128, 1)).getRelativeLuminance());
        assertEquals(0.0156, new Color(new RGBA(0, 0, 128, 1)).getRelativeLuminance());
    }

    function testBlending() {
        assertColor(new Color(new RGBA(0, 0, 0, 0)).blend(new Color(new RGBA(243, 34, 43))), new Color(new RGBA(243, 34, 43)));
        assertColor(new Color(new RGBA(255, 255, 255)).blend(new Color(new RGBA(243, 34, 43))), new Color(new RGBA(255, 255, 255)));
        assertColor(new Color(new RGBA(122, 122, 122, 0.7)).blend(new Color(new RGBA(243, 34, 43))), new Color(new RGBA(158, 95, 98)));
        assertColor(new Color(new RGBA(0, 0, 0, 0.58)).blend(new Color(new RGBA(255, 255, 255, 0.33))), new Color(new RGBA(49, 49, 49, 0.719)));
    }

    // suite('HSLA')

    function testHSLAToRGBA() {
        assertRGBA(HSLA.toRGBA(new HSLA(0, 0, 0, 0)), new RGBA(0, 0, 0, 0));
        assertRGBA(HSLA.toRGBA(new HSLA(0, 0, 0, 1)), new RGBA(0, 0, 0, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(0, 0, 1, 1)), new RGBA(255, 255, 255, 1));

        assertRGBA(HSLA.toRGBA(new HSLA(0, 1, 0.5, 1)), new RGBA(255, 0, 0, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(120, 1, 0.5, 1)), new RGBA(0, 255, 0, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(240, 1, 0.5, 1)), new RGBA(0, 0, 255, 1));

        assertRGBA(HSLA.toRGBA(new HSLA(60, 1, 0.5, 1)), new RGBA(255, 255, 0, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(180, 1, 0.5, 1)), new RGBA(0, 255, 255, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(300, 1, 0.5, 1)), new RGBA(255, 0, 255, 1));

        assertRGBA(HSLA.toRGBA(new HSLA(0, 0, 0.753, 1)), new RGBA(192, 192, 192, 1));

        assertRGBA(HSLA.toRGBA(new HSLA(0, 0, 0.502, 1)), new RGBA(128, 128, 128, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(0, 1, 0.251, 1)), new RGBA(128, 0, 0, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(60, 1, 0.251, 1)), new RGBA(128, 128, 0, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(120, 1, 0.251, 1)), new RGBA(0, 128, 0, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(300, 1, 0.251, 1)), new RGBA(128, 0, 128, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(180, 1, 0.251, 1)), new RGBA(0, 128, 128, 1));
        assertRGBA(HSLA.toRGBA(new HSLA(240, 1, 0.251, 1)), new RGBA(0, 0, 128, 1));
    }

    function testHSLAFromRGBA() {
        assertHSLA(HSLA.fromRGBA(new RGBA(0, 0, 0, 0)), new HSLA(0, 0, 0, 0));
        assertHSLA(HSLA.fromRGBA(new RGBA(0, 0, 0, 1)), new HSLA(0, 0, 0, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(255, 255, 255, 1)), new HSLA(0, 0, 1, 1));

        assertHSLA(HSLA.fromRGBA(new RGBA(255, 0, 0, 1)), new HSLA(0, 1, 0.5, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(0, 255, 0, 1)), new HSLA(120, 1, 0.5, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(0, 0, 255, 1)), new HSLA(240, 1, 0.5, 1));

        assertHSLA(HSLA.fromRGBA(new RGBA(255, 255, 0, 1)), new HSLA(60, 1, 0.5, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(0, 255, 255, 1)), new HSLA(180, 1, 0.5, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(255, 0, 255, 1)), new HSLA(300, 1, 0.5, 1));

        assertHSLA(HSLA.fromRGBA(new RGBA(192, 192, 192, 1)), new HSLA(0, 0, 0.753, 1));

        assertHSLA(HSLA.fromRGBA(new RGBA(128, 128, 128, 1)), new HSLA(0, 0, 0.502, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(128, 0, 0, 1)), new HSLA(0, 1, 0.251, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(128, 128, 0, 1)), new HSLA(60, 1, 0.251, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(0, 128, 0, 1)), new HSLA(120, 1, 0.251, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(128, 0, 128, 1)), new HSLA(300, 1, 0.251, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(0, 128, 128, 1)), new HSLA(180, 1, 0.251, 1));
        assertHSLA(HSLA.fromRGBA(new RGBA(0, 0, 128, 1)), new HSLA(240, 1, 0.251, 1));
    }

    // suite('HSVA')

    function testHSVAToRGBA() {
        assertRGBA(HSVA.toRGBA(new HSVA(0, 0, 0, 0)), new RGBA(0, 0, 0, 0));
        assertRGBA(HSVA.toRGBA(new HSVA(0, 0, 0, 1)), new RGBA(0, 0, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(0, 0, 1, 1)), new RGBA(255, 255, 255, 1));

        assertRGBA(HSVA.toRGBA(new HSVA(0, 1, 1, 1)), new RGBA(255, 0, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(120, 1, 1, 1)), new RGBA(0, 255, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(240, 1, 1, 1)), new RGBA(0, 0, 255, 1));

        assertRGBA(HSVA.toRGBA(new HSVA(60, 1, 1, 1)), new RGBA(255, 255, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(180, 1, 1, 1)), new RGBA(0, 255, 255, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(300, 1, 1, 1)), new RGBA(255, 0, 255, 1));

        assertRGBA(HSVA.toRGBA(new HSVA(0, 0, 0.753, 1)), new RGBA(192, 192, 192, 1));

        assertRGBA(HSVA.toRGBA(new HSVA(0, 0, 0.502, 1)), new RGBA(128, 128, 128, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(0, 1, 0.502, 1)), new RGBA(128, 0, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(60, 1, 0.502, 1)), new RGBA(128, 128, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(120, 1, 0.502, 1)), new RGBA(0, 128, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(300, 1, 0.502, 1)), new RGBA(128, 0, 128, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(180, 1, 0.502, 1)), new RGBA(0, 128, 128, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(240, 1, 0.502, 1)), new RGBA(0, 0, 128, 1));

        assertRGBA(HSVA.toRGBA(new HSVA(360, 0, 0, 0)), new RGBA(0, 0, 0, 0));
        assertRGBA(HSVA.toRGBA(new HSVA(360, 0, 0, 1)), new RGBA(0, 0, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(360, 0, 1, 1)), new RGBA(255, 255, 255, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(360, 1, 1, 1)), new RGBA(255, 0, 0, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(360, 0, 0.753, 1)), new RGBA(192, 192, 192, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(360, 0, 0.502, 1)), new RGBA(128, 128, 128, 1));
        assertRGBA(HSVA.toRGBA(new HSVA(360, 1, 0.502, 1)), new RGBA(128, 0, 0, 1));
    }

    function testHSVAFromRGBA() {
        assertHSVA(HSVA.fromRGBA(new RGBA(0, 0, 0, 0)), new HSVA(0, 0, 0, 0));
        assertHSVA(HSVA.fromRGBA(new RGBA(0, 0, 0, 1)), new HSVA(0, 0, 0, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(255, 255, 255, 1)), new HSVA(0, 0, 1, 1));

        assertHSVA(HSVA.fromRGBA(new RGBA(255, 0, 0, 1)), new HSVA(0, 1, 1, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(0, 255, 0, 1)), new HSVA(120, 1, 1, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(0, 0, 255, 1)), new HSVA(240, 1, 1, 1));

        assertHSVA(HSVA.fromRGBA(new RGBA(255, 255, 0, 1)), new HSVA(60, 1, 1, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(0, 255, 255, 1)), new HSVA(180, 1, 1, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(255, 0, 255, 1)), new HSVA(300, 1, 1, 1));

        assertHSVA(HSVA.fromRGBA(new RGBA(192, 192, 192, 1)), new HSVA(0, 0, 0.753, 1));

        assertHSVA(HSVA.fromRGBA(new RGBA(128, 128, 128, 1)), new HSVA(0, 0, 0.502, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(128, 0, 0, 1)), new HSVA(0, 1, 0.502, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(128, 128, 0, 1)), new HSVA(60, 1, 0.502, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(0, 128, 0, 1)), new HSVA(120, 1, 0.502, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(128, 0, 128, 1)), new HSVA(300, 1, 0.502, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(0, 128, 128, 1)), new HSVA(180, 1, 0.502, 1));
        assertHSVA(HSVA.fromRGBA(new RGBA(0, 0, 128, 1)), new HSVA(240, 1, 0.502, 1));
    }

    function testKeepHueValueWhenSaturationIs0() {
        assertRGBA(HSVA.toRGBA(new HSVA(10, 0, 0, 0)), HSVA.toRGBA(new HSVA(20, 0, 0, 0)));
        assertRGBA(new Color(new HSVA(10, 0, 0, 0)).rgba, new Color(new HSVA(20, 0, 0, 0)).rgba);
        assertFalse(HSVA.equalsStatic(new Color(new HSVA(10, 0, 0, 0)).hsva, new Color(new HSVA(20, 0, 0, 0)).hsva));
    }

    function testBug36240() {
        assertHSVA(HSVA.fromRGBA(new RGBA(92, 106, 196, 1)), new HSVA(232, 0.531, 0.769, 1));
        assertRGBA(HSVA.toRGBA(HSVA.fromRGBA(new RGBA(92, 106, 196, 1))), new RGBA(92, 106, 196, 1));
    }

    // suite('Format') suite('CSS')

    function testParseHex() {

        // invalid
        assertNull(ColorFormatCSS.parseHex(''));
        assertNull(ColorFormatCSS.parseHex('#'));
        assertNull(ColorFormatCSS.parseHex('#0102030'));

        // somewhat valid
        assertRGBA(ColorFormatCSS.parseHex('#FFFFG0').rgba, new RGBA(255, 255, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#FFFFg0').rgba, new RGBA(255, 255, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#-FFF00').rgba, new RGBA(15, 255, 0, 1));

        // valid
        assertRGBA(ColorFormatCSS.parseHex('#000000').rgba, new RGBA(0, 0, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#FFFFFF').rgba, new RGBA(255, 255, 255, 1));

        assertRGBA(ColorFormatCSS.parseHex('#FF0000').rgba, new RGBA(255, 0, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#00FF00').rgba, new RGBA(0, 255, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#0000FF').rgba, new RGBA(0, 0, 255, 1));

        assertRGBA(ColorFormatCSS.parseHex('#FFFF00').rgba, new RGBA(255, 255, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#00FFFF').rgba, new RGBA(0, 255, 255, 1));
        assertRGBA(ColorFormatCSS.parseHex('#FF00FF').rgba, new RGBA(255, 0, 255, 1));

        assertRGBA(ColorFormatCSS.parseHex('#C0C0C0').rgba, new RGBA(192, 192, 192, 1));

        assertRGBA(ColorFormatCSS.parseHex('#808080').rgba, new RGBA(128, 128, 128, 1));
        assertRGBA(ColorFormatCSS.parseHex('#800000').rgba, new RGBA(128, 0, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#808000').rgba, new RGBA(128, 128, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#008000').rgba, new RGBA(0, 128, 0, 1));
        assertRGBA(ColorFormatCSS.parseHex('#800080').rgba, new RGBA(128, 0, 128, 1));
        assertRGBA(ColorFormatCSS.parseHex('#008080').rgba, new RGBA(0, 128, 128, 1));
        assertRGBA(ColorFormatCSS.parseHex('#000080').rgba, new RGBA(0, 0, 128, 1));

        assertRGBA(ColorFormatCSS.parseHex('#010203').rgba, new RGBA(1, 2, 3, 1));
        assertRGBA(ColorFormatCSS.parseHex('#040506').rgba, new RGBA(4, 5, 6, 1));
        assertRGBA(ColorFormatCSS.parseHex('#070809').rgba, new RGBA(7, 8, 9, 1));
        assertRGBA(ColorFormatCSS.parseHex('#0a0A0a').rgba, new RGBA(10, 10, 10, 1));
        assertRGBA(ColorFormatCSS.parseHex('#0b0B0b').rgba, new RGBA(11, 11, 11, 1));
        assertRGBA(ColorFormatCSS.parseHex('#0c0C0c').rgba, new RGBA(12, 12, 12, 1));
        assertRGBA(ColorFormatCSS.parseHex('#0d0D0d').rgba, new RGBA(13, 13, 13, 1));
        assertRGBA(ColorFormatCSS.parseHex('#0e0E0e').rgba, new RGBA(14, 14, 14, 1));
        assertRGBA(ColorFormatCSS.parseHex('#0f0F0f').rgba, new RGBA(15, 15, 15, 1));
        assertRGBA(ColorFormatCSS.parseHex('#a0A0a0').rgba, new RGBA(160, 160, 160, 1));
        assertRGBA(ColorFormatCSS.parseHex('#CFA').rgba, new RGBA(204, 255, 170, 1));
        assertRGBA(ColorFormatCSS.parseHex('#CFA8').rgba, new RGBA(204, 255, 170, 0.533));
    }

}

package tests;

import testing.TestCase;

/**
 * Cityscape stores text as Haxe `String` and counts columns in UTF-16 code
 * units, like Monaco (see docs/PORTING.md). This checks that `length`,
 * `charCodeAt`, `substr` and `fromCharCode` work in UTF-16 units on every
 * target the tests run on.
 */
class HaxeStringTest extends TestCase {

    function testAsciiAndBmp() {
        assertEquals(1, 'a'.length);
        assertEquals(1, 'é'.length);
        assertEquals(0xe9, 'é'.charCodeAt(0));
        assertEquals(1, 'é'.length);
        assertEquals(0xe9, 'é'.charCodeAt(0));
        // CJK (BMP)
        assertEquals(2, '漢字'.length);
        assertEquals(0x6f22, '漢字'.charCodeAt(0));
        assertEquals(0x5b57, '漢字'.charCodeAt(1));
    }

    function testAstralIsTwoUnits() {
        final s = '😀';
        assertEquals(2, s.length);
        assertEquals(0xd83d, s.charCodeAt(0));
        assertEquals(0xde00, s.charCodeAt(1));
        assertEquals(null, s.charCodeAt(2));
    }

    function testMixed() {
        final s = 'a😀é';
        assertEquals(4, s.length);
        assertEquals(0x61, s.charCodeAt(0));
        assertEquals(0xd83d, s.charCodeAt(1));
        assertEquals(0xde00, s.charCodeAt(2));
        assertEquals(0xe9, s.charCodeAt(3));
        assertEquals('é', s.substr(3, 1));
        assertEquals('😀', s.substring(1, 3));
        assertEquals(3, s.indexOf('é'));
        // ZWJ sequence: man, ZWJ, woman, ZWJ, girl
        final family = '👨‍👩‍👧';
        assertEquals(8, family.length);
    }

    function testFromCharCode() {
        final s = String.fromCharCode(0x1f600);
        assertEquals(2, s.length);
        assertEquals('😀', s);
        final built = String.fromCharCode(0xd83d) + String.fromCharCode(0xde00);
        assertEquals('😀', built);
        assertEquals(2, built.length);
        final buf = new StringBuf();
        buf.addChar(0x61);
        buf.addChar(0x1f600);
        assertEquals('a😀', buf.toString());
        assertEquals(3, buf.toString().length);
    }

    function testLoneSurrogateSurvives() {
        // Monaco can split a string inside a surrogate pair (it never should
        // keep it, but intermediate values exist): check the halves round trip
        final s = '😀';
        final hi = s.substr(0, 1);
        final lo = s.substr(1, 1);
        assertEquals(1, hi.length);
        assertEquals(1, lo.length);
        assertEquals(0xd83d, hi.charCodeAt(0));
        assertEquals(0xde00, lo.charCodeAt(0));
        assertEquals(s, hi + lo);
    }

}

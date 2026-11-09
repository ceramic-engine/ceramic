// Ported from vscode src/vs/base/test/common/strings.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.base;

// Classes of this module:
// - StringsTest
//
// Ported: the tests of the functions of strings.ts that Cityscape has
// (graphemes, character classes, whitespace, BOM, count,
// htmlAttributeEncodeValue). Not ported: the tests of functions not ported
// (equalsIgnoreCase, beginsWithIgnoreCase, compareIgnoreCase, format,
// format2, lcut, escape, ltrim, rtrim, trim, trimWhitespace (tests
// JavaScript's String.trim), createRegExp (tests getNLines), fuzzyContains,
// containsUppercaseCharacter, uppercaseFirstLetter, getNLines, truncate,
// truncateMiddle, replaceAsync, removeAnsiEscapeCodes,
// removeAnsiEscapeCodesFromPrompt, containsAmbiguousCharacter,
// containsInvisibleCharacter).
//
// Cityscape additions (marked): Monaco's grapheme functions
// (`nextCharLength`, `prevCharLength`, `getCharContainingOffset`,
// `charCount`, `getLeftDeleteOffset`) have no test of their own in vscode
// (they are tested through the cursor); the expected values below follow
// strings.ts' rules (pairwise `breakBetweenGraphemeBreakType`, and
// `getLeftDeleteOffset`'s emoji heuristic).

import cityscape.base.common.Strings;
import testing.TestCase;

/**
 * suite('Strings')
 */
class StringsTest extends TestCase {

    function testLastNonWhitespaceIndex() {
        assertEquals(Strings.lastNonWhitespaceIndex('abc  \t \t '), 2);
        assertEquals(Strings.lastNonWhitespaceIndex('abc'), 2);
        assertEquals(Strings.lastNonWhitespaceIndex('abc\t'), 2);
        assertEquals(Strings.lastNonWhitespaceIndex('abc '), 2);
        assertEquals(Strings.lastNonWhitespaceIndex('abc  \t \t '), 2);
        assertEquals(Strings.lastNonWhitespaceIndex('abc  \t \t abc \t \t '), 11);
        assertEquals(Strings.lastNonWhitespaceIndex('abc  \t \t abc \t \t ', 8), 2);
        assertEquals(Strings.lastNonWhitespaceIndex('  \t \t '), -1);
    }

    function testContainsRTL() {
        assertEquals(Strings.containsRTL('a'), false);
        assertEquals(Strings.containsRTL(''), false);
        assertEquals(Strings.containsRTL(Strings.UTF8_BOM_CHARACTER + 'a'), false);
        assertEquals(Strings.containsRTL('hello world!'), false);
        assertEquals(Strings.containsRTL('a📚📚b'), false);
        assertEquals(Strings.containsRTL('هناك حقيقة مثبتة منذ زمن طويل'), true);
        assertEquals(Strings.containsRTL('זוהי עובדה מבוססת שדעתו'), true);
    }

    function testIssue115221IsEmojiImpreciseMisses() {
        // test('issue #115221: isEmojiImprecise misses ⭐')
        final codePoint = Strings.getNextCodePoint('⭐', '⭐'.length, 0);
        assertEquals(Strings.isEmojiImprecise(codePoint), true);
    }

    function testIsBasicASCII() {
        final assertIsBasicASCII = (str:String, expected:Bool) -> {
            assertEquals(Strings.isBasicASCII(str), expected, str + ' (${StringTools.fastCodeAt(str, 0)})');
        };
        assertIsBasicASCII('abcdefghijklmnopqrstuvwxyz', true);
        assertIsBasicASCII('ABCDEFGHIJKLMNOPQRSTUVWXYZ', true);
        assertIsBasicASCII('1234567890', true);
        assertIsBasicASCII('`~!@#$$%^&*()-_=+[{]}\\|;:\'",<.>/?', true);
        assertIsBasicASCII(' ', true);
        assertIsBasicASCII('\t', true);
        assertIsBasicASCII('\n', true);
        assertIsBasicASCII('\r', true);

        var ALL = '\r\t\n';
        for (i in 32...127) {
            ALL += String.fromCharCode(i);
        }
        assertIsBasicASCII(ALL, true);

        assertIsBasicASCII(String.fromCharCode(31), false);
        assertIsBasicASCII(String.fromCharCode(127), false);
        assertIsBasicASCII('ü', false);
        assertIsBasicASCII('a📚📚b', false);
    }

    function testGetLeadingWhitespace() {
        assertEquals(Strings.getLeadingWhitespace('  foo'), '  ');
        assertEquals(Strings.getLeadingWhitespace('  foo', 2), '');
        assertEquals(Strings.getLeadingWhitespace('  foo', 1, 1), '');
        assertEquals(Strings.getLeadingWhitespace('  foo', 0, 1), ' ');
        assertEquals(Strings.getLeadingWhitespace('  '), '  ');
        assertEquals(Strings.getLeadingWhitespace('  ', 1), ' ');
        assertEquals(Strings.getLeadingWhitespace('  ', 0, 1), ' ');
        assertEquals(Strings.getLeadingWhitespace('\t\tfunction foo(){', 0, 1), '\t');
        assertEquals(Strings.getLeadingWhitespace('\t\tfunction foo(){', 0, 2), '\t\t');
    }

    function testStartsWithUTF8BOM() {
        assertTrue(Strings.startsWithUTF8BOM(Strings.UTF8_BOM_CHARACTER));
        assertTrue(Strings.startsWithUTF8BOM(Strings.UTF8_BOM_CHARACTER + 'a'));
        assertTrue(Strings.startsWithUTF8BOM(Strings.UTF8_BOM_CHARACTER + 'aaaaaaaaaa'));
        assertTrue(!Strings.startsWithUTF8BOM(' ' + Strings.UTF8_BOM_CHARACTER));
        assertTrue(!Strings.startsWithUTF8BOM('foo'));
        assertTrue(!Strings.startsWithUTF8BOM(''));
    }

    function testStripUTF8BOM() {
        assertEquals(Strings.stripUTF8BOM(Strings.UTF8_BOM_CHARACTER), '');
        assertEquals(Strings.stripUTF8BOM(Strings.UTF8_BOM_CHARACTER + 'foobar'), 'foobar');
        assertEquals(Strings.stripUTF8BOM('foobar' + Strings.UTF8_BOM_CHARACTER), 'foobar' + Strings.UTF8_BOM_CHARACTER);
        assertEquals(Strings.stripUTF8BOM('abc'), 'abc');
        assertEquals(Strings.stripUTF8BOM(''), '');
    }

    function testGetGraphemeBreakType() {
        assertEquals(Strings.getGraphemeBreakType(0xBC1), GraphemeBreakType.SpacingMark);
    }

    function testCount() {
        assertEquals(Strings.count('hello world', 'o'), 2);
        assertEquals(Strings.count('hello world', 'l'), 3);
        assertEquals(Strings.count('hello world', 'z'), 0);
        assertEquals(Strings.count('hello world', 'hello'), 1);
        assertEquals(Strings.count('hello world', 'world'), 1);
        assertEquals(Strings.count('hello world', 'hello world'), 1);
        assertEquals(Strings.count('hello world', 'foo'), 0);
    }

    function testHtmlAttributeEncodeValue() {
        assertEquals(Strings.htmlAttributeEncodeValue(''), '');
        assertEquals(Strings.htmlAttributeEncodeValue('abc'), 'abc');
        assertEquals(Strings.htmlAttributeEncodeValue('<script>alert("Hello")</script>'), '&lt;script&gt;alert(&quot;Hello&quot;)&lt;/script&gt;');
        assertEquals(Strings.htmlAttributeEncodeValue('Hello & World'), 'Hello &amp; World');
        assertEquals(Strings.htmlAttributeEncodeValue('"Hello"'), '&quot;Hello&quot;');
        assertEquals(Strings.htmlAttributeEncodeValue('\'Hello\''), '&apos;Hello&apos;');
        assertEquals(Strings.htmlAttributeEncodeValue('<>&\'"'), '&lt;&gt;&amp;&apos;&quot;');
    }

    // Cityscape additions: the grapheme functions

    function testGraphemeLengths() {
        // ASCII
        assertEquals(Strings.nextCharLength('abc', 0), 1);
        assertEquals(Strings.prevCharLength('abc', 3), 1);
        // CR LF is one grapheme (GB3)
        assertEquals(Strings.nextCharLength('\r\nx', 0), 2);
        assertEquals(Strings.prevCharLength('x\r\n', 3), 2);
        // A surrogate pair
        assertEquals(Strings.nextCharLength('📚a', 0), 2);
        assertEquals(Strings.prevCharLength('a📚', 3), 2);
        // A combining mark extends the base (GB9)
        assertEquals(Strings.nextCharLength('éx', 0), 2);
        assertEquals(Strings.prevCharLength('xé', 3), 2);
        // An emoji ZWJ sequence (GB9 and GB11): 👨‍👩‍👧
        final family = '👨‍👩‍👧';
        assertEquals(family.length, 8);
        assertEquals(Strings.nextCharLength(family, 0), 8);
        assertEquals(Strings.prevCharLength(family, 8), 8);
        // A skin tone modifier is Extend
        assertEquals(Strings.nextCharLength('👍🏽', 0), 4);
        // Regional indicators never break between them (GB12 and GB13 without state): two flags are one cluster
        final flags = '🇫🇷🇩🇪';
        assertEquals(Strings.nextCharLength(flags, 0), 8);
        // Hangul syllable sequences (GB6 to GB8): L V T jamos
        assertEquals(Strings.nextCharLength('각', 0), 3);
        assertEquals(Strings.charCount('a📚é\r\n'), 4);
        assertDeepEquals([1, 3], Strings.getCharContainingOffset('a📚b', 2));
    }

    function testGetLeftDeleteOffset() {
        assertEquals(Strings.getLeftDeleteOffset(0, 'abc'), 0);
        assertEquals(Strings.getLeftDeleteOffset(3, 'abc'), 2);
        // One code point (a surrogate pair)
        assertEquals(Strings.getLeftDeleteOffset(3, 'a𐌀'), 1);
        // An emoji with a skin tone modifier is deleted at once
        assertEquals(Strings.getLeftDeleteOffset(5, 'a👍🏽'), 1);
        // A ZWJ sequence is deleted one emoji (and its joiner) at a time
        final family = '👨‍👩‍👧';
        assertEquals(Strings.getLeftDeleteOffset(8, family), 5);
        assertEquals(Strings.getLeftDeleteOffset(5, family), 2);
        assertEquals(Strings.getLeftDeleteOffset(2, family), 0);
        // A combining mark is deleted alone (not an emoji)
        assertEquals(Strings.getLeftDeleteOffset(2, 'é'), 1);
    }

}

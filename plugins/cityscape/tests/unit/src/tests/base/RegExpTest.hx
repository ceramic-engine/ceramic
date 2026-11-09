// New code for Cityscape (not a port): JavaScript semantics of
// `cityscape.base.common.RegExp` on every target.
package tests.base;

import cityscape.base.common.RegExp;
import testing.TestCase;

/**
 * The expected values are JavaScript's (`RegExp.prototype.exec`). On Node the
 * class is the native `RegExp`, so the Node run checks the expectations
 * themselves; the native run checks the translation to PCRE2. Most cases are
 * ones where PCRE2 alone (Unicode properties on) would answer differently.
 */
class RegExpTest extends TestCase {

    /**
     * `[index, match]` of each `exec` of a global copy of the regex, until
     * null.
     */
    static function all(source:String, flags:String, text:String):Array<Array<Any>> {
        final regex = new RegExp(source, flags.indexOf('g') == -1 ? flags + 'g' : flags);
        final result:Array<Array<Any>> = [];
        var guard = 0;
        while (guard++ < 100) {
            final m = regex.exec(text);
            if (m == null) {
                break;
            }
            result.push([m.index, m[0]]);
            if (m[0].length == 0) {
                regex.lastIndex++;
            }
        }
        return result;
    }

    function testWordAndDigitClassesAreAscii() {
        assertDeepEquals(all('\\w+', '', '\u{E9}t\u{E9} au'), [[1, 't'], [4, 'au']]);
        assertDeepEquals(all('\\d', '', '\u{663}3'), [[1, '3']]);
        assertDeepEquals(all('\\W', '', 'a\u{E9}'), [[1, '\u{E9}']]);
        assertDeepEquals(all('[\\w]+', 'u', '\u{E9}x_9'), [[1, 'x_9']]);
        assertDeepEquals(all('[^\\d]', '', '1a2'), [[1, 'a']]);
    }

    function testWordBoundaryIsAscii() {
        assertDeepEquals(all('\\bfoo\\b', '', '\u{E9}foo'), [[1, 'foo']]);
        assertDeepEquals(all('\\bfoo\\b', 'iu', 'xfoo foo'), [[5, 'foo']]);
        assertDeepEquals(all('o\\B', '', 'foo'), [[1, 'o']]);
    }

    function testWhitespaceClass() {
        assertDeepEquals(all('\\s', '', 'a\u{FEFF}b\u{A0}c'), [[1, '\u{FEFF}'], [3, '\u{A0}']]);
        // NEL (U+0085) is not whitespace in JavaScript
        assertDeepEquals(all('\\s', '', 'a\u{85}b'), []);
        assertDeepEquals(all('\\S+', '', ' ab\u{2003}c'), [[1, 'ab'], [4, 'c']]);
    }

    function testDotExcludesLineTerminators() {
        assertDeepEquals(all('a.b', '', 'a\rb a\nb a\u{2028}b a\u{85}b axb'), [[12, 'a\u{85}b'], [16, 'axb']]);
        assertDeepEquals(all('a.b', 's', 'a\nb'), [[0, 'a\nb']]);
        // `.` matches a whole code point with `u`
        assertDeepEquals(all('a.b', 'u', 'a\u{1F600}b'), [[0, 'a\u{1F600}b']]);
    }

    function testAnchorsWithoutMultiline() {
        assertDeepEquals(all('a$', '', 'a\n'), []);
        assertDeepEquals(all('a$', '', 'ba'), [[1, 'a']]);
        assertDeepEquals(all('^b', '', 'a\nb'), []);
        assertDeepEquals(all('^a', '', 'aa'), [[0, 'a']]);
    }

    function testAnchorsWithMultiline() {
        assertDeepEquals(all('^b', 'm', 'a\rb\nb\u{2028}b'), [[2, 'b'], [4, 'b'], [6, 'b']]);
        assertDeepEquals(all('a$', 'm', 'a\ra\r\na\u{2029}a'), [[0, 'a'], [2, 'a'], [5, 'a'], [7, 'a']]);
        // Between \r and \n
        assertDeepEquals(all('^$', 'm', '\r\n'), [[0, ''], [1, ''], [2, '']]);
    }

    function testLastIndexStepping() {
        final regex = new RegExp('a', 'g');
        final m1 = regex.exec('aXa');
        assertEquals(m1.index, 0);
        assertEquals(regex.lastIndex, 1);
        final m2 = regex.exec('aXa');
        assertEquals(m2.index, 2);
        assertEquals(regex.lastIndex, 3);
        assertEquals(regex.exec('aXa'), null);
        assertEquals(regex.lastIndex, 0);

        // Without g, lastIndex is ignored and not updated
        final simple = new RegExp('a');
        simple.lastIndex = 2;
        assertEquals(simple.exec('aXa').index, 0);
        assertEquals(simple.lastIndex, 2);

        // Empty match: lastIndex does not move
        final empty = new RegExp('x*', 'g');
        final m3 = empty.exec('ab');
        assertEquals(m3.index, 0);
        assertEquals(m3[0], '');
        assertEquals(empty.lastIndex, 0);

        // lastIndex past the end
        final past = new RegExp('a', 'g');
        past.lastIndex = 5;
        assertEquals(past.exec('aa'), null);
        assertEquals(past.lastIndex, 0);
    }

    function testSticky() {
        final regex = new RegExp('a', 'y');
        regex.lastIndex = 1;
        assertEquals(regex.exec('ba').index, 1);
        assertEquals(regex.lastIndex, 2);
        regex.lastIndex = 1;
        assertEquals(regex.exec('bba'), null);
        assertEquals(regex.lastIndex, 0);
    }

    function testIndicesInUtf16Units() {
        assertDeepEquals(all('b', '', '\u{1F600}b'), [[2, 'b']]);
        assertDeepEquals(all('\\u{1F600}', 'u', 'a\u{1F600}'), [[1, '\u{1F600}']]);
        assertDeepEquals(all('\\uD83D\\uDE00', 'u', 'a\u{1F600}'), [[1, '\u{1F600}']]);
        assertDeepEquals(all('\u{4E2D}\u{6587}', '', 'x\u{4E2D}\u{6587}'), [[1, '\u{4E2D}\u{6587}']]);
    }

    function testGroups() {
        final m = new RegExp('(a)|(b)').exec('b');
        assertEquals(m.length, 3);
        assertEquals(m[0], 'b');
        assertEquals(m[1], null);
        assertEquals(m[2], 'b');

        final named = new RegExp('(?<year>\\d{4})-(\\d\\d)').exec('in 2024-11');
        assertEquals(named.index, 3);
        assertEquals(named.length, 3);
        assertEquals(named[1], '2024');
        assertEquals(named[2], '11');

        final nonCapturing = new RegExp('(?:a)(?=b)(?!c)(?<=a)(b)').exec('ab');
        assertEquals(nonCapturing.length, 2);
        assertEquals(nonCapturing[1], 'b');

        final backReference = new RegExp('(\\w)\\1').exec('abccd');
        assertEquals(backReference.index, 2);
        assertEquals(backReference[0], 'cc');
    }

    function testCaseInsensitive() {
        assertDeepEquals(all('\u{E9}', 'iu', '\u{C9}'), [[0, '\u{C9}']]);
        assertDeepEquals(all('ab', 'i', 'xAB'), [[1, 'AB']]);
    }

    function testCharacterClasses() {
        assertDeepEquals(all('a[^]b', '', 'a\nb'), [[0, 'a\nb']]);
        assertDeepEquals(all('a[]b', '', 'ab a\nb'), []);
        // `[` inside a class is a literal (never a POSIX class)
        assertDeepEquals(all('[[:a]+', '', 'x[a:'), [[1, '[a:']]);
        assertDeepEquals(all('[\\u0041-\\u0043]+', '', 'xABCD'), [[1, 'ABC']]);
        assertDeepEquals(all('[\\b]', '', 'a\u{8}'), [[1, '\u{8}']]);
    }

    function testEscapes() {
        assertDeepEquals(all('\\v', '', '\n\u{B}'), [[1, '\u{B}']]);
        assertDeepEquals(all('\\/', '', 'a/b'), [[1, '/']]);
        assertDeepEquals(all('\\x41', '', 'BA'), [[1, 'A']]);
        assertDeepEquals(all('\\0', '', 'a\u{0}'), [[1, '\u{0}']]);
        assertDeepEquals(all('\\t\\n', '', 'a\t\n'), [[1, '\t\n']]);
        // Identity escapes of letters without the u flag
        assertDeepEquals(all('\\a\\e', '', 'xae'), [[1, 'ae']]);
    }

    function testUnicodeProperties() {
        assertDeepEquals(all('\\p{L}+', 'u', '1\u{E9}t\u{E9}2'), [[1, '\u{E9}t\u{E9}']]);
        assertDeepEquals(all('\\p{Script=Greek}', 'u', 'a\u{3B1}'), [[1, '\u{3B1}']]);
    }

    function testSourceAndFlags() {
        final regex = new RegExp('a', 'ugi');
        assertEquals(regex.flags, 'giu');
        assertTrue(regex.global);
        assertTrue(regex.ignoreCase);
        assertTrue(regex.unicode);
        assertFalse(regex.multiline);
        assertEquals(new RegExp('').source, '(?:)');
        // EscapeRegExpPattern: `/` outside classes and line terminators
        assertEquals('\\/foo\\/(bar)', new RegExp('/foo/(bar)').source);
        assertEquals('\\/a', new RegExp('\\/a').source);
        assertEquals('[/]x', new RegExp('[/]x').source);
        assertEquals('a\\nb\\rc', new RegExp('a\nb\rc').source);
        assertRaises(() -> new RegExp('a', 'gg'));
        assertRaises(() -> new RegExp('a', 'x'));
        assertRaises(() -> new RegExp('(a', ''));
    }

    function testWordDefinitionOfWordHelper() {
        final regex = cityscape.common.core.WordHelper.DEFAULT_WORD_REGEXP;
        regex.lastIndex = 0;
        final words = [];
        var m;
        while ((m = regex.exec('foo.bar(-1.5, b\u{E9}b\u{E9})')) != null) {
            words.push(m[0]);
        }
        regex.lastIndex = 0;
        assertDeepEquals(words, ['foo', 'bar', '-1.5', 'b\u{E9}b\u{E9}']);
    }


    /**
     * A hyphen next to a class escape inside a class is a literal in
     * JavaScript (Annex B): `[\w-?]` is not a range (the word pattern of
     * vscode's 'issue #61296' test). Expected values from node.
     */
    function testHyphenNextToClassEscapeInClass() {
        assertDeepEquals(all('[\\w-?]+', '', '..a-?b!'), [[2, 'a-?b']]);
        assertDeepEquals(all('[a-\\d]+', '', 'xx-a5-b'), [[2, '-a5-']]);
        assertDeepEquals(all('[\\s-x]+', '', 'ab -x c'), [[2, ' -x ']]);
    }

}

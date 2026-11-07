// Ported from gpui-kit 0.8.1: crates/base/src/text/selection.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.kit.base.text.Selection;
import glaze.util.Utf8;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.text.Selection` (Rust `text/selection.rs`).
 */
class TextSelectionTest extends TestCase {

    function testCharTypeFromChar() {
        assertEquals(CharType.Word, CharType.from('a'.code));
        assertEquals(CharType.Word, CharType.from('Z'.code));
        assertEquals(CharType.Word, CharType.from('0'.code));
        assertEquals(CharType.Word, CharType.from('_'.code));
        assertEquals(CharType.Other, CharType.from('.'.code));
        assertEquals(CharType.Other, CharType.from(','.code));
        assertEquals(CharType.Other, CharType.from(';'.code));
        assertEquals(CharType.Other, CharType.from('!'.code));
        assertEquals(CharType.Other, CharType.from('?'.code));
        assertEquals(CharType.Other, CharType.from('['.code));
        assertEquals(CharType.Other, CharType.from('{'.code));
        assertEquals(CharType.Whitespace, CharType.from(' '.code));
        assertEquals(CharType.Whitespace, CharType.from('\t'.code));
        assertEquals(CharType.Whitespace, CharType.from(0x00A0));
        assertEquals(CharType.Newline, CharType.from('\n'.code));
        assertEquals(CharType.Newline, CharType.from('\r'.code));
        assertEquals(CharType.Other, CharType.from(0x6C49)); // 汉
        assertEquals(CharType.Word, CharType.from(0xE9)); // é
        assertEquals(CharType.Word, CharType.from(0xE4)); // ä
        assertEquals(CharType.Word, CharType.from(0xF6)); // ö
        assertEquals(CharType.Word, CharType.from(0xFC)); // ü
        assertEquals(CharType.Word, CharType.from(0x434)); // д
    }

    function testWordRangeAt() {
        final text = "test text\nabcde 中文🎉 test\nhello[()]\ntest_connector ____\nRope\nrök\ngrande île";
        final tests:Array<{offset:Int, expected:String}> = [
            {offset: 0, expected: "test"},
            {offset: 4, expected: " "},
            {offset: 10, expected: "abcde"},
            {offset: 15, expected: " "},
            {offset: 16, expected: "中"},
            {offset: 19, expected: "文"},
            {offset: 22, expected: "🎉"},
            {offset: 27, expected: "test"},
            {offset: 37, expected: "["},
            {offset: 38, expected: "("},
            {offset: 39, expected: ")"},
            {offset: 40, expected: "]"},
            {offset: 42, expected: "test_connector"},
            {offset: 56, expected: " "},
            {offset: 57, expected: "____"},
            {offset: 62, expected: "Rope"},
            {offset: 67, expected: "rök"},
            {offset: 79, expected: "île"},
        ];

        for (test in tests) {
            final range = Selection.wordRangeAt(text, test.offset);
            final actual = range != null ? Utf8.substring(text, range.start, range.end) : null;
            assertEquals(test.expected, actual, 'offset ${test.offset}');
        }
    }

}

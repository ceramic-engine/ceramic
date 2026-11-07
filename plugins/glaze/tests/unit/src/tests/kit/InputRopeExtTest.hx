// Ported from gpui-kit 0.8.1: crates/base/src/input/base/rope_ext.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.Range;
import gpui.base.input.Bias;
import gpui.base.input.LspPosition;
import gpui.base.input.RopePoint;
import gpui.util.Utf8;
import ropey.Rope;
import testing.TestCase;

using gpui.base.input.RopeExt;

/**
 * Tests of `gpui.base.input.RopeExt` (Rust `rope_ext.rs`), with its doc
 * examples. `"..".len()` is the UTF-8 byte length (`Utf8.byteLength`).
 */
class InputRopeExtTest extends TestCase {

    static inline function len(s:String):Int {
        return Utf8.byteLength(s);
    }

    static function rangeStr(range:Null<Range>):String {
        return Range.describe(range);
    }

    function testSliceLine() {
        var rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope");
        assertEquals("Hello", rope.sliceLine(0).toString());
        assertEquals("World\r", rope.sliceLine(1).toString());
        assertEquals("This is a test 中文", rope.sliceLine(2).toString());
        assertEquals("Rope", rope.sliceLine(3).toString());

        // over bounds
        assertEquals("", rope.sliceLine(6).toString());

        // only have \r end
        rope = Rope.fromStr("Hello\r");
        assertEquals("Hello\r", rope.sliceLine(0).toString());
        assertEquals("", rope.sliceLine(1).toString());
    }

    function testLinesLen() {
        assertEquals(4, Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope").linesLen());
        assertEquals(1, Rope.fromStr("").linesLen());
        assertEquals(1, Rope.fromStr("Single line").linesLen());

        // only have \r end
        assertEquals(1, Rope.fromStr("Hello\r").linesLen());
    }

    function testLines() {
        final rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope\r");
        final lines = [for (line in rope.iterLines()) line.toString()];
        assertEquals("Hello|World\r|This is a test 中文|Rope\r", lines.join("|"));
    }

    function testEq() {
        final rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope");
        assertTrue(rope.equals(Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope")));
        assertFalse(rope.equals(Rope.fromStr("Hello\nWorld")));

        final rope1 = rope.clone();
        assertTrue(rope.equals(rope1));
    }

    function testIterLines() {
        final rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope");
        // .skip(1).take(2)
        final iter = rope.iterLines();
        final lines = [iter.nth(1).toString(), iter.next().toString()];
        assertEquals("World\r|This is a test 中文", lines.join("|"));
    }

    function testLineStartEndOffset() {
        final rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope");
        assertEquals(0, rope.lineStartOffset(0));
        assertEquals(5, rope.lineEndOffset(0));

        assertEquals(6, rope.lineStartOffset(1));
        assertEquals(12, rope.lineEndOffset(1));

        assertEquals(13, rope.lineStartOffset(2));
        assertEquals(34, rope.lineEndOffset(2));

        assertEquals(35, rope.lineStartOffset(3));
        assertEquals(39, rope.lineEndOffset(3));

        assertEquals(39, rope.lineStartOffset(4));
        assertEquals(39, rope.lineEndOffset(4));
    }

    function testLineColumn() {
        final rope = Rope.fromStr("a 中文🎉 test\nRope");
        assertEquals(len("a 中"), rope.positionToOffset(new LspPosition(0, 3)));
        assertEquals(len("a 中文🎉"), rope.positionToOffset(new LspPosition(0, 5)));
        assertEquals(len("a 中文🎉 test\nR"), rope.positionToOffset(new LspPosition(1, 1)));
        // u32::MAX does not fit a Haxe Int: the largest Int clamps the same way.
        assertEquals(len("a 中文🎉 test"), rope.positionToOffset(new LspPosition(0, 2147483647)));

        assertTrue(new LspPosition(1, 1).equals(rope.offsetToPosition(len("a 中文🎉 test\nR"))));
        assertTrue(new LspPosition(0, 5).equals(rope.offsetToPosition(len("a 中文🎉"))));
    }

    function testOffsetToPoint() {
        final rope = Rope.fromStr("a 中文🎉 test\nRope");
        assertTrue(new RopePoint(0, 0).equals(rope.offsetToPoint(0)));
        assertTrue(new RopePoint(0, 1).equals(rope.offsetToPoint(1)));
        assertTrue(new RopePoint(0, 5).equals(rope.offsetToPoint(len("a 中"))));
        assertTrue(new RopePoint(0, 12).equals(rope.offsetToPoint(len("a 中文🎉"))));
        assertTrue(new RopePoint(1, 1).equals(rope.offsetToPoint(len("a 中文🎉 test\nR"))));
    }

    function testPointToOffset() {
        final rope = Rope.fromStr("a 中文🎉 test\nRope");
        assertEquals(0, rope.pointToOffset(new RopePoint(0, 0)));
        assertEquals(1, rope.pointToOffset(new RopePoint(0, 1)));
        assertEquals(len("a 中"), rope.pointToOffset(new RopePoint(0, 5)));
        assertEquals(len("a 中文🎉"), rope.pointToOffset(new RopePoint(0, 12)));
        assertEquals(len("a 中文🎉 test\nR"), rope.pointToOffset(new RopePoint(1, 1)));
    }

    function testCharAt() {
        final rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文🎉\nRope");
        assertEquals('H'.code, rope.charAt(0));
        assertEquals('\n'.code, rope.charAt(5));
        assertEquals('T'.code, rope.charAt(13));
        assertEquals(0x4E2D, rope.charAt(28)); // 中
        assertEquals(0x1F389, rope.charAt(34)); // 🎉
        assertEquals('\n'.code, rope.charAt(38));
        assertEquals(null, rope.charAt(50));
    }

    function testWordAt() {
        final rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文 世界\nRope");
        assertEquals("Hello", rope.wordAt(0));
        assertEquals("0..5", rangeStr(rope.wordRange(0)));
        assertEquals("World", rope.wordAt(8));
        assertEquals("6..11", rangeStr(rope.wordRange(8)));
        assertEquals("", rope.wordAt(12));
        assertEquals("None", rangeStr(rope.wordRange(12)));
        assertEquals("This", rope.wordAt(13));
        assertEquals("13..17", rangeStr(rope.wordRange(13)));
        assertEquals("中文", rope.wordAt(31));
        assertEquals("28..34", rangeStr(rope.wordRange(31)));
        assertEquals("世界", rope.wordAt(38));
        assertEquals("35..41", rangeStr(rope.wordRange(38)));
        assertEquals("Rope", rope.wordAt(44));
        assertEquals("42..46", rangeStr(rope.wordRange(44)));
        assertEquals("Rope", rope.wordAt(45));
    }

    function testOffsetUtf16Conversion() {
        final rope = Rope.fromStr("hello 中文🎉 test\nRope");
        assertEquals(5, rope.offsetToOffsetUtf16(len("hello")));
        assertEquals(7, rope.offsetToOffsetUtf16(len("hello 中")));
        assertEquals(8, rope.offsetToOffsetUtf16(len("hello 中文")));
        assertEquals(10, rope.offsetToOffsetUtf16(len("hello 中文🎉")));
        assertEquals(20, rope.offsetToOffsetUtf16(100));

        assertEquals(len("hello"), rope.offsetUtf16ToOffset(5));
        assertEquals(len("hello 中"), rope.offsetUtf16ToOffset(7));
        assertEquals(len("hello 中文"), rope.offsetUtf16ToOffset(8));
        assertEquals(len("hello 中文🎉"), rope.offsetUtf16ToOffset(10));
        assertEquals(rope.len(), rope.offsetUtf16ToOffset(100));
    }

    function testReplace() {
        var rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope");
        rope.replace(new Range(6, 11), "Universe");
        assertEquals("Hello\nUniverse\r\nThis is a test 中文\nRope", rope.toString());

        rope.replace(new Range(0, 5), "Hi");
        assertEquals("Hi\nUniverse\r\nThis is a test 中文\nRope", rope.toString());

        rope.replace(new Range(rope.len() - 4, rope.len()), "String");
        assertEquals("Hi\nUniverse\r\nThis is a test 中文\nString", rope.toString());

        // Test for not on a char boundary
        rope = Rope.fromStr("中文");
        rope.replace(new Range(0, 1), "New");
        assertEquals("New文", rope.toString());
        rope = Rope.fromStr("中文");
        rope.replace(new Range(0, 2), "New");
        assertEquals("New文", rope.toString());
        rope = Rope.fromStr("中文");
        rope.replace(new Range(0, 3), "New");
        assertEquals("New文", rope.toString());
        rope = Rope.fromStr("中文");
        rope.replace(new Range(1, 4), "New");
        assertEquals("New", rope.toString());
    }

    function testClipOffset() {
        final rope = Rope.fromStr("Hello 中文🎉 test\nRope");
        // Inside multi-byte character '中' (3 bytes)
        assertEquals(5, rope.clipOffset(5, Bias.Left));
        assertEquals(6, rope.clipOffset(7, Bias.Left));
        assertEquals(9, rope.clipOffset(7, Bias.Right));
        assertEquals(9, rope.clipOffset(9, Bias.Left));

        // Inside multi-byte character '🎉' (4 bytes)
        assertEquals(12, rope.clipOffset(13, Bias.Left));
        assertEquals(16, rope.clipOffset(13, Bias.Right));
        assertEquals(16, rope.clipOffset(16, Bias.Left));

        // At character boundary
        assertEquals(5, rope.clipOffset(5, Bias.Left));
        assertEquals(5, rope.clipOffset(5, Bias.Right));

        // Out of bounds
        assertEquals(26, rope.clipOffset(26, Bias.Left));
        assertEquals(26, rope.clipOffset(100, Bias.Left));
    }

    function testCharIndexToOffset() {
        final rope = Rope.fromStr("a 中文🎉 test\nRope");
        assertEquals(0, rope.charIndexToOffset(0));
        assertEquals(1, rope.charIndexToOffset(1));
        assertEquals(len("a 中"), rope.charIndexToOffset(3));
        assertEquals(len("a 中文🎉"), rope.charIndexToOffset(5));
        assertEquals(len("a 中文🎉 "), rope.charIndexToOffset(6));

        assertEquals(0, rope.offsetToCharIndex(0));
        assertEquals(1, rope.offsetToCharIndex(1));
        assertEquals(3, rope.offsetToCharIndex(3));
        assertEquals(3, rope.offsetToCharIndex(4));
        assertEquals(3, rope.offsetToCharIndex(5));
        assertEquals(4, rope.offsetToCharIndex(6));
        assertEquals(5, rope.offsetToCharIndex(10));
    }

    // Doc examples of the RopeExt trait.

    function testDocExamples() {
        final rope = Rope.fromStr("Hello\nWorld\r\nThis is a test 中文\nRope");
        assertEquals(0, rope.lineStartOffset(0));
        assertEquals(6, rope.lineStartOffset(1));
        assertEquals(5, rope.lineEndOffset(0));
        assertEquals(12, rope.lineEndOffset(1));
        assertEquals("Hello\nWorld\r", rope.sliceLines(new Range(0, 2)).toString());
        assertEquals("World\r\nThis is a test 中文", rope.sliceLines(new Range(1, 3)).toString());
        assertEquals("This is a test 中文\nRope", rope.sliceLines(new Range(2, 5)).toString());
        assertEquals("Rope", rope.sliceLines(new Range(3, 10)).toString());
        assertEquals("", rope.sliceLines(new Range(5, 10)).toString());
        assertEquals(5, rope.lineLen(0));
        assertEquals(6, rope.lineLen(1));
        assertEquals(21, rope.lineLen(2));
        assertEquals(0, rope.lineLen(4));

        final rope = Rope.fromStr("a 中文🎉 test\nRope");
        assertEquals(0, rope.offsetToCharIndex(0));
        assertEquals(1, rope.offsetToCharIndex(1));
        assertEquals(3, rope.offsetToCharIndex(3));
        assertEquals(3, rope.offsetToCharIndex(4));
    }

}

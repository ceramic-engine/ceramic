// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Font;
import glaze.LineLayout;
import glaze.LineWrapper.Boundary;
import glaze.Point;
import glaze.Range;
import glaze.ShapedLine;
import glaze.TextAlign;
import glaze.kit.base.input.InputLineLayout;
import glaze.kit.base.input.LastLayout;
import glaze.kit.base.input.LineItem;
import glaze.kit.base.input.LineItems;
import glaze.kit.base.input.TextWrapper;
import glaze.kit.base.input.WidthRange;
import glaze.kit.base.input.WrapDisplayPoint;
import glaze.kit.base.input.WrappingIndent;
import glaze.util.Utf8;
import ropey.Rope;
import testing.TestCase;
import unicode_segmentation.UnicodeSegmentation;

using glaze.kit.base.input.RopeExt;

/**
 * Tests of `glaze.kit.base.input.TextWrapper` and `InputLineLayout` (Rust
 * `text_wrapper.rs`).
 *
 * Not ported: `production_wrap_keeps_shaped_cjk_latin_boundary_during_edits`
 * and `production_wrap_preserves_words_and_complete_graphemes`, which only
 * run on Linux with its native text engine (`#[cfg(target_os = "linux")]`).
 */
class InputTextWrapperTest extends TestCase {

    static inline function r(a:Int, b:Int):Range {
        return new Range(a, b);
    }

    static function ranges(list:Array<Range>):String {
        return [for (range in list) range.toString()].join(',');
    }

    static function shaped(len:Int = 0):ShapedLine {
        return new ShapedLine(new LineLayout(), '').withLen(len);
    }

    static function testFont():Font {
        return Font.of('Arial');
    }

    static function byteLength(s:String):Int {
        return Utf8.byteLength(s);
    }

    /**
     * `WidthRange.nextUp` / `nextDown` (Rust `f64::next_up` / `next_down`)
     * equal the 64 bit pattern arithmetic through `Int64` on every target
     * (JavaScript takes another path, without `Int64`): signs, zeros,
     * subnormals, infinities, NaN, and carries between the 32 bit words.
     */
    function testNextUpAndNextDownFollowTheBitPattern() {
        function reference(value:Float, up:Bool):Float {
            if (!up)
                return -reference(-value, true);
            if (value != value || value == Math.POSITIVE_INFINITY)
                return value;
            if (value == 0.0)
                return haxe.io.FPHelper.i64ToDouble(1, 0);
            final bits = haxe.io.FPHelper.doubleToI64(value);
            final next = value > 0 ? haxe.Int64.add(bits, 1) : haxe.Int64.sub(bits, 1);
            return haxe.io.FPHelper.i64ToDouble(next.low, next.high);
        }
        function bits(value:Float):String {
            final b = haxe.io.FPHelper.doubleToI64(value);
            return StringTools.hex(b.high, 8) + StringTools.hex(b.low, 8);
        }
        final values:Array<Float> = [
            0.0, -0.0, 1.0, -1.0, 0.5, 1.5, 100.25, -3.75, 1e-300, -1e300, Math.POSITIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NaN,
            haxe.io.FPHelper.i64ToDouble(1, 0), haxe.io.FPHelper.i64ToDouble(1, 0x80000000), // smallest subnormals
            haxe.io.FPHelper.i64ToDouble(-1, 0x7FEFFFFF), haxe.io.FPHelper.i64ToDouble(-1, 0xFFEFFFFF), // largest finite
            haxe.io.FPHelper.i64ToDouble(-1, 0x000FFFFF), haxe.io.FPHelper.i64ToDouble(0, 0x00100000), // subnormal and normal edges
            haxe.io.FPHelper.i64ToDouble(-1, 0x3FF00000), haxe.io.FPHelper.i64ToDouble(0, 0xBFF00001), // low word carries and borrows
            haxe.io.FPHelper.i64ToDouble(0x7FFFFFFF, 0x40000000), haxe.io.FPHelper.i64ToDouble(0x80000000, 0xC0000000)
        ];
        var seed = 99;
        function next():Int {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            return seed;
        }
        for (_ in 0...2000) {
            // Random patterns, and random low words around the carry
            final low = next() % 4 == 0 ? [0, -1, 0x7FFFFFFF, 0x80000000][next() % 4] : (next() << 1) ^ next();
            values.push(haxe.io.FPHelper.i64ToDouble(low, (next() << 1) ^ next()));
        }
        var checked = 0;
        for (value in values) {
            assertEquals(bits(reference(value, true)), bits(WidthRange.nextUp(value)), 'nextUp(' + bits(value) + ')');
            assertEquals(bits(reference(value, false)), bits(WidthRange.nextDown(value)), 'nextDown(' + bits(value) + ')');
            checked++;
        }
        assertEquals(2023, checked);
        // Two calls in a row do not share state
        assertEquals(1.0, WidthRange.nextDown(WidthRange.nextUp(1.0)));
    }

    function testMeasuredWrapKeepsCjkLatinBoundaryStableDuringEdits() {
        final measure = (text:String) -> {
            var width = 0.0;
            for (k in 0...text.length) {
                final c = StringTools.fastCodeAt(text, k);
                // low surrogates are counted with their high surrogate
                if (c >= 0xDC00 && c <= 0xDFFF)
                    continue;
                width += c < 0x80 ? 1. : 2.;
            }
            return width;
        };
        final wrapper = new TextWrapper(Font.of("Arial"), 14., 6.);
        var previous = new Rope();
        for (value in ["abcd的", "abcd的s", "abcd的ss", "abcd的s", "abcd的"]) {
            final text = Rope.fromStr(value);
            final start = previous.len() < text.len() ? previous.len() : text.len();
            final inserted = Rope.fromStr(text.sliceFrom(start).toString());
            wrapper._update(text, r(start, previous.len()), inserted, (line, width, _) -> TextWrapper.measuredWrapBoundaries(line, width, WrappingIndent.None, measure));
            final expected = StringTools.endsWith(value, 's') ? [r(0, 7), r(7, byteLength(value))] : [r(0, 7)];
            assertEquals(ranges(expected), ranges(wrapper.line(0).wrappedLines));
            final cursor = wrapper.offsetToDisplayPoint(byteLength(value));
            assertEquals(StringTools.endsWith(value, 's') ? 1 : 0, cursor.row);
            previous = text;
        }
    }

    function testMeasuredWrapPreservesWordsGraphemesAndIndentation() {
        final wrap = (text:String, width:Float, indent:WrappingIndent) -> {
            return TextWrapper.measuredWrapBoundaries(text, width, indent, s -> {
                var count = 0;
                for (_ in UnicodeSegmentation.graphemes(s, true))
                    count++;
                return count;
            }).map(b -> b.ix).join(',');
        };
        assertEquals('6', wrap("hello world", 8., WrappingIndent.None));
        assertEquals('${byteLength("a👩‍💻")}', wrap("a👩‍💻b", 2., WrappingIndent.None));
        assertEquals('5,8', wrap("  abcdefgh", 5., WrappingIndent.Same));
        assertEquals('2,7', wrap("  abcdefgh", 5., WrappingIndent.None));
        assertEquals('', wrap("", 0., WrappingIndent.None));
        assertEquals('1,2', wrap("abc", 0., WrappingIndent.None));
        // Closing punctuation stays with the preceding Chinese character.
        assertEquals('3,9', wrap("你好，世界", 2., WrappingIndent.None));
    }

    static function fakeWrapLine(line:String, wrapWidth:Float, start:Int):Array<Boundary> {
        return [];
    }

    function assertWrapperLines(text:Rope, wrapper:TextWrapper, expectedLines:Array<Array<String>>, ?pos:haxe.PosInfos) {
        final actualLines:Array<Array<String>> = [];
        var offset = 0;
        for (line in wrapper.iterLines()) {
            actualLines.push([for (range in line.wrappedLines) text.slice(offset + range.start, offset + range.end).toString()]);
            // +1 \n
            offset += line.len() + 1;
        }
        assertEquals(haxe.Json.stringify(expectedLines), haxe.Json.stringify(actualLines), null, pos);
    }

    function testUpdate() {
        final wrapper = new TextWrapper(testFont(), 14., null);
        final text = Rope.fromStr("Hello, 世界!\r\nThis is second line.\nThis is third line.\n这里是第 4 行。");

        wrapper._update(text, r(0, text.len()), text, fakeWrapLine);
        assertEquals(4, wrapper.linesCount());
        assertWrapperLines(text, wrapper, [
            ["Hello, 世界!\r"],
            ["This is second line."],
            ["This is third line."],
            ["这里是第 4 行。"],
        ]);

        // Add a new text to end
        var range = r(text.len(), text.len());
        var newText = "New text";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);
        assertEquals("Hello, 世界!\r\nThis is second line.\nThis is third line.\n这里是第 4 行。New text", text.toString());
        assertEquals(4, wrapper.linesCount());
        assertWrapperLines(text, wrapper, [
            ["Hello, 世界!\r"],
            ["This is second line."],
            ["This is third line."],
            ["这里是第 4 行。New text"],
        ]);

        // Replace first line `Hello` to `AAA`
        range = r(0, 5);
        newText = "AAA";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);
        assertEquals("AAA, 世界!\r\nThis is second line.\nThis is third line.\n这里是第 4 行。New text", text.toString());
        assertEquals(4, wrapper.linesCount());
        assertWrapperLines(text, wrapper, [
            ["AAA, 世界!\r"],
            ["This is second line."],
            ["This is third line."],
            ["这里是第 4 行。New text"],
        ]);

        // Remove the second line
        final startOffset = text.lineStartOffset(1);
        final endOffset = text.lineEndOffset(1);
        range = r(startOffset, endOffset + 1);
        text.replace(range, "");
        wrapper._update(text, range, Rope.fromStr(""), fakeWrapLine);
        assertEquals("AAA, 世界!\r\nThis is third line.\n这里是第 4 行。New text", text.toString());
        assertEquals(3, wrapper.linesCount());
        assertWrapperLines(text, wrapper, [
            ["AAA, 世界!\r"],
            ["This is third line."],
            ["这里是第 4 行。New text"],
        ]);

        // Replace the first 2 lines to "This is a new line."
        range = r(text.lineStartOffset(0), text.lineEndOffset(1) + 1);
        newText = "This is a new line.\nThis is new line 2.\n";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);
        assertEquals("This is a new line.\nThis is new line 2.\n这里是第 4 行。New text", text.toString());
        assertEquals(3, wrapper.linesCount());
        assertWrapperLines(text, wrapper, [
            ["This is a new line."],
            ["This is new line 2."],
            ["这里是第 4 行。New text"],
        ]);

        // Add a new line at the end
        range = r(text.len(), text.len());
        newText = "\nThis is a new line at the end.";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);
        assertEquals("This is a new line.\nThis is new line 2.\n这里是第 4 行。New text\nThis is a new line at the end.", text.toString());
        assertEquals(4, wrapper.linesCount());
        assertWrapperLines(text, wrapper, [
            ["This is a new line."],
            ["This is new line 2."],
            ["这里是第 4 行。New text"],
            ["This is a new line at the end."],
        ]);

        // Add a new line at the beginning
        range = r(0, 0);
        newText = "This is a new line at the beginning.\n";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);
        assertEquals("This is a new line at the beginning.\nThis is a new line.\nThis is new line 2.\n这里是第 4 行。New text\nThis is a new line at the end.", text.toString());
        assertEquals(5, wrapper.linesCount());
        assertWrapperLines(text, wrapper, [
            ["This is a new line at the beginning."],
            ["This is a new line."],
            ["This is new line 2."],
            ["这里是第 4 行。New text"],
            ["This is a new line at the end."],
        ]);

        // Remove all to at least one line in `lines`.
        range = r(0, text.len());
        newText = "";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);
        assertEquals("", text.toString());
        assertEquals(1, wrapper.linesCount());
        assertEquals(ranges([r(0, 0)]), ranges(wrapper.line(0).wrappedLines));

        // Test update_all
        range = r(0, text.len());
        newText = "This is a full text.\nThis is a second line.";
        text.replace(range, newText);
        wrapper._update(text, range, text, fakeWrapLine);
        assertEquals("This is a full text.\nThis is a second line.", text.toString());
        assertEquals(2, wrapper.linesCount());
    }

    /** The longest-row summary stays exact when the previously-longest line is shrunk. */
    function testLongestRowAfterShrink() {
        final wrapper = new TextWrapper(testFont(), 14., null);
        final text = Rope.fromStr("aa\nthis is the longest line\nbb");
        wrapper._update(text, r(0, text.len()), text, fakeWrapLine);
        assertEquals(1, wrapper.longestRow());

        // Shrink line 1 so line 2-equivalent isn't longest.
        // Make line 0 the longest now.
        final start = text.lineStartOffset(0);
        final end = text.lineEndOffset(0);
        final range = r(start, end);
        final newText = "a very very long first line now";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);
        assertEquals(0, wrapper.longestRow());
    }

    /** Editing the last line and deleting everything must keep the tree consistent. */
    function testEditLastLineAndFullDelete() {
        final wrapper = new TextWrapper(testFont(), 14., null);
        final text = Rope.fromStr("one\ntwo\nthree");
        wrapper._update(text, r(0, text.len()), text, fakeWrapLine);
        assertEquals(3, wrapper.linesCount());

        // Replace the last line only.
        final start = text.lineStartOffset(2);
        var range = r(start, text.len());
        final newText = "THREE EDITED";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);
        assertEquals(3, wrapper.linesCount());
        assertEquals("THREE EDITED".length, wrapper.line(2).len());

        // Delete everything.
        range = r(0, text.len());
        text.replace(range, "");
        wrapper._update(text, range, Rope.fromStr(""), fakeWrapLine);
        assertEquals(1, wrapper.linesCount());
        assertEquals(1, wrapper.len());
        assertEquals(ranges([r(0, 0)]), ranges(wrapper.line(0).wrappedLines));
    }

    function testWrapRowBufferLineBoundaries() {
        final wrapper = new TextWrapper(testFont(), 14., null);
        wrapper.text = Rope.fromStr("aa\nbbbb\nc");
        wrapper.lines = LineItems.fromArray([
            new LineItem(2, 0, [r(0, 2)], WidthRange.empty()),
            new LineItem(4, 0, [r(0, 2), r(2, 4)], WidthRange.empty()),
            new LineItem(1, 0, [r(0, 1)], WidthRange.empty()),
        ]);

        assertEquals(3, wrapper.linesCount());
        assertEquals(4, wrapper.len());

        assertEquals(0, wrapper.bufferLineToFirstWrapRow(0));
        assertEquals(1, wrapper.bufferLineToFirstWrapRow(1));
        assertEquals(3, wrapper.bufferLineToFirstWrapRow(2));
        assertEquals(4, wrapper.bufferLineToFirstWrapRow(3));

        assertTrue(r(0, 1).equals(wrapper.bufferLineToWrapRowRange(0)));
        assertTrue(r(1, 3).equals(wrapper.bufferLineToWrapRowRange(1)));
        assertTrue(r(3, 4).equals(wrapper.bufferLineToWrapRowRange(2)));
        assertTrue(r(4, 4).equals(wrapper.bufferLineToWrapRowRange(3)));

        assertEquals(0, wrapper.wrapRowToBufferLine(0));
        assertEquals(1, wrapper.wrapRowToBufferLine(1));
        assertEquals(1, wrapper.wrapRowToBufferLine(2));
        assertEquals(2, wrapper.wrapRowToBufferLine(3));
        assertEquals(2, wrapper.wrapRowToBufferLine(4));
    }

    function testWrapRowQueriesAfterIncrementalSplice() {
        final wrapper = new TextWrapper(testFont(), 14., 10.);
        final text = Rope.fromStr("aa\nbbbb\nc");
        final fakeWrapLine = (line:String, wrapWidth:Float, _:Int) -> Utf8.byteLength(line) > 2 ? [new Boundary(2, 0)] : [];

        wrapper._update(text, r(0, text.len()), text, fakeWrapLine);
        assertTrue(r(0, 1).equals(wrapper.bufferLineToWrapRowRange(0)));
        assertTrue(r(1, 3).equals(wrapper.bufferLineToWrapRowRange(1)));
        assertTrue(r(3, 4).equals(wrapper.bufferLineToWrapRowRange(2)));

        final range = r(text.lineStartOffset(1), text.lineEndOffset(1));
        final newText = "dd\neeee";
        text.replace(range, newText);
        wrapper._update(text, range, Rope.fromStr(newText), fakeWrapLine);

        assertEquals(4, wrapper.linesCount());
        assertEquals(5, wrapper.len());
        assertTrue(r(0, 1).equals(wrapper.bufferLineToWrapRowRange(0)));
        assertTrue(r(1, 2).equals(wrapper.bufferLineToWrapRowRange(1)));
        assertTrue(r(2, 4).equals(wrapper.bufferLineToWrapRowRange(2)));
        assertTrue(r(4, 5).equals(wrapper.bufferLineToWrapRowRange(3)));
        assertEquals(0, wrapper.wrapRowToBufferLine(0));
        assertEquals(1, wrapper.wrapRowToBufferLine(1));
        assertEquals(2, wrapper.wrapRowToBufferLine(2));
        assertEquals(2, wrapper.wrapRowToBufferLine(3));
        assertEquals(3, wrapper.wrapRowToBufferLine(4));
    }

    function testLineLayout() {
        final lineLayout = new InputLineLayout();

        final line1 = shaped(100);
        final line2 = shaped(50);
        lineLayout.setWrappedLines([line1, line2]);
        assertEquals(150, lineLayout.len());
        assertEquals(2, lineLayout.wrappedLines.length);
    }

    /** A layout context whose only load-bearing field is the line height. */
    static function testLastLayout(lineHeight:Float):LastLayout {
        return new LastLayout(r(0, 1), [0], [0], 0., r(0, 0), [], lineHeight, null, WrappingIndent.defaultValue(), 0., 0., null, TextAlign.Left, 0.);
    }

    static function pointString(p:Null<Point>):String {
        return p == null ? 'None' : '(${p.x}, ${p.y})';
    }

    function testPositionForIndexPrefersFirstLeadingEmptyVisualLine() {
        final lineLayout = new InputLineLayout();
        lineLayout.setWrappedLines([shaped(), shaped(), shaped(3)]);

        assertEquals('(0, 0)', pointString(lineLayout.positionForIndex(0, testLastLayout(20.), false)));
    }

    function testClickingPastAWrappedRowKeepsTheCaretOnThatRow() {
        // One buffer line wrapped into two visual rows, splitting at byte 10.
        final lineLayout = new InputLineLayout();
        lineLayout.setWrappedLines([shaped(10), shaped(5)]);
        final lastLayout = testLastLayout(20.);

        // Clicking past the last glyph of the first row resolves to the wrap boundary, which is
        // also the first offset of the second row, hence the affinity.
        var hit = lineLayout.closestIndexForPosition(new Point(999., 5.), lastLayout);
        assertEquals(10, hit.index);
        assertTrue(hit.lineEndAffinity);

        // Carrying that affinity is what keeps the caret on the row that was clicked; dropping it
        // is the bug: the caret shows up one row below the pointer.
        assertEquals(0., lineLayout.positionForIndex(hit.index, lastLayout, hit.lineEndAffinity).y);
        assertEquals(20., lineLayout.positionForIndex(hit.index, lastLayout, false).y);

        // The final row owns the end of the line outright, so there is nothing to disambiguate.
        hit = lineLayout.closestIndexForPosition(new Point(999., 25.), lastLayout);
        assertEquals(15, hit.index);
        assertFalse(hit.lineEndAffinity);
    }

    function testAWrapBoundaryOffsetResolvesToTheRowTheCaretIsDrawnOn() {
        final wrapper = new TextWrapper(testFont(), 14., null);
        wrapper.text = Rope.fromStr("first line\nthis one wraps");
        wrapper.lines = LineItems.fromArray([
            new LineItem(Rope.fromStr("first line").len(), 0, [r(0, 10)], WidthRange.empty()),
            new LineItem(Rope.fromStr("this one wraps").len(), 0, [r(0, 9), r(9, 14)], WidthRange.empty()),
        ]);

        // Offset 20 is the wrap boundary of the second buffer line: 11 (line start) + 9.
        // It is the last offset of wrap row 1 and the first of wrap row 2 at the same time, so
        // only the affinity can say which row a vertical move should step away from.
        assertTrue(new WrapDisplayPoint(1, 0, 9).equals(wrapper.offsetToDisplayPointWithAffinity(20, true)));
        assertTrue(new WrapDisplayPoint(2, 1, 0).equals(wrapper.offsetToDisplayPointWithAffinity(20, false)));
        assertTrue(wrapper.offsetToDisplayPointWithAffinity(20, false).equals(wrapper.offsetToDisplayPoint(20)));

        // An offset that is not on a boundary is unaffected either way.
        for (lineEndAffinity in [false, true]) {
            assertTrue(new WrapDisplayPoint(2, 1, 3).equals(wrapper.offsetToDisplayPointWithAffinity(23, lineEndAffinity)));
        }
    }

    function testOffsetToDisplayPoint() {
        final wrapper = new TextWrapper(testFont(), 14., null);
        wrapper.text = Rope.fromStr("Hello, 世界!\r\nThis is second line.\nThis is third line.\n这里是第 4 行。");
        wrapper.lines = LineItems.fromArray([
            // range: 0..15
            new LineItem(Rope.fromStr("Hello, 世界!\r").len(), 0, [r(0, 15)], WidthRange.empty()),
            // range: 16..36
            new LineItem(Rope.fromStr("This is second line.\n").len(), 0, [r(0, 10), r(10, 20)], WidthRange.empty()),
            // range: 37..56
            new LineItem(Rope.fromStr("This is third line.\n").len(), 0, [r(0, 9), r(9, 15), r(15, 20)], WidthRange.empty()),
            // range: 57..79
            new LineItem(Rope.fromStr("这里是第 4 行。").len(), 0, [r(0, 22)], WidthRange.empty()),
        ]);

        inline function p(row, localRow, column) return new WrapDisplayPoint(row, localRow, column);
        assertTrue(p(0, 0, 12).equals(wrapper.offsetToDisplayPoint(12)));
        assertTrue(p(0, 0, 15).equals(wrapper.offsetToDisplayPoint(15)));

        assertTrue(p(1, 0, 0).equals(wrapper.offsetToDisplayPoint(16)));
        assertTrue(p(1, 0, 5).equals(wrapper.offsetToDisplayPoint(21)));
        assertTrue(p(2, 1, 1).equals(wrapper.offsetToDisplayPoint(27)));
        assertTrue(p(3, 0, 0).equals(wrapper.offsetToDisplayPoint(37)));
        assertTrue(p(5, 2, 2).equals(wrapper.offsetToDisplayPoint(54)));
        assertTrue(p(6, 0, 2).equals(wrapper.offsetToDisplayPoint(59)));

        assertEquals(59, wrapper.displayPointToOffset(p(6, 0, 2)));
        assertEquals(54, wrapper.displayPointToOffset(p(5, 2, 2)));
        assertEquals(37, wrapper.displayPointToOffset(p(3, 0, 0)));
        assertEquals(27, wrapper.displayPointToOffset(p(2, 1, 1)));
        assertEquals(21, wrapper.displayPointToOffset(p(1, 0, 5)));
        assertEquals(16, wrapper.displayPointToOffset(p(1, 0, 0)));
        assertEquals(15, wrapper.displayPointToOffset(p(0, 0, 15)));
    }

    static function indentFakeWrapLine(line:String, wrapWidth:Float, _:Int):Array<Boundary> {
        if (StringTools.startsWith(line, ' '))
            return [new Boundary(5, 2)];
        final boundaries:Array<Boundary> = [];
        var i = 8;
        while (i < Utf8.byteLength(line)) {
            boundaries.push(new Boundary(i, 0));
            i += 8;
        }
        return boundaries;
    }

    function testWrappingIndentSameKeepsIndentReserved() {
        final wrapper = new TextWrapper(testFont(), 14.0, 10.);
        wrapper.wrappingIndent = WrappingIndent.Same;
        final text = Rope.fromStr("  abcdefghijklmnopqrstuv");

        wrapper._update(text, r(0, text.len()), text, indentFakeWrapLine);

        final line = wrapper.line(0);
        assertEquals(2, line.indent);
        assertEquals(ranges([r(0, 5), r(5, 24)]), ranges(line.wrappedLines));
    }

    function testWrappingIndentNoneContinuationLinesWrappedAtFullWidth() {
        final wrapper = new TextWrapper(testFont(), 14.0, 10.);
        wrapper.wrappingIndent = WrappingIndent.None;
        final text = Rope.fromStr("  abcdefghijklmnopqrstuv");

        wrapper._update(text, r(0, text.len()), text, indentFakeWrapLine);

        final line = wrapper.line(0);
        assertEquals(0, line.indent);
        assertEquals(ranges([r(0, 5), r(5, 13), r(13, 21), r(21, 24)]), ranges(line.wrappedLines));
    }

    function testWrapIndentOffsetsContinuationLines() {
        var lineLayout = new InputLineLayout();
        lineLayout.setWrappedLines([shaped(5), shaped(10)]);

        lineLayout = lineLayout.withWrapIndent(20.0);

        final lastLayout = new LastLayout(r(0, 1), [0], [0], 0., r(0, 0), [], 20.0, 10., WrappingIndent.Same, 0., 0., null, TextAlign.Left, 0.);

        assertEquals('(0, 0)', pointString(lineLayout.positionForIndex(0, lastLayout, false)));
        assertEquals('(20, 20)', pointString(lineLayout.positionForIndex(6, lastLayout, false)));
    }

}

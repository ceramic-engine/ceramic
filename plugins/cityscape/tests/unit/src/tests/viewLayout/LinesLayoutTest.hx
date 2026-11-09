// Ported from vscode src/vs/editor/test/common/viewLayout/linesLayout.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.viewLayout;

import cityscape.common.viewLayout.LinesLayout;
import testing.TestCase;

/**
 * suite('Editor ViewLayout - LinesLayout')
 */
class LinesLayoutTest extends TestCase {

    static function insertWhitespace(linesLayout:LinesLayout, afterLineNumber:Int, ordinal:Int, heightInPx:Float, minWidth:Float):String {
        var id:String = null;
        linesLayout.changeWhitespace((accessor) -> {
            id = accessor.insertWhitespace(afterLineNumber, ordinal, heightInPx, minWidth);
        });
        return id;
    }

    static function changeOneWhitespace(linesLayout:LinesLayout, id:String, newAfterLineNumber:Int, newHeight:Float):Void {
        linesLayout.changeWhitespace((accessor) -> {
            accessor.changeOneWhitespace(id, newAfterLineNumber, newHeight);
        });
    }

    static function removeWhitespace(linesLayout:LinesLayout, id:String):Void {
        linesLayout.changeWhitespace((accessor) -> {
            accessor.removeWhitespace(id);
        });
    }

    // test('LinesLayout 1')
    function testLinesLayout1() {

        // Start off with 10 lines
        final linesLayout = new LinesLayout(10, 10, 0, 0);

        // lines: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        // whitespace: -
        assertEquals(linesLayout.getLinesTotalHeight(), 100);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 10);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 20);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 30);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 40);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 50);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 60);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 70);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 80);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 90);

        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(0), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(1), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(5), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(9), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(10), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(11), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(15), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(19), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(20), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(21), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(29), 3);

        // Add whitespace of height 5px after 2nd line
        insertWhitespace(linesLayout, 2, 0, 5, 0);
        // lines: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        // whitespace: a(2,5)
        assertEquals(linesLayout.getLinesTotalHeight(), 105);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 10);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 25);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 35);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 45);

        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(0), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(1), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(9), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(10), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(20), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(21), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(24), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(25), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(35), 4);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(45), 5);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(104), 10);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(105), 10);

        // Add two more whitespaces of height 5px
        insertWhitespace(linesLayout, 3, 0, 5, 0);
        insertWhitespace(linesLayout, 4, 0, 5, 0);
        // lines: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        // whitespace: a(2,5), b(3, 5), c(4, 5)
        assertEquals(linesLayout.getLinesTotalHeight(), 115);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 10);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 25);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 40);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 55);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 65);

        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(0), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(1), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(9), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(10), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(19), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(20), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(34), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(35), 4);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(49), 4);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(50), 5);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(64), 5);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(65), 6);

        assertEquals(linesLayout.getVerticalOffsetForWhitespaceIndex(0), 20); // 20 -> 25
        assertEquals(linesLayout.getVerticalOffsetForWhitespaceIndex(1), 35); // 35 -> 40
        assertEquals(linesLayout.getVerticalOffsetForWhitespaceIndex(2), 50);

        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(0), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(19), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(20), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(21), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(22), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(23), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(24), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(25), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(26), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(34), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(35), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(36), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(39), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(40), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(41), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(49), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(50), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(51), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(54), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(55), -1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(1000), -1);

    }

    // test('LinesLayout 2')
    function testLinesLayout2() {

        // Start off with 10 lines and one whitespace after line 2, of height 5
        final linesLayout = new LinesLayout(10, 1, 0, 0);
        final a = insertWhitespace(linesLayout, 2, 0, 5, 0);

        // 10 lines
        // whitespace: - a(2,5)
        assertEquals(linesLayout.getLinesTotalHeight(), 15);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 1);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 7);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 8);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 9);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 10);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 11);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 12);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 13);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 14);

        // Change whitespace height
        // 10 lines
        // whitespace: - a(2,10)
        changeOneWhitespace(linesLayout, a, 2, 10);
        assertEquals(linesLayout.getLinesTotalHeight(), 20);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 1);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 12);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 13);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 14);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 15);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 16);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 17);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 18);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 19);

        // Change whitespace position
        // 10 lines
        // whitespace: - a(5,10)
        changeOneWhitespace(linesLayout, a, 5, 10);
        assertEquals(linesLayout.getLinesTotalHeight(), 20);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 1);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 2);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 3);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 4);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 15);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 16);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 17);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 18);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 19);

        // Pretend that lines 5 and 6 were deleted
        // 8 lines
        // whitespace: - a(4,10)
        linesLayout.onLinesDeleted(5, 6);
        assertEquals(linesLayout.getLinesTotalHeight(), 18);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 1);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 2);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 3);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 14);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 15);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 16);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 17);

        // Insert two lines at the beginning
        // 10 lines
        // whitespace: - a(6,10)
        linesLayout.onLinesInserted(1, 2);
        assertEquals(linesLayout.getLinesTotalHeight(), 20);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 1);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 2);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 3);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 4);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 5);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 16);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 17);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 18);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 19);

        // Remove whitespace
        // 10 lines
        removeWhitespace(linesLayout, a);
        assertEquals(linesLayout.getLinesTotalHeight(), 10);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 1);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 2);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 3);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 4);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 5);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 6);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 7);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 8);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 9);
    }

    // test('LinesLayout Padding')
    function testLinesLayoutPadding() {
        // Start off with 10 lines
        final linesLayout = new LinesLayout(10, 10, 15, 20);

        // lines: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        // whitespace: -
        assertEquals(linesLayout.getLinesTotalHeight(), 135);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 15);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 25);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 35);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 45);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 55);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 65);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 75);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 85);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 95);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 105);

        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(0), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(10), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(15), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(24), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(25), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(34), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(35), 3);

        // Add whitespace of height 5px after 2nd line
        insertWhitespace(linesLayout, 2, 0, 5, 0);
        // lines: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        // whitespace: a(2,5)
        assertEquals(linesLayout.getLinesTotalHeight(), 140);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 15);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 25);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 40);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 50);

        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(0), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(10), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(25), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(34), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(35), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(39), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(40), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(41), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(49), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(50), 4);

        // Add two more whitespaces of height 5px
        insertWhitespace(linesLayout, 3, 0, 5, 0);
        insertWhitespace(linesLayout, 4, 0, 5, 0);
        // lines: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        // whitespace: a(2,5), b(3, 5), c(4, 5)
        assertEquals(linesLayout.getLinesTotalHeight(), 150);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 15);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 25);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 40);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 55);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 70);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 80);

        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(0), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(15), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(24), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(30), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(35), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(39), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(40), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(49), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(50), 4);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(54), 4);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(55), 4);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(64), 4);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(65), 5);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(69), 5);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(70), 5);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(80), 6);

        assertEquals(linesLayout.getVerticalOffsetForWhitespaceIndex(0), 35); // 35 -> 40
        assertEquals(linesLayout.getVerticalOffsetForWhitespaceIndex(1), 50); // 50 -> 55
        assertEquals(linesLayout.getVerticalOffsetForWhitespaceIndex(2), 65);

        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(0), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(34), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(35), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(39), 0);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(40), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(49), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(50), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(54), 1);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(55), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(64), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(65), 2);
        assertEquals(linesLayout.getWhitespaceIndexAtOrAfterVerticallOffset(70), -1);
    }

    // test('LinesLayout getLineNumberAtOrAfterVerticalOffset')
    function testLinesLayoutGetLineNumberAtOrAfterVerticalOffset() {
        final linesLayout = new LinesLayout(10, 1, 0, 0);
        insertWhitespace(linesLayout, 6, 0, 10, 0);

        // 10 lines
        // whitespace: - a(6,10)
        assertEquals(linesLayout.getLinesTotalHeight(), 20);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 1);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 2);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 3);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 4);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 5);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 16);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 17);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 18);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 19);

        // Do some hit testing
        // line      [1, 2, 3, 4, 5, 6,  7,  8,  9, 10]
        // vertical: [0, 1, 2, 3, 4, 5, 16, 17, 18, 19]
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(-100), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(-1), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(0), 1);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(1), 2);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(2), 3);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(3), 4);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(4), 5);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(5), 6);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(6), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(7), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(8), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(9), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(10), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(11), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(12), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(13), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(14), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(15), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(16), 7);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(17), 8);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(18), 9);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(19), 10);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(20), 10);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(21), 10);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(22), 10);
        assertEquals(linesLayout.getLineNumberAtOrAfterVerticalOffset(23), 10);
    }

    // test('LinesLayout getCenteredLineInViewport')
    function testLinesLayoutGetCenteredLineInViewport() {
        final linesLayout = new LinesLayout(10, 1, 0, 0);
        insertWhitespace(linesLayout, 6, 0, 10, 0);

        // 10 lines
        // whitespace: - a(6,10)
        assertEquals(linesLayout.getLinesTotalHeight(), 20);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 1);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 2);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 3);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 4);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 5);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 16);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 17);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 18);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 19);

        // Find centered line in viewport 1
        // line      [1, 2, 3, 4, 5, 6,  7,  8,  9, 10]
        // vertical: [0, 1, 2, 3, 4, 5, 16, 17, 18, 19]
        assertEquals(linesLayout.getLinesViewportData(0, 1).centeredLineNumber, 1);
        assertEquals(linesLayout.getLinesViewportData(0, 2).centeredLineNumber, 2);
        assertEquals(linesLayout.getLinesViewportData(0, 3).centeredLineNumber, 2);
        assertEquals(linesLayout.getLinesViewportData(0, 4).centeredLineNumber, 3);
        assertEquals(linesLayout.getLinesViewportData(0, 5).centeredLineNumber, 3);
        assertEquals(linesLayout.getLinesViewportData(0, 6).centeredLineNumber, 4);
        assertEquals(linesLayout.getLinesViewportData(0, 7).centeredLineNumber, 4);
        assertEquals(linesLayout.getLinesViewportData(0, 8).centeredLineNumber, 5);
        assertEquals(linesLayout.getLinesViewportData(0, 9).centeredLineNumber, 5);
        assertEquals(linesLayout.getLinesViewportData(0, 10).centeredLineNumber, 6);
        assertEquals(linesLayout.getLinesViewportData(0, 11).centeredLineNumber, 6);
        assertEquals(linesLayout.getLinesViewportData(0, 12).centeredLineNumber, 6);
        assertEquals(linesLayout.getLinesViewportData(0, 13).centeredLineNumber, 6);
        assertEquals(linesLayout.getLinesViewportData(0, 14).centeredLineNumber, 6);
        assertEquals(linesLayout.getLinesViewportData(0, 15).centeredLineNumber, 6);
        assertEquals(linesLayout.getLinesViewportData(0, 16).centeredLineNumber, 6);
        assertEquals(linesLayout.getLinesViewportData(0, 17).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 18).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 19).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 21).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 22).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 23).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 24).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 25).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 26).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 27).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 28).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 29).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 30).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 31).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 32).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(0, 33).centeredLineNumber, 7);

        // Find centered line in viewport 2
        // line      [1, 2, 3, 4, 5, 6,  7,  8,  9, 10]
        // vertical: [0, 1, 2, 3, 4, 5, 16, 17, 18, 19]
        assertEquals(linesLayout.getLinesViewportData(0, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(1, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(2, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(3, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(4, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(5, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(6, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(7, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(8, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(9, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(10, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(11, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(12, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(13, 20).centeredLineNumber, 7);
        assertEquals(linesLayout.getLinesViewportData(14, 20).centeredLineNumber, 8);
        assertEquals(linesLayout.getLinesViewportData(15, 20).centeredLineNumber, 8);
        assertEquals(linesLayout.getLinesViewportData(16, 20).centeredLineNumber, 9);
        assertEquals(linesLayout.getLinesViewportData(17, 20).centeredLineNumber, 9);
        assertEquals(linesLayout.getLinesViewportData(18, 20).centeredLineNumber, 10);
        assertEquals(linesLayout.getLinesViewportData(19, 20).centeredLineNumber, 10);
        assertEquals(linesLayout.getLinesViewportData(20, 23).centeredLineNumber, 10);
        assertEquals(linesLayout.getLinesViewportData(21, 23).centeredLineNumber, 10);
        assertEquals(linesLayout.getLinesViewportData(22, 23).centeredLineNumber, 10);
    }

    // test('LinesLayout getLinesViewportData 1')
    function testLinesLayoutGetLinesViewportData1() {
        final linesLayout = new LinesLayout(10, 10, 0, 0);
        insertWhitespace(linesLayout, 6, 0, 100, 0);

        // 10 lines
        // whitespace: - a(6,100)
        assertEquals(linesLayout.getLinesTotalHeight(), 200);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 10);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 20);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 30);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 40);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 50);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 160);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 170);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 180);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 190);

        // viewport 0->50
        var viewportData = linesLayout.getLinesViewportData(0, 50);
        assertEquals(viewportData.startLineNumber, 1);
        assertEquals(viewportData.endLineNumber, 5);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 1);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 5);
        assertDeepEquals(viewportData.relativeVerticalOffset, [0, 10, 20, 30, 40]);

        // viewport 1->51
        viewportData = linesLayout.getLinesViewportData(1, 51);
        assertEquals(viewportData.startLineNumber, 1);
        assertEquals(viewportData.endLineNumber, 6);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 2);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 5);
        assertDeepEquals(viewportData.relativeVerticalOffset, [0, 10, 20, 30, 40, 50]);

        // viewport 5->55
        viewportData = linesLayout.getLinesViewportData(5, 55);
        assertEquals(viewportData.startLineNumber, 1);
        assertEquals(viewportData.endLineNumber, 6);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 2);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 5);
        assertDeepEquals(viewportData.relativeVerticalOffset, [0, 10, 20, 30, 40, 50]);

        // viewport 10->60
        viewportData = linesLayout.getLinesViewportData(10, 60);
        assertEquals(viewportData.startLineNumber, 2);
        assertEquals(viewportData.endLineNumber, 6);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 2);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 6);
        assertDeepEquals(viewportData.relativeVerticalOffset, [10, 20, 30, 40, 50]);

        // viewport 50->100
        viewportData = linesLayout.getLinesViewportData(50, 100);
        assertEquals(viewportData.startLineNumber, 6);
        assertEquals(viewportData.endLineNumber, 6);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 6);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 6);
        assertDeepEquals(viewportData.relativeVerticalOffset, [50]);

        // viewport 60->110
        viewportData = linesLayout.getLinesViewportData(60, 110);
        assertEquals(viewportData.startLineNumber, 7);
        assertEquals(viewportData.endLineNumber, 7);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 7);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 7);
        assertDeepEquals(viewportData.relativeVerticalOffset, [160]);

        // viewport 65->115
        viewportData = linesLayout.getLinesViewportData(65, 115);
        assertEquals(viewportData.startLineNumber, 7);
        assertEquals(viewportData.endLineNumber, 7);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 7);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 7);
        assertDeepEquals(viewportData.relativeVerticalOffset, [160]);

        // viewport 50->159
        viewportData = linesLayout.getLinesViewportData(50, 159);
        assertEquals(viewportData.startLineNumber, 6);
        assertEquals(viewportData.endLineNumber, 6);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 6);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 6);
        assertDeepEquals(viewportData.relativeVerticalOffset, [50]);

        // viewport 50->160
        viewportData = linesLayout.getLinesViewportData(50, 160);
        assertEquals(viewportData.startLineNumber, 6);
        assertEquals(viewportData.endLineNumber, 6);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 6);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 6);
        assertDeepEquals(viewportData.relativeVerticalOffset, [50]);

        // viewport 51->161
        viewportData = linesLayout.getLinesViewportData(51, 161);
        assertEquals(viewportData.startLineNumber, 6);
        assertEquals(viewportData.endLineNumber, 7);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 7);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 7);
        assertDeepEquals(viewportData.relativeVerticalOffset, [50, 160]);


        // viewport 150->169
        viewportData = linesLayout.getLinesViewportData(150, 169);
        assertEquals(viewportData.startLineNumber, 7);
        assertEquals(viewportData.endLineNumber, 7);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 7);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 7);
        assertDeepEquals(viewportData.relativeVerticalOffset, [160]);

        // viewport 159->169
        viewportData = linesLayout.getLinesViewportData(159, 169);
        assertEquals(viewportData.startLineNumber, 7);
        assertEquals(viewportData.endLineNumber, 7);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 7);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 7);
        assertDeepEquals(viewportData.relativeVerticalOffset, [160]);

        // viewport 160->169
        viewportData = linesLayout.getLinesViewportData(160, 169);
        assertEquals(viewportData.startLineNumber, 7);
        assertEquals(viewportData.endLineNumber, 7);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 7);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 7);
        assertDeepEquals(viewportData.relativeVerticalOffset, [160]);


        // viewport 160->1000
        viewportData = linesLayout.getLinesViewportData(160, 1000);
        assertEquals(viewportData.startLineNumber, 7);
        assertEquals(viewportData.endLineNumber, 10);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 7);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 10);
        assertDeepEquals(viewportData.relativeVerticalOffset, [160, 170, 180, 190]);
    }

    // test('LinesLayout getLinesViewportData 2 & getWhitespaceViewportData')
    function testLinesLayoutGetLinesViewportData2GetWhitespaceViewportData() {
        final linesLayout = new LinesLayout(10, 10, 0, 0);
        final a = insertWhitespace(linesLayout, 6, 0, 100, 0);
        final b = insertWhitespace(linesLayout, 7, 0, 50, 0);

        // 10 lines
        // whitespace: - a(6,100), b(7, 50)
        assertEquals(linesLayout.getLinesTotalHeight(), 250);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(1), 0);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(2), 10);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(3), 20);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(4), 30);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(5), 40);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(6), 50);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(7), 160);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(8), 220);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(9), 230);
        assertEquals(linesLayout.getVerticalOffsetForLineNumber(10), 240);

        // viewport 50->160
        var viewportData = linesLayout.getLinesViewportData(50, 160);
        assertEquals(viewportData.startLineNumber, 6);
        assertEquals(viewportData.endLineNumber, 6);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 6);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 6);
        assertDeepEquals(viewportData.relativeVerticalOffset, [50]);
        var whitespaceData = linesLayout.getWhitespaceViewportData(50, 160);
        assertDeepEquals(whitespaceData, [{
            id: a,
            afterLineNumber: 6,
            verticalOffset: 60,
            height: 100
        }]);

        // viewport 50->219
        viewportData = linesLayout.getLinesViewportData(50, 219);
        assertEquals(viewportData.startLineNumber, 6);
        assertEquals(viewportData.endLineNumber, 7);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 6);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 7);
        assertDeepEquals(viewportData.relativeVerticalOffset, [50, 160]);
        whitespaceData = linesLayout.getWhitespaceViewportData(50, 219);
        assertDeepEquals(whitespaceData, [{
            id: a,
            afterLineNumber: 6,
            verticalOffset: 60,
            height: 100
        }, {
            id: b,
            afterLineNumber: 7,
            verticalOffset: 170,
            height: 50
        }]);

        // viewport 50->220
        viewportData = linesLayout.getLinesViewportData(50, 220);
        assertEquals(viewportData.startLineNumber, 6);
        assertEquals(viewportData.endLineNumber, 7);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 6);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 7);
        assertDeepEquals(viewportData.relativeVerticalOffset, [50, 160]);

        // viewport 50->250
        viewportData = linesLayout.getLinesViewportData(50, 250);
        assertEquals(viewportData.startLineNumber, 6);
        assertEquals(viewportData.endLineNumber, 10);
        assertEquals(viewportData.completelyVisibleStartLineNumber, 6);
        assertEquals(viewportData.completelyVisibleEndLineNumber, 10);
        assertDeepEquals(viewportData.relativeVerticalOffset, [50, 160, 220, 230, 240]);
    }

    // test('LinesLayout getWhitespaceAtVerticalOffset')
    function testLinesLayoutGetWhitespaceAtVerticalOffset() {
        final linesLayout = new LinesLayout(10, 10, 0, 0);
        final a = insertWhitespace(linesLayout, 6, 0, 100, 0);
        final b = insertWhitespace(linesLayout, 7, 0, 50, 0);

        var whitespace = linesLayout.getWhitespaceAtVerticalOffset(0);
        assertEquals(whitespace, null);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(59);
        assertEquals(whitespace, null);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(60);
        assertEquals(whitespace.id, a);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(61);
        assertEquals(whitespace.id, a);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(159);
        assertEquals(whitespace.id, a);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(160);
        assertEquals(whitespace, null);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(161);
        assertEquals(whitespace, null);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(169);
        assertEquals(whitespace, null);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(170);
        assertEquals(whitespace.id, b);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(171);
        assertEquals(whitespace.id, b);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(219);
        assertEquals(whitespace.id, b);

        whitespace = linesLayout.getWhitespaceAtVerticalOffset(220);
        assertEquals(whitespace, null);
    }

    // test('LinesLayout')
    function testLinesLayout() {

        final linesLayout = new LinesLayout(100, 20, 0, 0);

        // Insert a whitespace after line number 2, of height 10
        final a = insertWhitespace(linesLayout, 2, 0, 10, 0);
        // whitespaces: a(2, 10)
        assertEquals(linesLayout.getWhitespacesCount(), 1);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 10);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 10);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 10);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 10);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 10);

        // Insert a whitespace again after line number 2, of height 20
        var b = insertWhitespace(linesLayout, 2, 0, 20, 0);
        // whitespaces: a(2, 10), b(2, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 2);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 10);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 10);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 30);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 30);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 30);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 30);

        // Change last inserted whitespace height to 30
        changeOneWhitespace(linesLayout, b, 2, 30);
        // whitespaces: a(2, 10), b(2, 30)
        assertEquals(linesLayout.getWhitespacesCount(), 2);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 10);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 30);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 10);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 40);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 40);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 40);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 40);

        // Remove last inserted whitespace
        removeWhitespace(linesLayout, b);
        // whitespaces: a(2, 10)
        assertEquals(linesLayout.getWhitespacesCount(), 1);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 10);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 10);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 10);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 10);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 10);

        // Add a whitespace before the first line of height 50
        b = insertWhitespace(linesLayout, 0, 0, 50, 0);
        // whitespaces: b(0, 50), a(2, 10)
        assertEquals(linesLayout.getWhitespacesCount(), 2);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 0);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 50);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 10);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 50);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 60);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 60);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 60);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 60);

        // Add a whitespace after line 4 of height 20
        insertWhitespace(linesLayout, 4, 0, 20, 0);
        // whitespaces: b(0, 50), a(2, 10), c(4, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 3);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 0);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 50);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 10);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 4);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(2), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 50);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 60);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(2), 80);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 80);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 60);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 60);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(5), 80);

        // Add a whitespace after line 3 of height 30
        insertWhitespace(linesLayout, 3, 0, 30, 0);
        // whitespaces: b(0, 50), a(2, 10), d(3, 30), c(4, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 4);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 0);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 50);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 10);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 3);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(2), 30);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(3), 4);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(3), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 50);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 60);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(2), 90);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(3), 110);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 110);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 60);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 90);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(5), 110);

        // Change whitespace after line 2 to height of 100
        changeOneWhitespace(linesLayout, a, 2, 100);
        // whitespaces: b(0, 50), a(2, 100), d(3, 30), c(4, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 4);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 0);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 50);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 100);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 3);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(2), 30);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(3), 4);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(3), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 50);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 150);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(2), 180);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(3), 200);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 200);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 150);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 180);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(5), 200);

        // Remove whitespace after line 2
        removeWhitespace(linesLayout, a);
        // whitespaces: b(0, 50), d(3, 30), c(4, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 3);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 0);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 50);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 3);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 30);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 4);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(2), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 50);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 80);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(2), 100);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 100);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 80);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(5), 100);

        // Remove whitespace before line 1
        removeWhitespace(linesLayout, b);
        // whitespaces: d(3, 30), c(4, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 2);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 3);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 30);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 4);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 30);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 50);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 30);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(5), 50);

        // Delete line 1
        linesLayout.onLinesDeleted(1, 1);
        // whitespaces: d(2, 30), c(3, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 2);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 2);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 30);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 3);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 30);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 50);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 30);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(5), 50);

        // Insert a line before line 1
        linesLayout.onLinesInserted(1, 1);
        // whitespaces: d(3, 30), c(4, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 2);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 3);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 30);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 4);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 30);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 50);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 30);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(5), 50);

        // Delete line 4
        linesLayout.onLinesDeleted(4, 4);
        // whitespaces: d(3, 30), c(3, 20)
        assertEquals(linesLayout.getWhitespacesCount(), 2);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 3);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(0), 30);
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 3);
        assertEquals(linesLayout.getHeightForWhitespaceIndex(1), 20);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(0), 30);
        assertEquals(linesLayout.getWhitespacesAccumulatedHeight(1), 50);
        assertEquals(linesLayout.getWhitespacesTotalHeight(), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(1), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(2), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(3), 0);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(4), 50);
        assertEquals(linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(5), 50);
    }

    // test('LinesLayout findInsertionIndex')
    function testLinesLayoutFindInsertionIndex() {

        final makeInternalWhitespace = function(afterLineNumbers:Array<Int>, ordinal:Int = 0) {
            return afterLineNumbers.map((afterLineNumber) -> new EditorWhitespace('', afterLineNumber, ordinal, 0, 0));
        };

        var arr;

        arr = makeInternalWhitespace([]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 0);

        arr = makeInternalWhitespace([1]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);

        arr = makeInternalWhitespace([1, 3]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 3, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 4, 0), 2);

        arr = makeInternalWhitespace([1, 3, 5]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 3, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 4, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 5, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 6, 0), 3);

        arr = makeInternalWhitespace([1, 3, 5], 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 3, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 4, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 5, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 6, 0), 3);

        arr = makeInternalWhitespace([1, 3, 5, 7]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 3, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 4, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 5, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 6, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 7, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 8, 0), 4);

        arr = makeInternalWhitespace([1, 3, 5, 7, 9]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 3, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 4, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 5, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 6, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 7, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 8, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 9, 0), 5);
        assertEquals(LinesLayout.findInsertionIndex(arr, 10, 0), 5);

        arr = makeInternalWhitespace([1, 3, 5, 7, 9, 11]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 3, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 4, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 5, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 6, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 7, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 8, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 9, 0), 5);
        assertEquals(LinesLayout.findInsertionIndex(arr, 10, 0), 5);
        assertEquals(LinesLayout.findInsertionIndex(arr, 11, 0), 6);
        assertEquals(LinesLayout.findInsertionIndex(arr, 12, 0), 6);

        arr = makeInternalWhitespace([1, 3, 5, 7, 9, 11, 13]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 3, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 4, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 5, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 6, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 7, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 8, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 9, 0), 5);
        assertEquals(LinesLayout.findInsertionIndex(arr, 10, 0), 5);
        assertEquals(LinesLayout.findInsertionIndex(arr, 11, 0), 6);
        assertEquals(LinesLayout.findInsertionIndex(arr, 12, 0), 6);
        assertEquals(LinesLayout.findInsertionIndex(arr, 13, 0), 7);
        assertEquals(LinesLayout.findInsertionIndex(arr, 14, 0), 7);

        arr = makeInternalWhitespace([1, 3, 5, 7, 9, 11, 13, 15]);
        assertEquals(LinesLayout.findInsertionIndex(arr, 0, 0), 0);
        assertEquals(LinesLayout.findInsertionIndex(arr, 1, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 2, 0), 1);
        assertEquals(LinesLayout.findInsertionIndex(arr, 3, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 4, 0), 2);
        assertEquals(LinesLayout.findInsertionIndex(arr, 5, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 6, 0), 3);
        assertEquals(LinesLayout.findInsertionIndex(arr, 7, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 8, 0), 4);
        assertEquals(LinesLayout.findInsertionIndex(arr, 9, 0), 5);
        assertEquals(LinesLayout.findInsertionIndex(arr, 10, 0), 5);
        assertEquals(LinesLayout.findInsertionIndex(arr, 11, 0), 6);
        assertEquals(LinesLayout.findInsertionIndex(arr, 12, 0), 6);
        assertEquals(LinesLayout.findInsertionIndex(arr, 13, 0), 7);
        assertEquals(LinesLayout.findInsertionIndex(arr, 14, 0), 7);
        assertEquals(LinesLayout.findInsertionIndex(arr, 15, 0), 8);
        assertEquals(LinesLayout.findInsertionIndex(arr, 16, 0), 8);
    }

    // test('LinesLayout changeWhitespaceAfterLineNumber & getFirstWhitespaceIndexAfterLineNumber')
    function testLinesLayoutChangeWhitespaceAfterLineNumberGetFirstWhitespaceIndexAfterLineNumber() {
        final linesLayout = new LinesLayout(100, 20, 0, 0);

        final a = insertWhitespace(linesLayout, 0, 0, 1, 0);
        final b = insertWhitespace(linesLayout, 7, 0, 1, 0);
        final c = insertWhitespace(linesLayout, 3, 0, 1, 0);

        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 0
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 0);
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), c); // 3
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 3);
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), b); // 7
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 7);

        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(1), 1); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(2), 1); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(3), 1); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(4), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(5), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(6), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(7), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(8), -1); // --

        // Do not really move a
        changeOneWhitespace(linesLayout, a, 1, 1);

        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 1
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 1);
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), c); // 3
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 3);
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), b); // 7
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 7);

        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(1), 0); // a
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(2), 1); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(3), 1); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(4), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(5), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(6), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(7), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(8), -1); // --


        // Do not really move a
        changeOneWhitespace(linesLayout, a, 2, 1);

        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 2
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 2);
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), c); // 3
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 3);
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), b); // 7
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 7);

        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(1), 0); // a
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(2), 0); // a
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(3), 1); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(4), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(5), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(6), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(7), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(8), -1); // --


        // Change a to conflict with c -> a gets placed after c
        changeOneWhitespace(linesLayout, a, 3, 1);

        assertEquals(linesLayout.getIdForWhitespaceIndex(0), c); // 3
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 3);
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), a); // 3
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 3);
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), b); // 7
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 7);

        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(1), 0); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(2), 0); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(3), 0); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(4), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(5), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(6), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(7), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(8), -1); // --


        // Make a no-op
        changeOneWhitespace(linesLayout, c, 3, 1);

        assertEquals(linesLayout.getIdForWhitespaceIndex(0), c); // 3
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 3);
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), a); // 3
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 3);
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), b); // 7
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 7);

        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(1), 0); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(2), 0); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(3), 0); // c
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(4), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(5), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(6), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(7), 2); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(8), -1); // --



        // Conflict c with b -> c gets placed after b
        changeOneWhitespace(linesLayout, c, 7, 1);

        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 3
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(0), 3);
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), b); // 7
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(1), 7);
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), c); // 7
        assertEquals(linesLayout.getAfterLineNumberForWhitespaceIndex(2), 7);

        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(1), 0); // a
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(2), 0); // a
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(3), 0); // a
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(4), 1); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(5), 1); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(6), 1); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(7), 1); // b
        assertEquals(linesLayout.getFirstWhitespaceIndexAfterLineNumber(8), -1); // --
    }

    // test('LinesLayout Bug')
    function testLinesLayoutBug() {
        final linesLayout = new LinesLayout(100, 20, 0, 0);

        final a = insertWhitespace(linesLayout, 0, 0, 1, 0);
        final b = insertWhitespace(linesLayout, 7, 0, 1, 0);

        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 0
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), b); // 7

        final c = insertWhitespace(linesLayout, 3, 0, 1, 0);

        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 0
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), c); // 3
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), b); // 7

        final d = insertWhitespace(linesLayout, 2, 0, 1, 0);
        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 0
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), d); // 2
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), c); // 3
        assertEquals(linesLayout.getIdForWhitespaceIndex(3), b); // 7

        final e = insertWhitespace(linesLayout, 8, 0, 1, 0);
        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 0
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), d); // 2
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), c); // 3
        assertEquals(linesLayout.getIdForWhitespaceIndex(3), b); // 7
        assertEquals(linesLayout.getIdForWhitespaceIndex(4), e); // 8

        final f = insertWhitespace(linesLayout, 11, 0, 1, 0);
        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 0
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), d); // 2
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), c); // 3
        assertEquals(linesLayout.getIdForWhitespaceIndex(3), b); // 7
        assertEquals(linesLayout.getIdForWhitespaceIndex(4), e); // 8
        assertEquals(linesLayout.getIdForWhitespaceIndex(5), f); // 11

        final g = insertWhitespace(linesLayout, 10, 0, 1, 0);
        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 0
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), d); // 2
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), c); // 3
        assertEquals(linesLayout.getIdForWhitespaceIndex(3), b); // 7
        assertEquals(linesLayout.getIdForWhitespaceIndex(4), e); // 8
        assertEquals(linesLayout.getIdForWhitespaceIndex(5), g); // 10
        assertEquals(linesLayout.getIdForWhitespaceIndex(6), f); // 11

        final h = insertWhitespace(linesLayout, 0, 0, 1, 0);
        assertEquals(linesLayout.getIdForWhitespaceIndex(0), a); // 0
        assertEquals(linesLayout.getIdForWhitespaceIndex(1), h); // 0
        assertEquals(linesLayout.getIdForWhitespaceIndex(2), d); // 2
        assertEquals(linesLayout.getIdForWhitespaceIndex(3), c); // 3
        assertEquals(linesLayout.getIdForWhitespaceIndex(4), b); // 7
        assertEquals(linesLayout.getIdForWhitespaceIndex(5), e); // 8
        assertEquals(linesLayout.getIdForWhitespaceIndex(6), g); // 10
        assertEquals(linesLayout.getIdForWhitespaceIndex(7), f); // 11
    }

}

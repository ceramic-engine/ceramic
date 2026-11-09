// Ported from vscode src/vs/editor/test/common/core/range.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.core;

import cityscape.common.core.Position;
import cityscape.common.core.Range;
import testing.TestCase;

/**
 * suite('Editor Core - Range')
 */
class RangeTest extends TestCase {

    function testEmptyRange() {
        final s = new Range(1, 1, 1, 1);
        assertEquals(s.startLineNumber, 1);
        assertEquals(s.startColumn, 1);
        assertEquals(s.endLineNumber, 1);
        assertEquals(s.endColumn, 1);
        assertEquals(s.isEmpty(), true);
    }

    function testSwapStartAndStopSameLine() {
        final s = new Range(1, 2, 1, 1);
        assertEquals(s.startLineNumber, 1);
        assertEquals(s.startColumn, 1);
        assertEquals(s.endLineNumber, 1);
        assertEquals(s.endColumn, 2);
        assertEquals(s.isEmpty(), false);
    }

    function testSwapStartAndStop() {
        final s = new Range(2, 1, 1, 2);
        assertEquals(s.startLineNumber, 1);
        assertEquals(s.startColumn, 2);
        assertEquals(s.endLineNumber, 2);
        assertEquals(s.endColumn, 1);
        assertEquals(s.isEmpty(), false);
    }

    function testNoSwapSameLine() {
        final s = new Range(1, 1, 1, 2);
        assertEquals(s.startLineNumber, 1);
        assertEquals(s.startColumn, 1);
        assertEquals(s.endLineNumber, 1);
        assertEquals(s.endColumn, 2);
        assertEquals(s.isEmpty(), false);
    }

    function testNoSwap() {
        final s = new Range(1, 1, 2, 1);
        assertEquals(s.startLineNumber, 1);
        assertEquals(s.startColumn, 1);
        assertEquals(s.endLineNumber, 2);
        assertEquals(s.endColumn, 1);
        assertEquals(s.isEmpty(), false);
    }

    function testCompareRangesUsingEnds() {
        var a:Range, b:Range;

        a = new Range(1, 1, 1, 3);
        b = new Range(1, 2, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) < 0, 'a.start < b.start, a.end < b.end');

        a = new Range(1, 1, 1, 3);
        b = new Range(1, 1, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) < 0, 'a.start = b.start, a.end < b.end');

        a = new Range(1, 2, 1, 3);
        b = new Range(1, 1, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) < 0, 'a.start > b.start, a.end < b.end');

        a = new Range(1, 1, 1, 4);
        b = new Range(1, 2, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) < 0, 'a.start < b.start, a.end = b.end');

        a = new Range(1, 1, 1, 4);
        b = new Range(1, 1, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) == 0, 'a.start = b.start, a.end = b.end');

        a = new Range(1, 2, 1, 4);
        b = new Range(1, 1, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) > 0, 'a.start > b.start, a.end = b.end');

        a = new Range(1, 1, 1, 5);
        b = new Range(1, 2, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) > 0, 'a.start < b.start, a.end > b.end');

        a = new Range(1, 1, 2, 4);
        b = new Range(1, 1, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) > 0, 'a.start = b.start, a.end > b.end');

        a = new Range(1, 2, 5, 1);
        b = new Range(1, 1, 1, 4);
        assertTrue(Range.compareRangesUsingEnds(a, b) > 0, 'a.start > b.start, a.end > b.end');
    }

    function testContainsPosition() {
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(1, 3)), false);
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(2, 1)), false);
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(2, 2)), true);
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(2, 3)), true);
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(3, 1)), true);
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(5, 9)), true);
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(5, 10)), true);
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(5, 11)), false);
        assertEquals(new Range(2, 2, 5, 10).containsPosition(new Position(6, 1)), false);
    }

    function testContainsRange() {
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(1, 3, 2, 2)), false);
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(2, 1, 2, 2)), false);
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(2, 2, 5, 11)), false);
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(2, 2, 6, 1)), false);
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(5, 9, 6, 1)), false);
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(5, 10, 6, 1)), false);
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(2, 2, 5, 10)), true);
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(2, 3, 5, 9)), true);
        assertEquals(new Range(2, 2, 5, 10).containsRange(new Range(3, 100, 4, 100)), true);
    }

    function testAreIntersecting() {
        assertEquals(Range.areIntersecting(new Range(2, 2, 3, 2), new Range(4, 2, 5, 2)), false);
        assertEquals(Range.areIntersecting(new Range(4, 2, 5, 2), new Range(2, 2, 3, 2)), false);
        assertEquals(Range.areIntersecting(new Range(4, 2, 5, 2), new Range(5, 2, 6, 2)), false);
        assertEquals(Range.areIntersecting(new Range(5, 2, 6, 2), new Range(4, 2, 5, 2)), false);
        assertEquals(Range.areIntersecting(new Range(2, 2, 2, 7), new Range(2, 4, 2, 6)), true);
        assertEquals(Range.areIntersecting(new Range(2, 2, 2, 7), new Range(2, 4, 2, 9)), true);
        assertEquals(Range.areIntersecting(new Range(2, 4, 2, 9), new Range(2, 2, 2, 7)), true);
    }

}

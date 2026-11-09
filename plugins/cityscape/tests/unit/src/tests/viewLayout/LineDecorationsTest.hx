// Ported from vscode src/vs/editor/test/common/viewLayout/lineDecorations.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.viewLayout;

import cityscape.common.ViewModel.InlineDecoration;
import cityscape.common.ViewModel.InlineDecorationType;
import cityscape.common.core.Range;
import cityscape.common.viewLayout.LineDecorations;
import testing.TestCase;

/**
 * suite('Editor ViewLayout - ViewLineParts')
 */
class LineDecorationsTest extends TestCase {

    // test('Bug 9827:Overlapping inline decorations can cause wrong inline class to be applied')
    function testBug9827OverlappingInlineDecorationsCanCauseWrongInlineClassToBeApplied() {

        final result = LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(1, 11, 'c1', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2', InlineDecorationType.Regular)
        ]);

        assertDeepEquals(result, [
            new DecorationSegment(0, 1, 'c1', 0),
            new DecorationSegment(2, 2, 'c2 c1', 0),
            new DecorationSegment(3, 9, 'c1', 0),
        ]);
    }

    // test('issue #3462: no whitespace shown at the end of a decorated line')
    function testIssue3462NoWhitespaceShownAtTheEndOfADecoratedLine() {

        final result = LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(15, 21, 'mtkw', InlineDecorationType.Regular),
            new LineDecoration(20, 21, 'inline-folded', InlineDecorationType.Regular),
        ]);

        assertDeepEquals(result, [
            new DecorationSegment(14, 18, 'mtkw', 0),
            new DecorationSegment(19, 19, 'mtkw inline-folded', 0)
        ]);
    }

    // test('issue #3661: Link decoration bleeds to next line when wrapping')
    function testIssue3661LinkDecorationBleedsToNextLineWhenWrapping() {

        final result = LineDecoration.filter([
            new InlineDecoration(new Range(2, 12, 3, 30), 'detected-link', InlineDecorationType.Regular)
        ], 3, 12, 500);

        assertDeepEquals(result, [
            new LineDecoration(12, 30, 'detected-link', InlineDecorationType.Regular),
        ]);
    }

    // test('issue #37401: Allow both before and after decorations on empty line')
    function testIssue37401AllowBothBeforeAndAfterDecorationsOnEmptyLine() {
        final result = LineDecoration.filter([
            new InlineDecoration(new Range(4, 1, 4, 2), 'before', InlineDecorationType.Before),
            new InlineDecoration(new Range(4, 0, 4, 1), 'after', InlineDecorationType.After),
        ], 4, 1, 500);

        assertDeepEquals(result, [
            new LineDecoration(1, 2, 'before', InlineDecorationType.Before),
            new LineDecoration(0, 1, 'after', InlineDecorationType.After),
        ]);
    }

    // test('ViewLineParts')
    function testViewLineParts() {

        assertDeepEquals(LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(1, 2, 'c1', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2', InlineDecorationType.Regular)
        ]), [
            new DecorationSegment(0, 0, 'c1', 0),
            new DecorationSegment(2, 2, 'c2', 0)
        ]);

        assertDeepEquals(LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(1, 3, 'c1', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2', InlineDecorationType.Regular)
        ]), [
            new DecorationSegment(0, 1, 'c1', 0),
            new DecorationSegment(2, 2, 'c2', 0)
        ]);

        assertDeepEquals(LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(1, 4, 'c1', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2', InlineDecorationType.Regular)
        ]), [
            new DecorationSegment(0, 1, 'c1', 0),
            new DecorationSegment(2, 2, 'c1 c2', 0)
        ]);

        assertDeepEquals(LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(1, 4, 'c1', InlineDecorationType.Regular),
            new LineDecoration(1, 4, 'c1*', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2', InlineDecorationType.Regular)
        ]), [
            new DecorationSegment(0, 1, 'c1 c1*', 0),
            new DecorationSegment(2, 2, 'c1 c1* c2', 0)
        ]);

        assertDeepEquals(LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(1, 4, 'c1', InlineDecorationType.Regular),
            new LineDecoration(1, 4, 'c1*', InlineDecorationType.Regular),
            new LineDecoration(1, 4, 'c1**', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2', InlineDecorationType.Regular)
        ]), [
            new DecorationSegment(0, 1, 'c1 c1* c1**', 0),
            new DecorationSegment(2, 2, 'c1 c1* c1** c2', 0)
        ]);

        assertDeepEquals(LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(1, 4, 'c1', InlineDecorationType.Regular),
            new LineDecoration(1, 4, 'c1*', InlineDecorationType.Regular),
            new LineDecoration(1, 4, 'c1**', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2*', InlineDecorationType.Regular)
        ]), [
            new DecorationSegment(0, 1, 'c1 c1* c1**', 0),
            new DecorationSegment(2, 2, 'c1 c1* c1** c2 c2*', 0)
        ]);

        assertDeepEquals(LineDecorationsNormalizer.normalize('abcabcabcabcabcabcabcabcabcabc', [
            new LineDecoration(1, 4, 'c1', InlineDecorationType.Regular),
            new LineDecoration(1, 4, 'c1*', InlineDecorationType.Regular),
            new LineDecoration(1, 4, 'c1**', InlineDecorationType.Regular),
            new LineDecoration(3, 4, 'c2', InlineDecorationType.Regular),
            new LineDecoration(3, 5, 'c2*', InlineDecorationType.Regular)
        ]), [
            new DecorationSegment(0, 1, 'c1 c1* c1**', 0),
            new DecorationSegment(2, 2, 'c1 c1* c1** c2 c2*', 0),
            new DecorationSegment(3, 3, 'c2*', 0)
        ]);
    }

}

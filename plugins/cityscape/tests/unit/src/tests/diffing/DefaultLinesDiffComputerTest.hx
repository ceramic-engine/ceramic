// Ported from vscode src/vs/editor/test/node/diffing/defaultLinesDiffComputer.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.diffing;

import cityscape.common.core.OffsetRange;
import cityscape.common.core.Range;
import cityscape.common.diff.RangeMapping.LineRangeMapping;
import cityscape.common.diff.RangeMapping.RangeMapping;
import cityscape.common.diff.defaultLinesDiffComputer.DefaultLinesDiffComputer;
import cityscape.common.diff.defaultLinesDiffComputer.LinesSliceCharSequence;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DynamicProgrammingDiffing;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.MyersDiffAlgorithm;
import testing.TestCase;

/**
 * vscode's suite 'myers'.
 */
class MyersTest extends TestCase {

    function test1():Void {
        final s1 = new LinesSliceCharSequence(['hello world'], new Range(1, 1, 1, LineRangeMapping.MAX_COLUMN), true);
        final s2 = new LinesSliceCharSequence(['hallo welt'], new Range(1, 1, 1, LineRangeMapping.MAX_COLUMN), true);

        final a = true ? new MyersDiffAlgorithm() : null;
        a.compute(s1, s2);
        // vscode's test only checks that it runs
        assertTrue(true);
        final b = new DynamicProgrammingDiffing();
        b.compute(s1, s2);
    }

}

/**
 * vscode's suite 'lineRangeMapping'.
 */
class LineRangeMappingTest extends TestCase {

    function testSimple():Void {
        assertEquals(
            "{[2,3)->[2,2)}",
            DefaultLinesDiffComputer.getLineRangeMapping(
                new RangeMapping(
                    new Range(2, 1, 3, 1),
                    new Range(2, 1, 2, 1)
                ),
                [
                    'const abc = "helloworld".split("");',
                    '',
                    ''
                ],
                [
                    'const asciiLower = "helloworld".split("");',
                    ''
                ]
            ).toString()
        );
    }

    function testEmptyLines():Void {
        assertEquals(
            "{[2,2)->[2,4)}",
            DefaultLinesDiffComputer.getLineRangeMapping(
                new RangeMapping(
                    new Range(2, 1, 2, 1),
                    new Range(2, 1, 4, 1)
                ),
                [
                    '',
                    '',
                ],
                [
                    '',
                    '',
                    '',
                    '',
                ]
            ).toString()
        );
    }

}

/**
 * vscode's suite 'LinesSliceCharSequence'.
 */
class LinesSliceCharSequenceTest extends TestCase {

    final sequence = new LinesSliceCharSequence(
        [
            'line1: foo',
            'line2: fizzbuzz',
            'line3: barr',
            'line4: hello world',
            'line5: bazz',
        ],
        new Range(2, 1, 5, 1), true
    );

    function testTranslateOffset():Void {
        final result = [for (offset in 0...sequence.length) sequence.translateOffset(offset).toString()];
        assertDeepEquals(
            [
                "(2,1)", "(2,2)", "(2,3)", "(2,4)", "(2,5)", "(2,6)", "(2,7)", "(2,8)", "(2,9)", "(2,10)", "(2,11)",
                "(2,12)", "(2,13)", "(2,14)", "(2,15)", "(2,16)",

                "(3,1)", "(3,2)", "(3,3)", "(3,4)", "(3,5)", "(3,6)", "(3,7)", "(3,8)", "(3,9)", "(3,10)", "(3,11)", "(3,12)",

                "(4,1)", "(4,2)", "(4,3)", "(4,4)", "(4,5)", "(4,6)", "(4,7)", "(4,8)", "(4,9)",
                "(4,10)", "(4,11)", "(4,12)", "(4,13)", "(4,14)", "(4,15)", "(4,16)", "(4,17)",
                "(4,18)", "(4,19)"
            ],
            result
        );
    }

    function testExtendToFullLines():Void {
        assertEquals(
            "line3: barr\n",
            sequence.getText(sequence.extendToFullLines(new OffsetRange(20, 25)))
        );

        assertEquals(
            "line3: barr\nline4: hello world\n",
            sequence.getText(sequence.extendToFullLines(new OffsetRange(20, 45)))
        );
    }

}

// Ported from vscode src/vs/editor/contrib/folding/test/browser/indentFold.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.folding;

import cityscape.contrib.folding.view.IndentRangeProvider;
import testing.TestCase;
import tests.TestTextModel.createTextModel;
import tests.contrib.folding.FoldingRangesTest.TestLimitReporter;

typedef IndentRange = {
    var start:Int;
    var end:Int;
}

/**
 * Suite 'Indentation Folding' of indentFold.test.ts.
 */
class IndentFoldTest extends TestCase {

    static function r(start:Int, end:Int):IndentRange {
        return {start: start, end: end};
    }

    function testLimitByIndent() {

        final lines = [
        /* 1*/ 'A',
        /* 2*/ '  A',
        /* 3*/ '  A',
        /* 4*/ '    A',
        /* 5*/ '      A',
        /* 6*/ '    A',
        /* 7*/ '      A',
        /* 8*/ '      A',
        /* 9*/ '         A',
        /* 10*/ '      A',
        /* 11*/ '         A',
        /* 12*/ '  A',
        /* 13*/ '              A',
        /* 14*/ '                 A',
        /* 15*/ 'A',
        /* 16*/ '  A'
        ];
        final r1 = r(1, 14); //0
        final r2 = r(3, 11); //1
        final r3 = r(4, 5); //2
        final r4 = r(6, 11); //2
        final r5 = r(8, 9); //3
        final r6 = r(10, 11); //3
        final r7 = r(12, 14); //1
        final r8 = r(13, 14);//4
        final r9 = r(15, 16);//0

        final model = createTextModel(lines.join('\n'));

        function assertLimit(maxEntries:Int, expectedRanges:Array<IndentRange>, message:String, ?pos:haxe.PosInfos):Void {
            var reported:Null<Int> = null;
            final indentRanges = IndentRangeProviderUtils.computeRanges(model, true, null, new TestLimitReporter(maxEntries, (computed, limited) -> reported = limited));
            assertTrue(indentRanges.length <= maxEntries, 'max ' + message, pos);
            final actual:Array<IndentRange> = [];
            for (i in 0...indentRanges.length) {
                actual.push({start: indentRanges.getStartLineNumber(i), end: indentRanges.getEndLineNumber(i)});
            }
            assertDeepEquals(expectedRanges, actual, message, pos);
            // Monaco's `false` is null
            assertEquals(9 <= maxEntries ? null : maxEntries, reported, 'limited', pos);
        }

        assertLimit(1000, [r1, r2, r3, r4, r5, r6, r7, r8, r9], '1000');
        assertLimit(9, [r1, r2, r3, r4, r5, r6, r7, r8, r9], '9');
        assertLimit(8, [r1, r2, r3, r4, r5, r6, r7, r9], '8');
        assertLimit(7, [r1, r2, r3, r4, r5, r7, r9], '7');
        assertLimit(6, [r1, r2, r3, r4, r7, r9], '6');
        assertLimit(5, [r1, r2, r3, r7, r9], '5');
        assertLimit(4, [r1, r2, r7, r9], '4');
        assertLimit(3, [r1, r2, r9], '3');
        assertLimit(2, [r1, r9], '2');
        assertLimit(1, [r1], '1');
        assertLimit(0, [], '0');

        model.dispose();
    }

}

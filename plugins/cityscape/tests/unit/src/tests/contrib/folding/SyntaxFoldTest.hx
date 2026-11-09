// Ported from vscode src/vs/editor/contrib/folding/test/browser/syntaxFold.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.folding;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Event;
import cityscape.common.Languages.FoldingContext;
import cityscape.common.Languages.FoldingRange;
import cityscape.common.Languages.FoldingRangeProvider;
import cityscape.common.Model.ITextModel;
import cityscape.contrib.folding.view.FoldingRanges.FoldingRegions;
import cityscape.contrib.folding.view.SyntaxRangeProvider;
import testing.TestCase;
import tests.TestTextModel.createTextModel;
import tests.contrib.folding.FoldingRangesTest.TestLimitReporter;
import tests.contrib.folding.IndentFoldTest.IndentRange;

class TestFoldingRangeProvider implements FoldingRangeProvider {

    public var id(default, null):Null<String> = null;
    public var onDidChange(default, null):Null<Event<FoldingRangeProvider>> = null;

    final model:ITextModel;
    final ranges:Array<IndentRange>;

    public function new(model:ITextModel, ranges:Array<IndentRange>) {
        this.model = model;
        this.ranges = ranges;
    }

    public function provideFoldingRanges(model:ITextModel, context:FoldingContext, token:CancellationToken, resolve:(ranges:Null<Array<FoldingRange>>) -> Void):Void {
        if (model == this.model) {
            resolve([for (r in ranges) {start: r.start, end: r.end}]);
            return;
        }
        resolve(null);
    }
}

/**
 * Suite 'Syntax folding'. The providers answer synchronously, so the
 * `await`ed computations complete at once.
 */
class SyntaxFoldTest extends TestCase {

    static function r(start:Int, end:Int):IndentRange {
        return {start: start, end: end};
    }

    function testLimitByNestingLevel() {
        final lines = [
            /* 1*/ '{',
            /* 2*/ '  A',
            /* 3*/ '  {',
            /* 4*/ '    {',
            /* 5*/ '      B',
            /* 6*/ '    }',
            /* 7*/ '    {',
            /* 8*/ '      A',
            /* 9*/ '      {',
            /* 10*/ '         A',
            /* 11*/ '      }',
            /* 12*/ '      {',
            /* 13*/ '        {',
            /* 14*/ '          {',
            /* 15*/ '             A',
            /* 16*/ '          }',
            /* 17*/ '        }',
            /* 18*/ '      }',
            /* 19*/ '    }',
            /* 20*/ '  }',
            /* 21*/ '}',
            /* 22*/ '{',
            /* 23*/ '  A',
            /* 24*/ '}',
        ];

        final r1 = r(1, 20); //0
        final r2 = r(3, 19); //1
        final r3 = r(4, 5); //2
        final r4 = r(7, 18); //2
        final r5 = r(9, 10); //3
        final r6 = r(12, 17); //4
        final r7 = r(13, 16); //5
        final r8 = r(14, 15); //6
        final r9 = r(22, 23); //0

        final model = createTextModel(lines.join('\n'));
        final ranges = [r1, r2, r3, r4, r5, r6, r7, r8, r9];
        final providers:Array<FoldingRangeProvider> = [new TestFoldingRangeProvider(model, ranges)];

        function assertLimit(maxEntries:Int, expectedRanges:Array<IndentRange>, message:String, ?pos:haxe.PosInfos):Void {
            var reported:Null<Int> = null;
            final foldingRangesLimit = new TestLimitReporter(maxEntries, (computed, limited) -> reported = limited);
            final syntaxRangeProvider = new SyntaxRangeProvider(model, providers, () -> {}, foldingRangesLimit, null);
            var computed = false;
            syntaxRangeProvider.compute(CancellationTokens.None, (indentRanges:Null<FoldingRegions>) -> {
                computed = true;
                final actual:Array<IndentRange> = [];
                if (indentRanges != null) {
                    for (i in 0...indentRanges.length) {
                        actual.push({start: indentRanges.getStartLineNumber(i), end: indentRanges.getEndLineNumber(i)});
                    }
                    assertEquals(9 <= maxEntries ? null : maxEntries, reported, 'limited', pos);
                }
                assertDeepEquals(expectedRanges, actual, message, pos);
            });
            assertTrue(computed, 'computed ' + message, pos);
            syntaxRangeProvider.dispose();
        }

        assertLimit(1000, [r1, r2, r3, r4, r5, r6, r7, r8, r9], '1000');
        assertLimit(9, [r1, r2, r3, r4, r5, r6, r7, r8, r9], '9');
        assertLimit(8, [r1, r2, r3, r4, r5, r6, r7, r9], '8');
        assertLimit(7, [r1, r2, r3, r4, r5, r6, r9], '7');
        assertLimit(6, [r1, r2, r3, r4, r5, r9], '6');
        assertLimit(5, [r1, r2, r3, r4, r9], '5');
        assertLimit(4, [r1, r2, r3, r9], '4');
        assertLimit(3, [r1, r2, r9], '3');
        assertLimit(2, [r1, r9], '2');
        assertLimit(1, [r1], '1');
        assertLimit(0, [], '0');

        model.dispose();
    }
}

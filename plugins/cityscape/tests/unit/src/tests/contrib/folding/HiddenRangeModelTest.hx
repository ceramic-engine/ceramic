// Ported from vscode src/vs/editor/contrib/folding/test/browser/hiddenRangeModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.folding;

import cityscape.common.core.Range;
import cityscape.contrib.folding.view.FoldingModel;
import cityscape.contrib.folding.view.HiddenRangeModel;
import cityscape.contrib.folding.view.IndentRangeProvider;
import testing.TestCase;
import tests.TestTextModel.createTextModel;
import tests.contrib.folding.FoldingModelTest.TestDecorationProvider;

typedef ExpectedRange = {
    var startLineNumber:Int;
    var endLineNumber:Int;
}

/**
 * Suite 'Hidden Range Model'.
 */
class HiddenRangeModelTest extends TestCase {

    static function r(startLineNumber:Int, endLineNumber:Int):ExpectedRange {
        return {startLineNumber: startLineNumber, endLineNumber: endLineNumber};
    }

    function assertRanges(actual:Array<Range>, expectedRegions:Array<ExpectedRange>, ?message:String, ?pos:haxe.PosInfos):Void {
        assertDeepEquals(expectedRegions, [for (r in actual) {startLineNumber: r.startLineNumber, endLineNumber: r.endLineNumber}], message, pos);
    }

    function testHasRanges() {
        final lines = [
        /* 1*/ '/**',
        /* 2*/ ' * Comment',
        /* 3*/ ' */',
        /* 4*/ 'class A {',
        /* 5*/ '  void foo() {',
        /* 6*/ '    if (true) {',
        /* 7*/ '      //hello',
        /* 8*/ '    }',
        /* 9*/ '  }',
        /* 10*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final foldingModel = new FoldingModel(textModel, new TestDecorationProvider(textModel));
        final hiddenRangeModel = new HiddenRangeModel(foldingModel);
        assertEquals(false, hiddenRangeModel.hasRanges());

        final ranges = IndentRangeProviderUtils.computeRanges(textModel, false, null);
        foldingModel.update(ranges);

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(1), foldingModel.getRegionAtLine(6)]);
        assertRanges(hiddenRangeModel.hiddenRanges, [r(2, 3), r(7, 7)]);

        assertEquals(true, hiddenRangeModel.hasRanges());
        assertEquals(false, hiddenRangeModel.isHidden(1));
        assertEquals(true, hiddenRangeModel.isHidden(2));
        assertEquals(true, hiddenRangeModel.isHidden(3));
        assertEquals(false, hiddenRangeModel.isHidden(4));
        assertEquals(false, hiddenRangeModel.isHidden(5));
        assertEquals(false, hiddenRangeModel.isHidden(6));
        assertEquals(true, hiddenRangeModel.isHidden(7));
        assertEquals(false, hiddenRangeModel.isHidden(8));
        assertEquals(false, hiddenRangeModel.isHidden(9));
        assertEquals(false, hiddenRangeModel.isHidden(10));

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(4)]);
        assertRanges(hiddenRangeModel.hiddenRanges, [r(2, 3), r(5, 9)]);

        assertEquals(true, hiddenRangeModel.hasRanges());
        assertEquals(false, hiddenRangeModel.isHidden(1));
        assertEquals(true, hiddenRangeModel.isHidden(2));
        assertEquals(true, hiddenRangeModel.isHidden(3));
        assertEquals(false, hiddenRangeModel.isHidden(4));
        assertEquals(true, hiddenRangeModel.isHidden(5));
        assertEquals(true, hiddenRangeModel.isHidden(6));
        assertEquals(true, hiddenRangeModel.isHidden(7));
        assertEquals(true, hiddenRangeModel.isHidden(8));
        assertEquals(true, hiddenRangeModel.isHidden(9));
        assertEquals(false, hiddenRangeModel.isHidden(10));

        foldingModel.toggleCollapseState([foldingModel.getRegionAtLine(1), foldingModel.getRegionAtLine(6), foldingModel.getRegionAtLine(4)]);
        assertRanges(hiddenRangeModel.hiddenRanges, []);
        assertEquals(false, hiddenRangeModel.hasRanges());
        assertEquals(false, hiddenRangeModel.isHidden(1));
        assertEquals(false, hiddenRangeModel.isHidden(2));
        assertEquals(false, hiddenRangeModel.isHidden(3));
        assertEquals(false, hiddenRangeModel.isHidden(4));
        assertEquals(false, hiddenRangeModel.isHidden(5));
        assertEquals(false, hiddenRangeModel.isHidden(6));
        assertEquals(false, hiddenRangeModel.isHidden(7));
        assertEquals(false, hiddenRangeModel.isHidden(8));
        assertEquals(false, hiddenRangeModel.isHidden(9));
        assertEquals(false, hiddenRangeModel.isHidden(10));
        textModel.dispose();
        hiddenRangeModel.dispose();
    }
}

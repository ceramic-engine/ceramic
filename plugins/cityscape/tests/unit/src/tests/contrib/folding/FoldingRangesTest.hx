// Ported from vscode src/vs/editor/contrib/folding/test/browser/foldingRanges.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.folding;

import cityscape.base.common.RegExp;
import cityscape.common.languages.LanguageConfiguration.FoldingMarkers;
import cityscape.contrib.folding.view.FoldingRanges;
import cityscape.contrib.folding.view.IndentRangeProvider;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

/**
 * Suite 'FoldingRanges'.
 */
class FoldingRangesTest extends TestCase {

    static final markers:FoldingMarkers = {
        start: new RegExp('^#region$'),
        end: new RegExp('^#endregion$')
    };

    static function foldRange(from:Int, to:Int, ?collapsed:Bool, source:FoldSource = FoldSource.provider, ?type:String):FoldRange {
        return new FoldRange(from, to, type, collapsed == true, source);
    }

    function assertEqualRanges(range1:FoldRange, range2:FoldRange, msg:String, ?pos:haxe.PosInfos):Void {
        assertEquals(range1.startLineNumber, range2.startLineNumber, msg + ' start', pos);
        assertEquals(range1.endLineNumber, range2.endLineNumber, msg + ' end', pos);
        assertEquals(range1.type, range2.type, msg + ' type', pos);
        assertEquals(range1.isCollapsed, range2.isCollapsed, msg + ' collapsed', pos);
        assertEquals((range1.source : Int), (range2.source : Int), msg + ' source', pos);
    }

    function testMaxFoldingRegions() {
        final lines:Array<String> = [];
        final nRegions = FoldingRangesConstants.MAX_FOLDING_REGIONS;
        final collector = new RangesCollector(new TestLimitReporter(FoldingRangesConstants.MAX_FOLDING_REGIONS));
        for (i in 0...nRegions) {
            final startLineNumber = lines.length;
            lines.push('#region');
            final endLineNumber = lines.length;
            lines.push('#endregion');
            collector.insertFirst(startLineNumber, endLineNumber, 0);
        }
        final model = createTextModel(lines.join('\n'));
        final actual = collector.toIndentRanges(model);
        assertEquals(nRegions, actual.length, 'len');
        model.dispose();
    }

    function testFindRange() {
        final lines = [
        /* 1*/ '#region',
        /* 2*/ '#endregion',
        /* 3*/ 'class A {',
        /* 4*/ '  void foo() {',
        /* 5*/ '    if (true) {',
        /* 6*/ '        return;',
        /* 7*/ '    }',
        /* 8*/ '',
        /* 9*/ '    if (true) {',
        /* 10*/ '      return;',
        /* 11*/ '    }',
        /* 12*/ '  }',
        /* 13*/ '}'];

        final textModel = createTextModel(lines.join('\n'));
        final actual = IndentRangeProviderUtils.computeRanges(textModel, false, markers);
        // let r0 = r(1, 2);
        // let r1 = r(3, 12);
        // let r2 = r(4, 11);
        // let r3 = r(5, 6);
        // let r4 = r(9, 10);

        assertEquals(0, actual.findRange(1), '1');
        assertEquals(0, actual.findRange(2), '2');
        assertEquals(1, actual.findRange(3), '3');
        assertEquals(2, actual.findRange(4), '4');
        assertEquals(3, actual.findRange(5), '5');
        assertEquals(3, actual.findRange(6), '6');
        assertEquals(2, actual.findRange(7), '7');
        assertEquals(2, actual.findRange(8), '8');
        assertEquals(4, actual.findRange(9), '9');
        assertEquals(4, actual.findRange(10), '10');
        assertEquals(2, actual.findRange(11), '11');
        assertEquals(1, actual.findRange(12), '12');
        assertEquals(-1, actual.findRange(13), '13');
        textModel.dispose();
    }

    function testSetCollapsed() {
        final lines:Array<String> = [];
        final nRegions = 500;
        for (i in 0...nRegions) {
            lines.push('#region');
        }
        for (i in 0...nRegions) {
            lines.push('#endregion');
        }
        final model = createTextModel(lines.join('\n'));
        final actual = IndentRangeProviderUtils.computeRanges(model, false, markers);
        assertEquals(nRegions, actual.length, 'len');
        for (i in 0...nRegions) {
            actual.setCollapsed(i, i % 3 == 0);
        }
        for (i in 0...nRegions) {
            assertEquals(i % 3 == 0, actual.isCollapsed(i), 'line' + i);
        }
        model.dispose();
    }

    function testSanitizeAndMerge1() {
        final regionSet1:Array<FoldRange> = [
            foldRange(0, 100), // invalid, should be removed
            foldRange(1, 100, false, FoldSource.provider, 'A'), // valid
            foldRange(1, 100, false, FoldSource.provider, 'Z'), // invalid, duplicate start
            foldRange(10, 10, false), // invalid, should be removed
            foldRange(20, 80, false, FoldSource.provider, 'C1'), // valid inside 'B'
            foldRange(22, 80, true, FoldSource.provider, 'D1'), // valid inside 'C1'
            foldRange(90, 101), // invalid, should be removed
        ];
        final regionSet2:Array<FoldRange> = [
            foldRange(20, 80, true), // should merge with C1
            foldRange(18, 80, true), // invalid, out of order
            foldRange(21, 81, true, FoldSource.provider, 'Z'), // invalid, overlapping
            foldRange(22, 80, true, FoldSource.provider, 'D2'), // should merge with D1
        ];
        final result = FoldingRegions.sanitizeAndMerge(regionSet1, regionSet2, 100);
        assertEquals(3, result.length, 'result length1');
        assertEqualRanges(result[0], foldRange(1, 100, false, FoldSource.provider, 'A'), 'A1');
        assertEqualRanges(result[1], foldRange(20, 80, true, FoldSource.provider, 'C1'), 'C1');
        assertEqualRanges(result[2], foldRange(22, 80, true, FoldSource.provider, 'D1'), 'D1');
    }

    function testSanitizeAndMerge2() {
        final regionSet1:Array<FoldRange> = [
            foldRange(1, 100, false, FoldSource.provider, 'a1'), // valid
            foldRange(2, 100, false, FoldSource.provider, 'a2'), // valid
            foldRange(3, 19, false, FoldSource.provider, 'a3'), // valid
            foldRange(20, 71, false, FoldSource.provider, 'a4'), // overlaps b3
            foldRange(21, 29, false, FoldSource.provider, 'a5'), // valid
            foldRange(81, 91, false, FoldSource.provider, 'a6'), // overlaps b4
        ];
        final regionSet2:Array<FoldRange> = [
            foldRange(30, 39, true, FoldSource.provider, 'b1'), // valid, will be recovered
            foldRange(40, 49, true, FoldSource.userDefined, 'b2'), // valid
            foldRange(50, 100, true, FoldSource.userDefined, 'b3'), // overlaps a4
            foldRange(80, 90, true, FoldSource.userDefined, 'b4'), // overlaps a6
            foldRange(92, 100, true, FoldSource.userDefined, 'b5'), // valid
        ];
        final result = FoldingRegions.sanitizeAndMerge(regionSet1, regionSet2, 100);
        assertEquals(9, result.length, 'result length1');
        assertEqualRanges(result[0], foldRange(1, 100, false, FoldSource.provider, 'a1'), 'P1');
        assertEqualRanges(result[1], foldRange(2, 100, false, FoldSource.provider, 'a2'), 'P2');
        assertEqualRanges(result[2], foldRange(3, 19, false, FoldSource.provider, 'a3'), 'P3');
        assertEqualRanges(result[3], foldRange(21, 29, false, FoldSource.provider, 'a5'), 'P4');
        assertEqualRanges(result[4], foldRange(30, 39, true, FoldSource.recovered, 'b1'), 'P5');
        assertEqualRanges(result[5], foldRange(40, 49, true, FoldSource.userDefined, 'b2'), 'P6');
        assertEqualRanges(result[6], foldRange(50, 100, true, FoldSource.userDefined, 'b3'), 'P7');
        assertEqualRanges(result[7], foldRange(80, 90, true, FoldSource.userDefined, 'b4'), 'P8');
        assertEqualRanges(result[8], foldRange(92, 100, true, FoldSource.userDefined, 'b5'), 'P9');
    }

    function testSanitizeAndMerge3() {
        final regionSet1:Array<FoldRange> = [
            foldRange(1, 100, false, FoldSource.provider, 'a1'), // valid
            foldRange(10, 29, false, FoldSource.provider, 'a2'), // matches manual hidden
            foldRange(35, 39, true, FoldSource.recovered, 'a3'), // valid
        ];
        final regionSet2:Array<FoldRange> = [
            foldRange(10, 29, true, FoldSource.recovered, 'b1'), // matches a
            foldRange(20, 28, true, FoldSource.provider, 'b2'), // should remain
            foldRange(30, 39, true, FoldSource.recovered, 'b3'), // should remain
        ];
        final result = FoldingRegions.sanitizeAndMerge(regionSet1, regionSet2, 100);
        assertEquals(5, result.length, 'result length3');
        assertEqualRanges(result[0], foldRange(1, 100, false, FoldSource.provider, 'a1'), 'R1');
        assertEqualRanges(result[1], foldRange(10, 29, true, FoldSource.provider, 'a2'), 'R2');
        assertEqualRanges(result[2], foldRange(20, 28, true, FoldSource.recovered, 'b2'), 'R3');
        assertEqualRanges(result[3], foldRange(30, 39, true, FoldSource.recovered, 'b3'), 'R3');
        assertEqualRanges(result[4], foldRange(35, 39, true, FoldSource.recovered, 'a3'), 'R4');
    }

    function testSanitizeAndMerge4() {
        final regionSet1:Array<FoldRange> = [
            foldRange(1, 100, false, FoldSource.provider, 'a1'), // valid
        ];
        final regionSet2:Array<FoldRange> = [
            foldRange(20, 28, true, FoldSource.provider, 'b1'), // hidden
            foldRange(30, 38, true, FoldSource.provider, 'b2'), // hidden
        ];
        final result = FoldingRegions.sanitizeAndMerge(regionSet1, regionSet2, 100);
        assertEquals(3, result.length, 'result length4');
        assertEqualRanges(result[0], foldRange(1, 100, false, FoldSource.provider, 'a1'), 'R1');
        assertEqualRanges(result[1], foldRange(20, 28, true, FoldSource.recovered, 'b1'), 'R2');
        assertEqualRanges(result[2], foldRange(30, 38, true, FoldSource.recovered, 'b2'), 'R3');
    }

}

/**
 * The `{ limit, update }` literals of vscode's folding tests.
 */
class TestLimitReporter implements cityscape.contrib.folding.view.Folding.FoldingLimitReporter {

    final _limit:Int;
    final _update:Null<(computed:Int, limited:Null<Int>) -> Void>;

    public function new(limit:Int, ?update:(computed:Int, limited:Null<Int>) -> Void) {
        _limit = limit;
        _update = update;
    }

    public var limit(get, never):Int;
    function get_limit():Int {
        return _limit;
    }

    public function update(computed:Int, limited:Null<Int>):Void {
        if (_update != null) {
            _update(computed, limited);
        }
    }

}

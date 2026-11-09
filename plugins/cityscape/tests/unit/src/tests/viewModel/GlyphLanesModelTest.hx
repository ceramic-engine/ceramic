// Ported from vscode src/vs/editor/test/common/viewModel/glyphLanesModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.viewModel;

import cityscape.common.Model.GlyphMarginLane;
import cityscape.common.core.Range;
import cityscape.common.viewModel.GlyphLanesModel;
import testing.TestCase;

/**
 * suite('GlyphLanesModel')
 */
class GlyphLanesModelTest extends TestCase {

    var model:GlyphMarginLanesModel;

    static function lineRange(startLineNumber:Int, endLineNumber:Int):Range {
        return new Range(startLineNumber, 1, endLineNumber, 1);
    }

    function assertLines(fromLine:Int, n:Int, expected:Array<Array<GlyphMarginLane>>, ?pos:haxe.PosInfos):Void {
        final result:Array<Array<GlyphMarginLane>> = [];
        for (i in 0...n) {
            result.push(model.getLanesAtLine(fromLine + i));
        }
        assertDeepEquals(expected, result, 'fromLine: $fromLine, n: $n', pos);
    }

    override public function setup():Void {
        model = new GlyphMarginLanesModel(10);
    }

    function testHandlesEmpty() {
        assertEquals(1, model.requiredLanes);
        assertLines(1, 1, [
            [GlyphMarginLane.Center],
        ]);
    }

    function testWorksWithASingleLineRange() {
        model.push(GlyphMarginLane.Left, lineRange(2, 3));
        assertEquals(1, model.requiredLanes);
        assertLines(1, 5, [
            [GlyphMarginLane.Center], // 1
            [GlyphMarginLane.Left], // 2
            [GlyphMarginLane.Left], // 3
            [GlyphMarginLane.Center], // 4
            [GlyphMarginLane.Center], // 5
        ]);
    }

    function testPersistsRanges() {
        model.push(GlyphMarginLane.Left, lineRange(2, 3), true);
        assertEquals(1, model.requiredLanes);
        assertLines(1, 5, [
            [GlyphMarginLane.Left], // 1
            [GlyphMarginLane.Left], // 2
            [GlyphMarginLane.Left], // 3
            [GlyphMarginLane.Left], // 4
            [GlyphMarginLane.Left], // 5
        ]);
    }

    function testHandlesOverlaps() {
        model.push(GlyphMarginLane.Left, lineRange(6, 9));
        model.push(GlyphMarginLane.Right, lineRange(5, 7));
        model.push(GlyphMarginLane.Center, lineRange(7, 8));
        assertEquals(3, model.requiredLanes);
        assertLines(5, 6, [
            [GlyphMarginLane.Right], // 5
            [GlyphMarginLane.Left, GlyphMarginLane.Right], // 6
            [GlyphMarginLane.Left, GlyphMarginLane.Center, GlyphMarginLane.Right], // 7
            [GlyphMarginLane.Left, GlyphMarginLane.Center], // 8
            [GlyphMarginLane.Left], // 9
            [GlyphMarginLane.Center], // 10
        ]);
    }

}

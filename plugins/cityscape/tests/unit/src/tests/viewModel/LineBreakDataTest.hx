// Ported from vscode src/vs/editor/test/common/viewModel/lineBreakData.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.viewModel;

import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.ModelLineProjectionData;
import testing.TestCase;

/**
 * suite('Editor ViewModel - LineBreakData'), with its sub suites
 * 'Injected Text 1', 'Injected Text 2' and 'Injected Text 3' (test names
 * prefixed with the sub suite).
 *
 * `ModelDecorationInjectedTextOptions.from({content})` is a plain
 * `{content: e}` here (the projection takes `InjectedTextOptions`, and only
 * reads `content` and `cursorStops`).
 */
class LineBreakDataTest extends TestCase {

    function testBasic() {
        final data = new ModelLineProjectionData([], [], [100], [0], 10);

        assertEquals(50, data.translateToInputOffset(0, 50));
        assertEquals(150, data.translateToInputOffset(1, 60));
    }

    static function sequence(length:Int, start:Int = 0):Array<Int> {
        final result = new Array<Int>();
        for (i in 0...length) {
            result.push(i + start);
        }
        return result;
    }

    function assertInverse(data:ModelLineProjectionData, ?pos:haxe.PosInfos) {
        for (i in 0...100) {
            final output = data.translateToOutputPosition(i);
            assertEquals(i, data.translateToInputOffset(output.outputLineIndex, output.outputOffset), null, pos);
        }
    }

    static function getInputOffsets(data:ModelLineProjectionData, outputLineIdx:Int):Array<Int> {
        return sequence(20).map(i -> data.translateToInputOffset(outputLineIdx, i));
    }

    static function getOutputOffsets(data:ModelLineProjectionData, affinity:PositionAffinity):Array<String> {
        return sequence(25).map(i -> data.translateToOutputPosition(i, affinity).toString());
    }

    static function mapTextToInjectedTextOptions(arr:Array<String>):Array<InjectedTextOptions> {
        return arr.map(e -> ({content: e} : InjectedTextOptions));
    }

    // suite('Injected Text 1')

    static function data1():ModelLineProjectionData {
        return new ModelLineProjectionData([2, 3, 10], mapTextToInjectedTextOptions(['1', '22', '333']), [10, 100], [], 10);
    }

    function testInjectedText1GetInputOffsetOfOutputPosition() {
        final data = data1();
        // For every view model position, what is the model position?
        assertDeepEquals([0, 1, 2, 2, 3, 3, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10, 11, 12, 13], getInputOffsets(data, 0));
        assertDeepEquals([7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 9, 10, 10, 10, 10, 11, 12, 13], getInputOffsets(data, 1));
    }

    function testInjectedText1GetOutputPositionOfInputOffset() {
        final data = data1();
        data.translateToOutputPosition(20);
        assertDeepEquals([
            '0:0', '0:1', '0:2', '0:4', '0:7', '0:8', '0:9', '1:10', '1:11', '1:12', '1:13', '1:17', '1:18', '1:19', '1:20',
            '1:21', '1:22', '1:23', '1:24', '1:25', '1:26', '1:27', '1:28', '1:29', '1:30',
        ], getOutputOffsets(data, PositionAffinity.None));

        assertDeepEquals([
            '0:0', '0:1', '0:2', '0:4', '0:7', '0:8', '0:9', '0:10', '1:11', '1:12', '1:13', '1:17', '1:18', '1:19', '1:20',
            '1:21', '1:22', '1:23', '1:24', '1:25', '1:26', '1:27', '1:28', '1:29', '1:30',
        ], getOutputOffsets(data, PositionAffinity.Left));

        assertDeepEquals([
            '0:0', '0:1', '0:3', '0:6', '0:7', '0:8', '0:9', '1:10', '1:11', '1:12', '1:16', '1:17', '1:18', '1:19', '1:20',
            '1:21', '1:22', '1:23', '1:24', '1:25', '1:26', '1:27', '1:28', '1:29', '1:30',
        ], getOutputOffsets(data, PositionAffinity.Right));
    }

    function testInjectedText1GetInputOffsetOfOutputPositionIsInverseOfGetOutputPositionOfInputOffset() {
        assertInverse(data1());
    }

    function testInjectedText1Normalization() {
        final data = data1();
        assertDeepEquals(
            [
                '1:0', '1:1', '1:2', '1:3', '1:4', '1:5', '1:6', '1:7', '1:8', '1:9', '1:10', '1:11', '1:12', '1:16', '1:16',
                '1:16', '1:16', '1:17', '1:18', '1:19', '1:20', '1:21', '1:22', '1:23', '1:24',
            ],
            sequence(25).map(v -> data.normalizeOutputPosition(1, v, PositionAffinity.Right)).map(s -> s.toString())
        );
    }

    // suite('Injected Text 2')

    static function data2():ModelLineProjectionData {
        return new ModelLineProjectionData([2, 2, 6], mapTextToInjectedTextOptions(['1', '22', '333']), [10, 100], [], 0);
    }

    function testInjectedText2GetInputOffsetOfOutputPosition() {
        final data = data2();
        assertDeepEquals([0, 1, 2, 2, 2, 2, 3, 4, 5, 6, 6, 6, 6, 7, 8, 9, 10, 11, 12, 13], getInputOffsets(data, 0));
        assertDeepEquals([6, 6, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23], getInputOffsets(data, 1));
    }

    function testInjectedText2GetInputOffsetOfOutputPositionIsInverseOfGetOutputPositionOfInputOffset() {
        assertInverse(data2());
    }

    // suite('Injected Text 3')

    static function data3():ModelLineProjectionData {
        return new ModelLineProjectionData([2, 2, 7], mapTextToInjectedTextOptions(['1', '22', '333']), [10, 100], [], 0);
    }

    function testInjectedText3GetInputOffsetOfOutputPosition() {
        final data = data3();
        assertDeepEquals([0, 1, 2, 2, 2, 2, 3, 4, 5, 6, 7, 7, 7, 7, 8, 9, 10, 11, 12, 13], getInputOffsets(data, 0));
        assertDeepEquals([7, 7, 7, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23], getInputOffsets(data, 1));
    }

    function testInjectedText3GetInputOffsetOfOutputPositionIsInverseOfGetOutputPositionOfInputOffset() {
        assertInverse(data3());
    }

    // Cityscape: injections that replace text (hidden ranges)

    function testHiddenRangeTranslations() {
        // 'abcdefgh' with 'cde' (offsets 2 to 5) hidden: view 'abfgh'
        final data = new ModelLineProjectionData([2], [({content: '', replacedLength: 3} : InjectedTextOptions)], [5], [], 0);
        // view to model
        assertDeepEquals([0, 1, 2, 6, 7, 8], [for (i in 0...6) data.translateToInputOffset(0, i)]);
        // model to view: inside the hidden range, at its start (or its end
        // with a right affinity)
        assertDeepEquals(['0:0', '0:1', '0:2', '0:2', '0:2', '0:2', '0:3', '0:4', '0:5'], [for (i in 0...9) data.translateToOutputPosition(i).toString()]);
        assertDeepEquals(['0:0', '0:1', '0:2', '0:2', '0:2', '0:2', '0:3', '0:4', '0:5'], [for (i in 0...9) data.translateToOutputPosition(i, PositionAffinity.Right).toString()]);
        // no injected text is reported for hidden text
        assertNull(data.getInjectedText(0, 2));
    }

    function testReplacementTranslations() {
        // 'abcdefgh' with 'cde' replaced by '#': view 'ab#fgh'
        final data = new ModelLineProjectionData([2], [({content: '#', replacedLength: 3} : InjectedTextOptions)], [6], [], 0);
        assertDeepEquals([0, 1, 2, 5, 6, 7, 8], [for (i in 0...7) data.translateToInputOffset(0, i)]);
        assertDeepEquals(['0:0', '0:1', '0:2', '0:2', '0:2', '0:3', '0:4', '0:5'], [for (i in 0...8) data.translateToOutputPosition(i).toString()]);
        assertDeepEquals(['0:0', '0:1', '0:3', '0:3', '0:3', '0:3', '0:4', '0:5'], [for (i in 0...8) data.translateToOutputPosition(i, PositionAffinity.Right).toString()]);
        assertNotNull(data.getInjectedText(0, 3));
    }

}

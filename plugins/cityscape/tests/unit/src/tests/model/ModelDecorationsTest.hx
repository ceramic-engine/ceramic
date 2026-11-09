// Ported from vscode src/vs/editor/test/common/model/modelDecorations.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes of this module:
// - EditorModelModelDecorationsTest
// - DecorationsAndEditingTest (helpers of suite('Decorations and editing'), no test of its own:
//   the classes of its nested suites extend it)
// - DecorationsAndEditingInsertCollapsedDecTest
// - DecorationsAndEditingInsertNonCollapsedDecTest
// - DecorationsAndEditingDeleteCollapsedDecTest
// - DecorationsAndEditingDeleteNonCollapsedDecTest
// - DecorationsAndEditingReplaceShortCollapsedDecTest
// - DecorationsAndEditingReplaceShortNonCollapsedDecTest
// - DecorationsAndEditingReplaceLongCollapsedDecTest
// - DecorationsAndEditingReplaceLongNonCollapsedDecTest
// - DeltaDecorationsTest

import cityscape.common.Model;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import tests.TestTextModel.createTextModel;
import testing.TestCase;

// --------- utils

private typedef ILightWeightDecoration2 = {
    var range:Range;
    var className:Null<String>;
}

private typedef ILineDecoration = {
    var start:Int;
    var end:Int;
    var className:Null<String>;
}

/**
 * The module level helpers of the vscode test file. They assert, so they are
 * instance methods of this base class.
 */
private class ModelDecorationsTestCase extends TestCase {

    function modelHasDecorations(model:TextModel, decorations:Array<ILightWeightDecoration2>):Void {
        final modelDecorations:Array<ILightWeightDecoration2> = [];
        final actualDecorations = model.getAllDecorations();
        for (i in 0...actualDecorations.length) {
            modelDecorations.push({
                range: actualDecorations[i].range,
                className: actualDecorations[i].options.className
            });
        }
        modelDecorations.sort((a, b) -> Range.compareRangesUsingStarts(a.range, b.range));
        assertDeepEquals(modelDecorations, decorations);
    }

    function modelHasDecoration(model:TextModel, startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int, className:String):Void {
        modelHasDecorations(model, [{
            range: new Range(startLineNumber, startColumn, endLineNumber, endColumn),
            className: className
        }]);
    }

    function modelHasNoDecorations(model:TextModel):Void {
        assertEquals(model.getAllDecorations().length, 0, 'Model has no decoration');
    }

    function addDecoration(model:TextModel, startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int, className:String):String {
        return model.changeDecorations((changeAccessor) -> {
            return changeAccessor.addDecoration(new Range(startLineNumber, startColumn, endLineNumber, endColumn), {
                description: 'test',
                className: className
            });
        });
    }

    function lineHasDecorations(model:TextModel, lineNumber:Int, decorations:Array<ILineDecoration>):Void {
        final lineDecorations:Array<ILineDecoration> = [];
        final decs = model.getLineDecorations(lineNumber);
        for (i in 0...decs.length) {
            lineDecorations.push({
                start: decs[i].range.startColumn,
                end: decs[i].range.endColumn,
                className: decs[i].options.className
            });
        }
        assertDeepEquals(lineDecorations, decorations, 'Line decorations');
    }

    function lineHasNoDecorations(model:TextModel, lineNumber:Int):Void {
        lineHasDecorations(model, lineNumber, []);
    }

    function lineHasDecoration(model:TextModel, lineNumber:Int, start:Int, end:Int, className:String):Void {
        lineHasDecorations(model, lineNumber, [{
            start: start,
            end: end,
            className: className
        }]);
    }

}

/**
 * suite('Editor Model - Model Decorations')
 */
class EditorModelModelDecorationsTest extends ModelDecorationsTestCase {

    static final LINE1 = 'My First Line';
    static final LINE2 = '\t\tMy Second Line';
    static final LINE3 = '    Third Line';
    static final LINE4 = '';
    static final LINE5 = '1';

    // --------- Model Decorations

    var thisModel:TextModel;

    override function setup():Void {
        final text =
            LINE1 + '\r\n' +
            LINE2 + '\n' +
            LINE3 + '\n' +
            LINE4 + '\r\n' +
            LINE5;
        thisModel = createTextModel(text);
    }

    override function teardown():Void {
        thisModel.dispose();
    }

    // test('single character decoration')
    function testSingleCharacterDecoration():Void {
        addDecoration(thisModel, 1, 1, 1, 2, 'myType');
        lineHasDecoration(thisModel, 1, 1, 2, 'myType');
        lineHasNoDecorations(thisModel, 2);
        lineHasNoDecorations(thisModel, 3);
        lineHasNoDecorations(thisModel, 4);
        lineHasNoDecorations(thisModel, 5);
    }

    // test('line decoration')
    function testLineDecoration():Void {
        addDecoration(thisModel, 1, 1, 1, 14, 'myType');
        lineHasDecoration(thisModel, 1, 1, 14, 'myType');
        lineHasNoDecorations(thisModel, 2);
        lineHasNoDecorations(thisModel, 3);
        lineHasNoDecorations(thisModel, 4);
        lineHasNoDecorations(thisModel, 5);
    }

    // test('full line decoration')
    function testFullLineDecoration():Void {
        addDecoration(thisModel, 1, 1, 2, 1, 'myType');

        final line1Decorations = thisModel.getLineDecorations(1);
        assertEquals(line1Decorations.length, 1);
        assertEquals(line1Decorations[0].options.className, 'myType');

        final line2Decorations = thisModel.getLineDecorations(1);
        assertEquals(line2Decorations.length, 1);
        assertEquals(line2Decorations[0].options.className, 'myType');

        lineHasNoDecorations(thisModel, 3);
        lineHasNoDecorations(thisModel, 4);
        lineHasNoDecorations(thisModel, 5);
    }

    // test('multiple line decoration')
    function testMultipleLineDecoration():Void {
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');

        final line1Decorations = thisModel.getLineDecorations(1);
        assertEquals(line1Decorations.length, 1);
        assertEquals(line1Decorations[0].options.className, 'myType');

        final line2Decorations = thisModel.getLineDecorations(1);
        assertEquals(line2Decorations.length, 1);
        assertEquals(line2Decorations[0].options.className, 'myType');

        final line3Decorations = thisModel.getLineDecorations(1);
        assertEquals(line3Decorations.length, 1);
        assertEquals(line3Decorations[0].options.className, 'myType');

        lineHasNoDecorations(thisModel, 4);
        lineHasNoDecorations(thisModel, 5);
    }

    // test('decoration gets removed')
    function testDecorationGetsRemoved():Void {
        final decId = addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.changeDecorations((changeAccessor) -> {
            changeAccessor.removeDecoration(decId);
        });
        modelHasNoDecorations(thisModel);
    }

    // test('decorations get removed')
    function testDecorationsGetRemoved():Void {
        final decId1 = addDecoration(thisModel, 1, 2, 3, 2, 'myType1');
        final decId2 = addDecoration(thisModel, 1, 2, 3, 1, 'myType2');
        modelHasDecorations(thisModel, [
            {
                range: new Range(1, 2, 3, 1),
                className: 'myType2'
            },
            {
                range: new Range(1, 2, 3, 2),
                className: 'myType1'
            }
        ]);
        thisModel.changeDecorations((changeAccessor) -> {
            changeAccessor.removeDecoration(decId1);
        });
        modelHasDecorations(thisModel, [
            {
                range: new Range(1, 2, 3, 1),
                className: 'myType2'
            }
        ]);
        thisModel.changeDecorations((changeAccessor) -> {
            changeAccessor.removeDecoration(decId2);
        });
        modelHasNoDecorations(thisModel);
    }

    // test('decoration range can be changed')
    function testDecorationRangeCanBeChanged():Void {
        final decId = addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.changeDecorations((changeAccessor) -> {
            changeAccessor.changeDecoration(decId, new Range(1, 1, 1, 2));
        });
        modelHasDecoration(thisModel, 1, 1, 1, 2, 'myType');
    }

    // test('decorations emit event on add')
    function testDecorationsEmitEventOnAdd():Void {
        var listenerCalled = 0;
        final disposable = thisModel.onDidChangeDecorations((e) -> {
            listenerCalled++;
        });
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        assertEquals(listenerCalled, 1, 'listener called');
        disposable.dispose();
    }

    // test('decorations emit event on change')
    function testDecorationsEmitEventOnChange():Void {
        var listenerCalled = 0;
        final decId = addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        final disposable = thisModel.onDidChangeDecorations((e) -> {
            listenerCalled++;
        });
        thisModel.changeDecorations((changeAccessor) -> {
            changeAccessor.changeDecoration(decId, new Range(1, 1, 1, 2));
        });
        assertEquals(listenerCalled, 1, 'listener called');
        disposable.dispose();
    }

    // test('decorations emit event on remove')
    function testDecorationsEmitEventOnRemove():Void {
        var listenerCalled = 0;
        final decId = addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        final disposable = thisModel.onDidChangeDecorations((e) -> {
            listenerCalled++;
        });
        thisModel.changeDecorations((changeAccessor) -> {
            changeAccessor.removeDecoration(decId);
        });
        assertEquals(listenerCalled, 1, 'listener called');
        disposable.dispose();
    }

    // test('decorations emit event when inserting one line text before it')
    function testDecorationsEmitEventWhenInsertingOneLineTextBeforeIt():Void {
        var listenerCalled = 0;
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');

        final disposable = thisModel.onDidChangeDecorations((e) -> {
            listenerCalled++;
        });

        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), 'Hallo ')]);
        assertEquals(listenerCalled, 1, 'listener called');
        disposable.dispose();
    }

    // test('decorations do not emit event on no-op deltaDecorations')
    function testDecorationsDoNotEmitEventOnNoOpDeltaDecorations():Void {
        var listenerCalled = 0;

        final disposable = thisModel.onDidChangeDecorations((e) -> {
            listenerCalled++;
        });

        thisModel.deltaDecorations([], []);
        thisModel.changeDecorations((accessor) -> {
            accessor.deltaDecorations([], []);
        });

        assertEquals(listenerCalled, 0, 'listener not called');
        disposable.dispose();
    }

    // test('decorations are updated when inserting one line text before it')
    function testDecorationsAreUpdatedWhenInsertingOneLineTextBeforeIt():Void {
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), 'Hallo ')]);
        modelHasDecoration(thisModel, 1, 8, 3, 2, 'myType');
    }

    // test('decorations are updated when inserting one line text before it 2')
    function testDecorationsAreUpdatedWhenInsertingOneLineTextBeforeIt2():Void {
        addDecoration(thisModel, 1, 1, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 1, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.replace(new Range(1, 1, 1, 1), 'Hallo ')]);
        modelHasDecoration(thisModel, 1, 1, 3, 2, 'myType');
    }

    // test('decorations are updated when inserting multiple lines text before it')
    function testDecorationsAreUpdatedWhenInsertingMultipleLinesTextBeforeIt():Void {
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), 'Hallo\nI\'m inserting multiple\nlines')]);
        modelHasDecoration(thisModel, 3, 7, 5, 2, 'myType');
    }

    // test('decorations change when inserting text after them')
    function testDecorationsChangeWhenInsertingTextAfterThem():Void {
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.insert(new Position(3, 2), 'Hallo')]);
        modelHasDecoration(thisModel, 1, 2, 3, 7, 'myType');
    }

    // test('decorations are updated when inserting text inside')
    function testDecorationsAreUpdatedWhenInsertingTextInside():Void {
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.insert(new Position(1, 3), 'Hallo ')]);
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
    }

    // test('decorations are updated when inserting text inside 2')
    function testDecorationsAreUpdatedWhenInsertingTextInside2():Void {
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.insert(new Position(3, 1), 'Hallo ')]);
        modelHasDecoration(thisModel, 1, 2, 3, 8, 'myType');
    }

    // test('decorations are updated when inserting text inside 3')
    function testDecorationsAreUpdatedWhenInsertingTextInside3():Void {
        addDecoration(thisModel, 1, 1, 2, 16, 'myType');
        modelHasDecoration(thisModel, 1, 1, 2, 16, 'myType');
        thisModel.applyEdits([EditOperation.insert(new Position(2, 2), '\n')]);
        modelHasDecoration(thisModel, 1, 1, 3, 15, 'myType');
    }

    // test('decorations are updated when inserting multiple lines text inside')
    function testDecorationsAreUpdatedWhenInsertingMultipleLinesTextInside():Void {
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.insert(new Position(1, 3), 'Hallo\nI\'m inserting multiple\nlines')]);
        modelHasDecoration(thisModel, 1, 2, 5, 2, 'myType');
    }

    // test('decorations are updated when deleting one line text before it')
    function testDecorationsAreUpdatedWhenDeletingOneLineTextBeforeIt():Void {
        addDecoration(thisModel, 1, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 1, 2, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 1, 2))]);
        modelHasDecoration(thisModel, 1, 1, 3, 2, 'myType');
    }

    // test('decorations are updated when deleting multiple lines text before it')
    function testDecorationsAreUpdatedWhenDeletingMultipleLinesTextBeforeIt():Void {
        addDecoration(thisModel, 2, 2, 3, 2, 'myType');
        modelHasDecoration(thisModel, 2, 2, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 2, 1))]);
        modelHasDecoration(thisModel, 1, 2, 2, 2, 'myType');
    }

    // test('decorations are updated when deleting multiple lines text before it 2')
    function testDecorationsAreUpdatedWhenDeletingMultipleLinesTextBeforeIt2():Void {
        addDecoration(thisModel, 2, 3, 3, 2, 'myType');
        modelHasDecoration(thisModel, 2, 3, 3, 2, 'myType');
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 2, 2))]);
        modelHasDecoration(thisModel, 1, 2, 2, 2, 'myType');
    }

    // test('decorations are updated when deleting text inside')
    function testDecorationsAreUpdatedWhenDeletingTextInside():Void {
        addDecoration(thisModel, 1, 2, 4, 1, 'myType');
        modelHasDecoration(thisModel, 1, 2, 4, 1, 'myType');
        thisModel.applyEdits([EditOperation.delete(new Range(1, 3, 2, 1))]);
        modelHasDecoration(thisModel, 1, 2, 3, 1, 'myType');
    }

    // test('decorations are updated when deleting text inside 2')
    function testDecorationsAreUpdatedWhenDeletingTextInside2():Void {
        addDecoration(thisModel, 1, 2, 4, 1, 'myType');
        modelHasDecoration(thisModel, 1, 2, 4, 1, 'myType');
        thisModel.applyEdits([
            EditOperation.delete(new Range(1, 1, 1, 2)),
            EditOperation.delete(new Range(4, 1, 4, 1))
        ]);
        modelHasDecoration(thisModel, 1, 1, 4, 1, 'myType');
    }

    // test('decorations are updated when deleting multiple lines text')
    function testDecorationsAreUpdatedWhenDeletingMultipleLinesText():Void {
        addDecoration(thisModel, 1, 2, 4, 1, 'myType');
        modelHasDecoration(thisModel, 1, 2, 4, 1, 'myType');
        thisModel.applyEdits([EditOperation.delete(new Range(1, 1, 3, 1))]);
        modelHasDecoration(thisModel, 1, 1, 2, 1, 'myType');
    }

    // test('decorations are updated when changing EOL')
    function testDecorationsAreUpdatedWhenChangingEOL():Void {
        addDecoration(thisModel, 1, 2, 4, 1, 'myType1');
        addDecoration(thisModel, 1, 3, 4, 1, 'myType2');
        addDecoration(thisModel, 1, 4, 4, 1, 'myType3');
        addDecoration(thisModel, 1, 5, 4, 1, 'myType4');
        addDecoration(thisModel, 1, 6, 4, 1, 'myType5');
        addDecoration(thisModel, 1, 7, 4, 1, 'myType6');
        addDecoration(thisModel, 1, 8, 4, 1, 'myType7');
        addDecoration(thisModel, 1, 9, 4, 1, 'myType8');
        addDecoration(thisModel, 1, 10, 4, 1, 'myType9');
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), 'x')]);
        thisModel.setEOL(EndOfLineSequence.CRLF);
        thisModel.applyEdits([EditOperation.insert(new Position(1, 1), 'x')]);
        modelHasDecorations(thisModel, [
            { range: new Range(1, 4, 4, 1), className: 'myType1' },
            { range: new Range(1, 5, 4, 1), className: 'myType2' },
            { range: new Range(1, 6, 4, 1), className: 'myType3' },
            { range: new Range(1, 7, 4, 1), className: 'myType4' },
            { range: new Range(1, 8, 4, 1), className: 'myType5' },
            { range: new Range(1, 9, 4, 1), className: 'myType6' },
            { range: new Range(1, 10, 4, 1), className: 'myType7' },
            { range: new Range(1, 11, 4, 1), className: 'myType8' },
            { range: new Range(1, 12, 4, 1), className: 'myType9' },
        ]);
    }

    // test('an apparently simple edit')
    function testAnApparentlySimpleEdit():Void {
        addDecoration(thisModel, 1, 2, 4, 1, 'myType1');
        thisModel.applyEdits([EditOperation.replace(new Range(1, 14, 2, 1), 'x')]);
        modelHasDecorations(thisModel, [
            { range: new Range(1, 2, 3, 1), className: 'myType1' },
        ]);
    }

    // test('removeAllDecorationsWithOwnerId can be called after model dispose')
    function testRemoveAllDecorationsWithOwnerIdCanBeCalledAfterModelDispose():Void {
        final model = createTextModel('asd');
        model.dispose();
        model.removeAllDecorationsWithOwnerId(1);
    }

    // test('removeAllDecorationsWithOwnerId works')
    function testRemoveAllDecorationsWithOwnerIdWorks():Void {
        thisModel.deltaDecorations([], [{ range: new Range(1, 2, 4, 1), options: { description: 'test', className: 'myType1' } }], 1);
        thisModel.removeAllDecorationsWithOwnerId(1);
        modelHasNoDecorations(thisModel);
    }

}

/**
 * suite('Decorations and editing'): its helpers. The suite has no test of its
 * own; the classes of its nested suites extend this class.
 */
class DecorationsAndEditingTest extends TestCase {

    function _runTest(decRange:Range, stickiness:TrackedRangeStickiness, editRange:Range, editText:String, editForceMoveMarkers:Bool, expectedDecRange:Range, msg:String):Void {
        final model = createTextModel([
            'My First Line',
            'My Second Line',
            'Third Line'
        ].join('\n'));

        final id = model.deltaDecorations([], [{ range: decRange, options: { description: 'test', stickiness: stickiness } }])[0];
        model.applyEdits([{
            range: editRange,
            text: editText,
            forceMoveMarkers: editForceMoveMarkers
        }]);
        final actual = model.getDecorationRange(id);
        assertDeepEquals(actual, expectedDecRange, msg);

        model.dispose();
    }

    function runTest(decRange:Range, editRange:Range, editText:String, expectedDecRange:Array<Array<Range>>):Void {
        _runTest(decRange, 0, editRange, editText, false, expectedDecRange[0][0], 'no-0-AlwaysGrowsWhenTypingAtEdges');
        _runTest(decRange, 1, editRange, editText, false, expectedDecRange[0][1], 'no-1-NeverGrowsWhenTypingAtEdges');
        _runTest(decRange, 2, editRange, editText, false, expectedDecRange[0][2], 'no-2-GrowsOnlyWhenTypingBefore');
        _runTest(decRange, 3, editRange, editText, false, expectedDecRange[0][3], 'no-3-GrowsOnlyWhenTypingAfter');

        _runTest(decRange, 0, editRange, editText, true, expectedDecRange[1][0], 'force-0-AlwaysGrowsWhenTypingAtEdges');
        _runTest(decRange, 1, editRange, editText, true, expectedDecRange[1][1], 'force-1-NeverGrowsWhenTypingAtEdges');
        _runTest(decRange, 2, editRange, editText, true, expectedDecRange[1][2], 'force-2-GrowsOnlyWhenTypingBefore');
        _runTest(decRange, 3, editRange, editText, true, expectedDecRange[1][3], 'force-3-GrowsOnlyWhenTypingAfter');
    }

}

/**
 * suite('Decorations and editing') > suite('insert') > suite('collapsed dec')
 */
class DecorationsAndEditingInsertCollapsedDecTest extends DecorationsAndEditingTest {

    // test('before')
    function testBefore():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 3, 1, 3), 'xx',
            [
                [new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6)],
                [new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6)],
            ]
        );
    }

    // test('equal')
    function testEqual():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 4, 1, 4), 'xx',
            [
                [new Range(1, 4, 1, 6), new Range(1, 6, 1, 6), new Range(1, 4, 1, 4), new Range(1, 6, 1, 6)],
                [new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6)],
            ]
        );
    }

    // test('after')
    function testAfter():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 5, 1, 5), 'xx',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

}

/**
 * suite('Decorations and editing') > suite('insert') > suite('non-collapsed dec')
 */
class DecorationsAndEditingInsertNonCollapsedDecTest extends DecorationsAndEditingTest {

    // test('before')
    function testBefore():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 3), 'xx',
            [
                [new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11)],
                [new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11)],
            ]
        );
    }

    // test('start')
    function testStart():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 4), 'xx',
            [
                [new Range(1, 4, 1, 11), new Range(1, 6, 1, 11), new Range(1, 4, 1, 11), new Range(1, 6, 1, 11)],
                [new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11)],
            ]
        );
    }

    // test('inside')
    function testInside():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 5), 'xx',
            [
                [new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11)],
                [new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11)],
            ]
        );
    }

    // test('end')
    function testEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 9, 1, 9), 'xx',
            [
                [new Range(1, 4, 1, 11), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 11)],
                [new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11)],
            ]
        );
    }

    // test('after')
    function testAfter():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 10, 1, 10), 'xx',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
            ]
        );
    }

}

/**
 * suite('Decorations and editing') > suite('delete') > suite('collapsed dec')
 */
class DecorationsAndEditingDeleteCollapsedDecTest extends DecorationsAndEditingTest {

    // test('edit.end < range.start')
    function testEditEndRangeStart():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 1, 1, 3), '',
            [
                [new Range(1, 2, 1, 2), new Range(1, 2, 1, 2), new Range(1, 2, 1, 2), new Range(1, 2, 1, 2)],
                [new Range(1, 2, 1, 2), new Range(1, 2, 1, 2), new Range(1, 2, 1, 2), new Range(1, 2, 1, 2)],
            ]
        );
    }

    // test('edit.end <= range.start')
    function testEditEndRangeStart2():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 2, 1, 4), '',
            [
                [new Range(1, 2, 1, 2), new Range(1, 2, 1, 2), new Range(1, 2, 1, 2), new Range(1, 2, 1, 2)],
                [new Range(1, 2, 1, 2), new Range(1, 2, 1, 2), new Range(1, 2, 1, 2), new Range(1, 2, 1, 2)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 3, 1, 5), '',
            [
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
            ]
        );
    }

    // test('edit.start >= range.end')
    function testEditStartRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 4, 1, 6), '',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

    // test('edit.start > range.end')
    function testEditStartRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 5, 1, 7), '',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

}

/**
 * suite('Decorations and editing') > suite('delete') > suite('non-collapsed dec')
 */
class DecorationsAndEditingDeleteNonCollapsedDecTest extends DecorationsAndEditingTest {

    // test('edit.end < range.start')
    function testEditEndRangeStart():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 1, 1, 3), '',
            [
                [new Range(1, 2, 1, 7), new Range(1, 2, 1, 7), new Range(1, 2, 1, 7), new Range(1, 2, 1, 7)],
                [new Range(1, 2, 1, 7), new Range(1, 2, 1, 7), new Range(1, 2, 1, 7), new Range(1, 2, 1, 7)],
            ]
        );
    }

    // test('edit.end <= range.start')
    function testEditEndRangeStart2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 2, 1, 4), '',
            [
                [new Range(1, 2, 1, 7), new Range(1, 2, 1, 7), new Range(1, 2, 1, 7), new Range(1, 2, 1, 7)],
                [new Range(1, 2, 1, 7), new Range(1, 2, 1, 7), new Range(1, 2, 1, 7), new Range(1, 2, 1, 7)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end < range.end')
    function testEditStartRangeStartEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 5), '',
            [
                [new Range(1, 3, 1, 7), new Range(1, 3, 1, 7), new Range(1, 3, 1, 7), new Range(1, 3, 1, 7)],
                [new Range(1, 3, 1, 7), new Range(1, 3, 1, 7), new Range(1, 3, 1, 7), new Range(1, 3, 1, 7)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end == range.end')
    function testEditStartRangeStartEditEndRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 9), '',
            [
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd3():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 10), '',
            [
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end < range.end')
    function testEditStartRangeStartEditEndRangeEnd4():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 6), '',
            [
                [new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7)],
                [new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end == range.end')
    function testEditStartRangeStartEditEndRangeEnd5():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 9), '',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd6():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 10), '',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end < range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 7), '',
            [
                [new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7)],
                [new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end == range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 9), '',
            [
                [new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5)],
                [new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end > range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd3():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 10), '',
            [
                [new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5)],
                [new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5)],
            ]
        );
    }

    // test('edit.start == range.end')
    function testEditStartRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 9, 1, 11), '',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
            ]
        );
    }

    // test('edit.start > range.end')
    function testEditStartRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 10, 1, 11), '',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
            ]
        );
    }

}

/**
 * suite('Decorations and editing') > suite('replace short') > suite('collapsed dec')
 */
class DecorationsAndEditingReplaceShortCollapsedDecTest extends DecorationsAndEditingTest {

    // test('edit.end < range.start')
    function testEditEndRangeStart():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 1, 1, 3), 'c',
            [
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
            ]
        );
    }

    // test('edit.end <= range.start')
    function testEditEndRangeStart2():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 2, 1, 4), 'c',
            [
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
                [new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3), new Range(1, 3, 1, 3)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 3, 1, 5), 'c',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

    // test('edit.start >= range.end')
    function testEditStartRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 4, 1, 6), 'c',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 5, 1, 5), new Range(1, 5, 1, 5), new Range(1, 5, 1, 5), new Range(1, 5, 1, 5)],
            ]
        );
    }

    // test('edit.start > range.end')
    function testEditStartRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 5, 1, 7), 'c',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

}

/**
 * suite('Decorations and editing') > suite('replace short') > suite('non-collapsed dec')
 */
class DecorationsAndEditingReplaceShortNonCollapsedDecTest extends DecorationsAndEditingTest {

    // test('edit.end < range.start')
    function testEditEndRangeStart():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 1, 1, 3), 'c',
            [
                [new Range(1, 3, 1, 8), new Range(1, 3, 1, 8), new Range(1, 3, 1, 8), new Range(1, 3, 1, 8)],
                [new Range(1, 3, 1, 8), new Range(1, 3, 1, 8), new Range(1, 3, 1, 8), new Range(1, 3, 1, 8)],
            ]
        );
    }

    // test('edit.end <= range.start')
    function testEditEndRangeStart2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 2, 1, 4), 'c',
            [
                [new Range(1, 3, 1, 8), new Range(1, 3, 1, 8), new Range(1, 3, 1, 8), new Range(1, 3, 1, 8)],
                [new Range(1, 3, 1, 8), new Range(1, 3, 1, 8), new Range(1, 3, 1, 8), new Range(1, 3, 1, 8)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end < range.end')
    function testEditStartRangeStartEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 5), 'c',
            [
                [new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8)],
                [new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end == range.end')
    function testEditStartRangeStartEditEndRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 9), 'c',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd3():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 10), 'c',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end < range.end')
    function testEditStartRangeStartEditEndRangeEnd4():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 6), 'c',
            [
                [new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8)],
                [new Range(1, 5, 1, 8), new Range(1, 5, 1, 8), new Range(1, 5, 1, 8), new Range(1, 5, 1, 8)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end == range.end')
    function testEditStartRangeStartEditEndRangeEnd5():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 9), 'c',
            [
                [new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5)],
                [new Range(1, 5, 1, 5), new Range(1, 5, 1, 5), new Range(1, 5, 1, 5), new Range(1, 5, 1, 5)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd6():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 10), 'c',
            [
                [new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5), new Range(1, 4, 1, 5)],
                [new Range(1, 5, 1, 5), new Range(1, 5, 1, 5), new Range(1, 5, 1, 5), new Range(1, 5, 1, 5)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end < range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 7), 'c',
            [
                [new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8)],
                [new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end == range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 9), 'c',
            [
                [new Range(1, 4, 1, 6), new Range(1, 4, 1, 6), new Range(1, 4, 1, 6), new Range(1, 4, 1, 6)],
                [new Range(1, 4, 1, 6), new Range(1, 4, 1, 6), new Range(1, 4, 1, 6), new Range(1, 4, 1, 6)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end > range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd3():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 10), 'c',
            [
                [new Range(1, 4, 1, 6), new Range(1, 4, 1, 6), new Range(1, 4, 1, 6), new Range(1, 4, 1, 6)],
                [new Range(1, 4, 1, 6), new Range(1, 4, 1, 6), new Range(1, 4, 1, 6), new Range(1, 4, 1, 6)],
            ]
        );
    }

    // test('edit.start == range.end')
    function testEditStartRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 9, 1, 11), 'c',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 10), new Range(1, 4, 1, 10), new Range(1, 4, 1, 10), new Range(1, 4, 1, 10)],
            ]
        );
    }

    // test('edit.start > range.end')
    function testEditStartRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 10, 1, 11), 'c',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
            ]
        );
    }

}

/**
 * suite('Decorations and editing') > suite('replace long') > suite('collapsed dec')
 */
class DecorationsAndEditingReplaceLongCollapsedDecTest extends DecorationsAndEditingTest {

    // test('edit.end < range.start')
    function testEditEndRangeStart():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 1, 1, 3), 'cccc',
            [
                [new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6)],
                [new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6)],
            ]
        );
    }

    // test('edit.end <= range.start')
    function testEditEndRangeStart2():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 2, 1, 4), 'cccc',
            [
                [new Range(1, 4, 1, 6), new Range(1, 6, 1, 6), new Range(1, 4, 1, 4), new Range(1, 6, 1, 6)],
                [new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6), new Range(1, 6, 1, 6)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 3, 1, 5), 'cccc',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 7, 1, 7), new Range(1, 7, 1, 7), new Range(1, 7, 1, 7), new Range(1, 7, 1, 7)],
            ]
        );
    }

    // test('edit.start >= range.end')
    function testEditStartRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 4, 1, 6), 'cccc',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 8, 1, 8), new Range(1, 8, 1, 8), new Range(1, 8, 1, 8), new Range(1, 8, 1, 8)],
            ]
        );
    }

    // test('edit.start > range.end')
    function testEditStartRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 5, 1, 7), 'cccc',
            [
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
                [new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4), new Range(1, 4, 1, 4)],
            ]
        );
    }

}

/**
 * suite('Decorations and editing') > suite('replace long') > suite('non-collapsed dec')
 */
class DecorationsAndEditingReplaceLongNonCollapsedDecTest extends DecorationsAndEditingTest {

    // test('edit.end < range.start')
    function testEditEndRangeStart():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 1, 1, 3), 'cccc',
            [
                [new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11)],
                [new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11)],
            ]
        );
    }

    // test('edit.end <= range.start')
    function testEditEndRangeStart2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 2, 1, 4), 'cccc',
            [
                [new Range(1, 4, 1, 11), new Range(1, 6, 1, 11), new Range(1, 4, 1, 11), new Range(1, 6, 1, 11)],
                [new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11), new Range(1, 6, 1, 11)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end < range.end')
    function testEditStartRangeStartEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 5), 'cccc',
            [
                [new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11)],
                [new Range(1, 7, 1, 11), new Range(1, 7, 1, 11), new Range(1, 7, 1, 11), new Range(1, 7, 1, 11)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end == range.end')
    function testEditStartRangeStartEditEndRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 9), 'cccc',
            [
                [new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7)],
                [new Range(1, 7, 1, 7), new Range(1, 7, 1, 7), new Range(1, 7, 1, 7), new Range(1, 7, 1, 7)],
            ]
        );
    }

    // test('edit.start < range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd3():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 10), 'cccc',
            [
                [new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7), new Range(1, 4, 1, 7)],
                [new Range(1, 7, 1, 7), new Range(1, 7, 1, 7), new Range(1, 7, 1, 7), new Range(1, 7, 1, 7)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end < range.end')
    function testEditStartRangeStartEditEndRangeEnd4():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 6), 'cccc',
            [
                [new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11)],
                [new Range(1, 8, 1, 11), new Range(1, 8, 1, 11), new Range(1, 8, 1, 11), new Range(1, 8, 1, 11)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end == range.end')
    function testEditStartRangeStartEditEndRangeEnd5():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 9), 'cccc',
            [
                [new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8)],
                [new Range(1, 8, 1, 8), new Range(1, 8, 1, 8), new Range(1, 8, 1, 8), new Range(1, 8, 1, 8)],
            ]
        );
    }

    // test('edit.start == range.start && edit.end > range.end')
    function testEditStartRangeStartEditEndRangeEnd6():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 10), 'cccc',
            [
                [new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8), new Range(1, 4, 1, 8)],
                [new Range(1, 8, 1, 8), new Range(1, 8, 1, 8), new Range(1, 8, 1, 8), new Range(1, 8, 1, 8)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end < range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 7), 'cccc',
            [
                [new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11)],
                [new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11), new Range(1, 4, 1, 11)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end == range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 9), 'cccc',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
            ]
        );
    }

    // test('edit.start > range.start && edit.start < range.end && edit.end > range.end')
    function testEditStartRangeStartEditStartRangeEndEditEndRangeEnd3():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 10), 'cccc',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
            ]
        );
    }

    // test('edit.start == range.end')
    function testEditStartRangeEnd():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 9, 1, 11), 'cccc',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 13), new Range(1, 4, 1, 13), new Range(1, 4, 1, 13), new Range(1, 4, 1, 13)],
            ]
        );
    }

    // test('edit.start > range.end')
    function testEditStartRangeEnd2():Void {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 10, 1, 11), 'cccc',
            [
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
                [new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9), new Range(1, 4, 1, 9)],
            ]
        );
    }

}

private typedef ILightWeightDecoration = {
    var id:String;
    var range:Range;
}

/**
 * suite('deltaDecorations')
 */
class DeltaDecorationsTest extends TestCase {

    static function decoration(id:String, startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColum:Int):ILightWeightDecoration {
        return {
            id: id,
            range: new Range(startLineNumber, startColumn, endLineNumber, endColum)
        };
    }

    static function toModelDeltaDecoration(dec:ILightWeightDecoration):IModelDeltaDecoration {
        return {
            range: dec.range,
            options: {
                description: 'test',
                className: dec.id
            }
        };
    }

    static function strcmp(a:String, b:String):Int {
        if (a == b) {
            return 0;
        }
        if (a < b) {
            return -1;
        }
        return 1;
    }

    static function readModelDecorations(model:TextModel, ids:Array<String>):Array<ILightWeightDecoration> {
        return ids.map((id) -> {
            final dec:ILightWeightDecoration = {
                range: model.getDecorationRange(id),
                id: model.getDecorationOptions(id).className
            };
            return dec;
        });
    }

    function _testDeltaDecorations(text:Array<String>, decorations:Array<ILightWeightDecoration>, newDecorations:Array<ILightWeightDecoration>):Void {

        final model = createTextModel(text.join('\n'));

        // Add initial decorations & assert they are added
        final initialIds = model.deltaDecorations([], decorations.map(toModelDeltaDecoration));
        final actualDecorations = readModelDecorations(model, initialIds);

        assertEquals(initialIds.length, decorations.length, 'returns expected cnt of ids');
        assertEquals(initialIds.length, model.getAllDecorations().length, 'does not leak decorations');
        actualDecorations.sort((a, b) -> strcmp(a.id, b.id));
        decorations.sort((a, b) -> strcmp(a.id, b.id));
        assertDeepEquals(actualDecorations, decorations);

        final newIds = model.deltaDecorations(initialIds, newDecorations.map(toModelDeltaDecoration));
        final actualNewDecorations = readModelDecorations(model, newIds);

        assertEquals(newIds.length, newDecorations.length, 'returns expected cnt of ids');
        assertEquals(newIds.length, model.getAllDecorations().length, 'does not leak decorations');
        actualNewDecorations.sort((a, b) -> strcmp(a.id, b.id));
        newDecorations.sort((a, b) -> strcmp(a.id, b.id));
        assertDeepEquals(actualDecorations, decorations);

        model.dispose();
    }

    static function range(startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int):Range {
        return new Range(startLineNumber, startColumn, endLineNumber, endColumn);
    }

    // test('result respects input')
    function testResultRespectsInput():Void {
        final model = createTextModel([
            'Hello world,',
            'How are you?'
        ].join('\n'));

        final ids = model.deltaDecorations([], [
            toModelDeltaDecoration(decoration('a', 1, 1, 1, 12)),
            toModelDeltaDecoration(decoration('b', 2, 1, 2, 13))
        ]);

        assertDeepEquals(model.getDecorationRange(ids[0]), range(1, 1, 1, 12));
        assertDeepEquals(model.getDecorationRange(ids[1]), range(2, 1, 2, 13));

        model.dispose();
    }

    // test('deltaDecorations 1')
    function testDeltaDecorations1():Void {
        _testDeltaDecorations(
            [
                'This is a text',
                'That has multiple lines',
                'And is very friendly',
                'Towards testing'
            ],
            [
                decoration('a', 1, 1, 1, 2),
                decoration('b', 1, 1, 1, 15),
                decoration('c', 1, 1, 2, 1),
                decoration('d', 1, 1, 2, 24),
                decoration('e', 2, 1, 2, 24),
                decoration('f', 2, 1, 4, 16)
            ],
            [
                decoration('x', 1, 1, 1, 2),
                decoration('b', 1, 1, 1, 15),
                decoration('c', 1, 1, 2, 1),
                decoration('d', 1, 1, 2, 24),
                decoration('e', 2, 1, 2, 21),
                decoration('f', 2, 17, 4, 16)
            ]
        );
    }

    // test('deltaDecorations 2')
    function testDeltaDecorations2():Void {
        _testDeltaDecorations(
            [
                'This is a text',
                'That has multiple lines',
                'And is very friendly',
                'Towards testing'
            ],
            [
                decoration('a', 1, 1, 1, 2),
                decoration('b', 1, 2, 1, 3),
                decoration('c', 1, 3, 1, 4),
                decoration('d', 1, 4, 1, 5),
                decoration('e', 1, 5, 1, 6)
            ],
            [
                decoration('a', 1, 2, 1, 3),
                decoration('b', 1, 3, 1, 4),
                decoration('c', 1, 4, 1, 5),
                decoration('d', 1, 5, 1, 6)
            ]
        );
    }

    // test('deltaDecorations 3')
    function testDeltaDecorations3():Void {
        _testDeltaDecorations(
            [
                'This is a text',
                'That has multiple lines',
                'And is very friendly',
                'Towards testing'
            ],
            [
                decoration('a', 1, 1, 1, 2),
                decoration('b', 1, 2, 1, 3),
                decoration('c', 1, 3, 1, 4),
                decoration('d', 1, 4, 1, 5),
                decoration('e', 1, 5, 1, 6)
            ],
            []
        );
    }

    // test("issue #4317: editor.setDecorations doesn't update the hover message")
    function testIssue4317EditorSetDecorationsDoesnTUpdateTheHoverMessage():Void {

        final model = createTextModel('Hello world!');

        var ids = model.deltaDecorations([], [{
            range: {
                startLineNumber: 1,
                startColumn: 1,
                endLineNumber: 100,
                endColumn: 1
            },
            options: {
                description: 'test',
                hoverMessage: { value: 'hello1' }
            }
        }]);

        ids = model.deltaDecorations(ids, [{
            range: {
                startLineNumber: 1,
                startColumn: 1,
                endLineNumber: 100,
                endColumn: 1
            },
            options: {
                description: 'test',
                hoverMessage: { value: 'hello2' }
            }
        }]);

        final actualDecoration = model.getDecorationOptions(ids[0]);

        assertDeepEquals(actualDecoration.hoverMessage, { value: 'hello2' });

        model.dispose();
    }

    // test("model doesn't get confused with individual tracked ranges")
    function testModelDoesnTGetConfusedWithIndividualTrackedRanges():Void {
        final model = createTextModel([
            'Hello world,',
            'How are you?'
        ].join('\n'));

        final trackedRangeId = model.changeDecorations((changeAcessor) -> {
            return changeAcessor.addDecoration(
                {
                    startLineNumber: 1,
                    startColumn: 1,
                    endLineNumber: 1,
                    endColumn: 1
                },
                {
                    description: 'test',
                    stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges
                }
            );
        });
        model.changeDecorations((changeAccessor) -> {
            changeAccessor.removeDecoration(trackedRangeId);
        });

        var ids = model.deltaDecorations([], [
            toModelDeltaDecoration(decoration('a', 1, 1, 1, 12)),
            toModelDeltaDecoration(decoration('b', 2, 1, 2, 13))
        ]);

        assertDeepEquals(model.getDecorationRange(ids[0]), range(1, 1, 1, 12));
        assertDeepEquals(model.getDecorationRange(ids[1]), range(2, 1, 2, 13));

        ids = model.deltaDecorations(ids, [
            toModelDeltaDecoration(decoration('a', 1, 1, 1, 12)),
            toModelDeltaDecoration(decoration('b', 2, 1, 2, 13))
        ]);

        assertDeepEquals(model.getDecorationRange(ids[0]), range(1, 1, 1, 12));
        assertDeepEquals(model.getDecorationRange(ids[1]), range(2, 1, 2, 13));

        model.dispose();
    }

    // test("issue #16922: Clicking on link doesn't seem to do anything")
    function testIssue16922ClickingOnLinkDoesnTSeemToDoAnything():Void {
        final model = createTextModel([
            'Hello world,',
            'How are you?',
            'Fine.',
            'Good.',
        ].join('\n'));

        model.deltaDecorations([], [
            { range: new Range(1, 1, 1, 1), options: { description: 'test', className: '1' } },
            { range: new Range(1, 13, 1, 13), options: { description: 'test', className: '2' } },
            { range: new Range(2, 1, 2, 1), options: { description: 'test', className: '3' } },
            { range: new Range(2, 1, 2, 4), options: { description: 'test', className: '4' } },
            { range: new Range(2, 8, 2, 13), options: { description: 'test', className: '5' } },
            { range: new Range(3, 1, 4, 6), options: { description: 'test', className: '6' } },
            { range: new Range(1, 1, 3, 6), options: { description: 'test', className: 'x1' } },
            { range: new Range(2, 5, 2, 8), options: { description: 'test', className: 'x2' } },
            { range: new Range(1, 1, 2, 8), options: { description: 'test', className: 'x3' } },
            { range: new Range(2, 5, 3, 1), options: { description: 'test', className: 'x4' } },
        ]);

        final inRange = model.getDecorationsInRange(new Range(2, 6, 2, 6));

        final inRangeClassNames = inRange.map(d -> d.options.className);
        inRangeClassNames.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        assertDeepEquals(inRangeClassNames, ['x1', 'x2', 'x3', 'x4']);

        model.dispose();
    }

    // test('issue #41492: URL highlighting persists after pasting over url')
    function testIssue41492URLHighlightingPersistsAfterPastingOverUrl():Void {

        final model = createTextModel([
            'My First Line'
        ].join('\n'));

        final id = model.deltaDecorations([], [{ range: new Range(1, 2, 1, 14), options: { description: 'test', stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, collapseOnReplaceEdit: true } }])[0];
        model.applyEdits([{
            range: new Range(1, 1, 1, 14),
            text: 'Some new text that is longer than the previous one',
            forceMoveMarkers: false
        }]);
        final actual = model.getDecorationRange(id);
        assertDeepEquals(actual, new Range(1, 1, 1, 1));

        model.dispose();
    }

}

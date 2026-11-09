// Ported from vscode src/vs/editor/test/common/model/modelEditOperation.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes of this module:
// - EditorModelModelEditOperationTest

import cityscape.common.Model;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

/**
 * suite('Editor Model - Model Edit Operation')
 */
class EditorModelModelEditOperationTest extends TestCase {

    static final LINE1 = 'My First Line';
    static final LINE2 = '\t\tMy Second Line';
    static final LINE3 = '    Third Line';
    static final LINE4 = '';
    static final LINE5 = '1';

    var model:TextModel;

    override function setup():Void {
        final text =
            LINE1 + '\r\n' +
            LINE2 + '\n' +
            LINE3 + '\n' +
            LINE4 + '\r\n' +
            LINE5;
        model = createTextModel(text);
    }

    override function teardown():Void {
        model.dispose();
    }

    static function createSingleEditOp(text:String, positionLineNumber:Int, positionColumn:Int, ?selectionLineNumber:Int, ?selectionColumn:Int):ISingleEditOperation {
        if (selectionLineNumber == null) {
            selectionLineNumber = positionLineNumber;
        }
        if (selectionColumn == null) {
            selectionColumn = positionColumn;
        }
        final range = new Range(
            selectionLineNumber,
            selectionColumn,
            positionLineNumber,
            positionColumn
        );

        return {
            range: range,
            text: text,
            forceMoveMarkers: false
        };
    }

    static function simplifyEdit(edit:Dynamic):{range:Dynamic, text:Null<String>, forceMoveMarkers:Bool} {
        return {
            range: edit.range,
            text: edit.text,
            forceMoveMarkers: edit.forceMoveMarkers == true
        };
    }

    function assertSingleEditOp(singleEditOp:ISingleEditOperation, editedLines:Array<String>):Void {
        final editOp:Array<IIdentifiedSingleEditOperation> = [cast singleEditOp];

        final inverseEditOp = model.applyEdits(editOp, true);

        assertEquals(model.getLineCount(), editedLines.length);
        for (i in 0...editedLines.length) {
            assertEquals(model.getLineContent(i + 1), editedLines[i]);
        }

        // IValidEditOperation has the fields read by applyEdits (range, text, identifier)
        final originalOp = model.applyEdits(cast inverseEditOp, true);

        assertEquals(model.getLineCount(), 5);
        assertEquals(model.getLineContent(1), LINE1);
        assertEquals(model.getLineContent(2), LINE2);
        assertEquals(model.getLineContent(3), LINE3);
        assertEquals(model.getLineContent(4), LINE4);
        assertEquals(model.getLineContent(5), LINE5);

        assertDeepEquals(originalOp.map(simplifyEdit), editOp.map(simplifyEdit));
    }

    function testInsertInline() {
        assertSingleEditOp(
            createSingleEditOp('a', 1, 1),
            [
                'aMy First Line',
                LINE2,
                LINE3,
                LINE4,
                LINE5
            ]
        );
    }

    function testReplaceInlineInline1() {
        assertSingleEditOp(
            createSingleEditOp(' incredibly awesome', 1, 3),
            [
                'My incredibly awesome First Line',
                LINE2,
                LINE3,
                LINE4,
                LINE5
            ]
        );
    }

    function testReplaceInlineInline2() {
        assertSingleEditOp(
            createSingleEditOp(' with text at the end.', 1, 14),
            [
                'My First Line with text at the end.',
                LINE2,
                LINE3,
                LINE4,
                LINE5
            ]
        );
    }

    function testReplaceInlineInline3() {
        assertSingleEditOp(
            createSingleEditOp('My new First Line.', 1, 1, 1, 14),
            [
                'My new First Line.',
                LINE2,
                LINE3,
                LINE4,
                LINE5
            ]
        );
    }

    function testReplaceInlineMultiLine1() {
        assertSingleEditOp(
            createSingleEditOp('My new First Line.', 1, 1, 3, 15),
            [
                'My new First Line.',
                LINE4,
                LINE5
            ]
        );
    }

    function testReplaceInlineMultiLine2() {
        assertSingleEditOp(
            createSingleEditOp('My new First Line.', 1, 2, 3, 15),
            [
                'MMy new First Line.',
                LINE4,
                LINE5
            ]
        );
    }

    function testReplaceInlineMultiLine3() {
        assertSingleEditOp(
            createSingleEditOp('My new First Line.', 1, 2, 3, 2),
            [
                'MMy new First Line.   Third Line',
                LINE4,
                LINE5
            ]
        );
    }

    function testReplaceMuliLineMultiLine() {
        assertSingleEditOp(
            createSingleEditOp('1\n2\n3\n4\n', 1, 1),
            [
                '1',
                '2',
                '3',
                '4',
                LINE1,
                LINE2,
                LINE3,
                LINE4,
                LINE5
            ]
        );
    }

}

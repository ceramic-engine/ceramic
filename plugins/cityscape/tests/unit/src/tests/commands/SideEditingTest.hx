// Ported from vscode src/vs/editor/test/browser/commands/sideEditing.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.commands;

// Classes of this module:
// - EditorSideEditingCollapsedSelectionTest
// - SideEditingTest

import cityscape.common.Model;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import testing.TestCase;
import testing.TestCodeEditor;

/**
 * suite('Editor Side Editing - collapsed selection')
 */
class EditorSideEditingCollapsedSelectionTest extends TestCase {

    function doTestCommand(lines:Array<String>, selections:Array<Selection>, edits:Array<IIdentifiedSingleEditOperation>, expectedLines:Array<String>, expectedSelections:Array<Selection>, ?pos:haxe.PosInfos):Void {
        TestCodeEditor.withTestCodeEditor(lines, {}, (editor, viewModel) -> {
            final model = editor.getModel();

            viewModel.setSelections('tests', selections);

            model.applyEdits(edits);

            assertDeepEquals(expectedLines, model.getLinesContent(), null, pos);

            final actualSelections = viewModel.getSelections();
            assertDeepEquals([for (s in expectedSelections) s.toString()], [for (s in actualSelections) s.toString()], null, pos);
        });
    }

    /**
     * test('replace at selection')
     */
    function testReplaceAtSelection() {
        doTestCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth'
            ],
            [new Selection(1, 1, 1, 1)],
            [
                EditOperation.replace(new Selection(1, 1, 1, 1), 'something ')
            ],
            [
                'something first',
                'second line',
                'third line',
                'fourth'
            ],
            [new Selection(1, 11, 1, 11)]
        );
    }

    /**
     * test('replace at selection 2')
     */
    function testReplaceAtSelection2() {
        doTestCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth'
            ],
            [new Selection(1, 1, 1, 6)],
            [
                EditOperation.replace(new Selection(1, 1, 1, 6), 'something')
            ],
            [
                'something',
                'second line',
                'third line',
                'fourth'
            ],
            [new Selection(1, 1, 1, 10)]
        );
    }

    /**
     * test('insert at selection')
     */
    function testInsertAtSelection() {
        doTestCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth'
            ],
            [new Selection(1, 1, 1, 1)],
            [
                EditOperation.insert(new Position(1, 1), 'something ')
            ],
            [
                'something first',
                'second line',
                'third line',
                'fourth'
            ],
            [new Selection(1, 11, 1, 11)]
        );
    }

    /**
     * test('insert at selection sitting on max column')
     */
    function testInsertAtSelectionSittingOnMaxColumn() {
        doTestCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth'
            ],
            [new Selection(1, 6, 1, 6)],
            [
                EditOperation.insert(new Position(1, 6), ' something\nnew ')
            ],
            [
                'first something',
                'new ',
                'second line',
                'third line',
                'fourth'
            ],
            [new Selection(2, 5, 2, 5)]
        );
    }

    /**
     * test('issue #3994: replace on top of selection')
     */
    function testIssue3994ReplaceOnTopOfSelection() {
        doTestCommand(
            [
                '$$obj = New-Object "system.col"'
            ],
            [new Selection(1, 30, 1, 30)],
            [
                EditOperation.replaceMove(new Range(1, 19, 1, 31), '"System.Collections"')
            ],
            [
                '$$obj = New-Object "System.Collections"'
            ],
            [new Selection(1, 39, 1, 39)]
        );
    }

    /**
     * test('issue #15267: Suggestion that adds a line - cursor goes to the wrong line ')
     */
    function testIssue15267SuggestionThatAddsALineCursorGoesToTheWrongLine() {
        doTestCommand(
            [
                'package main',
                '',
                'import (',
                '\t"fmt"',
                ')',
                '',
                'func main(',
                '\tfmt.Println(strings.Con)',
                '}'
            ],
            [new Selection(8, 25, 8, 25)],
            [
                EditOperation.replaceMove(new Range(5, 1, 5, 1), '\t\"strings\"\n')
            ],
            [
                'package main',
                '',
                'import (',
                '\t"fmt"',
                '\t"strings"',
                ')',
                '',
                'func main(',
                '\tfmt.Println(strings.Con)',
                '}'
            ],
            [new Selection(9, 25, 9, 25)]
        );
    }

    /**
     * test('issue #15236: Selections broke after deleting text using vscode.TextEditor.edit ')
     */
    function testIssue15236SelectionsBrokeAfterDeletingTextUsingVscodeTextEditorEdit() {
        doTestCommand(
            [
                'foofoofoo, foofoofoo, bar'
            ],
            [new Selection(1, 1, 1, 10), new Selection(1, 12, 1, 21)],
            [
                EditOperation.replace(new Range(1, 1, 1, 10), ''),
                EditOperation.replace(new Range(1, 12, 1, 21), ''),
            ],
            [
                ', , bar'
            ],
            [new Selection(1, 1, 1, 1), new Selection(1, 3, 1, 3)]
        );
    }

}

/**
 * suite('SideEditing'), its suites 'insert', 'delete', 'replace short' and
 * 'replace long' (their nested suites prefix the test names).
 */
class SideEditingTest extends TestCase {

    static final LINES = [
        'My First Line',
        'My Second Line',
        'Third Line'
    ];

    function _runTest(selection:Selection, editRange:Range, editText:String, editForceMoveMarkers:Bool, expected:Selection, msg:String, ?pos:haxe.PosInfos):Void {
        TestCodeEditor.withTestCodeEditor(LINES.join('\n'), {}, (editor, viewModel) -> {
            viewModel.setSelections('tests', [selection]);
            editor.getModel().applyEdits([{
                range: editRange,
                text: editText,
                forceMoveMarkers: editForceMoveMarkers
            }]);
            final actual = viewModel.getSelection();
            assertDeepEquals(expected.toString(), actual.toString(), msg, pos);
        });
    }

    function runTest(selection:Range, editRange:Range, editText:String, expected:Array<Array<Selection>>, ?pos:haxe.PosInfos):Void {
        final sel1 = new Selection(selection.startLineNumber, selection.startColumn, selection.endLineNumber, selection.endColumn);
        _runTest(sel1, editRange, editText, false, expected[0][0], '0-0-regular-no-force', pos);
        _runTest(sel1, editRange, editText, true, expected[1][0], '1-0-regular-force', pos);

        // RTL selection
        final sel2 = new Selection(selection.endLineNumber, selection.endColumn, selection.startLineNumber, selection.startColumn);
        _runTest(sel2, editRange, editText, false, expected[0][1], '0-1-inverse-no-force', pos);
        _runTest(sel2, editRange, editText, true, expected[1][1], '1-1-inverse-force', pos);
    }

    /**
     * test('before')
     */
    function testInsertCollapsedSelBefore() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 3, 1, 3), 'xx',
            [
                [new Selection(1, 6, 1, 6), new Selection(1, 6, 1, 6)],
                [new Selection(1, 6, 1, 6), new Selection(1, 6, 1, 6)],
            ]
        );
    }

    /**
     * test('equal')
     */
    function testInsertCollapsedSelEqual() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 4, 1, 4), 'xx',
            [
                [new Selection(1, 6, 1, 6), new Selection(1, 6, 1, 6)],
                [new Selection(1, 6, 1, 6), new Selection(1, 6, 1, 6)],
            ]
        );
    }

    /**
     * test('after')
     */
    function testInsertCollapsedSelAfter() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 5, 1, 5), 'xx',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('before')
     */
    function testInsertNonCollapsedDecBefore() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 3), 'xx',
            [
                [new Selection(1, 6, 1, 11), new Selection(1, 11, 1, 6)],
                [new Selection(1, 6, 1, 11), new Selection(1, 11, 1, 6)],
            ]
        );
    }

    /**
     * test('start')
     */
    function testInsertNonCollapsedDecStart() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 4), 'xx',
            [
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
                [new Selection(1, 6, 1, 11), new Selection(1, 11, 1, 6)],
            ]
        );
    }

    /**
     * test('inside')
     */
    function testInsertNonCollapsedDecInside() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 5), 'xx',
            [
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
            ]
        );
    }

    /**
     * test('end')
     */
    function testInsertNonCollapsedDecEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 9, 1, 9), 'xx',
            [
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
            ]
        );
    }

    /**
     * test('after')
     */
    function testInsertNonCollapsedDecAfter() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 10, 1, 10), 'xx',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.end < range.start')
     */
    function testDeleteCollapsedDecEditEndRangeStart() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 1, 1, 3), '',
            [
                [new Selection(1, 2, 1, 2), new Selection(1, 2, 1, 2)],
                [new Selection(1, 2, 1, 2), new Selection(1, 2, 1, 2)],
            ]
        );
    }

    /**
     * test('edit.end <= range.start')
     */
    function testDeleteCollapsedDecEditEndRangeStart_2() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 2, 1, 4), '',
            [
                [new Selection(1, 2, 1, 2), new Selection(1, 2, 1, 2)],
                [new Selection(1, 2, 1, 2), new Selection(1, 2, 1, 2)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end > range.end')
     */
    function testDeleteCollapsedDecEditStartRangeStartEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 3, 1, 5), '',
            [
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
            ]
        );
    }

    /**
     * test('edit.start >= range.end')
     */
    function testDeleteCollapsedDecEditStartRangeEnd() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 4, 1, 6), '',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.end')
     */
    function testDeleteCollapsedDecEditStartRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 5, 1, 7), '',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.end < range.start')
     */
    function testDeleteNonCollapsedDecEditEndRangeStart() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 1, 1, 3), '',
            [
                [new Selection(1, 2, 1, 7), new Selection(1, 7, 1, 2)],
                [new Selection(1, 2, 1, 7), new Selection(1, 7, 1, 2)],
            ]
        );
    }

    /**
     * test('edit.end <= range.start')
     */
    function testDeleteNonCollapsedDecEditEndRangeStart_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 2, 1, 4), '',
            [
                [new Selection(1, 2, 1, 7), new Selection(1, 7, 1, 2)],
                [new Selection(1, 2, 1, 7), new Selection(1, 7, 1, 2)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end < range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 5), '',
            [
                [new Selection(1, 3, 1, 7), new Selection(1, 7, 1, 3)],
                [new Selection(1, 3, 1, 7), new Selection(1, 7, 1, 3)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end == range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditEndRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 9), '',
            [
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end > range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditEndRangeEnd_3() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 10), '',
            [
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end < range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditEndRangeEnd_4() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 6), '',
            [
                [new Selection(1, 4, 1, 7), new Selection(1, 7, 1, 4)],
                [new Selection(1, 4, 1, 7), new Selection(1, 7, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end == range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditEndRangeEnd_5() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 9), '',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end > range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditEndRangeEnd_6() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 10), '',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end < range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 7), '',
            [
                [new Selection(1, 4, 1, 7), new Selection(1, 7, 1, 4)],
                [new Selection(1, 4, 1, 7), new Selection(1, 7, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end == range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 9), '',
            [
                [new Selection(1, 4, 1, 5), new Selection(1, 5, 1, 4)],
                [new Selection(1, 4, 1, 5), new Selection(1, 5, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end > range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd_3() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 10), '',
            [
                [new Selection(1, 4, 1, 5), new Selection(1, 5, 1, 4)],
                [new Selection(1, 4, 1, 5), new Selection(1, 5, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start == range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 9, 1, 11), '',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.end')
     */
    function testDeleteNonCollapsedDecEditStartRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 10, 1, 11), '',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.end < range.start')
     */
    function testReplaceShortCollapsedDecEditEndRangeStart() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 1, 1, 3), 'c',
            [
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
            ]
        );
    }

    /**
     * test('edit.end <= range.start')
     */
    function testReplaceShortCollapsedDecEditEndRangeStart_2() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 2, 1, 4), 'c',
            [
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
                [new Selection(1, 3, 1, 3), new Selection(1, 3, 1, 3)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end > range.end')
     */
    function testReplaceShortCollapsedDecEditStartRangeStartEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 3, 1, 5), 'c',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start >= range.end')
     */
    function testReplaceShortCollapsedDecEditStartRangeEnd() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 4, 1, 6), 'c',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 5, 1, 5), new Selection(1, 5, 1, 5)],
            ]
        );
    }

    /**
     * test('edit.start > range.end')
     */
    function testReplaceShortCollapsedDecEditStartRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 5, 1, 7), 'c',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.end < range.start')
     */
    function testReplaceShortNonCollapsedDecEditEndRangeStart() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 1, 1, 3), 'c',
            [
                [new Selection(1, 3, 1, 8), new Selection(1, 8, 1, 3)],
                [new Selection(1, 3, 1, 8), new Selection(1, 8, 1, 3)],
            ]
        );
    }

    /**
     * test('edit.end <= range.start')
     */
    function testReplaceShortNonCollapsedDecEditEndRangeStart_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 2, 1, 4), 'c',
            [
                [new Selection(1, 3, 1, 8), new Selection(1, 8, 1, 3)],
                [new Selection(1, 3, 1, 8), new Selection(1, 8, 1, 3)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end < range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 5), 'c',
            [
                [new Selection(1, 4, 1, 8), new Selection(1, 8, 1, 4)],
                [new Selection(1, 4, 1, 8), new Selection(1, 8, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end == range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditEndRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 9), 'c',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end > range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditEndRangeEnd_3() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 10), 'c',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end < range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditEndRangeEnd_4() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 6), 'c',
            [
                [new Selection(1, 4, 1, 8), new Selection(1, 8, 1, 4)],
                [new Selection(1, 5, 1, 8), new Selection(1, 8, 1, 5)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end == range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditEndRangeEnd_5() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 9), 'c',
            [
                [new Selection(1, 4, 1, 5), new Selection(1, 5, 1, 4)],
                [new Selection(1, 5, 1, 5), new Selection(1, 5, 1, 5)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end > range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditEndRangeEnd_6() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 10), 'c',
            [
                [new Selection(1, 4, 1, 5), new Selection(1, 5, 1, 4)],
                [new Selection(1, 5, 1, 5), new Selection(1, 5, 1, 5)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end < range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 7), 'c',
            [
                [new Selection(1, 4, 1, 8), new Selection(1, 8, 1, 4)],
                [new Selection(1, 4, 1, 8), new Selection(1, 8, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end == range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 9), 'c',
            [
                [new Selection(1, 4, 1, 6), new Selection(1, 6, 1, 4)],
                [new Selection(1, 4, 1, 6), new Selection(1, 6, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end > range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd_3() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 10), 'c',
            [
                [new Selection(1, 4, 1, 6), new Selection(1, 6, 1, 4)],
                [new Selection(1, 4, 1, 6), new Selection(1, 6, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start == range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 9, 1, 11), 'c',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 10), new Selection(1, 10, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.end')
     */
    function testReplaceShortNonCollapsedDecEditStartRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 10, 1, 11), 'c',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.end < range.start')
     */
    function testReplaceLongCollapsedDecEditEndRangeStart() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 1, 1, 3), 'cccc',
            [
                [new Selection(1, 6, 1, 6), new Selection(1, 6, 1, 6)],
                [new Selection(1, 6, 1, 6), new Selection(1, 6, 1, 6)],
            ]
        );
    }

    /**
     * test('edit.end <= range.start')
     */
    function testReplaceLongCollapsedDecEditEndRangeStart_2() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 2, 1, 4), 'cccc',
            [
                [new Selection(1, 6, 1, 6), new Selection(1, 6, 1, 6)],
                [new Selection(1, 6, 1, 6), new Selection(1, 6, 1, 6)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end > range.end')
     */
    function testReplaceLongCollapsedDecEditStartRangeStartEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 3, 1, 5), 'cccc',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 7, 1, 7), new Selection(1, 7, 1, 7)],
            ]
        );
    }

    /**
     * test('edit.start >= range.end')
     */
    function testReplaceLongCollapsedDecEditStartRangeEnd() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 4, 1, 6), 'cccc',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 8, 1, 8), new Selection(1, 8, 1, 8)],
            ]
        );
    }

    /**
     * test('edit.start > range.end')
     */
    function testReplaceLongCollapsedDecEditStartRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 4),
            new Range(1, 5, 1, 7), 'cccc',
            [
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
                [new Selection(1, 4, 1, 4), new Selection(1, 4, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.end < range.start')
     */
    function testReplaceLongNonCollapsedDecEditEndRangeStart() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 1, 1, 3), 'cccc',
            [
                [new Selection(1, 6, 1, 11), new Selection(1, 11, 1, 6)],
                [new Selection(1, 6, 1, 11), new Selection(1, 11, 1, 6)],
            ]
        );
    }

    /**
     * test('edit.end <= range.start')
     */
    function testReplaceLongNonCollapsedDecEditEndRangeStart_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 2, 1, 4), 'cccc',
            [
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
                [new Selection(1, 6, 1, 11), new Selection(1, 11, 1, 6)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end < range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 5), 'cccc',
            [
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
                [new Selection(1, 7, 1, 11), new Selection(1, 11, 1, 7)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end == range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditEndRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 9), 'cccc',
            [
                [new Selection(1, 4, 1, 7), new Selection(1, 7, 1, 4)],
                [new Selection(1, 7, 1, 7), new Selection(1, 7, 1, 7)],
            ]
        );
    }

    /**
     * test('edit.start < range.start && edit.end > range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditEndRangeEnd_3() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 3, 1, 10), 'cccc',
            [
                [new Selection(1, 4, 1, 7), new Selection(1, 7, 1, 4)],
                [new Selection(1, 7, 1, 7), new Selection(1, 7, 1, 7)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end < range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditEndRangeEnd_4() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 6), 'cccc',
            [
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
                [new Selection(1, 8, 1, 11), new Selection(1, 11, 1, 8)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end == range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditEndRangeEnd_5() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 9), 'cccc',
            [
                [new Selection(1, 4, 1, 8), new Selection(1, 8, 1, 4)],
                [new Selection(1, 8, 1, 8), new Selection(1, 8, 1, 8)],
            ]
        );
    }

    /**
     * test('edit.start == range.start && edit.end > range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditEndRangeEnd_6() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 4, 1, 10), 'cccc',
            [
                [new Selection(1, 4, 1, 8), new Selection(1, 8, 1, 4)],
                [new Selection(1, 8, 1, 8), new Selection(1, 8, 1, 8)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end < range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 7), 'cccc',
            [
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
                [new Selection(1, 4, 1, 11), new Selection(1, 11, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end == range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 9), 'cccc',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.start && edit.start < range.end && edit.end > range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeStartEditStartRangeEndEditEndRangeEnd_3() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 5, 1, 10), 'cccc',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start == range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeEnd() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 9, 1, 11), 'cccc',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 13), new Selection(1, 13, 1, 4)],
            ]
        );
    }

    /**
     * test('edit.start > range.end')
     */
    function testReplaceLongNonCollapsedDecEditStartRangeEnd_2() {
        runTest(
            new Range(1, 4, 1, 9),
            new Range(1, 10, 1, 11), 'cccc',
            [
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
                [new Selection(1, 4, 1, 9), new Selection(1, 9, 1, 4)],
            ]
        );
    }

}

// Ported from vscode src/vs/editor/contrib/linesOperations/test/browser/copyLinesCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.linesOperations;

import cityscape.common.core.Selection;
import cityscape.contrib.linesOperations.view.CopyLinesCommand;
import cityscape.contrib.linesOperations.view.LinesOperations.DuplicateSelectionAction;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.TestCommand;

/**
 * suite('Editor Contrib - Copy Lines Command')
 */
class CopyLinesCommandTest extends TestCase {

    function doTestCopyLinesDownCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(this, lines, null, selection, (accessor, sel) -> new CopyLinesCommand(sel, true), expectedLines, expectedSelection, null, null, pos);
    }

    function doTestCopyLinesUpCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(this, lines, null, selection, (accessor, sel) -> new CopyLinesCommand(sel, false), expectedLines, expectedSelection, null, null, pos);
    }

    /**
     * test('copy first line down')
     */
    function testCopyFirstLineDown() {
        doTestCopyLinesDownCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 1),
            [
                'first',
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 3, 2, 1)
        );
    }

    /**
     * test('copy first line up')
     */
    function testCopyFirstLineUp() {
        doTestCopyLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 1),
            [
                'first',
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 1)
        );
    }

    /**
     * test('copy last line down')
     */
    function testCopyLastLineDown() {
        doTestCopyLinesDownCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 3, 5, 1),
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth',
                'fifth'
            ],
            new Selection(6, 3, 6, 1)
        );
    }

    /**
     * test('copy last line up')
     */
    function testCopyLastLineUp() {
        doTestCopyLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 3, 5, 1),
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth',
                'fifth'
            ],
            new Selection(5, 3, 5, 1)
        );
    }

    /**
     * test('issue #1322: copy line up')
     */
    function testIssue1322CopyLineUp() {
        doTestCopyLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 11, 3, 11),
            [
                'first',
                'second line',
                'third line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 11, 3, 11)
        );
    }

    /**
     * test('issue #1322: copy last line up')
     */
    function testIssue1322CopyLastLineUp() {
        doTestCopyLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 6, 5, 6),
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth',
                'fifth'
            ],
            new Selection(5, 6, 5, 6)
        );
    }

    /**
     * test('copy many lines up')
     */
    function testCopyManyLinesUp() {
        doTestCopyLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(4, 3, 2, 1),
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(4, 3, 2, 1)
        );
    }

    /**
     * test('ignore empty selection')
     */
    function testIgnoreEmptySelection() {
        doTestCopyLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 1, 1),
            [
                'first',
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 1, 1)
        );
    }

}

/**
 * suite('Editor Contrib - Duplicate Selection')
 */
class EditorContribDuplicateSelectionTest extends TestCase {

    final duplicateSelectionAction = new DuplicateSelectionAction();

    function doTestDuplicateSelectionAction(lines:Array<String>, selections:Array<Selection>, expectedLines:Array<String>, expectedSelections:Array<Selection>, ?pos:haxe.PosInfos):Void {
        TestCodeEditor.withTestCodeEditor(lines.join('\n'), {}, (editor, _) -> {
            editor.setSelections(cast selections);
            duplicateSelectionAction.run(null, editor, {});
            assertDeepEquals(expectedLines.join('\n'), editor.getValue(), null, pos);
            assertDeepEquals(expectedSelections.map(s -> s.toString()), editor.getSelections().map(s -> s.toString()), null, pos);
        });
    }

    /**
     * test('empty selection')
     */
    function testEmptySelection() {
        doTestDuplicateSelectionAction(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            [new Selection(2, 2, 2, 2), new Selection(3, 2, 3, 2)],
            [
                'first',
                'second line',
                'second line',
                'third line',
                'third line',
                'fourth line',
                'fifth'
            ],
            [new Selection(3, 2, 3, 2), new Selection(5, 2, 5, 2)]
        );
    }

    /**
     * test('with selection')
     */
    function testWithSelection() {
        doTestDuplicateSelectionAction(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            [new Selection(2, 1, 2, 4), new Selection(3, 1, 3, 4)],
            [
                'first',
                'secsecond line',
                'thithird line',
                'fourth line',
                'fifth'
            ],
            [new Selection(2, 4, 2, 7), new Selection(3, 4, 3, 7)]
        );
    }

}

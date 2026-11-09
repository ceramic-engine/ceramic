// Ported from vscode src/vs/editor/contrib/caretOperations/test/browser/moveCarretCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.caretOperations;

import cityscape.common.core.Selection;
import cityscape.contrib.caretOperations.view.MoveCaretCommand;
import testing.TestCase;
import testing.TestCommand;

/**
 * suite('Editor Contrib - Move Caret Command')
 */
class MoveCaretCommandTest extends TestCase {

    function doTestMoveCaretLeftCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(this, lines, null, selection, (accessor, sel) -> new MoveCaretCommand(sel, true), expectedLines, expectedSelection, null, null, pos);
    }

    function doTestMoveCaretRightCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(this, lines, null, selection, (accessor, sel) -> new MoveCaretCommand(sel, false), expectedLines, expectedSelection, null, null, pos);
    }

    function testMoveSelectionToLeft() {
        doTestMoveCaretLeftCommand(
            [
                '012345'
            ],
            new Selection(1, 3, 1, 5),
            [
                '023145'
            ],
            new Selection(1, 2, 1, 4)
        );
    }

    function testMoveSelectionToRight() {
        doTestMoveCaretRightCommand(
            [
                '012345'
            ],
            new Selection(1, 3, 1, 5),
            [
                '014235'
            ],
            new Selection(1, 4, 1, 6)
        );
    }

    function testMoveSelectionToLeftFromFirstColumnNoChange() {
        doTestMoveCaretLeftCommand(
            [
                '012345'
            ],
            new Selection(1, 1, 1, 1),
            [
                '012345'
            ],
            new Selection(1, 1, 1, 1)
        );
    }

    function testMoveSelectionToRightFromLastColumnNoChange() {
        doTestMoveCaretRightCommand(
            [
                '012345'
            ],
            new Selection(1, 5, 1, 7),
            [
                '012345'
            ],
            new Selection(1, 5, 1, 7)
        );
    }

}

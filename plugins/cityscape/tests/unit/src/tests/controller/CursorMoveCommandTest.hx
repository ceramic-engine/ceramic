// Ported from vscode src/vs/editor/test/browser/controller/cursorMoveCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.controller;

// Classes of this module:
// - CursorMoveCommandTest
// - CursorMoveByBlanklineTest

import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.CursorMoveCommands;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.view.CoreCommands;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions.EditorCommand;
import testing.TestCase;
import testing.TestCodeEditor;

/**
 * The helpers of cursorMoveCommand.test.ts (module functions).
 */
class CursorMoveCommandTestBase extends TestCase {

    // Move command

    function move(viewModel:ViewModel, args:CoreCommandArgs):Void {
        CoreNavigationCommands.CursorMove.runCoreEditorCommand(viewModel, args);
    }

    function moveToLineStart(viewModel:ViewModel):Void {
        move(viewModel, {to: CursorMove.RawDirection.WrappedLineStart});
    }

    function moveToLineFirstNonWhitespaceCharacter(viewModel:ViewModel):Void {
        move(viewModel, {to: CursorMove.RawDirection.WrappedLineFirstNonWhitespaceCharacter});
    }

    function moveToLineCenter(viewModel:ViewModel):Void {
        move(viewModel, {to: CursorMove.RawDirection.WrappedLineColumnCenter});
    }

    function moveToLineEnd(viewModel:ViewModel):Void {
        move(viewModel, {to: CursorMove.RawDirection.WrappedLineEnd});
    }

    function moveToLineLastNonWhitespaceCharacter(viewModel:ViewModel):Void {
        move(viewModel, {to: CursorMove.RawDirection.WrappedLineLastNonWhitespaceCharacter});
    }

    function moveLeft(viewModel:ViewModel, ?value:Int, ?by:String, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.Left, by: by, value: value, select: select});
    }

    function moveRight(viewModel:ViewModel, ?value:Int, ?by:String, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.Right, by: by, value: value, select: select});
    }

    function moveUp(viewModel:ViewModel, noOfLines:Int = 1, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.Up, by: CursorMove.RawUnit.WrappedLine, value: noOfLines, select: select});
    }

    function moveUpByBlankLine(viewModel:ViewModel, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.PrevBlankLine, by: CursorMove.RawUnit.WrappedLine, select: select});
    }

    function moveUpByModelLine(viewModel:ViewModel, noOfLines:Int = 1, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.Up, value: noOfLines, select: select});
    }

    function moveDown(viewModel:ViewModel, noOfLines:Int = 1, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.Down, by: CursorMove.RawUnit.WrappedLine, value: noOfLines, select: select});
    }

    function moveDownByBlankLine(viewModel:ViewModel, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.NextBlankLine, by: CursorMove.RawUnit.WrappedLine, select: select});
    }

    function moveDownByModelLine(viewModel:ViewModel, noOfLines:Int = 1, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.Down, value: noOfLines, select: select});
    }

    function moveToTop(viewModel:ViewModel, noOfLines:Int = 1, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.ViewPortTop, value: noOfLines, select: select});
    }

    function moveToCenter(viewModel:ViewModel, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.ViewPortCenter, select: select});
    }

    function moveToBottom(viewModel:ViewModel, noOfLines:Int = 1, ?select:Bool):Void {
        move(viewModel, {to: CursorMove.RawDirection.ViewPortBottom, value: noOfLines, select: select});
    }

    function cursorEqual(viewModel:ViewModel, posLineNumber:Int, posColumn:Int, ?selLineNumber:Int, ?selColumn:Int, ?pos:haxe.PosInfos):Void {
        if (selLineNumber == null) {
            selLineNumber = posLineNumber;
        }
        if (selColumn == null) {
            selColumn = posColumn;
        }
        positionEqual(viewModel.getPosition(), posLineNumber, posColumn, pos);
        selectionEqual(viewModel.getSelection(), posLineNumber, posColumn, selLineNumber, selColumn, pos);
    }

    function positionEqual(position:Position, lineNumber:Int, column:Int, ?pos:haxe.PosInfos):Void {
        assertDeepEquals(new Position(lineNumber, column), position, 'position equal', pos);
    }

    function selectionEqual(selection:Selection, posLineNumber:Int, posColumn:Int, selLineNumber:Int, selColumn:Int, ?pos:haxe.PosInfos):Void {
        assertDeepEquals({
            selectionStartLineNumber: selLineNumber,
            selectionStartColumn: selColumn,
            positionLineNumber: posLineNumber,
            positionColumn: posColumn
        }, {
            selectionStartLineNumber: selection.selectionStartLineNumber,
            selectionStartColumn: selection.selectionStartColumn,
            positionLineNumber: selection.positionLineNumber,
            positionColumn: selection.positionColumn
        }, 'selection equal', pos);
    }

    function moveTo(viewModel:ViewModel, lineNumber:Int, column:Int, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.MoveToSelect.runCoreEditorCommand(viewModel, {
                position: new Position(lineNumber, column)
            });
        }
        else {
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, {
                position: new Position(lineNumber, column)
            });
        }
    }

    function moveToEndOfLine(viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorEndSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorEnd.runCoreEditorCommand(viewModel, {});
        }
    }

}

/**
 * suite('Cursor move command test')
 */
class CursorMoveCommandTest extends CursorMoveCommandTestBase {

    static final TEXT = [
        '    \tMy First Line\t ',
        '\tMy Second Line',
        '    Third Line🐶',
        '',
        '1'
    ].join('\n');

    function executeTest(callback:(editor:TestCodeEditor, viewModel:ViewModel) -> Void):Void {
        TestCodeEditor.withTestCodeEditor(TEXT, {}, (editor, viewModel) -> {
            callback(editor, viewModel);
        });
    }

    /**
     * test('move left should move to left character')
     */
    function testMoveLeftShouldMoveToLeftCharacter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveLeft(viewModel);
            cursorEqual(viewModel, 1, 7);
        });
    }

    /**
     * test('move left should move to left by n characters')
     */
    function testMoveLeftShouldMoveToLeftByNCharacters() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveLeft(viewModel, 3);
            cursorEqual(viewModel, 1, 5);
        });
    }

    /**
     * test('move left should move to left by half line')
     */
    function testMoveLeftShouldMoveToLeftByHalfLine() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveLeft(viewModel, 1, CursorMove.RawUnit.HalfLine);
            cursorEqual(viewModel, 1, 1);
        });
    }

    /**
     * test('move left moves to previous line')
     */
    function testMoveLeftMovesToPreviousLine() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 2, 3);
            moveLeft(viewModel, 10);
            cursorEqual(viewModel, 1, 21);
        });
    }

    /**
     * test('move right should move to right character')
     */
    function testMoveRightShouldMoveToRightCharacter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 5);
            moveRight(viewModel);
            cursorEqual(viewModel, 1, 6);
        });
    }

    /**
     * test('move right should move to right by n characters')
     */
    function testMoveRightShouldMoveToRightByNCharacters() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 2);
            moveRight(viewModel, 6);
            cursorEqual(viewModel, 1, 8);
        });
    }

    /**
     * test('move right should move to right by half line')
     */
    function testMoveRightShouldMoveToRightByHalfLine() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 4);
            moveRight(viewModel, 1, CursorMove.RawUnit.HalfLine);
            cursorEqual(viewModel, 1, 14);
        });
    }

    /**
     * test('move right moves to next line')
     */
    function testMoveRightMovesToNextLine() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveRight(viewModel, 100);
            cursorEqual(viewModel, 2, 1);
        });
    }

    /**
     * test('move to first character of line from middle')
     */
    function testMoveToFirstCharacterOfLineFromMiddle() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveToLineStart(viewModel);
            cursorEqual(viewModel, 1, 1);
        });
    }

    /**
     * test('move to first character of line from first non white space character')
     */
    function testMoveToFirstCharacterOfLineFromFirstNonWhiteSpaceCharacter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 6);
            moveToLineStart(viewModel);
            cursorEqual(viewModel, 1, 1);
        });
    }

    /**
     * test('move to first character of line from first character')
     */
    function testMoveToFirstCharacterOfLineFromFirstCharacter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 1);
            moveToLineStart(viewModel);
            cursorEqual(viewModel, 1, 1);
        });
    }

    /**
     * test('move to first non white space character of line from middle')
     */
    function testMoveToFirstNonWhiteSpaceCharacterOfLineFromMiddle() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveToLineFirstNonWhitespaceCharacter(viewModel);
            cursorEqual(viewModel, 1, 6);
        });
    }

    /**
     * test('move to first non white space character of line from first non white space character')
     */
    function testMoveToFirstNonWhiteSpaceCharacterOfLineFromFirstNonWhiteSpaceCharacter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 6);
            moveToLineFirstNonWhitespaceCharacter(viewModel);
            cursorEqual(viewModel, 1, 6);
        });
    }

    /**
     * test('move to first non white space character of line from first character')
     */
    function testMoveToFirstNonWhiteSpaceCharacterOfLineFromFirstCharacter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 1);
            moveToLineFirstNonWhitespaceCharacter(viewModel);
            cursorEqual(viewModel, 1, 6);
        });
    }

    /**
     * test('move to end of line from middle')
     */
    function testMoveToEndOfLineFromMiddle() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveToLineEnd(viewModel);
            cursorEqual(viewModel, 1, 21);
        });
    }

    /**
     * test('move to end of line from last non white space character')
     */
    function testMoveToEndOfLineFromLastNonWhiteSpaceCharacter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 19);
            moveToLineEnd(viewModel);
            cursorEqual(viewModel, 1, 21);
        });
    }

    /**
     * test('move to end of line from line end')
     */
    function testMoveToEndOfLineFromLineEnd() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 21);
            moveToLineEnd(viewModel);
            cursorEqual(viewModel, 1, 21);
        });
    }

    /**
     * test('move to last non white space character from middle')
     */
    function testMoveToLastNonWhiteSpaceCharacterFromMiddle() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveToLineLastNonWhitespaceCharacter(viewModel);
            cursorEqual(viewModel, 1, 19);
        });
    }

    /**
     * test('move to last non white space character from last non white space character')
     */
    function testMoveToLastNonWhiteSpaceCharacterFromLastNonWhiteSpaceCharacter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 19);
            moveToLineLastNonWhitespaceCharacter(viewModel);
            cursorEqual(viewModel, 1, 19);
        });
    }

    /**
     * test('move to last non white space character from line end')
     */
    function testMoveToLastNonWhiteSpaceCharacterFromLineEnd() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 21);
            moveToLineLastNonWhitespaceCharacter(viewModel);
            cursorEqual(viewModel, 1, 19);
        });
    }

    /**
     * test('move to center of line not from center')
     */
    function testMoveToCenterOfLineNotFromCenter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 8);
            moveToLineCenter(viewModel);
            cursorEqual(viewModel, 1, 11);
        });
    }

    /**
     * test('move to center of line from center')
     */
    function testMoveToCenterOfLineFromCenter() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 11);
            moveToLineCenter(viewModel);
            cursorEqual(viewModel, 1, 11);
        });
    }

    /**
     * test('move to center of line from start')
     */
    function testMoveToCenterOfLineFromStart() {
        executeTest((editor, viewModel) -> {
            moveToLineStart(viewModel);
            moveToLineCenter(viewModel);
            cursorEqual(viewModel, 1, 11);
        });
    }

    /**
     * test('move to center of line from end')
     */
    function testMoveToCenterOfLineFromEnd() {
        executeTest((editor, viewModel) -> {
            moveToLineEnd(viewModel);
            moveToLineCenter(viewModel);
            cursorEqual(viewModel, 1, 11);
        });
    }

    /**
     * test('move up by cursor move command')
     */
    function testMoveUpByCursorMoveCommand() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 3, 5);
            cursorEqual(viewModel, 3, 5);

            moveUp(viewModel, 2);
            cursorEqual(viewModel, 1, 5);

            moveUp(viewModel, 1);
            cursorEqual(viewModel, 1, 1);
        });
    }

    /**
     * test('move up by model line cursor move command')
     */
    function testMoveUpByModelLineCursorMoveCommand() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 3, 5);
            cursorEqual(viewModel, 3, 5);

            moveUpByModelLine(viewModel, 2);
            cursorEqual(viewModel, 1, 5);

            moveUpByModelLine(viewModel, 1);
            cursorEqual(viewModel, 1, 1);
        });
    }

    /**
     * test('move down by model line cursor move command')
     */
    function testMoveDownByModelLineCursorMoveCommand() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 3, 5);
            cursorEqual(viewModel, 3, 5);

            moveDownByModelLine(viewModel, 2);
            cursorEqual(viewModel, 5, 2);

            moveDownByModelLine(viewModel, 1);
            cursorEqual(viewModel, 5, 2);
        });
    }

    /**
     * test('move up with selection by cursor move command')
     */
    function testMoveUpWithSelectionByCursorMoveCommand() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 3, 5);
            cursorEqual(viewModel, 3, 5);

            moveUp(viewModel, 1, true);
            cursorEqual(viewModel, 2, 2, 3, 5);

            moveUp(viewModel, 1, true);
            cursorEqual(viewModel, 1, 5, 3, 5);
        });
    }

    /**
     * test('move up and down with tabs by cursor move command')
     */
    function testMoveUpAndDownWithTabsByCursorMoveCommand() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 1, 5);
            cursorEqual(viewModel, 1, 5);

            moveDown(viewModel, 4);
            cursorEqual(viewModel, 5, 2);

            moveUp(viewModel, 1);
            cursorEqual(viewModel, 4, 1);

            moveUp(viewModel, 1);
            cursorEqual(viewModel, 3, 5);

            moveUp(viewModel, 1);
            cursorEqual(viewModel, 2, 2);

            moveUp(viewModel, 1);
            cursorEqual(viewModel, 1, 5);
        });
    }

    /**
     * test('move up and down with end of lines starting from a long one by cursor move command')
     */
    function testMoveUpAndDownWithEndOfLinesStartingFromALongOneByCursorMoveCommand() {
        executeTest((editor, viewModel) -> {
            moveToEndOfLine(viewModel);
            cursorEqual(viewModel, 1, 21);

            moveToEndOfLine(viewModel);
            cursorEqual(viewModel, 1, 21);

            moveDown(viewModel, 2);
            cursorEqual(viewModel, 3, 17);

            moveDown(viewModel, 1);
            cursorEqual(viewModel, 4, 1);

            moveDown(viewModel, 1);
            cursorEqual(viewModel, 5, 2);

            moveUp(viewModel, 4);
            cursorEqual(viewModel, 1, 21);
        });
    }

    /**
     * test('move to view top line moves to first visible line if it is first line')
     */
    function testMoveToViewTopLineMovesToFirstVisibleLineIfItIsFirstLine() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(1, 1, 10, 1);

            moveTo(viewModel, 2, 2);
            moveToTop(viewModel);

            cursorEqual(viewModel, 1, 6);
        });
    }

    /**
     * test('move to view top line moves to top visible line when first line is not visible')
     */
    function testMoveToViewTopLineMovesToTopVisibleLineWhenFirstLineIsNotVisible() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(2, 1, 10, 1);

            moveTo(viewModel, 4, 1);
            moveToTop(viewModel);

            cursorEqual(viewModel, 2, 2);
        });
    }

    /**
     * test('move to view top line moves to nth line from top')
     */
    function testMoveToViewTopLineMovesToNthLineFromTop() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(1, 1, 10, 1);

            moveTo(viewModel, 4, 1);
            moveToTop(viewModel, 3);

            cursorEqual(viewModel, 3, 5);
        });
    }

    /**
     * test('move to view top line moves to last line if n is greater than last visible line number')
     */
    function testMoveToViewTopLineMovesToLastLineIfNIsGreaterThanLastVisibleLineNumber() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(1, 1, 3, 1);

            moveTo(viewModel, 2, 2);
            moveToTop(viewModel, 4);

            cursorEqual(viewModel, 3, 5);
        });
    }

    /**
     * test('move to view center line moves to the center line')
     */
    function testMoveToViewCenterLineMovesToTheCenterLine() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(3, 1, 3, 1);

            moveTo(viewModel, 2, 2);
            moveToCenter(viewModel);

            cursorEqual(viewModel, 3, 5);
        });
    }

    /**
     * test('move to view bottom line moves to last visible line if it is last line')
     */
    function testMoveToViewBottomLineMovesToLastVisibleLineIfItIsLastLine() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(1, 1, 5, 1);

            moveTo(viewModel, 2, 2);
            moveToBottom(viewModel);

            cursorEqual(viewModel, 5, 1);
        });
    }

    /**
     * test('move to view bottom line moves to last visible line when last line is not visible')
     */
    function testMoveToViewBottomLineMovesToLastVisibleLineWhenLastLineIsNotVisible() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(2, 1, 3, 1);

            moveTo(viewModel, 2, 2);
            moveToBottom(viewModel);

            cursorEqual(viewModel, 3, 5);
        });
    }

    /**
     * test('move to view bottom line moves to nth line from bottom')
     */
    function testMoveToViewBottomLineMovesToNthLineFromBottom() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(1, 1, 5, 1);

            moveTo(viewModel, 4, 1);
            moveToBottom(viewModel, 3);

            cursorEqual(viewModel, 3, 5);
        });
    }

    /**
     * test('move to view bottom line moves to first line if n is lesser than first visible line number')
     */
    function testMoveToViewBottomLineMovesToFirstLineIfNIsLesserThanFirstVisibleLineNumber() {
        executeTest((editor, viewModel) -> {
            viewModel._getCompletelyVisibleViewRangeOverride = () -> new Range(2, 1, 5, 1);

            moveTo(viewModel, 4, 1);
            moveToBottom(viewModel, 5);

            cursorEqual(viewModel, 2, 2);
        });
    }

}

/**
 * suite('Cursor move by blankline test')
 */
class CursorMoveByBlanklineTest extends CursorMoveCommandTestBase {

    static final TEXT = [
        '    \tMy First Line\t ',
        '\tMy Second Line',
        '    Third Line🐶',
        '',
        '1',
        '2',
        '3',
        '',
        '         ',
        'a',
        'b',
    ].join('\n');

    function executeTest(callback:(editor:TestCodeEditor, viewModel:ViewModel) -> Void):Void {
        TestCodeEditor.withTestCodeEditor(TEXT, {}, (editor, viewModel) -> {
            callback(editor, viewModel);
        });
    }

    /**
     * test('move down should move to start of next blank line')
     */
    function testMoveDownShouldMoveToStartOfNextBlankLine() {
        executeTest((editor, viewModel) -> {
            moveDownByBlankLine(viewModel, false);
            cursorEqual(viewModel, 4, 1);
        });
    }

    /**
     * test('move up should move to start of previous blank line')
     */
    function testMoveUpShouldMoveToStartOfPreviousBlankLine() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 7, 1);
            moveUpByBlankLine(viewModel, false);
            cursorEqual(viewModel, 4, 1);
        });
    }

    /**
     * test('move down should skip over whitespace if already on blank line')
     */
    function testMoveDownShouldSkipOverWhitespaceIfAlreadyOnBlankLine() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 8, 1);
            moveDownByBlankLine(viewModel, false);
            cursorEqual(viewModel, 11, 1);
        });
    }

    /**
     * test('move up should skip over whitespace if already on blank line')
     */
    function testMoveUpShouldSkipOverWhitespaceIfAlreadyOnBlankLine() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 9, 1);
            moveUpByBlankLine(viewModel, false);
            cursorEqual(viewModel, 4, 1);
        });
    }

    /**
     * test('move up should go to first column of first line if not empty')
     */
    function testMoveUpShouldGoToFirstColumnOfFirstLineIfNotEmpty() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 2, 1);
            moveUpByBlankLine(viewModel, false);
            cursorEqual(viewModel, 1, 1);
        });
    }

    /**
     * test('move down should go to first column of last line if not empty')
     */
    function testMoveDownShouldGoToFirstColumnOfLastLineIfNotEmpty() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 10, 1);
            moveDownByBlankLine(viewModel, false);
            cursorEqual(viewModel, 11, 1);
        });
    }

    /**
     * test('select down should select to start of next blank line')
     */
    function testSelectDownShouldSelectToStartOfNextBlankLine() {
        executeTest((editor, viewModel) -> {
            moveDownByBlankLine(viewModel, true);
            selectionEqual(viewModel.getSelection(), 4, 1, 1, 1);
        });
    }

    /**
     * test('select up should select to start of previous blank line')
     */
    function testSelectUpShouldSelectToStartOfPreviousBlankLine() {
        executeTest((editor, viewModel) -> {
            moveTo(viewModel, 7, 1);
            moveUpByBlankLine(viewModel, true);
            selectionEqual(viewModel.getSelection(), 4, 1, 7, 1);
        });
    }

}

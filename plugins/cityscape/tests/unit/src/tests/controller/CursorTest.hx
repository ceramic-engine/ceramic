// Ported from vscode src/vs/editor/test/browser/controller/cursor.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.controller;

// Classes of this module:
// - EditorControllerCursorTest
// - EditorControllerTest
// - UndoStopsTest

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.base.common.Uri;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.ViewModelEventDispatcher;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.NullTokenize;
import cityscape.common.model.TextModel;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.view.CoreCommands;
import haxe.extern.EitherType;
import haxe.io.UInt32Array;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.TestTokenizationSupport;
import tests.TestTextModel;

/**
 * The module functions of cursor.test.ts, and the test services of a test
 * (vscode's `createCodeEditorServices`: a `Cityscape` context per test).
 */
class CursorTestBase extends TestCase {

    var disposables:DisposableStore;
    var instantiationService:Cityscape;

    override function setup():Void {
        disposables = new DisposableStore();
        instantiationService = new Cityscape();
    }

    /**
     * The editors of the test, disposed before the models (Monaco's text
     * model accepts a detach after its disposal, this port asserts it).
     */
    var editors:Array<TestCodeEditor> = [];

    override function teardown():Void {
        for (editor in editors) {
            editor.dispose();
        }
        editors = [];
        disposables.dispose();
    }

    // --------- utils

    function moveTo(editor:TestCodeEditor, viewModel:ViewModel, lineNumber:Int, column:Int, inSelectionMode:Bool = false):Void {
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

    function moveLeft(editor:TestCodeEditor, viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorLeftSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorLeft.runCoreEditorCommand(viewModel, {});
        }
    }

    function moveRight(editor:TestCodeEditor, viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorRightSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorRight.runCoreEditorCommand(viewModel, {});
        }
    }

    function moveDown(editor:TestCodeEditor, viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorDownSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorDown.runCoreEditorCommand(viewModel, {});
        }
    }

    function moveUp(editor:TestCodeEditor, viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorUpSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorUp.runCoreEditorCommand(viewModel, {});
        }
    }

    function moveToBeginningOfLine(editor:TestCodeEditor, viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorHomeSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorHome.runCoreEditorCommand(viewModel, {});
        }
    }

    function moveToEndOfLine(editor:TestCodeEditor, viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorEndSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorEnd.runCoreEditorCommand(viewModel, {});
        }
    }

    function moveToBeginningOfBuffer(editor:TestCodeEditor, viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorTopSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorTop.runCoreEditorCommand(viewModel, {});
        }
    }

    function moveToEndOfBuffer(editor:TestCodeEditor, viewModel:ViewModel, inSelectionMode:Bool = false):Void {
        if (inSelectionMode) {
            CoreNavigationCommands.CursorBottomSelect.runCoreEditorCommand(viewModel, {});
        }
        else {
            CoreNavigationCommands.CursorBottom.runCoreEditorCommand(viewModel, {});
        }
    }

    /**
     * `what` is a `Position`, a `Selection` or an array of selections.
     */
    function assertCursor(viewModel:ViewModel, what:Any, ?pos:haxe.PosInfos):Void {
        var selections:Array<Selection>;
        if (Std.isOfType(what, Position)) {
            final what:Position = cast what;
            selections = [new Selection(what.lineNumber, what.column, what.lineNumber, what.column)];
        }
        else if (Std.isOfType(what, Selection)) {
            selections = [cast what];
        }
        else {
            selections = cast what;
        }
        final actual = [for (s in viewModel.getSelections()) s.toString()];
        final expected = [for (s in selections) s.toString()];

        assertDeepEquals(expected, actual, null, pos);
    }

    function createTextModel(text:String, ?languageId:String, ?options:IRelaxedTextModelCreationOptions, ?uri:Uri):TextModel {
        final model = TestTextModel.instantiateTextModel(instantiationService, text, languageId, options, uri);
        disposables.add(model);
        return model;
    }

    /**
     * `text` is a model, a string or an array of lines.
     */
    function withTestCodeEditor(text:EitherType<TextModel, EitherType<String, Array<String>>>, options:IEditorOptions, callback:(editor:TestCodeEditor, viewModel:ViewModel) -> Void):Void {
        var model:TextModel;
        if (Std.isOfType(text, TextModel)) {
            model = cast text;
        }
        else if (Std.isOfType(text, Array)) {
            model = createTextModel((cast text : Array<String>).join('\n'));
        }
        else {
            model = createTextModel(cast text);
        }
        final editor = new TestCodeEditor(instantiationService, model, options);
        editors.push(editor);
        final viewModel = editor.getViewModel();
        viewModel.setHasFocus(true);
        callback(editor, viewModel);
    }

}

/**
 * suite('Editor Controller - Cursor')
 */
class EditorControllerCursorTest extends CursorTestBase {

    static final LINE1 = '    \tMy First Line\t ';
    static final LINE2 = '\tMy Second Line';
    static final LINE3 = '    Third Line🐶';
    static final LINE4 = '';
    static final LINE5 = '1';

    static final TEXT =
        LINE1 + '\r\n' +
        LINE2 + '\n' +
        LINE3 + '\n' +
        LINE4 + '\r\n' +
        LINE5;

    function runTest(callback:(editor:TestCodeEditor, viewModel:ViewModel) -> Void):Void {
        withTestCodeEditor(TEXT, {}, (editor, viewModel) -> {
            callback(editor, viewModel);
        });
    }

    /**
     * test('cursor initialized')
     */
    function testCursorInitialized() {
        runTest((editor, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('no move')
     */
    function testNoMove() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 1);
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('move')
     */
    function testMove() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 2);
            assertCursor(viewModel, new Position(1, 2));
        });
    }

    /**
     * test('move in selection mode')
     */
    function testMoveInSelectionMode() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 2, true);
            assertCursor(viewModel, new Selection(1, 1, 1, 2));
        });
    }

    /**
     * test('move beyond line end')
     */
    function testMoveBeyondLineEnd() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 25);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
        });
    }

    /**
     * test('move empty line')
     */
    function testMoveEmptyLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 4, 20);
            assertCursor(viewModel, new Position(4, 1));
        });
    }

    /**
     * test('move one char line')
     */
    function testMoveOneCharLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 5, 20);
            assertCursor(viewModel, new Position(5, 2));
        });
    }

    /**
     * test('selection down')
     */
    function testSelectionDown() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 2, 1, true);
            assertCursor(viewModel, new Selection(1, 1, 2, 1));
        });
    }

    /**
     * test('move and then select')
     */
    function testMoveAndThenSelect() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 2, 3);
            assertCursor(viewModel, new Position(2, 3));

            moveTo(editor, viewModel, 2, 15, true);
            assertCursor(viewModel, new Selection(2, 3, 2, 15));

            moveTo(editor, viewModel, 1, 2, true);
            assertCursor(viewModel, new Selection(2, 3, 1, 2));
        });
    }

    /**
     * test('move left on top left position')
     */
    function testMoveLeftOnTopLeftPosition() {
        runTest((editor, viewModel) -> {
            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('move left')
     */
    function testMoveLeft() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 3);
            assertCursor(viewModel, new Position(1, 3));
            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Position(1, 2));
        });
    }

    /**
     * test('move left with surrogate pair')
     */
    function testMoveLeftWithSurrogatePair() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 17);
            assertCursor(viewModel, new Position(3, 17));
            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Position(3, 15));
        });
    }

    /**
     * test('move left goes to previous row')
     */
    function testMoveLeftGoesToPreviousRow() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 2, 1);
            assertCursor(viewModel, new Position(2, 1));
            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Position(1, 21));
        });
    }

    /**
     * test('move left selection')
     */
    function testMoveLeftSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 2, 1);
            assertCursor(viewModel, new Position(2, 1));
            moveLeft(editor, viewModel, true);
            assertCursor(viewModel, new Selection(2, 1, 1, 21));
        });
    }

    /**
     * test('move right on bottom right position')
     */
    function testMoveRightOnBottomRightPosition() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 5, 2);
            assertCursor(viewModel, new Position(5, 2));
            moveRight(editor, viewModel);
            assertCursor(viewModel, new Position(5, 2));
        });
    }

    /**
     * test('move right')
     */
    function testMoveRight() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 3);
            assertCursor(viewModel, new Position(1, 3));
            moveRight(editor, viewModel);
            assertCursor(viewModel, new Position(1, 4));
        });
    }

    /**
     * test('move right with surrogate pair')
     */
    function testMoveRightWithSurrogatePair() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 15);
            assertCursor(viewModel, new Position(3, 15));
            moveRight(editor, viewModel);
            assertCursor(viewModel, new Position(3, 17));
        });
    }

    /**
     * test('move right goes to next row')
     */
    function testMoveRightGoesToNextRow() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 21);
            assertCursor(viewModel, new Position(1, 21));
            moveRight(editor, viewModel);
            assertCursor(viewModel, new Position(2, 1));
        });
    }

    /**
     * test('move right selection')
     */
    function testMoveRightSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 21);
            assertCursor(viewModel, new Position(1, 21));
            moveRight(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 21, 2, 1));
        });
    }

    /**
     * test('move down')
     */
    function testMoveDown() {
        runTest((editor, viewModel) -> {
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(2, 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(3, 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(4, 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(5, 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(5, 2));
        });
    }

    /**
     * test('move down with selection')
     */
    function testMoveDownWithSelection() {
        runTest((editor, viewModel) -> {
            moveDown(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 1, 2, 1));
            moveDown(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 1, 3, 1));
            moveDown(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 1, 4, 1));
            moveDown(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 1, 5, 1));
            moveDown(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 1, 5, 2));
        });
    }

    /**
     * test('move down with tabs')
     */
    function testMoveDownWithTabs() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 5);
            assertCursor(viewModel, new Position(1, 5));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(2, 2));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(3, 5));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(4, 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(5, 2));
        });
    }

    /**
     * test('move up')
     */
    function testMoveUp() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 5);
            assertCursor(viewModel, new Position(3, 5));

            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(2, 2));

            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(1, 5));
        });
    }

    /**
     * test('move up with selection')
     */
    function testMoveUpWithSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 5);
            assertCursor(viewModel, new Position(3, 5));

            moveUp(editor, viewModel, true);
            assertCursor(viewModel, new Selection(3, 5, 2, 2));

            moveUp(editor, viewModel, true);
            assertCursor(viewModel, new Selection(3, 5, 1, 5));
        });
    }

    /**
     * test('move up and down with tabs')
     */
    function testMoveUpAndDownWithTabs() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 5);
            assertCursor(viewModel, new Position(1, 5));
            moveDown(editor, viewModel);
            moveDown(editor, viewModel);
            moveDown(editor, viewModel);
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(5, 2));
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(4, 1));
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(3, 5));
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(2, 2));
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(1, 5));
        });
    }

    /**
     * test('move up and down with end of lines starting from a long one')
     */
    function testMoveUpAndDownWithEndOfLinesStartingFromALongOne() {
        runTest((editor, viewModel) -> {
            moveToEndOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
            moveToEndOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(2, LINE2.length + 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(3, LINE3.length + 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(4, LINE4.length + 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(5, LINE5.length + 1));
            moveUp(editor, viewModel);
            moveUp(editor, viewModel);
            moveUp(editor, viewModel);
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
        });
    }

    /**
     * test('issue #44465: cursor position not correct when move')
     */
    function testIssue44465CursorPositionNotCorrectWhenMove() {
        runTest((editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 5, 1, 5)]);
            // going once up on the first line remembers the offset visual columns
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(2, 2));
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(1, 5));

            // going twice up on the first line discards the offset visual columns
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(2, 1));
        });
    }

    /**
     * test('issue #144041: Cursor up/down works')
     */
    function testIssue144041CursorUpDownWorks() {
        final model = createTextModel(
            [
                'Word1 Word2 Word3 Word4',
                'Word5 Word6 Word7 Word8',
            ].join('\n')
        );

        withTestCodeEditor(model, { wrappingIndent: 'indent', wordWrap: 'wordWrapColumn', wordWrapColumn: 20 }, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 1, 1, 1)]);

            final cursorPositions:Array<Dynamic> = [];
            function reportCursorPosition() {
                cursorPositions.push(viewModel.getCursorStates()[0].viewState.position.toString());
            }

            reportCursorPosition();
            CoreNavigationCommands.CursorDown.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorDown.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorDown.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorDown.runEditorCommand(null, editor, null);

            reportCursorPosition();
            CoreNavigationCommands.CursorUp.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorUp.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorUp.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorUp.runEditorCommand(null, editor, null);
            reportCursorPosition();

            assertDeepEquals(cursorPositions, [
                '(1,1)',
                '(2,5)',
                '(3,1)',
                '(4,5)',
                '(4,10)',
                '(3,1)',
                '(2,5)',
                '(1,1)',
                '(1,1)',
            ]);
        });

        model.dispose();
    }

    /**
     * test('issue #140195: Cursor up/down makes progress')
     */
    function testIssue140195CursorUpDownMakesProgress() {
        final model = createTextModel(
            [
                'Word1 Word2 Word3 Word4',
                'Word5 Word6 Word7 Word8',
            ].join('\n')
        );

        withTestCodeEditor(model, { wrappingIndent: 'indent', wordWrap: 'wordWrapColumn', wordWrapColumn: 20 }, (editor, viewModel) -> {
            editor.changeDecorations((changeAccessor) -> {
                changeAccessor.deltaDecorations([], [
                    {
                        range: new Range(1, 22, 1, 22),
                        options: {
                            showIfCollapsed: true,
                            description: 'test',
                            after: {
                                content: 'some very very very very very very very very long text',
                            }
                        }
                    }
                ]);
            });
            viewModel.setSelections('test', [new Selection(1, 1, 1, 1)]);

            final cursorPositions:Array<Dynamic> = [];
            function reportCursorPosition() {
                cursorPositions.push(viewModel.getCursorStates()[0].viewState.position.toString());
            }

            reportCursorPosition();
            CoreNavigationCommands.CursorDown.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorDown.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorDown.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorDown.runEditorCommand(null, editor, null);

            reportCursorPosition();
            CoreNavigationCommands.CursorUp.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorUp.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorUp.runEditorCommand(null, editor, null);
            reportCursorPosition();
            CoreNavigationCommands.CursorUp.runEditorCommand(null, editor, null);
            reportCursorPosition();

            assertDeepEquals(cursorPositions, [
                '(1,1)',
                '(2,5)',
                '(5,19)',
                '(6,1)',
                '(7,5)',
                '(6,1)',
                '(2,8)',
                '(1,1)',
                '(1,1)',
            ]);
        });

        model.dispose();
    }

    /**
     * test('move to beginning of line')
     */
    function testMoveToBeginningOfLine() {
        runTest((editor, viewModel) -> {
            moveToBeginningOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, 6));
            moveToBeginningOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('move to beginning of line from within line')
     */
    function testMoveToBeginningOfLineFromWithinLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 8);
            moveToBeginningOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, 6));
            moveToBeginningOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('move to beginning of line from whitespace at beginning of line')
     */
    function testMoveToBeginningOfLineFromWhitespaceAtBeginningOfLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 2);
            moveToBeginningOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, 6));
            moveToBeginningOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('move to beginning of line from within line selection')
     */
    function testMoveToBeginningOfLineFromWithinLineSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 8);
            moveToBeginningOfLine(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 8, 1, 6));
            moveToBeginningOfLine(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 8, 1, 1));
        });
    }

    /**
     * test('move to beginning of line with selection multiline forward')
     */
    function testMoveToBeginningOfLineWithSelectionMultilineForward() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 8);
            moveTo(editor, viewModel, 3, 9, true);
            moveToBeginningOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(3, 5, 3, 5));
        });
    }

    /**
     * test('move to beginning of line with selection multiline backward')
     */
    function testMoveToBeginningOfLineWithSelectionMultilineBackward() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 9);
            moveTo(editor, viewModel, 1, 8, true);
            moveToBeginningOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(1, 6, 1, 6));
        });
    }

    /**
     * test('move to beginning of line with selection single line forward')
     */
    function testMoveToBeginningOfLineWithSelectionSingleLineForward() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 2);
            moveTo(editor, viewModel, 3, 9, true);
            moveToBeginningOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(3, 5, 3, 5));
        });
    }

    /**
     * test('move to beginning of line with selection single line backward')
     */
    function testMoveToBeginningOfLineWithSelectionSingleLineBackward() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 9);
            moveTo(editor, viewModel, 3, 2, true);
            moveToBeginningOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(3, 5, 3, 5));
        });
    }

    /**
     * test('issue #15401: "End" key is behaving weird when text is selected part 1')
     */
    function testIssue15401EndKeyIsBehavingWeirdWhenTextIsSelectedPart1() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 8);
            moveTo(editor, viewModel, 3, 9, true);
            moveToBeginningOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(3, 5, 3, 5));
        });
    }

    /**
     * test('issue #17011: Shift+home/end now go to the end of the selection start\'s line, not the selection\'s end')
     */
    function testIssue17011ShiftHomeEndNowGoToTheEndOfTheSelectionStartSLineNotTheSelectionSEnd() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 8);
            moveTo(editor, viewModel, 3, 9, true);
            moveToBeginningOfLine(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 8, 3, 5));
        });
    }

    /**
     * test('move to end of line')
     */
    function testMoveToEndOfLine() {
        runTest((editor, viewModel) -> {
            moveToEndOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
            moveToEndOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
        });
    }

    /**
     * test('move to end of line from within line')
     */
    function testMoveToEndOfLineFromWithinLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 6);
            moveToEndOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
            moveToEndOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
        });
    }

    /**
     * test('move to end of line from whitespace at end of line')
     */
    function testMoveToEndOfLineFromWhitespaceAtEndOfLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 20);
            moveToEndOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
            moveToEndOfLine(editor, viewModel);
            assertCursor(viewModel, new Position(1, LINE1.length + 1));
        });
    }

    /**
     * test('move to end of line from within line selection')
     */
    function testMoveToEndOfLineFromWithinLineSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 6);
            moveToEndOfLine(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 6, 1, LINE1.length + 1));
            moveToEndOfLine(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 6, 1, LINE1.length + 1));
        });
    }

    /**
     * test('move to end of line with selection multiline forward')
     */
    function testMoveToEndOfLineWithSelectionMultilineForward() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 1);
            moveTo(editor, viewModel, 3, 9, true);
            moveToEndOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(3, 17, 3, 17));
        });
    }

    /**
     * test('move to end of line with selection multiline backward')
     */
    function testMoveToEndOfLineWithSelectionMultilineBackward() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 9);
            moveTo(editor, viewModel, 1, 1, true);
            moveToEndOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(1, 21, 1, 21));
        });
    }

    /**
     * test('move to end of line with selection single line forward')
     */
    function testMoveToEndOfLineWithSelectionSingleLineForward() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 1);
            moveTo(editor, viewModel, 3, 9, true);
            moveToEndOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(3, 17, 3, 17));
        });
    }

    /**
     * test('move to end of line with selection single line backward')
     */
    function testMoveToEndOfLineWithSelectionSingleLineBackward() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 9);
            moveTo(editor, viewModel, 3, 1, true);
            moveToEndOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(3, 17, 3, 17));
        });
    }

    /**
     * test('issue #15401: "End" key is behaving weird when text is selected part 2')
     */
    function testIssue15401EndKeyIsBehavingWeirdWhenTextIsSelectedPart2() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 1);
            moveTo(editor, viewModel, 3, 9, true);
            moveToEndOfLine(editor, viewModel, false);
            assertCursor(viewModel, new Selection(3, 17, 3, 17));
        });
    }

    /**
     * test('move to beginning of buffer')
     */
    function testMoveToBeginningOfBuffer() {
        runTest((editor, viewModel) -> {
            moveToBeginningOfBuffer(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('move to beginning of buffer from within first line')
     */
    function testMoveToBeginningOfBufferFromWithinFirstLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 3);
            moveToBeginningOfBuffer(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('move to beginning of buffer from within another line')
     */
    function testMoveToBeginningOfBufferFromWithinAnotherLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 3);
            moveToBeginningOfBuffer(editor, viewModel);
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('move to beginning of buffer from within first line selection')
     */
    function testMoveToBeginningOfBufferFromWithinFirstLineSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 3);
            moveToBeginningOfBuffer(editor, viewModel, true);
            assertCursor(viewModel, new Selection(1, 3, 1, 1));
        });
    }

    /**
     * test('move to beginning of buffer from within another line selection')
     */
    function testMoveToBeginningOfBufferFromWithinAnotherLineSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 3);
            moveToBeginningOfBuffer(editor, viewModel, true);
            assertCursor(viewModel, new Selection(3, 3, 1, 1));
        });
    }

    /**
     * test('move to end of buffer')
     */
    function testMoveToEndOfBuffer() {
        runTest((editor, viewModel) -> {
            moveToEndOfBuffer(editor, viewModel);
            assertCursor(viewModel, new Position(5, LINE5.length + 1));
        });
    }

    /**
     * test('move to end of buffer from within last line')
     */
    function testMoveToEndOfBufferFromWithinLastLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 5, 1);
            moveToEndOfBuffer(editor, viewModel);
            assertCursor(viewModel, new Position(5, LINE5.length + 1));
        });
    }

    /**
     * test('move to end of buffer from within another line')
     */
    function testMoveToEndOfBufferFromWithinAnotherLine() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 3);
            moveToEndOfBuffer(editor, viewModel);
            assertCursor(viewModel, new Position(5, LINE5.length + 1));
        });
    }

    /**
     * test('move to end of buffer from within last line selection')
     */
    function testMoveToEndOfBufferFromWithinLastLineSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 5, 1);
            moveToEndOfBuffer(editor, viewModel, true);
            assertCursor(viewModel, new Selection(5, 1, 5, LINE5.length + 1));
        });
    }

    /**
     * test('move to end of buffer from within another line selection')
     */
    function testMoveToEndOfBufferFromWithinAnotherLineSelection() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 3);
            moveToEndOfBuffer(editor, viewModel, true);
            assertCursor(viewModel, new Selection(3, 3, 5, LINE5.length + 1));
        });
    }

    /**
     * test('select all')
     */
    function testSelectAll() {
        runTest((editor, viewModel) -> {
            CoreNavigationCommands.SelectAll.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, new Selection(1, 1, 5, LINE5.length + 1));
        });
    }

    /**
     * test('no move doesn\'t trigger event')
     */
    function testNoMoveDoesnTTriggerEvent() {

        runTest((editor, viewModel) -> {
            final disposable = viewModel.onEvent((e) -> {
                assertTrue(false, 'was not expecting event');
            });
            moveTo(editor, viewModel, 1, 1);
            disposable.dispose();
        });
    }

    /**
     * test('move eventing')
     */
    function testMoveEventing() {
        runTest((editor, viewModel) -> {
            var events = 0;
            final disposable = viewModel.onEvent((e) -> {
                if (e.kind == OutgoingViewModelEventKind.CursorStateChanged) {
                    events++;
                    assertDeepEquals((cast e : CursorStateChangedEvent).selections, [new Selection(1, 2, 1, 2)]);
                }
            });
            moveTo(editor, viewModel, 1, 2);
            assertEquals(events, 1, 'receives 1 event');
            disposable.dispose();
        });
    }

    /**
     * test('move in selection mode eventing')
     */
    function testMoveInSelectionModeEventing() {
        runTest((editor, viewModel) -> {
            var events = 0;
            final disposable = viewModel.onEvent((e) -> {
                if (e.kind == OutgoingViewModelEventKind.CursorStateChanged) {
                    events++;
                    assertDeepEquals((cast e : CursorStateChangedEvent).selections, [new Selection(1, 1, 1, 2)]);
                }
            });
            moveTo(editor, viewModel, 1, 2, true);
            assertEquals(events, 1, 'receives 1 event');
            disposable.dispose();
        });
    }

    /**
     * test('saveState & restoreState')
     */
    function testSaveStateRestoreState() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 2, 1, true);
            assertCursor(viewModel, new Selection(1, 1, 2, 1));

            final savedState = haxe.Json.stringify(viewModel.saveCursorState());

            moveTo(editor, viewModel, 1, 1, false);
            assertCursor(viewModel, new Position(1, 1));

            viewModel.restoreCursorState(haxe.Json.parse(savedState));
            assertCursor(viewModel, new Selection(1, 1, 2, 1));
        });
    }

    /**
     * test('Independent model edit 1')
     */
    function testIndependentModelEdit1() {
        runTest((editor, viewModel) -> {
            moveTo(editor, viewModel, 2, 16, true);

            editor.getModel().applyEdits([EditOperation.delete(new Range(2, 1, 2, 2))]);
            assertCursor(viewModel, new Selection(1, 1, 2, 15));
        });
    }

    /**
     * test('column select 1')
     */
    function testColumnSelect1() {
        withTestCodeEditor([
            '\tprivate compute(a:number): boolean {',
            '\t\tif (a + 3 === 0 || a + 5 === 0) {',
            '\t\t\treturn false;',
            '\t\t}',
            '\t}'
        ], {}, (editor, viewModel) -> {

            moveTo(editor, viewModel, 1, 7, false);
            assertCursor(viewModel, new Position(1, 7));

            CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(viewModel, {
                position: new Position(4, 4),
                viewPosition: new Position(4, 4),
                mouseColumn: 15,
                doColumnSelect: true
            });

            final expectedSelections = [
                new Selection(1, 7, 1, 12),
                new Selection(2, 4, 2, 9),
                new Selection(3, 3, 3, 6),
                new Selection(4, 4, 4, 4),
            ];

            assertCursor(viewModel, expectedSelections);

        });
    }

    /**
     * test('grapheme breaking')
     */
    function testGraphemeBreaking() {
        withTestCodeEditor([
            'abcabc',
            'ãããããã',
            '辻󠄀辻󠄀辻󠄀',
            'பு',
        ], {}, (editor, viewModel) -> {

            viewModel.setSelections('test', [new Selection(2, 1, 2, 1)]);
            moveRight(editor, viewModel);
            assertCursor(viewModel, new Position(2, 3));
            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Position(2, 1));

            viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
            moveRight(editor, viewModel);
            assertCursor(viewModel, new Position(3, 4));
            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Position(3, 1));

            viewModel.setSelections('test', [new Selection(4, 1, 4, 1)]);
            moveRight(editor, viewModel);
            assertCursor(viewModel, new Position(4, 3));
            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Position(4, 1));

            viewModel.setSelections('test', [new Selection(1, 3, 1, 3)]);
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(2, 5));
            moveDown(editor, viewModel);
            assertCursor(viewModel, new Position(3, 4));
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(2, 5));
            moveUp(editor, viewModel);
            assertCursor(viewModel, new Position(1, 3));

        });
    }

    /**
     * test('issue #4905 - column select is biased to the right')
     */
    function testIssue4905ColumnSelectIsBiasedToTheRight() {
        withTestCodeEditor([
            'var gulp = require("gulp");',
            'var path = require("path");',
            'var rimraf = require("rimraf");',
            'var isarray = require("isarray");',
            'var merge = require("merge-stream");',
            'var concat = require("gulp-concat");',
            'var newer = require("gulp-newer");',
        ].join('\n'), {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 4, false);
            assertCursor(viewModel, new Position(1, 4));

            CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(viewModel, {
                position: new Position(4, 1),
                viewPosition: new Position(4, 1),
                mouseColumn: 1,
                doColumnSelect: true
            });

            assertCursor(viewModel, [
                new Selection(1, 4, 1, 1),
                new Selection(2, 4, 2, 1),
                new Selection(3, 4, 3, 1),
                new Selection(4, 4, 4, 1),
            ]);
        });
    }

    /**
     * test('issue #20087: column select with mouse')
     */
    function testIssue20087ColumnSelectWithMouse() {
        withTestCodeEditor([
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" Key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SoMEKEy" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" valuE="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="00X"/>',
        ].join('\n'), {}, (editor, viewModel) -> {

            moveTo(editor, viewModel, 10, 10, false);
            assertCursor(viewModel, new Position(10, 10));

            CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(viewModel, {
                position: new Position(1, 1),
                viewPosition: new Position(1, 1),
                mouseColumn: 1,
                doColumnSelect: true
            });
            assertCursor(viewModel, [
                new Selection(10, 10, 10, 1),
                new Selection(9, 10, 9, 1),
                new Selection(8, 10, 8, 1),
                new Selection(7, 10, 7, 1),
                new Selection(6, 10, 6, 1),
                new Selection(5, 10, 5, 1),
                new Selection(4, 10, 4, 1),
                new Selection(3, 10, 3, 1),
                new Selection(2, 10, 2, 1),
                new Selection(1, 10, 1, 1),
            ]);

            CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(viewModel, {
                position: new Position(1, 1),
                viewPosition: new Position(1, 1),
                mouseColumn: 1,
                doColumnSelect: true
            });
            assertCursor(viewModel, [
                new Selection(10, 10, 10, 1),
                new Selection(9, 10, 9, 1),
                new Selection(8, 10, 8, 1),
                new Selection(7, 10, 7, 1),
                new Selection(6, 10, 6, 1),
                new Selection(5, 10, 5, 1),
                new Selection(4, 10, 4, 1),
                new Selection(3, 10, 3, 1),
                new Selection(2, 10, 2, 1),
                new Selection(1, 10, 1, 1),
            ]);

        });
    }

    /**
     * test('issue #20087: column select with keyboard')
     */
    function testIssue20087ColumnSelectWithKeyboard() {
        withTestCodeEditor([
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" Key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SoMEKEy" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" valuE="000"/>',
            '<property id="SomeThing" key="SomeKey" value="000"/>',
            '<property id="SomeThing" key="SomeKey" value="00X"/>',
        ].join('\n'), {}, (editor, viewModel) -> {

            moveTo(editor, viewModel, 10, 10, false);
            assertCursor(viewModel, new Position(10, 10));

            CoreNavigationCommands.CursorColumnSelectLeft.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(10, 10, 10, 9)
            ]);

            CoreNavigationCommands.CursorColumnSelectLeft.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(10, 10, 10, 8)
            ]);

            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(10, 10, 10, 9)
            ]);

            CoreNavigationCommands.CursorColumnSelectUp.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(10, 10, 10, 9),
                new Selection(9, 10, 9, 9),
            ]);

            CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(10, 10, 10, 9)
            ]);
        });
    }

    /**
     * test('issue #118062: Column selection cannot select first position of a line')
     */
    function testIssue118062ColumnSelectionCannotSelectFirstPositionOfALine() {
        withTestCodeEditor([
            'hello world',
        ].join('\n'), {}, (editor, viewModel) -> {

            moveTo(editor, viewModel, 1, 2, false);
            assertCursor(viewModel, new Position(1, 2));

            CoreNavigationCommands.CursorColumnSelectLeft.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 2, 1, 1)
            ]);
        });
    }

    /**
     * test('column select with keyboard')
     */
    function testColumnSelectWithKeyboard() {
        withTestCodeEditor([
            'var gulp = require("gulp");',
            'var path = require("path");',
            'var rimraf = require("rimraf");',
            'var isarray = require("isarray");',
            'var merge = require("merge-stream");',
            'var concat = require("gulp-concat");',
            'var newer = require("gulp-newer");',
        ].join('\n'), {}, (editor, viewModel) -> {

            moveTo(editor, viewModel, 1, 4, false);
            assertCursor(viewModel, new Position(1, 4));

            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 5)
            ]);

            CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 5),
                new Selection(2, 4, 2, 5)
            ]);

            CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 5),
                new Selection(2, 4, 2, 5),
                new Selection(3, 4, 3, 5),
            ]);

            CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 5),
                new Selection(2, 4, 2, 5),
                new Selection(3, 4, 3, 5),
                new Selection(4, 4, 4, 5),
                new Selection(5, 4, 5, 5),
                new Selection(6, 4, 6, 5),
                new Selection(7, 4, 7, 5),
            ]);

            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 6),
                new Selection(2, 4, 2, 6),
                new Selection(3, 4, 3, 6),
                new Selection(4, 4, 4, 6),
                new Selection(5, 4, 5, 6),
                new Selection(6, 4, 6, 6),
                new Selection(7, 4, 7, 6),
            ]);

            // 10 times
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 16),
                new Selection(2, 4, 2, 16),
                new Selection(3, 4, 3, 16),
                new Selection(4, 4, 4, 16),
                new Selection(5, 4, 5, 16),
                new Selection(6, 4, 6, 16),
                new Selection(7, 4, 7, 16),
            ]);

            // 10 times
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 26),
                new Selection(2, 4, 2, 26),
                new Selection(3, 4, 3, 26),
                new Selection(4, 4, 4, 26),
                new Selection(5, 4, 5, 26),
                new Selection(6, 4, 6, 26),
                new Selection(7, 4, 7, 26),
            ]);

            // 2 times => reaching the ending of lines 1 and 2
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 28),
                new Selection(2, 4, 2, 28),
                new Selection(3, 4, 3, 28),
                new Selection(4, 4, 4, 28),
                new Selection(5, 4, 5, 28),
                new Selection(6, 4, 6, 28),
                new Selection(7, 4, 7, 28),
            ]);

            // 4 times => reaching the ending of line 3
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 28),
                new Selection(2, 4, 2, 28),
                new Selection(3, 4, 3, 32),
                new Selection(4, 4, 4, 32),
                new Selection(5, 4, 5, 32),
                new Selection(6, 4, 6, 32),
                new Selection(7, 4, 7, 32),
            ]);

            // 2 times => reaching the ending of line 4
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 28),
                new Selection(2, 4, 2, 28),
                new Selection(3, 4, 3, 32),
                new Selection(4, 4, 4, 34),
                new Selection(5, 4, 5, 34),
                new Selection(6, 4, 6, 34),
                new Selection(7, 4, 7, 34),
            ]);

            // 1 time => reaching the ending of line 7
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 28),
                new Selection(2, 4, 2, 28),
                new Selection(3, 4, 3, 32),
                new Selection(4, 4, 4, 34),
                new Selection(5, 4, 5, 35),
                new Selection(6, 4, 6, 35),
                new Selection(7, 4, 7, 35),
            ]);

            // 3 times => reaching the ending of lines 5 & 6
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 28),
                new Selection(2, 4, 2, 28),
                new Selection(3, 4, 3, 32),
                new Selection(4, 4, 4, 34),
                new Selection(5, 4, 5, 37),
                new Selection(6, 4, 6, 37),
                new Selection(7, 4, 7, 35),
            ]);

            // cannot go anywhere anymore
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 28),
                new Selection(2, 4, 2, 28),
                new Selection(3, 4, 3, 32),
                new Selection(4, 4, 4, 34),
                new Selection(5, 4, 5, 37),
                new Selection(6, 4, 6, 37),
                new Selection(7, 4, 7, 35),
            ]);

            // cannot go anywhere anymore even if we insist
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 28),
                new Selection(2, 4, 2, 28),
                new Selection(3, 4, 3, 32),
                new Selection(4, 4, 4, 34),
                new Selection(5, 4, 5, 37),
                new Selection(6, 4, 6, 37),
                new Selection(7, 4, 7, 35),
            ]);

            // can easily go back
            CoreNavigationCommands.CursorColumnSelectLeft.runCoreEditorCommand(viewModel, {});
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 28),
                new Selection(2, 4, 2, 28),
                new Selection(3, 4, 3, 32),
                new Selection(4, 4, 4, 34),
                new Selection(5, 4, 5, 36),
                new Selection(6, 4, 6, 36),
                new Selection(7, 4, 7, 35),
            ]);
        });
    }

    /**
     * test('setSelection / setPosition with source')
     */
    function testSetSelectionSetPositionWithSource() {

        final tokenizationSupport:ITokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line:String, hasEOL:Bool, state:IState) -> {
                return new EncodedTokenizationResult(new UInt32Array(0), state);
            }
        );

        final LANGUAGE_ID = 'modelModeTest1';
        final languageRegistration = instantiationService.tokenizationRegistry.register(LANGUAGE_ID, tokenizationSupport);
        final model = createTextModel('Just text', LANGUAGE_ID);

        withTestCodeEditor(model, {}, (editor1, cursor1) -> {
            var event:Null<ICursorPositionChangedEvent> = null;
            final disposable = editor1.onDidChangeCursorPosition(e -> {
                event = e;
            });

            editor1.setSelection(new Range(1, 2, 1, 3), 'navigation');
            assertEquals(event.source, 'navigation');

            event = null;
            editor1.setPosition(new Position(1, 2), 'navigation');
            assertEquals(event.source, 'navigation');
            disposable.dispose();
        });

        languageRegistration.dispose();
        model.dispose();
    }

}

typedef ICursorOpts = {
    var text:Array<String>;
    @:optional var languageId:Null<String>;
    @:optional var modelOpts:IRelaxedTextModelCreationOptions;
    @:optional var editorOpts:IEditorOptions;
}

enum abstract AutoClosingColumnType(Int) from Int to Int {
    var Normal = 0;
    var Special1 = 1;
    var Special2 = 2;
}

/**
 * The tokenizer states of `setupAutoClosingLanguageTokenization`.
 */
private class BaseState implements IState {
    public final parent:Null<IState>;
    public function new(?parent:IState) {
        this.parent = parent;
    }
    public function clone():IState {
        return this;
    }
    public function equals(other:IState):Bool {
        if (!Std.isOfType(other, BaseState)) {
            return false;
        }
        final other:BaseState = cast other;
        if (this.parent == null && other.parent == null) {
            return true;
        }
        if (this.parent == null || other.parent == null) {
            return false;
        }
        return this.parent.equals(other.parent);
    }
}

private class StringState implements IState {
    public final char:String;
    public final parentState:IState;
    public function new(char:String, parentState:IState) {
        this.char = char;
        this.parentState = parentState;
    }
    public function clone():IState {
        return this;
    }
    public function equals(other:IState):Bool {
        return Std.isOfType(other, StringState) && this.char == (cast other : StringState).char && this.parentState.equals((cast other : StringState).parentState);
    }
}

private class BlockCommentState implements IState {
    public final parentState:IState;
    public function new(parentState:IState) {
        this.parentState = parentState;
    }
    public function clone():IState {
        return this;
    }
    public function equals(other:IState):Bool {
        // `other instanceof StringState` in vscode
        return Std.isOfType(other, StringState) && this.parentState.equals((cast other : StringState).parentState);
    }
}

/**
 * suite('Editor Controller')
 */
class EditorControllerTest extends CursorTestBase {

    static inline final surroundingLanguageId = 'surroundingLanguage';
    static inline final indentRulesLanguageId = 'indentRulesLanguage';
    static inline final electricCharLanguageId = 'electricCharLanguage';
    static inline final autoClosingLanguageId = 'autoClosingLanguage';

    var languageConfigurationService:cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
    var languageService:cityscape.common.services.LanguageService;

    override function setup():Void {
        super.setup();
        languageConfigurationService = instantiationService.languageConfigurationService;
        languageService = instantiationService.languageService;

        disposables.add(languageService.registerLanguage({id: surroundingLanguageId}));
        disposables.add(languageConfigurationService.register(surroundingLanguageId, {
            autoClosingPairs: [{open: '(', close: ')'}]
        }));

        setupIndentRulesLanguage(indentRulesLanguageId, {
            decreaseIndentPattern: new RegExp('^\\s*((?!\\S.*\\/[*]).*[*]\\/\\s*)?[})\\]]|^\\s*(case\\b.*|default):\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$$'),
            increaseIndentPattern: new RegExp('^((?!\\/\\/).)*(\\{[^}"\'`]*|\\([^)"\']*|\\[[^\\]"\']*|^\\s*(\\{\\}|\\(\\)|\\[\\]|(case\\b.*|default):))\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$$'),
            indentNextLinePattern: new RegExp('^\\s*(for|while|if|else)\\b(?!.*[;{}]\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$$)'),
            unIndentedLinePattern: new RegExp('^(?!.*([;{}]|\\S:)\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$$)(?!.*(\\{[^}"\']*|\\([^)"\']*|\\[[^\\]"\']*|^\\s*(\\{\\}|\\(\\)|\\[\\]|(case\\b.*|default):))\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$$)(?!^\\s*((?!\\S.*\\/[*]).*[*]\\/\\s*)?[})\\]]|^\\s*(case\\b.*|default):\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$$)(?!^\\s*(for|while|if|else)\\b(?!.*[;{}]\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$$))')
        });

        disposables.add(languageService.registerLanguage({id: electricCharLanguageId}));
        disposables.add(languageConfigurationService.register(electricCharLanguageId, {
            __electricCharacterSupport: {
                docComment: {open: '/**', close: ' */'}
            },
            brackets: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')']
            ]
        }));

        setupAutoClosingLanguage();
    }

    function setupOnEnterLanguage(indentAction:IndentAction):String {
        final onEnterLanguageId = 'onEnterMode';

        disposables.add(languageService.registerLanguage({id: onEnterLanguageId}));
        disposables.add(languageConfigurationService.register(onEnterLanguageId, {
            onEnterRules: [{
                beforeText: new RegExp('.*'),
                action: {
                    indentAction: indentAction
                }
            }]
        }));
        return onEnterLanguageId;
    }

    function setupIndentRulesLanguage(languageId:String, indentationRules:IndentationRule):String {
        disposables.add(languageService.registerLanguage({id: languageId}));
        disposables.add(languageConfigurationService.register(languageId, {
            indentationRules: indentationRules
        }));
        return languageId;
    }

    function setupAutoClosingLanguage():Void {
        disposables.add(languageService.registerLanguage({id: autoClosingLanguageId}));
        disposables.add(languageConfigurationService.register(autoClosingLanguageId, {
            comments: {
                blockComment: ['/*', '*/']
            },
            autoClosingPairs: [
                {open: '{', close: '}'},
                {open: '[', close: ']'},
                {open: '(', close: ')'},
                {open: '\'', close: '\'', notIn: ['string', 'comment']},
                {open: '\"', close: '\"', notIn: ['string']},
                {open: '`', close: '`', notIn: ['string', 'comment']},
                {open: '/**', close: ' */', notIn: ['string']},
                {open: 'begin', close: 'end', notIn: ['string']}
            ],
            __electricCharacterSupport: {
                docComment: {open: '/**', close: ' */'}
            }
        }));
    }

    /**
     * The tokenizer of vscode's test (regular expressions written as loops).
     */
    function setupAutoClosingLanguageTokenization():Void {
        final encodedLanguageId:Int = languageService.languageIdCodec.encodeLanguageId(autoClosingLanguageId);
        disposables.add(instantiationService.tokenizationRegistry.register(autoClosingLanguageId, new TestTokenizationSupport(
            () -> new BaseState(),
            (line:String, hasEOL:Bool, _state:IState) -> {
                var state:IState = _state;
                final tokens:Array<{length:Int, type:StandardTokenType}> = [];
                final generateToken = (length:Int, type:StandardTokenType, ?newState:IState) -> {
                    if (tokens.length > 0 && tokens[tokens.length - 1].type == type) {
                        // grow last tokens
                        tokens[tokens.length - 1].length += length;
                    }
                    else {
                        tokens.push({length: length, type: type});
                    }
                    line = line.substring(length);
                    if (newState != null) {
                        state = newState;
                    }
                };
                // `line.match(/^[^chars]+/g)`: the length of the run of characters not in `chars`
                final runNotIn = (chars:String) -> {
                    var i = 0;
                    while (i < line.length && chars.indexOf(line.charAt(i)) == -1) {
                        i++;
                    }
                    return i;
                };
                final advance = () -> {
                    if (Std.isOfType(state, BaseState)) {
                        final m1 = runNotIn('\'"`{}/');
                        if (m1 > 0) {
                            return generateToken(m1, StandardTokenType.Other);
                        }
                        final c = line.charAt(0);
                        if (c == '\'' || c == '"' || c == '`') {
                            return generateToken(1, StandardTokenType.String, new StringState(line.charAt(0), state));
                        }
                        if (c == '{') {
                            return generateToken(1, StandardTokenType.Other, new BaseState(state));
                        }
                        if (c == '}') {
                            final parent = (cast state : BaseState).parent;
                            return generateToken(1, StandardTokenType.Other, parent != null ? parent : new BaseState());
                        }
                        if (StringTools.startsWith(line, '//')) {
                            return generateToken(line.length, StandardTokenType.Comment, state);
                        }
                        if (StringTools.startsWith(line, '/*')) {
                            return generateToken(2, StandardTokenType.Comment, new BlockCommentState(state));
                        }
                        return generateToken(1, StandardTokenType.Other, state);
                    }
                    else if (Std.isOfType(state, StringState)) {
                        final m1 = runNotIn('\\\'"`$$');
                        if (m1 > 0) {
                            return generateToken(m1, StandardTokenType.String);
                        }
                        if (StringTools.startsWith(line, '\\')) {
                            return generateToken(2, StandardTokenType.String);
                        }
                        if (line.charAt(0) == (cast state : StringState).char) {
                            return generateToken(1, StandardTokenType.String, (cast state : StringState).parentState);
                        }
                        if (StringTools.startsWith(line, '$${')) {
                            return generateToken(2, StandardTokenType.Other, new BaseState(state));
                        }
                        return generateToken(1, StandardTokenType.Other, state);
                    }
                    else if (Std.isOfType(state, BlockCommentState)) {
                        final m1 = runNotIn('*');
                        if (m1 > 0) {
                            return generateToken(m1, StandardTokenType.String);
                        }
                        if (StringTools.startsWith(line, '*/')) {
                            return generateToken(2, StandardTokenType.Comment, (cast state : BlockCommentState).parentState);
                        }
                        return generateToken(1, StandardTokenType.Other, state);
                    }
                    else {
                        throw 'unknown state';
                    }
                };
                while (line.length > 0) {
                    advance();
                }
                final result = new UInt32Array(tokens.length * 2);
                var startIndex = 0;
                for (i in 0...tokens.length) {
                    result[2 * i] = startIndex;
                    result[2 * i + 1] = (
                        (encodedLanguageId << MetadataConsts.LANGUAGEID_OFFSET)
                        | ((tokens[i].type : Int) << MetadataConsts.TOKEN_TYPE_OFFSET)
                    );
                    startIndex += tokens[i].length;
                }
                return new EncodedTokenizationResult(result, state);
            }
        )));
    }

    function setAutoClosingLanguageEnabledSet(chars:String):Void {
        disposables.add(languageConfigurationService.register(autoClosingLanguageId, {
            autoCloseBefore: chars,
            autoClosingPairs: [
                {open: '{', close: '}'},
                {open: '[', close: ']'},
                {open: '(', close: ')'},
                {open: '\'', close: '\'', notIn: ['string', 'comment']},
                {open: '\"', close: '\"', notIn: ['string']},
                {open: '`', close: '`', notIn: ['string', 'comment']},
                {open: '/**', close: ' */', notIn: ['string']}
            ],
        }));
    }

    function usingCursor(opts:ICursorOpts, callback:(editor:TestCodeEditor, model:TextModel, viewModel:ViewModel) -> Void):Void {
        final model = createTextModel(opts.text.join('\n'), opts.languageId, opts.modelOpts);
        final editorOptions:IEditorOptions = opts.editorOpts != null ? opts.editorOpts : {};
        withTestCodeEditor(model, editorOptions, (editor, viewModel) -> {
            callback(editor, model, viewModel);
        });
    }

    function extractAutoClosingSpecialColumns(maxColumn:Int, annotatedLine:String):Array<AutoClosingColumnType> {
        final result:Array<AutoClosingColumnType> = [];
        for (j in 1...maxColumn + 1) {
            result[j] = AutoClosingColumnType.Normal;
        }
        var column = 1;
        for (j in 0...annotatedLine.length) {
            if (annotatedLine.charAt(j) == '|') {
                result[column] = AutoClosingColumnType.Special1;
            }
            else if (annotatedLine.charAt(j) == '!') {
                result[column] = AutoClosingColumnType.Special2;
            }
            else {
                column++;
            }
        }
        return result;
    }

    function assertType(editor:TestCodeEditor, model:ITextModel, viewModel:ViewModel, lineNumber:Int, column:Int, chr:String, expectedInsert:String, message:String, ?pos:haxe.PosInfos):Void {
        final lineContent = model.getLineContent(lineNumber);
        final expected = lineContent.substr(0, column - 1) + expectedInsert + lineContent.substr(column - 1);
        moveTo(editor, viewModel, lineNumber, column);
        viewModel.type(chr, 'keyboard');
        assertDeepEquals(expected, model.getLineContent(lineNumber), message, pos);
        model.undo();
    }

    /**
     * test('issue microsoft/monaco-editor#443: Indentation of a single row deletes selected text in some cases')
     */
    function testIssueMicrosoftMonacoEditor443IndentationOfASingleRowDeletesSelectedTextInSomeCases() {
        final model = createTextModel(
            [
                'Hello world!',
                'another line'
            ].join('\n'),
            null,
            {
                insertSpaces: false
            },
        );
        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 1, 1, 13)]);

            // Check that indenting maintains the selection start at column 1
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertDeepEquals(viewModel.getSelection(), new Selection(1, 1, 1, 14));
        });
    }

    /**
     * test('Bug 9121: Auto indent + undo + redo is funky')
     */
    function testBug9121AutoIndentUndoRedoIsFunky() {
        final model = createTextModel(
            [
                ''
            ].join('\n'),
            null,
            {
                insertSpaces: false,
                trimAutoWhitespace: false
            },
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n', 'assert1');

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t', 'assert2');

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t\n\t', 'assert3');

            viewModel.type('x');
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t\n\tx', 'assert4');

            CoreNavigationCommands.CursorLeft.runCoreEditorCommand(viewModel, {});
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t\n\tx', 'assert5');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t\nx', 'assert6');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\tx', 'assert7');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\nx', 'assert8');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'x', 'assert9');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\nx', 'assert10');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t\nx', 'assert11');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t\n\tx', 'assert12');

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t\nx', 'assert13');

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\nx', 'assert14');

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'x', 'assert15');
        });
    }

    /**
     * test('issue #23539: Setting model EOL isn\'t undoable')
     */
    function testIssue23539SettingModelEOLIsnTUndoable() {
        withTestCodeEditor([
            'Hello',
            'world'
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();

            assertCursor(viewModel, new Position(1, 1));
            model.setEOL(EndOfLineSequence.LF);
            assertEquals(model.getValue(), 'Hello\nworld');

            model.pushEOL(EndOfLineSequence.CRLF);
            assertEquals(model.getValue(), 'Hello\r\nworld');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(), 'Hello\nworld');
        });
    }

    /**
     * test('issue #47733: Undo mangles unicode characters')
     */
    function testIssue47733UndoManglesUnicodeCharacters() {
        final languageId = 'myMode';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            surroundingPairs: [{ open: '%', close: '%' }]
        }));

        final model = createTextModel('\'👁\'', languageId);

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            editor.setSelection(new Selection(1, 1, 1, 2));

            viewModel.type('%', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.LF), '%\'%👁\'', 'assert1');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\'👁\'', 'assert2');
        });
    }

    /**
     * test('issue #46208: Allow empty selections in the undo/redo stack')
     */
    function testIssue46208AllowEmptySelectionsInTheUndoRedoStack() {
        final model = createTextModel('');

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.type('Hello', 'keyboard');
            viewModel.type(' ', 'keyboard');
            viewModel.type('world', 'keyboard');
            viewModel.type(' ', 'keyboard');
            assertEquals(model.getLineContent(1), 'Hello world ');
            assertCursor(viewModel, new Position(1, 13));

            moveLeft(editor, viewModel);
            moveRight(editor, viewModel);

            model.pushEditOperations([], [EditOperation.replaceMove(new Range(1, 12, 1, 13), '')], (_) -> []);
            assertEquals(model.getLineContent(1), 'Hello world');
            assertCursor(viewModel, new Position(1, 12));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'Hello world ');
            assertCursor(viewModel, new Selection(1, 13, 1, 13));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'Hello world');
            assertCursor(viewModel, new Position(1, 12));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'Hello');
            assertCursor(viewModel, new Position(1, 6));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '');
            assertCursor(viewModel, new Position(1, 1));

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'Hello');
            assertCursor(viewModel, new Position(1, 6));

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'Hello world');
            assertCursor(viewModel, new Position(1, 12));

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'Hello world ');
            assertCursor(viewModel, new Position(1, 13));

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'Hello world');
            assertCursor(viewModel, new Position(1, 12));

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'Hello world');
            assertCursor(viewModel, new Position(1, 12));
        });
    }

    /**
     * test('bug #16815:Shift+Tab doesn\'t go back to tabstop')
     */
    function testBug16815ShiftTabDoesnTGoBackToTabstop() {
        final languageId = setupOnEnterLanguage(IndentAction.IndentOutdent);
        final model = createTextModel(
            [
                '     function baz() {'
            ].join('\n'),
            languageId
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 6, false);
            assertCursor(viewModel, new Selection(1, 6, 1, 6));

            CoreEditingCommands.Outdent.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '    function baz() {');
            assertCursor(viewModel, new Selection(1, 5, 1, 5));
        });
    }

    /**
     * test('Bug #18293:[regression][editor] Can\'t outdent whitespace line')
     */
    function testBug18293RegressionEditorCanTOutdentWhitespaceLine() {
        final model = createTextModel(
            [
                '      '
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 7, false);
            assertCursor(viewModel, new Selection(1, 7, 1, 7));

            CoreEditingCommands.Outdent.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '    ');
            assertCursor(viewModel, new Selection(1, 5, 1, 5));
        });
    }

    /**
     * test('issue #95591: Unindenting moves cursor to beginning of line')
     */
    function testIssue95591UnindentingMovesCursorToBeginningOfLine() {
        final model = createTextModel(
            [
                '        '
            ].join('\n')
        );

        withTestCodeEditor(model, { useTabStops: false }, (editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 9, false);
            assertCursor(viewModel, new Selection(1, 9, 1, 9));

            CoreEditingCommands.Outdent.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '    ');
            assertCursor(viewModel, new Selection(1, 5, 1, 5));
        });
    }

    /**
     * test('Bug #16657: [editor] Tab on empty line of zero indentation moves cursor to position (1,1)')
     */
    function testBug16657EditorTabOnEmptyLineOfZeroIndentationMovesCursorToPosition11() {
        final model = createTextModel(
            [
                'function baz() {',
                '\tfunction hello() { // something here',
                '\t',
                '',
                '\t}',
                '}',
                ''
            ].join('\n'),
            null,
            {
                insertSpaces: false,
            },
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 7, 1, false);
            assertCursor(viewModel, new Selection(7, 1, 7, 1));

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(7), '\t');
            assertCursor(viewModel, new Selection(7, 2, 7, 2));
        });
    }

    /**
     * test('bug #16740: [editor] Cut line doesn\'t quite cut the last line')
     */
    function testBug16740EditorCutLineDoesnTQuiteCutTheLastLine() {

        // Part 1 => there is text on the last line
        withTestCodeEditor([
            'asdasd',
            'qwerty'
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();

            moveTo(editor, viewModel, 2, 1, false);
            assertCursor(viewModel, new Selection(2, 1, 2, 1));

            viewModel.cut('keyboard');
            assertEquals(model.getLineCount(), 1);
            assertEquals(model.getLineContent(1), 'asdasd');

        });

        // Part 2 => there is no text on the last line
        withTestCodeEditor([
            'asdasd',
            ''
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();

            moveTo(editor, viewModel, 2, 1, false);
            assertCursor(viewModel, new Selection(2, 1, 2, 1));

            viewModel.cut('keyboard');
            assertEquals(model.getLineCount(), 1);
            assertEquals(model.getLineContent(1), 'asdasd');

            viewModel.cut('keyboard');
            assertEquals(model.getLineCount(), 1);
            assertEquals(model.getLineContent(1), '');
        });
    }

    /**
     * test('issue #128602: When cutting multiple lines (ctrl x), the last line will not be erased')
     */
    function testIssue128602WhenCuttingMultipleLinesCtrlXTheLastLineWillNotBeErased() {
        withTestCodeEditor([
            'a1',
            'a2',
            'a3'
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();

            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 1),
                new Selection(2, 1, 2, 1),
                new Selection(3, 1, 3, 1),
            ]);

            viewModel.cut('keyboard');
            assertEquals(model.getLineCount(), 1);
            assertEquals(model.getLineContent(1), '');
        });
    }

    /**
     * test('Bug #11476: Double bracket surrounding + undo is broken')
     */
    function testBug11476DoubleBracketSurroundingUndoIsBroken() {
        usingCursor({
            text: [
                'hello'
            ],
            languageId: surroundingLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 3, false);
            moveTo(editor, viewModel, 1, 5, true);
            assertCursor(viewModel, new Selection(1, 3, 1, 5));

            viewModel.type('(', 'keyboard');
            assertCursor(viewModel, new Selection(1, 4, 1, 6));

            viewModel.type('(', 'keyboard');
            assertCursor(viewModel, new Selection(1, 5, 1, 7));
        });
    }

    /**
     * test('issue #1140: Backspace stops prematurely')
     */
    function testIssue1140BackspaceStopsPrematurely() {
        final model = createTextModel(
            [
                'function baz() {',
                '  return 1;',
                '};'
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 2, false);
            moveTo(editor, viewModel, 1, 14, true);
            assertCursor(viewModel, new Selection(3, 2, 1, 14));

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertCursor(viewModel, new Selection(1, 14, 1, 14));
            assertEquals(model.getLineCount(), 1);
            assertEquals(model.getLineContent(1), 'function baz(;');
        });
    }

    /**
     * test('issue #10212: Pasting entire line does not replace selection')
     */
    function testIssue10212PastingEntireLineDoesNotReplaceSelection() {
        usingCursor({
            text: [
                'line1',
                'line2'
            ],
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 1, false);
            moveTo(editor, viewModel, 2, 6, true);

            viewModel.paste('line1\n', true);

            assertEquals(model.getLineContent(1), 'line1');
            assertEquals(model.getLineContent(2), 'line1');
            assertEquals(model.getLineContent(3), '');
        });
    }

    /**
     * test('issue #74722: Pasting whole line does not replace selection')
     */
    function testIssue74722PastingWholeLineDoesNotReplaceSelection() {
        usingCursor({
            text: [
                'line1',
                'line sel 2',
                'line3'
            ],
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(2, 6, 2, 9)]);

            viewModel.paste('line1\n', true);

            assertEquals(model.getLineContent(1), 'line1');
            assertEquals(model.getLineContent(2), 'line line1');
            assertEquals(model.getLineContent(3), ' 2');
            assertEquals(model.getLineContent(4), 'line3');
        });
    }

    /**
     * test('issue #4996: Multiple cursor paste pastes contents of all cursors')
     */
    function testIssue4996MultipleCursorPastePastesContentsOfAllCursors() {
        usingCursor({
            text: [
                'line1',
                'line2',
                'line3'
            ],
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1)]);

            viewModel.paste(
                'a\nb\nc\nd',
                false,
                [
                    'a\nb',
                    'c\nd'
                ]
            );

            assertEquals(model.getValue(), [
                'a',
                'bline1',
                'c',
                'dline2',
                'line3'
            ].join('\n'));
        });
    }

    /**
     * test('issue #16155: Paste into multiple cursors has edge case when number of lines equals number of cursors - 1')
     */
    function testIssue16155PasteIntoMultipleCursorsHasEdgeCaseWhenNumberOfLinesEqualsNumberOfCursors1() {
        usingCursor({
            text: [
                'test',
                'test',
                'test',
                'test'
            ],
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 5),
                new Selection(2, 1, 2, 5),
                new Selection(3, 1, 3, 5),
                new Selection(4, 1, 4, 5),
            ]);

            viewModel.paste(
                'aaa\nbbb\nccc\n',
                false,
                null
            );

            assertEquals(model.getValue(), [
                'aaa',
                'bbb',
                'ccc',
                '',
                'aaa',
                'bbb',
                'ccc',
                '',
                'aaa',
                'bbb',
                'ccc',
                '',
                'aaa',
                'bbb',
                'ccc',
                '',
            ].join('\n'));
        });
    }

    /**
     * test('issue #43722: Multiline paste doesn\'t work anymore')
     */
    function testIssue43722MultilinePasteDoesnTWorkAnymore() {
        usingCursor({
            text: [
                'test',
                'test',
                'test',
                'test'
            ],
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 5),
                new Selection(2, 1, 2, 5),
                new Selection(3, 1, 3, 5),
                new Selection(4, 1, 4, 5),
            ]);

            viewModel.paste(
                'aaa\r\nbbb\r\nccc\r\nddd\r\n',
                false,
                null
            );

            assertEquals(model.getValue(), [
                'aaa',
                'bbb',
                'ccc',
                'ddd',
            ].join('\n'));
        });
    }

    /**
     * test('issue #46440: (1) Pasting a multi-line selection pastes entire selection into every insertion point')
     */
    function testIssue464401PastingAMultiLineSelectionPastesEntireSelectionIntoEveryInsertionPoint() {
        usingCursor({
            text: [
                'line1',
                'line2',
                'line3'
            ],
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1), new Selection(3, 1, 3, 1)]);

            viewModel.paste(
                'a\nb\nc',
                false,
                null
            );

            assertEquals(model.getValue(), [
                'aline1',
                'bline2',
                'cline3'
            ].join('\n'));
        });
    }

    /**
     * test('issue #46440: (2) Pasting a multi-line selection pastes entire selection into every insertion point')
     */
    function testIssue464402PastingAMultiLineSelectionPastesEntireSelectionIntoEveryInsertionPoint() {
        usingCursor({
            text: [
                'line1',
                'line2',
                'line3'
            ],
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1), new Selection(3, 1, 3, 1)]);

            viewModel.paste(
                'a\nb\nc\n',
                false,
                null
            );

            assertEquals(model.getValue(), [
                'aline1',
                'bline2',
                'cline3'
            ].join('\n'));
        });
    }

    /**
     * test('issue #3071: Investigate why undo stack gets corrupted')
     */
    function testIssue3071InvestigateWhyUndoStackGetsCorrupted() {
        final model = createTextModel(
            [
                'some lines',
                'and more lines',
                'just some text',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 1, false);
            moveTo(editor, viewModel, 3, 4, true);

            var isFirst = true;
            final disposable = model.onDidChangeContent((_) -> {
                if (isFirst) {
                    isFirst = false;
                    viewModel.type('\t', 'keyboard');
                }
            });

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(), [
                '\t just some text'
            ].join('\n'), '001');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(), [
                '    some lines',
                '    and more lines',
                '    just some text',
            ].join('\n'), '002');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(), [
                'some lines',
                'and more lines',
                'just some text',
            ].join('\n'), '003');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(), [
                'some lines',
                'and more lines',
                'just some text',
            ].join('\n'), '004');

            disposable.dispose();
        });
    }

    /**
     * test('issue #12950: Cannot Double Click To Insert Emoji Using OSX Emoji Panel')
     */
    function testIssue12950CannotDoubleClickToInsertEmojiUsingOSXEmojiPanel() {
        usingCursor({
            text: [
                'some lines',
                'and more lines',
                'just some text',
            ],
            languageId: null
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 1, false);

            viewModel.type('😍', 'keyboard');

            assertEquals(model.getValue(), [
                'some lines',
                'and more lines',
                '😍just some text',
            ].join('\n'));
        });
    }

    /**
     * test('issue #3463: pressing tab adds spaces, but not as many as for a tab')
     */
    function testIssue3463PressingTabAddsSpacesButNotAsManyAsForATab() {
        final model = createTextModel(
            [
                'function a() {',
                '\tvar a = {',
                '\t\tx: 3',
                '\t};',
                '}',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 2, false);
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(3), '\t    \tx: 3');
        });
    }

    /**
     * test('issue #4312: trying to type a tab character over a sequence of spaces results in unexpected behaviour')
     */
    function testIssue4312TryingToTypeATabCharacterOverASequenceOfSpacesResultsInUnexpectedBehaviour() {
        final model = createTextModel(
            [
                'var foo = 123;       // this is a comment',
                'var bar = 4;       // another comment'
            ].join('\n'),
            null,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 15, false);
            moveTo(editor, viewModel, 1, 22, true);
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'var foo = 123;\t// this is a comment');
        });
    }

    /**
     * test('issue #832: word right')
     */
    function testIssue832WordRight() {

        usingCursor({
            text: [
                '   /* Just some   more   text a+= 3 +5-3 + 7 */  '
            ],
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 1, false);

            function assertWordRight(col:Int, expectedCol:Int) {
                final args = {
                    position: {
                        lineNumber: 1,
                        column: col
                    }
                };
                if (col == 1) {
                    CoreNavigationCommands.WordSelect.runCoreEditorCommand(viewModel, args);
                } else {
                    CoreNavigationCommands.WordSelectDrag.runCoreEditorCommand(viewModel, args);
                }

                assertEquals(viewModel.getSelection().startColumn, 1, 'TEST FOR ' + col);
                assertEquals(viewModel.getSelection().endColumn, expectedCol, 'TEST FOR ' + col);
            }

            assertWordRight(1, '   '.length + 1);
            assertWordRight(2, '   '.length + 1);
            assertWordRight(3, '   '.length + 1);
            assertWordRight(4, '   '.length + 1);
            assertWordRight(5, '   /'.length + 1);
            assertWordRight(6, '   /*'.length + 1);
            assertWordRight(7, '   /* '.length + 1);
            assertWordRight(8, '   /* Just'.length + 1);
            assertWordRight(9, '   /* Just'.length + 1);
            assertWordRight(10, '   /* Just'.length + 1);
            assertWordRight(11, '   /* Just'.length + 1);
            assertWordRight(12, '   /* Just '.length + 1);
            assertWordRight(13, '   /* Just some'.length + 1);
            assertWordRight(14, '   /* Just some'.length + 1);
            assertWordRight(15, '   /* Just some'.length + 1);
            assertWordRight(16, '   /* Just some'.length + 1);
            assertWordRight(17, '   /* Just some '.length + 1);
            assertWordRight(18, '   /* Just some  '.length + 1);
            assertWordRight(19, '   /* Just some   '.length + 1);
            assertWordRight(20, '   /* Just some   more'.length + 1);
            assertWordRight(21, '   /* Just some   more'.length + 1);
            assertWordRight(22, '   /* Just some   more'.length + 1);
            assertWordRight(23, '   /* Just some   more'.length + 1);
            assertWordRight(24, '   /* Just some   more '.length + 1);
            assertWordRight(25, '   /* Just some   more  '.length + 1);
            assertWordRight(26, '   /* Just some   more   '.length + 1);
            assertWordRight(27, '   /* Just some   more   text'.length + 1);
            assertWordRight(28, '   /* Just some   more   text'.length + 1);
            assertWordRight(29, '   /* Just some   more   text'.length + 1);
            assertWordRight(30, '   /* Just some   more   text'.length + 1);
            assertWordRight(31, '   /* Just some   more   text '.length + 1);
            assertWordRight(32, '   /* Just some   more   text a'.length + 1);
            assertWordRight(33, '   /* Just some   more   text a+'.length + 1);
            assertWordRight(34, '   /* Just some   more   text a+='.length + 1);
            assertWordRight(35, '   /* Just some   more   text a+= '.length + 1);
            assertWordRight(36, '   /* Just some   more   text a+= 3'.length + 1);
            assertWordRight(37, '   /* Just some   more   text a+= 3 '.length + 1);
            assertWordRight(38, '   /* Just some   more   text a+= 3 +'.length + 1);
            assertWordRight(39, '   /* Just some   more   text a+= 3 +5'.length + 1);
            assertWordRight(40, '   /* Just some   more   text a+= 3 +5-'.length + 1);
            assertWordRight(41, '   /* Just some   more   text a+= 3 +5-3'.length + 1);
            assertWordRight(42, '   /* Just some   more   text a+= 3 +5-3 '.length + 1);
            assertWordRight(43, '   /* Just some   more   text a+= 3 +5-3 +'.length + 1);
            assertWordRight(44, '   /* Just some   more   text a+= 3 +5-3 + '.length + 1);
            assertWordRight(45, '   /* Just some   more   text a+= 3 +5-3 + 7'.length + 1);
            assertWordRight(46, '   /* Just some   more   text a+= 3 +5-3 + 7 '.length + 1);
            assertWordRight(47, '   /* Just some   more   text a+= 3 +5-3 + 7 *'.length + 1);
            assertWordRight(48, '   /* Just some   more   text a+= 3 +5-3 + 7 */'.length + 1);
            assertWordRight(49, '   /* Just some   more   text a+= 3 +5-3 + 7 */ '.length + 1);
            assertWordRight(50, '   /* Just some   more   text a+= 3 +5-3 + 7 */  '.length + 1);
        });
    }

    /**
     * test('issue #33788: Wrong cursor position when double click to select a word')
     */
    function testIssue33788WrongCursorPositionWhenDoubleClickToSelectAWord() {
        final model = createTextModel(
            [
                'Just some text'
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            CoreNavigationCommands.WordSelect.runCoreEditorCommand(viewModel, { position: new Position(1, 8) });
            assertDeepEquals(viewModel.getSelection(), new Selection(1, 6, 1, 10));

            CoreNavigationCommands.WordSelectDrag.runCoreEditorCommand(viewModel, { position: new Position(1, 8) });
            assertDeepEquals(viewModel.getSelection(), new Selection(1, 6, 1, 10));
        });
    }

    /**
     * test('issue #12887: Double-click highlighting separating white space')
     */
    function testIssue12887DoubleClickHighlightingSeparatingWhiteSpace() {
        final model = createTextModel(
            [
                'abc def'
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            CoreNavigationCommands.WordSelect.runCoreEditorCommand(viewModel, { position: new Position(1, 5) });
            assertDeepEquals(viewModel.getSelection(), new Selection(1, 5, 1, 8));
        });
    }

    /**
     * test('issue #9675: Undo/Redo adds a stop in between CHN Characters')
     */
    function testIssue9675UndoRedoAddsAStopInBetweenCHNCharacters() {
        withTestCodeEditor([], {}, (editor, viewModel) -> {
            final model = editor.getModel();
            assertCursor(viewModel, new Position(1, 1));

            // Typing sennsei in Japanese - Hiragana
            viewModel.type('ｓ', 'keyboard');
            viewModel.compositionType('せ', 1, 0, 0);
            viewModel.compositionType('せｎ', 1, 0, 0);
            viewModel.compositionType('せん', 2, 0, 0);
            viewModel.compositionType('せんｓ', 2, 0, 0);
            viewModel.compositionType('せんせ', 3, 0, 0);
            viewModel.compositionType('せんせ', 3, 0, 0);
            viewModel.compositionType('せんせい', 3, 0, 0);
            viewModel.compositionType('せんせい', 4, 0, 0);
            viewModel.compositionType('せんせい', 4, 0, 0);
            viewModel.compositionType('せんせい', 4, 0, 0);

            assertEquals(model.getLineContent(1), 'せんせい');
            assertCursor(viewModel, new Position(1, 5));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '');
            assertCursor(viewModel, new Position(1, 1));
        });
    }

    /**
     * test('issue #23983: Calling model.setEOL does not reset cursor position')
     */
    function testIssue23983CallingModelSetEOLDoesNotResetCursorPosition() {
        usingCursor({
            text: [
                'first line',
                'second line'
            ]
        }, (editor, model, viewModel) -> {
            model.setEOL(EndOfLineSequence.CRLF);

            viewModel.setSelections('test', [new Selection(2, 2, 2, 2)]);
            model.setEOL(EndOfLineSequence.LF);

            assertCursor(viewModel, new Selection(2, 2, 2, 2));
        });
    }

    /**
     * test('issue #23983: Calling model.setValue() resets cursor position')
     */
    function testIssue23983CallingModelSetValueResetsCursorPosition() {
        usingCursor({
            text: [
                'first line',
                'second line'
            ]
        }, (editor, model, viewModel) -> {
            model.setEOL(EndOfLineSequence.CRLF);

            viewModel.setSelections('test', [new Selection(2, 2, 2, 2)]);
            model.setValue([
                'different first line',
                'different second line',
                'new third line'
            ].join('\n'));

            assertCursor(viewModel, new Selection(1, 1, 1, 1));
        });
    }

    /**
     * test('issue #36740: wordwrap creates an extra step / character at the wrapping point')
     */
    function testIssue36740WordwrapCreatesAnExtraStepCharacterAtTheWrappingPoint() {
        // a single model line => 4 view lines
        withTestCodeEditor([
            [
                'Lorem ipsum ',
                'dolor sit amet ',
                'consectetur ',
                'adipiscing elit',
            ].join('')
        ], { wordWrap: 'wordWrapColumn', wordWrapColumn: 16 }, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 7, 1, 7)]);

            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 9, 1, 9));

            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 10, 1, 10));

            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 11, 1, 11));

            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 12, 1, 12));

            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 13, 1, 13));

            // moving to view line 2
            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 14, 1, 14));

            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 13, 1, 13));

            // moving back to view line 1
            moveLeft(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 12, 1, 12));
        });
    }

    /**
     * test('issue #110376: multiple selections with wordwrap behave differently')
     */
    function testIssue110376MultipleSelectionsWithWordwrapBehaveDifferently() {
        // a single model line => 4 view lines
        withTestCodeEditor([
            [
                'just a sentence. just a ',
                'sentence. just a sentence.',
            ].join('')
        ], { wordWrap: 'wordWrapColumn', wordWrapColumn: 25 }, (editor, viewModel) -> {
            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 16),
                new Selection(1, 18, 1, 33),
                new Selection(1, 35, 1, 50),
            ]);

            moveLeft(editor, viewModel);
            assertCursor(viewModel, [
                new Selection(1, 1, 1, 1),
                new Selection(1, 18, 1, 18),
                new Selection(1, 35, 1, 35),
            ]);

            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 16),
                new Selection(1, 18, 1, 33),
                new Selection(1, 35, 1, 50),
            ]);

            moveRight(editor, viewModel);
            assertCursor(viewModel, [
                new Selection(1, 16, 1, 16),
                new Selection(1, 33, 1, 33),
                new Selection(1, 50, 1, 50),
            ]);
        });
    }

    /**
     * test('issue #98320: Multi-Cursor, Wrap lines and cursorSelectRight ==> cursors out of sync')
     */
    function testIssue98320MultiCursorWrapLinesAndCursorSelectRightCursorsOutOfSync() {
        // a single model line => 4 view lines
        withTestCodeEditor([
            [
                'lorem_ipsum-1993x11x13',
                'dolor_sit_amet-1998x04x27',
                'consectetur-2007x10x08',
                'adipiscing-2012x07x27',
                'elit-2015x02x27',
            ].join('\n')
        ], { wordWrap: 'wordWrapColumn', wordWrapColumn: 16 }, (editor, viewModel) -> {
            viewModel.setSelections('test', [
                new Selection(1, 13, 1, 13),
                new Selection(2, 16, 2, 16),
                new Selection(3, 13, 3, 13),
                new Selection(4, 12, 4, 12),
                new Selection(5, 6, 5, 6),
            ]);
            assertCursor(viewModel, [
                new Selection(1, 13, 1, 13),
                new Selection(2, 16, 2, 16),
                new Selection(3, 13, 3, 13),
                new Selection(4, 12, 4, 12),
                new Selection(5, 6, 5, 6),
            ]);

            moveRight(editor, viewModel, true);
            assertCursor(viewModel, [
                new Selection(1, 13, 1, 14),
                new Selection(2, 16, 2, 17),
                new Selection(3, 13, 3, 14),
                new Selection(4, 12, 4, 13),
                new Selection(5, 6, 5, 7),
            ]);

            moveRight(editor, viewModel, true);
            assertCursor(viewModel, [
                new Selection(1, 13, 1, 15),
                new Selection(2, 16, 2, 18),
                new Selection(3, 13, 3, 15),
                new Selection(4, 12, 4, 14),
                new Selection(5, 6, 5, 8),
            ]);

            moveRight(editor, viewModel, true);
            assertCursor(viewModel, [
                new Selection(1, 13, 1, 16),
                new Selection(2, 16, 2, 19),
                new Selection(3, 13, 3, 16),
                new Selection(4, 12, 4, 15),
                new Selection(5, 6, 5, 9),
            ]);

            moveRight(editor, viewModel, true);
            assertCursor(viewModel, [
                new Selection(1, 13, 1, 17),
                new Selection(2, 16, 2, 20),
                new Selection(3, 13, 3, 17),
                new Selection(4, 12, 4, 16),
                new Selection(5, 6, 5, 10),
            ]);
        });
    }

    /**
     * test('issue #41573 - delete across multiple lines does not shrink the selection when word wraps')
     */
    function testIssue41573DeleteAcrossMultipleLinesDoesNotShrinkTheSelectionWhenWordWraps() {
        withTestCodeEditor([
            'Authorization: \'Bearer pHKRfCTFSnGxs6akKlb9ddIXcca0sIUSZJutPHYqz7vEeHdMTMh0SGN0IGU3a0n59DXjTLRsj5EJ2u33qLNIFi9fk5XF8pK39PndLYUZhPt4QvHGLScgSkK0L4gwzkzMloTQPpKhqiikiIOvyNNSpd2o8j29NnOmdTUOKi9DVt74PD2ohKxyOrWZ6oZprTkb3eKajcpnS0LABKfaw2rmv4\','
        ].join('\n'), { wordWrap: 'wordWrapColumn', wordWrapColumn: 100 }, (editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 43, false);
            moveTo(editor, viewModel, 1, 147, true);
            assertCursor(viewModel, new Selection(1, 43, 1, 147));

            editor.getModel().applyEdits([{
                range: new Range(1, 1, 1, 43),
                text: ''
            }]);

            assertCursor(viewModel, new Selection(1, 1, 1, 105));
        });
    }

    /**
     * test('issue #22717: Moving text cursor cause an incorrect position in Chinese')
     */
    function testIssue22717MovingTextCursorCauseAnIncorrectPositionInChinese() {
        // a single model line => 4 view lines
        withTestCodeEditor([
            [
                '一二三四五六七八九十',
                '12345678901234567890',
            ].join('\n')
        ], {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 5, 1, 5)]);

            moveDown(editor, viewModel);
            assertCursor(viewModel, new Selection(2, 9, 2, 9));

            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(2, 10, 2, 10));

            moveRight(editor, viewModel);
            assertCursor(viewModel, new Selection(2, 11, 2, 11));

            moveUp(editor, viewModel);
            assertCursor(viewModel, new Selection(1, 6, 1, 6));
        });
    }

    /**
     * test('issue #112301: new stickyTabStops feature interferes with word wrap')
     */
    function testIssue112301NewStickyTabStopsFeatureInterferesWithWordWrap() {
        withTestCodeEditor([
            [
                'function hello() {',
                '        console.log(`this is a long console message`)',
                '}',
            ].join('\n')
        ], { wordWrap: 'wordWrapColumn', wordWrapColumn: 32, stickyTabStops: true }, (editor, viewModel) -> {
            viewModel.setSelections('test', [
                new Selection(2, 31, 2, 31)
            ]);
            moveRight(editor, viewModel, false);
            assertCursor(viewModel, new Position(2, 32));

            moveRight(editor, viewModel, false);
            assertCursor(viewModel, new Position(2, 33));

            moveRight(editor, viewModel, false);
            assertCursor(viewModel, new Position(2, 34));

            moveLeft(editor, viewModel, false);
            assertCursor(viewModel, new Position(2, 33));

            moveLeft(editor, viewModel, false);
            assertCursor(viewModel, new Position(2, 32));

            moveLeft(editor, viewModel, false);
            assertCursor(viewModel, new Position(2, 31));
        });
    }

    /**
     * test('issue #44805: Should not be able to undo in readonly editor')
     */
    function testIssue44805ShouldNotBeAbleToUndoInReadonlyEditor() {
        final model = createTextModel(
            [
                ''
            ].join('\n')
        );

        withTestCodeEditor(model, { readOnly: true }, (editor, viewModel) -> {
            model.pushEditOperations([new Selection(1, 1, 1, 1)], [{
                range: new Range(1, 1, 1, 1),
                text: 'Hello world!'
            }], (_) -> [new Selection(1, 1, 1, 1)]);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'Hello world!');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'Hello world!');
        });
    }

    /**
     * test('issue #46314: ViewModel is out of sync with Model!')
     */
    function testIssue46314ViewModelIsOutOfSyncWithModel() {

        final tokenizationSupport:ITokenizationSupport = new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line:String, hasEOL:Bool, state:IState) -> {
                return new EncodedTokenizationResult(new UInt32Array(0), state);
            }
        );

        final LANGUAGE_ID = 'modelModeTest1';
        final languageRegistration = instantiationService.tokenizationRegistry.register(LANGUAGE_ID, tokenizationSupport);
        final model = createTextModel('Just text', LANGUAGE_ID);

        withTestCodeEditor(model, {}, (editor1, cursor1) -> {
            withTestCodeEditor(model, {}, (editor2, cursor2) -> {

                final disposable = editor1.onDidChangeCursorPosition((_) -> {
                    model.tokenization.tokenizeIfCheap(1);
                });

                model.applyEdits([{ range: new Range(1, 1, 1, 1), text: '-' }]);

                disposable.dispose();
            });
        });

        languageRegistration.dispose();
        model.dispose();
    }

    /**
     * test('issue #37967: problem replacing consecutive characters')
     */
    function testIssue37967ProblemReplacingConsecutiveCharacters() {
        final model = createTextModel(
            [
                'const a = "foo";',
                'const b = ""'
            ].join('\n')
        );

        withTestCodeEditor(model, { multiCursorMergeOverlapping: false }, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(1, 12, 1, 12),
                new Selection(1, 16, 1, 16),
                new Selection(2, 12, 2, 12),
                new Selection(2, 13, 2, 13),
            ]);

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);

            assertCursor(viewModel, [
                new Selection(1, 11, 1, 11),
                new Selection(1, 14, 1, 14),
                new Selection(2, 11, 2, 11),
                new Selection(2, 11, 2, 11),
            ]);

            viewModel.type('\'', 'keyboard');

            assertEquals(model.getLineContent(1), 'const a = \'foo\';');
            assertEquals(model.getLineContent(2), 'const b = \'\'');
        });
    }

    /**
     * test('issue #15761: Cursor doesn\'t move in a redo operation')
     */
    function testIssue15761CursorDoesnTMoveInARedoOperation() {
        final model = createTextModel(
            [
                'hello'
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(1, 4, 1, 4)
            ]);

            editor.executeEdits('test', [{
                range: new Range(1, 1, 1, 1),
                text: '*',
                forceMoveMarkers: true
            }]);
            assertCursor(viewModel, [
                new Selection(1, 5, 1, 5),
            ]);

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertCursor(viewModel, [
                new Selection(1, 4, 1, 4),
            ]);

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertCursor(viewModel, [
                new Selection(1, 5, 1, 5),
            ]);
        });
    }

    /**
     * test('issue #42783: API Calls with Undo Leave Cursor in Wrong Position')
     */
    function testIssue42783APICallsWithUndoLeaveCursorInWrongPosition() {
        final model = createTextModel(
            [
                'ab'
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(1, 1, 1, 1)
            ]);

            editor.executeEdits('test', [{
                range: new Range(1, 1, 1, 3),
                text: ''
            }]);
            assertCursor(viewModel, [
                new Selection(1, 1, 1, 1),
            ]);

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertCursor(viewModel, [
                new Selection(1, 1, 1, 1),
            ]);

            editor.executeEdits('test', [{
                range: new Range(1, 1, 1, 2),
                text: ''
            }]);
            assertCursor(viewModel, [
                new Selection(1, 1, 1, 1),
            ]);
        });
    }

    /**
     * test('issue #85712: Paste line moves cursor to start of current line rather than start of next line')
     */
    function testIssue85712PasteLineMovesCursorToStartOfCurrentLineRatherThanStartOfNextLine() {
        final model = createTextModel(
            [
                'abc123',
                ''
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(2, 1, 2, 1)
            ]);
            viewModel.paste('something\n', true);
            assertEquals(model.getValue(), [
                'abc123',
                'something',
                ''
            ].join('\n'));
            assertCursor(viewModel, new Position(3, 1));
        });
    }

    /**
     * test('issue #84897: Left delete behavior in some languages is changed')
     */
    function testIssue84897LeftDeleteBehaviorInSomeLanguagesIsChanged() {
        final model = createTextModel(
            [
                'สวัสดี'
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(1, 7, 1, 7)
            ]);

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'สวัสด');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'สวัส');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'สวั');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'สว');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'ส');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '');
        });
    }

    /**
     * test('issue #122914: Left delete behavior in some languages is changed (useTabStops: false)')
     */
    function testIssue122914LeftDeleteBehaviorInSomeLanguagesIsChangedUseTabStopsFalse() {
        final model = createTextModel(
            [
                'สวัสดี'
            ].join('\n')
        );

        withTestCodeEditor(model, { useTabStops: false }, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(1, 7, 1, 7)
            ]);

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'สวัสด');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'สวัส');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'สวั');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'สว');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'ส');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '');
        });
    }

    /**
     * test('issue #99629: Emoji modifiers in text treated separately when using backspace')
     */
    function testIssue99629EmojiModifiersInTextTreatedSeparatelyWhenUsingBackspace() {
        final model = createTextModel(
            [
                '👶🏾'
            ].join('\n')
        );

        withTestCodeEditor(model, { useTabStops: false }, (editor, viewModel) -> {
            final len = model.getValueLength();
            editor.setSelections([
                new Selection(1, 1 + len, 1, 1 + len)
            ]);

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '');
        });
    }

    /**
     * test('issue #99629: Emoji modifiers in text treated separately when using backspace (ZWJ sequence)')
     */
    function testIssue99629EmojiModifiersInTextTreatedSeparatelyWhenUsingBackspaceZWJSequence() {
        final model = createTextModel(
            [
                '👨‍👩🏽‍👧‍👦'
            ].join('\n')
        );

        withTestCodeEditor(model, { useTabStops: false }, (editor, viewModel) -> {
            final len = model.getValueLength();
            editor.setSelections([
                new Selection(1, 1 + len, 1, 1 + len)
            ]);

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '👨‍👩🏽‍👧');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '👨‍👩🏽');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '👨');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '');
        });
    }

    /**
     * test('issue #105730: move left behaves differently for multiple cursors')
     */
    function testIssue105730MoveLeftBehavesDifferentlyForMultipleCursors() {
        final model = createTextModel('asdfghjkl, asdfghjkl, asdfghjkl, ');

        withTestCodeEditor(
            model,
            {
                wordWrap: 'wordWrapColumn',
                wordWrapColumn: 24
            },
            (editor, viewModel) -> {
                viewModel.setSelections('test', [
                    new Selection(1, 10, 1, 12),
                    new Selection(1, 21, 1, 23),
                    new Selection(1, 32, 1, 34)
                ]);
                moveLeft(editor, viewModel, false);
                assertCursor(viewModel, [
                    new Selection(1, 10, 1, 10),
                    new Selection(1, 21, 1, 21),
                    new Selection(1, 32, 1, 32)
                ]);

                viewModel.setSelections('test', [
                    new Selection(1, 10, 1, 12),
                    new Selection(1, 21, 1, 23),
                    new Selection(1, 32, 1, 34)
                ]);
                moveLeft(editor, viewModel, true);
                assertCursor(viewModel, [
                    new Selection(1, 10, 1, 11),
                    new Selection(1, 21, 1, 22),
                    new Selection(1, 32, 1, 33)
                ]);
            });
    }

    /**
     * test('issue #105730: move right should always skip wrap point')
     */
    function testIssue105730MoveRightShouldAlwaysSkipWrapPoint() {
        final model = createTextModel('asdfghjkl, asdfghjkl, asdfghjkl, \nasdfghjkl,');

        withTestCodeEditor(
            model,
            {
                wordWrap: 'wordWrapColumn',
                wordWrapColumn: 24
            },
            (editor, viewModel) -> {
                viewModel.setSelections('test', [
                    new Selection(1, 22, 1, 22)
                ]);
                moveRight(editor, viewModel, false);
                moveRight(editor, viewModel, false);
                assertCursor(viewModel, [
                    new Selection(1, 24, 1, 24),
                ]);

                viewModel.setSelections('test', [
                    new Selection(1, 22, 1, 22)
                ]);
                moveRight(editor, viewModel, true);
                moveRight(editor, viewModel, true);
                assertCursor(viewModel, [
                    new Selection(1, 22, 1, 24),
                ]);
            }
        );
    }

    /**
     * test('issue #123178: sticky tab in consecutive wrapped lines')
     */
    function testIssue123178StickyTabInConsecutiveWrappedLines() {
        final model = createTextModel('    aaaa        aaaa', null, { tabSize: 4 });

        withTestCodeEditor(
            model,
            {
                wordWrap: 'wordWrapColumn',
                wordWrapColumn: 8,
                stickyTabStops: true,
            },
            (editor, viewModel) -> {
                viewModel.setSelections('test', [
                    new Selection(1, 9, 1, 9)
                ]);
                moveRight(editor, viewModel, false);
                assertCursor(viewModel, [
                    new Selection(1, 10, 1, 10),
                ]);

                moveLeft(editor, viewModel, false);
                assertCursor(viewModel, [
                    new Selection(1, 9, 1, 9),
                ]);
            }
        );
    }

    /**
     * test('Cursor honors insertSpaces configuration on new line')
     */
    function testCursorHonorsInsertSpacesConfigurationOnNewLine() {
        usingCursor({
            text: [
                '    \tMy First Line\t ',
                '\tMy Second Line',
                '    Third Line',
                '',
                '1'
            ]
        }, (editor, model, viewModel) -> {
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(1, 21), source: 'keyboard' });
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    \tMy First Line\t ');
            assertEquals(model.getLineContent(2), '        ');
        });
    }

    /**
     * test('Cursor honors insertSpaces configuration on tab')
     */
    function testCursorHonorsInsertSpacesConfigurationOnTab() {
        final model = createTextModel(
            [
                '    \tMy First Line\t ',
                'My Second Line123',
                '    Third Line',
                '',
                '1'
            ].join('\n'),
            null,
            {
                tabSize: 13,
                indentSize: 13,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            // Tab on column 1
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(2, 1) });
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), '             My Second Line123');
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);

            // Tab on column 2
            assertEquals(model.getLineContent(2), 'My Second Line123');
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(2, 2) });
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'M            y Second Line123');
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);

            // Tab on column 3
            assertEquals(model.getLineContent(2), 'My Second Line123');
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(2, 3) });
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'My            Second Line123');
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);

            // Tab on column 4
            assertEquals(model.getLineContent(2), 'My Second Line123');
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(2, 4) });
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'My           Second Line123');
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);

            // Tab on column 5
            assertEquals(model.getLineContent(2), 'My Second Line123');
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(2, 5) });
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'My S         econd Line123');
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);

            // Tab on column 5
            assertEquals(model.getLineContent(2), 'My Second Line123');
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(2, 5) });
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'My S         econd Line123');
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);

            // Tab on column 13
            assertEquals(model.getLineContent(2), 'My Second Line123');
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(2, 13) });
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'My Second Li ne123');
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);

            // Tab on column 14
            assertEquals(model.getLineContent(2), 'My Second Line123');
            CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, { position: new Position(2, 14) });
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'My Second Lin             e123');
        });
    }

    /**
     * test('Enter auto-indents with insertSpaces setting 1')
     */
    function testEnterAutoIndentsWithInsertSpacesSetting1() {
        final languageId = setupOnEnterLanguage(IndentAction.Indent);
        usingCursor({
            text: [
                '\thello'
            ],
            languageId: languageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 7, false);
            assertCursor(viewModel, new Selection(1, 7, 1, 7));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.CRLF), '\thello\r\n        ');
        });
    }

    /**
     * test('Enter auto-indents with insertSpaces setting 2')
     */
    function testEnterAutoIndentsWithInsertSpacesSetting2() {
        final languageId = setupOnEnterLanguage(IndentAction.None);
        usingCursor({
            text: [
                '\thello'
            ],
            languageId: languageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 7, false);
            assertCursor(viewModel, new Selection(1, 7, 1, 7));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.CRLF), '\thello\r\n    ');
        });
    }

    /**
     * test('Enter auto-indents with insertSpaces setting 3')
     */
    function testEnterAutoIndentsWithInsertSpacesSetting3() {
        final languageId = setupOnEnterLanguage(IndentAction.IndentOutdent);
        usingCursor({
            text: [
                '\thell()'
            ],
            languageId: languageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 7, false);
            assertCursor(viewModel, new Selection(1, 7, 1, 7));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.CRLF), '\thell(\r\n        \r\n    )');
        });
    }

    /**
     * test('issue #148256: Pressing Enter creates line with bad indent with insertSpaces: true')
     */
    function testIssue148256PressingEnterCreatesLineWithBadIndentWithInsertSpacesTrue() {
        usingCursor({
            text: [
                '  \t'
            ],
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 4, false);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(), '  \t\n    ');
        });
    }

    /**
     * test('issue #148256: Pressing Enter creates line with bad indent with insertSpaces: false')
     */
    function testIssue148256PressingEnterCreatesLineWithBadIndentWithInsertSpacesFalse() {
        usingCursor({
            text: [
                '  \t'
            ]
        }, (editor, model, viewModel) -> {
            model.updateOptions({
                insertSpaces: false
            });
            moveTo(editor, viewModel, 1, 4, false);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(), '  \t\n\t');
        });
    }

    /**
     * test('removeAutoWhitespace off')
     */
    function testRemoveAutoWhitespaceOff() {
        usingCursor({
            text: [
                '    some  line abc  '
            ],
            modelOpts: {
                trimAutoWhitespace: false
            }
        }, (editor, model, viewModel) -> {

            // Move cursor to the end, verify that we do not trim whitespaces if line has values
            moveTo(editor, viewModel, 1, model.getLineContent(1).length + 1);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    some  line abc  ');
            assertEquals(model.getLineContent(2), '    ');

            // Try to enter again, we should trimmed previous line
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    some  line abc  ');
            assertEquals(model.getLineContent(2), '    ');
            assertEquals(model.getLineContent(3), '    ');
        });
    }

    /**
     * test('removeAutoWhitespace on: removes only whitespace the cursor added 1')
     */
    function testRemoveAutoWhitespaceOnRemovesOnlyWhitespaceTheCursorAdded1() {
        usingCursor({
            text: [
                '    '
            ]
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, model.getLineContent(1).length + 1);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    ');
            assertEquals(model.getLineContent(2), '    ');

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    ');
            assertEquals(model.getLineContent(2), '');
            assertEquals(model.getLineContent(3), '    ');
        });
    }

    /**
     * test('issue #115033: indent and appendText')
     */
    function testIssue115033IndentAndAppendText() {
        final languageId = 'onEnterMode';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            onEnterRules: [{
                beforeText: new RegExp('.*'),
                action: {
                    indentAction: IndentAction.Indent,
                    appendText: 'x'
                }
            }]
        }));
        usingCursor({
            text: [
                'text'
            ],
            languageId: languageId,
        }, (editor, model, viewModel) -> {

            moveTo(editor, viewModel, 1, 5);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), 'text');
            assertEquals(model.getLineContent(2), '    x');
            assertCursor(viewModel, new Position(2, 6));
        });
    }

    /**
     * test('issue #6862: Editor removes auto inserted indentation when formatting on type')
     */
    function testIssue6862EditorRemovesAutoInsertedIndentationWhenFormattingOnType() {
        final languageId = setupOnEnterLanguage(IndentAction.IndentOutdent);
        usingCursor({
            text: [
                'function foo (params: string) {}'
            ],
            languageId: languageId,
        }, (editor, model, viewModel) -> {

            moveTo(editor, viewModel, 1, 32);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), 'function foo (params: string) {');
            assertEquals(model.getLineContent(2), '    ');
            assertEquals(model.getLineContent(3), '}');

            // vscode's local class TestCommand: Issue6862TestCommand below
            viewModel.executeCommand(new Issue6862TestCommand(viewModel), 'autoFormat');
            assertEquals(model.getLineContent(1), 'function foo(params: string) {');
            assertEquals(model.getLineContent(2), '    ');
            assertEquals(model.getLineContent(3), '}');
        });
    }

    /**
     * test('removeAutoWhitespace on: removes only whitespace the cursor added 2')
     */
    function testRemoveAutoWhitespaceOnRemovesOnlyWhitespaceTheCursorAdded2() {
        final languageId = 'testLang';
        final registration = languageService.registerLanguage({ id: languageId });
        final model = createTextModel(
            [
                '    if (a) {',
                '        ',
                '',
                '',
                '    }'
            ].join('\n'),
            languageId
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {

            moveTo(editor, viewModel, 3, 1);
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '    if (a) {');
            assertEquals(model.getLineContent(2), '        ');
            assertEquals(model.getLineContent(3), '    ');
            assertEquals(model.getLineContent(4), '');
            assertEquals(model.getLineContent(5), '    }');

            moveTo(editor, viewModel, 4, 1);
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '    if (a) {');
            assertEquals(model.getLineContent(2), '        ');
            assertEquals(model.getLineContent(3), '');
            assertEquals(model.getLineContent(4), '    ');
            assertEquals(model.getLineContent(5), '    }');

            moveTo(editor, viewModel, 5, model.getLineMaxColumn(5));
            viewModel.type('something', 'keyboard');
            assertEquals(model.getLineContent(1), '    if (a) {');
            assertEquals(model.getLineContent(2), '        ');
            assertEquals(model.getLineContent(3), '');
            assertEquals(model.getLineContent(4), '');
            assertEquals(model.getLineContent(5), '    }something');
        });

        registration.dispose();
    }

    /**
     * test('removeAutoWhitespace on: test 1')
     */
    function testRemoveAutoWhitespaceOnTest1() {
        final model = createTextModel(
            [
                '    some  line abc  '
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {

            // Move cursor to the end, verify that we do not trim whitespaces if line has values
            moveTo(editor, viewModel, 1, model.getLineContent(1).length + 1);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    some  line abc  ');
            assertEquals(model.getLineContent(2), '    ');

            // Try to enter again, we should trimmed previous line
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    some  line abc  ');
            assertEquals(model.getLineContent(2), '');
            assertEquals(model.getLineContent(3), '    ');

            // More whitespaces
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '    some  line abc  ');
            assertEquals(model.getLineContent(2), '');
            assertEquals(model.getLineContent(3), '        ');

            // Enter and verify that trimmed again
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    some  line abc  ');
            assertEquals(model.getLineContent(2), '');
            assertEquals(model.getLineContent(3), '');
            assertEquals(model.getLineContent(4), '        ');

            // Trimmed if we will keep only text
            moveTo(editor, viewModel, 1, 5);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    ');
            assertEquals(model.getLineContent(2), '    some  line abc  ');
            assertEquals(model.getLineContent(3), '');
            assertEquals(model.getLineContent(4), '');
            assertEquals(model.getLineContent(5), '');

            // Trimmed if we will keep only text by selection
            moveTo(editor, viewModel, 2, 5);
            moveTo(editor, viewModel, 3, 1, true);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(1), '    ');
            assertEquals(model.getLineContent(2), '    ');
            assertEquals(model.getLineContent(3), '    ');
            assertEquals(model.getLineContent(4), '');
            assertEquals(model.getLineContent(5), '');
        });
    }

    /**
     * test('issue #15118: remove auto whitespace when pasting entire line')
     */
    function testIssue15118RemoveAutoWhitespaceWhenPastingEntireLine() {
        final model = createTextModel(
            [
                '    function f() {',
                '        // I\'m gonna copy this line',
                '        return 3;',
                '    }',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {

            moveTo(editor, viewModel, 3, model.getLineMaxColumn(3));
            viewModel.type('\n', 'keyboard');

            assertEquals(model.getValue(), [
                '    function f() {',
                '        // I\'m gonna copy this line',
                '        return 3;',
                '        ',
                '    }',
            ].join('\n'));
            assertCursor(viewModel, new Position(4, model.getLineMaxColumn(4)));

            viewModel.paste('        // I\'m gonna copy this line\n', true);
            assertEquals(model.getValue(), [
                '    function f() {',
                '        // I\'m gonna copy this line',
                '        return 3;',
                '        // I\'m gonna copy this line',
                '',
                '    }',
            ].join('\n'));
            assertCursor(viewModel, new Position(5, 1));
        });
    }

    /**
     * test('issue #40695: maintain cursor position when copying lines using ctrl+c, ctrl+v')
     */
    function testIssue40695MaintainCursorPositionWhenCopyingLinesUsingCtrlCCtrlV() {
        final model = createTextModel(
            [
                '    function f() {',
                '        // I\'m gonna copy this line',
                '        // Another line',
                '        return 3;',
                '    }',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {

            editor.setSelections([new Selection(4, 10, 4, 10)]);
            viewModel.paste('        // I\'m gonna copy this line\n', true);

            assertEquals(model.getValue(), [
                '    function f() {',
                '        // I\'m gonna copy this line',
                '        // Another line',
                '        // I\'m gonna copy this line',
                '        return 3;',
                '    }',
            ].join('\n'));
            assertCursor(viewModel, new Position(5, 10));
        });
    }

    /**
     * test('UseTabStops is off')
     */
    function testUseTabStopsIsOff() {
        final model = createTextModel(
            [
                '    x',
                '        a    ',
                '    '
            ].join('\n')
        );

        withTestCodeEditor(model, { useTabStops: false }, (editor, viewModel) -> {
            // DeleteLeft removes just one whitespace
            moveTo(editor, viewModel, 2, 9);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), '       a    ');
        });
    }

    /**
     * test('Backspace removes whitespaces with tab size')
     */
    function testBackspaceRemovesWhitespacesWithTabSize() {
        final model = createTextModel(
            [
                ' \t \t     x',
                '        a    ',
                '    '
            ].join('\n')
        );

        withTestCodeEditor(model, { useTabStops: true }, (editor, viewModel) -> {
            // DeleteLeft does not remove tab size, because some text exists before
            moveTo(editor, viewModel, 2, model.getLineContent(2).length + 1);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), '        a   ');

            // DeleteLeft removes tab size = 4
            moveTo(editor, viewModel, 2, 9);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), '    a   ');

            // DeleteLeft removes tab size = 4
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'a   ');

            // Undo DeleteLeft - get us back to original indentation
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), '        a   ');

            // Nothing is broken when cursor is in (1,1)
            moveTo(editor, viewModel, 1, 1);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), ' \t \t     x');

            // DeleteLeft stops at tab stops even in mixed whitespace case
            moveTo(editor, viewModel, 1, 10);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), ' \t \t    x');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), ' \t \tx');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), ' \tx');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'x');

            // DeleteLeft on last line
            moveTo(editor, viewModel, 3, model.getLineContent(3).length + 1);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(3), '');

            // DeleteLeft with removing new line symbol
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'x\n        a   ');

            // In case of selection DeleteLeft only deletes selected text
            moveTo(editor, viewModel, 2, 3);
            moveTo(editor, viewModel, 2, 4, true);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), '       a   ');
        });
    }

    /**
     * test('PR #5423: Auto indent + undo + redo is funky')
     */
    function testPR5423AutoIndentUndoRedoIsFunky() {
        final model = createTextModel(
            [
                ''
            ].join('\n'),
            null,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n', 'assert1');

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\t', 'assert2');

            viewModel.type('y', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\ty', 'assert2');

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\ty\n\t', 'assert3');

            viewModel.type('x');
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\ty\n\tx', 'assert4');

            CoreNavigationCommands.CursorLeft.runCoreEditorCommand(viewModel, {});
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\ty\n\tx', 'assert5');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\ty\nx', 'assert6');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\tyx', 'assert7');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\tx', 'assert8');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\nx', 'assert9');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'x', 'assert10');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\nx', 'assert11');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\ty\nx', 'assert12');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\ty\n\tx', 'assert13');

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\n\ty\nx', 'assert14');

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '\nx', 'assert15');

            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'x', 'assert16');
        });
    }

    /**
     * test('issue #90973: Undo brings back model alternative version')
     */
    function testIssue90973UndoBringsBackModelAlternativeVersion() {
        final model = createTextModel(
            [
                ''
            ].join('\n'),
            null,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            final beforeVersion = model.getVersionId();
            final beforeAltVersion = model.getAlternativeVersionId();
            viewModel.type('Hello', 'keyboard');
            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            final afterVersion = model.getVersionId();
            final afterAltVersion = model.getAlternativeVersionId();

            assertNotEquals(beforeVersion, afterVersion);
            assertEquals(beforeAltVersion, afterAltVersion);
        });
    }

    /**
     * test('Enter honors increaseIndentPattern')
     */
    function testEnterHonorsIncreaseIndentPattern() {
        usingCursor({
            text: [
                'if (true) {',
                '\tif (true) {'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false },
            editorOpts: { autoIndent: 'full' }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 12, false);
            assertCursor(viewModel, new Selection(1, 12, 1, 12));

            viewModel.type('\n', 'keyboard');
            model.tokenization.forceTokenization(model.getLineCount());
            assertCursor(viewModel, new Selection(2, 2, 2, 2));

            moveTo(editor, viewModel, 3, 13, false);
            assertCursor(viewModel, new Selection(3, 13, 3, 13));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 3, 4, 3));
        });
    }

    /**
     * test('Type honors decreaseIndentPattern')
     */
    function testTypeHonorsDecreaseIndentPattern() {
        usingCursor({
            text: [
                'if (true) {',
                '\t'
            ],
            languageId: indentRulesLanguageId,
            editorOpts: { autoIndent: 'full' }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 2, false);
            assertCursor(viewModel, new Selection(2, 2, 2, 2));

            viewModel.type('}', 'keyboard');
            assertCursor(viewModel, new Selection(2, 2, 2, 2));
            assertEquals(model.getLineContent(2), '}', '001');
        });
    }

    /**
     * test('Enter honors unIndentedLinePattern')
     */
    function testEnterHonorsUnIndentedLinePattern() {
        usingCursor({
            text: [
                'if (true) {',
                '\t\t\treturn true'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false },
            editorOpts: { autoIndent: 'full' }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 15, false);
            assertCursor(viewModel, new Selection(2, 15, 2, 15));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(3, 2, 3, 2));
        });
    }

    /**
     * test('Enter honors indentNextLinePattern')
     */
    function testEnterHonorsIndentNextLinePattern() {
        usingCursor({
            text: [
                'if (true)',
                '\treturn true;',
                'if (true)',
                '\t\t\t\treturn true'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false },
            editorOpts: { autoIndent: 'full' }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 14, false);
            assertCursor(viewModel, new Selection(2, 14, 2, 14));

            viewModel.type('\n', 'keyboard');
            model.tokenization.forceTokenization(model.getLineCount());
            assertCursor(viewModel, new Selection(3, 1, 3, 1));

            moveTo(editor, viewModel, 5, 16, false);
            assertCursor(viewModel, new Selection(5, 16, 5, 16));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(6, 2, 6, 2));
        });
    }

    /**
     * test('Enter honors indentNextLinePattern 2')
     */
    function testEnterHonorsIndentNextLinePattern2() {
        final model = createTextModel(
            [
                'if (true)',
                '\tif (true)'
            ].join('\n'),
            indentRulesLanguageId,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, { autoIndent: 'full' }, (editor, viewModel) -> {
            moveTo(editor, viewModel, 2, 11, false);
            assertCursor(viewModel, new Selection(2, 11, 2, 11));

            viewModel.type('\n', 'keyboard');
            model.tokenization.forceTokenization(model.getLineCount());
            assertCursor(viewModel, new Selection(3, 3, 3, 3));

            viewModel.type('console.log();', 'keyboard');
            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 1, 4, 1));
        });
    }

    /**
     * test('Enter honors intential indent')
     */
    function testEnterHonorsIntentialIndent() {
        usingCursor({
            text: [
                'if (true) {',
                '\tif (true) {',
                'return true;',
                '}}'
            ],
            languageId: indentRulesLanguageId,
            editorOpts: { autoIndent: 'full' }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 13, false);
            assertCursor(viewModel, new Selection(3, 13, 3, 13));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 1, 4, 1));
            assertEquals(model.getLineContent(3), 'return true;', '001');
        });
    }

    /**
     * test('Enter supports selection 1')
     */
    function testEnterSupportsSelection1() {
        usingCursor({
            text: [
                'if (true) {',
                '\tif (true) {',
                '\t\treturn true;',
                '\t}a}'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 4, 3, false);
            moveTo(editor, viewModel, 4, 4, true);
            assertCursor(viewModel, new Selection(4, 3, 4, 4));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(5, 1, 5, 1));
            assertEquals(model.getLineContent(4), '\t}', '001');
        });
    }

    /**
     * test('Enter supports selection 2')
     */
    function testEnterSupportsSelection2() {
        usingCursor({
            text: [
                'if (true) {',
                '\tif (true) {'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 12, false);
            moveTo(editor, viewModel, 2, 13, true);
            assertCursor(viewModel, new Selection(2, 12, 2, 13));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(3, 3, 3, 3));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 3, 4, 3));
        });
    }

    /**
     * test('Enter honors tabSize and insertSpaces 1')
     */
    function testEnterHonorsTabSizeAndInsertSpaces1() {
        usingCursor({
            text: [
                'if (true) {',
                '\tif (true) {'
            ],
            languageId: indentRulesLanguageId,
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 12, false);
            assertCursor(viewModel, new Selection(1, 12, 1, 12));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(2, 5, 2, 5));

            model.tokenization.forceTokenization(model.getLineCount());

            moveTo(editor, viewModel, 3, 13, false);
            assertCursor(viewModel, new Selection(3, 13, 3, 13));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 9, 4, 9));
        });
    }

    /**
     * test('Enter honors tabSize and insertSpaces 2')
     */
    function testEnterHonorsTabSizeAndInsertSpaces2() {
        usingCursor({
            text: [
                'if (true) {',
                '    if (true) {'
            ],
            languageId: indentRulesLanguageId,
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 12, false);
            assertCursor(viewModel, new Selection(1, 12, 1, 12));

            viewModel.type('\n', 'keyboard');
            model.tokenization.forceTokenization(model.getLineCount());
            assertCursor(viewModel, new Selection(2, 5, 2, 5));

            moveTo(editor, viewModel, 3, 16, false);
            assertCursor(viewModel, new Selection(3, 16, 3, 16));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(3), '    if (true) {');
            assertCursor(viewModel, new Selection(4, 9, 4, 9));
        });
    }

    /**
     * test('Enter honors tabSize and insertSpaces 3')
     */
    function testEnterHonorsTabSizeAndInsertSpaces3() {
        usingCursor({
            text: [
                'if (true) {',
                '    if (true) {'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 12, false);
            assertCursor(viewModel, new Selection(1, 12, 1, 12));

            viewModel.type('\n', 'keyboard');
            model.tokenization.forceTokenization(model.getLineCount());
            assertCursor(viewModel, new Selection(2, 2, 2, 2));

            moveTo(editor, viewModel, 3, 16, false);
            assertCursor(viewModel, new Selection(3, 16, 3, 16));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(3), '    if (true) {');
            assertCursor(viewModel, new Selection(4, 3, 4, 3));
        });
    }

    /**
     * test('Enter supports intentional indentation')
     */
    function testEnterSupportsIntentionalIndentation() {
        usingCursor({
            text: [
                '\tif (true) {',
                '\t\tswitch(true) {',
                '\t\t\tcase true:',
                '\t\t\t\tbreak;',
                '\t\t}',
                '\t}'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false },
            editorOpts: { autoIndent: 'full' }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 5, 4, false);
            assertCursor(viewModel, new Selection(5, 4, 5, 4));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(5), '\t\t}');
            assertCursor(viewModel, new Selection(6, 3, 6, 3));
        });
    }

    /**
     * test('Enter should not adjust cursor position when press enter in the middle of a line 1')
     */
    function testEnterShouldNotAdjustCursorPositionWhenPressEnterInTheMiddleOfALine1() {
        usingCursor({
            text: [
                'if (true) {',
                '\tif (true) {',
                '\t\treturn true;',
                '\t}a}'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 9, false);
            assertCursor(viewModel, new Selection(3, 9, 3, 9));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 3, 4, 3));
            assertEquals(model.getLineContent(4), '\t\t true;', '001');
        });
    }

    /**
     * test('Enter should not adjust cursor position when press enter in the middle of a line 2')
     */
    function testEnterShouldNotAdjustCursorPositionWhenPressEnterInTheMiddleOfALine2() {
        usingCursor({
            text: [
                'if (true) {',
                '\tif (true) {',
                '\t\treturn true;',
                '\t}a}'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 3, false);
            assertCursor(viewModel, new Selection(3, 3, 3, 3));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 3, 4, 3));
            assertEquals(model.getLineContent(4), '\t\treturn true;', '001');
        });
    }

    /**
     * test('Enter should not adjust cursor position when press enter in the middle of a line 3')
     */
    function testEnterShouldNotAdjustCursorPositionWhenPressEnterInTheMiddleOfALine3() {
        usingCursor({
            text: [
                'if (true) {',
                '  if (true) {',
                '    return true;',
                '  }a}'
            ],
            languageId: indentRulesLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 11, false);
            assertCursor(viewModel, new Selection(3, 11, 3, 11));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 5, 4, 5));
            assertEquals(model.getLineContent(4), '     true;', '001');
        });
    }

    /**
     * test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 1')
     */
    function testEnterShouldAdjustCursorPositionWhenPressEnterInTheMiddleOfLeadingWhitespaces1() {
        usingCursor({
            text: [
                'if (true) {',
                '\tif (true) {',
                '\t\treturn true;',
                '\t}a}'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 2, false);
            assertCursor(viewModel, new Selection(3, 2, 3, 2));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 2, 4, 2));
            assertEquals(model.getLineContent(4), '\t\treturn true;', '001');

            moveTo(editor, viewModel, 4, 1, false);
            assertCursor(viewModel, new Selection(4, 1, 4, 1));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(5, 1, 5, 1));
            assertEquals(model.getLineContent(5), '\t\treturn true;', '002');
        });
    }

    /**
     * test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 2')
     */
    function testEnterShouldAdjustCursorPositionWhenPressEnterInTheMiddleOfLeadingWhitespaces2() {
        usingCursor({
            text: [
                '\tif (true) {',
                '\t\tif (true) {',
                '\t    \treturn true;',
                '\t\t}a}'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 4, false);
            assertCursor(viewModel, new Selection(3, 4, 3, 4));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 3, 4, 3));
            assertEquals(model.getLineContent(4), '\t\t\treturn true;', '001');

            moveTo(editor, viewModel, 4, 1, false);
            assertCursor(viewModel, new Selection(4, 1, 4, 1));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(5, 1, 5, 1));
            assertEquals(model.getLineContent(5), '\t\t\treturn true;', '002');
        });
    }

    /**
     * test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 3')
     */
    function testEnterShouldAdjustCursorPositionWhenPressEnterInTheMiddleOfLeadingWhitespaces3() {
        usingCursor({
            text: [
                'if (true) {',
                '  if (true) {',
                '    return true;',
                '}a}'
            ],
            languageId: indentRulesLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 2, false);
            assertCursor(viewModel, new Selection(3, 2, 3, 2));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 2, 4, 2));
            assertEquals(model.getLineContent(4), '    return true;', '001');

            moveTo(editor, viewModel, 4, 3, false);
            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(5, 3, 5, 3));
            assertEquals(model.getLineContent(5), '    return true;', '002');
        });
    }

    /**
     * test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 4')
     */
    function testEnterShouldAdjustCursorPositionWhenPressEnterInTheMiddleOfLeadingWhitespaces4() {
        usingCursor({
            text: [
                'if (true) {',
                '  if (true) {',
                '\t  return true;',
                '}a}',
                '',
                'if (true) {',
                '  if (true) {',
                '\t  return true;',
                '}a}'
            ],
            languageId: indentRulesLanguageId,
            modelOpts: {
                tabSize: 2,
                indentSize: 2
            }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 3, false);
            assertCursor(viewModel, new Selection(3, 3, 3, 3));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 4, 4, 4));
            assertEquals(model.getLineContent(4), '    return true;', '001');

            moveTo(editor, viewModel, 9, 4, false);
            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(10, 5, 10, 5));
            assertEquals(model.getLineContent(10), '    return true;', '001');
        });
    }

    /**
     * test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 5')
     */
    function testEnterShouldAdjustCursorPositionWhenPressEnterInTheMiddleOfLeadingWhitespaces5() {
        usingCursor({
            text: [
                'if (true) {',
                '  if (true) {',
                '    return true;',
                '    return true;',
                ''
            ],
            languageId: indentRulesLanguageId,
            modelOpts: { tabSize: 2 }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 5, false);
            moveTo(editor, viewModel, 4, 3, true);
            assertCursor(viewModel, new Selection(3, 5, 4, 3));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 3, 4, 3));
            assertEquals(model.getLineContent(4), '    return true;', '001');
        });
    }

    /**
     * test('issue microsoft/monaco-editor#108 part 1/2: Auto indentation on Enter with selection is half broken')
     */
    function testIssueMicrosoftMonacoEditor108Part12AutoIndentationOnEnterWithSelectionIsHalfBroken() {
        usingCursor({
            text: [
                'function baz() {',
                '\tvar x = 1;',
                '\t\t\t\t\t\t\treturn x;',
                '}'
            ],
            modelOpts: {
                insertSpaces: false,
            },
            languageId: indentRulesLanguageId,
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 8, false);
            moveTo(editor, viewModel, 2, 12, true);
            assertCursor(viewModel, new Selection(3, 8, 2, 12));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(3), '\treturn x;');
            assertCursor(viewModel, new Position(3, 2));
        });
    }

    /**
     * test('issue microsoft/monaco-editor#108 part 2/2: Auto indentation on Enter with selection is half broken')
     */
    function testIssueMicrosoftMonacoEditor108Part22AutoIndentationOnEnterWithSelectionIsHalfBroken() {
        usingCursor({
            text: [
                'function baz() {',
                '\tvar x = 1;',
                '\t\t\t\t\t\t\treturn x;',
                '}'
            ],
            modelOpts: {
                insertSpaces: false,
            },
            languageId: indentRulesLanguageId,
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 12, false);
            moveTo(editor, viewModel, 3, 8, true);
            assertCursor(viewModel, new Selection(2, 12, 3, 8));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(3), '\treturn x;');
            assertCursor(viewModel, new Position(3, 2));
        });
    }

    /**
     * test('onEnter works if there are no indentation rules')
     */
    function testOnEnterWorksIfThereAreNoIndentationRules() {
        usingCursor({
            text: [
                '<?',
                '\tif (true) {',
                '\t\techo $$hi;',
                '\t\techo $$bye;',
                '\t}',
                '?>'
            ],
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 5, 3, false);
            assertCursor(viewModel, new Selection(5, 3, 5, 3));

            viewModel.type('\n', 'keyboard');
            assertEquals(model.getLineContent(6), '\t');
            assertCursor(viewModel, new Selection(6, 2, 6, 2));
            assertEquals(model.getLineContent(5), '\t}');
        });
    }

    /**
     * test('onEnter works if there are no indentation rules 2')
     */
    function testOnEnterWorksIfThereAreNoIndentationRules2() {
        usingCursor({
            text: [
                '\tif (5)',
                '\t\treturn 5;',
                '\t'
            ],
            modelOpts: { insertSpaces: false }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 2, false);
            assertCursor(viewModel, new Selection(3, 2, 3, 2));

            viewModel.type('\n', 'keyboard');
            assertCursor(viewModel, new Selection(4, 2, 4, 2));
            assertEquals(model.getLineContent(4), '\t');
        });
    }

    /**
     * test('bug #16543: Tab should indent to correct indentation spot immediately')
     */
    function testBug16543TabShouldIndentToCorrectIndentationSpotImmediately() {
        final model = createTextModel(
            [
                'function baz() {',
                '\tfunction hello() { // something here',
                '\t',
                '',
                '\t}',
                '}'
            ].join('\n'),
            indentRulesLanguageId,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 4, 1, false);
            assertCursor(viewModel, new Selection(4, 1, 4, 1));

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(4), '\t\t');
        });
    }

    /**
     * test('bug #2938 (1): When pressing Tab on white-space only lines, indent straight to the right spot (similar to empty lines)')
     */
    function testBug29381WhenPressingTabOnWhiteSpaceOnlyLinesIndentStraightToTheRightSpotSimilarToEmptyLines() {
        final model = createTextModel(
            [
                '\tfunction baz() {',
                '\t\tfunction hello() { // something here',
                '\t\t',
                '\t',
                '\t\t}',
                '\t}'
            ].join('\n'),
            indentRulesLanguageId,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 4, 2, false);
            assertCursor(viewModel, new Selection(4, 2, 4, 2));

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(4), '\t\t\t');
        });
    }

    /**
     * test('bug #2938 (2): When pressing Tab on white-space only lines, indent straight to the right spot (similar to empty lines)')
     */
    function testBug29382WhenPressingTabOnWhiteSpaceOnlyLinesIndentStraightToTheRightSpotSimilarToEmptyLines() {
        final model = createTextModel(
            [
                '\tfunction baz() {',
                '\t\tfunction hello() { // something here',
                '\t\t',
                '    ',
                '\t\t}',
                '\t}'
            ].join('\n'),
            indentRulesLanguageId,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 4, 1, false);
            assertCursor(viewModel, new Selection(4, 1, 4, 1));

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(4), '\t\t\t');
        });
    }

    /**
     * test('bug #2938 (3): When pressing Tab on white-space only lines, indent straight to the right spot (similar to empty lines)')
     */
    function testBug29383WhenPressingTabOnWhiteSpaceOnlyLinesIndentStraightToTheRightSpotSimilarToEmptyLines() {
        final model = createTextModel(
            [
                '\tfunction baz() {',
                '\t\tfunction hello() { // something here',
                '\t\t',
                '\t\t\t',
                '\t\t}',
                '\t}'
            ].join('\n'),
            indentRulesLanguageId,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 4, 3, false);
            assertCursor(viewModel, new Selection(4, 3, 4, 3));

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(4), '\t\t\t\t');
        });
    }

    /**
     * test('bug #2938 (4): When pressing Tab on white-space only lines, indent straight to the right spot (similar to empty lines)')
     */
    function testBug29384WhenPressingTabOnWhiteSpaceOnlyLinesIndentStraightToTheRightSpotSimilarToEmptyLines() {
        final model = createTextModel(
            [
                '\tfunction baz() {',
                '\t\tfunction hello() { // something here',
                '\t\t',
                '\t\t\t\t',
                '\t\t}',
                '\t}'
            ].join('\n'),
            indentRulesLanguageId,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            moveTo(editor, viewModel, 4, 4, false);
            assertCursor(viewModel, new Selection(4, 4, 4, 4));

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(4), '\t\t\t\t\t');
        });
    }

    /**
     * test('bug #31015: When pressing Tab on lines and Enter rules are avail, indent straight to the right spotTab')
     */
    function testBug31015WhenPressingTabOnLinesAndEnterRulesAreAvailIndentStraightToTheRightSpotTab() {
        final onEnterLanguageId = setupOnEnterLanguage(IndentAction.Indent);
        final model = createTextModel(
            [
                '    if (a) {',
                '        ',
                '',
                '',
                '    }'
            ].join('\n'),
            onEnterLanguageId
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {

            moveTo(editor, viewModel, 3, 1);
            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '    if (a) {');
            assertEquals(model.getLineContent(2), '        ');
            assertEquals(model.getLineContent(3), '        ');
            assertEquals(model.getLineContent(4), '');
            assertEquals(model.getLineContent(5), '    }');
        });
    }

    /**
     * test('type honors indentation rules: ruby keywords')
     */
    function testTypeHonorsIndentationRulesRubyKeywords() {
        final rubyLanguageId = setupIndentRulesLanguage('ruby', {
            increaseIndentPattern: new RegExp('^\\s*((begin|class|def|else|elsif|ensure|for|if|module|rescue|unless|until|when|while)|(.*\\sdo\\b))\\b[^\\{;]*$$'),
            decreaseIndentPattern: new RegExp('^\\s*([}\\]]([,)]?\\s*(#|$$)|\\.[a-zA-Z_]\\w*\\b)|(end|rescue|ensure|else|elsif|when)\\b)')
        });
        final model = createTextModel(
            [
                'class Greeter',
                '  def initialize(name)',
                '    @name = name',
                '    en'
            ].join('\n'),
            rubyLanguageId
        );

        withTestCodeEditor(model, { autoIndent: 'full' }, (editor, viewModel) -> {
            moveTo(editor, viewModel, 4, 7, false);
            assertCursor(viewModel, new Selection(4, 7, 4, 7));

            viewModel.type('d', 'keyboard');
            assertEquals(model.getLineContent(4), '  end');
        });
    }

    /**
     * test('Auto indent on type: increaseIndentPattern has higher priority than decreaseIndent when inheriting')
     */
    function testAutoIndentOnTypeIncreaseIndentPatternHasHigherPriorityThanDecreaseIndentWhenInheriting() {
        usingCursor({
            text: [
                '\tif (true) {',
                '\t\tconsole.log();',
                '\t} else if {',
                '\t\tconsole.log()',
                '\t}'
            ],
            languageId: indentRulesLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 5, 3, false);
            assertCursor(viewModel, new Selection(5, 3, 5, 3));

            viewModel.type('e', 'keyboard');
            assertCursor(viewModel, new Selection(5, 4, 5, 4));
            assertEquals(model.getLineContent(5), '\t}e', 'This line should not decrease indent');
        });
    }

    /**
     * test('type honors users indentation adjustment')
     */
    function testTypeHonorsUsersIndentationAdjustment() {
        usingCursor({
            text: [
                '\tif (true ||',
                '\t ) {',
                '\t}',
                'if (true ||',
                ') {',
                '}'
            ],
            languageId: indentRulesLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 3, false);
            assertCursor(viewModel, new Selection(2, 3, 2, 3));

            viewModel.type(' ', 'keyboard');
            assertCursor(viewModel, new Selection(2, 4, 2, 4));
            assertEquals(model.getLineContent(2), '\t  ) {', 'This line should not decrease indent');
        });
    }

    /**
     * test('bug 29972: if a line is line comment, open bracket should not indent next line')
     */
    function testBug29972IfALineIsLineCommentOpenBracketShouldNotIndentNextLine() {
        usingCursor({
            text: [
                'if (true) {',
                '\t// {',
                '\t\t'
            ],
            languageId: indentRulesLanguageId,
            editorOpts: { autoIndent: 'full' }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 3, false);
            assertCursor(viewModel, new Selection(3, 3, 3, 3));

            viewModel.type('}', 'keyboard');
            assertCursor(viewModel, new Selection(3, 2, 3, 2));
            assertEquals(model.getLineContent(3), '}');
        });
    }

    /**
     * test('issue #38261: TAB key results in bizarre indentation in C++ mode ')
     */
    function testIssue38261TABKeyResultsInBizarreIndentationInCMode() {
        final languageId = 'indentRulesMode';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            brackets: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')']
            ],
            indentationRules: {
                increaseIndentPattern: new RegExp("(^.*\\{[^}]*$)"),
                decreaseIndentPattern: new RegExp("^\\s*\\}")
            }
        }));

        final model = createTextModel(
            [
                'int main() {',
                '  return 0;',
                '}',
                '',
                'bool Foo::bar(const string &a,',
                '              const string &b) {',
                '  foo();',
                '',
                ')',
            ].join('\n'),
            languageId,
            {
                tabSize: 2,
                indentSize: 2
            }
        );

        withTestCodeEditor(model, { autoIndent: 'advanced' }, (editor, viewModel) -> {
            moveTo(editor, viewModel, 8, 1, false);
            assertCursor(viewModel, new Selection(8, 1, 8, 1));

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(),
                [
                    'int main() {',
                    '  return 0;',
                    '}',
                    '',
                    'bool Foo::bar(const string &a,',
                    '              const string &b) {',
                    '  foo();',
                    '  ',
                    ')',
                ].join('\n')
            );
            assertDeepEquals(viewModel.getSelection(), new Selection(8, 3, 8, 3));
        });
    }

    /**
     * test('issue #57197: indent rules regex should be stateless')
     */
    function testIssue57197IndentRulesRegexShouldBeStateless() {
        final languageId = setupIndentRulesLanguage('lang', {
            decreaseIndentPattern: new RegExp('^\\s*}$$', 'gm'),
            increaseIndentPattern: new RegExp('^(?![^\\S\\n]*(?!--|\\u2013\\u2013|\\u2014\\u2014)(?:[-❍❑■⬜□☐▪▫\\u2013\\u2014≡→›✘xX✔✓☑+]|\\[[ xX+-]?\\])\\s[^\\n]*)[^\\S\\n]*(.+:)[^\\S\\n]*(?:(?=@[^\\s*~(]+(?::\\/\\/[^\\s*~(:]+)?(?:\\([^)]*\\))?)|$$)', 'gm'),
        });
        usingCursor({
            text: [
                'Project:',
            ],
            languageId: languageId,
            modelOpts: { insertSpaces: false },
            editorOpts: { autoIndent: 'full' }
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 9, false);
            assertCursor(viewModel, new Selection(1, 9, 1, 9));

            viewModel.type('\n', 'keyboard');
            model.tokenization.forceTokenization(model.getLineCount());
            assertCursor(viewModel, new Selection(2, 2, 2, 2));

            moveTo(editor, viewModel, 1, 9, false);
            assertCursor(viewModel, new Selection(1, 9, 1, 9));
            viewModel.type('\n', 'keyboard');
            model.tokenization.forceTokenization(model.getLineCount());
            assertCursor(viewModel, new Selection(2, 2, 2, 2));
        });
    }

    /**
     * test('typing in json')
     */
    function testTypingInJson() {
        final languageId = 'indentRulesMode';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            brackets: [
                ['{', '}'],
                ['[', ']'],
                ['(', ')']
            ],
            indentationRules: {
                increaseIndentPattern: new RegExp("({+(?=([^\"]*\"[^\"]*\")*[^\"}]*$))|(\\[+(?=([^\"]*\"[^\"]*\")*[^\"\\]]*$))"),
                decreaseIndentPattern: new RegExp("^\\s*[}\\]],?\\s*$")
            }
        }));

        final model = createTextModel(
            [
                '{',
                '  "scripts: {"',
                '    "watch": "a {"',
                '    "build{": "b"',
                '    "tasks": []',
                '    "tasks": ["a"]',
                '  "}"',
                '"}"'
            ].join('\n'),
            languageId,
            {
                tabSize: 2,
                indentSize: 2
            }
        );

        withTestCodeEditor(model, { autoIndent: 'full' }, (editor, viewModel) -> {
            moveTo(editor, viewModel, 3, 19, false);
            assertCursor(viewModel, new Selection(3, 19, 3, 19));

            viewModel.type('\n', 'keyboard');
            assertDeepEquals(model.getLineContent(4), '    ');

            moveTo(editor, viewModel, 5, 18, false);
            assertCursor(viewModel, new Selection(5, 18, 5, 18));

            viewModel.type('\n', 'keyboard');
            assertDeepEquals(model.getLineContent(6), '    ');

            moveTo(editor, viewModel, 7, 15, false);
            assertCursor(viewModel, new Selection(7, 15, 7, 15));

            viewModel.type('\n', 'keyboard');
            assertDeepEquals(model.getLineContent(8), '      ');
            assertDeepEquals(model.getLineContent(9), '    ]');

            moveTo(editor, viewModel, 10, 18, false);
            assertCursor(viewModel, new Selection(10, 18, 10, 18));

            viewModel.type('\n', 'keyboard');
            assertDeepEquals(model.getLineContent(11), '    ]');
        });
    }

    /**
     * test('issue #111128: Multicursor `Enter` issue with indentation')
     */
    function testIssue111128MulticursorEnterIssueWithIndentation() {
        final model = createTextModel('    let a, b, c;', indentRulesLanguageId, { detectIndentation: false, insertSpaces: false, tabSize: 4 });
        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(1, 11, 1, 11),
                new Selection(1, 14, 1, 14),
            ]);
            viewModel.type('\n', 'keyboard');
            assertEquals(model.getValue(), '    let a,\n\t b,\n\t c;');
        });
    }

    /**
     * test('issue #122714: tabSize=1 prevent typing a string matching decreaseIndentPattern in an empty file')
     */
    function testIssue122714TabSize1PreventTypingAStringMatchingDecreaseIndentPatternInAnEmptyFile() {
        final latextLanguageId = setupIndentRulesLanguage('latex', {
            increaseIndentPattern: new RegExp('\\\\begin{(?!document)([^}]*)}(?!.*\\\\end{\\1})'),
            decreaseIndentPattern: new RegExp('^\\s*\\\\end{(?!document)')
        });
        final model = createTextModel(
            '\\end',
            latextLanguageId,
            { tabSize: 1 }
        );

        withTestCodeEditor(model, { autoIndent: 'full' }, (editor, viewModel) -> {
            moveTo(editor, viewModel, 1, 5, false);
            assertCursor(viewModel, new Selection(1, 5, 1, 5));

            viewModel.type('{', 'keyboard');
            assertEquals(model.getLineContent(1), '\\end{}');
        });
    }

    /**
     * test('ElectricCharacter - does nothing if no electric char')
     */
    function testElectricCharacterDoesNothingIfNoElectricChar() {
        usingCursor({
            text: [
                '  if (a) {',
                ''
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 1);
            viewModel.type('*', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '*');
        });
    }

    /**
     * test('ElectricCharacter - indents in order to match bracket')
     */
    function testElectricCharacterIndentsInOrderToMatchBracket() {
        usingCursor({
            text: [
                '  if (a) {',
                ''
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 1);
            viewModel.type('}', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '  }');
        });
    }

    /**
     * test('ElectricCharacter - unindents in order to match bracket')
     */
    function testElectricCharacterUnindentsInOrderToMatchBracket() {
        usingCursor({
            text: [
                '  if (a) {',
                '    '
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 5);
            viewModel.type('}', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '  }');
        });
    }

    /**
     * test('ElectricCharacter - matches with correct bracket')
     */
    function testElectricCharacterMatchesWithCorrectBracket() {
        usingCursor({
            text: [
                '  if (a) {',
                '    if (b) {',
                '    }',
                '    '
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 4, 1);
            viewModel.type('}', 'keyboard');
            assertDeepEquals(model.getLineContent(4), '  }    ');
        });
    }

    /**
     * test('ElectricCharacter - does nothing if bracket does not match')
     */
    function testElectricCharacterDoesNothingIfBracketDoesNotMatch() {
        usingCursor({
            text: [
                '  if (a) {',
                '    if (b) {',
                '    }',
                '  }  '
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 4, 6);
            viewModel.type('}', 'keyboard');
            assertDeepEquals(model.getLineContent(4), '  }  }');
        });
    }

    /**
     * test('ElectricCharacter - matches bracket even in line with content')
     */
    function testElectricCharacterMatchesBracketEvenInLineWithContent() {
        usingCursor({
            text: [
                '  if (a) {',
                '// hello'
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 1);
            viewModel.type('}', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '  }// hello');
        });
    }

    /**
     * test('ElectricCharacter - is no-op if bracket is lined up')
     */
    function testElectricCharacterIsNoOpIfBracketIsLinedUp() {
        usingCursor({
            text: [
                '  if (a) {',
                '  '
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 3);
            viewModel.type('}', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '  }');
        });
    }

    /**
     * test('ElectricCharacter - is no-op if there is non-whitespace text before')
     */
    function testElectricCharacterIsNoOpIfThereIsNonWhitespaceTextBefore() {
        usingCursor({
            text: [
                '  if (a) {',
                'a'
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 2);
            viewModel.type('}', 'keyboard');
            assertDeepEquals(model.getLineContent(2), 'a}');
        });
    }

    /**
     * test('ElectricCharacter - is no-op if pairs are all matched before')
     */
    function testElectricCharacterIsNoOpIfPairsAreAllMatchedBefore() {
        usingCursor({
            text: [
                'foo(() => {',
                '  ( 1 + 2 ) ',
                '})'
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 13);
            viewModel.type('*', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '  ( 1 + 2 ) *');
        });
    }

    /**
     * test('ElectricCharacter - is no-op if matching bracket is on the same line')
     */
    function testElectricCharacterIsNoOpIfMatchingBracketIsOnTheSameLine() {
        usingCursor({
            text: [
                '(div',
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 1, 5);
            var changeText:Null<String> = null;
            final disposable = model.onDidChangeContent(e -> {
                changeText = e.changes[0].text;
            });
            viewModel.type(')', 'keyboard');
            assertDeepEquals(model.getLineContent(1), '(div)');
            assertDeepEquals(changeText, ')');
            disposable.dispose();
        });
    }

    /**
     * test('ElectricCharacter - is no-op if the line has other content')
     */
    function testElectricCharacterIsNoOpIfTheLineHasOtherContent() {
        usingCursor({
            text: [
                'Math.max(',
                '\t2',
                '\t3'
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 3, 3);
            viewModel.type(')', 'keyboard');
            assertDeepEquals(model.getLineContent(3), '\t3)');
        });
    }

    /**
     * test('ElectricCharacter - appends text')
     */
    function testElectricCharacterAppendsText() {
        usingCursor({
            text: [
                '  if (a) {',
                '/*'
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 3);
            viewModel.type('*', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '/** */');
        });
    }

    /**
     * test('ElectricCharacter - appends text 2')
     */
    function testElectricCharacterAppendsText2() {
        usingCursor({
            text: [
                '  if (a) {',
                '  /*'
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 5);
            viewModel.type('*', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '  /** */');
        });
    }

    /**
     * test('ElectricCharacter - issue #23711: Replacing selected text with )]} fails to delete old text with backwards-dragged selection')
     */
    function testElectricCharacterIssue23711ReplacingSelectedTextWithFailsToDeleteOldTextWithBackwardsDraggedSelection() {
        usingCursor({
            text: [
                '{',
                'word'
            ],
            languageId: electricCharLanguageId
        }, (editor, model, viewModel) -> {
            moveTo(editor, viewModel, 2, 5);
            moveTo(editor, viewModel, 2, 1, true);
            viewModel.type('}', 'keyboard');
            assertDeepEquals(model.getLineContent(2), '}');
        });
    }

    /**
     * test('issue #61070: backtick (`) should auto-close after a word character')
     */
    function testIssue61070BacktickShouldAutoCloseAfterAWordCharacter() {
        usingCursor({
            text: ['const markup = highlight'],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            model.tokenization.forceTokenization(1);
            assertType(editor, model, viewModel, 1, 25, '`', '``', 'auto closes ` @ (1, 25)');
        });
    }

    /**
     * test('issue #132912: quotes should not auto-close if they are closing a string')
     */
    function testIssue132912QuotesShouldNotAutoCloseIfTheyAreClosingAString() {
        setupAutoClosingLanguageTokenization();
        final model = createTextModel('const t2 = `something $${t1}', autoClosingLanguageId);
        withTestCodeEditor(
            model,
            {},
            (editor, viewModel) -> {
                final model = viewModel.model;
                model.tokenization.forceTokenization(1);
                assertType(editor, model, viewModel, 1, 28, '`', '`', 'does not auto close ` @ (1, 28)');
            }
        );
    }

    /**
     * test('autoClosingPairs - open parens: default')
     */
    function testAutoClosingPairsOpenParensDefault() {
        usingCursor({
            text: [
                'var a = [];',
                'var b = `asd`;',
                'var c = \'asd\';',
                'var d = "asd";',
                'var e = /*3*/\t3;',
                'var f = /** 3 */3;',
                'var g = (3+5);',
                'var h = { a: \'value\' };',
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {

            final autoClosePositions = [
                'var| a| |=| [|]|;|',
                'var| b| |=| |`asd|`|;|',
                'var| c| |=| |\'asd|\'|;|',
                'var| d| |=| |"asd|"|;|',
                'var| e| |=| /*3*/|\t3|;|',
                'var| f| |=| /**| 3| */3|;|',
                'var| g| |=| (3+5|)|;|',
                'var| h| |=| {| a|:| |\'value|\'| |}|;|',
            ];
            for (i in 0...autoClosePositions.length) {
                final lineNumber = i + 1;
                final autoCloseColumns = extractAutoClosingSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

                for (column in 1...autoCloseColumns.length) {
                    model.tokenization.forceTokenization(lineNumber);
                    if (autoCloseColumns[column] == AutoClosingColumnType.Special1) {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '()', 'auto closes @ (${lineNumber}, ${column})');
                    } else {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '(', 'does not auto close @ (${lineNumber}, ${column})');
                    }
                }
            }
        });
    }

    /**
     * test('autoClosingPairs - open parens: whitespace')
     */
    function testAutoClosingPairsOpenParensWhitespace() {
        usingCursor({
            text: [
                'var a = [];',
                'var b = `asd`;',
                'var c = \'asd\';',
                'var d = "asd";',
                'var e = /*3*/\t3;',
                'var f = /** 3 */3;',
                'var g = (3+5);',
                'var h = { a: \'value\' };',
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoClosingBrackets: 'beforeWhitespace'
            }
        }, (editor, model, viewModel) -> {

            final autoClosePositions = [
                'var| a| =| [|];|',
                'var| b| =| `asd`;|',
                'var| c| =| \'asd\';|',
                'var| d| =| "asd";|',
                'var| e| =| /*3*/|\t3;|',
                'var| f| =| /**| 3| */3;|',
                'var| g| =| (3+5|);|',
                'var| h| =| {| a:| \'value\'| |};|',
            ];
            for (i in 0...autoClosePositions.length) {
                final lineNumber = i + 1;
                final autoCloseColumns = extractAutoClosingSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

                for (column in 1...autoCloseColumns.length) {
                    model.tokenization.forceTokenization(lineNumber);
                    if (autoCloseColumns[column] == AutoClosingColumnType.Special1) {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '()', 'auto closes @ (${lineNumber}, ${column})');
                    } else {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '(', 'does not auto close @ (${lineNumber}, ${column})');
                    }
                }
            }
        });
    }

    /**
     * test('autoClosingPairs - open parens disabled/enabled open quotes enabled/disabled')
     */
    function testAutoClosingPairsOpenParensDisabledEnabledOpenQuotesEnabledDisabled() {
        usingCursor({
            text: [
                'var a = [];',
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoClosingBrackets: 'beforeWhitespace',
                autoClosingQuotes: 'never'
            }
        }, (editor, model, viewModel) -> {

            final autoClosePositions = [
                'var| a| =| [|];|',
            ];
            for (i in 0...autoClosePositions.length) {
                final lineNumber = i + 1;
                final autoCloseColumns = extractAutoClosingSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

                for (column in 1...autoCloseColumns.length) {
                    model.tokenization.forceTokenization(lineNumber);
                    if (autoCloseColumns[column] == AutoClosingColumnType.Special1) {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '()', 'auto closes @ (${lineNumber}, ${column})');
                    } else {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '(', 'does not auto close @ (${lineNumber}, ${column})');
                    }
                    assertType(editor, model, viewModel, lineNumber, column, '\'', '\'', 'does not auto close @ (${lineNumber}, ${column})');
                }
            }
        });

        usingCursor({
            text: [
                'var b = [];',
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoClosingBrackets: 'never',
                autoClosingQuotes: 'beforeWhitespace'
            }
        }, (editor, model, viewModel) -> {

            final autoClosePositions = [
                'var b =| [|];|',
            ];
            for (i in 0...autoClosePositions.length) {
                final lineNumber = i + 1;
                final autoCloseColumns = extractAutoClosingSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

                for (column in 1...autoCloseColumns.length) {
                    model.tokenization.forceTokenization(lineNumber);
                    if (autoCloseColumns[column] == AutoClosingColumnType.Special1) {
                        assertType(editor, model, viewModel, lineNumber, column, '\'', '\'\'', 'auto closes @ (${lineNumber}, ${column})');
                    } else {
                        assertType(editor, model, viewModel, lineNumber, column, '\'', '\'', 'does not auto close @ (${lineNumber}, ${column})');
                    }
                    assertType(editor, model, viewModel, lineNumber, column, '(', '(', 'does not auto close @ (${lineNumber}, ${column})');
                }
            }
        });
    }

    /**
     * test('autoClosingPairs - configurable open parens')
     */
    function testAutoClosingPairsConfigurableOpenParens() {
        setAutoClosingLanguageEnabledSet('abc');
        usingCursor({
            text: [
                'var a = [];',
                'var b = `asd`;',
                'var c = \'asd\';',
                'var d = "asd";',
                'var e = /*3*/\t3;',
                'var f = /** 3 */3;',
                'var g = (3+5);',
                'var h = { a: \'value\' };',
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoClosingBrackets: 'languageDefined'
            }
        }, (editor, model, viewModel) -> {

            final autoClosePositions = [
                'v|ar |a = [|];|',
                'v|ar |b = `|asd`;|',
                'v|ar |c = \'|asd\';|',
                'v|ar d = "|asd";|',
                'v|ar e = /*3*/\t3;|',
                'v|ar f = /** 3| */3;|',
                'v|ar g = (3+5|);|',
                'v|ar h = { |a: \'v|alue\' |};|',
            ];
            for (i in 0...autoClosePositions.length) {
                final lineNumber = i + 1;
                final autoCloseColumns = extractAutoClosingSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

                for (column in 1...autoCloseColumns.length) {
                    model.tokenization.forceTokenization(lineNumber);
                    if (autoCloseColumns[column] == AutoClosingColumnType.Special1) {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '()', 'auto closes @ (${lineNumber}, ${column})');
                    } else {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '(', 'does not auto close @ (${lineNumber}, ${column})');
                    }
                }
            }
        });
    }

    /**
     * test('autoClosingPairs - auto-pairing can be disabled')
     */
    function testAutoClosingPairsAutoPairingCanBeDisabled() {
        usingCursor({
            text: [
                'var a = [];',
                'var b = `asd`;',
                'var c = \'asd\';',
                'var d = "asd";',
                'var e = /*3*/\t3;',
                'var f = /** 3 */3;',
                'var g = (3+5);',
                'var h = { a: \'value\' };',
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoClosingBrackets: 'never',
                autoClosingQuotes: 'never'
            }
        }, (editor, model, viewModel) -> {

            final autoClosePositions = [
                'var a = [];',
                'var b = `asd`;',
                'var c = \'asd\';',
                'var d = "asd";',
                'var e = /*3*/\t3;',
                'var f = /** 3 */3;',
                'var g = (3+5);',
                'var h = { a: \'value\' };',
            ];
            for (i in 0...autoClosePositions.length) {
                final lineNumber = i + 1;
                final autoCloseColumns = extractAutoClosingSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

                for (column in 1...autoCloseColumns.length) {
                    model.tokenization.forceTokenization(lineNumber);
                    if (autoCloseColumns[column] == AutoClosingColumnType.Special1) {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '()', 'auto closes @ (${lineNumber}, ${column})');
                        assertType(editor, model, viewModel, lineNumber, column, '"', '""', 'auto closes @ (${lineNumber}, ${column})');
                    } else {
                        assertType(editor, model, viewModel, lineNumber, column, '(', '(', 'does not auto close @ (${lineNumber}, ${column})');
                        assertType(editor, model, viewModel, lineNumber, column, '"', '"', 'does not auto close @ (${lineNumber}, ${column})');
                    }
                }
            }
        });
    }

    /**
     * test('autoClosingPairs - auto wrapping is configurable')
     */
    function testAutoClosingPairsAutoWrappingIsConfigurable() {
        usingCursor({
            text: [
                'var a = asd'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {

            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 4),
                new Selection(1, 9, 1, 12),
            ]);

            // type a `
            viewModel.type('`', 'keyboard');

            assertEquals(model.getValue(), '`var` a = `asd`');

            // type a (
            viewModel.type('(', 'keyboard');

            assertEquals(model.getValue(), '`(var)` a = `(asd)`');
        });

        usingCursor({
            text: [
                'var a = asd'
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoSurround: 'never'
            }
        }, (editor, model, viewModel) -> {

            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 4),
            ]);

            // type a `
            viewModel.type('`', 'keyboard');

            assertEquals(model.getValue(), '` a = asd');
        });

        usingCursor({
            text: [
                'var a = asd'
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoSurround: 'quotes'
            }
        }, (editor, model, viewModel) -> {

            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 4),
            ]);

            // type a `
            viewModel.type('`', 'keyboard');
            assertEquals(model.getValue(), '`var` a = asd');

            // type a (
            viewModel.type('(', 'keyboard');
            assertEquals(model.getValue(), '`(` a = asd');
        });

        usingCursor({
            text: [
                'var a = asd'
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoSurround: 'brackets'
            }
        }, (editor, model, viewModel) -> {

            viewModel.setSelections('test', [
                new Selection(1, 1, 1, 4),
            ]);

            // type a (
            viewModel.type('(', 'keyboard');
            assertEquals(model.getValue(), '(var) a = asd');

            // type a `
            viewModel.type('`', 'keyboard');
            assertEquals(model.getValue(), '(`) a = asd');
        });
    }

    /**
     * test('autoClosingPairs - quote')
     */
    function testAutoClosingPairsQuote() {
        usingCursor({
            text: [
                'var a = [];',
                'var b = `asd`;',
                'var c = \'asd\';',
                'var d = "asd";',
                'var e = /*3*/\t3;',
                'var f = /** 3 */3;',
                'var g = (3+5);',
                'var h = { a: \'value\' };',
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {

            final autoClosePositions = [
                'var a |=| [|]|;|',
                'var b |=| `asd`|;|',
                'var c |=| \'asd\'|;|',
                'var d |=| "asd"|;|',
                'var e |=| /*3*/|\t3;|',
                'var f |=| /**| 3 */3;|',
                'var g |=| (3+5)|;|',
                'var h |=| {| a:| \'value\'| |}|;|',
            ];
            for (i in 0...autoClosePositions.length) {
                final lineNumber = i + 1;
                final autoCloseColumns = extractAutoClosingSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

                for (column in 1...autoCloseColumns.length) {
                    model.tokenization.forceTokenization(lineNumber);
                    if (autoCloseColumns[column] == AutoClosingColumnType.Special1) {
                        assertType(editor, model, viewModel, lineNumber, column, '\'', '\'\'', 'auto closes @ (${lineNumber}, ${column})');
                    } else if (autoCloseColumns[column] == AutoClosingColumnType.Special2) {
                        assertType(editor, model, viewModel, lineNumber, column, '\'', '', 'over types @ (${lineNumber}, ${column})');
                    } else {
                        assertType(editor, model, viewModel, lineNumber, column, '\'', '\'', 'does not auto close @ (${lineNumber}, ${column})');
                    }
                }
            }
        });
    }

    /**
     * test('autoClosingPairs - multi-character autoclose')
     */
    function testAutoClosingPairsMultiCharacterAutoclose() {
        usingCursor({
            text: [
                '',
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {

            model.setValue('begi');
            viewModel.setSelections('test', [new Selection(1, 5, 1, 5)]);
            viewModel.type('n', 'keyboard');
            assertEquals(model.getLineContent(1), 'beginend');

            model.setValue('/*');
            viewModel.setSelections('test', [new Selection(1, 3, 1, 3)]);
            viewModel.type('*', 'keyboard');
            assertEquals(model.getLineContent(1), '/** */');
        });
    }

    /**
     * test('autoClosingPairs - doc comments can be turned off')
     */
    function testAutoClosingPairsDocCommentsCanBeTurnedOff() {
        usingCursor({
            text: [
                '',
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoClosingComments: 'never'
            }
        }, (editor, model, viewModel) -> {

            model.setValue('/*');
            viewModel.setSelections('test', [new Selection(1, 3, 1, 3)]);
            viewModel.type('*', 'keyboard');
            assertEquals(model.getLineContent(1), '/**');
        });
    }

    /**
     * test('issue #72177: multi-character autoclose with conflicting patterns')
     */
    function testIssue72177MultiCharacterAutocloseWithConflictingPatterns() {
        final languageId = 'autoClosingModeMultiChar';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            autoClosingPairs: [
                { open: '(', close: ')' },
                { open: '(*', close: '*)' },
                { open: '<@', close: '@>' },
                { open: '<@@', close: '@@>' },
            ],
        }));

        usingCursor({
            text: [
                '',
            ],
            languageId: languageId
        }, (editor, model, viewModel) -> {
            viewModel.type('(', 'keyboard');
            assertEquals(model.getLineContent(1), '()');
            viewModel.type('*', 'keyboard');
            assertEquals(model.getLineContent(1), '(**)', 'doesn\'t add entire close when already closed substring is there');

            model.setValue('(');
            viewModel.setSelections('test', [new Selection(1, 2, 1, 2)]);
            viewModel.type('*', 'keyboard');
            assertEquals(model.getLineContent(1), '(**)', 'does add entire close if not already there');

            model.setValue('');
            viewModel.type('<@', 'keyboard');
            assertEquals(model.getLineContent(1), '<@@>');
            viewModel.type('@', 'keyboard');
            assertEquals(model.getLineContent(1), '<@@@@>', 'autocloses when before multi-character closing brace');
            viewModel.type('(', 'keyboard');
            assertEquals(model.getLineContent(1), '<@@()@@>', 'autocloses when before multi-character closing brace');
        });
    }

    /**
     * test('issue #55314: Do not auto-close when ending with open')
     */
    function testIssue55314DoNotAutoCloseWhenEndingWithOpen() {
        final languageId = 'myElectricMode';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            autoClosingPairs: [
                { open: '{', close: '}' },
                { open: '[', close: ']' },
                { open: '(', close: ')' },
                { open: '\'', close: '\'', notIn: ['string', 'comment'] },
                { open: '\"', close: '\"', notIn: ['string'] },
                { open: 'B\"', close: '\"', notIn: ['string', 'comment'] },
                { open: '`', close: '`', notIn: ['string', 'comment'] },
                { open: '/**', close: ' */', notIn: ['string'] }
            ],
        }));

        usingCursor({
            text: [
                'little goat',
                'little LAMB',
                'little sheep',
                'Big LAMB'
            ],
            languageId: languageId
        }, (editor, model, viewModel) -> {
            model.tokenization.forceTokenization(model.getLineCount());
            assertType(editor, model, viewModel, 1, 4, '"', '"', 'does not double quote when ending with open');
            model.tokenization.forceTokenization(model.getLineCount());
            assertType(editor, model, viewModel, 2, 4, '"', '"', 'does not double quote when ending with open');
            model.tokenization.forceTokenization(model.getLineCount());
            assertType(editor, model, viewModel, 3, 4, '"', '"', 'does not double quote when ending with open');
            model.tokenization.forceTokenization(model.getLineCount());
            assertType(editor, model, viewModel, 4, 2, '"', '"', 'does not double quote when ending with open');
            model.tokenization.forceTokenization(model.getLineCount());
            assertType(editor, model, viewModel, 4, 3, '"', '"', 'does not double quote when ending with open');
        });
    }

    /**
     * test('issue #27937: Trying to add an item to the front of a list is cumbersome')
     */
    function testIssue27937TryingToAddAnItemToTheFrontOfAListIsCumbersome() {
        usingCursor({
            text: [
                'var arr = ["b", "c"];'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertType(editor, model, viewModel, 1, 12, '"', '"', 'does not over type and will not auto close');
        });
    }

    /**
     * test('issue #25658 - Do not auto-close single/double quotes after word characters')
     */
    function testIssue25658DoNotAutoCloseSingleDoubleQuotesAfterWordCharacters() {
        usingCursor({
            text: [
                '',
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {

            function typeCharacters(viewModel:ViewModel, chars:String):Void {
                for (i in 0...chars.length) {
                    viewModel.type(chars.charAt(i), 'keyboard');
                }
            }

            // First gif
            model.tokenization.forceTokenization(model.getLineCount());
            typeCharacters(viewModel, 'teste1 = teste\' ok');
            assertEquals(model.getLineContent(1), 'teste1 = teste\' ok');

            viewModel.setSelections('test', [new Selection(1, 1000, 1, 1000)]);
            typeCharacters(viewModel, '\n');
            model.tokenization.forceTokenization(model.getLineCount());
            typeCharacters(viewModel, 'teste2 = teste \'ok');
            assertEquals(model.getLineContent(2), 'teste2 = teste \'ok\'');

            viewModel.setSelections('test', [new Selection(2, 1000, 2, 1000)]);
            typeCharacters(viewModel, '\n');
            model.tokenization.forceTokenization(model.getLineCount());
            typeCharacters(viewModel, 'teste3 = teste" ok');
            assertEquals(model.getLineContent(3), 'teste3 = teste" ok');

            viewModel.setSelections('test', [new Selection(3, 1000, 3, 1000)]);
            typeCharacters(viewModel, '\n');
            model.tokenization.forceTokenization(model.getLineCount());
            typeCharacters(viewModel, 'teste4 = teste "ok');
            assertEquals(model.getLineContent(4), 'teste4 = teste "ok"');

            // Second gif
            viewModel.setSelections('test', [new Selection(4, 1000, 4, 1000)]);
            typeCharacters(viewModel, '\n');
            model.tokenization.forceTokenization(model.getLineCount());
            typeCharacters(viewModel, 'teste \'');
            assertEquals(model.getLineContent(5), 'teste \'\'');

            viewModel.setSelections('test', [new Selection(5, 1000, 5, 1000)]);
            typeCharacters(viewModel, '\n');
            model.tokenization.forceTokenization(model.getLineCount());
            typeCharacters(viewModel, 'teste "');
            assertEquals(model.getLineContent(6), 'teste ""');

            viewModel.setSelections('test', [new Selection(6, 1000, 6, 1000)]);
            typeCharacters(viewModel, '\n');
            model.tokenization.forceTokenization(model.getLineCount());
            typeCharacters(viewModel, 'teste\'');
            assertEquals(model.getLineContent(7), 'teste\'');

            viewModel.setSelections('test', [new Selection(7, 1000, 7, 1000)]);
            typeCharacters(viewModel, '\n');
            model.tokenization.forceTokenization(model.getLineCount());
            typeCharacters(viewModel, 'teste"');
            assertEquals(model.getLineContent(8), 'teste"');
        });
    }

    /**
     * test('issue #37315 - overtypes only those characters that it inserted')
     */
    function testIssue37315OvertypesOnlyThoseCharactersThatItInserted() {
        usingCursor({
            text: [
                '',
                'y=();'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            viewModel.type('x=(', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.type('asd', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=(asd)');

            // overtype!
            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=(asd)');

            // do not overtype!
            viewModel.setSelections('test', [new Selection(2, 4, 2, 4)]);
            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(2), 'y=());');

        });
    }

    /**
     * test('issue #37315 - stops overtyping once cursor leaves area')
     */
    function testIssue37315StopsOvertypingOnceCursorLeavesArea() {
        usingCursor({
            text: [
                '',
                'y=();'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            viewModel.type('x=(', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.setSelections('test', [new Selection(1, 5, 1, 5)]);
            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=())');
        });
    }

    /**
     * test('issue #37315 - it overtypes only once')
     */
    function testIssue37315ItOvertypesOnlyOnce() {
        usingCursor({
            text: [
                '',
                'y=();'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            viewModel.type('x=(', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.setSelections('test', [new Selection(1, 4, 1, 4)]);
            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=())');
        });
    }

    /**
     * test('issue #37315 - it can remember multiple auto-closed instances')
     */
    function testIssue37315ItCanRememberMultipleAutoClosedInstances() {
        usingCursor({
            text: [
                '',
                'y=();'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            viewModel.type('x=(', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.type('(', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=(())');

            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=(())');

            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=(())');
        });
    }

    /**
     * test('issue #118270 - auto closing deletes only those characters that it inserted')
     */
    function testIssue118270AutoClosingDeletesOnlyThoseCharactersThatItInserted() {
        usingCursor({
            text: [
                '',
                'y=();'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            viewModel.type('x=(', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.type('asd', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=(asd)');

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'x=()');

            // delete closing char!
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'x=');

            // do not delete closing char!
            viewModel.setSelections('test', [new Selection(2, 4, 2, 4)]);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'y=);');

        });
    }

    /**
     * test('issue #78527 - does not close quote on odd count')
     */
    function testIssue78527DoesNotCloseQuoteOnOddCount() {
        usingCursor({
            text: [
                'std::cout << \'"\' << entryMap'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 29, 1, 29)]);

            viewModel.type('[', 'keyboard');
            assertEquals(model.getLineContent(1), 'std::cout << \'"\' << entryMap[]');

            viewModel.type('"', 'keyboard');
            assertEquals(model.getLineContent(1), 'std::cout << \'"\' << entryMap[""]');

            viewModel.type('a', 'keyboard');
            assertEquals(model.getLineContent(1), 'std::cout << \'"\' << entryMap["a"]');

            viewModel.type('"', 'keyboard');
            assertEquals(model.getLineContent(1), 'std::cout << \'"\' << entryMap["a"]');

            viewModel.type(']', 'keyboard');
            assertEquals(model.getLineContent(1), 'std::cout << \'"\' << entryMap["a"]');
        });
    }

    /**
     * test('issue #85983 - editor.autoClosingBrackets: beforeWhitespace is incorrect for Python')
     */
    function testIssue85983EditorAutoClosingBracketsBeforeWhitespaceIsIncorrectForPython() {
        final languageId = 'pythonMode';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            autoClosingPairs: [
                { open: '{', close: '}' },
                { open: '[', close: ']' },
                { open: '(', close: ')' },
                { open: '\"', close: '\"', notIn: ['string'] },
                { open: 'r\"', close: '\"', notIn: ['string', 'comment'] },
                { open: 'R\"', close: '\"', notIn: ['string', 'comment'] },
                { open: 'u\"', close: '\"', notIn: ['string', 'comment'] },
                { open: 'U\"', close: '\"', notIn: ['string', 'comment'] },
                { open: 'f\"', close: '\"', notIn: ['string', 'comment'] },
                { open: 'F\"', close: '\"', notIn: ['string', 'comment'] },
                { open: 'b\"', close: '\"', notIn: ['string', 'comment'] },
                { open: 'B\"', close: '\"', notIn: ['string', 'comment'] },
                { open: '\'', close: '\'', notIn: ['string', 'comment'] },
                { open: 'r\'', close: '\'', notIn: ['string', 'comment'] },
                { open: 'R\'', close: '\'', notIn: ['string', 'comment'] },
                { open: 'u\'', close: '\'', notIn: ['string', 'comment'] },
                { open: 'U\'', close: '\'', notIn: ['string', 'comment'] },
                { open: 'f\'', close: '\'', notIn: ['string', 'comment'] },
                { open: 'F\'', close: '\'', notIn: ['string', 'comment'] },
                { open: 'b\'', close: '\'', notIn: ['string', 'comment'] },
                { open: 'B\'', close: '\'', notIn: ['string', 'comment'] },
                { open: '`', close: '`', notIn: ['string'] }
            ],
        }));

        usingCursor({
            text: [
                'foo\'hello\''
            ],
            editorOpts: {
                autoClosingBrackets: 'beforeWhitespace'
            },
            languageId: languageId
        }, (editor, model, viewModel) -> {
            assertType(editor, model, viewModel, 1, 4, '(', '(', 'does not auto close @ (1, 4)');
        });
    }

    /**
     * test('issue #78975 - Parentheses swallowing does not work when parentheses are inserted by autocomplete')
     */
    function testIssue78975ParenthesesSwallowingDoesNotWorkWhenParenthesesAreInsertedByAutocomplete() {
        usingCursor({
            text: [
                '<div id'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 8, 1, 8)]);

            viewModel.executeEdits('snippet', [{ range: new Range(1, 6, 1, 8), text: 'id=""' }], (_) -> [new Selection(1, 10, 1, 10)]);
            assertEquals(model.getLineContent(1), '<div id=""');

            viewModel.type('a', 'keyboard');
            assertEquals(model.getLineContent(1), '<div id="a"');

            viewModel.type('"', 'keyboard');
            assertEquals(model.getLineContent(1), '<div id="a"');
        });
    }

    /**
     * test('issue #78833 - Add config to use old brackets/quotes overtyping')
     */
    function testIssue78833AddConfigToUseOldBracketsQuotesOvertyping() {
        usingCursor({
            text: [
                '',
                'y=();'
            ],
            languageId: autoClosingLanguageId,
            editorOpts: {
                autoClosingOvertype: 'always'
            }
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            viewModel.type('x=(', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.setSelections('test', [new Selection(1, 4, 1, 4)]);
            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(1), 'x=()');

            viewModel.setSelections('test', [new Selection(2, 4, 2, 4)]);
            viewModel.type(')', 'keyboard');
            assertEquals(model.getLineContent(2), 'y=();');
        });
    }

    /**
     * test('issue #15825: accents on mac US intl keyboard')
     */
    function testIssue15825AccentsOnMacUSIntlKeyboard() {
        usingCursor({
            text: [
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            // Typing ` + e on the mac US intl kb layout
            viewModel.startComposition();
            viewModel.type('`', 'keyboard');
            viewModel.compositionType('è', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            assertEquals(model.getValue(), 'è');
        });
    }

    /**
     * test('issue #90016: allow accents on mac US intl keyboard to surround selection')
     */
    function testIssue90016AllowAccentsOnMacUSIntlKeyboardToSurroundSelection() {
        usingCursor({
            text: [
                'test'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 1, 1, 5)]);

            // Typing ` + e on the mac US intl kb layout
            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            assertEquals(model.getValue(), '\'test\'');
        });
    }

    /**
     * test('issue #53357: Over typing ignores characters after backslash')
     */
    function testIssue53357OverTypingIgnoresCharactersAfterBackslash() {
        usingCursor({
            text: [
                'console.log();'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {

            viewModel.setSelections('test', [new Selection(1, 13, 1, 13)]);

            viewModel.type('\'', 'keyboard');
            assertEquals(model.getValue(), 'console.log(\'\');');

            viewModel.type('it', 'keyboard');
            assertEquals(model.getValue(), 'console.log(\'it\');');

            viewModel.type('\\', 'keyboard');
            assertEquals(model.getValue(), 'console.log(\'it\\\');');

            viewModel.type('\'', 'keyboard');
            assertEquals(model.getValue(), 'console.log(\'it\\\'\');');
        });
    }

    /**
     * test('issue #84998: Overtyping Brackets doesn\'t work after backslash')
     */
    function testIssue84998OvertypingBracketsDoesnTWorkAfterBackslash() {
        usingCursor({
            text: [
                ''
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {

            viewModel.setSelections('test', [new Selection(1, 1, 1, 1)]);

            viewModel.type('\\', 'keyboard');
            assertEquals(model.getValue(), '\\');

            viewModel.type('(', 'keyboard');
            assertEquals(model.getValue(), '\\()');

            viewModel.type('abc', 'keyboard');
            assertEquals(model.getValue(), '\\(abc)');

            viewModel.type('\\', 'keyboard');
            assertEquals(model.getValue(), '\\(abc\\)');

            viewModel.type(')', 'keyboard');
            assertEquals(model.getValue(), '\\(abc\\)');
        });
    }

    /**
     * test('issue #2773: Accents (´`¨^, others?) are inserted in the wrong position (Mac)')
     */
    function testIssue2773AccentsOthersAreInsertedInTheWrongPositionMac() {
        usingCursor({
            text: [
                'hello',
                'world'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            // Typing ` and pressing shift+down on the mac US intl kb layout
            // Here we're just replaying what the cursor gets
            viewModel.startComposition();
            viewModel.type('`', 'keyboard');
            moveDown(editor, viewModel, true);
            viewModel.compositionType('`', 1, 0, 0, 'keyboard');
            viewModel.compositionType('`', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            assertEquals(model.getValue(), '`hello\nworld');
            assertCursor(viewModel, new Selection(1, 2, 2, 2));
        });
    }

    /**
     * test('issue #26820: auto close quotes when not used as accents')
     */
    function testIssue26820AutoCloseQuotesWhenNotUsedAsAccents() {
        usingCursor({
            text: [
                ''
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            // on the mac US intl kb layout

            // Typing ' + space
            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');
            assertEquals(model.getValue(), '\'\'');

            // Typing one more ' + space
            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');
            assertEquals(model.getValue(), '\'\'');

            // Typing ' as a closing tag
            model.setValue('\'abc');
            viewModel.setSelections('test', [new Selection(1, 5, 1, 5)]);
            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            assertEquals(model.getValue(), '\'abc\'');

            // quotes before the newly added character are all paired.
            model.setValue('\'abc\'def ');
            viewModel.setSelections('test', [new Selection(1, 10, 1, 10)]);
            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            assertEquals(model.getValue(), '\'abc\'def \'\'');

            // No auto closing if there is non-whitespace character after the cursor
            model.setValue('abc');
            viewModel.setSelections('test', [new Selection(1, 1, 1, 1)]);
            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            // No auto closing if it's after a word.
            model.setValue('abc');
            viewModel.setSelections('test', [new Selection(1, 4, 1, 4)]);
            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            assertEquals(model.getValue(), 'abc\'');
        });
    }

    /**
     * test('issue #144690: Quotes do not overtype when using US Intl PC keyboard layout')
     */
    function testIssue144690QuotesDoNotOvertypeWhenUsingUSIntlPCKeyboardLayout() {
        usingCursor({
            text: [
                ''
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            assertCursor(viewModel, new Position(1, 1));

            // Pressing ' + ' + ;

            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.compositionType('\'', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');
            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('\';', 1, 0, 0, 'keyboard');
            viewModel.compositionType('\';', 2, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            assertEquals(model.getValue(), '\'\';');
        });
    }

    /**
     * test('issue #144693: Typing a quote using US Intl PC keyboard layout always surrounds words')
     */
    function testIssue144693TypingAQuoteUsingUSIntlPCKeyboardLayoutAlwaysSurroundsWords() {
        usingCursor({
            text: [
                'const hello = 3;'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 7, 1, 12)]);

            // Pressing ' + e

            viewModel.startComposition();
            viewModel.type('\'', 'keyboard');
            viewModel.compositionType('é', 1, 0, 0, 'keyboard');
            viewModel.compositionType('é', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');

            assertEquals(model.getValue(), 'const é = 3;');
        });
    }

    /**
     * test('issue #82701: auto close does not execute when IME is canceled via backspace')
     */
    function testIssue82701AutoCloseDoesNotExecuteWhenIMEIsCanceledViaBackspace() {
        usingCursor({
            text: [
                '{}'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 2, 1, 2)]);

            // Typing a + backspace
            viewModel.startComposition();
            viewModel.type('a', 'keyboard');
            viewModel.compositionType('', 1, 0, 0, 'keyboard');
            viewModel.endComposition('keyboard');
            assertEquals(model.getValue(), '{}');
        });
    }

    /**
     * test('issue #20891: All cursors should do the same thing')
     */
    function testIssue20891AllCursorsShouldDoTheSameThing() {
        usingCursor({
            text: [
                'var a = asd'
            ],
            languageId: autoClosingLanguageId
        }, (editor, model, viewModel) -> {

            viewModel.setSelections('test', [
                new Selection(1, 9, 1, 9),
                new Selection(1, 12, 1, 12),
            ]);

            // type a `
            viewModel.type('`', 'keyboard');

            assertEquals(model.getValue(), 'var a = `asd`');
        });
    }

    /**
     * test('issue #41825: Special handling of quotes in surrounding pairs')
     */
    function testIssue41825SpecialHandlingOfQuotesInSurroundingPairs() {
        final languageId = 'myMode';

        disposables.add(languageService.registerLanguage({ id: languageId }));
        disposables.add(languageConfigurationService.register(languageId, {
            surroundingPairs: [
                { open: '"', close: '"' },
                { open: '\'', close: '\'' },
            ]
        }));

        final model = createTextModel('var x = \'hi\';', languageId);

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(1, 9, 1, 10),
                new Selection(1, 12, 1, 13)
            ]);
            viewModel.type('"', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.LF), 'var x = "hi";', 'assert1');

            editor.setSelections([
                new Selection(1, 9, 1, 10),
                new Selection(1, 12, 1, 13)
            ]);
            viewModel.type('\'', 'keyboard');
            assertEquals(model.getValue(EndOfLinePreference.LF), 'var x = \'hi\';', 'assert2');
        });
    }

    /**
     * test('All cursors should do the same thing when deleting left')
     */
    function testAllCursorsShouldDoTheSameThingWhenDeletingLeft() {
        final model = createTextModel(
            [
                'var a = ()'
            ].join('\n'),
            autoClosingLanguageId
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [
                new Selection(1, 4, 1, 4),
                new Selection(1, 10, 1, 10),
            ]);

            // delete left
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);

            assertEquals(model.getValue(), 'va a = )');
        });
    }

    /**
     * test('issue #7100: Mouse word selection is strange when non-word character is at the end of line')
     */
    function testIssue7100MouseWordSelectionIsStrangeWhenNonWordCharacterIsAtTheEndOfLine() {
        final model = createTextModel(
            [
                'before.a',
                'before',
                'hello:',
                'there:',
                'this is strange:',
                'here',
                'it',
                'is',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            CoreNavigationCommands.WordSelect.runEditorCommand(null, editor, {
                position: new Position(3, 7)
            });
            assertCursor(viewModel, new Selection(3, 7, 3, 7));

            CoreNavigationCommands.WordSelectDrag.runEditorCommand(null, editor, {
                position: new Position(4, 7)
            });
            assertCursor(viewModel, new Selection(3, 7, 4, 7));
        });
    }

    /**
     * test('issue #112039: shift-continuing a double/triple-click and drag selection does not remember its starting mode')
     */
    function testIssue112039ShiftContinuingADoubleTripleClickAndDragSelectionDoesNotRememberItsStartingMode() {
        final model = createTextModel(
            [
                'just some text',
                'and another line',
                'and another one',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            CoreNavigationCommands.WordSelect.runEditorCommand(null, editor, {
                position: new Position(2, 6)
            });
            CoreNavigationCommands.MoveToSelect.runEditorCommand(null, editor, {
                position: new Position(1, 8),
            });
            assertCursor(viewModel, new Selection(2, 12, 1, 6));
        });
    }

    /**
     * test('issue #158236: Shift click selection does not work on line number indicator')
     */
    function testIssue158236ShiftClickSelectionDoesNotWorkOnLineNumberIndicator() {
        final model = createTextModel(
            [
                'just some text',
                'and another line',
                'and another one',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            CoreNavigationCommands.MoveTo.runEditorCommand(null, editor, {
                position: new Position(3, 5)
            });
            CoreNavigationCommands.LineSelectDrag.runEditorCommand(null, editor, {
                position: new Position(2, 1)
            });
            assertCursor(viewModel, new Selection(3, 5, 2, 1));
        });
    }

    /**
     * test('issue #111513: Text gets automatically selected when typing at the same location in another editor')
     */
    function testIssue111513TextGetsAutomaticallySelectedWhenTypingAtTheSameLocationInAnotherEditor() {
        final model = createTextModel(
            [
                'just',
                '',
                'some text',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor1, viewModel1) -> {
            editor1.setSelections([
                new Selection(2, 1, 2, 1)
            ]);
            withTestCodeEditor(model, {}, (editor2, viewModel2) -> {
                editor2.setSelections([
                    new Selection(2, 1, 2, 1)
                ]);
                viewModel2.type('e', 'keyboard');
                assertCursor(viewModel2, new Position(2, 2));
                assertCursor(viewModel1, new Position(2, 2));
            });
        });
    }

}

/**
 * suite('Undo stops')
 */
class UndoStopsTest extends CursorTestBase {

    /**
     * test('there is an undo stop between typing and deleting left')
     */
    function testThereIsAnUndoStopBetweenTypingAndDeletingLeft() {
        final model = createTextModel(
            [
                'A  line',
                'Another line',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 3, 1, 3)]);
            viewModel.type('first', 'keyboard');
            assertEquals(model.getLineContent(1), 'A first line');
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A fir line');
            assertCursor(viewModel, new Selection(1, 6, 1, 6));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A first line');
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A  line');
            assertCursor(viewModel, new Selection(1, 3, 1, 3));
        });

        model.dispose();
    }

    /**
     * test('there is an undo stop between typing and deleting right')
     */
    function testThereIsAnUndoStopBetweenTypingAndDeletingRight() {
        final model = createTextModel(
            [
                'A  line',
                'Another line',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 3, 1, 3)]);
            viewModel.type('first', 'keyboard');
            assertEquals(model.getLineContent(1), 'A first line');
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A firstine');
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A first line');
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A  line');
            assertCursor(viewModel, new Selection(1, 3, 1, 3));
        });

        model.dispose();
    }

    /**
     * test('there is an undo stop between deleting left and typing')
     */
    function testThereIsAnUndoStopBetweenDeletingLeftAndTyping() {
        final model = createTextModel(
            [
                'A  line',
                'Another line',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(2, 8, 2, 8)]);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), ' line');
            assertCursor(viewModel, new Selection(2, 1, 2, 1));

            viewModel.type('Second', 'keyboard');
            assertEquals(model.getLineContent(2), 'Second line');
            assertCursor(viewModel, new Selection(2, 7, 2, 7));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), ' line');
            assertCursor(viewModel, new Selection(2, 1, 2, 1));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'Another line');
            assertCursor(viewModel, new Selection(2, 8, 2, 8));
        });

        model.dispose();
    }

    /**
     * test('there is an undo stop between deleting left and deleting right')
     */
    function testThereIsAnUndoStopBetweenDeletingLeftAndDeletingRight() {
        final model = createTextModel(
            [
                'A  line',
                'Another line',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(2, 8, 2, 8)]);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), ' line');
            assertCursor(viewModel, new Selection(2, 1, 2, 1));

            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), '');
            assertCursor(viewModel, new Selection(2, 1, 2, 1));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), ' line');
            assertCursor(viewModel, new Selection(2, 1, 2, 1));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'Another line');
            assertCursor(viewModel, new Selection(2, 8, 2, 8));
        });

        model.dispose();
    }

    /**
     * test('there is an undo stop between deleting right and typing')
     */
    function testThereIsAnUndoStopBetweenDeletingRightAndTyping() {
        final model = createTextModel(
            [
                'A  line',
                'Another line',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(2, 9, 2, 9)]);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'Another ');
            assertCursor(viewModel, new Selection(2, 9, 2, 9));

            viewModel.type('text', 'keyboard');
            assertEquals(model.getLineContent(2), 'Another text');
            assertCursor(viewModel, new Selection(2, 13, 2, 13));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'Another ');
            assertCursor(viewModel, new Selection(2, 9, 2, 9));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'Another line');
            assertCursor(viewModel, new Selection(2, 9, 2, 9));
        });

        model.dispose();
    }

    /**
     * test('there is an undo stop between deleting right and deleting left')
     */
    function testThereIsAnUndoStopBetweenDeletingRightAndDeletingLeft() {
        final model = createTextModel(
            [
                'A  line',
                'Another line',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(2, 9, 2, 9)]);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'Another ');
            assertCursor(viewModel, new Selection(2, 9, 2, 9));

            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'An');
            assertCursor(viewModel, new Selection(2, 3, 2, 3));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'Another ');
            assertCursor(viewModel, new Selection(2, 9, 2, 9));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(2), 'Another line');
            assertCursor(viewModel, new Selection(2, 9, 2, 9));
        });

        model.dispose();
    }

    /**
     * test('inserts undo stop when typing space')
     */
    function testInsertsUndoStopWhenTypingSpace() {
        final model = createTextModel(
            [
                'A  line',
                'Another line',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 3, 1, 3)]);
            viewModel.type('first and interesting', 'keyboard');
            assertEquals(model.getLineContent(1), 'A first and interesting line');
            assertCursor(viewModel, new Selection(1, 24, 1, 24));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A first and line');
            assertCursor(viewModel, new Selection(1, 12, 1, 12));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A first line');
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), 'A  line');
            assertCursor(viewModel, new Selection(1, 3, 1, 3));
        });

        model.dispose();
    }

    /**
     * test('can undo typing and EOL change in one undo stop')
     */
    function testCanUndoTypingAndEOLChangeInOneUndoStop() {
        final model = createTextModel(
            [
                'A  line',
                'Another line',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [new Selection(1, 3, 1, 3)]);
            viewModel.type('first', 'keyboard');
            assertEquals(model.getValue(), 'A first line\nAnother line');
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            model.pushEOL(EndOfLineSequence.CRLF);
            assertEquals(model.getValue(), 'A first line\r\nAnother line');
            assertCursor(viewModel, new Selection(1, 8, 1, 8));

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(), 'A  line\nAnother line');
            assertCursor(viewModel, new Selection(1, 3, 1, 3));
        });

        model.dispose();
    }

    /**
     * test('issue #93585: Undo multi cursor edit corrupts document')
     */
    function testIssue93585UndoMultiCursorEditCorruptsDocument() {
        final model = createTextModel(
            [
                'hello world',
                'hello world',
            ].join('\n')
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.setSelections('test', [
                new Selection(2, 7, 2, 12),
                new Selection(1, 7, 1, 12),
            ]);
            viewModel.type('no', 'keyboard');
            assertEquals(model.getValue(), 'hello no\nhello no');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(), 'hello world\nhello world');
        });

        model.dispose();
    }

    /**
     * test('there is a single undo stop for consecutive whitespaces')
     */
    function testThereIsASingleUndoStopForConsecutiveWhitespaces() {
        final model = createTextModel(
            [
                ''
            ].join('\n'),
            null,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.type('a', 'keyboard');
            viewModel.type('b', 'keyboard');
            viewModel.type(' ', 'keyboard');
            viewModel.type(' ', 'keyboard');
            viewModel.type('c', 'keyboard');
            viewModel.type('d', 'keyboard');

            assertEquals(model.getValue(EndOfLinePreference.LF), 'ab  cd', 'assert1');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'ab  ', 'assert2');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'ab', 'assert3');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '', 'assert4');
        });

        model.dispose();
    }

    /**
     * test('there is no undo stop after a single whitespace')
     */
    function testThereIsNoUndoStopAfterASingleWhitespace() {
        final model = createTextModel(
            [
                ''
            ].join('\n'),
            null,
            {
                insertSpaces: false,
            }
        );

        withTestCodeEditor(model, {}, (editor, viewModel) -> {
            viewModel.type('a', 'keyboard');
            viewModel.type('b', 'keyboard');
            viewModel.type(' ', 'keyboard');
            viewModel.type('c', 'keyboard');
            viewModel.type('d', 'keyboard');

            assertEquals(model.getValue(EndOfLinePreference.LF), 'ab cd', 'assert1');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), 'ab', 'assert3');

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertEquals(model.getValue(EndOfLinePreference.LF), '', 'assert4');
        });

        model.dispose();
    }

}

/**
 * The local command class of test('issue #6862: Editor removes auto inserted
 * indentation when formatting on type').
 */
private class Issue6862TestCommand implements ICommand {

    final viewModel:ViewModel;
    var _selectionId:Null<String> = null;
    public final insertsAutoWhitespace:Bool = false;

    public function new(viewModel:ViewModel) {
        this.viewModel = viewModel;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addEditOperation(new Range(1, 13, 1, 14), '');
        this._selectionId = builder.trackSelection(viewModel.getSelection());
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return helper.getTrackedSelection(this._selectionId);
    }

}

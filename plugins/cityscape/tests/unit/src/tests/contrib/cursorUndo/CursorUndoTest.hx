// Ported from vscode src/vs/editor/contrib/cursorUndo/test/browser/cursorUndo.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.cursorUndo;

import cityscape.common.EditorCommon.Handler;
import cityscape.common.core.Selection;
import cityscape.contrib.cursorUndo.view.CursorUndo;
import cityscape.view.CoreCommands;
import testing.TestCase;
import testing.TestCodeEditor;

/**
 * suite('FindController') of cursorUndo.test.ts (vscode's suite name).
 */
class CursorUndoTest extends TestCase {

    final cursorUndoAction = new CursorUndo();

    static function selectionsToString(selections:Array<Selection>):Array<String> {
        return [for (s in selections) s.toString()];
    }

    function testIssue82535EdgeCaseWithCursorUndo() {
        TestCodeEditor.withTestCodeEditor('', {}, (editor, _) -> {

            editor.registerAndInstantiateContribution(CursorUndoRedoController.ID, e -> new CursorUndoRedoController(e));

            // type hello
            editor.trigger('test', Handler.Type, {text: 'hello'});

            // press left
            CoreNavigationCommands.CursorLeft.runEditorCommand(null, editor, {});

            // press Delete
            CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, {});
            assertEquals('hell', editor.getValue());
            assertDeepEquals(selectionsToString([new Selection(1, 5, 1, 5)]), selectionsToString(editor.getSelections()));

            // press left
            CoreNavigationCommands.CursorLeft.runEditorCommand(null, editor, {});
            assertDeepEquals(selectionsToString([new Selection(1, 4, 1, 4)]), selectionsToString(editor.getSelections()));

            // press Ctrl+U
            cursorUndoAction.run(null, editor, {});
            assertDeepEquals(selectionsToString([new Selection(1, 5, 1, 5)]), selectionsToString(editor.getSelections()));
        });
    }

    function testIssue82535EdgeCaseWithCursorUndoReverse() {
        TestCodeEditor.withTestCodeEditor('', {}, (editor, _) -> {

            editor.registerAndInstantiateContribution(CursorUndoRedoController.ID, e -> new CursorUndoRedoController(e));

            // type hello
            editor.trigger('test', Handler.Type, {text: 'hell'});
            editor.trigger('test', Handler.Type, {text: 'o'});
            assertEquals('hello', editor.getValue());
            assertDeepEquals(selectionsToString([new Selection(1, 6, 1, 6)]), selectionsToString(editor.getSelections()));

            // press Ctrl+U
            cursorUndoAction.run(null, editor, {});
            assertDeepEquals(selectionsToString([new Selection(1, 6, 1, 6)]), selectionsToString(editor.getSelections()));
        });
    }

}

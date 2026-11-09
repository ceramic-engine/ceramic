// Ported from vscode src/vs/editor/contrib/cursorUndo/browser/cursorUndo.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.cursorUndo.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.base.common.Lifecycle.Disposable;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorContextKeys;
import cityscape.common.core.Selection;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * Cursor undo and redo (cursorUndo.ts), registered by
 * `CursorUndoRegistration.register`.
 */

private class CursorState {

    public final selections:Array<Selection>;

    public function new(selections:Array<Selection>) {
        this.selections = selections;
    }

    public function equals(other:CursorState):Bool {
        final thisLen = this.selections.length;
        final otherLen = other.selections.length;
        if (thisLen != otherLen) {
            return false;
        }
        for (i in 0...thisLen) {
            if (!this.selections[i].equalsSelection(other.selections[i])) {
                return false;
            }
        }
        return true;
    }

}

private class StackElement {

    public final cursorState:CursorState;
    public final scrollTop:Float;
    public final scrollLeft:Float;

    public function new(cursorState:CursorState, scrollTop:Float, scrollLeft:Float) {
        this.cursorState = cursorState;
        this.scrollTop = scrollTop;
        this.scrollLeft = scrollLeft;
    }

}

class CursorUndoRedoController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.cursorUndoRedoController';

    public static function get(editor:ICodeEditor):Null<CursorUndoRedoController> {
        return editor.getContribution(CursorUndoRedoController.ID);
    }

    final _editor:ICodeEditor;
    var _isCursorUndoRedo:Bool;

    var _undoStack:Array<StackElement>;
    var _redoStack:Array<StackElement>;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._isCursorUndoRedo = false;

        this._undoStack = [];
        this._redoStack = [];

        this._register(editor.onDidChangeModel((e) -> {
            this._undoStack = [];
            this._redoStack = [];
        }));
        this._register(editor.onDidChangeModelContent((e) -> {
            this._undoStack = [];
            this._redoStack = [];
        }));
        this._register(editor.onDidChangeCursorSelection((e) -> {
            if (this._isCursorUndoRedo) {
                return;
            }
            if (e.oldSelections == null) {
                return;
            }
            if (e.oldModelVersionId != e.modelVersionId) {
                return;
            }
            final prevState = new CursorState(e.oldSelections);
            final isEqualToLastUndoStack = (this._undoStack.length > 0 && this._undoStack[this._undoStack.length - 1].cursorState.equals(prevState));
            if (!isEqualToLastUndoStack) {
                this._undoStack.push(new StackElement(prevState, editor.getScrollTop(), editor.getScrollLeft()));
                this._redoStack = [];
                if (this._undoStack.length > 50) {
                    // keep the cursor undo stack bounded
                    this._undoStack.shift();
                }
            }
        }));
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function cursorUndo():Void {
        if (!this._editor.hasModel() || this._undoStack.length == 0) {
            return;
        }

        this._redoStack.push(new StackElement(new CursorState(this._editor.getSelections()), this._editor.getScrollTop(), this._editor.getScrollLeft()));
        this._applyState(this._undoStack.pop());
    }

    public function cursorRedo():Void {
        if (!this._editor.hasModel() || this._redoStack.length == 0) {
            return;
        }

        this._undoStack.push(new StackElement(new CursorState(this._editor.getSelections()), this._editor.getScrollTop(), this._editor.getScrollLeft()));
        this._applyState(this._redoStack.pop());
    }

    function _applyState(stackElement:StackElement):Void {
        this._isCursorUndoRedo = true;
        this._editor.setSelections(cast stackElement.cursorState.selections);
        this._editor.setScrollPosition({
            scrollTop: stackElement.scrollTop,
            scrollLeft: stackElement.scrollLeft
        });
        this._isCursorUndoRedo = false;
    }

}

class CursorUndo extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'cursorUndo',
            label: r != null ? r.localize('cursor.undo', "Cursor Undo") : "Cursor Undo",
            alias: 'Cursor Undo',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.CtrlCmd | KeyCode.KeyU,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = CursorUndoRedoController.get(editor);
        if (controller != null) {
            controller.cursorUndo();
        }
    }

}

class CursorRedo extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'cursorRedo',
            label: r != null ? r.localize('cursor.redo', "Cursor Redo") : "Cursor Redo",
            alias: 'Cursor Redo',
            precondition: null
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = CursorUndoRedoController.get(editor);
        if (controller != null) {
            controller.cursorRedo();
        }
    }

}

class CursorUndoRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(CursorUndoRedoController.ID, editor -> new CursorUndoRedoController(editor), EditorContributionInstantiation.Eager); // eager because it needs to listen to record cursor state ASAP
        r.registerEditorAction(new CursorUndo(r));
        r.registerEditorAction(new CursorRedo(r));
    }

}

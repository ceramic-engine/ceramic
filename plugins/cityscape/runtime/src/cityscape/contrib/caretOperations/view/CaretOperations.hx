// Ported from vscode src/vs/editor/contrib/caretOperations/browser/caretOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.caretOperations.view;

import cityscape.Cityscape;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorContextKeys;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * The actions of caretOperations.ts and transpose.ts, registered by
 * `CaretOperationsRegistration.register`.
 */

class MoveCaretAction extends EditorAction {

    final left:Bool;

    public function new(left:Bool, opts:IActionOptions) {
        super(opts);

        this.left = left;
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final commands:Array<Null<ICommand>> = [];
        final selections = editor.getSelections();

        for (selection in selections) {
            commands.push(new MoveCaretCommand(selection, this.left));
        }

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

class MoveCaretLeftAction extends MoveCaretAction {

    public function new(?r:EditorExtensionsRegistry) {
        super(true, {
            id: 'editor.action.moveCarretLeftAction',
            label: r != null ? r.localize('caret.moveLeft', "Move Selected Text Left") : "Move Selected Text Left",
            alias: 'Move Selected Text Left',
            precondition: EditorContextKeys.writable
        });
    }

}

class MoveCaretRightAction extends MoveCaretAction {

    public function new(?r:EditorExtensionsRegistry) {
        super(false, {
            id: 'editor.action.moveCarretRightAction',
            label: r != null ? r.localize('caret.moveRight', "Move Selected Text Right") : "Move Selected Text Right",
            alias: 'Move Selected Text Right',
            precondition: EditorContextKeys.writable
        });
    }

}

class CaretOperationsRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        // caretOperations.ts
        r.registerEditorAction(new MoveCaretLeftAction(r));
        r.registerEditorAction(new MoveCaretRightAction(r));
        // transpose.ts
        r.registerEditorAction(new Transpose.TransposeLettersAction(r));
    }

}

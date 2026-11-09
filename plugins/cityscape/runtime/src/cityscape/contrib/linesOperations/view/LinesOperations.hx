// Ported from vscode src/vs/editor/contrib/linesOperations/browser/linesOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.linesOperations.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.common.EditorContextKeys;
import cityscape.common.cursor.CursorTypeOperations;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.CoreCommands;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * TODO(step 4, linesOperations): only the indent and outdent line actions
 * so far (the editor's Cmd+] and Cmd+[); the other line operations (copy,
 * move, sort, delete, join, transpose, case...) come with the contribution.
 */

class IndentLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.indentLines',
            label: r != null ? r.localize('lines.indent', "Indent Line") : "Indent Line",
            alias: 'Indent Line',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyCode.BracketRight,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final viewModel = editor._getViewModel();
        if (viewModel == null) {
            return;
        }
        editor.pushUndoStop();
        editor.executeCommands(this.id, cast TypeOperations.indent(viewModel.cursorConfig, editor.getModel(), editor.getSelections()));
        editor.pushUndoStop();
    }

}

class OutdentLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.outdentLines',
            label: r != null ? r.localize('lines.outdent', "Outdent Line") : "Outdent Line",
            alias: 'Outdent Line',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyCode.BracketLeft,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        CoreEditingCommands.Outdent.runEditorCommand(_accessor, editor, null);
    }

}

class LinesOperationsRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorAction(new IndentLinesAction(r));
        r.registerEditorAction(new OutdentLinesAction(r));
    }

}

// Ported from vscode src/vs/editor/contrib/caretOperations/browser/transpose.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.caretOperations.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorContextKeys;
import cityscape.common.commands.ReplaceCommand;
import cityscape.common.core.Range;
import cityscape.common.cursor.CursorMoveOperations.MoveOperations;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

class TransposeLettersAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transposeLetters',
            label: r != null ? r.localize('transposeLetters.label', "Transpose Letters") : "Transpose Letters",
            alias: 'Transpose Letters',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.textInputFocus,
                primary: 0,
                mac: {
                    primary: KeyMod.WinCtrl | KeyCode.KeyT
                },
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final model = editor.getModel();
        final commands:Array<Null<ICommand>> = [];
        final selections = editor.getSelections();

        for (selection in selections) {
            if (!selection.isEmpty()) {
                continue;
            }

            final lineNumber = selection.startLineNumber;
            final column = selection.startColumn;

            final lastColumn = model.getLineMaxColumn(lineNumber);

            if (lineNumber == 1 && (column == 1 || (column == 2 && lastColumn == 2))) {
                // at beginning of file, nothing to do
                continue;
            }

            // handle special case: when at end of line, transpose left two chars
            // otherwise, transpose left and right chars
            final endPosition = (column == lastColumn) ?
                selection.getPosition() :
                MoveOperations.rightPosition(model, selection.getPosition().lineNumber, selection.getPosition().column);

            final middlePosition = MoveOperations.leftPosition(model, endPosition);
            final beginPosition = MoveOperations.leftPosition(model, middlePosition);

            final leftChar = model.getValueInRange(Range.fromPositions(beginPosition, middlePosition));
            final rightChar = model.getValueInRange(Range.fromPositions(middlePosition, endPosition));

            final replaceRange = Range.fromPositions(beginPosition, endPosition);
            commands.push(new ReplaceCommand(replaceRange, rightChar + leftChar));
        }

        if (commands.length > 0) {
            editor.pushUndoStop();
            editor.executeCommands(this.id, commands);
            editor.pushUndoStop();
        }
    }

}

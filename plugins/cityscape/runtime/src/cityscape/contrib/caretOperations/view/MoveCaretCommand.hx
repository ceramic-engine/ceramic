// Ported from vscode src/vs/editor/contrib/caretOperations/browser/moveCaretCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.caretOperations.view;

import cityscape.common.EditorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

class MoveCaretCommand implements ICommand {

    final _selection:Selection;
    final _isMovingLeft:Bool;

    public final insertsAutoWhitespace:Bool = false;

    public function new(selection:Selection, isMovingLeft:Bool) {
        this._selection = selection;
        this._isMovingLeft = isMovingLeft;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        if (this._selection.startLineNumber != this._selection.endLineNumber || this._selection.isEmpty()) {
            return;
        }
        final lineNumber = this._selection.startLineNumber;
        final startColumn = this._selection.startColumn;
        final endColumn = this._selection.endColumn;
        if (this._isMovingLeft && startColumn == 1) {
            return;
        }
        if (!this._isMovingLeft && endColumn == model.getLineMaxColumn(lineNumber)) {
            return;
        }

        if (this._isMovingLeft) {
            final rangeBefore = new Range(lineNumber, startColumn - 1, lineNumber, startColumn);
            final charBefore = model.getValueInRange(rangeBefore);
            builder.addEditOperation(rangeBefore, null);
            builder.addEditOperation(new Range(lineNumber, endColumn, lineNumber, endColumn), charBefore);
        }
        else {
            final rangeAfter = new Range(lineNumber, endColumn, lineNumber, endColumn + 1);
            final charAfter = model.getValueInRange(rangeAfter);
            builder.addEditOperation(rangeAfter, null);
            builder.addEditOperation(new Range(lineNumber, startColumn, lineNumber, startColumn), charAfter);
        }
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        if (this._isMovingLeft) {
            return new Selection(this._selection.startLineNumber, this._selection.startColumn - 1, this._selection.endLineNumber, this._selection.endColumn - 1);
        }
        else {
            return new Selection(this._selection.startLineNumber, this._selection.startColumn + 1, this._selection.endLineNumber, this._selection.endColumn + 1);
        }
    }

}

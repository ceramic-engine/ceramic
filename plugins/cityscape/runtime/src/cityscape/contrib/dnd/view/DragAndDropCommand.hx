// Ported from vscode src/vs/editor/contrib/dnd/browser/dragAndDropCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.dnd.view;

import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ICursorStateComputerData;
import cityscape.common.EditorCommon.IEditOperationBuilder;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

/**
 * Moves (or copies) the text of a selection to a position, the moved text
 * selected afterwards.
 */
class DragAndDropCommand implements ICommand {

    final selection:Selection;
    final targetPosition:Position;
    var targetSelection:Null<Selection>;
    final copy:Bool;

    public final insertsAutoWhitespace:Bool = false;

    public function new(selection:Selection, targetPosition:Position, copy:Bool) {
        this.selection = selection;
        this.targetPosition = targetPosition;
        this.copy = copy;
        this.targetSelection = null;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        final text = model.getValueInRange(this.selection);
        if (!this.copy) {
            builder.addEditOperation(this.selection, null);
        }
        builder.addEditOperation(new Range(this.targetPosition.lineNumber, this.targetPosition.column, this.targetPosition.lineNumber, this.targetPosition.column), text);

        if (this.selection.containsPosition(this.targetPosition) && !(
            this.copy && (
                this.selection.getEndPosition().equals(this.targetPosition) || this.selection.getStartPosition().equals(this.targetPosition)
            ) // we allow users to paste content beside the selection
        )) {
            this.targetSelection = this.selection;
            return;
        }

        if (this.copy) {
            this.targetSelection = new Selection(
                this.targetPosition.lineNumber,
                this.targetPosition.column,
                this.selection.endLineNumber - this.selection.startLineNumber + this.targetPosition.lineNumber,
                this.selection.startLineNumber == this.selection.endLineNumber ?
                    this.targetPosition.column + this.selection.endColumn - this.selection.startColumn :
                    this.selection.endColumn
            );
            return;
        }

        if (this.targetPosition.lineNumber > this.selection.endLineNumber) {
            // Drag the selection downwards
            this.targetSelection = new Selection(
                this.targetPosition.lineNumber - this.selection.endLineNumber + this.selection.startLineNumber,
                this.targetPosition.column,
                this.targetPosition.lineNumber,
                this.selection.startLineNumber == this.selection.endLineNumber ?
                    this.targetPosition.column + this.selection.endColumn - this.selection.startColumn :
                    this.selection.endColumn
            );
            return;
        }

        if (this.targetPosition.lineNumber < this.selection.endLineNumber) {
            // Drag the selection upwards
            this.targetSelection = new Selection(
                this.targetPosition.lineNumber,
                this.targetPosition.column,
                this.targetPosition.lineNumber + this.selection.endLineNumber - this.selection.startLineNumber,
                this.selection.startLineNumber == this.selection.endLineNumber ?
                    this.targetPosition.column + this.selection.endColumn - this.selection.startColumn :
                    this.selection.endColumn
            );
            return;
        }

        // The target position is at the same line as the selection's end position.
        if (this.selection.endColumn <= this.targetPosition.column) {
            // The target position is after the selection's end position
            this.targetSelection = new Selection(
                this.targetPosition.lineNumber - this.selection.endLineNumber + this.selection.startLineNumber,
                this.selection.startLineNumber == this.selection.endLineNumber ?
                    this.targetPosition.column - this.selection.endColumn + this.selection.startColumn :
                    this.targetPosition.column - this.selection.endColumn + this.selection.startColumn,
                this.targetPosition.lineNumber,
                this.selection.startLineNumber == this.selection.endLineNumber ?
                    this.targetPosition.column :
                    this.selection.endColumn
            );
        }
        else {
            // The target position is before the selection's end position. Since the selection doesn't contain the target position, the selection is one-line and target position is before this selection.
            this.targetSelection = new Selection(
                this.targetPosition.lineNumber - this.selection.endLineNumber + this.selection.startLineNumber,
                this.targetPosition.column,
                this.targetPosition.lineNumber,
                this.targetPosition.column + this.selection.endColumn - this.selection.startColumn
            );
        }
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return this.targetSelection;
    }

}

// Ported from vscode src/vs/editor/contrib/inPlaceReplace/browser/inPlaceReplaceCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inPlaceReplace.view;

import cityscape.common.EditorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

class InPlaceReplaceCommand implements ICommand {

    final _editRange:Range;
    final _originalSelection:Selection;
    final _text:String;

    public final insertsAutoWhitespace:Bool = false;

    public function new(editRange:Range, originalSelection:Selection, text:String) {
        this._editRange = editRange;
        this._originalSelection = originalSelection;
        this._text = text;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(this._editRange, this._text);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        final srcRange = inverseEditOperations[0].range;

        if (!this._originalSelection.isEmpty()) {
            // Preserve selection and extends to typed text
            return new Selection(
                srcRange.endLineNumber,
                srcRange.endColumn - this._text.length,
                srcRange.endLineNumber,
                srcRange.endColumn
            );
        }

        return new Selection(
            srcRange.endLineNumber,
            Std.int(Math.min(this._originalSelection.positionColumn, srcRange.endColumn)),
            srcRange.endLineNumber,
            Std.int(Math.min(this._originalSelection.positionColumn, srcRange.endColumn))
        );
    }

}

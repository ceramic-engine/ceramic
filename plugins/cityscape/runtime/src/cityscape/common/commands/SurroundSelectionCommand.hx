// Ported from vscode src/vs/editor/common/commands/surroundSelectionCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.commands;

import cityscape.common.EditorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

class SurroundSelectionCommand implements ICommand {

    final _range:Selection;
    final _charBeforeSelection:String;
    final _charAfterSelection:String;
    public final insertsAutoWhitespace:Bool = false;

    public function new(range:Selection, charBeforeSelection:String, charAfterSelection:String) {
        this._range = range;
        this._charBeforeSelection = charBeforeSelection;
        this._charAfterSelection = charAfterSelection;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(new Range(
            this._range.startLineNumber,
            this._range.startColumn,
            this._range.startLineNumber,
            this._range.startColumn
        ), this._charBeforeSelection);

        builder.addTrackedEditOperation(new Range(
            this._range.endLineNumber,
            this._range.endColumn,
            this._range.endLineNumber,
            this._range.endColumn
        ), this._charAfterSelection);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        final firstOperationRange = inverseEditOperations[0].range;
        final secondOperationRange = inverseEditOperations[1].range;

        return new Selection(
            firstOperationRange.endLineNumber,
            firstOperationRange.endColumn,
            secondOperationRange.endLineNumber,
            secondOperationRange.endColumn - this._charAfterSelection.length
        );
    }

}

/**
 * A surround selection command that runs after composition finished.
 */
class CompositionSurroundSelectionCommand implements ICommand {

    final _position:Position;
    final _text:String;
    final _charAfter:String;
    public final insertsAutoWhitespace:Bool = false;

    public function new(_position:Position, _text:String, _charAfter:String) {
        this._position = _position;
        this._text = _text;
        this._charAfter = _charAfter;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(new Range(
            this._position.lineNumber,
            this._position.column,
            this._position.lineNumber,
            this._position.column
        ), this._text + this._charAfter);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        final opRange = inverseEditOperations[0].range;

        return new Selection(
            opRange.endLineNumber,
            opRange.startColumn,
            opRange.endLineNumber,
            opRange.endColumn - this._charAfter.length
        );
    }

}

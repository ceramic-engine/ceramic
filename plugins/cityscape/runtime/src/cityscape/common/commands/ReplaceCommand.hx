// Ported from vscode src/vs/editor/common/commands/replaceCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.commands;

import cityscape.common.EditorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

class ReplaceCommand implements ICommand {

    final _range:Range;
    final _text:String;
    public final insertsAutoWhitespace:Bool;

    public function new(range:Range, text:String, insertsAutoWhitespace:Bool = false) {
        this._range = range;
        this._text = text;
        this.insertsAutoWhitespace = insertsAutoWhitespace;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(this._range, this._text);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        final srcRange = inverseEditOperations[0].range;
        return Selection.fromPositions(srcRange.getEndPosition());
    }

}

class ReplaceCommandThatSelectsText implements ICommand {

    final _range:Range;
    final _text:String;
    public final insertsAutoWhitespace:Bool = false;

    public function new(range:Range, text:String) {
        this._range = range;
        this._text = text;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(this._range, this._text);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        final srcRange = inverseEditOperations[0].range;
        return Selection.fromRange(srcRange, SelectionDirection.LTR);
    }

}

class ReplaceCommandWithoutChangingPosition implements ICommand {

    final _range:Range;
    final _text:String;
    public final insertsAutoWhitespace:Bool;

    public function new(range:Range, text:String, insertsAutoWhitespace:Bool = false) {
        this._range = range;
        this._text = text;
        this.insertsAutoWhitespace = insertsAutoWhitespace;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(this._range, this._text);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        final srcRange = inverseEditOperations[0].range;
        return Selection.fromPositions(srcRange.getStartPosition());
    }

}

class ReplaceCommandWithOffsetCursorState implements ICommand {

    final _range:Range;
    final _text:String;
    final _columnDeltaOffset:Int;
    final _lineNumberDeltaOffset:Int;
    public final insertsAutoWhitespace:Bool;

    public function new(range:Range, text:String, lineNumberDeltaOffset:Int, columnDeltaOffset:Int, insertsAutoWhitespace:Bool = false) {
        this._range = range;
        this._text = text;
        this._columnDeltaOffset = columnDeltaOffset;
        this._lineNumberDeltaOffset = lineNumberDeltaOffset;
        this.insertsAutoWhitespace = insertsAutoWhitespace;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(this._range, this._text);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        final srcRange = inverseEditOperations[0].range;
        return Selection.fromPositions(srcRange.getEndPosition().delta(this._lineNumberDeltaOffset, this._columnDeltaOffset));
    }

}

class ReplaceCommandThatPreservesSelection implements ICommand {

    final _range:Range;
    final _text:String;
    final _initialSelection:Selection;
    final _forceMoveMarkers:Bool;
    var _selectionId:Null<String>;
    public final insertsAutoWhitespace:Bool = false;

    public function new(editRange:Range, text:String, initialSelection:Selection, forceMoveMarkers:Bool = false) {
        this._range = editRange;
        this._text = text;
        this._initialSelection = initialSelection;
        this._forceMoveMarkers = forceMoveMarkers;
        this._selectionId = null;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(this._range, this._text, this._forceMoveMarkers);
        this._selectionId = builder.trackSelection(this._initialSelection);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return helper.getTrackedSelection(this._selectionId);
    }

}

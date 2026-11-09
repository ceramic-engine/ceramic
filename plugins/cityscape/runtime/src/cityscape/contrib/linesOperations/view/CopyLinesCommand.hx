// Ported from vscode src/vs/editor/contrib/linesOperations/browser/copyLinesCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.linesOperations.view;

import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ICursorStateComputerData;
import cityscape.common.EditorCommon.IEditOperationBuilder;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

class CopyLinesCommand implements ICommand {

    final _selection:Selection;
    final _isCopyingDown:Bool;
    final _noop:Bool;

    var _selectionDirection:SelectionDirection;
    var _selectionId:Null<String>;
    var _startLineNumberDelta:Int;
    var _endLineNumberDelta:Int;

    public final insertsAutoWhitespace:Bool = false;

    public function new(selection:Selection, isCopyingDown:Bool, ?noop:Bool) {
        this._selection = selection;
        this._isCopyingDown = isCopyingDown;
        this._noop = noop == true;
        this._selectionDirection = SelectionDirection.LTR;
        this._selectionId = null;
        this._startLineNumberDelta = 0;
        this._endLineNumberDelta = 0;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        var s = this._selection;

        this._startLineNumberDelta = 0;
        this._endLineNumberDelta = 0;
        if (s.startLineNumber < s.endLineNumber && s.endColumn == 1) {
            this._endLineNumberDelta = 1;
            s = s.setEndPosition(s.endLineNumber - 1, model.getLineMaxColumn(s.endLineNumber - 1));
        }

        final sourceLines:Array<String> = [];
        for (i in s.startLineNumber...s.endLineNumber + 1) {
            sourceLines.push(model.getLineContent(i));
        }
        final sourceText = sourceLines.join('\n');

        if (sourceText == '') {
            // Duplicating empty line
            if (this._isCopyingDown) {
                this._startLineNumberDelta++;
                this._endLineNumberDelta++;
            }
        }

        if (this._noop) {
            builder.addEditOperation(new Range(s.endLineNumber, model.getLineMaxColumn(s.endLineNumber), s.endLineNumber + 1, 1), s.endLineNumber == model.getLineCount() ? '' : '\n');
        }
        else {
            if (!this._isCopyingDown) {
                builder.addEditOperation(new Range(s.endLineNumber, model.getLineMaxColumn(s.endLineNumber), s.endLineNumber, model.getLineMaxColumn(s.endLineNumber)), '\n' + sourceText);
            }
            else {
                builder.addEditOperation(new Range(s.startLineNumber, 1, s.startLineNumber, 1), sourceText + '\n');
            }
        }

        this._selectionId = builder.trackSelection(s);
        this._selectionDirection = this._selection.getDirection();
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        var result = helper.getTrackedSelection(this._selectionId);

        if (this._startLineNumberDelta != 0 || this._endLineNumberDelta != 0) {
            var startLineNumber = result.startLineNumber;
            var startColumn = result.startColumn;
            var endLineNumber = result.endLineNumber;
            var endColumn = result.endColumn;

            if (this._startLineNumberDelta != 0) {
                startLineNumber = startLineNumber + this._startLineNumberDelta;
                startColumn = 1;
            }

            if (this._endLineNumberDelta != 0) {
                endLineNumber = endLineNumber + this._endLineNumberDelta;
                endColumn = 1;
            }

            result = Selection.createWithDirection(startLineNumber, startColumn, endLineNumber, endColumn, this._selectionDirection);
        }

        return result;
    }

}

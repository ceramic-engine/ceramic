// Ported from vscode src/vs/editor/contrib/linesOperations/browser/sortLinesCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.linesOperations.view;

import cityscape.base.common.Collator;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ICursorStateComputerData;
import cityscape.common.EditorCommon.IEditOperationBuilder;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

/**
 * The result of `getSortData`.
 */
private typedef SortData = {
    final startLineNumber:Int;
    final endLineNumber:Int;
    final before:Array<String>;
    final after:Array<String>;
}

class SortLinesCommand implements ICommand {

    static var _COLLATOR:Null<Collator> = null;

    public static function getCollator():Collator {
        if (SortLinesCommand._COLLATOR == null) {
            SortLinesCommand._COLLATOR = new Collator();
        }
        return SortLinesCommand._COLLATOR;
    }

    final selection:Selection;
    final descending:Bool;
    var selectionId:Null<String>;

    public final insertsAutoWhitespace:Bool = false;

    public function new(selection:Selection, descending:Bool) {
        this.selection = selection;
        this.descending = descending;
        this.selectionId = null;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        final op = sortLines(model, this.selection, this.descending);
        if (op != null) {
            builder.addEditOperation(op.range, op.text);
        }

        this.selectionId = builder.trackSelection(this.selection);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return helper.getTrackedSelection(this.selectionId);
    }

    public static function canRun(model:Null<ITextModel>, selection:Selection, descending:Bool):Bool {
        if (model == null) {
            return false;
        }

        final data = getSortData(model, selection, descending);

        if (data == null) {
            return false;
        }

        for (i in 0...data.before.length) {
            if (data.before[i] != data.after[i]) {
                return true;
            }
        }

        return false;
    }

    static function getSortData(model:ITextModel, selection:Selection, descending:Bool):Null<SortData> {
        final startLineNumber = selection.startLineNumber;
        var endLineNumber = selection.endLineNumber;

        if (selection.endColumn == 1) {
            endLineNumber--;
        }

        // Nothing to sort if user didn't select anything.
        if (startLineNumber >= endLineNumber) {
            return null;
        }

        final linesToSort:Array<String> = [];

        // Get the contents of the selection to be sorted.
        for (lineNumber in startLineNumber...endLineNumber + 1) {
            linesToSort.push(model.getLineContent(lineNumber));
        }

        var sorted = linesToSort.slice(0);
        final collator = SortLinesCommand.getCollator();
        haxe.ds.ArraySort.sort(sorted, collator.compare);

        // If descending, reverse the order.
        if (descending == true) {
            sorted.reverse();
        }

        return {
            startLineNumber: startLineNumber,
            endLineNumber: endLineNumber,
            before: linesToSort,
            after: sorted
        };
    }

    static function sortLines(model:ITextModel, selection:Selection, descending:Bool):Null<ISingleEditOperation> {
        final data = getSortData(model, selection, descending);

        if (data == null) {
            return null;
        }

        return EditOperation.replace(
            new Range(data.startLineNumber, 1, data.endLineNumber, model.getLineMaxColumn(data.endLineNumber)),
            data.after.join('\n')
        );
    }

}

// Ported from vscode src/vs/editor/contrib/find/browser/replaceAllCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.find.view;

import cityscape.common.EditorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

private class EditOperation {

    public var range:Range;
    public var text:String;

    public function new(range:Range, text:String) {
        this.range = range;
        this.text = text;
    }

}

/**
 * Replaces all the given ranges in one command (adjacent ones merged), and
 * keeps the editor selection where it was.
 */
class ReplaceAllCommand implements ICommand {

    final _editorSelection:Selection;
    var _trackedEditorSelectionId:Null<String>;
    final _ranges:Array<Range>;
    final _replaceStrings:Array<String>;
    public final insertsAutoWhitespace:Bool = false;

    public function new(editorSelection:Selection, ranges:Array<Range>, replaceStrings:Array<String>) {
        this._editorSelection = editorSelection;
        this._ranges = ranges;
        this._replaceStrings = replaceStrings;
        this._trackedEditorSelectionId = null;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        if (this._ranges.length > 0) {
            // Collect all edit operations
            final ops:Array<EditOperation> = [];
            for (i in 0...this._ranges.length) {
                ops.push(new EditOperation(this._ranges[i], this._replaceStrings[i]));
            }

            // Sort them in ascending order by range starts
            haxe.ds.ArraySort.sort(ops, (o1, o2) -> {
                return Range.compareRangesUsingStarts(o1.range, o2.range);
            });

            // Merge operations that touch each other
            final resultOps:Array<EditOperation> = [];
            var previousOp = ops[0];
            for (i in 1...ops.length) {
                if (previousOp.range.endLineNumber == ops[i].range.startLineNumber && previousOp.range.endColumn == ops[i].range.startColumn) {
                    // These operations are one after another and can be merged
                    previousOp.range = previousOp.range.plusRange(ops[i].range);
                    previousOp.text = previousOp.text + ops[i].text;
                } else {
                    resultOps.push(previousOp);
                    previousOp = ops[i];
                }
            }
            resultOps.push(previousOp);

            for (op in resultOps) {
                builder.addEditOperation(op.range, op.text);
            }
        }

        this._trackedEditorSelectionId = builder.trackSelection(this._editorSelection);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return helper.getTrackedSelection(this._trackedEditorSelectionId);
    }

}

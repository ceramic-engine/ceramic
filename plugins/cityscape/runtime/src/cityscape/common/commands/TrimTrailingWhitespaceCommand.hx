// Ported from vscode src/vs/editor/common/commands/trimTrailingWhitespaceCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.commands;

import cityscape.base.common.Strings;
import cityscape.common.EditorCommon;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Model;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

class TrimTrailingWhitespaceCommand implements ICommand {

    final _selection:Selection;
    var _selectionId:Null<String>;
    final _cursors:Array<Position>;
    final _trimInRegexesAndStrings:Bool;
    public final insertsAutoWhitespace:Bool = false;

    public function new(selection:Selection, cursors:Array<Position>, trimInRegexesAndStrings:Bool) {
        this._selection = selection;
        this._cursors = cursors;
        this._selectionId = null;
        this._trimInRegexesAndStrings = trimInRegexesAndStrings;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        final ops = trimTrailingWhitespace(model, this._cursors, this._trimInRegexesAndStrings);
        for (i in 0...ops.length) {
            final op = ops[i];

            builder.addEditOperation(op.range, op.text);
        }

        this._selectionId = builder.trackSelection(this._selection);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        return helper.getTrackedSelection(this._selectionId);
    }

    /**
     * Generate commands for trimming trailing whitespace on a model and ignore lines on which cursors are sitting.
     */
    public static function trimTrailingWhitespace(model:ITextModel, cursors:Array<Position>, trimInRegexesAndStrings:Bool):Array<IIdentifiedSingleEditOperation> {
        // Sort cursors ascending
        haxe.ds.ArraySort.sort(cursors, (a, b) -> {
            if (a.lineNumber == b.lineNumber) {
                return a.column - b.column;
            }
            return a.lineNumber - b.lineNumber;
        });

        // Reduce multiple cursors on the same line and only keep the last one on the line
        var i = cursors.length - 2;
        while (i >= 0) {
            if (cursors[i].lineNumber == cursors[i + 1].lineNumber) {
                // Remove cursor at `i`
                cursors.splice(i, 1);
            }
            i--;
        }

        final r:Array<IIdentifiedSingleEditOperation> = [];
        var rLen = 0;
        var cursorIndex = 0;
        final cursorLen = cursors.length;

        final lineCount = model.getLineCount();
        for (lineNumber in 1...lineCount + 1) {
            final lineContent = model.getLineContent(lineNumber);
            final maxLineColumn = lineContent.length + 1;
            var minEditColumn = 0;

            if (cursorIndex < cursorLen && cursors[cursorIndex].lineNumber == lineNumber) {
                minEditColumn = cursors[cursorIndex].column;
                cursorIndex++;
                if (minEditColumn == maxLineColumn) {
                    // The cursor is at the end of the line => no edits for sure on this line
                    continue;
                }
            }

            if (lineContent.length == 0) {
                continue;
            }

            final lastNonWhitespaceIndex = Strings.lastNonWhitespaceIndex(lineContent);

            var fromColumn = 0;
            if (lastNonWhitespaceIndex == -1) {
                // Entire line is whitespace
                fromColumn = 1;
            }
            else if (lastNonWhitespaceIndex != lineContent.length - 1) {
                // There is trailing whitespace
                fromColumn = lastNonWhitespaceIndex + 2;
            }
            else {
                // There is no trailing whitespace
                continue;
            }

            if (!trimInRegexesAndStrings) {
                if (!model.tokenization.hasAccurateTokensForLine(lineNumber)) {
                    // We don't want to force line tokenization, as that can be expensive, but we also don't want to trim
                    // trailing whitespace in lines that are not tokenized yet, as that can be wrong and trim whitespace from
                    // lines that the user requested we don't. So we bail out if the tokens are not accurate for this line.
                    continue;
                }

                final lineTokens = model.tokenization.getLineTokens(lineNumber);
                final fromColumnType = lineTokens.getStandardTokenType(lineTokens.findTokenIndexAtOffset(fromColumn));

                if (fromColumnType == StandardTokenType.String || fromColumnType == StandardTokenType.RegEx) {
                    continue;
                }
            }

            fromColumn = Std.int(Math.max(minEditColumn, fromColumn));
            r[rLen++] = EditOperation.delete(new Range(
                lineNumber, fromColumn,
                lineNumber, maxLineColumn
            ));
        }

        return r;
    }

}

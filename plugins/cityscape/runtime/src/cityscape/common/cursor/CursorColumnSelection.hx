// Ported from vscode src/vs/editor/common/cursor/cursorColumnSelection.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.common.CursorCommon;
import cityscape.common.core.Position;
import cityscape.common.core.Range;

class ColumnSelection {

    public static function columnSelect(config:CursorConfiguration, model:ICursorSimpleModel, fromLineNumber:Int, fromVisibleColumn:Int, toLineNumber:Int, toVisibleColumn:Int):IColumnSelectResult {
        final lineCount = Std.int(Math.abs(toLineNumber - fromLineNumber)) + 1;
        final reversed = (fromLineNumber > toLineNumber);
        final isRTL = (fromVisibleColumn > toVisibleColumn);
        final isLTR = (fromVisibleColumn < toVisibleColumn);

        final result:Array<SingleCursorState> = [];

        for (i in 0...lineCount) {
            final lineNumber = fromLineNumber + (reversed ? -i : i);

            final startColumn = config.columnFromVisibleColumn(model, lineNumber, fromVisibleColumn);
            final endColumn = config.columnFromVisibleColumn(model, lineNumber, toVisibleColumn);
            final visibleStartColumn = config.visibleColumnFromColumn(model, new Position(lineNumber, startColumn));
            final visibleEndColumn = config.visibleColumnFromColumn(model, new Position(lineNumber, endColumn));

            if (isLTR) {
                if (visibleStartColumn > toVisibleColumn) {
                    continue;
                }
                if (visibleEndColumn < fromVisibleColumn) {
                    continue;
                }
            }

            if (isRTL) {
                if (visibleEndColumn > fromVisibleColumn) {
                    continue;
                }
                if (visibleStartColumn < toVisibleColumn) {
                    continue;
                }
            }

            result.push(new SingleCursorState(
                new Range(lineNumber, startColumn, lineNumber, startColumn), SelectionStartKind.Simple, 0,
                new Position(lineNumber, endColumn), 0
            ));
        }

        if (result.length == 0) {
            // We are after all the lines, so add cursor at the end of each line
            for (i in 0...lineCount) {
                final lineNumber = fromLineNumber + (reversed ? -i : i);
                final maxColumn = model.getLineMaxColumn(lineNumber);

                result.push(new SingleCursorState(
                    new Range(lineNumber, maxColumn, lineNumber, maxColumn), SelectionStartKind.Simple, 0,
                    new Position(lineNumber, maxColumn), 0
                ));
            }
        }

        return {
            viewStates: result,
            reversed: reversed,
            fromLineNumber: fromLineNumber,
            fromVisualColumn: fromVisibleColumn,
            toLineNumber: toLineNumber,
            toVisualColumn: toVisibleColumn
        };
    }

    public static function columnSelectLeft(config:CursorConfiguration, model:ICursorSimpleModel, prevColumnSelectData:IColumnSelectData):IColumnSelectResult {
        var toViewVisualColumn = prevColumnSelectData.toViewVisualColumn;
        if (toViewVisualColumn > 0) {
            toViewVisualColumn--;
        }

        return ColumnSelection.columnSelect(config, model, prevColumnSelectData.fromViewLineNumber, prevColumnSelectData.fromViewVisualColumn, prevColumnSelectData.toViewLineNumber, toViewVisualColumn);
    }

    public static function columnSelectRight(config:CursorConfiguration, model:ICursorSimpleModel, prevColumnSelectData:IColumnSelectData):IColumnSelectResult {
        var maxVisualViewColumn = 0;
        final minViewLineNumber = Std.int(Math.min(prevColumnSelectData.fromViewLineNumber, prevColumnSelectData.toViewLineNumber));
        final maxViewLineNumber = Std.int(Math.max(prevColumnSelectData.fromViewLineNumber, prevColumnSelectData.toViewLineNumber));
        for (lineNumber in minViewLineNumber...maxViewLineNumber + 1) {
            final lineMaxViewColumn = model.getLineMaxColumn(lineNumber);
            final lineMaxVisualViewColumn = config.visibleColumnFromColumn(model, new Position(lineNumber, lineMaxViewColumn));
            maxVisualViewColumn = Std.int(Math.max(maxVisualViewColumn, lineMaxVisualViewColumn));
        }

        var toViewVisualColumn = prevColumnSelectData.toViewVisualColumn;
        if (toViewVisualColumn < maxVisualViewColumn) {
            toViewVisualColumn++;
        }

        return columnSelect(config, model, prevColumnSelectData.fromViewLineNumber, prevColumnSelectData.fromViewVisualColumn, prevColumnSelectData.toViewLineNumber, toViewVisualColumn);
    }

    public static function columnSelectUp(config:CursorConfiguration, model:ICursorSimpleModel, prevColumnSelectData:IColumnSelectData, isPaged:Bool):IColumnSelectResult {
        final linesCount = isPaged ? config.pageSize : 1;
        final toViewLineNumber = Std.int(Math.max(1, prevColumnSelectData.toViewLineNumber - linesCount));
        return columnSelect(config, model, prevColumnSelectData.fromViewLineNumber, prevColumnSelectData.fromViewVisualColumn, toViewLineNumber, prevColumnSelectData.toViewVisualColumn);
    }

    public static function columnSelectDown(config:CursorConfiguration, model:ICursorSimpleModel, prevColumnSelectData:IColumnSelectData, isPaged:Bool):IColumnSelectResult {
        final linesCount = isPaged ? config.pageSize : 1;
        final toViewLineNumber = Std.int(Math.min(model.getLineCount(), prevColumnSelectData.toViewLineNumber + linesCount));
        return columnSelect(config, model, prevColumnSelectData.fromViewLineNumber, prevColumnSelectData.fromViewVisualColumn, toViewLineNumber, prevColumnSelectData.toViewVisualColumn);
    }

}

typedef IColumnSelectResult = {
    var viewStates:Array<SingleCursorState>;
    var reversed:Bool;
    var fromLineNumber:Int;
    var fromVisualColumn:Int;
    var toLineNumber:Int;
    var toVisualColumn:Int;
}

// Ported from vscode src/vs/editor/common/cursor/cursorMoveOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.base.common.Strings;
import cityscape.common.CursorCommon;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.core.CursorColumns;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.cursor.CursorAtomicMoveOperations;

class CursorPosition {

    public final lineNumber:Int;
    public final column:Int;
    public final leftoverVisibleColumns:Int;

    public function new(lineNumber:Int, column:Int, leftoverVisibleColumns:Int) {
        this.lineNumber = lineNumber;
        this.column = column;
        this.leftoverVisibleColumns = leftoverVisibleColumns;
    }

}

class MoveOperations {

    /**
     * `Constants.MAX_SAFE_SMALL_INTEGER` of base/common/uint.ts.
     */
    static inline final MAX_SAFE_SMALL_INTEGER = 1 << 30;

    public static function leftPosition(model:ICursorSimpleModel, position:Position):Position {
        if (position.column > model.getLineMinColumn(position.lineNumber)) {
            return position.delta(0, -Strings.prevCharLength(model.getLineContent(position.lineNumber), position.column - 1));
        }
        else if (position.lineNumber > 1) {
            final newLineNumber = position.lineNumber - 1;
            return new Position(newLineNumber, model.getLineMaxColumn(newLineNumber));
        }
        else {
            return position;
        }
    }

    static function leftPositionAtomicSoftTabs(model:ICursorSimpleModel, position:Position, tabSize:Int):Position {
        if (position.column <= model.getLineIndentColumn(position.lineNumber)) {
            final minColumn = model.getLineMinColumn(position.lineNumber);
            final lineContent = model.getLineContent(position.lineNumber);
            final newPosition = AtomicTabMoveOperations.atomicPosition(lineContent, position.column - 1, tabSize, Direction.Left);
            if (newPosition != -1 && newPosition + 1 >= minColumn) {
                return new Position(position.lineNumber, newPosition + 1);
            }
        }
        return leftPosition(model, position);
    }

    static function left(config:CursorConfiguration, model:ICursorSimpleModel, position:Position):CursorPosition {
        final pos = config.stickyTabStops
            ? MoveOperations.leftPositionAtomicSoftTabs(model, position, config.tabSize)
            : MoveOperations.leftPosition(model, position);
        return new CursorPosition(pos.lineNumber, pos.column, 0);
    }

    /**
     * @param noOfColumns Must be either `1`
     * or `Math.round(viewModel.getLineContent(viewLineNumber).length / 2)` (for half lines).
     */
    public static function moveLeft(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool, noOfColumns:Int):SingleCursorState {
        var lineNumber:Int;
        var column:Int;

        if (cursor.hasSelection() && !inSelectionMode) {
            // If the user has a selection and does not want to extend it,
            // put the cursor at the beginning of the selection.
            lineNumber = cursor.selection.startLineNumber;
            column = cursor.selection.startColumn;
        }
        else {
            // This has no effect if noOfColumns === 1.
            // It is ok to do so in the half-line scenario.
            final pos = cursor.position.delta(0, -(noOfColumns - 1));
            // We clip the position before normalization, as normalization is not defined
            // for possibly negative columns.
            final normalizedPos = model.normalizePosition(MoveOperations.clipPositionColumn(pos, model), PositionAffinity.Left);
            final p = MoveOperations.left(config, model, normalizedPos);

            lineNumber = p.lineNumber;
            column = p.column;
        }

        return cursor.move(inSelectionMode, lineNumber, column, 0);
    }

    /**
     * Adjusts the column so that it is within min/max of the line.
     */
    static function clipPositionColumn(position:Position, model:ICursorSimpleModel):Position {
        return new Position(
            position.lineNumber,
            MoveOperations.clipRange(position.column, model.getLineMinColumn(position.lineNumber),
                model.getLineMaxColumn(position.lineNumber))
        );
    }

    static function clipRange(value:Int, min:Int, max:Int):Int {
        if (value < min) {
            return min;
        }
        if (value > max) {
            return max;
        }
        return value;
    }

    public static function rightPosition(model:ICursorSimpleModel, lineNumber:Int, column:Int):Position {
        if (column < model.getLineMaxColumn(lineNumber)) {
            column = column + Strings.nextCharLength(model.getLineContent(lineNumber), column - 1);
        }
        else if (lineNumber < model.getLineCount()) {
            lineNumber = lineNumber + 1;
            column = model.getLineMinColumn(lineNumber);
        }
        return new Position(lineNumber, column);
    }

    public static function rightPositionAtomicSoftTabs(model:ICursorSimpleModel, lineNumber:Int, column:Int, tabSize:Int, indentSize:Int):Position {
        if (column < model.getLineIndentColumn(lineNumber)) {
            final lineContent = model.getLineContent(lineNumber);
            final newPosition = AtomicTabMoveOperations.atomicPosition(lineContent, column - 1, tabSize, Direction.Right);
            if (newPosition != -1) {
                return new Position(lineNumber, newPosition + 1);
            }
        }
        return rightPosition(model, lineNumber, column);
    }

    public static function right(config:CursorConfiguration, model:ICursorSimpleModel, position:Position):CursorPosition {
        final pos = config.stickyTabStops
            ? MoveOperations.rightPositionAtomicSoftTabs(model, position.lineNumber, position.column, config.tabSize, config.indentSize)
            : MoveOperations.rightPosition(model, position.lineNumber, position.column);
        return new CursorPosition(pos.lineNumber, pos.column, 0);
    }

    public static function moveRight(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool, noOfColumns:Int):SingleCursorState {
        var lineNumber:Int;
        var column:Int;

        if (cursor.hasSelection() && !inSelectionMode) {
            // If we are in selection mode, move right without selection cancels selection and puts cursor at the end of the selection
            lineNumber = cursor.selection.endLineNumber;
            column = cursor.selection.endColumn;
        }
        else {
            final pos = cursor.position.delta(0, noOfColumns - 1);
            final normalizedPos = model.normalizePosition(MoveOperations.clipPositionColumn(pos, model), PositionAffinity.Right);
            final r = MoveOperations.right(config, model, normalizedPos);
            lineNumber = r.lineNumber;
            column = r.column;
        }

        return cursor.move(inSelectionMode, lineNumber, column, 0);
    }

    /**
     * `normalizationAffinity` is optional in Monaco: null here means no
     * normalization.
     */
    public static function vertical(config:CursorConfiguration, model:ICursorSimpleModel, lineNumber:Int, column:Int, leftoverVisibleColumns:Int, newLineNumber:Int, allowMoveOnEdgeLine:Bool, ?normalizationAffinity:PositionAffinity):CursorPosition {
        final currentVisibleColumn = CursorColumns.visibleColumnFromColumn(model.getLineContent(lineNumber), column, config.tabSize) + leftoverVisibleColumns;
        final lineCount = model.getLineCount();
        final wasOnFirstPosition = (lineNumber == 1 && column == 1);
        final wasOnLastPosition = (lineNumber == lineCount && column == model.getLineMaxColumn(lineNumber));
        final wasAtEdgePosition = (newLineNumber < lineNumber ? wasOnFirstPosition : wasOnLastPosition);

        lineNumber = newLineNumber;
        if (lineNumber < 1) {
            lineNumber = 1;
            if (allowMoveOnEdgeLine) {
                column = model.getLineMinColumn(lineNumber);
            }
            else {
                column = Std.int(Math.min(model.getLineMaxColumn(lineNumber), column));
            }
        }
        else if (lineNumber > lineCount) {
            lineNumber = lineCount;
            if (allowMoveOnEdgeLine) {
                column = model.getLineMaxColumn(lineNumber);
            }
            else {
                column = Std.int(Math.min(model.getLineMaxColumn(lineNumber), column));
            }
        }
        else {
            column = config.columnFromVisibleColumn(model, lineNumber, currentVisibleColumn);
        }

        if (wasAtEdgePosition) {
            leftoverVisibleColumns = 0;
        }
        else {
            leftoverVisibleColumns = currentVisibleColumn - CursorColumns.visibleColumnFromColumn(model.getLineContent(lineNumber), column, config.tabSize);
        }

        if (normalizationAffinity != null) {
            final position = new Position(lineNumber, column);
            final newPosition = model.normalizePosition(position, normalizationAffinity);
            leftoverVisibleColumns = leftoverVisibleColumns + (column - newPosition.column);
            lineNumber = newPosition.lineNumber;
            column = newPosition.column;
        }
        return new CursorPosition(lineNumber, column, leftoverVisibleColumns);
    }

    public static function down(config:CursorConfiguration, model:ICursorSimpleModel, lineNumber:Int, column:Int, leftoverVisibleColumns:Int, count:Int, allowMoveOnLastLine:Bool):CursorPosition {
        return vertical(config, model, lineNumber, column, leftoverVisibleColumns, lineNumber + count, allowMoveOnLastLine, PositionAffinity.RightOfInjectedText);
    }

    public static function moveDown(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool, linesCount:Int):SingleCursorState {
        var lineNumber:Int;
        var column:Int;

        if (cursor.hasSelection() && !inSelectionMode) {
            // If we are in selection mode, move down acts relative to the end of selection
            lineNumber = cursor.selection.endLineNumber;
            column = cursor.selection.endColumn;
        }
        else {
            lineNumber = cursor.position.lineNumber;
            column = cursor.position.column;
        }

        var i = 0;
        var r:CursorPosition;
        do {
            r = MoveOperations.down(config, model, lineNumber + i, column, cursor.leftoverVisibleColumns, linesCount, true);
            final np = model.normalizePosition(new Position(r.lineNumber, r.column), PositionAffinity.None);
            if (np.lineNumber > lineNumber) {
                break;
            }
        } while (i++ < 10 && lineNumber + i < model.getLineCount());

        return cursor.move(inSelectionMode, r.lineNumber, r.column, r.leftoverVisibleColumns);
    }

    public static function translateDown(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState):SingleCursorState {
        final selection = cursor.selection;

        final selectionStart = MoveOperations.down(config, model, selection.selectionStartLineNumber, selection.selectionStartColumn, cursor.selectionStartLeftoverVisibleColumns, 1, false);
        final position = MoveOperations.down(config, model, selection.positionLineNumber, selection.positionColumn, cursor.leftoverVisibleColumns, 1, false);

        return new SingleCursorState(
            new Range(selectionStart.lineNumber, selectionStart.column, selectionStart.lineNumber, selectionStart.column),
            SelectionStartKind.Simple,
            selectionStart.leftoverVisibleColumns,
            new Position(position.lineNumber, position.column),
            position.leftoverVisibleColumns
        );
    }

    public static function up(config:CursorConfiguration, model:ICursorSimpleModel, lineNumber:Int, column:Int, leftoverVisibleColumns:Int, count:Int, allowMoveOnFirstLine:Bool):CursorPosition {
        return vertical(config, model, lineNumber, column, leftoverVisibleColumns, lineNumber - count, allowMoveOnFirstLine, PositionAffinity.LeftOfInjectedText);
    }

    public static function moveUp(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool, linesCount:Int):SingleCursorState {
        var lineNumber:Int;
        var column:Int;

        if (cursor.hasSelection() && !inSelectionMode) {
            // If we are in selection mode, move up acts relative to the beginning of selection
            lineNumber = cursor.selection.startLineNumber;
            column = cursor.selection.startColumn;
        }
        else {
            lineNumber = cursor.position.lineNumber;
            column = cursor.position.column;
        }

        final r = MoveOperations.up(config, model, lineNumber, column, cursor.leftoverVisibleColumns, linesCount, true);

        return cursor.move(inSelectionMode, r.lineNumber, r.column, r.leftoverVisibleColumns);
    }

    public static function translateUp(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState):SingleCursorState {

        final selection = cursor.selection;

        final selectionStart = MoveOperations.up(config, model, selection.selectionStartLineNumber, selection.selectionStartColumn, cursor.selectionStartLeftoverVisibleColumns, 1, false);
        final position = MoveOperations.up(config, model, selection.positionLineNumber, selection.positionColumn, cursor.leftoverVisibleColumns, 1, false);

        return new SingleCursorState(
            new Range(selectionStart.lineNumber, selectionStart.column, selectionStart.lineNumber, selectionStart.column),
            SelectionStartKind.Simple,
            selectionStart.leftoverVisibleColumns,
            new Position(position.lineNumber, position.column),
            position.leftoverVisibleColumns
        );
    }

    static function _isBlankLine(model:ICursorSimpleModel, lineNumber:Int):Bool {
        if (model.getLineFirstNonWhitespaceColumn(lineNumber) == 0) {
            // empty or contains only whitespace
            return true;
        }
        return false;
    }

    public static function moveToPrevBlankLine(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool):SingleCursorState {
        var lineNumber = cursor.position.lineNumber;

        // If our current line is blank, move to the previous non-blank line
        while (lineNumber > 1 && _isBlankLine(model, lineNumber)) {
            lineNumber--;
        }

        // Find the previous blank line
        while (lineNumber > 1 && !_isBlankLine(model, lineNumber)) {
            lineNumber--;
        }

        return cursor.move(inSelectionMode, lineNumber, model.getLineMinColumn(lineNumber), 0);
    }

    public static function moveToNextBlankLine(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool):SingleCursorState {
        final lineCount = model.getLineCount();
        var lineNumber = cursor.position.lineNumber;

        // If our current line is blank, move to the next non-blank line
        while (lineNumber < lineCount && _isBlankLine(model, lineNumber)) {
            lineNumber++;
        }

        // Find the next blank line
        while (lineNumber < lineCount && !_isBlankLine(model, lineNumber)) {
            lineNumber++;
        }

        return cursor.move(inSelectionMode, lineNumber, model.getLineMinColumn(lineNumber), 0);
    }

    public static function moveToBeginningOfLine(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool):SingleCursorState {
        final lineNumber = cursor.position.lineNumber;
        final minColumn = model.getLineMinColumn(lineNumber);
        var firstNonBlankColumn = model.getLineFirstNonWhitespaceColumn(lineNumber);
        if (firstNonBlankColumn == 0) {
            firstNonBlankColumn = minColumn;
        }

        var column:Int;

        final relevantColumnNumber = cursor.position.column;
        if (relevantColumnNumber == firstNonBlankColumn) {
            column = minColumn;
        }
        else {
            column = firstNonBlankColumn;
        }

        return cursor.move(inSelectionMode, lineNumber, column, 0);
    }

    public static function moveToEndOfLine(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool, sticky:Bool):SingleCursorState {
        final lineNumber = cursor.position.lineNumber;
        final maxColumn = model.getLineMaxColumn(lineNumber);
        return cursor.move(inSelectionMode, lineNumber, maxColumn, sticky ? MAX_SAFE_SMALL_INTEGER - maxColumn : 0);
    }

    public static function moveToBeginningOfBuffer(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool):SingleCursorState {
        return cursor.move(inSelectionMode, 1, 1, 0);
    }

    public static function moveToEndOfBuffer(config:CursorConfiguration, model:ICursorSimpleModel, cursor:SingleCursorState, inSelectionMode:Bool):SingleCursorState {
        final lastLineNumber = model.getLineCount();
        final lastColumn = model.getLineMaxColumn(lastLineNumber);

        return cursor.move(inSelectionMode, lastLineNumber, lastColumn, 0);
    }

}

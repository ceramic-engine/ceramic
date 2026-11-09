// Ported from vscode src/vs/editor/common/cursor/cursorMoveCommands.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.base.common.JsValues;
import cityscape.common.CursorCommon;
import cityscape.common.ViewModel.IViewModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.cursor.CursorMoveOperations;
import cityscape.common.cursor.CursorWordOperations;
import cityscape.platform.commands.common.Commands.ICommandMetadata;

class CursorMoveCommands {

    public static function addCursorDown(viewModel:IViewModel, cursors:Array<CursorState>, useLogicalLine:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        var resultLen = 0;
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[resultLen++] = new CursorState(cursor.modelState, cursor.viewState);
            if (useLogicalLine) {
                result[resultLen++] = CursorState.fromModelState(MoveOperations.translateDown(viewModel.cursorConfig, viewModel.model, cursor.modelState));
            }
            else {
                result[resultLen++] = CursorState.fromViewState(MoveOperations.translateDown(viewModel.cursorConfig, viewModel, cursor.viewState));
            }
        }
        return result;
    }

    public static function addCursorUp(viewModel:IViewModel, cursors:Array<CursorState>, useLogicalLine:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        var resultLen = 0;
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[resultLen++] = new CursorState(cursor.modelState, cursor.viewState);
            if (useLogicalLine) {
                result[resultLen++] = CursorState.fromModelState(MoveOperations.translateUp(viewModel.cursorConfig, viewModel.model, cursor.modelState));
            }
            else {
                result[resultLen++] = CursorState.fromViewState(MoveOperations.translateUp(viewModel.cursorConfig, viewModel, cursor.viewState));
            }
        }
        return result;
    }

    public static function moveToBeginningOfLine(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[i] = _moveToLineStart(viewModel, cursor, inSelectionMode);
        }

        return result;
    }

    static function _moveToLineStart(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool):PartialCursorState {
        final currentViewStateColumn = cursor.viewState.position.column;
        final currentModelStateColumn = cursor.modelState.position.column;
        final isFirstLineOfWrappedLine = currentViewStateColumn == currentModelStateColumn;

        final currentViewStatelineNumber = cursor.viewState.position.lineNumber;
        final firstNonBlankColumn = viewModel.getLineFirstNonWhitespaceColumn(currentViewStatelineNumber);
        final isBeginningOfViewLine = currentViewStateColumn == firstNonBlankColumn;

        if (!isFirstLineOfWrappedLine && !isBeginningOfViewLine) {
            return _moveToLineStartByView(viewModel, cursor, inSelectionMode);
        }
        else {
            return _moveToLineStartByModel(viewModel, cursor, inSelectionMode);
        }
    }

    static function _moveToLineStartByView(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool):PartialCursorState {
        return CursorState.fromViewState(
            MoveOperations.moveToBeginningOfLine(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode)
        );
    }

    static function _moveToLineStartByModel(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool):PartialCursorState {
        return CursorState.fromModelState(
            MoveOperations.moveToBeginningOfLine(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode)
        );
    }

    public static function moveToEndOfLine(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool, sticky:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[i] = _moveToLineEnd(viewModel, cursor, inSelectionMode, sticky);
        }

        return result;
    }

    static function _moveToLineEnd(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool, sticky:Bool):PartialCursorState {
        final viewStatePosition = cursor.viewState.position;
        final viewModelMaxColumn = viewModel.getLineMaxColumn(viewStatePosition.lineNumber);
        final isEndOfViewLine = viewStatePosition.column == viewModelMaxColumn;

        final modelStatePosition = cursor.modelState.position;
        final modelMaxColumn = viewModel.model.getLineMaxColumn(modelStatePosition.lineNumber);
        final isEndLineOfWrappedLine = viewModelMaxColumn - viewStatePosition.column == modelMaxColumn - modelStatePosition.column;

        if (isEndOfViewLine || isEndLineOfWrappedLine) {
            return _moveToLineEndByModel(viewModel, cursor, inSelectionMode, sticky);
        }
        else {
            return _moveToLineEndByView(viewModel, cursor, inSelectionMode, sticky);
        }
    }

    static function _moveToLineEndByView(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool, sticky:Bool):PartialCursorState {
        return CursorState.fromViewState(
            MoveOperations.moveToEndOfLine(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode, sticky)
        );
    }

    static function _moveToLineEndByModel(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool, sticky:Bool):PartialCursorState {
        return CursorState.fromModelState(
            MoveOperations.moveToEndOfLine(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode, sticky)
        );
    }

    public static function expandLineSelection(viewModel:IViewModel, cursors:Array<CursorState>):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];

            final startLineNumber = cursor.modelState.selection.startLineNumber;
            final lineCount = viewModel.model.getLineCount();

            var endLineNumber = cursor.modelState.selection.endLineNumber;
            var endColumn:Int;
            if (endLineNumber == lineCount) {
                endColumn = viewModel.model.getLineMaxColumn(lineCount);
            }
            else {
                endLineNumber++;
                endColumn = 1;
            }

            result[i] = CursorState.fromModelState(new SingleCursorState(
                new Range(startLineNumber, 1, startLineNumber, 1), SelectionStartKind.Simple, 0,
                new Position(endLineNumber, endColumn), 0
            ));
        }
        return result;
    }

    public static function moveToBeginningOfBuffer(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[i] = CursorState.fromModelState(MoveOperations.moveToBeginningOfBuffer(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode));
        }
        return result;
    }

    public static function moveToEndOfBuffer(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[i] = CursorState.fromModelState(MoveOperations.moveToEndOfBuffer(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode));
        }
        return result;
    }

    public static function selectAll(viewModel:IViewModel, cursor:CursorState):PartialCursorState {
        final lineCount = viewModel.model.getLineCount();
        final maxColumn = viewModel.model.getLineMaxColumn(lineCount);

        return CursorState.fromModelState(new SingleCursorState(
            new Range(1, 1, 1, 1), SelectionStartKind.Simple, 0,
            new Position(lineCount, maxColumn), 0
        ));
    }

    public static function line(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool, _position:IPosition, _viewPosition:Null<IPosition>):PartialCursorState {
        final position = viewModel.model.validatePosition(_position);
        final viewPosition = (
            _viewPosition != null
                ? viewModel.coordinatesConverter.validateViewPosition(new Position(_viewPosition.lineNumber, _viewPosition.column), position)
                : viewModel.coordinatesConverter.convertModelPositionToViewPosition(position)
        );

        if (!inSelectionMode) {
            // Entering line selection for the first time
            final lineCount = viewModel.model.getLineCount();

            var selectToLineNumber = position.lineNumber + 1;
            var selectToColumn = 1;
            if (selectToLineNumber > lineCount) {
                selectToLineNumber = lineCount;
                selectToColumn = viewModel.model.getLineMaxColumn(selectToLineNumber);
            }

            return CursorState.fromModelState(new SingleCursorState(
                new Range(position.lineNumber, 1, selectToLineNumber, selectToColumn), SelectionStartKind.Line, 0,
                new Position(selectToLineNumber, selectToColumn), 0
            ));
        }

        // Continuing line selection
        final enteringLineNumber = cursor.modelState.selectionStart.getStartPosition().lineNumber;

        if (position.lineNumber < enteringLineNumber) {

            return CursorState.fromViewState(cursor.viewState.move(
                true, viewPosition.lineNumber, 1, 0
            ));

        }
        else if (position.lineNumber > enteringLineNumber) {

            final lineCount = viewModel.getLineCount();

            var selectToViewLineNumber = viewPosition.lineNumber + 1;
            var selectToViewColumn = 1;
            if (selectToViewLineNumber > lineCount) {
                selectToViewLineNumber = lineCount;
                selectToViewColumn = viewModel.getLineMaxColumn(selectToViewLineNumber);
            }

            return CursorState.fromViewState(cursor.viewState.move(
                true, selectToViewLineNumber, selectToViewColumn, 0
            ));

        }
        else {

            final endPositionOfSelectionStart = cursor.modelState.selectionStart.getEndPosition();
            return CursorState.fromModelState(cursor.modelState.move(
                true, endPositionOfSelectionStart.lineNumber, endPositionOfSelectionStart.column, 0
            ));

        }
    }

    public static function word(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool, _position:IPosition):PartialCursorState {
        final position = viewModel.model.validatePosition(_position);
        return CursorState.fromModelState(WordOperations.word(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode, position));
    }

    public static function cancelSelection(viewModel:IViewModel, cursor:CursorState):PartialCursorState {
        if (!cursor.modelState.hasSelection()) {
            return new CursorState(cursor.modelState, cursor.viewState);
        }

        final lineNumber = cursor.viewState.position.lineNumber;
        final column = cursor.viewState.position.column;

        return CursorState.fromViewState(new SingleCursorState(
            new Range(lineNumber, column, lineNumber, column), SelectionStartKind.Simple, 0,
            new Position(lineNumber, column), 0
        ));
    }

    public static function moveTo(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool, _position:IPosition, _viewPosition:Null<IPosition>):PartialCursorState {
        if (inSelectionMode) {
            if (cursor.modelState.selectionStartKind == SelectionStartKind.Word) {
                return word(viewModel, cursor, inSelectionMode, _position);
            }
            if (cursor.modelState.selectionStartKind == SelectionStartKind.Line) {
                return line(viewModel, cursor, inSelectionMode, _position, _viewPosition);
            }
        }
        final position = viewModel.model.validatePosition(_position);
        final viewPosition = (
            _viewPosition != null
                ? viewModel.coordinatesConverter.validateViewPosition(new Position(_viewPosition.lineNumber, _viewPosition.column), position)
                : viewModel.coordinatesConverter.convertModelPositionToViewPosition(position)
        );
        return CursorState.fromViewState(cursor.viewState.move(inSelectionMode, viewPosition.lineNumber, viewPosition.column, 0));
    }

    public static function simpleMove(viewModel:IViewModel, cursors:Array<CursorState>, direction:CursorMoveDirection, inSelectionMode:Bool, value:Int, unit:CursorMoveUnit):Null<Array<PartialCursorState>> {
        switch (direction) {
            case CursorMoveDirection.Left: {
                if (unit == CursorMoveUnit.HalfLine) {
                    // Move left by half the current line length
                    return _moveHalfLineLeft(viewModel, cursors, inSelectionMode);
                }
                else {
                    // Move left by `moveParams.value` columns
                    return _moveLeft(viewModel, cursors, inSelectionMode, value);
                }
            }
            case CursorMoveDirection.Right: {
                if (unit == CursorMoveUnit.HalfLine) {
                    // Move right by half the current line length
                    return _moveHalfLineRight(viewModel, cursors, inSelectionMode);
                }
                else {
                    // Move right by `moveParams.value` columns
                    return _moveRight(viewModel, cursors, inSelectionMode, value);
                }
            }
            case CursorMoveDirection.Up: {
                if (unit == CursorMoveUnit.WrappedLine) {
                    // Move up by view lines
                    return _moveUpByViewLines(viewModel, cursors, inSelectionMode, value);
                }
                else {
                    // Move up by model lines
                    return _moveUpByModelLines(viewModel, cursors, inSelectionMode, value);
                }
            }
            case CursorMoveDirection.Down: {
                if (unit == CursorMoveUnit.WrappedLine) {
                    // Move down by view lines
                    return _moveDownByViewLines(viewModel, cursors, inSelectionMode, value);
                }
                else {
                    // Move down by model lines
                    return _moveDownByModelLines(viewModel, cursors, inSelectionMode, value);
                }
            }
            case CursorMoveDirection.PrevBlankLine: {
                if (unit == CursorMoveUnit.WrappedLine) {
                    return [for (cursor in cursors) (CursorState.fromViewState(MoveOperations.moveToPrevBlankLine(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode)) : PartialCursorState)];
                }
                else {
                    return [for (cursor in cursors) (CursorState.fromModelState(MoveOperations.moveToPrevBlankLine(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode)) : PartialCursorState)];
                }
            }
            case CursorMoveDirection.NextBlankLine: {
                if (unit == CursorMoveUnit.WrappedLine) {
                    return [for (cursor in cursors) (CursorState.fromViewState(MoveOperations.moveToNextBlankLine(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode)) : PartialCursorState)];
                }
                else {
                    return [for (cursor in cursors) (CursorState.fromModelState(MoveOperations.moveToNextBlankLine(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode)) : PartialCursorState)];
                }
            }
            case CursorMoveDirection.WrappedLineStart: {
                // Move to the beginning of the current view line
                return _moveToViewMinColumn(viewModel, cursors, inSelectionMode);
            }
            case CursorMoveDirection.WrappedLineFirstNonWhitespaceCharacter: {
                // Move to the first non-whitespace column of the current view line
                return _moveToViewFirstNonWhitespaceColumn(viewModel, cursors, inSelectionMode);
            }
            case CursorMoveDirection.WrappedLineColumnCenter: {
                // Move to the "center" of the current view line
                return _moveToViewCenterColumn(viewModel, cursors, inSelectionMode);
            }
            case CursorMoveDirection.WrappedLineEnd: {
                // Move to the end of the current view line
                return _moveToViewMaxColumn(viewModel, cursors, inSelectionMode);
            }
            case CursorMoveDirection.WrappedLineLastNonWhitespaceCharacter: {
                // Move to the last non-whitespace column of the current view line
                return _moveToViewLastNonWhitespaceColumn(viewModel, cursors, inSelectionMode);
            }
            default:
                return null;
        }

    }

    public static function viewportMove(viewModel:IViewModel, cursors:Array<CursorState>, direction:CursorMoveDirection, inSelectionMode:Bool, value:Int):Null<Array<PartialCursorState>> {
        final visibleViewRange = viewModel.getCompletelyVisibleViewRange();
        final visibleModelRange = viewModel.coordinatesConverter.convertViewRangeToModelRange(visibleViewRange);
        switch (direction) {
            case CursorMoveDirection.ViewPortTop: {
                // Move to the nth line start in the viewport (from the top)
                final modelLineNumber = _firstLineNumberInRange(viewModel.model, visibleModelRange, value);
                final modelColumn = viewModel.model.getLineFirstNonWhitespaceColumn(modelLineNumber);
                return [_moveToModelPosition(viewModel, cursors[0], inSelectionMode, modelLineNumber, modelColumn)];
            }
            case CursorMoveDirection.ViewPortBottom: {
                // Move to the nth line start in the viewport (from the bottom)
                final modelLineNumber = _lastLineNumberInRange(viewModel.model, visibleModelRange, value);
                final modelColumn = viewModel.model.getLineFirstNonWhitespaceColumn(modelLineNumber);
                return [_moveToModelPosition(viewModel, cursors[0], inSelectionMode, modelLineNumber, modelColumn)];
            }
            case CursorMoveDirection.ViewPortCenter: {
                // Move to the line start in the viewport center
                final modelLineNumber = Math.round((visibleModelRange.startLineNumber + visibleModelRange.endLineNumber) / 2);
                final modelColumn = viewModel.model.getLineFirstNonWhitespaceColumn(modelLineNumber);
                return [_moveToModelPosition(viewModel, cursors[0], inSelectionMode, modelLineNumber, modelColumn)];
            }
            case CursorMoveDirection.ViewPortIfOutside: {
                // Move to a position inside the viewport
                final result:Array<PartialCursorState> = [];
                for (i in 0...cursors.length) {
                    final cursor = cursors[i];
                    result[i] = findPositionInViewportIfOutside(viewModel, cursor, visibleViewRange, inSelectionMode);
                }
                return result;
            }
            default:
                return null;
        }
    }

    public static function findPositionInViewportIfOutside(viewModel:IViewModel, cursor:CursorState, visibleViewRange:Range, inSelectionMode:Bool):PartialCursorState {
        final viewLineNumber = cursor.viewState.position.lineNumber;

        if (visibleViewRange.startLineNumber <= viewLineNumber && viewLineNumber <= visibleViewRange.endLineNumber - 1) {
            // Nothing to do, cursor is in viewport
            return new CursorState(cursor.modelState, cursor.viewState);

        }
        else {
            var newViewLineNumber:Int;
            if (viewLineNumber > visibleViewRange.endLineNumber - 1) {
                newViewLineNumber = visibleViewRange.endLineNumber - 1;
            }
            else if (viewLineNumber < visibleViewRange.startLineNumber) {
                newViewLineNumber = visibleViewRange.startLineNumber;
            }
            else {
                newViewLineNumber = viewLineNumber;
            }
            final position = MoveOperations.vertical(viewModel.cursorConfig, viewModel, viewLineNumber, cursor.viewState.position.column, cursor.viewState.leftoverVisibleColumns, newViewLineNumber, false);
            return CursorState.fromViewState(cursor.viewState.move(inSelectionMode, position.lineNumber, position.column, position.leftoverVisibleColumns));
        }
    }

    /**
     * Find the nth line start included in the range (from the start).
     */
    static function _firstLineNumberInRange(model:ICursorSimpleModel, range:Range, count:Int):Int {
        var startLineNumber = range.startLineNumber;
        if (range.startColumn != model.getLineMinColumn(startLineNumber)) {
            // Move on to the second line if the first line start is not included in the range
            startLineNumber++;
        }

        return Std.int(Math.min(range.endLineNumber, startLineNumber + count - 1));
    }

    /**
     * Find the nth line start included in the range (from the end).
     */
    static function _lastLineNumberInRange(model:ICursorSimpleModel, range:Range, count:Int):Int {
        var startLineNumber = range.startLineNumber;
        if (range.startColumn != model.getLineMinColumn(startLineNumber)) {
            // Move on to the second line if the first line start is not included in the range
            startLineNumber++;
        }

        return Std.int(Math.max(startLineNumber, range.endLineNumber - count + 1));
    }

    static function _moveLeft(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool, noOfColumns:Int):Array<PartialCursorState> {
        return [for (cursor in cursors) (
            CursorState.fromViewState(
                MoveOperations.moveLeft(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode, noOfColumns)
            ) : PartialCursorState
        )];
    }

    static function _moveHalfLineLeft(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final viewLineNumber = cursor.viewState.position.lineNumber;
            final halfLine = Math.round(viewModel.getLineLength(viewLineNumber) / 2);
            result[i] = CursorState.fromViewState(MoveOperations.moveLeft(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode, halfLine));
        }
        return result;
    }

    static function _moveRight(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool, noOfColumns:Int):Array<PartialCursorState> {
        return [for (cursor in cursors) (
            CursorState.fromViewState(
                MoveOperations.moveRight(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode, noOfColumns)
            ) : PartialCursorState
        )];
    }

    static function _moveHalfLineRight(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final viewLineNumber = cursor.viewState.position.lineNumber;
            final halfLine = Math.round(viewModel.getLineLength(viewLineNumber) / 2);
            result[i] = CursorState.fromViewState(MoveOperations.moveRight(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode, halfLine));
        }
        return result;
    }

    static function _moveDownByViewLines(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool, linesCount:Int):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[i] = CursorState.fromViewState(MoveOperations.moveDown(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode, linesCount));
        }
        return result;
    }

    static function _moveDownByModelLines(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool, linesCount:Int):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[i] = CursorState.fromModelState(MoveOperations.moveDown(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode, linesCount));
        }
        return result;
    }

    static function _moveUpByViewLines(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool, linesCount:Int):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[i] = CursorState.fromViewState(MoveOperations.moveUp(viewModel.cursorConfig, viewModel, cursor.viewState, inSelectionMode, linesCount));
        }
        return result;
    }

    static function _moveUpByModelLines(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool, linesCount:Int):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            result[i] = CursorState.fromModelState(MoveOperations.moveUp(viewModel.cursorConfig, viewModel.model, cursor.modelState, inSelectionMode, linesCount));
        }
        return result;
    }

    static function _moveToViewPosition(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool, toViewLineNumber:Int, toViewColumn:Int):PartialCursorState {
        return CursorState.fromViewState(cursor.viewState.move(inSelectionMode, toViewLineNumber, toViewColumn, 0));
    }

    static function _moveToModelPosition(viewModel:IViewModel, cursor:CursorState, inSelectionMode:Bool, toModelLineNumber:Int, toModelColumn:Int):PartialCursorState {
        return CursorState.fromModelState(cursor.modelState.move(inSelectionMode, toModelLineNumber, toModelColumn, 0));
    }

    static function _moveToViewMinColumn(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final viewLineNumber = cursor.viewState.position.lineNumber;
            final viewColumn = viewModel.getLineMinColumn(viewLineNumber);
            result[i] = _moveToViewPosition(viewModel, cursor, inSelectionMode, viewLineNumber, viewColumn);
        }
        return result;
    }

    static function _moveToViewFirstNonWhitespaceColumn(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final viewLineNumber = cursor.viewState.position.lineNumber;
            final viewColumn = viewModel.getLineFirstNonWhitespaceColumn(viewLineNumber);
            result[i] = _moveToViewPosition(viewModel, cursor, inSelectionMode, viewLineNumber, viewColumn);
        }
        return result;
    }

    static function _moveToViewCenterColumn(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final viewLineNumber = cursor.viewState.position.lineNumber;
            final viewColumn = Math.round((viewModel.getLineMaxColumn(viewLineNumber) + viewModel.getLineMinColumn(viewLineNumber)) / 2);
            result[i] = _moveToViewPosition(viewModel, cursor, inSelectionMode, viewLineNumber, viewColumn);
        }
        return result;
    }

    static function _moveToViewMaxColumn(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final viewLineNumber = cursor.viewState.position.lineNumber;
            final viewColumn = viewModel.getLineMaxColumn(viewLineNumber);
            result[i] = _moveToViewPosition(viewModel, cursor, inSelectionMode, viewLineNumber, viewColumn);
        }
        return result;
    }

    static function _moveToViewLastNonWhitespaceColumn(viewModel:IViewModel, cursors:Array<CursorState>, inSelectionMode:Bool):Array<PartialCursorState> {
        final result:Array<PartialCursorState> = [];
        for (i in 0...cursors.length) {
            final cursor = cursors[i];
            final viewLineNumber = cursor.viewState.position.lineNumber;
            final viewColumn = viewModel.getLineLastNonWhitespaceColumn(viewLineNumber);
            result[i] = _moveToViewPosition(viewModel, cursor, inSelectionMode, viewLineNumber, viewColumn);
        }
        return result;
    }

}

/**
 * Monaco's `CursorMove.Direction`.
 */
enum abstract CursorMoveDirection(Int) from Int to Int {
    var Left = 0;
    var Right = 1;
    var Up = 2;
    var Down = 3;
    var PrevBlankLine = 4;
    var NextBlankLine = 5;

    var WrappedLineStart = 6;
    var WrappedLineFirstNonWhitespaceCharacter = 7;
    var WrappedLineColumnCenter = 8;
    var WrappedLineEnd = 9;
    var WrappedLineLastNonWhitespaceCharacter = 10;

    var ViewPortTop = 11;
    var ViewPortCenter = 12;
    var ViewPortBottom = 13;

    var ViewPortIfOutside = 14;
}

/**
 * Monaco's `CursorMove.Unit`.
 */
enum abstract CursorMoveUnit(Int) from Int to Int {
    var None = 0;
    var Line = 1;
    var WrappedLine = 2;
    var Character = 3;
    var HalfLine = 4;
}

/**
 * Arguments for Cursor move command (Monaco's `CursorMove.RawArguments`;
 * every field is optional, like the `Partial<RawArguments>` of `parse`).
 */
typedef CursorMoveRawArguments = {
    @:optional var to:String;
    @:optional var select:Bool;
    @:optional var by:String;
    @:optional var value:Int;
}

typedef CursorMoveParsedArguments = {
    var direction:CursorMoveDirection;
    var unit:CursorMoveUnit;
    var select:Bool;
    var value:Int;
}

/**
 * Monaco's `CursorMove` namespace.
 */
class CursorMove {

    static function isCursorMoveArgs(arg:Any):Bool {
        if (!JsValues.isObject(arg)) {
            return false;
        }

        final to = JsValues.field(arg, 'to');
        if (!JsValues.isString(to)) {
            return false;
        }

        final select = JsValues.field(arg, 'select');
        if (!JsValues.isUndefined(select) && !JsValues.isBoolean(select)) {
            return false;
        }

        final by = JsValues.field(arg, 'by');
        if (!JsValues.isUndefined(by) && !JsValues.isString(by)) {
            return false;
        }

        final value = JsValues.field(arg, 'value');
        if (!JsValues.isUndefined(value) && !JsValues.isNumber(value)) {
            return false;
        }

        return true;
    }

    /**
     * Validates the argument of the cursorMove command (the `constraint` of
     * Monaco's metadata, which `ICommandMetadata` does not keep).
     */
    public static function isValidArgs(arg:Any):Bool {
        return isCursorMoveArgs(arg);
    }

    public static final metadata:ICommandMetadata = {
        description: 'Move cursor to a logical position in the view',
        args: [
            {
                name: 'Cursor move argument object',
                description: "Property-value pairs that can be passed through this argument:
					* 'to': A mandatory logical position value providing where to move the cursor.
						```
						'left', 'right', 'up', 'down', 'prevBlankLine', 'nextBlankLine',
						'wrappedLineStart', 'wrappedLineEnd', 'wrappedLineColumnCenter'
						'wrappedLineFirstNonWhitespaceCharacter', 'wrappedLineLastNonWhitespaceCharacter'
						'viewPortTop', 'viewPortCenter', 'viewPortBottom', 'viewPortIfOutside'
						```
					* 'by': Unit to move. Default is computed based on 'to' value.
						```
						'line', 'wrappedLine', 'character', 'halfLine'
						```
					* 'value': Number of units to move. Default is '1'.
					* 'select': If 'true' makes the selection. Default is 'false'.
				"
            }
        ]
    };

    /**
     * Positions in the view for cursor move command.
     */
    public static final RawDirection = {
        Left: 'left',
        Right: 'right',
        Up: 'up',
        Down: 'down',

        PrevBlankLine: 'prevBlankLine',
        NextBlankLine: 'nextBlankLine',

        WrappedLineStart: 'wrappedLineStart',
        WrappedLineFirstNonWhitespaceCharacter: 'wrappedLineFirstNonWhitespaceCharacter',
        WrappedLineColumnCenter: 'wrappedLineColumnCenter',
        WrappedLineEnd: 'wrappedLineEnd',
        WrappedLineLastNonWhitespaceCharacter: 'wrappedLineLastNonWhitespaceCharacter',

        ViewPortTop: 'viewPortTop',
        ViewPortCenter: 'viewPortCenter',
        ViewPortBottom: 'viewPortBottom',

        ViewPortIfOutside: 'viewPortIfOutside'
    };

    /**
     * Units for Cursor move 'by' argument
     */
    public static final RawUnit = {
        Line: 'line',
        WrappedLine: 'wrappedLine',
        Character: 'character',
        HalfLine: 'halfLine'
    };

    public static function parse(args:CursorMoveRawArguments):Null<CursorMoveParsedArguments> {
        if (args.to == null || args.to.length == 0) {
            // illegal arguments
            return null;
        }

        var direction:CursorMoveDirection;
        switch (args.to) {
            case 'left':
                direction = CursorMoveDirection.Left;
            case 'right':
                direction = CursorMoveDirection.Right;
            case 'up':
                direction = CursorMoveDirection.Up;
            case 'down':
                direction = CursorMoveDirection.Down;
            case 'prevBlankLine':
                direction = CursorMoveDirection.PrevBlankLine;
            case 'nextBlankLine':
                direction = CursorMoveDirection.NextBlankLine;
            case 'wrappedLineStart':
                direction = CursorMoveDirection.WrappedLineStart;
            case 'wrappedLineFirstNonWhitespaceCharacter':
                direction = CursorMoveDirection.WrappedLineFirstNonWhitespaceCharacter;
            case 'wrappedLineColumnCenter':
                direction = CursorMoveDirection.WrappedLineColumnCenter;
            case 'wrappedLineEnd':
                direction = CursorMoveDirection.WrappedLineEnd;
            case 'wrappedLineLastNonWhitespaceCharacter':
                direction = CursorMoveDirection.WrappedLineLastNonWhitespaceCharacter;
            case 'viewPortTop':
                direction = CursorMoveDirection.ViewPortTop;
            case 'viewPortBottom':
                direction = CursorMoveDirection.ViewPortBottom;
            case 'viewPortCenter':
                direction = CursorMoveDirection.ViewPortCenter;
            case 'viewPortIfOutside':
                direction = CursorMoveDirection.ViewPortIfOutside;
            default:
                // illegal arguments
                return null;
        }

        var unit = CursorMoveUnit.None;
        switch (args.by) {
            case 'line':
                unit = CursorMoveUnit.Line;
            case 'wrappedLine':
                unit = CursorMoveUnit.WrappedLine;
            case 'character':
                unit = CursorMoveUnit.Character;
            case 'halfLine':
                unit = CursorMoveUnit.HalfLine;
            case _:
        }

        return {
            direction: direction,
            unit: unit,
            select: (args.select == true),
            value: (args.value == null || args.value == 0 ? 1 : args.value)
        };
    }

}

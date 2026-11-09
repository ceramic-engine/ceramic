// Ported from vscode src/vs/editor/common/cursor/oneCursor.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.common.CursorCommon;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.Model.TrackedRangeStickiness;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

/**
 * Represents a single cursor.
 */
class Cursor {

    public var modelState:SingleCursorState;
    public var viewState:SingleCursorState;

    var _selTrackedRange:Null<String>;
    var _trackSelection:Bool;

    public function new(context:CursorContext) {
        this._selTrackedRange = null;
        this._trackSelection = true;

        this._setState(
            context,
            new SingleCursorState(new Range(1, 1, 1, 1), SelectionStartKind.Simple, 0, new Position(1, 1), 0),
            new SingleCursorState(new Range(1, 1, 1, 1), SelectionStartKind.Simple, 0, new Position(1, 1), 0)
        );
    }

    public function dispose(context:CursorContext):Void {
        this._removeTrackedRange(context);
    }

    public function startTrackingSelection(context:CursorContext):Void {
        this._trackSelection = true;
        this._updateTrackedRange(context);
    }

    public function stopTrackingSelection(context:CursorContext):Void {
        this._trackSelection = false;
        this._removeTrackedRange(context);
    }

    function _updateTrackedRange(context:CursorContext):Void {
        if (!this._trackSelection) {
            // don't track the selection
            return;
        }
        this._selTrackedRange = context.model._setTrackedRange(this._selTrackedRange, this.modelState.selection, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges);
    }

    function _removeTrackedRange(context:CursorContext):Void {
        this._selTrackedRange = context.model._setTrackedRange(this._selTrackedRange, null, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges);
    }

    public function asCursorState():CursorState {
        return new CursorState(this.modelState, this.viewState);
    }

    public function readSelectionFromMarkers(context:CursorContext):Selection {
        final range = context.model._getTrackedRange(this._selTrackedRange);

        if (this.modelState.selection.isEmpty() && !range.isEmpty()) {
            // Avoid selecting text when recovering from markers
            return Selection.fromRange(range.collapseToEnd(), this.modelState.selection.getDirection());
        }

        return Selection.fromRange(range, this.modelState.selection.getDirection());
    }

    public function ensureValidState(context:CursorContext):Void {
        this._setState(context, this.modelState, this.viewState);
    }

    public function setState(context:CursorContext, modelState:Null<SingleCursorState>, viewState:Null<SingleCursorState>):Void {
        this._setState(context, modelState, viewState);
    }

    static function _validatePositionWithCache(viewModel:ICursorSimpleModel, position:Position, cacheInput:Position, cacheOutput:Position):Position {
        if (position.equals(cacheInput)) {
            return cacheOutput;
        }
        return viewModel.normalizePosition(position, PositionAffinity.None);
    }

    static function _validateViewState(viewModel:ICursorSimpleModel, viewState:SingleCursorState):SingleCursorState {
        final position = viewState.position;
        final sStartPosition = viewState.selectionStart.getStartPosition();
        final sEndPosition = viewState.selectionStart.getEndPosition();

        final validPosition = viewModel.normalizePosition(position, PositionAffinity.None);
        final validSStartPosition = _validatePositionWithCache(viewModel, sStartPosition, position, validPosition);
        final validSEndPosition = _validatePositionWithCache(viewModel, sEndPosition, sStartPosition, validSStartPosition);

        if (position.equals(validPosition) && sStartPosition.equals(validSStartPosition) && sEndPosition.equals(validSEndPosition)) {
            // fast path: the state is valid
            return viewState;
        }

        return new SingleCursorState(
            Range.fromPositions(validSStartPosition, validSEndPosition),
            viewState.selectionStartKind,
            viewState.selectionStartLeftoverVisibleColumns + sStartPosition.column - validSStartPosition.column,
            validPosition,
            viewState.leftoverVisibleColumns + position.column - validPosition.column
        );
    }

    function _setState(context:CursorContext, modelState:Null<SingleCursorState>, viewState:Null<SingleCursorState>):Void {
        if (viewState != null) {
            viewState = Cursor._validateViewState(context.viewModel, viewState);
        }

        if (modelState == null) {
            if (viewState == null) {
                return;
            }
            // We only have the view state => compute the model state
            final selectionStart = context.model.validateRange(
                context.coordinatesConverter.convertViewRangeToModelRange(viewState.selectionStart)
            );

            final position = context.model.validatePosition(
                context.coordinatesConverter.convertViewPositionToModelPosition(viewState.position)
            );

            modelState = new SingleCursorState(selectionStart, viewState.selectionStartKind, viewState.selectionStartLeftoverVisibleColumns, position, viewState.leftoverVisibleColumns);
        }
        else {
            // Validate new model state
            final selectionStart = context.model.validateRange(modelState.selectionStart);
            final selectionStartLeftoverVisibleColumns = modelState.selectionStart.equalsRange(selectionStart) ? modelState.selectionStartLeftoverVisibleColumns : 0;

            final position = context.model.validatePosition(
                modelState.position
            );
            final leftoverVisibleColumns = modelState.position.equals(position) ? modelState.leftoverVisibleColumns : 0;

            modelState = new SingleCursorState(selectionStart, modelState.selectionStartKind, selectionStartLeftoverVisibleColumns, position, leftoverVisibleColumns);
        }

        if (viewState == null) {
            // We only have the model state => compute the view state
            final viewSelectionStart1 = context.coordinatesConverter.convertModelPositionToViewPosition(new Position(modelState.selectionStart.startLineNumber, modelState.selectionStart.startColumn));
            final viewSelectionStart2 = context.coordinatesConverter.convertModelPositionToViewPosition(new Position(modelState.selectionStart.endLineNumber, modelState.selectionStart.endColumn));
            final viewSelectionStart = new Range(viewSelectionStart1.lineNumber, viewSelectionStart1.column, viewSelectionStart2.lineNumber, viewSelectionStart2.column);
            final viewPosition = context.coordinatesConverter.convertModelPositionToViewPosition(modelState.position);
            viewState = new SingleCursorState(viewSelectionStart, modelState.selectionStartKind, modelState.selectionStartLeftoverVisibleColumns, viewPosition, modelState.leftoverVisibleColumns);
        }
        else {
            // Validate new view state
            final viewSelectionStart = context.coordinatesConverter.validateViewRange(viewState.selectionStart, modelState.selectionStart);
            final viewPosition = context.coordinatesConverter.validateViewPosition(viewState.position, modelState.position);
            viewState = new SingleCursorState(viewSelectionStart, modelState.selectionStartKind, modelState.selectionStartLeftoverVisibleColumns, viewPosition, modelState.leftoverVisibleColumns);
        }

        this.modelState = modelState;
        this.viewState = viewState;

        this._updateTrackedRange(context);
    }

}

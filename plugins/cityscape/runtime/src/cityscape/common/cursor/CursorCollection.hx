// Ported from vscode src/vs/editor/common/cursor/cursorCollection.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.common.CursorCommon;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.OneCursor.Cursor;

private class SortedCursor {

    public var index:Int;
    public var selection:Selection;

    public function new(index:Int, selection:Selection) {
        this.index = index;
        this.selection = selection;
    }

}

class CursorCollection {

    var context:CursorContext;

    /**
     * `cursors[0]` is the primary cursor, thus `cursors.length >= 1` is always true.
     * `cursors.slice(1)` are secondary cursors.
     */
    var cursors:Array<Cursor>;

    // An index which identifies the last cursor that was added / moved (think Ctrl+drag)
    // This index refers to `cursors.slice(1)`, i.e. after removing the primary cursor.
    var lastAddedCursorIndex:Int;

    public function new(context:CursorContext) {
        this.context = context;
        this.cursors = [new Cursor(context)];
        this.lastAddedCursorIndex = 0;
    }

    public function dispose():Void {
        for (cursor in this.cursors) {
            cursor.dispose(this.context);
        }
    }

    public function startTrackingSelections():Void {
        for (cursor in this.cursors) {
            cursor.startTrackingSelection(this.context);
        }
    }

    public function stopTrackingSelections():Void {
        for (cursor in this.cursors) {
            cursor.stopTrackingSelection(this.context);
        }
    }

    public function updateContext(context:CursorContext):Void {
        this.context = context;
    }

    public function ensureValidState():Void {
        for (cursor in this.cursors) {
            cursor.ensureValidState(this.context);
        }
    }

    public function readSelectionFromMarkers():Array<Selection> {
        return [for (c in this.cursors) c.readSelectionFromMarkers(this.context)];
    }

    public function getAll():Array<CursorState> {
        return [for (c in this.cursors) c.asCursorState()];
    }

    public function getViewPositions():Array<Position> {
        return [for (c in this.cursors) c.viewState.position];
    }

    public function getTopMostViewPosition():Position {
        // findFirstMin
        var result = this.cursors[0];
        for (i in 1...this.cursors.length) {
            final c = this.cursors[i];
            if (Position.compare(c.viewState.position, result.viewState.position) < 0) {
                result = c;
            }
        }
        return result.viewState.position;
    }

    public function getBottomMostViewPosition():Position {
        // findLastMax
        var result = this.cursors[0];
        for (i in 1...this.cursors.length) {
            final c = this.cursors[i];
            if (Position.compare(c.viewState.position, result.viewState.position) >= 0) {
                result = c;
            }
        }
        return result.viewState.position;
    }

    public function getSelections():Array<Selection> {
        return [for (c in this.cursors) c.modelState.selection];
    }

    public function getViewSelections():Array<Selection> {
        return [for (c in this.cursors) c.viewState.selection];
    }

    public function setSelections(selections:Array<Selection>):Void {
        this.setStates(CursorState.fromSelections(selections));
    }

    public function getPrimaryCursor():CursorState {
        return this.cursors[0].asCursorState();
    }

    public function setStates(states:Null<Array<PartialCursorState>>):Void {
        if (states == null) {
            return;
        }
        this.cursors[0].setState(this.context, states[0].modelState, states[0].viewState);
        this._setSecondaryStates(states.slice(1));
    }

    /**
     * Creates or disposes secondary cursors as necessary to match the number of `secondarySelections`.
     */
    function _setSecondaryStates(secondaryStates:Array<PartialCursorState>):Void {
        final secondaryCursorsLength = this.cursors.length - 1;
        final secondaryStatesLength = secondaryStates.length;

        if (secondaryCursorsLength < secondaryStatesLength) {
            final createCnt = secondaryStatesLength - secondaryCursorsLength;
            for (i in 0...createCnt) {
                this._addSecondaryCursor();
            }
        }
        else if (secondaryCursorsLength > secondaryStatesLength) {
            final removeCnt = secondaryCursorsLength - secondaryStatesLength;
            for (i in 0...removeCnt) {
                this._removeSecondaryCursor(this.cursors.length - 2);
            }
        }

        for (i in 0...secondaryStatesLength) {
            this.cursors[i + 1].setState(this.context, secondaryStates[i].modelState, secondaryStates[i].viewState);
        }
    }

    public function killSecondaryCursors():Void {
        this._setSecondaryStates([]);
    }

    function _addSecondaryCursor():Void {
        this.cursors.push(new Cursor(this.context));
        this.lastAddedCursorIndex = this.cursors.length - 1;
    }

    public function getLastAddedCursorIndex():Int {
        if (this.cursors.length == 1 || this.lastAddedCursorIndex == 0) {
            return 0;
        }
        return this.lastAddedCursorIndex;
    }

    function _removeSecondaryCursor(removeIndex:Int):Void {
        if (this.lastAddedCursorIndex >= removeIndex + 1) {
            this.lastAddedCursorIndex--;
        }
        this.cursors[removeIndex + 1].dispose(this.context);
        this.cursors.splice(removeIndex + 1, 1);
    }

    public function normalize():Void {
        if (this.cursors.length == 1) {
            return;
        }
        final cursors = this.cursors.slice(0);

        final sortedCursors:Array<SortedCursor> = [];
        for (i in 0...cursors.length) {
            sortedCursors.push(new SortedCursor(i, cursors[i].modelState.selection));
        }

        haxe.ds.ArraySort.sort(sortedCursors, (a, b) -> Range.compareRangesUsingStarts(a.selection, b.selection));

        var sortedCursorIndex = 0;
        while (sortedCursorIndex < sortedCursors.length - 1) {
            final current = sortedCursors[sortedCursorIndex];
            final next = sortedCursors[sortedCursorIndex + 1];

            final currentSelection = current.selection;
            final nextSelection = next.selection;

            if (!this.context.cursorConfig.multiCursorMergeOverlapping) {
                sortedCursorIndex++;
                continue;
            }

            var shouldMergeCursors:Bool;
            if (nextSelection.isEmpty() || currentSelection.isEmpty()) {
                // Merge touching cursors if one of them is collapsed
                shouldMergeCursors = nextSelection.getStartPosition().isBeforeOrEqual(currentSelection.getEndPosition());
            }
            else {
                // Merge only overlapping cursors (i.e. allow touching ranges)
                shouldMergeCursors = nextSelection.getStartPosition().isBefore(currentSelection.getEndPosition());
            }

            if (shouldMergeCursors) {
                final winnerSortedCursorIndex = current.index < next.index ? sortedCursorIndex : sortedCursorIndex + 1;
                final looserSortedCursorIndex = current.index < next.index ? sortedCursorIndex + 1 : sortedCursorIndex;

                final looserIndex = sortedCursors[looserSortedCursorIndex].index;
                final winnerIndex = sortedCursors[winnerSortedCursorIndex].index;

                final looserSelection = sortedCursors[looserSortedCursorIndex].selection;
                final winnerSelection = sortedCursors[winnerSortedCursorIndex].selection;

                if (!looserSelection.equalsSelection(winnerSelection)) {
                    final resultingRange = looserSelection.plusRange(winnerSelection);
                    final looserSelectionIsLTR = (looserSelection.selectionStartLineNumber == looserSelection.startLineNumber && looserSelection.selectionStartColumn == looserSelection.startColumn);
                    final winnerSelectionIsLTR = (winnerSelection.selectionStartLineNumber == winnerSelection.startLineNumber && winnerSelection.selectionStartColumn == winnerSelection.startColumn);

                    // Give more importance to the last added cursor (think Ctrl-dragging + hitting another cursor)
                    var resultingSelectionIsLTR:Bool;
                    if (looserIndex == this.lastAddedCursorIndex) {
                        resultingSelectionIsLTR = looserSelectionIsLTR;
                        this.lastAddedCursorIndex = winnerIndex;
                    }
                    else {
                        // Winner takes it all
                        resultingSelectionIsLTR = winnerSelectionIsLTR;
                    }

                    var resultingSelection:Selection;
                    if (resultingSelectionIsLTR) {
                        resultingSelection = new Selection(resultingRange.startLineNumber, resultingRange.startColumn, resultingRange.endLineNumber, resultingRange.endColumn);
                    }
                    else {
                        resultingSelection = new Selection(resultingRange.endLineNumber, resultingRange.endColumn, resultingRange.startLineNumber, resultingRange.startColumn);
                    }

                    sortedCursors[winnerSortedCursorIndex].selection = resultingSelection;
                    final resultingState = CursorState.fromModelSelection(resultingSelection);
                    cursors[winnerIndex].setState(this.context, resultingState.modelState, resultingState.viewState);
                }

                for (sortedCursor in sortedCursors) {
                    if (sortedCursor.index > looserIndex) {
                        sortedCursor.index--;
                    }
                }

                cursors.splice(looserIndex, 1);
                sortedCursors.splice(looserSortedCursorIndex, 1);
                this._removeSecondaryCursor(looserIndex - 1);

                sortedCursorIndex--;
            }
            sortedCursorIndex++;
        }
    }

}

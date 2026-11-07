// Ported from gpui-kit 0.8.1: crates/base/src/input/base/movement.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Context;
import gpui.Point;
import gpui.Window;
import gpui.base.input.InputActions;

using gpui.base.input.RopeExt;

/**
 * A cursor target and the line-end affinity the caret carries there (Rust
 * `(usize, bool)`).
 */
class CursorTarget {

    public final offset:Int;

    public final lineEndAffinity:Bool;

    public inline function new(offset:Int, lineEndAffinity:Bool) {
        this.offset = offset;
        this.lineEndAffinity = lineEndAffinity;
    }

}

/**
 * Where `moveAllCursors` puts one cursor (Rust
 * `(usize, Option<(Pixels, usize)>, bool)`).
 */
class CursorMove {

    public final offset:Int;

    public final anchor:Null<ColumnAnchor>;

    public final lineEndAffinity:Bool;

    public inline function new(offset:Int, anchor:Null<ColumnAnchor>, lineEndAffinity:Bool) {
        this.offset = offset;
        this.anchor = anchor;
        this.lineEndAffinity = lineEndAffinity;
    }

}

/**
 * Cursor movement of the input engine: the `impl InputBaseState` block of
 * movement.rs, as static extensions (`using gpui.base.input.InputMovement;`).
 */
class InputMovement {

    /** Compute the column anchor for the given `offset`. Wrap/fold-aware. */
    public static function preferredColumnFor(self:InputBaseState, offset:Int):Null<ColumnAnchor> {
        return preferredColumnForWithAffinity(self, offset, false);
    }

    /**
     * Like `preferredColumnFor`, but resolves an offset on a soft wrap
     * boundary to the row the caret is drawn on.
     */
    public static function preferredColumnForWithAffinity(self:InputBaseState, offset:Int, lineEndAffinity:Bool):Null<ColumnAnchor> {
        final lastLayout = self.lastLayout;
        if (lastLayout == null) return null;
        final point = self.text.offsetToPoint(offset);
        final line = lastLayout.line(point.row);
        if (line == null) return null;
        final pos = line.positionForIndex(point.column, lastLayout, lineEndAffinity);
        if (pos == null) return null;
        return new ColumnAnchor(pos.x, point.column);
    }

    /**
     * The line-end affinity that applies to `sel`. Only the active cursor
     * carries one; every other cursor sits at the start of its row.
     */
    public static function lineEndAffinityFor(self:InputBaseState, sel:CursorSelection):Bool {
        return sel.id == self.activeSelection().id && self.cursorLineEndAffinity;
    }

    /**
     * The line-end affinity for a cursor known only by its offset. Cursors
     * never share an offset, so this is the active cursor's affinity when
     * `offset` is where it sits.
     */
    public static function lineEndAffinityAt(self:InputBaseState, offset:Int):Bool {
        return offset == self.cursor() && self.cursorLineEndAffinity;
    }

    /**
     * Called after moving the cursor. Updates the active selection's
     * `columnAnchor` if we know where the cursor now is.
     */
    public static function updatePreferredColumn(self:InputBaseState):Void {
        final anchor = preferredColumnForWithAffinity(self, self.cursor(), self.cursorLineEndAffinity);
        self.activeSelectionMut().columnAnchor = anchor;
    }

    /**
     * Move the cursor to the given UTF-8 offset.
     *
     * Ensure the offset uses `nextBoundary` or `previousBoundary` to get the
     * correct offset.
     */
    public static function moveTo(self:InputBaseState, offset:Int, direction:Null<MoveDirection>, cx:Context<InputBaseState>):Void {
        moveToWithAffinity(self, offset, direction, false, cx);
    }

    /**
     * Like `moveTo`, but also carries the caret's line-end affinity.
     *
     * A soft wrap boundary is one offset shared by the end of one visual line
     * and the start of the next, so the offset alone cannot say where to draw
     * the caret. Callers that resolved the offset from a visual position (a
     * click, a drag, a vertical move) already know which of the two rows the
     * user meant, and pass it here. Taking it in the same call as the move is
     * what keeps the two from drifting apart.
     */
    public static function moveToWithAffinity(self:InputBaseState, offset:Int, direction:Null<MoveDirection>, lineEndAffinity:Bool,
            cx:Context<InputBaseState>):Void {
        self.undoManager.breakTransactionCoalescing();
        self.selections.removeAllButActive();
        final offset = self.cursorBoundary(offset, Bias.Left);
        self.cursorLineEndAffinity = lineEndAffinity;
        self.setCursorTo(offset);
        self.scrollTo(offset, direction, cx);
        self.pauseBlinkCursor(cx);
        updatePreferredColumn(self);
        self.modeKind.hideContextMenu(self, cx);
        self.modeKind.clearInlineCompletion(self, cx);
        cx.notify();
    }

    /**
     * Compute the target offset when moving a cursor at `offset` vertically
     * by `moveLines`, honoring the remembered `columnAnchor`. Wrap/fold-aware.
     *
     * Returns the new offset together with the line-end affinity the caret
     * should carry there.
     */
    public static function verticalTarget(self:InputBaseState, offset:Int, columnAnchor:Null<ColumnAnchor>, lineEndAffinity:Bool,
            moveLines:Int):CursorTarget {
        final lastLayout = self.lastLayout;
        if (lastLayout == null) {
            return new CursorTarget(offset, lineEndAffinity);
        }

        // Start from the row the caret is drawn on, not the row the raw offset
        // falls in: on a soft wrap boundary those are two different rows.
        final displayPoint = self.displayMap.offsetToWrapDisplayPointWithAffinity(offset, lineEndAffinity);

        // Convert wrap row to display row (skips folded rows), move, then convert back
        final displayRow = self.displayMap.wrapRowToDisplayRow(displayPoint.row);
        final currentDisplayRow:Int = displayRow != null ? displayRow : self.displayMap.nearestVisibleDisplayRow(displayPoint.row);
        final displayRowCount = self.displayMap.displayRowCount();
        final maxDisplayRow = displayRowCount > 0 ? displayRowCount - 1 : 0;
        // `saturating_add_signed` then `min`
        var targetDisplayRow = currentDisplayRow + moveLines;
        if (targetDisplayRow < 0) targetDisplayRow = 0;
        if (targetDisplayRow > maxDisplayRow) targetDisplayRow = maxDisplayRow;
        final wrapRow = self.displayMap.displayRowToWrapRow(targetDisplayRow);
        final targetWrapRow:Int = wrapRow != null ? wrapRow : displayPoint.row;

        var newOffset = self.displayMap.wrapDisplayPointToOffset(new WrapDisplayPoint(targetWrapRow, displayPoint.localRow, 0));

        final columnAnchor = columnAnchor != null ? columnAnchor : preferredColumnForWithAffinity(self, offset, lineEndAffinity);
        var newAffinity = false;
        if (columnAnchor != null) {
            final preferredX = columnAnchor.x;
            final column = columnAnchor.column;
            // Get display point again to update local_row.
            final next = self.displayMap.offsetToWrapDisplayPoint(newOffset);
            final nextDisplayPoint = new WrapDisplayPoint(next.row, next.localRow, 0);
            final nextPoint = self.displayMap.wrapDisplayPointToPoint(nextDisplayPoint);
            final lineStartOffset = self.text.lineStartOffset(nextPoint.row);

            // If in visible range, prefer to use position to get column.
            final line = lastLayout.line(nextPoint.row);
            if (line != null) {
                final hit = line.closestIndexForPosition(new Point(preferredX, nextDisplayPoint.localRow * (lastLayout.lineHeight:Float)), lastLayout);
                if (hit != null) {
                    newOffset = lineStartOffset + hit.index;
                    // Landing on a wrap boundary means the preferred column
                    // pointed past the last glyph of the target row, so the
                    // caret stays on that row.
                    newAffinity = hit.lineEndAffinity;
                }
            }
            else {
                // Not in visible range, use column directly.
                final maxLineLen = self.text.sliceLine(nextPoint.row).len();
                newOffset = lineStartOffset + (column < maxLineLen ? column : maxLineLen);
            }
        }

        return new CursorTarget(newOffset, newAffinity);
    }

    /**
     * Extend to the document edge when there is no further visual row. Plain
     * movement retains its column there, but selection must still reach the
     * remaining text on the first or last row.
     */
    public static function verticalSelectionTarget(self:InputBaseState, offset:Int, columnAnchor:Null<ColumnAnchor>, lineEndAffinity:Bool,
            moveLines:Int):CursorTarget {
        final target = verticalTarget(self, offset, columnAnchor, lineEndAffinity, moveLines);
        if (self.lastLayout != null) {
            inline function row(offset:Int, affinity:Bool):Int {
                return self.displayMap.offsetToWrapDisplayPointWithAffinity(offset, affinity).row;
            }
            if (row(offset, lineEndAffinity) == row(target.offset, target.lineEndAffinity)) {
                return new CursorTarget(moveLines < 0 ? 0 : self.text.len(), false);
            }
        }
        return target;
    }

    /**
     * Move every cursor through `f`, which maps each selection to a
     * `CursorMove` (offset, column anchor, line-end affinity), collapsing each
     * to a cursor. Overlapping cursors are merged, then the standard post-move
     * sequence runs. Only the active cursor's affinity is kept, see
     * `moveToWithAffinity`.
     */
    public static function moveAllCursors(self:InputBaseState, f:(InputBaseState, CursorSelection) -> CursorMove, direction:Null<MoveDirection>,
            window:Window, cx:Context<InputBaseState>):Void {
        self.undoManager.breakTransactionCoalescing();
        var activeAffinity = false;
        final activeId = self.activeSelection().id;
        final newSelections:Array<CursorSelection> = [];
        for (sel in self.selections.iter()) {
            final move = f(self, sel);
            if (sel.id == activeId) {
                activeAffinity = move.lineEndAffinity;
            }
            final newSel = sel.copy();
            newSel.placeAt(self.cursorBoundary(move.offset, Bias.Left), move.anchor);
            newSelections.push(newSel);
        }
        self.selections.replaceAll(newSelections);
        self.selections.mergeOverlapping();

        self.cursorLineEndAffinity = activeAffinity;
        self.scrollTo(self.cursor(), direction, cx);
        self.pauseBlinkCursor(cx);
        self.modeKind.hideContextMenu(self, cx);
        self.modeKind.clearInlineCompletion(self, cx);
        cx.notify();
    }

    /**
     * Move every cursor vertically by `moveLines`.
     *
     * When `collapse` is set, a non-empty selection first collapses to just
     * outside its start (up) or end (down) before moving, otherwise the
     * cursor offset is used.
     */
    static function moveVertical(self:InputBaseState, moveLines:Int, collapse:Bool, window:Window, cx:Context<InputBaseState>):Void {
        if (self.isSingleLine()) {
            return;
        }
        self.pauseBlinkCursor(cx);

        final direction = moveLines < 0 ? MoveDirection.Up : MoveDirection.Down;

        moveAllCursors(self, (s, sel) -> {
            var effective:Int;
            var anchor:Null<ColumnAnchor>;
            var affinity:Bool;
            if (sel.isEmpty() || !collapse) {
                effective = sel.cursorOffset();
                anchor = sel.columnAnchor;
                affinity = lineEndAffinityFor(s, sel);
            }
            else if (moveLines < 0) {
                final e = s.previousBoundary(sel.start > 0 ? sel.start - 1 : 0);
                effective = e;
                anchor = preferredColumnFor(s, e);
                affinity = false;
            }
            else {
                final e = s.nextBoundary(sel.end > 0 ? sel.end - 1 : 0);
                final a = lineEndAffinityAt(s, e);
                effective = e;
                anchor = preferredColumnForWithAffinity(s, e, a);
                affinity = a;
            }
            if (anchor == null) anchor = preferredColumnForWithAffinity(s, effective, affinity);
            final target = verticalTarget(s, effective, anchor, affinity, moveLines);
            return new CursorMove(target.offset, anchor, target.lineEndAffinity);
        }, direction, window, cx);
    }

    public static function left(self:InputBaseState, _:MoveLeft, window:Window, cx:Context<InputBaseState>):Void {
        // With a lone cursor at the very start there is nowhere to move.
        // Propagate the keystroke so an ancestor (e.g. a navigable command
        // palette) can act on it. This is harmless when nothing is bound
        // there. With multiple cursors the others can still move, so only the
        // single-cursor case propagates.
        if (self.selections.isSingle() && self.activeSelection().isEmpty() && self.cursor() == 0) {
            cx.propagate();
            return;
        }

        moveAllCursors(self, (s, sel) -> {
            final offset = sel.isEmpty() ? s.previousBoundary(sel.cursorOffset()) : sel.start;
            return new CursorMove(offset, preferredColumnFor(s, offset), false);
        }, null, window, cx);
    }

    public static function right(self:InputBaseState, _:MoveRight, window:Window, cx:Context<InputBaseState>):Void {
        // Mirror `left`: a lone cursor at the end of the text has nowhere to
        // move, so let the keystroke bubble to an ancestor.
        if (self.selections.isSingle() && self.activeSelection().isEmpty() && self.cursor() == self.text.len()) {
            cx.propagate();
            return;
        }

        moveAllCursors(self, (s, sel) -> {
            final offset = sel.isEmpty() ? s.nextBoundary(sel.cursorOffset()) : sel.end;
            return new CursorMove(offset, preferredColumnFor(s, offset), false);
        }, null, window, cx);
    }

    public static function up(self:InputBaseState, action:MoveUp, window:Window, cx:Context<InputBaseState>):Void {
        if (self.modeKind.handleContextMenuAction(self, action.boxedClone(), window, cx)) {
            return;
        }

        moveVertical(self, -1, true, window, cx);
    }

    public static function down(self:InputBaseState, action:MoveDown, window:Window, cx:Context<InputBaseState>):Void {
        if (self.modeKind.handleContextMenuAction(self, action.boxedClone(), window, cx)) {
            return;
        }

        moveVertical(self, 1, true, window, cx);
    }

    public static function pageUp(self:InputBaseState, _:MovePageUp, window:Window, cx:Context<InputBaseState>):Void {
        if (self.isSingleLine()) {
            return;
        }

        final lastLayout = self.lastLayout;
        if (lastLayout == null) {
            return;
        }

        // `as isize` truncates toward zero.
        final displayLines = Std.int((self.inputBounds.size.height:Float) / (lastLayout.lineHeight:Float));
        moveVertical(self, -displayLines, false, window, cx);
    }

    public static function pageDown(self:InputBaseState, _:MovePageDown, window:Window, cx:Context<InputBaseState>):Void {
        if (self.isSingleLine()) {
            return;
        }

        final lastLayout = self.lastLayout;
        if (lastLayout == null) {
            return;
        }

        final displayLines = Std.int((self.inputBounds.size.height:Float) / (lastLayout.lineHeight:Float));
        moveVertical(self, displayLines, false, window, cx);
    }

    public static function home(self:InputBaseState, _:MoveHome, window:Window, cx:Context<InputBaseState>):Void {
        moveAllCursors(self, (s, sel) -> {
            final offset = s.startOfLineAt(sel.cursorOffset(), lineEndAffinityFor(s, sel));
            return new CursorMove(offset, preferredColumnFor(s, offset), false);
        }, MoveDirection.Up, window, cx);
    }

    public static function end(self:InputBaseState, _:MoveEnd, window:Window, cx:Context<InputBaseState>):Void {
        moveAllCursors(self, (s, sel) -> {
            final offset = s.endOfLineAt(sel.cursorOffset(), lineEndAffinityFor(s, sel));
            // The caret belongs at the end of the visual row it is on.
            return new CursorMove(offset, preferredColumnFor(s, offset), true);
        }, MoveDirection.Down, window, cx);
    }

    public static function moveToStart(self:InputBaseState, _:MoveToStart, window:Window, cx:Context<InputBaseState>):Void {
        moveTo(self, 0, null, cx);
    }

    public static function moveToEnd(self:InputBaseState, _:MoveToEnd, window:Window, cx:Context<InputBaseState>):Void {
        moveTo(self, self.text.len(), null, cx);
    }

    public static function moveToPreviousWord(self:InputBaseState, _:MoveToPreviousWord, window:Window, cx:Context<InputBaseState>):Void {
        moveAllCursors(self, (s, sel) -> {
            final offset = s.previousStartOfWordAt(sel.cursorOffset());
            return new CursorMove(offset, preferredColumnFor(s, offset), false);
        }, null, window, cx);
    }

    public static function moveToNextWord(self:InputBaseState, _:MoveToNextWord, window:Window, cx:Context<InputBaseState>):Void {
        moveAllCursors(self, (s, sel) -> {
            final offset = s.nextEndOfWordAt(sel.cursorOffset());
            return new CursorMove(offset, preferredColumnFor(s, offset), false);
        }, null, window, cx);
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/input/base/touch.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.Context;
import glaze.LongPressEvent;
import glaze.Pixels;
import glaze.Point;
import glaze.Range;
import glaze.TouchPhase;
import glaze.Window;
import glaze.kit.base.AutoScroll;

using glaze.kit.base.input.InputMovement;
using glaze.kit.base.input.InputWordSelection;

/**
 * Touch selection for the input engine: grab handles and the edit menu (the
 * `impl InputBaseState` block of touch.rs, as static extensions:
 * `using glaze.kit.base.input.InputTouch;`).
 *
 * The touch selection remembers the range it made. As soon as the selection
 * is something else (the caret moved, text was typed, another cursor was
 * added) the handles and the menu are gone, without anyone having to hide
 * them. Only the touch gesture and the menu's own actions move the range and
 * carry the touch selection along.
 */
class InputTouch {

    /**
     * The live touch selection, laid out for the handles and the edit menu.
     *
     * Null when the last touch selection has since changed into something
     * else, or when its ends are not laid out (scrolled out of view).
     */
    public static function touchSelection(self:InputBaseState):Null<TouchSelectionSnapshot> {
        final range = self.touchSelection.range;
        if (range == null) return null;
        final selection = self.activeSelection();
        if (selection.start != range.start || selection.end != range.end) {
            return null;
        }

        final layout = self.lastLayout;
        if (layout == null) return null;
        final lineHeight = layout.lineHeight;
        final laidOut = layout.visibleRangeOffset;
        final lastBounds = self.lastBounds;
        if (lastBounds == null) return null;
        final origin = lastBounds.origin;
        final viewport = self.inputBounds;
        // An end scrolled out of the input gets no handle. Its line may not
        // even be laid out; it then stands just outside the viewport on its
        // side, which is all the other end's drag needs to know about it.
        function caretBox(offset:Int, standInY:Float):Bounds {
            final position = self.lineAndPositionForOffset(offset).position;
            if (position != null && (laidOut.contains(offset) || laidOut.end == offset)) {
                return TouchSelectionSnapshot.caretLineBox(origin.add(position), lineHeight);
            }
            return TouchSelectionSnapshot.caretLineBox(new Point(viewport.left(), standInY), lineHeight);
        }
        final start = caretBox(range.start, viewport.top() - (lineHeight:Float));
        final end = caretBox(range.end, viewport.bottom());
        final drag = self.touchSelection.drag;
        return TouchSelectionSnapshot.create(start, end)
            .withEdgeVisible(Start, TouchSelectionSnapshot.caretInView(start, viewport))
            .withEdgeVisible(End, TouchSelectionSnapshot.caretInView(end, viewport))
            .withMenuOpen(self.touchSelection.menuOpen)
            .withDragging(drag != null ? drag.edge() : null);
    }

    /** Records the current selection as the one the touch gesture made. */
    static function retainTouchSelection(self:InputBaseState):Void {
        final selection = self.activeSelection();
        self.touchSelection.range = new Range(selection.start, selection.end);
    }

    /**
     * Keeps the current selection as a touch selection, with the menu open
     * over it: what a double tap's word selection asks for.
     */
    public static function keepTouchSelection(self:InputBaseState, cx:Context<InputBaseState>):Void {
        retainTouchSelection(self);
        self.touchSelection.menuOpen = true;
        self.touchSelection.drag = null;
        cx.notify();
    }

    /**
     * Drops the handles and the edit menu. Called where the selection is
     * about to be moved by something other than the gesture.
     */
    public static function dismissTouchSelection(self:InputBaseState, cx:Context<InputBaseState>):Void {
        if (self.touchSelection.range == null) {
            return;
        }
        self.touchSelection = new TouchSelection();
        cx.notify();
    }

    /**
     * Closes the edit menu and keeps the selection with its handles.
     *
     * The menu's own actions end here: Copy has done its work, Select All
     * reopens the menu over the new range through `selectAllFromEditMenu`.
     */
    public static function closeEditMenu(self:InputBaseState, cx:Context<InputBaseState>):Void {
        if (!self.touchSelection.menuOpen) {
            return;
        }
        self.touchSelection.menuOpen = false;
        cx.notify();
    }

    /**
     * Reopens the edit menu when `position` is on the touch selection, the
     * way a tap on selected text asks for it. Returns whether it did.
     */
    public static function reopenEditMenuAt(self:InputBaseState, position:Point, cx:Context<InputBaseState>):Bool {
        final snapshot = touchSelection(self);
        if (snapshot == null) {
            return false;
        }
        if (snapshot.isEmpty()) {
            return false;
        }
        final offset = self.resolveMousePosition(position).offset;
        final selection = self.activeSelection();
        if (offset <= selection.start || offset >= selection.end) {
            return false;
        }
        self.touchSelection.menuOpen = true;
        cx.notify();
        return true;
    }

    /**
     * Steps the menu aside while the content scrolls under a finger, and
     * brings it back over the handles once the finger lifts.
     */
    public static function editMenuOnScroll(self:InputBaseState, phase:TouchPhase, cx:Context<InputBaseState>):Void {
        if (self.touchSelection.range == null) {
            return;
        }
        switch phase {
            case Ended | Cancelled:
                if (!self.touchSelection.menuOpen) {
                    self.touchSelection.menuOpen = true;
                    cx.notify();
                }
            case _:
                closeEditMenu(self, cx);
        }
    }

    /**
     * Selects everything and, when a touch selection is live, keeps the
     * handles and the edit menu over the new range.
     */
    public static function selectAllFromEditMenu(self:InputBaseState, window:Window, cx:Context<InputBaseState>):Void {
        final touch = self.touchSelection.range != null;
        self.selectAll(window, cx);
        if (touch) {
            retainTouchSelection(self);
            self.touchSelection.menuOpen = true;
            cx.notify();
        }
    }

    /** Rust `text.chars().all(char::is_whitespace)`. */
    static function allWhitespace(text:String):Bool {
        final codePoints:Array<Int> = [];
        final byteOffsets:Array<Int> = [];
        final count = glaze.util.Utf8.decode(text, codePoints, byteOffsets);
        for (i in 0...count) {
            if (!glaze.util.Utf8.isWhitespace(codePoints[i])) return false;
        }
        return true;
    }

    /**
     * Handles one phase of a long press inside the input.
     *
     * Returns whether the started phase was claimed; the caller then
     * captures the gesture so the moves keep coming even after the finger
     * leaves the input.
     */
    public static function onLongPress(self:InputBaseState, event:LongPressEvent, window:Window, cx:Context<InputBaseState>):Bool {
        switch event.phase {
            case Started:
                if (self.disabled) {
                    return false;
                }
                if (!self.focusHandle.isFocused(window)) {
                    window.focus(self.focusHandle, cx.app);
                }
                // The input selects on its own; keep the window text
                // selection from starting a drag under it.
                glaze.kit.base.GlobalState.suppressTextSelection(cx.app);
                self.undoManager.breakTransactionCoalescing();
                self.touchSelection = new TouchSelection();

                final resolved = self.resolveMousePosition(event.startPosition);
                final offset = resolved.offset;
                final lineEndAffinity = resolved.lineEndAffinity;
                self.selections.removeAllButActive();
                self.setCursorTo(offset);
                self.selectWord(offset, window, cx);
                final pressedWord = !self.activeSelection().isEmpty() && !allWhitespace(self.selectedText().toString());
                if (!pressedWord) {
                    // Whitespace or an empty field: the press places the
                    // caret, and the menu offers Paste and Select All.
                    self.moveToWithAffinity(offset, null, lineEndAffinity, cx);
                    self.selectedWordRange = null;
                }
                self.selecting = true;
                retainTouchSelection(self);
                cx.notify();
                return true;
            case Moved:
                final resolved = self.resolveMousePosition(event.position);
                if (self.selectedWordRange != null) {
                    // The press took a word; the sweep grows it a word at a time.
                    self.selectToWithAffinity(resolved.offset, resolved.lineEndAffinity, cx);
                }
                else {
                    // The press placed the caret; the sweep carries it.
                    self.moveToWithAffinity(resolved.offset, null, resolved.lineEndAffinity, cx);
                }
                retainTouchSelection(self);
                return true;
            case Ended | Cancelled:
                self.selecting = false;
                self.selectedWordRange = null;
                if (self.touchSelection.range != null) {
                    self.touchSelection.menuOpen = true;
                }
                cx.notify();
                return true;
        }
    }

    /**
     * Starts dragging one end of the touch selection from `finger`.
     *
     * The other end stays where it is. The menu closes for the duration of
     * the drag and reopens on `endEdgeDrag`.
     */
    public static function beginEdgeDrag(self:InputBaseState, edge:SelectionEdge, finger:Point, cx:Context<InputBaseState>):Void {
        final snapshot = touchSelection(self);
        if (snapshot == null) {
            return;
        }
        self.undoManager.breakTransactionCoalescing();
        self.selectedWordRange = null;
        self.activeSelectionMut().reversed = edge == Start;
        self.touchSelection.drag = EdgeDrag.begin(edge, snapshot.edge(edge), finger);
        self.touchSelection.menuOpen = false;
        cx.notify();
    }

    /**
     * Moves the dragged end to the text under `finger`.
     *
     * Past the top or bottom of a multi-line input the content scrolls under
     * the finger, so the end can reach text that was out of view.
     */
    public static function updateEdgeDrag(self:InputBaseState, finger:Point, cx:Context<InputBaseState>):Void {
        final drag = self.touchSelection.drag;
        if (drag == null) {
            return;
        }
        final position = drag.textPosition(finger);
        extendEdgeDragTo(self, position, cx);

        if (self.isSingleLine()) {
            return;
        }
        self.autoScroll.lastDragPosition = position;
        final delta = AutoScroll.computeDelta(position.y, self.inputBounds);
        // Input's ScrollHandle uses negative-y-is-down; negate the positive-towards-bottom delta.
        final scrollDelta:Null<Float> = delta != null ? -delta : null;
        self.autoScroll.set(scrollDelta, cx, (delta, state, cx) -> {
            final current = state.scrollHandle.offset();
            state.updateScrollOffset(new Point(current.x, current.y + delta), cx);
            final position = state.autoScroll.lastDragPosition;
            if (position != null) {
                extendEdgeDragTo(state, position, cx);
            }
        });
    }

    static function extendEdgeDragTo(self:InputBaseState, position:Point, cx:Context<InputBaseState>):Void {
        if (self.touchSelection.drag == null) {
            return;
        }
        final resolved = self.resolveMousePosition(position);
        final before = self.activeSelection().copy();
        self.selectToWithAffinity(resolved.offset, resolved.lineEndAffinity, cx);
        // A handle never collapses the selection: at the other end it stops,
        // and the finger has to pass that end to swap the two.
        if (self.activeSelection().isEmpty()) {
            self.selections.setActive(before);
            return;
        }
        // Dragging one end past the other swaps them: the selection now runs
        // the other way and the finger holds what became the other handle.
        final edge = self.activeSelection().reversed ? SelectionEdge.Start : SelectionEdge.End;
        final drag = self.touchSelection.drag;
        if (drag != null) {
            drag.setEdge(edge);
        }
        retainTouchSelection(self);
        cx.notify();
    }

    /** Ends the handle drag and reopens the edit menu. */
    public static function endEdgeDrag(self:InputBaseState, cx:Context<InputBaseState>):Void {
        final drag = self.touchSelection.drag;
        self.touchSelection.drag = null;
        if (drag == null) {
            return;
        }
        self.autoScroll.stop();
        if (self.activeSelection().isEmpty()) {
            self.activeSelectionMut().reversed = false;
        }
        self.touchSelection.menuOpen = true;
        cx.notify();
    }

    @:allow(tests)
    static function isEditMenuOpen(self:InputBaseState):Bool {
        return self.touchSelection.menuOpen;
    }

    @:allow(tests)
    static function touchSelectionRange(self:InputBaseState):Null<Range> {
        return self.touchSelection.range;
    }

}

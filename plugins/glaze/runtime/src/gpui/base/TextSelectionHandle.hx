// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.App;
import gpui.Bounds;
import gpui.Entity;
import gpui.HitboxBehavior;
import gpui.Hsla;
import gpui.TouchDragEvent;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.Point;
import gpui.Subscription;
import gpui.WeakEntity;
import gpui.Window;
import gpui.base.SelectableTextState;
import gpui.base.WindowSelectionState.TableCellAnchor;
import gpui.base.TouchHandleLayout.TouchHandleHitbox;
import gpui.base.input.TouchHandle;

/**
 * A stable, participant-neutral handle for text that participates in window
 * selection.
 */
class TextSelectionHandle {

    @:allow(gpui.base)
    final state:Entity<SelectableTextState>;

    function new(state:Entity<SelectableTextState>) {
        this.state = state;
    }

    /** Creates a selection participant handle with fallback text for copying (Rust `new`). */
    public static function create(fallbackCopyText:String, cx:App):TextSelectionHandle {
        return new TextSelectionHandle(cx.newEntity(_ -> new SelectableTextState(fallbackCopyText)));
    }

    /** Returns this participant's stable identity. */
    public inline function entityId():Int {
        return state.entityId();
    }

    /** Returns the current geometry selection snapshot for this participant. */
    public function snapshot(cx:App):Null<TextSelectionSnapshot> {
        return state.read(cx).snapshot();
    }

    /** Records the anchor cell during prepaint, before any participant paints. */
    @:allow(gpui.base)
    function recordTableCell(bounds:Bounds, cx:App):Void {
        final state = windowSelection(cx);
        if (state == null) {
            return;
        }
        final state = state.read(cx);
        if (state.touchSelectAll) {
            return;
        }
        final snapshot = snapshot(cx);
        if (snapshot == null) {
            return;
        }
        final points = snapshot.windowPoints();
        if (snapshot.anchor().entityId() == entityId() && points != null && bounds.contains(points.anchor())) {
            state.tableCellAnchor = new TableCellAnchor(snapshot.anchor(), bounds);
        }
    }

    /** The current gesture's anchor cell, shared only by participants in its window. */
    @:allow(gpui.base)
    function tableCellSelection(cx:App):Null<Bounds> {
        final state = windowSelection(cx);
        if (state == null) return null;
        final state = state.read(cx);
        if (state.touchSelectAll) {
            return null;
        }
        final anchor = state.tableCellAnchor;
        if (anchor == null) return null;
        final snapshot = snapshot(cx);
        if (snapshot == null) return null;
        return snapshot.anchor().equals(anchor.endpoint) ? anchor.bounds : null;
    }

    /** Retires an anchor projection when its participant replaces its content. */
    @:allow(gpui.base)
    function clearTableCellSelection(cx:App):Void {
        final state = windowSelection(cx);
        if (state != null) {
            final state = state.read(cx);
            final anchor = state.tableCellAnchor;
            if (anchor != null && anchor.endpoint.entityId() == entityId()) {
                state.tableCellAnchor = null;
            }
        }
    }

    function windowSelection(cx:App):Null<Entity<WindowSelectionState>> {
        final weak = state.read(cx).windowSelection;
        return weak != null ? weak.upgrade() : null;
    }

    /** Sets the fallback text copied while this participant participates. */
    public function setFallbackCopyText(text:String, cx:App):Void {
        state.update(cx, (state, _) -> state.setFallbackCopyText(text));
    }

    /** Marks participant-local selection, such as select-all, as active. */
    public function setLocalSelection(active:Bool, cx:App):Void {
        state.update(cx, (state, _) -> state.setLocalSelection(active));
    }

    /** Returns whether participant-local selection is active. */
    public function hasLocalSelection(cx:App):Bool {
        return state.read(cx).localSelection;
    }

    /** Registers this participant and its geometry for the current frame. */
    public function register(registration:TextSelectionRegistration, window:Window, cx:App):Void {
        final scope = TextSelection.currentTextSelectionScope(window.id, cx);
        if (scope != null) {
            registration._scope = scope;
        }
        final windowState = WindowSelectionState.existing(window, cx);
        if (windowState == null) {
            return;
        }
        state.read(cx).windowSelection = windowState.downgrade();
        windowState.read(cx).registerQuietly(this, registration);
        final snapshot = windowState.read(cx).participantSnapshot(entityId());
        if (!TextSelectionSnapshot.eq(this.snapshot(cx), snapshot)) {
            // Plain text projects its runs immediately after registering.
            // Rich text may already have painted, so notify after the frame
            // as well, when another draw can actually be scheduled.
            state.update(cx, (participant, _) -> participant.setSnapshotQuietly(snapshot));
            windowState.read(cx).drawChanged.set(entityId(), downgrade());
        }
        TextSelection.scheduleSelectionFrame(windowState, window, cx);
    }

    /** Projects the current snapshot onto plain-text runs and caches their copy text. */
    public function updateRuns(runs:Array<TextSelectionRun>, cx:App):TextSelectionProjection {
        return state.read(cx).updateRuns(runs);
    }

    /**
     * The projected text this participant adds to the window's selected text,
     * or `null` when it adds none or copies through its own callback.
     */
    @:allow(gpui.base)
    function projectedCopyText(cx:App):Null<String> {
        final item = state.read(cx).copyItem(0);
        return item != null && item.callback == null ? item.fallback : null;
    }

    /** Rich text renders its own selection; retain geometry only for word hit testing. */
    @:allow(gpui.base)
    function setHitTestRuns(runs:Array<TextSelectionRun>, cx:App):Void {
        state.read(cx).runs = runs.copy();
    }

    /**
     * Lets a drag from a double or triple click that this participant selected
     * for itself, from the caret `start` to the caret `end` in window
     * coordinates, extend the selection by the same unit through the window
     * selection, as a shift-click after it does.
     */
    @:allow(gpui.base)
    function holdMultiClick(start:Bounds, end:Bounds, clickCount:Int, cx:App):Void {
        final windowState = windowSelection(cx);
        if (windowState == null) {
            return;
        }
        windowState.update(cx, (windowState, cx) -> {
            final unit = windowState.unitOf(state, start, end, clickCount, cx.app);
            if (unit != null) {
                windowState.holdUnit(unit, cx.app);
            }
        });
    }

    /** Subscribes to participant selection notifications. */
    public function subscribe(callback:(TextSelectionEvent, App) -> Void, cx:App):Subscription {
        return cx.subscribe(state, TextSelectionEvent, (_, event, cx) -> callback(event, cx));
    }

    /** Subscribes `window` to refresh whenever this participant's selection changes. */
    public function refreshWindowOnChange(window:Window, cx:App):Subscription {
        return subscribe((event, cx) -> {
            switch event {
                case SelectionChanged(_):
                    if (Window.windows.contains(window)) window.refresh();
                case _:
            }
        }, cx);
    }

    /** Sets the callback which focuses the participant when a drag begins in it. */
    public function focusWith(callback:(Window, App) -> Void, cx:App):Void {
        state.update(cx, (state, _) -> state.setFocusHandler(callback));
    }

    /** Sets the synchronous participant cleanup command used by window clear. */
    public function clearWith(callback:(App) -> Void, cx:App):Void {
        state.update(cx, (state, _) -> state.clearWith(callback));
    }

    /** Sets a participant-specific copy projection. */
    public function copyWith(callback:(App) -> String, cx:App):Void {
        state.update(cx, (state, _) -> state.copyWith(callback));
    }

    /**
     * Lays out the touch handles at the ends of this participant's selection,
     * as they were painted last frame, and gives each a hitbox where the
     * finger takes it. Call during the participant's prepaint; hand the result
     * to `paintTouchHandles`.
     */
    public function prepaintTouchHandles(window:Window, cx:App):TouchHandleLayout {
        final windowState = WindowSelectionState.existing(window, cx);
        if (windowState == null) {
            return new TouchHandleLayout();
        }
        final hitboxes = [
            for (handle in windowState.read(cx).touchHandlesOf(entityId()))
                new TouchHandleHitbox(handle.edge, window.insertHitbox(TouchHandle.hitBounds(handle.edge, handle.caret), HitboxBehavior.BlockMouse))
        ];
        return new TouchHandleLayout(hitboxes);
    }

    /**
     * Paints the touch handles at the ends of this participant's selection, in
     * `color`, where the participant is in the paint order. Call at the end of
     * the participant's paint, after `register` for the frame.
     */
    public function paintTouchHandles(layout:TouchHandleLayout, color:Hsla, window:Window, cx:App):Void {
        final windowState = WindowSelectionState.existing(window, cx);
        if (windowState == null) {
            return;
        }
        for (handle in windowState.read(cx).touchHandlesOf(entityId())) {
            TouchHandle.paint(handle.edge, handle.caret, color, window);
        }
        final bounds:Array<Bounds> = [for (handle in layout.hitboxes) handle.hitbox.bounds];
        if (!windowState.read(cx).handlesPaintedAt(entityId(), bounds)) {
            windowState.update(cx, (state, _) -> state.registerHandles(entityId(), bounds));
        }
        for (handle in layout.hitboxes) {
            final edge = handle.edge;
            final hitbox = handle.hitbox;
            final weakState = windowState.downgrade();
            // Touch: the drag is offered on the first touch, before it can
            // become a tap, a long press or a pan.
            window.onMouseEvent(TouchDrag, (event, phase, window, cx) -> {
                final event:TouchDragEvent = cast event;
                if (!phase.bubble() || event.phase != Started || window.defaultPrevented() || !hitbox.isHovered(window)) {
                    return;
                }
                final windowState = weakState.upgrade();
                if (windowState == null) {
                    return;
                }
                window.preventDefault();
                cx.stopPropagation();
                windowState.update(cx, (state, cx) -> state.beginEdgeDrag(edge, event.position, window, cx.app));
                WindowSelectionState.resolveContentKeys(windowState, cx);
            });
            // Mouse: the same drag for a pointer.
            window.onMouseEvent(MouseDown, (event, phase, window, cx) -> {
                final event:MouseDownEvent = cast event;
                if (!phase.bubble() || event.button != MouseButton.Left || !hitbox.isHovered(window)) {
                    return;
                }
                final windowState = weakState.upgrade();
                if (windowState == null) {
                    return;
                }
                cx.stopPropagation();
                windowState.update(cx, (state, cx) -> state.beginEdgeDrag(edge, event.position, window, cx.app));
                WindowSelectionState.resolveContentKeys(windowState, cx);
            });
        }
    }

    /** Sets a participant-specific lookup for stable virtualized content keys. */
    public function resolveContentKeyWith(callback:(Point, App) -> Null<TextSelectionContentKey>, cx:App):Void {
        state.update(cx, (state, _) -> state.resolveContentKeyWith(callback));
    }

    @:allow(gpui.base)
    function downgrade():WeakEntity<SelectableTextState> {
        return state.downgrade();
    }

}

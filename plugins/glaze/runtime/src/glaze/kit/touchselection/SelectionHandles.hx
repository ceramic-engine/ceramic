// Ported from gpui-kit 0.8.1: crates/component/src/touch_selection/handle.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.touchselection;

import glaze.App;
import glaze.Bounds;
import glaze.Component;
import glaze.Hitbox;
import glaze.HitboxBehavior;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.TouchDragEvent;
import glaze.TouchPhase;
import glaze.Window;
import glaze.kit.base.Popup;
import glaze.kit.base.input.SelectionEdge;
import glaze.kit.base.input.TouchHandle;
import glaze.kit.base.input.TouchSelectionSnapshot;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/** Reads the touch selection as laid out by the time the handles paint. */
typedef SnapshotSource = (Window, App) -> Null<TouchSelectionSnapshot>;

/** What a handle's owner gets told as the finger moves it. */
typedef DragHandler = (SelectionEdge, TouchPhase, Point, Window, App) -> Void;

/** Where a surface was painted this frame, for owners that must protect it. */
typedef SurfaceHandler = (Bounds, Window, App) -> Void;

/** One handle laid out for this frame. */
private class LaidOutHandle {

    public final edge:SelectionEdge;

    public final caret:Bounds;

    public final hitbox:Hitbox;

    public function new(edge:SelectionEdge, caret:Bounds, hitbox:Hitbox) {
        this.edge = edge;
        this.caret = caret;
        this.hitbox = hitbox;
    }

}

/**
 * The grab handles at the ends of an input's touch selection, floating above
 * the input: its knobs reach past the field's edge, where the input's own
 * clip would cut them off. (Text that takes part in the window selection
 * paints its handles itself, in place; see
 * `TextSelectionHandle.paintTouchHandles`.)
 *
 * The handles read the selection's geometry as they paint, after the input
 * has painted this frame, so they sit on the text as it is now.
 *
 * A handle claims the touch drag that begins on it before the window can
 * take the drag for panning, and blocks the mouse so a stray tap on it does
 * not reach the text underneath. A mouse can drag it too.
 */
class SelectionHandles extends Component {

    final source:SnapshotSource;

    final onDrag:DragHandler;

    @prop var onPaint:Null<SurfaceHandler> = null;

    public function new(source:SnapshotSource, onDrag:DragHandler) {
        super();
        this.source = source;
        this.onDrag = onDrag;
    }

    /** Lays out a handle for each end of a non-empty selection that is in view. */
    static function layout(source:SnapshotSource, window:Window, cx:App):Array<LaidOutHandle> {
        final snapshot = source(window, cx);
        if (snapshot == null) {
            return [];
        }
        final windowBounds = new Bounds(new Point(0, 0), window.viewportSize());
        final handles:Array<LaidOutHandle> = [];
        if (!snapshot.isEmpty()) {
            for (edge in [SelectionEdge.Start, SelectionEdge.End]) {
                // No handle for an end scrolled out of its owner, nor for one
                // outside the window.
                final caret = snapshot.edge(edge);
                if (!snapshot.isEdgeVisible(edge) || !windowBounds.contains(caret.origin)) {
                    continue;
                }
                final hitbox = window.insertHitbox(TouchHandle.hitBounds(edge, caret), HitboxBehavior.BlockMouse);
                handles.push(new LaidOutHandle(edge, caret, hitbox));
            }
        }
        return handles;
    }

    static function paintHandle(handle:LaidOutHandle, window:Window, cx:App):Void {
        TouchHandle.paint(handle.edge, handle.caret, Theme.global(cx).selection.alpha(1.), window);
    }

    /**
     * The drag begins on whichever handle is under the finger or pointer;
     * its moves and its end are routed by which end is being dragged, so
     * they keep coming even if that handle is not laid out for a frame.
     */
    static function listen(handles:Array<LaidOutHandle>, source:SnapshotSource, onDrag:DragHandler, window:Window):Void {
        for (handle in handles) {
            final hitbox = handle.hitbox;
            final edge = handle.edge;
            // Touch: the drag is offered on the first touch, before it can
            // become a tap, a long press or a pan.
            window.onMouseEvent(TouchDrag, (event, phase, window, cx) -> {
                final event:TouchDragEvent = cast event;
                if (!phase.bubble() || event.phase != Started || window.defaultPrevented() || !hitbox.isHovered(window)) {
                    return;
                }
                window.preventDefault();
                cx.stopPropagation();
                onDrag(edge, Started, event.position, window, cx);
            });
            // Mouse: the same drag for a pointer.
            window.onMouseEvent(MouseDown, (event, phase, window, cx) -> {
                final event:MouseDownEvent = cast event;
                if (!phase.bubble() || event.button != MouseButton.Left || !hitbox.isHovered(window)) {
                    return;
                }
                cx.stopPropagation();
                onDrag(edge, Started, event.position, window, cx);
            });
        }

        // The drag in progress is read live: it may have begun after this
        // frame painted, and its first moves must not be lost.
        final dragging = (window:Window, cx:App) -> {
            final snapshot = source(window, cx);
            return snapshot != null ? snapshot.dragging() : null;
        };
        window.onMouseEvent(TouchDrag, (event, phase, window, cx) -> {
            final event:TouchDragEvent = cast event;
            if (!phase.bubble() || event.phase == Started) {
                return;
            }
            final edge = dragging(window, cx);
            if (edge == null) {
                return;
            }
            cx.stopPropagation();
            onDrag(edge, event.phase, event.position, window, cx);
        });
        window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
            final event:MouseMoveEvent = cast event;
            if (!phase.bubble() || event.pressedButton != MouseButton.Left) {
                return;
            }
            final edge = dragging(window, cx);
            if (edge == null) {
                return;
            }
            onDrag(edge, Moved, event.position, window, cx);
        });
        window.onMouseEvent(MouseUp, (event, phase, window, cx) -> {
            final event:MouseUpEvent = cast event;
            if (!phase.bubble() || event.button != MouseButton.Left) {
                return;
            }
            final edge = dragging(window, cx);
            if (edge == null) {
                return;
            }
            onDrag(edge, Ended, event.position, window, cx);
        });
    }

    public function render(window:Window, cx:App):IntoElement {
        final source = this.source;
        final onDrag = this.onDrag;
        final onPaint = this.onPaint;
        return deferred(
            canvas((_, window, cx) -> layout(source, window, cx), (_, handles:Array<LaidOutHandle>, window, cx) -> {
                for (handle in handles) {
                    paintHandle(handle, window, cx);
                    if (onPaint != null) {
                        onPaint(handle.hitbox.bounds, window, cx);
                    }
                }
                listen(handles, source, onDrag, window);
            })
                .absolute()
                .size0()
        ).withPriority(Popup.POPUP_PRIORITY);
    }

}

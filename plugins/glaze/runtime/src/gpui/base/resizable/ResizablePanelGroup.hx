// Ported from gpui-kit 0.8.1: crates/base/src/resizable/panel.rs (ResizablePanelEvent,
// DragPanel, ResizablePanelGroup, ResizePanelGroupElement)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.resizable;

import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.Context;
import gpui.Element;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.GlobalElementId;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.Model;
import gpui.MouseMoveEvent;
import gpui.Pixels;
import gpui.Render;
import gpui.RenderOnce;
import gpui.Style;
import gpui.Window;
import gpui.base.KeyedEntity;
import gpui.base.resizable.ResizeHandle.ResizeHandleRenderer;

import gpui.base.Prelude.*;

using gpui.base.Geometry.AxisExt;
using gpui.base.ElementExt;

/**
 * The events of a `ResizableState`.
 */
enum ResizablePanelEvent {
    Resized;
}

/**
 * The payload of a panel handle drag (Rust drags a `DragPanel` value and
 * renders a clone of it, an empty view).
 */
class DragPanel {

    public function new() {}

}

/**
 * The drag view of a `DragPanel` (renders nothing).
 */
class DragPanelView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new gpui.Empty();
    }

}

/**
 * A group of resizable panels.
 */
class ResizablePanelGroup implements RenderOnce {

    final id:ElementId;

    var stateValue:Null<Entity<ResizableState>> = null;

    var axisValue:Axis = Horizontal;

    var sizeValue:Null<Pixels> = null;

    var childPanels:Array<ResizablePanel> = [];

    var onResizeValue:(Entity<ResizableState>, Window, App) -> Void = (_, _, _) -> {};

    var handleAppearance:Null<ResizeHandleRenderer> = null;

    /**
     * Create a new resizable panel group.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * Hand the painted part of every divider in this group to `appearance`.
     *
     * The hit area, the cursor and the drag stay here; a renderer that
     * returns `null` for a given handle leaves the built-in line on it.
     */
    public function withHandleAppearance(appearance:ResizeHandleRenderer):ResizablePanelGroup {
        handleAppearance = appearance;
        return this;
    }

    /**
     * Bind yourself to a resizable state entity.
     *
     * If not provided, it will handle its own state internally.
     */
    public function withState(state:Entity<ResizableState>):ResizablePanelGroup {
        stateValue = state;
        return this;
    }

    /**
     * Set the axis of the resizable panel group, default is horizontal.
     */
    public function axis(axis:Axis):ResizablePanelGroup {
        axisValue = axis;
        return this;
    }

    /**
     * Add a panel to the group (any element is wrapped in a panel, Rust
     * `impl Into<ResizablePanel>`).
     *
     * - The `axis` will be set to the same axis as the group.
     * - The `initial_size` will be set to the average size of all panels if not provided.
     * - The `group` will be set to the group entity.
     */
    public function child(panel:IntoResizablePanel):ResizablePanelGroup {
        if (panel != null) childPanels.push(panel);
        return this;
    }

    /**
     * Add multiple panels to the group (replaces the panels added before,
     * like the original).
     */
    public function children(panels:Array<IntoResizablePanel>):ResizablePanelGroup {
        childPanels = [for (panel in panels) if (panel != null) (panel : ResizablePanel)];
        return this;
    }

    /**
     * Set size of the resizable panel group
     *
     * - When the axis is horizontal, the size is the height of the group.
     * - When the axis is vertical, the size is the width of the group.
     */
    public function size(size:Pixels):ResizablePanelGroup {
        sizeValue = size;
        return this;
    }

    /**
     * Set the callback to be called when the panels are resized.
     */
    public function onResize(onResize:(Entity<ResizableState>, Window, App) -> Void):ResizablePanelGroup {
        onResizeValue = onResize;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        // Rust `unwrap_or` evaluates the keyed state even when a state is bound.
        final ownState = KeyedEntity.useObserved(window, id, ResizableState, cx, (_, _) -> new ResizableState());
        final state = stateValue != null ? stateValue : ownState;
        final axis = axisValue;
        final container = axis.isHorizontal() ? hFlex() : vFlex();

        // Sync panels to the state
        final panelsCount = childPanels.length;
        state.update(cx, (state, cx) -> state.syncPanelsCount(axis, panelsCount, cx));
        // Like GPUI's accessed entities: a change of the state renders the
        // view drawing this group again.
        final changes = state.read(cx).changes;

        container.id(id).sizeFull();
        // The group only distributes space along its own axis, so a caller
        // supplied size can only mean the cross axis.
        if (sizeValue != null) {
            switch axis {
                case Horizontal: container.h(sizeValue);
                case Vertical: container.w(sizeValue);
            }
        }
        for (ix in 0...childPanels.length) {
            final panel = childPanels[ix];
            panel.panelIx = ix;
            panel.axis = axis;
            panel.state = state;
            panel.handleAppearance = handleAppearance;
            container.child(panel);
        }
        container.onPrepaint((bounds, window, cx) -> {
            // The same bounds as last frame change nothing; updating the
            // state for them would mark it changed every frame.
            if (state.read(cx).bounds.equals(bounds)) {
                return;
            }
            state.update(cx, (state, cx) -> {
                final sizeChanged = (state.bounds.size.along(axis) : Float) != (bounds.size.along(axis) : Float);

                state.bounds = bounds;

                if (sizeChanged) {
                    state.adjustToContainerSize(cx);
                    // The adjustment lands after this frame's layout has
                    // already been computed, and a notify raised during a
                    // draw only records the view as dirty without scheduling
                    // a frame for it. Defer the notify so it runs once the
                    // draw has finished and can schedule the settling frame.
                    final state = cx.entity();
                    window.defer(cx.app, (_, cx) -> {
                        state.update(cx, (state, cx) -> state.notifyChanged(cx));
                    });
                }
            });
        });
        container.child(new ResizePanelGroupElement(state, axis, onResizeValue));
        return container;
    }

}

/**
 * Rust `impl Into<ResizablePanel>`: a panel, or any element (wrapped in a
 * new panel).
 */
abstract IntoResizablePanel(ResizablePanel) from ResizablePanel to ResizablePanel {

    @:from static function fromElement(element:IntoElement):IntoResizablePanel {
        return Resizable.resizablePanel().child(element);
    }

    @:from static function fromGroup(group:ResizablePanelGroup):IntoResizablePanel {
        return Resizable.resizablePanel().child(group);
    }

}

/**
 * Listens to the window mouse events of a group while one of its panels is
 * being resized.
 */
class ResizePanelGroupElement extends Element {

    final state:Entity<ResizableState>;

    final onResize:(Entity<ResizableState>, Window, App) -> Void;

    final axis:Axis;

    public function new(state:Entity<ResizableState>, axis:Axis, onResize:(Entity<ResizableState>, Window, App) -> Void) {
        this.state = state;
        this.axis = axis;
        this.onResize = onResize;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return window.requestLayout(@:privateAccess gpui.Style.sharedDefaultStyle(), null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {}

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final state = this.state;
        final axis = this.axis;
        window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
            if (!phase.bubble()) {
                return;
            }
            final ix = state.read(cx).resizingPanelIx;
            if (ix == null) {
                return;
            }
            final e:MouseMoveEvent = cast event;

            state.update(cx, (state, cx) -> {
                if (ix >= state.panels.length) throw 'BUG: invalid panel index';
                final panel = state.panels[ix];

                switch axis {
                    case Horizontal:
                        state.resizePanelAtHandle(ix, e.position.x - panel.bounds.left(), window, cx);
                    case Vertical:
                        state.resizePanelAtHandle(ix, e.position.y - panel.bounds.top(), window, cx);
                }
                state.notifyChanged(cx);
            });
        });

        // When any mouse up, stop dragging
        final onResize = this.onResize;
        window.onMouseEvent(MouseUp, (_, phase, window, cx) -> {
            if (state.read(cx).resizingPanelIx == null) {
                return;
            }
            if (phase.bubble()) {
                state.update(cx, (state, cx) -> state.doneResizing(cx));
                onResize(state, window, cx);
            }
        });
    }

}

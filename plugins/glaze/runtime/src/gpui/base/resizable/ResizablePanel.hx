// Ported from gpui-kit 0.8.1: crates/base/src/resizable/panel.rs (ResizablePanel)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.resizable;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.ElementId;
import gpui.Entity;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.resizable.ResizablePanelGroup.DragPanel;
import gpui.base.resizable.ResizablePanelGroup.DragPanelView;
import gpui.base.resizable.ResizeHandle.ResizeHandleRenderer;
import gpui.util.MathUtil;

import gpui.Prelude.*;

using gpui.base.Geometry.AxisExt;
using gpui.base.ElementExt;
using gpui.base.StyledExt;

/**
 * A resizable panel inside a `ResizablePanelGroup`.
 *
 * Implements `Styled`, so call sites can override the panel's rendered
 * styles. User overrides are applied between the panel's flex defaults and
 * its size management: the caller can override the internal
 * `flex_grow: 1` (e.g. via `.flexNone()`) and add their own padding, colors
 * or borders, while the panel's runtime size constraints (min / max width
 * and `flex_basis` driven by `ResizableState`) always win.
 *
 * To keep a panel's size when the group's container resizes, use `fixed()`.
 *
 * Reserved styles: do not call `flexBasis`, `absolute` or `overflowHidden`
 * from outside, they fight the panel's own layout management.
 */
class ResizablePanel implements RenderOnce implements Styled implements ParentElement {

    @:allow(gpui.base.resizable)
    var axis:Axis = Horizontal;

    @:allow(gpui.base.resizable)
    var panelIx:Int = 0;

    @:allow(gpui.base.resizable)
    var state:Null<Entity<ResizableState>> = null;

    /**
     * Initial size is the size that the panel has when it is created.
     */
    var initialSize:Null<Pixels> = null;

    /**
     * Size range limit of this panel.
     */
    var sizeRangeValue:PixelsRange = new PixelsRange(Resizable.PANEL_MIN_SIZE, Pixels.MAX);

    final childElements:Array<AnyElement> = [];

    var visibleValue:Bool = true;

    final panelStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.base.resizable)
    var handleAppearance:Null<ResizeHandleRenderer> = null;

    var fixedValue:Bool = false;

    /**
     * Create a new resizable panel (see `Resizable.resizablePanel()`).
     */
    @:allow(gpui.base.resizable)
    function new() {}

    /**
     * Set the visibility of the panel, default is true.
     */
    public function visible(visible:Bool):ResizablePanel {
        visibleValue = visible;
        return this;
    }

    /**
     * Set the initial size of the panel.
     */
    public function size(size:Pixels):ResizablePanel {
        initialSize = size;
        return this;
    }

    /**
     * Set the size range to limit panel resize.
     *
     * Default is `PANEL_MIN_SIZE` to `Pixels.MAX`.
     */
    public function sizeRange(range:PixelsRange):ResizablePanel {
        sizeRangeValue = range;
        return this;
    }

    /**
     * Keep this panel's size when the group's container resizes.
     *
     * When the container grows or shrinks, the other panels share the
     * difference in proportion to their sizes. Dragging its own handle still
     * resizes it. It needs a `size()`, and at least one panel in the group
     * should not be fixed.
     */
    public function fixed():ResizablePanel {
        fixedValue = true;
        return this;
    }

    public inline function style():StyleRefinement {
        return panelStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):ResizablePanel {
        childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        if (!visibleValue) {
            return div().id(ElementId.NamedInteger('resizable-panel', panelIx));
        }

        final state = this.state;
        if (state == null) throw 'BUG: The `state` in ResizablePanel should be present.';
        final panels = state.read(cx).panels;
        if (panelIx >= panels.length) throw 'BUG: The `index` of ResizablePanel should be one of in `state`.';
        final panelState = panels[panelIx];
        final sizeRange = sizeRangeValue;
        // A fixed panel needs a size to keep; without one it lays out as usual.
        final fixed = fixedValue && initialSize != null;
        final panelIx = this.panelIx;
        final axis = this.axis;

        final el = div()
            .id(ElementId.NamedInteger('resizable-panel', panelIx))
            .flex()
            .flexGrow1()
            .sizeFull()
            .relative()
            // Apply caller style overrides here: between the flex defaults
            // above and the size management below.
            .refineStyle(panelStyle);
        if (axis.isVertical()) {
            el.minH(gpui.Prelude.px(sizeRange.start)).maxH(gpui.Prelude.px(sizeRange.end));
        }
        if (axis.isHorizontal()) {
            el.minW(gpui.Prelude.px(sizeRange.start)).maxW(gpui.Prelude.px(sizeRange.end));
        }
        // 1. initial_size is None, to use auto size.
        // 2. initial_size is Some and size is none, to use the initial size of the panel for first time render.
        // 3. initial_size is Some and size is Some, use `size`.
        if (initialSize == null) el.flexShrink1();
        if (initialSize != null) {
            // The `self.size` is None, that mean the initial size for the panel,
            // so we need set `flex_shrink_0` To let it keep the initial size.
            if (panelState.size == null && (initialSize : Float) != 0.) {
                el.flexNone();
            }
            el.flexBasis(gpui.Prelude.px(initialSize));
        }
        if (panelState.size != null) {
            el.flexBasis(gpui.Prelude.px(MathUtil.max(MathUtil.min(panelState.size, sizeRange.end), sizeRange.start)));
        }
        // A fixed panel neither grows nor shrinks with the container, so the
        // first frame of a resize already has its size. Not `flexNone`, which
        // also resets the basis set above.
        if (fixed) el.flexGrow0().flexShrink0();
        el.onPrepaint((bounds, _, cx) -> {
            if (!state.read(cx).panelSizeChanges(panelIx, bounds, sizeRange, fixed)) {
                return;
            }
            state.update(cx, (state, cx) -> state.updatePanelSize(panelIx, bounds, sizeRange, fixed, cx));
        });
        el.extend(childElements);
        if (panelIx > 0) {
            final ix = panelIx - 1;
            final handle = ResizeHandle.resizeHandle(ElementId.NamedInteger('resizable-handle', ix), axis);
            if (handleAppearance != null) handle.withAppearance(handleAppearance);
            handle.onDrag(new DragPanel(), (_, _, _, cx) -> {
                cx.stopPropagation();
                // Set current resizing panel ix
                state.update(cx, (state, _) -> {
                    state.resizingPanelIx = ix;
                });
                return cx.newEntity((_:gpui.Context<DragPanelView>) -> new DragPanelView());
            });
            el.child(handle);
        }
        return el;
    }

}

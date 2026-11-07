// Ported from gpui-kit 0.8.1: crates/base/src/resizable/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-022 (a panel laid out at PANEL_MIN_SIZE does not notify every frame). See DEVIATIONS.md.
package glaze.kit.base.resizable;

import glaze.Axis;
import glaze.Bounds;
import glaze.Context;
import glaze.Model;
import glaze.Pixels;
import glaze.Window;
import glaze.kit.base.resizable.ResizablePanelGroup.ResizablePanelEvent;
import glaze.util.MathUtil;

import glaze.Prelude.*;

/**
 * State for a `ResizablePanel`.
 *
 * Emits `ResizablePanelEvent`. Like the original, every change notifies
 * the entity (`notifyChanged`). GPUI then invalidates every view that read
 * the state while drawing (its accessed entities); the port's views track
 * observable fields instead, so a change also bumps `changes`, which the
 * group reads when it renders.
 */
class ResizableState extends Model {

    /**
     * The `axis` will sync to actual axis of the ResizablePanelGroup in use.
     */
    @:allow(glaze.kit.base.resizable, tests)
    var axis:Axis = Horizontal;

    @:allow(glaze.kit.base.resizable, tests)
    var panels:Array<ResizablePanelState> = [];

    @:allow(glaze.kit.base.resizable, tests)
    var sizesValue:Array<Float> = [];

    @:allow(glaze.kit.base.resizable, tests)
    var resizingPanelIx:Null<Int> = null;

    @:allow(glaze.kit.base.resizable, tests)
    var bounds:Bounds = new Bounds();

    /**
     * Bumped by every change, read by the group that renders the state.
     */
    @:allow(glaze.kit.base.resizable, tests)
    @observe var changes:Int = 0;

    public function new() {
        super();
    }

    /**
     * Rust `cx.notify()` on the state: notifies its observers and the views
     * that rendered it.
     */
    @:allow(glaze.kit.base.resizable, tests)
    function notifyChanged(cx:Context<ResizableState>):Void {
        changes = changes + 1;
        cx.notify();
    }

    /**
     * Get the size of the panels.
     */
    public function sizes():Array<Pixels> {
        return cast sizesValue;
    }

    /**
     * Programmatically resize the panel at `ix` to `size`, redistributing
     * space among siblings using the same logic as a drag.
     *
     * Sizes are clamped to the panel's `size_range` and to the container.
     * Emits `ResizablePanelEvent.Resized` so subscribers (e.g. preference
     * persistence) see the change just as if the user had dragged a handle.
     *
     * Out-of-range indices are a no-op. For the last panel, space is taken
     * from the previous sibling (the last panel has no handle of its own).
     */
    public function resizePanel(ix:Int, size:Pixels, window:Window, cx:Context<ResizableState>):Void {
        if (ix >= sizesValue.length) {
            return;
        }
        if (ix + 1 < sizesValue.length) {
            resizePanelAtHandle(ix, size, window, cx);
        } else if (ix > 0) {
            // Last panel: drive its size by resizing the previous sibling so
            // the freed space lands here.
            final delta:Float = f32(sizesValue[ix] - (size : Float));
            final prev:Float = sizesValue[ix - 1];
            resizePanelAtHandle(ix - 1, f32(prev + delta), window, cx);
        }
        doneResizing(cx);
    }

    /**
     * Insert a panel state at `ix`, or append it when no index is supplied.
     *
     * Existing panel sizes are redistributed so their total remains equal to
     * the current container size.
     */
    public function insertPanel(size:Null<Pixels>, ix:Null<Int>, cx:Context<ResizableState>):Void {
        final panelState = new ResizablePanelState();
        panelState.size = size;

        final size:Float = size != null ? (size : Float) : (Resizable.PANEL_MIN_SIZE : Float);

        // We make sure that the size always sums up to the container size
        // by reducing the size of all other panels first.
        final containerSize:Float = MathUtil.max(containerSize(), 1.);
        final totalLeftoverSize:Float = MathUtil.max(f32(containerSize - size), 1.);

        for (i in 0...panels.length) {
            final ratio = f32(sizesValue[i] / containerSize);
            sizesValue[i] = f32(totalLeftoverSize * ratio);
            panels[i].size = sizesValue[i];
        }

        if (ix != null) {
            panels.insert(ix, panelState);
            sizesValue.insert(ix, size);
        } else {
            panels.push(panelState);
            sizesValue.push(size);
        }

        notifyChanged(cx);
    }

    /**
     * Adopt slot sizes decided by an owner that keeps its own record of the
     * layout (the dock's pane tree does).
     *
     * Unlike `insertPanel`, nothing is redistributed: the caller has already
     * decided how the space divides. Slots the caller left unconstrained keep
     * whatever they had.
     */
    @:allow(glaze.kit.base, glaze.kit, tests)
    function adoptSizes(sizes:Array<Null<Pixels>>, cx:Context<ResizableState>):Void {
        var changed = false;
        for (ix in 0...sizes.length) {
            final size = sizes[ix];
            // The preference is mirrored exactly, `null` included.
            if (ix < panels.length) {
                final panel = panels[ix];
                if (!sameOptionalSize(panel.size, size)) {
                    panel.size = size;
                    changed = true;
                }
            }

            // The measurement only moves when the tree names a size.
            if (size == null) continue;
            if (ix < sizesValue.length) {
                if ((sizesValue[ix] : Float) != (size : Float)) {
                    sizesValue[ix] = size;
                    changed = true;
                }
            }
        }

        if (changed) {
            notifyChanged(cx);
        }
    }

    /**
     * `Pixels` arithmetic is `f32` in GPUI: every result is rounded like one.
     */
    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    static inline function sameOptionalSize(a:Null<Pixels>, b:Null<Pixels>):Bool {
        return a == null ? b == null : (b != null && (a : Float) == (b : Float));
    }

    @:allow(glaze.kit.base.resizable, tests)
    function syncPanelsCount(axis:Axis, panelsCount:Int, cx:Context<ResizableState>):Void {
        var changed = this.axis != axis;
        this.axis = axis;

        if (panelsCount > panels.length) {
            final diff = panelsCount - panels.length;
            for (_ in 0...diff) {
                panels.push(new ResizablePanelState());
                sizesValue.push(Resizable.PANEL_MIN_SIZE);
            }
            changed = true;
        }

        if (panelsCount < panels.length) {
            panels.resize(panelsCount);
            sizesValue.resize(panelsCount);
            changed = true;
        }

        if (changed) {
            // We need to make sure the total size is in line with the container size.
            adjustToContainerSize(cx);
        }
    }

    /**
     * Whether `updatePanelSize` with these arguments would change anything.
     * A panel reports its bounds as it prepaints, every frame it is drawn;
     * updating the state for the same bounds would mark it, and every view
     * that reads it, changed on every frame.
     */
    @:allow(glaze.kit.base.resizable, tests)
    function panelSizeChanges(panelIx:Int, bounds:Bounds, sizeRange:PixelsRange, fixed:Bool):Bool {
        if (panelIx >= panels.length) {
            return true;
        }
        final panel = panels[panelIx];
        // Deliberate deviation DEV-022: a stored size of PANEL_MIN_SIZE (the
        // placeholder of a panel not measured yet) is a change only when
        // `updatePanelSize` would adopt another size; a panel laid out at
        // exactly PANEL_MIN_SIZE no longer updates and notifies every frame.
        final size:Float = bounds.size.along(axis);
        return (panelIx < sizesValue.length && (sizesValue[panelIx] : Float) == (Resizable.PANEL_MIN_SIZE : Float)
                && (size != (Resizable.PANEL_MIN_SIZE : Float) || !sameOptionalSize(panel.size, size)))
            || !panel.bounds.equals(bounds)
            || !panel.sizeRange.equals(sizeRange)
            || panel.fixed != fixed;
    }

    @:allow(glaze.kit.base.resizable, tests)
    function updatePanelSize(panelIx:Int, bounds:Bounds, sizeRange:PixelsRange, fixed:Bool, cx:Context<ResizableState>):Void {
        panels[panelIx].fixed = fixed;
        final size:Float = bounds.size.along(axis);
        // This check is only necessary to stop the very first panel from resizing on its own
        // it needs to be passed when the panel is freshly created so we get the initial size,
        // but its also fine when it sometimes passes later.
        if ((sizesValue[panelIx] : Float) == (Resizable.PANEL_MIN_SIZE : Float)) {
            sizesValue[panelIx] = size;
            panels[panelIx].size = size;
        }
        panels[panelIx].bounds = bounds;
        panels[panelIx].sizeRange = sizeRange;
        notifyChanged(cx);
    }

    /**
     * Remove the panel at `panelIx` and redistribute the remaining space.
     */
    public function removePanel(panelIx:Int, cx:Context<ResizableState>):Void {
        panels.splice(panelIx, 1);
        sizesValue.splice(panelIx, 1);
        if (resizingPanelIx != null) {
            if (resizingPanelIx > panelIx) {
                resizingPanelIx = resizingPanelIx - 1;
            }
        }
        adjustToContainerSize(cx);
    }

    /**
     * Reset the panel at `panelIx` while preserving its current size.
     */
    public function resetPanel(panelIx:Int, cx:Context<ResizableState>):Void {
        final oldSize = sizesValue[panelIx];

        panels[panelIx] = new ResizablePanelState();
        sizesValue[panelIx] = oldSize;
        adjustToContainerSize(cx);
    }

    /**
     * Remove all panel state.
     */
    public function clear():Void {
        panels.resize(0);
        sizesValue.resize(0);
    }

    /**
     * Return the measured size of the group along its resize axis.
     */
    public inline function containerSize():Pixels {
        return bounds.size.along(axis);
    }

    @:allow(glaze.kit.base.resizable, tests)
    function doneResizing(cx:Context<ResizableState>):Void {
        resizingPanelIx = null;
        cx.emit(ResizablePanelEvent.Resized);
    }

    function panelSizeRange(ix:Int):PixelsRange {
        if (ix >= panels.length) {
            return new PixelsRange(Resizable.PANEL_MIN_SIZE, Pixels.MAX);
        }
        return panels[ix].sizeRange;
    }

    function syncRealPanelSizes():Void {
        for (i in 0...panels.length) {
            sizesValue[i] = panels[i].bounds.size.along(axis);
        }
    }

    /**
     * Resize the panel at `ix` by treating `ix` as the drag-handle position
     * (the handle that sits between panel `ix` and panel `ix + 1`). Returns
     * early on the last panel since there is no handle below it.
     *
     * This is the worker behind drag interactions and the public
     * `resizePanel` API.
     */
    @:allow(glaze.kit.base.resizable, tests)
    function resizePanelAtHandle(ix:Int, size:Pixels, window:Window, cx:Context<ResizableState>):Void {
        final oldSizes = sizesValue.copy();
        final size:Float = size;

        var ix = ix;
        // Only resize the left panels.
        if (ix >= oldSizes.length - 1) {
            return;
        }
        final containerSize:Float = containerSize();
        syncRealPanelSizes();

        final moveChanged = f32(size - oldSizes[ix]);
        if (moveChanged == 0.) {
            return;
        }

        final sizeRange = panelSizeRange(ix);
        final newSize = MathUtil.clamp(size, sizeRange.start, sizeRange.end);
        final isExpand = moveChanged > 0.;

        final mainIx = ix;
        final newSizes = oldSizes.copy();

        if (isExpand) {
            var changed = f32(newSize - oldSizes[ix]);
            newSizes[ix] = newSize;

            while (changed > 0. && ix < oldSizes.length - 1) {
                ix += 1;
                // A fixed panel only gives up space to a drag on its own handle.
                if (panels[ix].fixed && ix != mainIx + 1) {
                    continue;
                }
                final sizeRange = panelSizeRange(ix);
                final availableSize = MathUtil.max(f32(newSizes[ix] - sizeRange.start), 0.);
                final toReduce = MathUtil.min(changed, availableSize);
                newSizes[ix] = f32(newSizes[ix] - toReduce);
                changed = f32(changed - toReduce);
            }
        } else {
            var changed = f32(newSize - size);
            newSizes[ix] = newSize;

            while (changed > 0. && ix > 0) {
                ix -= 1;
                if (panels[ix].fixed) {
                    continue;
                }
                final sizeRange = panelSizeRange(ix);
                final availableSize = MathUtil.max(f32(newSizes[ix] - sizeRange.start), 0.);
                final toReduce = MathUtil.min(changed, availableSize);
                changed = f32(changed - toReduce);
                newSizes[ix] = f32(newSizes[ix] - toReduce);
            }

            newSizes[mainIx + 1] = f32(newSizes[mainIx + 1] + f32(f32(oldSizes[mainIx] - size) - changed));
        }

        // If total size exceeds container size, adjust the main panel
        var totalSize = 0.;
        for (s in newSizes) totalSize = f32(totalSize + s);
        if (totalSize > containerSize) {
            final overflow = f32(totalSize - containerSize);
            newSizes[mainIx] = MathUtil.max(f32(newSizes[mainIx] - overflow), sizeRange.start);
        }

        for (i in 0...oldSizes.length) {
            panels[i].size = newSizes[i];
        }
        sizesValue = newSizes;
        notifyChanged(cx);
    }

    /**
     * Adjust panel sizes according to the container size.
     *
     * When the container size changes, the panels should take up the same percentage as they did before.
     */
    @:allow(glaze.kit.base.resizable, tests)
    function adjustToContainerSize(cx:Context<ResizableState>):Void {
        if ((containerSize() : Float) == 0.) {
            return;
        }

        // A panel with no size preference is laid out by flex, and its entry
        // in `sizes` is a placeholder until something measures it. Flex
        // already fits the container, so there is nothing here to adjust.
        for (panel in panels) {
            if (panel.size == null) return;
        }

        // Fixed panels keep their size; the other panels share what is left
        // in the same proportions as before. A container too small for the
        // fixed panels leaves every size alone, so the proportions survive
        // until it grows again.
        var fixedSize = 0.;
        var total = 0.;
        for (i in 0...panels.length) {
            if (i >= sizesValue.length) break;
            if (panels[i].fixed) fixedSize = f32(fixedSize + sizesValue[i]) else total = f32(total + sizesValue[i]);
        }
        if (!Math.isFinite(total) || total <= 0.) {
            return;
        }
        final totalSize = total;
        final available:Float = f32((containerSize() : Float) - fixedSize);
        if (available <= 0.) {
            return;
        }

        for (i in 0...panels.length) {
            if (panels[i].fixed) {
                panels[i].size = sizesValue[i];
                continue;
            }
            final size = sizesValue[i];
            final ratio = f32(size / totalSize);
            final newSize = f32(available * ratio);

            sizesValue[i] = newSize;
            panels[i].size = newSize;
        }
        notifyChanged(cx);
    }

}

/**
 * The state of one panel of a `ResizableState`.
 */
@:allow(glaze.kit.base.resizable, tests)
class ResizablePanelState {

    public var size:Null<Pixels> = null;

    public var sizeRange:PixelsRange = new PixelsRange(0., 0.);

    var bounds:Bounds = new Bounds();

    /**
     * See `ResizablePanel.fixed`.
     */
    var fixed:Bool = false;

    public function new() {}

}

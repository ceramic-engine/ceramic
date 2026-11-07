// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_placement.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.Pixels;
import glaze.kit.base.resizable.Resizable;
import glaze.util.MathUtil;

/**
 * Runtime state for one dock: whether it is open, collapsible, its current
 * size, and whether it is mid-resize.
 *
 * This does not include the dock's placement or its panel content. `DockArea`
 * owns one of these per dock, paired with that dock's `PaneTree` and keyed
 * by its `DockPlacement`. Rust `Copy`: use `copy()` for a value copy.
 */
class Dock {

    var open:Bool = true;

    var collapsible:Bool = true;

    var sizeValue:Pixels;

    var liveSizeValue:Null<Pixels> = null;

    var resizing:Bool = false;

    public function new(size:Pixels) {
        sizeValue = size;
    }

    public function copy():Dock {
        final dock = new Dock(sizeValue);
        dock.open = open;
        dock.collapsible = collapsible;
        dock.liveSizeValue = liveSizeValue;
        dock.resizing = resizing;
        return dock;
    }

    public inline function isOpen():Bool {
        return open;
    }

    public inline function setOpen(open:Bool):Void {
        this.open = open;
    }

    public inline function isCollapsible():Bool {
        return collapsible;
    }

    public inline function setCollapsible(collapsible:Bool):Void {
        this.collapsible = collapsible;
    }

    public inline function size():Pixels {
        return sizeValue;
    }

    /**
     * Set the dock's size, never below `PANEL_MIN_SIZE`.
     *
     * The floor is here rather than at the call sites because
     * `DockArea.setDockSize` is public and unclamped: a smaller value would
     * collapse the dock to nothing, the skin clips the resize handle that
     * would drag it back out, and the collapsed size persists.
     */
    public function setSize(size:Pixels):Void {
        sizeValue = MathUtil.max(size, Resizable.PANEL_MIN_SIZE);
    }

    /**
     * A size below `PANEL_MIN_SIZE` that a drag in progress is showing. It is
     * never persisted: the drag's release settles it into either a closed
     * dock or one at the minimum.
     */
    @:allow(glaze.kit.base.dock)
    inline function liveSize():Null<Pixels> {
        return liveSizeValue;
    }

    @:allow(glaze.kit.base.dock)
    inline function setLiveSize(size:Null<Pixels>):Void {
        liveSizeValue = size;
    }

    public inline function isResizing():Bool {
        return resizing;
    }

    public inline function setResizing(resizing:Bool):Void {
        this.resizing = resizing;
    }

}

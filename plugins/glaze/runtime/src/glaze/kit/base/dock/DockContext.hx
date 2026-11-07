// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_area.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.App;
import glaze.Pixels;
import glaze.Point;
import glaze.Window;

/**
 * What a skin needs to draw one dock, and the callbacks it invokes rather
 * than reimplementing the open/close and clamping behavior.
 */
class DockContext {

    final placementValue:DockPlacement;

    final sizeValue:Pixels;

    final open:Bool;

    final collapsible:Bool;

    final onToggle:(Window, App) -> Void;

    final onResize:(Point, Window, App) -> Void;

    final onResizeEnd:(Window, App) -> Void;

    @:allow(glaze.kit.base.dock)
    function new(placement:DockPlacement, size:Pixels, open:Bool, collapsible:Bool, onToggle:(Window, App) -> Void,
            onResize:(Point, Window, App) -> Void, onResizeEnd:(Window, App) -> Void) {
        this.placementValue = placement;
        this.sizeValue = size;
        this.open = open;
        this.collapsible = collapsible;
        this.onToggle = onToggle;
        this.onResize = onResize;
        this.onResizeEnd = onResizeEnd;
    }

    public inline function placement():DockPlacement {
        return placementValue;
    }

    /**
     * The dock's extent along its own axis: width for left/right, height for
     * bottom.
     */
    public inline function size():Pixels {
        return sizeValue;
    }

    public inline function isOpen():Bool {
        return open;
    }

    public inline function isCollapsible():Bool {
        return collapsible;
    }

    public function toggle(window:Window, cx:App):Void {
        onToggle(window, cx);
    }

    /**
     * Resize from a pointer position in window coordinates. Base clamps it
     * against the area bounds and the opposite dock.
     */
    public function resizeTo(pointer:Point, window:Window, cx:App):Void {
        onResize(pointer, window, cx);
    }

    /**
     * End a resize started with `resizeTo`. A bottom dock dragged below its
     * minimum snaps shut or to the minimum, whichever is nearer.
     */
    public function endResize(window:Window, cx:App):Void {
        onResizeEnd(window, cx);
    }

}

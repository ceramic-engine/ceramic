// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_placement.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.Bounds;
import gpui.Pixels;
import gpui.Point;
import gpui.Size;
import gpui.SpringMath;
import gpui.base.resizable.Resizable;
import gpui.util.MathUtil;

/**
 * Pure arithmetic for resizing one dock (left/right/bottom). The caller
 * supplies the area bounds and the opposite dock's size; base does not reach
 * across entities to find them.
 *
 * This decides how big a dock is allowed to be. It draws nothing: the
 * resize-handle chrome lives in the component layer. Rust `Copy`; the
 * builders return a new value.
 */
class DockSizing {

    final placement:DockPlacement;

    final area:Bounds;

    final oppositeDockSize:Pixels;

    public function new(placement:DockPlacement, ?area:Bounds, oppositeDockSize:Pixels = 0.) {
        this.placement = placement;
        this.area = area != null ? area : new Bounds();
        this.oppositeDockSize = oppositeDockSize;
    }

    /**
     * Set the full area bounds (origin and size).
     */
    public function withAreaBounds(area:Bounds):DockSizing {
        return new DockSizing(placement, area, oppositeDockSize);
    }

    /**
     * Set only the area's width, leaving its origin and height untouched.
     */
    public function withAreaWidth(width:Pixels):DockSizing {
        return new DockSizing(placement, new Bounds(area.origin, new Size(width, area.size.height)), oppositeDockSize);
    }

    /**
     * Set only the area's height, leaving its origin and width untouched.
     */
    public function withAreaHeight(height:Pixels):DockSizing {
        return new DockSizing(placement, new Bounds(area.origin, new Size(area.size.width, height)), oppositeDockSize);
    }

    /**
     * Set the size of the dock on the opposite side (right, for a left
     * dock; left, for a right dock). Bottom docks have no opposite side.
     */
    public function withOppositeDockSize(size:Pixels):DockSizing {
        return new DockSizing(placement, area, size);
    }

    /**
     * The dock size the pointer implies, before clamping.
     *
     * `DockPlacement.Center` names the canvas, which has no edge to measure
     * from and no dock size, so it answers zero rather than failing.
     */
    public function sizeFromPointer(pointer:Point):Pixels {
        return switch placement {
            case Left: SpringMath.f32(pointer.x - area.left());
            case Right: SpringMath.f32(area.right() - pointer.x);
            case Bottom: SpringMath.f32(area.bottom() - pointer.y);
            case Center: 0.;
        }
    }

    /**
     * Clamp a size into the range this dock may occupy: never below
     * `PANEL_MIN_SIZE`, and never so large it would squeeze the opposite
     * dock (if any) below `PANEL_MIN_SIZE` either. The `max(PANEL_MIN_SIZE)`
     * on the computed maximum keeps the clamp range non-empty when the area
     * is narrower than both minimums combined.
     *
     * `DockPlacement.Center` constrains nothing, so it hands the size back
     * unchanged.
     */
    public function clamp(size:Pixels):Pixels {
        final min:Float = Resizable.PANEL_MIN_SIZE;
        if (placement == DockPlacement.Center) return size;
        final maxSize:Float = if (placement == DockPlacement.Bottom) {
            MathUtil.max(SpringMath.f32(area.size.height - min), min);
        }
        else {
            MathUtil.max(SpringMath.f32(SpringMath.f32(area.size.width - min) - (oppositeDockSize : Float)), min);
        }
        // Rust `f32::clamp`
        return MathUtil.clamp(size, min, maxSize);
    }

}

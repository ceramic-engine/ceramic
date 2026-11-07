// Ported from gpui-kit 0.8.1: crates/base/src/dock/drag.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.Bounds;
import gpui.Point;
import gpui.SpringMath;
import gpui.base.Geometry.Placement;

/**
 * Drag hit-testing for the dock: the free function and constant of
 * `drag.rs` (the types are `DragPanel`, `AnyDrag`, `DropTarget`,
 * `DropIndicator` and `DropPlaceholderBounds`).
 *
 * This decides where a drop would land. It draws nothing: the styled drag
 * preview and the rendered drop indicator live in the component layer.
 */
class Drag {

    /**
     * Stands in for `DragPanel.dragSessionId` on host-owned drag items, which
     * carry no session of their own. Session ids start at 1, so 0 never
     * collides.
     */
    @:allow(gpui.base.dock, tests)
    static inline final ITEM_DRAG_SESSION_ID:Int = 0;

    /**
     * Which split zone `position` falls into within `bounds`, or `null` for
     * the centre zone (merge into the tab group rather than split).
     */
    @:allow(gpui.base.dock, tests)
    static function splitPlacementAt(bounds:Bounds, position:Point):Null<Placement> {
        final width = bounds.size.width;
        final height = bounds.size.height;
        return if (position.x < SpringMath.f32(bounds.left() + SpringMath.f32(width * SpringMath.f32(0.35)))) {
            Placement.Left;
        }
        else if (position.x > SpringMath.f32(bounds.left() + SpringMath.f32(width * SpringMath.f32(0.65)))) {
            Placement.Right;
        }
        else if (position.y < SpringMath.f32(bounds.top() + SpringMath.f32(height * SpringMath.f32(0.35)))) {
            Placement.Top;
        }
        else if (position.y > SpringMath.f32(bounds.top() + SpringMath.f32(height * SpringMath.f32(0.65)))) {
            Placement.Bottom;
        }
        else {
            null;
        }
    }

}

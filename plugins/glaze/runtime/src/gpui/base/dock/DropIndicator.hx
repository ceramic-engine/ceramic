// Ported from gpui-kit 0.8.1: crates/base/src/dock/drag.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.Bounds;
import gpui.base.Geometry.Placement;

/**
 * What the skin should draw while a drag hovers a group.
 *
 * It carries geometry over time (where the placeholder comes from, where it
 * settles, and which run of the animation this is) but not the tween. Easing
 * and duration are styling and belong to the skin that draws it.
 */
class DropIndicator {

    final boundsValue:Bounds;

    final placementValue:Null<Placement>;

    final fromValue:DropPlaceholderBounds;

    final toValue:DropPlaceholderBounds;

    final dragSessionIdValue:Int;

    final epochValue:Int;

    @:allow(gpui.base.dock, tests)
    function new(bounds:Bounds, placement:Null<Placement>, from:DropPlaceholderBounds, to:DropPlaceholderBounds, dragSessionId:Int, epoch:Int) {
        this.boundsValue = bounds;
        this.placementValue = placement;
        this.fromValue = from;
        this.toValue = to;
        this.dragSessionIdValue = dragSessionId;
        this.epochValue = epoch;
    }

    /**
     * The hovered group's content bounds, in window coordinates.
     */
    public inline function bounds():Bounds {
        return boundsValue;
    }

    /**
     * `null` means the drop merges into the tab group.
     */
    public inline function placement():Null<Placement> {
        return placementValue;
    }

    /**
     * Where the placeholder starts, relative to `bounds`.
     */
    public inline function from():DropPlaceholderBounds {
        return fromValue;
    }

    /**
     * Where the placeholder settles, relative to `bounds`.
     */
    public inline function to():DropPlaceholderBounds {
        return toValue;
    }

    /**
     * Which drag session this indicator belongs to. Host-owned drag items
     * share `Drag.ITEM_DRAG_SESSION_ID`.
     */
    public inline function dragSessionId():Int {
        return dragSessionIdValue;
    }

    /**
     * Bumped on every restart, so an animation keyed on it replays instead of
     * resuming when the target placement changes.
     */
    public inline function epoch():Int {
        return epochValue;
    }

    public function equals(other:DropIndicator):Bool {
        return boundsValue.equals(other.boundsValue) && placementValue == other.placementValue && fromValue.equals(other.fromValue)
            && toValue.equals(other.toValue) && dragSessionIdValue == other.dragSessionIdValue && epochValue == other.epochValue;
    }

}

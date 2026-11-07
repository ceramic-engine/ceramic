// Ported from gpui-kit 0.8.1: crates/base/src/dock/drag.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.kit.base.Geometry.Placement;

/**
 * Where a host-owned drag landed: a tab group, and the edge it resolved.
 *
 * A split layout has no free coordinates, so the container reports the group
 * and the placement instead of a position. `placement` is `null` for the
 * centre zone, meaning merge into the group rather than split.
 */
class DropTarget {

    final nodeValue:NodeId;

    final placementValue:Null<Placement>;

    @:allow(glaze.kit.base.dock, tests)
    function new(node:NodeId, placement:Null<Placement>) {
        this.nodeValue = node;
        this.placementValue = placement;
    }

    public inline function node():NodeId {
        return nodeValue;
    }

    public inline function placement():Null<Placement> {
        return placementValue;
    }

    public function equals(other:DropTarget):Bool {
        return nodeValue == other.nodeValue && placementValue == other.placementValue;
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/edit.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.Pixels;
import glaze.kit.base.Geometry.Placement;

/**
 * Where a panel should land.
 */
enum InsertTarget {
    /**
     * Into an existing tab group, optionally at a specific index.
     */
    Tabs(node:NodeId, ix:Null<Int>, activate:Bool);

    /**
     * Beside an existing node, creating a new tab group for the panel.
     */
    Split(node:NodeId, placement:Placement, size:Null<Pixels>);
}

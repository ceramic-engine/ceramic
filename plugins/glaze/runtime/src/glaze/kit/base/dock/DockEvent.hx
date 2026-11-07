// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_area.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

/**
 * What the dock area reports outward.
 */
enum DockEvent {
    /**
     * The layout changed. Subscribe to persist it; this fires on every edit,
     * so a subscriber that writes to disk should debounce.
     */
    LayoutChanged;

    /**
     * A host-owned drag item was dropped inside the dock.
     */
    DragDrop(item:AnyDrag, target:DropTarget);
}

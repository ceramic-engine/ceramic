// Ported from gpui-kit 0.8.1: crates/base/src/dock/tab_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

/**
 * Behavior a tab group cannot carry out on its own.
 *
 * Every variant here ends in an edit to the layout tree, and the tree belongs
 * to the container that owns this group. Reporting the intent instead of
 * reaching for the container keeps the whole detach-then-reinsert dance (and
 * the reentrancy it used to provoke) out of the group entirely.
 */
enum TabGroupEvent {
    /**
     * A panel was dropped on this group. `target` says where in the tree it
     * lands; the container applies it as a single `PaneTree.movePanel`.
     */
    Drop(panel:PanelId, source:NodeId, target:InsertTarget);

    /**
     * A host-owned drag landed on this group.
     */
    DragDrop(item:AnyDrag, target:DropTarget);

    /**
     * The user asked to close `panel`.
     */
    ClosePanel(panel:PanelId);

    /**
     * The displayed tab changed, so the tree's stored `activeIx` is stale.
     */
    ActiveChanged(ix:Int);

    /**
     * This group asked to fill the whole dock. The container installs the
     * group as its zoomed view, chrome and all: the tab bar is where the
     * control that zooms back out lives.
     */
    ZoomIn;

    /**
     * This group gave the dock back.
     */
    ZoomOut;
}

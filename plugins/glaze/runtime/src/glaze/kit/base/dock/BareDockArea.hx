// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_area.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

/**
 * The renderer an area starts with: the layout and nothing else.
 */
class BareDockArea extends DockAreaRendererBase {

    public function tabGroupRenderer():TabGroupRenderer {
        return new BareTabGroup();
    }

}

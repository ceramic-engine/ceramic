// Ported from gpui-kit 0.8.1: crates/base/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.App;

/**
 * Reads panel properties out of the live entity map that `DockArea` keeps.
 *
 * This is the `PanelSource` implementation `PaneTree.toState` runs
 * against when `DockArea.dump` writes a live layout out.
 */
class LivePanels implements PanelSource {

    final panels:Map<Int, PanelView>;

    final cx:App;

    @:allow(gpui.base.dock)
    function new(panels:Map<Int, PanelView>, cx:App) {
        this.panels = panels;
        this.cx = cx;
    }

    public function panelName(id:PanelId):String {
        final panel = panels.get(id.asU64());
        return panel != null ? panel.panelName(cx) : '';
    }

    public function isVisible(id:PanelId):Bool {
        final panel = panels.get(id.asU64());
        return panel != null && panel.visible(cx);
    }

    public function dump(id:PanelId):PanelState {
        final panel = panels.get(id.asU64());
        return panel != null ? panel.dump(cx) : PanelState.defaultValue();
    }

}

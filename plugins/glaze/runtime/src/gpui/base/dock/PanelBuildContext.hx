// Ported from gpui-kit 0.8.1: crates/base/src/dock/registry.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.WeakEntity;

/**
 * Everything a panel builder needs to reconstruct a panel from persisted data.
 */
class PanelBuildContext {

    final dockAreaValue:WeakEntity<DockArea>;

    final stateValue:PanelState;

    final infoValue:PanelInfo;

    public function new(dockArea:WeakEntity<DockArea>, state:PanelState, info:PanelInfo) {
        this.dockAreaValue = dockArea;
        this.stateValue = state;
        this.infoValue = info;
    }

    public inline function dockArea():WeakEntity<DockArea> {
        return dockAreaValue;
    }

    public inline function state():PanelState {
        return stateValue;
    }

    public inline function info():PanelInfo {
        return infoValue;
    }

}

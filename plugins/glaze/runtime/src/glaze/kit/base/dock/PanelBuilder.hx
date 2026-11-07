// Ported from gpui-kit 0.8.1: crates/base/src/dock/state_convert.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

/**
 * Turns a persisted leaf into a live panel id.
 *
 * The production implementation (`DockArea.load`) consults `PanelRegistry`
 * and falls back to an invalid-panel placeholder that retains the original
 * `PanelState`, so a panel type this build does not know about survives a
 * load/save round trip instead of being erased.
 */
interface PanelBuilder {

    function build(state:PanelState, info:PanelInfo):PanelId;

}

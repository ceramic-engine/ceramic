// Ported from gpui-kit 0.8.1: crates/base/src/dock/state_convert.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

/**
 * How the layout tree reads properties of panels it only knows by id.
 *
 * Keeping this behind an interface is what lets the whole layout algebra be
 * tested without an `App`.
 */
interface PanelSource {

    function panelName(id:PanelId):String;

    function isVisible(id:PanelId):Bool;

    function dump(id:PanelId):PanelState;

}

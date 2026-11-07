// Ported from gpui-kit 0.8.1: crates/component/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

enum abstract PanelStyle(Int) {
    /**
     * Display the TabBar when there are multiple tabs, otherwise display the simple title.
     */
    var Auto;

    /**
     * Always display the tab bar.
     */
    var TabBar;

    /**
     * Rust `Default`.
     */
    public static inline function defaultValue():PanelStyle {
        return Auto;
    }
}

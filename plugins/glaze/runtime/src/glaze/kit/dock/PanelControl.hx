// Ported from gpui-kit 0.8.1: crates/component/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

enum abstract PanelControl(Int) {
    var Both;
    var Menu;
    var Toolbar;

    /**
     * Rust `Default`.
     */
    public static inline function defaultValue():PanelControl {
        return Menu;
    }

    public inline function toolbarVisible():Bool {
        return (cast this : PanelControl) == Both || (cast this : PanelControl) == Toolbar;
    }

    public inline function menuVisible():Bool {
        return (cast this : PanelControl) == Both || (cast this : PanelControl) == Menu;
    }
}

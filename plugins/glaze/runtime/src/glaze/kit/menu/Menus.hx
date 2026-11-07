// Ported from gpui-kit 0.8.1: crates/component/src/menu/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.menu;

import gpui.AppContext;

/**
 * The `menu` module of gpui-component: `PopupMenu` / `PopupMenuItem`,
 * `ContextMenu` (`using gpui.component.menu.ContextMenu.ContextMenuExt;`),
 * `DropdownMenu` (`using gpui.component.menu.DropdownMenu;`) and
 * `AppMenuBar`.
 *
 * Named `Menus` so that it does not shadow GPUI's `gpui.Menu`.
 */
class Menus {

    /**
     * Registers the key bindings of the menus (called by `Component.init`).
     */
    public static function init(cx:AppContext):Void {
        AppMenuBar.init(cx);
        PopupMenu.init(cx);
    }

}

// Ported from gpui-kit 0.8.1: crates/component/src/menu/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.menu;

import glaze.AppContext;

/**
 * The `menu` module of gpui-component: `PopupMenu` / `PopupMenuItem`,
 * `ContextMenu` (`using glaze.kit.menu.ContextMenu.ContextMenuExt;`),
 * `DropdownMenu` (`using glaze.kit.menu.DropdownMenu;`) and
 * `AppMenuBar`.
 *
 * Named `Menus` so that it does not shadow GPUI's `glaze.Menu`.
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

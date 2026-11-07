// Ported from gpui-kit 0.8.1: crates/component/src/sidebar/header.rs, crates/component/src/sidebar/footer.rs (impl DropdownMenu)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.sidebar;

import glaze.Anchor;
import glaze.ElementId;
import glaze.kit.menu.ContextMenu.MenuBuilder;
import glaze.kit.menu.DropdownMenu.DropdownMenuPopover;

/**
 * The `DropdownMenu` trait the original implements for `SidebarHeader` and
 * `SidebarFooter`, as a static extension:
 * `using glaze.kit.sidebar.SidebarDropdownMenu;`.
 */
class SidebarDropdownMenu {

    /** Create a dropdown menu with the given items, anchored to the TopLeft corner. */
    public static function dropdownMenu(self:SidebarHeader, f:MenuBuilder):DropdownMenuPopover {
        return dropdownMenuWithAnchor(self, TopLeft, f);
    }

    /** Create a dropdown menu with the given items, anchored to the given corner. */
    public static function dropdownMenuWithAnchor(self:SidebarHeader, anchor:Anchor, f:MenuBuilder):DropdownMenuPopover {
        // Rust `self.interactivity().element_id`: the header's base has no id
        // until it renders.
        final id:Null<ElementId> = @:privateAccess self.base.interactivity.elementId;
        return @:privateAccess new DropdownMenuPopover(id != null ? id : ElementId.Integer(0), anchor, self, f);
    }

}

/**
 * The `DropdownMenu` trait of `SidebarFooter`:
 * `using glaze.kit.sidebar.SidebarDropdownMenu.SidebarFooterDropdownMenu;`.
 */
class SidebarFooterDropdownMenu {

    /** Create a dropdown menu with the given items, anchored to the TopLeft corner. */
    public static function dropdownMenu(self:SidebarFooter, f:MenuBuilder):DropdownMenuPopover {
        return dropdownMenuWithAnchor(self, TopLeft, f);
    }

    /** Create a dropdown menu with the given items, anchored to the given corner. */
    public static function dropdownMenuWithAnchor(self:SidebarFooter, anchor:Anchor, f:MenuBuilder):DropdownMenuPopover {
        final id:Null<ElementId> = @:privateAccess self.base.interactivity.elementId;
        return @:privateAccess new DropdownMenuPopover(id != null ? id : ElementId.Integer(0), anchor, self, f);
    }

}

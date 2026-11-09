// Ported from gpui-kit 0.8.1: crates/component/src/sidebar/header.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.sidebar;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.Div;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Collapsible;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * Header for the `Sidebar`.
 *
 * Listeners go on `base` (Rust `InteractiveElement`). The `DropdownMenu` trait the original implements for it is
 * `SidebarDropdownMenu` (`using glaze.kit.sidebar.SidebarDropdownMenu;`).
 */
class SidebarHeader extends Component implements Styled implements ParentElement implements Selectable implements Collapsible {

    public final base:Div = div();

    final headerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    @prop var selected:Bool = false;

    @prop var collapsed:Bool = false;

    /**
     * Create a new `SidebarHeader`.
     */
    public function new() {
        super();
    }

    public function setSelected(selected:Bool):Void {
        this.selected = selected;
    }

    public function isSelected():Bool {
        return selected;
    }

    /** Rust `Selectable::set_open` default. */
    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    /** Rust `Selectable::is_open` default. */
    public function isOpen():Bool {
        return isSelected();
    }

    public function setCollapsed(collapsed:Bool):Void {
        this.collapsed = collapsed;
    }

    public function isCollapsed():Bool {
        return collapsed;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):SidebarHeader {
        if (child != null) childElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return headerStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final element = base
            .id('sidebar-header')
            .hFlex()
            .gap2()
            .p2()
            .wFull()
            .justifyBetween()
            .rounded(theme.radius)
            .refineStyle(headerStyle)
            .hover(s -> s.bg(theme.tokens.sidebarAccent.background).textColor(theme.sidebarAccentForeground));
        if (selected) {
            element.bg(theme.tokens.sidebarAccent.background).textColor(theme.sidebarAccentForeground);
        }
        element.extend(childElements);
        return element;
    }

}

// Ported from gpui-kit 0.8.1: crates/component/src/sidebar/header.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.sidebar;

import gpui.AnyElement;
import gpui.App;
import gpui.Div;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.ComponentTraits.Collapsible;
import gpui.base.ComponentTraits.Selectable;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * Header for the `Sidebar`.
 *
 * Listeners go on `base` (Rust `InteractiveElement`). The `DropdownMenu` trait the original implements for it is
 * `SidebarDropdownMenu` (`using gpui.component.sidebar.SidebarDropdownMenu;`).
 */
class SidebarHeader implements RenderOnce implements Styled implements ParentElement implements Selectable implements Collapsible {

    public final base:Div = div();

    final headerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var selectedValue:Bool = false;

    var collapsedValue:Bool = false;

    /**
     * Create a new `SidebarHeader`.
     */
    public function new() {}

    public function selected(selected:Bool):SidebarHeader {
        selectedValue = selected;
        return this;
    }

    public function setSelected(selected:Bool):Void {
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    /** Rust `Selectable::set_open` default. */
    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    /** Rust `Selectable::is_open` default. */
    public function isOpen():Bool {
        return isSelected();
    }

    public function collapsed(collapsed:Bool):SidebarHeader {
        collapsedValue = collapsed;
        return this;
    }

    public function setCollapsed(collapsed:Bool):Void {
        collapsedValue = collapsed;
    }

    public function isCollapsed():Bool {
        return collapsedValue;
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
        if (selectedValue) {
            element.bg(theme.tokens.sidebarAccent.background).textColor(theme.sidebarAccentForeground);
        }
        element.extend(childElements);
        return element;
    }

}

// Ported from gpui-kit 0.8.1: crates/component/src/sidebar/footer.rs
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

import gpui.base.Prelude.*;

/**
 * Footer for the `Sidebar`.
 *
 * Listeners and styles go on `base` (Rust `InteractiveElement` and `Styled`
 * forward to it). The `DropdownMenu` trait the original implements for it is
 * `SidebarDropdownMenu.SidebarFooterDropdownMenu`.
 */
class SidebarFooter implements RenderOnce implements Styled implements ParentElement implements Selectable implements Collapsible {

    public final base:Div = hFlex().gap2().wFull();

    var selectedValue:Bool = false;

    var collapsedValue:Bool = false;

    /**
     * Create a new `SidebarFooter`.
     */
    public function new() {}

    public function selected(selected:Bool):SidebarFooter {
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

    public function collapsed(collapsed:Bool):SidebarFooter {
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
        base.extend(elements);
    }

    public function child(child:IntoElement):SidebarFooter {
        base.child(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final element = hFlex()
            .id('sidebar-footer')
            .gap2()
            .p2()
            .wFull()
            .justifyBetween()
            .rounded(theme.radius)
            .hover(s -> s.bg(theme.tokens.sidebarAccent.background).textColor(theme.sidebarAccentForeground));
        if (selectedValue) {
            element.bg(theme.tokens.sidebarAccent.background).textColor(theme.sidebarAccentForeground);
        }
        return element.child(base);
    }

}

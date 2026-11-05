// Ported from gpui-kit 0.8.1: crates/component/src/sidebar/group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.sidebar;

import gpui.App;
import gpui.ElementId;
import gpui.IntoElement;
import gpui.Window;
import gpui.component.sidebar.Sidebar.SidebarItem;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.StyledExt;

/**
 * A group of items in the `Sidebar`.
 */
class SidebarGroup<E:SidebarItem> implements SidebarItem {

    final label:String;

    var collapsedValue:Bool = false;

    var childItems:Array<E> = [];

    /**
     * Create a new `SidebarGroup` with the given label.
     */
    public function new(label:String) {
        this.label = label;
    }

    /**
     * Add a child to the sidebar group, the child should implement `SidebarItem`.
     */
    public function child(child:E):SidebarGroup<E> {
        if (child != null) childItems.push(child);
        return this;
    }

    /**
     * Add multiple children to the sidebar group.
     *
     * See also `child`.
     */
    public function children(children:Iterable<E>):SidebarGroup<E> {
        for (child in children) if (child != null) childItems.push(child);
        return this;
    }

    public function collapsed(collapsed:Bool):SidebarGroup<E> {
        collapsedValue = collapsed;
        return this;
    }

    public function setCollapsed(collapsed:Bool):Void {
        collapsedValue = collapsed;
    }

    public function isCollapsed():Bool {
        return collapsedValue;
    }

    public function cloneItem():SidebarItem {
        final copy = new SidebarGroup<E>(label);
        copy.collapsedValue = collapsedValue;
        copy.childItems = [for (item in childItems) cast item.cloneItem()];
        return copy;
    }

    public function renderItem(id:ElementId, window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final idString = Sidebar.elementIdString(id);

        final group = vFlex().relative();
        if (!collapsedValue) {
            group.child(
                hFlex()
                    .flexShrink0()
                    .px2()
                    .rounded(theme.radius)
                    .textXs()
                    .textColor(theme.sidebarForeground.opacity(0.7))
                    .h8()
                    .child(label)
            );
        }
        final list = div()
            .gap2()
            .flexCol();
        for (ix in 0...childItems.length) {
            final child = childItems[ix];
            child.setCollapsed(collapsedValue);
            list.child(child.renderItem(ElementId.Name('$idString-$ix'), window, cx).intoAnyElement());
        }
        return group.child(list);
    }

}

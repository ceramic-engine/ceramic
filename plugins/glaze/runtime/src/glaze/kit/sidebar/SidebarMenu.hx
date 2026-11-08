// Ported from gpui-kit 0.8.1: crates/component/src/sidebar/menu.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.sidebar;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;
import glaze.kit.sidebar.Sidebar.SidebarItem;
import glaze.kit.theme.Theme;
import glaze.kit.tooltip.Tooltip;
import glaze.kit.tooltip.Tooltip.ManagedTooltip;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;
using glaze.kit.menu.ContextMenu.ContextMenuExt;

/**
 * Menu for the `Sidebar`.
 */
class SidebarMenu implements SidebarItem implements Styled {

    final menuStyle:StyleRefinement;

    var collapsedValue:Bool = false;

    var items:Array<SidebarMenuItem> = [];

    /**
     * Create a new SidebarMenu
     */
    public function new(?style:StyleRefinement) {
        menuStyle = style != null ? style : new StyleRefinement();
    }

    /**
     * Add a `SidebarMenuItem` child menu item to the sidebar menu.
     *
     * See also `children`.
     */
    public function child(child:SidebarMenuItem):SidebarMenu {
        if (child != null) items.push(child);
        return this;
    }

    /**
     * Add multiple `SidebarMenuItem` child menu items to the sidebar menu
     * (replaces the items added before, like the original).
     */
    public function children(children:Iterable<SidebarMenuItem>):SidebarMenu {
        items = glaze.util.Iterables.toArrayNonNull(children);
        return this;
    }

    public function isCollapsed():Bool {
        return collapsedValue;
    }

    public function setCollapsed(collapsed:Bool):Void {
        collapsedValue = collapsed;
    }

    public function collapsed(collapsed:Bool):SidebarMenu {
        collapsedValue = collapsed;
        return this;
    }

    public inline function style():StyleRefinement {
        return menuStyle;
    }

    public function cloneItem():SidebarItem {
        final copy = new SidebarMenu(menuStyle);
        copy.collapsedValue = collapsedValue;
        copy.items = [for (item in items) item.clone()];
        return copy;
    }

    public function renderItem(id:ElementId, window:Window, cx:App):IntoElement {
        final idString = Sidebar.elementIdString(id);
        final menu = vFlex()
            .gap2()
            .refineStyle(menuStyle);
        for (ix in 0...items.length) {
            final item = items[ix];
            final id = '$idString-$ix';
            item.setCollapsed(collapsedValue);
            menu.child(item.renderItem(ElementId.Name(id), window, cx).intoAnyElement());
        }
        return menu;
    }

}

/**
 * Menu item for the `SidebarMenu`.
 */
class SidebarMenuItem implements SidebarItem implements Styled {

    var iconValue:Null<Icon> = null;

    var labelValue:String;

    var accessibilityLabelValue:Null<String> = null;

    var labelStyleValue:StyleRefinement = new StyleRefinement();

    var itemStyle:StyleRefinement = new StyleRefinement();

    var handler:(ClickEvent, Window, App) -> Void = (_, _, _) -> {};

    var activeValue:Bool = false;

    var defaultOpenValue:Bool = false;

    var clickToOpenValue:Bool = false;

    var collapsedValue:Bool = false;

    var clickToToggleValue:Bool = false;

    var childItems:Array<SidebarMenuItem> = [];

    var suffixValue:Null<(Window, App) -> AnyElement> = null;

    var disabledValue:Bool = false;

    var contextMenuValue:Null<(PopupMenu, Window, App) -> PopupMenu> = null;

    /**
     * Create a new `SidebarMenuItem` with a label.
     */
    public function new(label:String) {
        labelValue = label;
    }

    /**
     * Rust `Clone`.
     */
    public function clone():SidebarMenuItem {
        final copy = new SidebarMenuItem(labelValue);
        copy.iconValue = iconValue != null ? iconValue.clone() : null;
        copy.accessibilityLabelValue = accessibilityLabelValue;
        copy.labelStyleValue = labelStyleValue;
        copy.itemStyle = itemStyle;
        copy.handler = handler;
        copy.activeValue = activeValue;
        copy.defaultOpenValue = defaultOpenValue;
        copy.clickToOpenValue = clickToOpenValue;
        copy.collapsedValue = collapsedValue;
        copy.clickToToggleValue = clickToToggleValue;
        copy.childItems = [for (item in childItems) item.clone()];
        copy.suffixValue = suffixValue;
        copy.disabledValue = disabledValue;
        copy.contextMenuValue = contextMenuValue;
        return copy;
    }

    public function cloneItem():SidebarItem {
        return clone();
    }

    /**
     * Set the icon for the menu item
     */
    public function icon(icon:IntoIcon):SidebarMenuItem {
        iconValue = icon;
        return this;
    }

    /**
     * Set the style for the label
     */
    public function labelStyle(style:StyleRefinement):SidebarMenuItem {
        labelStyleValue = style;
        return this;
    }

    /**
     * Set the accessibility label of the item row.
     *
     * Defaults to the visible label text.
     */
    public function accessibilityLabel(label:String):SidebarMenuItem {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Set the active state of the menu item
     */
    public function active(active:Bool):SidebarMenuItem {
        activeValue = active;
        return this;
    }

    /**
     * Add a click handler to the menu item
     */
    public function onClick(handler:(ClickEvent, Window, App) -> Void):SidebarMenuItem {
        this.handler = handler;
        return this;
    }

    /**
     * Set the collapsed state of the menu item
     */
    public function collapsed(collapsed:Bool):SidebarMenuItem {
        collapsedValue = collapsed;
        return this;
    }

    public function isCollapsed():Bool {
        return collapsedValue;
    }

    public function setCollapsed(collapsed:Bool):Void {
        collapsedValue = collapsed;
    }

    /**
     * Set the default open state of the Submenu, default is `false`.
     *
     * This only used on initial render, the internal state will be used afterwards.
     */
    public function defaultOpen(open:Bool):SidebarMenuItem {
        defaultOpenValue = open;
        return this;
    }

    /**
     * Set whether clicking the menu item open the submenu.
     *
     * Default is `false`. If `false` we only handle open/close via the caret
     * button.
     */
    public function clickToOpen(clickToOpen:Bool):SidebarMenuItem {
        clickToOpenValue = clickToOpen;
        return this;
    }

    /**
     * Set whether clicking the menu item toggles the submenu.
     *
     * If click_to_open is `true`, this has no effect. Default is `false`.
     */
    public function clickToToggle(clickToToggle:Bool):SidebarMenuItem {
        clickToToggleValue = clickToToggle;
        return this;
    }

    /**
     * Set the submenu items (replaces the items set before, like the
     * original).
     */
    public function children(children:Iterable<SidebarMenuItem>):SidebarMenuItem {
        childItems = glaze.util.Iterables.toArrayNonNull(children);
        return this;
    }

    /**
     * Set the suffix for the menu item.
     */
    public function suffix(builder:(Window, App) -> IntoElement):SidebarMenuItem {
        suffixValue = (window, cx) -> builder(window, cx).intoAnyElement();
        return this;
    }

    /**
     * Set disabled flat for menu item.
     */
    public function disable(disable:Bool):SidebarMenuItem {
        disabledValue = disable;
        return this;
    }

    function isSubmenu():Bool {
        return childItems.length > 0;
    }

    @:allow(glaze.kit.sidebar, tests)
    function collapsedTooltip():Null<String> {
        return (collapsedValue && iconValue != null) ? labelValue : null;
    }

    /**
     * Accessible name for the submenu caret: the toggle is icon-only, so
     * assistive tech needs the item it acts on.
     */
    @:allow(glaze.kit.sidebar, tests)
    function caretAccessibilityLabel():String {
        return 'Toggle $labelValue submenu';
    }

    /**
     * Set the context menu for the menu item.
     */
    public function contextMenu(f:(PopupMenu, Window, App) -> PopupMenu):SidebarMenuItem {
        contextMenuValue = f;
        return this;
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    /**
     * The accessibility properties of the row (`Role::TreeItem`, its label,
     * `aria_selected`) are not exported: the port has no accessibility tree.
     */
    public function renderItem(id:ElementId, window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final clickToOpen = clickToOpenValue;
        final clickToToggle = clickToToggleValue;
        final defaultOpen = defaultOpenValue;
        final collapsedTooltip = collapsedTooltip();
        final isSubmenu = isSubmenu();
        final openState = isSubmenu ? window.useKeyedState(id, cx, _ -> defaultOpen) : null;
        final handler = this.handler;
        final isCollapsed = collapsedValue;
        final isActive = activeValue;
        final isHoverable = !isActive && !disabledValue;
        final isDisabled = disabledValue;
        final isOpen = openState != null && !isCollapsed && openState.read(cx).value;

        final row = hFlex()
            .sizeFull()
            .id('item')
            .overflowXHidden()
            .flexShrink0()
            .p2()
            .gapX2()
            .rounded(theme.radius)
            .textSm()
            .refineStyle(itemStyle);
        if (isHoverable) {
            row.hover(s -> s.bg(theme.sidebarAccent.opacity(0.8)).textColor(theme.sidebarAccentForeground));
        }
        if (isActive) {
            row.fontMedium().bg(theme.tokens.sidebarAccent.background).textColor(theme.sidebarAccentForeground);
        }
        if (iconValue != null) row.child(iconValue);
        if (isCollapsed) {
            row.justifyCenter();
            if (isActive) {
                row.bg(theme.tokens.sidebarAccent.background).textColor(theme.sidebarAccentForeground);
            }
        }
        if (!isCollapsed) {
            final labelRow = hFlex()
                .flex1()
                .overflowXHidden()
                .refineStyle(labelStyleValue)
                .child(labelValue);
            final labelBox = hFlex()
                .flex1()
                .gapX2()
                .justifyBetween()
                .overflowXHidden()
                .child(labelRow);
            if (suffixValue != null) labelBox.child(suffixValue(window, cx));
            row.h7().child(labelBox);
            if (openState != null) {
                final caretIcon = Icon.component(IconName.ChevronRight).size4();
                if (isOpen) caretIcon.rotate(percentage(90. / 360.));
                row.child(
                    Button.component('caret')
                        .xsmall()
                        .ghost()
                        .accessibilityLabel(caretAccessibilityLabel())
                        .icon(caretIcon)
                        .onClick((_, _, cx) -> {
                            // Avoid trigger item click, just expand/collapse submenu
                            cx.stopPropagation();
                            openState.update(cx, (isOpen, cx) -> {
                                isOpen.value = !isOpen.value;
                                cx.notify();
                            });
                        })
                );
            }
        }
        if (isDisabled) {
            row.textColor(theme.mutedForeground);
        }
        if (!isDisabled) {
            row.onClick((ev, window, cx) -> {
                if (clickToOpen) {
                    if (openState != null) {
                        openState.update(cx, (isOpen, cx) -> {
                            isOpen.value = true;
                            cx.notify();
                        });
                    }
                } else if (clickToToggle) {
                    if (openState != null) {
                        openState.update(cx, (isOpen, cx) -> {
                            isOpen.value = !isOpen.value;
                            cx.notify();
                        });
                    }
                }
                handler(ev, window, cx);
            });
        }
        if (collapsedTooltip != null) {
            ManagedTooltip.managedTooltipAt(row, Placement.Right, (window, cx) -> new Tooltip(collapsedTooltip).build(window, cx));
        }
        final rowElement:AnyElement = if (contextMenuValue != null) {
            final contextMenu = contextMenuValue;
            row.contextMenu((menu, window, cx) -> contextMenu(menu, window, cx.app)).intoAnyElement();
        } else {
            row.intoAnyElement();
        };

        final element = div()
            .id(id)
            .testSupport()
            .wFull()
            .child(rowElement);
        if (isOpen) {
            final idString = Sidebar.elementIdString(id);
            final submenu = vFlex()
                .id('submenu')
                .borderL1()
                .borderColor(theme.sidebarBorder)
                .gap1()
                .ml3p5()
                .pl2p5()
                .py0p5();
            for (ix in 0...childItems.length) {
                final item = childItems[ix];
                submenu.child(item.renderItem(ElementId.Name('$idString-$ix'), window, cx).intoAnyElement());
            }
            element.child(submenu);
        }
        return element;
    }

}

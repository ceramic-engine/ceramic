// Ported from gpui-kit 0.8.1: crates/component/src/menu/menu_item.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.menu;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Disableable;
import glaze.kit.theme.Theme;

import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A row of a `PopupMenu` (crate private in Rust).
 *
 * The accessibility properties (`Role::MenuItem`, the label, `aria_selected`)
 * are kept as data: the port has no accessibility tree.
 */
class MenuItemElement implements RenderOnce implements Styled implements ParentElement implements Disableable {

    final id:ElementId;

    @:allow(glaze.kit, tests)
    var ariaLabelValue:Null<String> = null;

    final menuItemStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit, tests)
    var disabledValue:Bool = false;

    @:allow(glaze.kit, tests)
    var selectedValue:Bool = false;

    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    var onHoverHandler:Null<(Bool, Window, App) -> Void> = null;

    final childElements:Array<AnyElement> = [];

    /**
     * Create a new MenuItem with the given ID.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * Set ListItem as the selected item style.
     */
    public function selected(selected:Bool):MenuItemElement {
        selectedValue = selected;
        return this;
    }

    /**
     * Set the accessible label for the menu item.
     */
    public function ariaLabel(label:String):MenuItemElement {
        ariaLabelValue = label;
        return this;
    }

    /**
     * Set the disabled state of the MenuItem.
     */
    public function disabled(disabled:Bool):MenuItemElement {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    /**
     * Set a handler for when the MenuItem is clicked.
     */
    public function onClick(handler:(ClickEvent, Window, App) -> Void):MenuItemElement {
        onClickHandler = handler;
        return this;
    }

    /**
     * Set a handler for when the mouse enters the MenuItem.
     */
    public function onHover(handler:(Bool, Window, App) -> Void):MenuItemElement {
        onHoverHandler = handler;
        return this;
    }

    public inline function style():StyleRefinement {
        return menuItemStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):MenuItemElement {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):MenuItemElement {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final element = hFlex()
            .id(id)
            .gapX1()
            .py1()
            .px2()
            .textBase()
            .textColor(theme.foreground)
            .relative()
            .itemsCenter()
            .justifyBetween()
            .refineStyle(menuItemStyle);
        if (onHoverHandler != null) {
            final onHover = onHoverHandler;
            element.onHover((hovered, window, cx) -> onHover(hovered, window, cx));
        }
        if (!disabledValue) {
            // Not `group_hover` on the item's own group: GPUI styles an
            // element before registering its group, and that fallback keeps
            // the pointer's item lit after a key moves the highlight away.
            element.hover(s -> s.bg(theme.tokens.accent.background).textColor(theme.accentForeground));
            if (selectedValue) {
                element.bg(theme.tokens.accent.background).textColor(theme.accentForeground);
            }
            if (onClickHandler != null) {
                element.onMouseDown(Left, (_, _, cx) -> {
                    cx.stopPropagation();
                }).onClick(onClickHandler);
            }
        }
        if (disabledValue) {
            element.textColor(theme.mutedForeground);
        }
        element.extend(childElements);
        return element;
    }

}

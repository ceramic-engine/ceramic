// Ported from gpui-kit 0.8.1: crates/component/src/menu/menu_item.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.menu;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
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
class MenuItemElement extends Component implements Styled implements ParentElement implements Disableable {

    final id:ElementId;

    /**
     * Set the accessible label for the menu item.
     */
    @:allow(glaze.kit, tests)
    @prop var ariaLabel:Null<String> = null;

    final menuItemStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set the disabled state of the MenuItem.
     */
    @:allow(glaze.kit, tests)
    @prop var disabled:Bool = false;

    /**
     * Set ListItem as the selected item style.
     */
    @:allow(glaze.kit, tests)
    @prop var selected:Bool = false;

    /**
     * Set a handler for when the MenuItem is clicked.
     */
    @prop var onClick:Null<(ClickEvent, Window, App) -> Void> = null;

    var onHoverHandler:Null<(Bool, Window, App) -> Void> = null;

    final childElements:Array<AnyElement> = [];

    /**
     * Create a new MenuItem with the given ID.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public function setDisabled(disabled:Bool):Void {
        this.disabled = disabled;
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
        if (!disabled) {
            // Not `group_hover` on the item's own group: GPUI styles an
            // element before registering its group, and that fallback keeps
            // the pointer's item lit after a key moves the highlight away.
            element.hover(s -> s.bg(theme.tokens.accent.background).textColor(theme.accentForeground));
            if (selected) {
                element.bg(theme.tokens.accent.background).textColor(theme.accentForeground);
            }
            if (onClick != null) {
                element.onMouseDown(Left, (_, _, cx) -> {
                    cx.stopPropagation();
                }).onClick(onClick);
            }
        }
        if (disabled) {
            element.textColor(theme.mutedForeground);
        }
        element.extend(childElements);
        return element;
    }

}

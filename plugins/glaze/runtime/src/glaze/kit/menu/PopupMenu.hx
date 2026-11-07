// Ported from gpui-kit 0.8.1: crates/component/src/menu/popup_menu.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.menu;

import gpui.Action;
import gpui.Anchor;
import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.Axis;
import gpui.Bounds;
import gpui.ClickEvent;
import gpui.ClickEvent.KeyboardClickEvent;
import gpui.Context;
import gpui.DismissEvent;
import gpui.Edges;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.Menu.OwnedMenuItem;
import gpui.Model;
import gpui.MouseDownEvent;
import gpui.Pixels;
import gpui.Point;
import gpui.Render;
import gpui.ScrollHandle;
import gpui.WeakEntity;
import gpui.Window;
import gpui.base.Actions.Cancel;
import gpui.base.Actions.Confirm;
import gpui.base.Actions.SelectDown;
import gpui.base.Actions.SelectLeft;
import gpui.base.Actions.SelectRight;
import gpui.base.Actions.SelectUp;
import gpui.base.Geometry.Side;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Size;
import gpui.component.kbd.Kbd;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.ElementExt;
using gpui.component.ThemeStyled;
using gpui.component.scroll.Scrollable;

/**
 * The kind of a `PopupMenuItem` (the variants of the Rust enum).
 */
enum abstract PopupMenuItemKind(Int) {

    /** A menu separator item. */
    var Separator;

    /** A non-interactive label item. */
    var Label;

    /** A standard menu item. */
    var Item;

    /** A menu item with custom element render. */
    var ElementItem;

    /** A submenu item that opens another popup menu. */
    var Submenu;

}

/**
 * An menu item in a popup menu.
 *
 * Rust's enum with data becomes a class with a `kind`: the builders below
 * mutate the variant's fields in place, like the Rust `match &mut self`.
 * Fields that a variant does not have stay at their default.
 */
@:allow(gpui.component.menu)
class PopupMenuItem {

    @:allow(gpui.component, tests)
    final kind:PopupMenuItemKind;

    @:allow(gpui.component, tests)
    var iconValue:Null<Icon> = null;

    @:allow(gpui.component, tests)
    var labelValue:Null<String> = null;

    @:allow(gpui.component, tests)
    var disabledValue:Bool = false;

    @:allow(gpui.component, tests)
    var checkedValue:Bool = false;

    @:allow(gpui.component, tests)
    var isLink:Bool = false;

    @:allow(gpui.component, tests)
    var actionValue:Null<Action> = null;

    /** For link items, and the `on_click` of items and element items. */
    @:allow(gpui.component, tests)
    var handler:Null<(ClickEvent, Window, App) -> Void> = null;

    /** The custom element render of an `ElementItem`. */
    var renderFn:Null<(Window, App) -> IntoElement> = null;

    /** The menu of a `Submenu`. */
    @:allow(gpui.component, tests)
    var menu:Null<Entity<PopupMenu>> = null;

    function new(kind:PopupMenuItemKind) {
        this.kind = kind;
    }

    /**
     * Create a new menu item with the given label.
     */
    public static function create(label:String):PopupMenuItem {
        final item = new PopupMenuItem(Item);
        item.labelValue = label;
        return item;
    }

    /**
     * Create a new menu item with custom element render.
     */
    public static function element(builder:(Window, App) -> IntoElement):PopupMenuItem {
        final item = new PopupMenuItem(ElementItem);
        item.renderFn = builder;
        return item;
    }

    /**
     * Create a new submenu item that opens another popup menu.
     */
    public static function submenu(label:String, menu:Entity<PopupMenu>):PopupMenuItem {
        final item = new PopupMenuItem(Submenu);
        item.labelValue = label;
        item.menu = menu;
        return item;
    }

    /**
     * Create a separator menu item.
     */
    public static function separator():PopupMenuItem {
        return new PopupMenuItem(Separator);
    }

    /**
     * Creates a label menu item.
     */
    public static function label(label:String):PopupMenuItem {
        final item = new PopupMenuItem(Label);
        item.labelValue = label;
        return item;
    }

    /**
     * Set the icon for the menu item.
     *
     * Only works for `Item`, `ElementItem` and `Submenu`.
     */
    public function icon(icon:IntoIcon):PopupMenuItem {
        switch kind {
            case Item | ElementItem | Submenu:
                iconValue = icon;
            case _:
        }
        return this;
    }

    /**
     * Set the action for the menu item.
     *
     * Only works for `Item` and `ElementItem`.
     */
    public function action(action:Action):PopupMenuItem {
        switch kind {
            case Item | ElementItem:
                actionValue = action;
            case _:
        }
        return this;
    }

    /**
     * Set the disabled state for the menu item.
     *
     * Only works for `Item`, `ElementItem` and `Submenu`.
     */
    public function disabled(disabled:Bool):PopupMenuItem {
        switch kind {
            case Item | ElementItem | Submenu:
                disabledValue = disabled;
            case _:
        }
        return this;
    }

    /**
     * Set checked state for the menu item.
     *
     * NOTE: If `check_side` is `Side.Left`, the icon will replace with a check icon.
     */
    public function checked(checked:Bool):PopupMenuItem {
        switch kind {
            case Item | ElementItem:
                checkedValue = checked;
            case _:
        }
        return this;
    }

    /**
     * Add a click handler for the menu item.
     *
     * Only works for `Item` and `ElementItem`.
     */
    public function onClick(handler:(ClickEvent, Window, App) -> Void):PopupMenuItem {
        switch kind {
            case Item | ElementItem:
                this.handler = handler;
            case _:
        }
        return this;
    }

    /**
     * Create a link menu item.
     */
    public static function link(label:String, href:String):PopupMenuItem {
        final item = new PopupMenuItem(Item);
        item.labelValue = label;
        item.isLink = true;
        item.handler = (_, _, cx) -> cx.openUrl(href);
        return item;
    }

    inline function isClickable():Bool {
        return kind != Separator && switch kind {
            case Item | ElementItem | Submenu: !disabledValue;
            case _: false;
        }
    }

    inline function isSeparator():Bool {
        return kind == Separator;
    }

    function hasLeftIcon(checkSide:Side):Bool {
        return switch kind {
            case Item | ElementItem: iconValue != null || (checkSide.isLeft() && checkedValue);
            case Submenu: iconValue != null;
            case _: false;
        }
    }

    inline function isChecked():Bool {
        return switch kind {
            case Item | ElementItem: checkedValue;
            case _: false;
        }
    }

    @:allow(tests)
    function a11yLabel():Null<String> {
        return switch kind {
            case Item | Label | Submenu: labelValue;
            case Separator | ElementItem: null;
        }
    }

}

/**
 * The options shared by the rows of one render.
 */
private class RenderOptions {

    public final hasLeftIcon:Bool;

    public final checkSide:Side;

    public final radius:Pixels;

    public function new(hasLeftIcon:Bool, checkSide:Side, radius:Pixels) {
        this.hasLeftIcon = hasLeftIcon;
        this.checkSide = checkSide;
        this.radius = radius;
    }

}

/**
 * A popup menu: a list of items, labels, separators and submenus, driven by
 * the keyboard (`PopupMenu` key context) and the pointer.
 *
 * Build it with `PopupMenu.build(window, cx, (menu, window, cx) -> menu.menu(...))`.
 * Rust's `Focusable` is the public `focusHandle` field. `DismissEvent` is
 * emitted when the menu closes.
 */
class PopupMenu extends Model implements Render {

    static inline final CONTEXT = 'PopupMenu';

    public static function init(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('enter', new Confirm(false), CONTEXT),
            new KeyBinding('escape', new Cancel(), CONTEXT),
            new KeyBinding('up', new SelectUp(), CONTEXT),
            new KeyBinding('down', new SelectDown(), CONTEXT),
            new KeyBinding('left', new SelectLeft(), CONTEXT),
            new KeyBinding('right', new SelectRight(), CONTEXT),
        ]);
    }

    public final focusHandle:FocusHandle;

    @:allow(gpui.component, tests)
    var menuItems:Array<PopupMenuItem> = [];

    /** The focus handle of Entity to handle actions. */
    @:allow(gpui.component, tests)
    var actionContextValue:Null<FocusHandle> = null;

    /**
     * The focus to restore on dismiss. Unlike `actionContextValue`, this does
     * not change where actions are dispatched: they still bubble from the
     * menu's own focus path (through the trigger element's ancestors).
     */
    @:allow(gpui.component, tests)
    var previousFocusHandle:Null<FocusHandle> = null;

    /**
     * A focus handle on the trigger's dispatch path, so shortcut hints can
     * resolve against the key contexts the menu's actions bubble through on
     * the very frame the menu opens. GPUI looks a handle up in the previously
     * rendered frame, and the trigger was in it when the menu was not yet.
     */
    @:allow(gpui.component, tests)
    var triggerFocusHandle:Null<FocusHandle> = null;

    @:allow(gpui.component, tests)
    @observe var selectedIndex:Null<Int> = null;

    var minWidth:Null<Pixels> = null;

    var maxWidthValue:Null<Pixels> = null;

    var maxHeight:Null<Pixels> = null;

    /** Updated on prepaint (not observable, like Rust's plain field). */
    @:allow(gpui.component, tests)
    var bounds:Bounds = new Bounds(new Point(0., 0.), new gpui.Size(0., 0.));

    var size:Size = Medium;

    var checkSideValue:Side = Left;

    /** The parent menu of this menu, if this is a submenu */
    @:allow(gpui.component, tests)
    var parentMenu:Null<WeakEntity<PopupMenu>> = null;

    @:allow(gpui.component, tests)
    var scrollableValue:Bool = false;

    var externalLinkIconValue:Bool = true;

    @:allow(gpui.component, tests)
    final scrollHandle:ScrollHandle = new ScrollHandle();

    // This will update on render
    @:allow(gpui.component, tests)
    var submenuAnchor:Anchor = TopLeft;

    @:allow(gpui.component, tests)
    var submenuAnchorLeft:Pixels = 0.;

    /**
     * Paint priority for this menu layer. The top-level menu starts at
     * `POPUP_PRIORITY` and each nested submenu increments it, so deeper levels
     * are always drawn on top of shallower ones.
     *
     * The top-level menu relies on its container (e.g. `Popover`,
     * `ContextMenu`) to `deferred`-draw it, and each submenu is deferred once
     * in `renderItem` with `priority + 1`. Keeping a single deferred layer
     * per level matters because GPUI caps nested deferred depth.
     *
     * Deferring is also what lets a submenu open from a `scrollable` menu:
     * a deferred draw is painted at the window level with no inherited
     * content mask, so the items container's `overflowYScroll` clip never
     * reaches it, while the scroll offset is still baked into its anchor.
     */
    @:allow(gpui.component, tests)
    var priority:Int = gpui.base.Popup.POPUP_PRIORITY;

    @:allow(gpui.component)
    function new(cx:AppContext) {
        super();
        focusHandle = (cx:App).focusHandle();
    }

    public static function build(window:Window, cx:AppContext, f:(PopupMenu, Window, Context<PopupMenu>) -> PopupMenu):Entity<PopupMenu> {
        return (cx:App).newEntity((cx:Context<PopupMenu>) -> f(new PopupMenu(cx), window, cx));
    }

    /**
     * Set the focus handle of Entity to handle actions.
     *
     * When the menu is dismissed or before an action is triggered, the focus
     * will be returned to this handle. Then the action will be dispatched to
     * this handle. Submenus without their own action context use the nearest
     * parent's explicit context for actions and shortcut hints.
     */
    public function actionContext(handle:FocusHandle):PopupMenu {
        actionContextValue = handle;
        return this;
    }

    @:allow(gpui.component)
    function setActionContext(actionContext:Null<FocusHandle>, cx:Context<PopupMenu>):Void {
        this.actionContextValue = actionContext;

        for (item in menuItems) {
            if (item.kind == Submenu) {
                item.menu.update(cx, (menu, cx) -> {
                    menu.setActionContext(actionContext, cx);
                });
            }
        }
    }

    /**
     * Set the focus to restore when the menu is dismissed, without changing
     * where actions are dispatched.
     */
    @:allow(gpui.component)
    function setPreviousFocus(handle:Null<FocusHandle>, cx:Context<PopupMenu>):Void {
        this.previousFocusHandle = handle;

        for (item in menuItems) {
            if (item.kind == Submenu) {
                item.menu.update(cx, (menu, cx) -> {
                    menu.setPreviousFocus(handle, cx);
                });
            }
        }
    }

    /**
     * Set the focus handle on the trigger's dispatch path that shortcut hints
     * resolve against, without changing focus or where actions are dispatched.
     */
    @:allow(gpui.component)
    function setTriggerFocus(handle:Null<FocusHandle>, cx:Context<PopupMenu>):Void {
        this.triggerFocusHandle = handle;

        for (item in menuItems) {
            if (item.kind == Submenu) {
                item.menu.update(cx, (menu, cx) -> {
                    menu.setTriggerFocus(handle, cx);
                });
            }
        }
    }

    /**
     * Set min width of the popup menu, default is 120px
     */
    public function minW(width:Pixels):PopupMenu {
        minWidth = width;
        return this;
    }

    /**
     * Set max width of the popup menu, default is 500px
     */
    public function maxW(width:Pixels):PopupMenu {
        maxWidthValue = width;
        return this;
    }

    /**
     * Set max height of the popup menu, default is half of the window height
     */
    public function maxH(height:Pixels):PopupMenu {
        maxHeight = height;
        return this;
    }

    /**
     * Set the menu to be scrollable to show vertical scrollbar.
     */
    public function scrollable(scrollable:Bool):PopupMenu {
        scrollableValue = scrollable;
        return this;
    }

    /**
     * Set the side to show check icon, default is `Side.Left`.
     */
    public function checkSide(side:Side):PopupMenu {
        checkSideValue = side;
        return this;
    }

    /**
     * Set the menu to show external link icon, default is true.
     */
    public function externalLinkIcon(visible:Bool):PopupMenu {
        externalLinkIconValue = visible;
        return this;
    }

    /**
     * Add Menu Item
     */
    public function menu(label:String, action:Action):PopupMenu {
        return menuWithDisabled(label, action, false);
    }

    /**
     * Add Menu Item with enable state
     */
    public function menuWithEnable(label:String, action:Action, enable:Bool):PopupMenu {
        addMenuItem(label, null, action, !enable, false);
        return this;
    }

    /**
     * Add Menu Item with disabled state
     */
    public function menuWithDisabled(label:String, action:Action, disabled:Bool):PopupMenu {
        addMenuItem(label, null, action, disabled, false);
        return this;
    }

    /**
     * Add label
     */
    public function label(label:String):PopupMenu {
        menuItems.push(PopupMenuItem.label(label));
        return this;
    }

    /**
     * Add Menu to open link
     */
    public function link(label:String, href:String):PopupMenu {
        return linkWithDisabled(label, href, false);
    }

    /**
     * Add Menu to open link with disabled state
     */
    public function linkWithDisabled(label:String, href:String, disabled:Bool):PopupMenu {
        menuItems.push(PopupMenuItem.link(label, href).disabled(disabled));
        return this;
    }

    /**
     * Add Menu to open link
     */
    public function linkWithIcon(label:String, icon:IntoIcon, href:String):PopupMenu {
        return linkWithIconAndDisabled(label, icon, href, false);
    }

    /**
     * Add Menu to open link with icon and disabled state
     */
    function linkWithIconAndDisabled(label:String, icon:IntoIcon, href:String, disabled:Bool):PopupMenu {
        menuItems.push(PopupMenuItem.link(label, href).icon(icon).disabled(disabled));
        return this;
    }

    /**
     * Add Menu Item with Icon.
     */
    public function menuWithIcon(label:String, icon:IntoIcon, action:Action):PopupMenu {
        return menuWithIconAndDisabled(label, icon, action, false);
    }

    /**
     * Add Menu Item with Icon and disabled state
     */
    public function menuWithIconAndDisabled(label:String, icon:IntoIcon, action:Action, disabled:Bool):PopupMenu {
        addMenuItem(label, icon, action, disabled, false);
        return this;
    }

    /**
     * Add Menu Item with check icon
     */
    public function menuWithCheck(label:String, checked:Bool, action:Action):PopupMenu {
        return menuWithCheckAndDisabled(label, checked, action, false);
    }

    /**
     * Add Menu Item with check icon and disabled state
     */
    public function menuWithCheckAndDisabled(label:String, checked:Bool, action:Action, disabled:Bool):PopupMenu {
        addMenuItem(label, null, action, disabled, checked);
        return this;
    }

    /**
     * Add Menu Item with custom element render.
     */
    public function menuElement(action:Action, builder:(Window, App) -> IntoElement):PopupMenu {
        return menuElementWithCheck(false, action, builder);
    }

    /**
     * Add Menu Item with custom element render with disabled state.
     */
    public function menuElementWithDisabled(action:Action, disabled:Bool, builder:(Window, App) -> IntoElement):PopupMenu {
        return menuElementWithCheckAndDisabled(false, action, disabled, builder);
    }

    /**
     * Add Menu Item with custom element render with icon.
     */
    public function menuElementWithIcon(icon:IntoIcon, action:Action, builder:(Window, App) -> IntoElement):PopupMenu {
        return menuElementWithIconAndDisabled(icon, action, false, builder);
    }

    /**
     * Add Menu Item with custom element render with check state
     */
    public function menuElementWithCheck(checked:Bool, action:Action, builder:(Window, App) -> IntoElement):PopupMenu {
        return menuElementWithCheckAndDisabled(checked, action, false, builder);
    }

    /**
     * Add Menu Item with custom element render with icon and disabled state
     */
    function menuElementWithIconAndDisabled(icon:IntoIcon, action:Action, disabled:Bool, builder:(Window, App) -> IntoElement):PopupMenu {
        menuItems.push(PopupMenuItem.element(builder).action(action).icon(icon).disabled(disabled));
        return this;
    }

    /**
     * Add Menu Item with custom element render with check state and disabled state
     */
    function menuElementWithCheckAndDisabled(checked:Bool, action:Action, disabled:Bool, builder:(Window, App) -> IntoElement):PopupMenu {
        menuItems.push(PopupMenuItem.element(builder).action(action).checked(checked).disabled(disabled));
        return this;
    }

    /**
     * Add a separator Menu Item
     */
    public function separator():PopupMenu {
        if (menuItems.length == 0) {
            return this;
        }

        if (menuItems[menuItems.length - 1].kind == Separator) {
            return this;
        }

        menuItems.push(PopupMenuItem.separator());
        return this;
    }

    /**
     * Add a Submenu
     */
    public function submenu(label:String, window:Window, cx:Context<PopupMenu>, f:(PopupMenu, Window, Context<PopupMenu>) -> PopupMenu):PopupMenu {
        return submenuWithIcon(null, label, window, cx, f);
    }

    /**
     * Add a Submenu item with icon
     */
    public function submenuWithIcon(icon:Null<Icon>, label:String, window:Window, cx:Context<PopupMenu>, f:(PopupMenu, Window, Context<PopupMenu>) -> PopupMenu):PopupMenu {
        final submenu = PopupMenu.build(window, cx, f);
        // Rust `cx.entity().downgrade()`: the entity may still be under
        // construction, so take the weak handle from the context.
        final parentMenu = cx.weakEntity();
        final parentPriority = this.priority;
        submenu.update(cx, (view, _) -> {
            view.parentMenu = parentMenu;
            view.priority = parentPriority + 1;
        });

        final item = PopupMenuItem.submenu(label, submenu);
        if (icon != null) item.icon(icon);
        menuItems.push(item);
        return this;
    }

    /**
     * Add menu item.
     */
    public function item(item:PopupMenuItem):PopupMenu {
        menuItems.push(item);
        return this;
    }

    /**
     * Replace all menu items by re-running a builder on this menu, keeping its
     * identity (focus, parent menu, layer priority).
     *
     * For menus whose content arrives asynchronously after the menu is shown,
     * e.g. swapping a "loading..." placeholder for the loaded items.
     *
     * Rust moves the menu out and back in; the builders here mutate the menu
     * in place and return it, so the menu is rebuilt in place (the fields of
     * another menu returned by the builder are taken over).
     */
    public function rebuild(window:Window, cx:Context<PopupMenu>, f:(PopupMenu, Window, Context<PopupMenu>) -> PopupMenu):Void {
        menuItems = [];
        selectedIndex = null;
        final result = f(this, window, cx);
        if (result != this) {
            menuItems = result.menuItems;
            actionContextValue = result.actionContextValue;
            previousFocusHandle = result.previousFocusHandle;
            triggerFocusHandle = result.triggerFocusHandle;
            selectedIndex = result.selectedIndex;
            minWidth = result.minWidth;
            maxWidthValue = result.maxWidthValue;
            maxHeight = result.maxHeight;
            size = result.size;
            checkSideValue = result.checkSideValue;
            scrollableValue = result.scrollableValue;
            externalLinkIconValue = result.externalLinkIconValue;
        }
        cx.notify();
    }

    function addMenuItem(label:String, icon:Null<Icon>, action:Action, disabled:Bool, checked:Bool):PopupMenu {
        final item = PopupMenuItem.create(label);
        if (icon != null) item.icon(icon);
        menuItems.push(item
            .disabled(disabled)
            .checked(checked)
            .action(action));
        return this;
    }

    @:allow(gpui.component)
    function withMenuItems(items:Array<OwnedMenuItem>, window:Window, cx:Context<PopupMenu>):PopupMenu {
        var self = this;
        for (item in items) {
            switch item {
                case Action(name, action, _, checked, disabled):
                    self = self.menuWithCheckAndDisabled(name, checked, action.boxedClone(), disabled);
                case Separator:
                    self = self.separator();
                case Submenu(submenu):
                    self = self.submenu(submenu.name, window, cx, (menu, window, cx) -> {
                        return menu.withMenuItems([for (item in submenu.items) item.clone()], window, cx);
                    });
                case SystemMenu(_):
            }
        }

        if (self.menuItems.length > 20) {
            self.scrollableValue = true;
        }

        return self;
    }

    @:allow(gpui.component, tests)
    function activeSubmenu():Null<Entity<PopupMenu>> {
        final ix = selectedIndex;
        if (ix != null) {
            final item = menuItems[ix];
            if (item != null) {
                return item.kind == Submenu ? item.menu : null;
            }
        }

        return null;
    }

    public function isEmpty():Bool {
        return menuItems.length == 0;
    }

    function clickableMenuItemIndices():Array<Int> {
        return [for (ix => item in menuItems) if (item.isClickable()) ix];
    }

    function onClick(ix:Int, event:ClickEvent, window:Window, cx:Context<PopupMenu>):Void {
        cx.stopPropagation();
        window.preventDefault();
        selectedIndex = ix;
        activate(event, window, cx);
    }

    function confirm(_:Confirm, window:Window, cx:Context<PopupMenu>):Void {
        // Rust `ClickEvent::default()`: a keyboard click of enter with empty bounds
        activate(Keyboard(new KeyboardClickEvent(Enter, new Bounds(new Point(0., 0.), new gpui.Size(0., 0.)))), window, cx);
    }

    function activate(event:ClickEvent, window:Window, cx:Context<PopupMenu>):Void {
        final index = selectedIndex;
        if (index == null)
            return;
        final item = menuItems[index];
        if (item == null || !item.isClickable()) {
            return;
        }
        switch item.kind {
            case Item | ElementItem:
                if (item.handler != null) {
                    item.handler(event, window, cx.app);
                }
                else if (item.actionValue != null) {
                    dispatchConfirmAction(item.actionValue, window, cx);
                }

                dismiss(null, window, cx);
            case Submenu if (!item.disabledValue):
                selectSubmenu(window, cx);
            case _:
        }
    }

    function dispatchConfirmAction(action:Action, window:Window, cx:Context<PopupMenu>):Void {
        final context = resolvedActionContext(cx.app);
        if (context != null) {
            context.focus(window, cx.app);
        }

        window.dispatchAction(action.boxedClone(), cx.app);
    }

    function resolvedActionContext(cx:App):Null<FocusHandle> {
        if (actionContextValue != null)
            return actionContextValue;
        if (parentMenu == null)
            return null;
        final parent = parentMenu.upgrade();
        if (parent == null)
            return null;
        return parent.read(cx).resolvedActionContext(cx);
    }

    function setSelectedIndex(ix:Int, cx:Context<PopupMenu>):Void {
        if (selectedIndex != ix) {
            selectedIndex = ix;
            scrollHandle.scrollToItem(ix);
        }
    }

    function selectUp(_:SelectUp, _:Window, cx:Context<PopupMenu>):Void {
        cx.stopPropagation();
        final ix = selectedIndex != null ? selectedIndex : 0;

        var i = menuItems.length - 1;
        while (i >= 0) {
            if (i < ix && menuItems[i].isClickable()) {
                setSelectedIndex(i, cx);
                return;
            }
            i--;
        }

        final clickable = clickableMenuItemIndices();
        if (clickable.length > 0) {
            setSelectedIndex(clickable[clickable.length - 1], cx);
        }
    }

    function selectDown(_:SelectDown, _:Window, cx:Context<PopupMenu>):Void {
        cx.stopPropagation();
        final ix = selectedIndex;
        if (ix == null) {
            final clickable = clickableMenuItemIndices();
            if (clickable.length > 0) {
                setSelectedIndex(clickable[0], cx);
            }
            return;
        }

        for (i in 0...menuItems.length) {
            if (i > ix && menuItems[i].isClickable()) {
                setSelectedIndex(i, cx);
                return;
            }
        }

        final clickable = clickableMenuItemIndices();
        if (clickable.length > 0) {
            setSelectedIndex(clickable[0], cx);
        }
    }

    function selectLeft(_:SelectLeft, window:Window, cx:Context<PopupMenu>):Void {
        final handled = if (submenuAnchor == TopLeft || submenuAnchor == BottomLeft) {
            unselectSubmenu(window, cx);
        }
        else {
            selectSubmenu(window, cx);
        }

        if (parentSide(cx.app).isLeft()) {
            focusParentMenu(window, cx);
        }

        if (handled) {
            return;
        }

        // For parent AppMenuBar to handle.
        if (parentMenu == null) {
            cx.propagate();
        }
    }

    function selectRight(_:SelectRight, window:Window, cx:Context<PopupMenu>):Void {
        final handled = if (submenuAnchor == TopLeft || submenuAnchor == BottomLeft) {
            selectSubmenu(window, cx);
        }
        else {
            unselectSubmenu(window, cx);
        }

        if (parentSide(cx.app).isRight()) {
            focusParentMenu(window, cx);
        }

        if (handled) {
            return;
        }

        // For parent AppMenuBar to handle.
        if (parentMenu == null) {
            cx.propagate();
        }
    }

    /** Rust `_select_submenu`. */
    function selectSubmenu(window:Window, cx:Context<PopupMenu>):Bool {
        final activeSubmenu = this.activeSubmenu();
        if (activeSubmenu != null) {
            // Focus the submenu, so that can be handle the action.
            activeSubmenu.update(cx, (view, cx) -> {
                final clickable = view.clickableMenuItemIndices();
                if (clickable.length > 0) {
                    view.setSelectedIndex(clickable[0], cx);
                }
                else {
                    view.selectedIndex = null;
                }
                view.focusHandle.focus(window, cx.app);
            });
            return true;
        }

        return false;
    }

    /** Rust `_unselect_submenu`. */
    function unselectSubmenu(_:Window, cx:Context<PopupMenu>):Bool {
        final activeSubmenu = this.activeSubmenu();
        if (activeSubmenu != null) {
            activeSubmenu.update(cx, (view, _) -> {
                view.selectedIndex = null;
            });
            return true;
        }

        return false;
    }

    /** Rust `_focus_parent_menu`. */
    function focusParentMenu(window:Window, cx:Context<PopupMenu>):Void {
        if (parentMenu == null) {
            return;
        }
        final parent = parentMenu.upgrade();
        if (parent == null) {
            return;
        }

        selectedIndex = null;
        parent.update(cx, (view, cx) -> {
            view.focusHandle.focus(window, cx.app);
        });
    }

    function parentSide(cx:App):Side {
        if (parentMenu == null) {
            return Left;
        }

        final parent = parentMenu.upgrade();
        if (parent == null) {
            return Left;
        }

        return switch parent.read(cx).submenuAnchor {
            case TopLeft | BottomLeft: Left;
            case TopRight | BottomRight: Right;
            // Center anchors are not used for submenu positioning, but we must cover them.
            case _: Left;
        }
    }

    /**
     * Dismiss the menu and the entire parent chain.
     *
     * The submenu is closed together with its parent, same as macOS menus.
     */
    function dismiss(_:Null<Cancel>, window:Window, cx:Context<PopupMenu>):Void {
        selectedIndex = null;
        cx.emit(DismissEvent.instance);

        // Focus back to the previous focused handle, unless the item's click
        // handler has already moved focus elsewhere (e.g. opened a dialog and
        // focused its input): stealing focus back would break that.
        final focusMovedAway = window.focused(cx.app) != null && !focusHandle.containsFocused(window, cx.app);
        if (!focusMovedAway) {
            final handle = previousFocusHandle != null ? previousFocusHandle : actionContextValue;
            if (handle != null) {
                window.focus(handle, cx.app);
            }
        }

        if (parentMenu == null) {
            return;
        }

        // Dismiss parent menu, when this menu is dismissed
        parentMenu.tryUpdate(cx, (view, cx) -> {
            view.dismiss(null, window, cx);
        });
    }

    function handleDismiss(position:Point, window:Window, cx:Context<PopupMenu>):Void {
        // Do not dismiss, if click inside the parent menu
        if (parentMenu != null) {
            final parent = parentMenu.upgrade();
            if (parent != null) {
                if (parent.read(cx).bounds.contains(position)) {
                    return;
                }
            }
        }

        // Do not dismiss, if there have an active submenu, the click may be
        // inside the submenu, let the submenu to handle it.
        //
        // Otherwise the submenu will be dismissed before its item's `on_click`.
        if (activeSubmenu() != null) {
            return;
        }

        dismiss(null, window, cx);
    }

    function onMouseDownOut(e:MouseDownEvent, window:Window, cx:Context<PopupMenu>):Void {
        handleDismiss(e.position, window, cx);
    }

    function renderKeyBinding(action:Null<Action>, window:Window, cx:Context<PopupMenu>):Null<Kbd> {
        if (action == null)
            return null;

        // Each handle names a dispatch path GPUI can resolve in the previously
        // rendered frame: the explicit action target, the trigger the menu
        // opened from (already rendered when the menu first draws), the focus
        // the menu interrupted, then the menu's own path once it has been
        // rendered. A binding registered without a key context applies on
        // every path, so it is the last resort rather than the window's
        // leftover context stack, which only holds the path of whatever
        // element happened to paint last.
        final actionContext = resolvedActionContext(cx.app);
        var kbd:Null<Kbd> = null;
        for (handle in [actionContext, triggerFocusHandle, previousFocusHandle, focusHandle]) {
            if (handle == null)
                continue;
            kbd = Kbd.bindingForActionIn(action, handle, window);
            if (kbd != null)
                break;
        }
        if (kbd == null) {
            kbd = Kbd.globalBindingForAction(action, window);
        }
        if (kbd == null)
            return null;
        return kbd
            .p0()
            .flexNowrap()
            .border0()
            .bg(transparentWhite());
    }

    static function renderIcon(hasIcon:Bool, checked:Bool, icon:Null<Icon>, _:Window, _:Context<PopupMenu>):Null<Icon> {
        if (!hasIcon) {
            return null;
        }

        final icon = if (icon != null) {
            icon.clone();
        }
        else if (checked) {
            new Icon(IconName.Check);
        }
        else {
            Icon.empty();
        }

        return icon.xsmall();
    }

    inline function maxWidth():Pixels {
        return maxWidthValue != null ? maxWidthValue : px(500.);
    }

    /**
     * Calculate the anchor corner and left offset for child submenu.
     *
     * Rust reads `window.bounds().size`, the size of the window: the
     * viewport size here.
     */
    function updateSubmenuMenuAnchor(window:Window):Void {
        final bounds = this.bounds;
        final maxWidth = this.maxWidth();
        final windowSize = window.viewportSize();
        var anchor:Anchor;
        var left:Pixels;
        if (maxWidth + bounds.origin.x > windowSize.width) {
            anchor = TopRight;
            left = -16.;
        }
        else {
            anchor = TopLeft;
            left = (bounds.size.width:Float) - 8.;
        }

        final isBottomPos = bounds.origin.y + bounds.size.height > windowSize.height;
        submenuAnchor = isBottomPos ? anchor.otherSideAlong(Axis.Vertical) : anchor;
        submenuAnchorLeft = left;
    }

    function renderItem(ix:Int, item:PopupMenuItem, options:RenderOptions, window:Window, cx:Context<PopupMenu>):MenuItemElement {
        final theme = Theme.global(cx);
        final hasLeftIcon = options.hasLeftIcon;
        final isLeftCheck = options.checkSide.isLeft() && item.isChecked();
        final rightCheckIcon = if (options.checkSide.isRight() && item.isChecked()) {
            new Icon(IconName.Check).xsmall();
        }
        else {
            null;
        }

        final selected = selectedIndex == ix;
        final EDGE_PADDING:Pixels = px(4.);
        final INNER_PADDING:Pixels = px(8.);

        final isSubmenu = item.kind == Submenu;

        final itemHeight:Pixels = size == Small ? px(20.) : px(26.);
        final radius:Pixels = size == Small ? options.radius * 0.5 : options.radius;

        final element = new MenuItemElement(ix)
            .relative()
            .textSm()
            .py0()
            .px(INNER_PADDING)
            .rounded(radius)
            .itemsCenter()
            .selected(selected)
            .onHover(cx.listener((menu:PopupMenu, hovered:Bool, window:Window, cx:Context<PopupMenu>) -> {
                if (hovered) {
                    // Pointing elsewhere closes the open submenu; take back
                    // the focus the keyboard may have moved into it.
                    final activeSubmenu = menu.activeSubmenu();
                    if (menu.selectedIndex != ix
                        && activeSubmenu != null
                        && activeSubmenu.read(cx).focusHandle.containsFocused(window, cx.app)) {
                        menu.focusHandle.focus(window, cx.app);
                    }
                    menu.selectedIndex = ix;
                }
                else if (!isSubmenu
                    && menu.selectedIndex == ix
                    // A key press ends hover under a still pointer; keep the
                    // highlight so the next arrow key moves on from this item.
                    && !window.lastInputWasKeyboard()) {
                    // TODO: Better handle the submenu unselection when hover out
                    menu.selectedIndex = null;
                }
            }));
        final a11yLabel = item.a11yLabel();
        if (a11yLabel != null) element.ariaLabel(a11yLabel);

        final onItemClick = cx.listener((menu:PopupMenu, event:ClickEvent, window:Window, cx:Context<PopupMenu>) -> {
            menu.onClick(ix, event, window, cx);
        });

        switch item.kind {
            case Separator:
                return element
                    .hAuto()
                    .p0()
                    .my0p5()
                    .mxNeg1()
                    .borderB(px(2.))
                    .borderColor(theme.border)
                    .disabled(true);
            case Label:
                final icon = renderIcon(hasLeftIcon, false, null, window, cx);
                return element.disabled(true).cursorDefault().child(
                    hFlex()
                        .cursorDefault()
                        .itemsCenter()
                        .gapX1()
                        .children(icon != null ? [(icon : IntoElement)] : [])
                        .child(div().flex1().child(item.labelValue))
                );
            case ElementItem:
                if (!item.disabledValue) {
                    element.onClick(onItemClick);
                }
                final icon = renderIcon(hasLeftIcon, isLeftCheck, item.iconValue, window, cx);
                return element
                    .disabled(item.disabledValue)
                    .child(
                        hFlex()
                            .flex1()
                            .minH(itemHeight)
                            .itemsCenter()
                            .gapX1()
                            .children(icon != null ? [(icon : IntoElement)] : [])
                            .child(item.renderFn(window, cx.app))
                            .children(rightCheckIcon != null ? [(rightCheckIcon.ml3() : IntoElement)] : [])
                    );
            case Item:
                final showLinkIcon = item.isLink && externalLinkIconValue;
                final action = item.actionValue != null ? item.actionValue.boxedClone() : null;
                final key = renderKeyBinding(action, window, cx);

                if (!item.disabledValue) {
                    element.onClick(onItemClick);
                }
                final icon = renderIcon(hasLeftIcon, isLeftCheck, item.iconValue, window, cx);
                final content = hFlex()
                    .wFull()
                    .gap3()
                    .itemsCenter()
                    .justifyBetween();
                if (!showLinkIcon) content.child(item.labelValue);
                if (rightCheckIcon != null) content.child(rightCheckIcon);
                if (showLinkIcon) {
                    content.child(
                        hFlex()
                            .wFull()
                            .justifyBetween()
                            .gap1p5()
                            .child(item.labelValue)
                            .child(
                                new Icon(IconName.ExternalLink)
                                    .xsmall()
                                    .textColor(theme.mutedForeground)
                            )
                    );
                }
                if (key != null) content.child(key);
                return element
                    .disabled(item.disabledValue)
                    .h(itemHeight)
                    .gapX1()
                    .children(icon != null ? [(icon : IntoElement)] : [])
                    .child(content);
            case Submenu:
                if (!item.disabledValue) {
                    element.onClick(onItemClick);
                }
                final icon = renderIcon(hasLeftIcon, false, item.iconValue, window, cx);
                element
                    .selected(selected)
                    .disabled(item.disabledValue)
                    .itemsStart()
                    .child(
                        hFlex()
                            .minH(itemHeight)
                            .sizeFull()
                            .itemsCenter()
                            .gapX1()
                            .children(icon != null ? [(icon : IntoElement)] : [])
                            .child(
                                hFlex()
                                    .flex1()
                                    .gap2()
                                    .itemsCenter()
                                    .justifyBetween()
                                    .child(item.labelValue)
                                    .child(
                                        new Icon(IconName.ChevronRight)
                                            .xsmall()
                                            .textColor(theme.mutedForeground)
                                    )
                            )
                    );
                if (selected) {
                    final anchor = submenuAnchor;
                    final left = submenuAnchorLeft;
                    final isBottomPos = anchor == BottomLeft || anchor == BottomRight;
                    final submenu = div()
                        .id('submenu')
                        .occlude();
                    if (isBottomPos) submenu.bottom0();
                    if (!isBottomPos) submenu.topNeg1();
                    element.child(
                        deferred(
                            anchored()
                                .anchor(anchor)
                                .child(
                                    submenu
                                        .left(left)
                                        .child(item.menu)
                                )
                                .snapToWindowWithMargin(Edges.all(EDGE_PADDING))
                        )
                            .withPriority(priority + 1)
                    );
                }
                return element;
        }
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<PopupMenu> = cast cx;
        final theme = Theme.global(cx);
        updateSubmenuMenuAnchor(window);

        // Submenus attached via the public `item()` + `PopupMenuItem.submenu()`
        // path (from contexts that only have the menu value, e.g. a table
        // delegate's `context_menu`) have no parent wired at construction time.
        // Wire them here so the dismiss chain, click-outside checks and keyboard
        // navigation treat them the same as `submenu()`-built children.
        final parent = cx.weakEntity();
        final parentPriority = priority;
        for (item in menuItems) {
            if (item.kind == Submenu) {
                if (item.menu.read(cx).parentMenu == null) {
                    item.menu.update(cx, (menu, _) -> {
                        menu.parentMenu = parent;
                        menu.priority = parentPriority + 1;
                    });
                }
            }
        }

        final view:Entity<PopupMenu> = cx.entity();
        final itemsCount = menuItems.length;

        final maxHeight:Pixels = if (this.maxHeight != null) {
            this.maxHeight;
        }
        else {
            final windowHalfHeight = window.viewportSize().height * 0.5;
            Math.min(windowHalfHeight, px(450.));
        }

        var hasLeftIcon = false;
        for (item in menuItems) {
            if (item.hasLeftIcon(checkSideValue)) {
                hasLeftIcon = true;
                break;
            }
        }

        final maxWidth = this.maxWidth();
        final options = new RenderOptions(hasLeftIcon, checkSideValue, Math.min(theme.radius, px(8.)));

        final items = vFlex()
            .id('items')
            .p1()
            .gapY0p5()
            .minW(rems(8.));
        if (minWidth != null) items.minW(minWidth);
        items.maxW(maxWidth);
        if (scrollableValue) {
            items.maxH(maxHeight)
                .overflowYScroll()
                .trackScroll(scrollHandle);
        }
        final rows:Array<IntoElement> = [];
        for (ix => item in menuItems) {
            // Ignore last separator
            if (ix + 1 == itemsCount && item.isSeparator())
                continue;
            rows.push(renderItem(ix, item, options, window, cx));
        }
        items.children(rows).onPrepaint((bounds, _, cx) -> {
            // Rust `view.update(cx, |r, _| r.bounds = bounds)`, which does not
            // notify: written in place, since an update while the window draws
            // would mark the menu's view dirty and draw the window again.
            view.read(cx).bounds = bounds;
        });

        final root = vFlex()
            .id('popup-menu')
            .keyContext(CONTEXT)
            .trackFocus(focusHandle)
            .onAction(SelectUp, cx.listener(selectUpListener))
            .onAction(SelectDown, cx.listener(selectDownListener))
            .onAction(SelectLeft, cx.listener(selectLeftListener))
            .onAction(SelectRight, cx.listener(selectRightListener))
            .onAction(Confirm, cx.listener(confirmListener))
            .onAction(Cancel, cx.listener(dismissListener))
            .onMouseDownOut(cx.listener(onMouseDownOutListener))
            .popoverStyle(cx.app)
            .textColor(theme.popoverForeground)
            .relative()
            .occlude()
            .child(items);
        if (scrollableValue) {
            root.verticalScrollbar(scrollHandle);
        }
        return root;
    }

    static function selectUpListener(this_:PopupMenu, action:SelectUp, window:Window, cx:Context<PopupMenu>):Void {
        this_.selectUp(action, window, cx);
    }

    static function selectDownListener(this_:PopupMenu, action:SelectDown, window:Window, cx:Context<PopupMenu>):Void {
        this_.selectDown(action, window, cx);
    }

    static function selectLeftListener(this_:PopupMenu, action:SelectLeft, window:Window, cx:Context<PopupMenu>):Void {
        this_.selectLeft(action, window, cx);
    }

    static function selectRightListener(this_:PopupMenu, action:SelectRight, window:Window, cx:Context<PopupMenu>):Void {
        this_.selectRight(action, window, cx);
    }

    static function confirmListener(this_:PopupMenu, action:Confirm, window:Window, cx:Context<PopupMenu>):Void {
        this_.confirm(action, window, cx);
    }

    static function dismissListener(this_:PopupMenu, action:Cancel, window:Window, cx:Context<PopupMenu>):Void {
        this_.dismiss(action, window, cx);
    }

    static function onMouseDownOutListener(this_:PopupMenu, event:MouseDownEvent, window:Window, cx:Context<PopupMenu>):Void {
        this_.onMouseDownOut(event, window, cx);
    }

}

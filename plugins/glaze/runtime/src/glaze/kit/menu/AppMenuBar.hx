// Ported from gpui-kit 0.8.1: crates/component/src/menu/app_menu_bar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.menu;

import glaze.App;
import glaze.AppContext;
import glaze.ClickEvent;
import glaze.Context;
import glaze.DismissEvent;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Menu.OwnedMenu;
import glaze.Model;
import glaze.MouseDownEvent;
import glaze.Render;
import glaze.ScrollHandle;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.GlobalState;
import glaze.kit.button.Button;
import glaze.kit.scroll.ScrollableMask;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.InteractiveElementExt;

/**
 * The application menu bar, for Windows and Linux, drawn in the window.
 *
 * It shows the menus of `GlobalState.appMenus()` (set them with
 * `GlobalState.global(cx).setAppMenus(...)`, then `reload`).
 */
class AppMenuBar extends Model implements Render {

    static inline final CONTEXT = 'AppMenuBar';

    public static function init(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('escape', new Cancel(), CONTEXT),
            new KeyBinding('left', new SelectLeft(), CONTEXT),
            new KeyBinding('right', new SelectRight(), CONTEXT),
        ]);
    }

    @:allow(glaze.kit, tests)
    var menus:Array<Entity<AppMenu>> = [];

    @:allow(glaze.kit, tests)
    @observe var selectedIndex:Null<Int> = null;

    @:allow(glaze.kit, tests)
    var actionContext:Null<FocusHandle> = null;

    final scrollHandle:ScrollHandle = new ScrollHandle();

    @:allow(glaze.kit, tests)
    function new() {
        super();
    }

    /**
     * Create a new app menu bar.
     *
     * Rust reloads while building the entity (with `cx.entity()`); the port
     * builds it, then reloads it (the entity must exist to own its menus).
     */
    public static function create(cx:AppContext):Entity<AppMenuBar> {
        final menuBar = (cx:App).newEntity((_:Context<AppMenuBar>) -> new AppMenuBar());
        menuBar.update(cx, (this_, cx) -> this_.reload(cx));
        return menuBar;
    }

    /**
     * Reload the menus from the app.
     */
    public function reload(cx:Context<AppMenuBar>):Void {
        final menuBar = cx.entity();
        final menus:Array<OwnedMenu> = [for (menu in GlobalState.global(cx).appMenus()) menu.clone()];
        // Rust drops the previous menus with the vector
        for (menu in this.menus) {
            (menu : AppMenu).destroy();
        }
        this.menus = [for (ix => menu in menus) AppMenu.create(ix, menu, menuBar, cx)];
        selectedIndex = null;
        actionContext = null;
        cx.notify();
    }

    function onMoveLeft(_:SelectLeft, window:Window, cx:Context<AppMenuBar>):Void {
        final selectedIndex = this.selectedIndex;
        if (selectedIndex == null) {
            return;
        }

        final newIx = if (selectedIndex == 0) {
            menus.length > 0 ? menus.length - 1 : 0;
        }
        else {
            selectedIndex - 1;
        }
        setSelectedIndex(newIx, window, cx);
    }

    function onMoveRight(_:SelectRight, window:Window, cx:Context<AppMenuBar>):Void {
        final selectedIndex = this.selectedIndex;
        if (selectedIndex == null) {
            return;
        }

        final newIx = if (selectedIndex + 1 >= menus.length) {
            0;
        }
        else {
            selectedIndex + 1;
        }
        setSelectedIndex(newIx, window, cx);
    }

    @:allow(glaze.kit)
    function onCancel(_:Null<Cancel>, window:Window, cx:Context<AppMenuBar>):Void {
        setSelectedIndex(null, window, cx);
    }

    @:allow(glaze.kit, tests)
    function setSelectedIndex(ix:Null<Int>, window:Window, cx:Context<AppMenuBar>):Void {
        if (selectedIndex == null && ix != null) {
            actionContext = window.focused(cx.app);
        }
        else if (ix == null) {
            if (actionContext != null) {
                actionContext.focus(window, cx.app);
            }
            actionContext = null;
        }

        selectedIndex = ix;
    }

    @:allow(glaze.kit.menu)
    inline function hasActivatedMenu():Bool {
        return selectedIndex != null;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<AppMenuBar> = cast cx;
        return div()
            .relative()
            .sizeFull()
            .child(
                hFlex()
                    .id('app-menu-bar')
                    .keyContext(CONTEXT)
                    .onAction(SelectLeft, cx.listener((this_:AppMenuBar, action:SelectLeft, window:Window, cx:Context<AppMenuBar>) -> this_.onMoveLeft(action, window, cx)))
                    .onAction(SelectRight, cx.listener((this_:AppMenuBar, action:SelectRight, window:Window, cx:Context<AppMenuBar>) -> this_.onMoveRight(action, window, cx)))
                    .onAction(Cancel, cx.listener((this_:AppMenuBar, action:Cancel, window:Window, cx:Context<AppMenuBar>) -> this_.onCancel(action, window, cx)))
                    .sizeFull()
                    .gapX1()
                    .overflowXScroll()
                    .lockScrollAxis()
                    .trackScroll(scrollHandle)
                    .children([for (menu in menus) (menu : IntoElement)])
            )
            .child(ScrollableMask.verticalWheel(scrollHandle));
    }

}

/**
 * A menu in the menu bar.
 */
class AppMenu extends Model implements Render {

    final menuBar:Entity<AppMenuBar>;

    final ix:Int;

    final name:String;

    final menu:OwnedMenu;

    @:allow(glaze.kit, tests)
    var popupMenu:Null<Entity<PopupMenu>> = null;

    var subscription:Null<Subscription> = null;

    function new(ix:Int, menu:OwnedMenu, menuBar:Entity<AppMenuBar>) {
        super();
        this.ix = ix;
        this.menuBar = menuBar;
        this.name = menu.name;
        this.menu = menu.clone();
    }

    @:allow(glaze.kit)
    static function create(ix:Int, menu:OwnedMenu, menuBar:Entity<AppMenuBar>, cx:AppContext):Entity<AppMenu> {
        return (cx:App).newEntity((_:Context<AppMenu>) -> new AppMenu(ix, menu, menuBar));
    }

    /**
     * Whether this menu's popup is the one the menu bar currently has open.
     */
    function isOpen(cx:App):Bool {
        return menuBar.read(cx).selectedIndex == ix;
    }

    function buildPopupMenu(window:Window, cx:Context<AppMenu>):Entity<PopupMenu> {
        final actionContext = menuBar.read(cx).actionContext;
        final popupMenu = if (this.popupMenu == null) {
            final items = [for (item in menu.items) item.clone()];
            final popupMenu = PopupMenu.build(window, cx, (menu, window, cx) -> {
                return menu.withMenuItems(items, window, cx);
            });
            popupMenu.update(cx, (menu, cx) -> {
                menu.setActionContext(actionContext, cx);
            });
            subscription = cx.subscribeIn(popupMenu, DismissEvent, window, (this_:AppMenu, emitter, event, window, cx) -> this_.handleDismiss(emitter, event, window, cx));
            this.popupMenu = popupMenu;

            popupMenu;
        }
        else {
            final menu = this.popupMenu;
            menu.update(cx, (menu, cx) -> {
                menu.setActionContext(actionContext, cx);
            });
            menu;
        }

        final focusHandle = popupMenu.read(cx).focusHandle;
        if (!focusHandle.containsFocused(window, cx.app)) {
            focusHandle.focus(window, cx.app);
        }

        return popupMenu;
    }

    function handleDismiss(_:Entity<PopupMenu>, _:DismissEvent, window:Window, cx:Context<AppMenu>):Void {
        if (subscription != null) {
            subscription.dispose();
            subscription = null;
        }
        popupMenu = null;
        menuBar.update(cx, (state, cx) -> {
            state.onCancel(null, window, cx);
        });
    }

    function handleTriggerClick(event:ClickEvent, window:Window, cx:Context<AppMenu>):Void {
        switch event {
            case Mouse(_):
                return;
            case _:
        }

        toggle(window, cx);
    }

    function toggle(window:Window, cx:Context<AppMenu>):Void {
        final isOpen = this.isOpen(cx.app);
        final ix = this.ix;
        menuBar.update(cx, (state, cx) -> {
            final newIx:Null<Int> = isOpen ? null : ix;
            state.setSelectedIndex(newIx, window, cx);
        });
    }

    function handleHover(hovered:Bool, window:Window, cx:Context<AppMenu>):Void {
        if (!hovered) {
            return;
        }

        final hasActivatedMenu = menuBar.read(cx).hasActivatedMenu();
        if (!hasActivatedMenu) {
            return;
        }

        final ix = this.ix;
        menuBar.update(cx, (state, cx) -> {
            state.setSelectedIndex(ix, window, cx);
        });
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<AppMenu> = cast cx;
        final isOpen = this.isOpen(cx.app);

        final element = div()
            .id(ix)
            .relative()
            .child(
                new Button('menu')
                    .small()
                    .py0p5()
                    .compact()
                    .ghost()
                    .label(name)
                    .open(isOpen)
                    .onMouseDown(Left, cx.listener((this_:AppMenu, _:MouseDownEvent, window:Window, cx:Context<AppMenu>) -> {
                        // Stop propagation to avoid dragging the window.
                        window.preventDefault();
                        cx.stopPropagation();
                        this_.toggle(window, cx);
                    }))
                    .onClick(cx.listener((this_:AppMenu, event:ClickEvent, window:Window, cx:Context<AppMenu>) -> this_.handleTriggerClick(event, window, cx)))
            )
            .onHover(cx.listener((this_:AppMenu, hovered:Bool, window:Window, cx:Context<AppMenu>) -> this_.handleHover(hovered, window, cx)));
        if (isOpen) {
            element.child(deferred(
                anchored()
                    .anchor(TopLeft)
                    .snapToWindowWithMargin(glaze.Edges.all(px(8.)))
                    .child(
                        div()
                            .sizeFull()
                            .occlude()
                            .top1()
                            .child(buildPopupMenu(window, cx))
                    )
            ));
        }
        return element;
    }

}

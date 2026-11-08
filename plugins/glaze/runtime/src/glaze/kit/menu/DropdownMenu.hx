// Ported from gpui-kit 0.8.1: crates/component/src/menu/dropdown_menu.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.menu;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.DismissEvent;
import glaze.Element;
import glaze.ElementId;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.RenderOnce;
import glaze.Window;
import glaze.kit.base.Popover.PopoverState;
import glaze.kit.button.Button;
import glaze.kit.menu.ContextMenu.MenuBuilder;
import glaze.kit.popover.Popover;

/**
 * A dropdown menu for buttons, as a static extension:
 * `using glaze.kit.menu.DropdownMenu;` (Rust: the `DropdownMenu`
 * trait, implemented for `Button`).
 */
class DropdownMenu {

    /**
     * Create a dropdown menu with the given items, anchored to the TopLeft corner
     */
    public static function dropdownMenu(self:Button, f:MenuBuilder):DropdownMenuPopover {
        return dropdownMenuWithAnchor(self, TopLeft, f);
    }

    /**
     * Create a dropdown menu with the given items, anchored to the given corner
     */
    public static function dropdownMenuWithAnchor(self:Button, anchor:Anchor, f:MenuBuilder):DropdownMenuPopover {
        final id:Null<ElementId> = @:privateAccess self.id;

        return new DropdownMenuPopover(id != null ? id : ElementId.Integer(0), anchor, self, f);
    }

}

/**
 * The popover of a `DropdownMenu`: the trigger and its `PopupMenu`. The
 * trigger is any `Selectable` (Rust `DropdownMenuPopover<T: Selectable>`):
 * a `Button`, a `SidebarHeader` or a `SidebarFooter`.
 */
class DropdownMenuPopover implements RenderOnce {

    final id:ElementId;

    var anchorValue:Anchor;

    final trigger:glaze.kit.base.ComponentTraits.Selectable;

    final builder:MenuBuilder;

    var onOpenChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    @:allow(glaze.kit.menu)
    function new(id:ElementId, anchor:Anchor, trigger:glaze.kit.base.ComponentTraits.Selectable, builder:MenuBuilder) {
        this.id = ElementId.Name('dropdown-menu:' + ContextMenu.debugElementId(id));
        this.anchorValue = anchor;
        this.trigger = trigger;
        this.builder = builder;
    }

    /**
     * Set the anchor corner for the dropdown menu popover.
     */
    public function anchor(anchor:Anchor):DropdownMenuPopover {
        anchorValue = anchor;
        return this;
    }

    /**
     * Add a callback to be called when the menu opens or closes, with the
     * new open state.
     */
    public function onOpenChange(callback:(Bool, Window, App) -> Void):DropdownMenuPopover {
        onOpenChangeHandler = callback;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return new TriggerFocus(id, (triggerFocus, window, cx) -> {
            final popover:IntoElement = renderPopover(triggerFocus, window, cx);
            return popover;
        });
    }

    function renderPopover(triggerFocus:FocusHandle, window:Window, cx:App):Popover {
        final builder = this.builder;
        final menuState = window.useKeyedState(id, cx, _ -> new DropdownMenuState()).read(cx).value;

        // Rust `format!("popover:{}", self.id)`: the name of the id
        final popoverId = switch id {
            case Name(name): 'popover:' + name;
            case _: 'popover:' + ContextMenu.debugElementId(id);
        };
        final popover = Popover.component(popoverId)
            .appearance(false)
            .overlayClosable(false)
            .trigger(trigger)
            .anchor(anchorValue);
        if (onOpenChangeHandler != null) {
            final callback = onOpenChangeHandler;
            popover.onOpenChange((open, window, cx) -> callback(open, window, cx));
        }
        return popover.content((_, window, cx) -> {
            // Here is special logic to only create the PopupMenu once and reuse it.
            // Because this `content` will called in every time render, so we need to store the menu
            // in state to avoid recreating at every render.
            //
            // And we also need to rebuild the menu when it is dismissed, to rebuild menu items
            // dynamically for support `dropdown_menu` method, so we listen for DismissEvent below.
            var menu = menuState.menu;
            if (menu == null) {
                menu = PopupMenu.build(window, cx, (menu, window, cx) -> {
                    return builder(menu, window, cx);
                });
                menu.update(cx, (menu, cx) -> {
                    menu.setTriggerFocus(triggerFocus, cx);
                });
                menuState.menu = menu;
                menu.read(cx).focusHandle.focus(window, cx.app);

                // Listen for dismiss events from the PopupMenu to close the popover.
                // (Rust holds weak handles here to avoid a reference cycle.)
                final popoverState = cx.weakEntity();
                window.subscribe(menu, DismissEvent, cx.app, (_, _, window, cx) -> {
                    final state = popoverState.upgrade();
                    if (state != null) {
                        state.update(cx, (state, cx) -> {
                            state.dismiss(window, cx);
                        });
                    }
                    // Rust drops the menu with its last strong handle here
                    final dismissed = menuState.menu;
                    menuState.menu = null;
                    if (dismissed != null) {
                        dismissed.intoAny().destroy();
                    }
                }).detach();
            }

            return menu;
        });
    }

}

/**
 * The menu a dropdown keeps while it is open (not observable: it is written
 * while the popover renders).
 */
private class DropdownMenuState implements glaze.Droppable {

    public var menu:Null<Entity<PopupMenu>> = null;

    public function new() {}

    /**
     * The state is dropped with the element (or the window): so is the menu
     * it holds (Rust drops its strong handle).
     */
    public function drop():Void {
        final menu = this.menu;
        this.menu = null;
        if (menu != null) {
            menu.intoAny().destroy();
        }
    }

}

/**
 * Registers a focus handle on the trigger's dispatch node without ever
 * focusing it, so the menu opened from the trigger can resolve its shortcut
 * hints against the trigger's key contexts on the frame it opens. GPUI looks
 * a handle up in the previously rendered frame; the trigger was in it when
 * the menu was not yet.
 */
private class TriggerFocus extends Element {

    final id:ElementId;

    var build:Null<(FocusHandle, Window, App) -> AnyElement>;

    // Rust's `TriggerFocusFrame` (the request layout state)
    var focusHandle:Null<FocusHandle> = null;

    var child:Null<AnyElement> = null;

    public function new(id:ElementId, build:(FocusHandle, Window, App) -> AnyElement) {
        this.id = id;
        this.build = build;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final focusHandle = window.withOptionalElementState(id, TriggerFocusState, (state, _) -> {
            if (state == null) {
                return cx.focusHandle();
            }
            if (state.value == null) {
                state.value = new TriggerFocusState();
            }
            if (state.value.focusHandle == null) {
                state.value.focusHandle = cx.focusHandle();
            }
            return state.value.focusHandle;
        });
        final build = this.build;
        this.build = null;
        if (build == null) {
            throw 'TriggerFocus is laid out once';
        }
        final child = build(focusHandle, window, cx);
        final layoutId = child.requestLayout(window, cx);

        this.focusHandle = focusHandle;
        this.child = child;
        return layoutId;
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        window.setFocusHandle(focusHandle, cx);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}

private class TriggerFocusState {

    public var focusHandle:Null<FocusHandle> = null;

    public function new() {}

}

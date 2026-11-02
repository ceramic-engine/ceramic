// Ported from gpui-kit 0.8.1: crates/component/src/menu/context_menu.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.menu;

import gpui.Anchor;
import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Bounds;
import gpui.Context;
import gpui.DismissEvent;
import gpui.Div;
import gpui.Element;
import gpui.ElementId;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.GlobalElementId;
import gpui.Hitbox;
import gpui.HitboxBehavior;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.MouseDownEvent;
import gpui.ParentElement;
import gpui.Point;
import gpui.RenderOnce;
import gpui.SizeOf;
import gpui.Style;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Subscription;
import gpui.Window;

import gpui.Prelude.*;

/**
 * Adds a context menu to an element, as a static extension:
 * `using gpui.component.menu.ContextMenu.ContextMenuExt;`.
 */
class ContextMenuExt {

    /**
     * Add a context menu to the element.
     *
     * The `ContextMenu` wraps the element and adds a child to it, an empty
     * absolute placeholder that draws the open menu as a deferred layer, so
     * it does not affect the layout of the element.
     *
     * Works on a `Div` and on a component `Button` (Rust: any
     * `InteractiveElement + ParentElement + Styled`).
     */
    public static function contextMenu<E:ParentElement & Styled>(self:E, f:(PopupMenu, Window, Context<PopupMenu>) -> PopupMenu, ?pos:haxe.PosInfos):ContextMenu<E> {
        // The ID must be stable across renders, otherwise the element state
        // (open menu) is lost on every re-render.
        final elementId = ContextMenu.interactiveElementId(self);
        final id:ElementId = elementId != null
            ? ElementId.Name('context-menu-' + ContextMenu.debugElementId(elementId))
            : ElementId.CodeLocation(pos.fileName, pos.lineNumber);
        return new ContextMenu(id, self).menu(f);
    }

}

/**
 * A context menu that can be shown on right-click, or on a long press on a
 * touch screen.
 */
class ContextMenu<E:ParentElement & Styled> extends Element implements ParentElement implements Styled {

    final id:ElementId;

    var element:Null<E>;

    var menuBuilder:Null<MenuBuilder> = null;

    // This is not in use, just for style refinement forwarding.
    final ignoreStyle:StyleRefinement = new StyleRefinement();

    final anchor:Anchor = TopLeft;

    // Rust's `RequestLayoutState` (a fresh `ContextMenuState`) and `PrepaintState`
    var layoutElement:Null<AnyElement> = null;

    var drawsMenu:Null<CellBool> = null;

    var sharedState:Null<ContextMenuSharedState> = null;

    var hitbox:Null<Hitbox> = null;

    /**
     * Create a new context menu with the given ID.
     */
    public function new(id:ElementId, element:E) {
        this.id = id;
        this.element = element;
    }

    /**
     * Build the context menu using the given builder function.
     */
    @:allow(gpui.component.menu)
    function menu(builder:MenuBuilder):ContextMenu<E> {
        menuBuilder = builder;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        if (element != null) {
            element.extend(elements);
        }
    }

    public function child(child:IntoElement):ContextMenu<E> {
        extend([child]);
        return this;
    }

    public function children(children:Array<IntoElement>):ContextMenu<E> {
        extend([for (child in children) (child : AnyElement)]);
        return this;
    }

    public function style():StyleRefinement {
        if (element != null) {
            return element.style();
        }
        return ignoreStyle;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    function withElementState<R>(id:GlobalElementId, window:Window, cx:App, f:(ContextMenu<E>, ContextMenuState, Window, App) -> R):R {
        return window.withOptionalElementState(id, ContextMenuState, (elementState, window) -> {
            if (elementState.value == null) {
                elementState.value = new ContextMenuState();
            }
            return f(this, elementState.value, window, cx);
        });
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final anchor = this.anchor;

        return withElementState(id, window, cx, (this_, state, window, cx) -> {
            final shared = state.sharedState;
            final position = shared.position;
            final open = shared.open;
            if (shared.triggerFocusHandle == null) {
                shared.triggerFocusHandle = cx.focusHandle();
            }
            final menuView = shared.menuView;
            final drawsMenu = new CellBool(false);
            final menuElement = if (menuView != null && open && !menuView.read(cx).isEmpty()) {
                new DeferredMenu(drawsMenu, menuView, position, anchor);
            }
            else {
                null;
            }

            final element = this_.element;
            this_.element = null;
            if (element == null) {
                throw 'Element should exists.';
            }
            if (menuElement != null) {
                element.extend([menuElement.intoAnyElement()]);
            }
            final element = ContextMenu.toAnyElement(element);

            final layoutId = element.requestLayout(window, cx);

            this_.layoutElement = element;
            this_.drawsMenu = drawsMenu;
            this_.sharedState = shared;
            return layoutId;
        });
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final triggerFocus = sharedState.triggerFocusHandle;
        if (triggerFocus != null) {
            window.setFocusHandle(triggerFocus, cx);
        }
        final position = sharedState.position;
        drawsMenu.value = bounds.contains(position);
        if (layoutElement != null) {
            layoutElement.prepaint(window, cx);
        }
        hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final builder = menuBuilder;
        final sharedState = this.sharedState;
        final hitbox = this.hitbox;

        // A finger has no right button, so a long press opens the menu. This
        // listener goes in before the children paint, so an input inside the
        // trigger claims its long press first. Rich-text selection is handled
        // by the window layer, which runs later; yield over its text geometry.
        window.onMouseEvent(LongPress, (event, phase, window, cx) -> {
            final event:gpui.LongPressEvent = cast event;
            if (phase.bubble()
                && event.phase == Started
                && !window.defaultPrevented()
                && hitbox.isHovered(window)
                && !gpui.base.TextSelection.isSelectableAt(event.startPosition, window, cx)) {
                window.preventDefault();
                openMenu(sharedState, builder, event.startPosition, window, cx);
            }
        });

        // Register before child paint so bubbling reaches the innermost
        // trigger first, after its input has had a chance to take focus.
        window.onMouseEvent(MouseDown, (event, phase, window, cx) -> {
            final event:MouseDownEvent = cast event;
            if (phase.bubble() && event.button == Right && hitbox.isHovered(window)) {
                cx.stopPropagation();
                openMenu(sharedState, builder, event.position, window, cx);
            }
        });

        if (layoutElement != null) {
            layoutElement.paint(window, cx);
        }
    }

    /**
     * Builds the menu and shows it at `position`.
     */
    static function openMenu(sharedState:ContextMenuSharedState, builder:Null<MenuBuilder>, position:Point, window:Window, cx:App):Void {
        // Capture the focused element to restore focus to on dismiss.
        // If focus is still on the previous menu, keep its captured focus.
        final focused = window.focused(cx);
        final previousFocusHandle = if (focused == null) {
            null;
        }
        else {
            final menu = sharedState.menuView;
            if (menu != null && menu.read(cx).focusHandle == focused) {
                menu.read(cx).previousFocusHandle;
            }
            else {
                focused;
            }
        }

        // The input whose selection the menu keeps (`selection_input`) comes
        // with the inputs (wave 6).

        // Clear any existing menu view to allow immediate replacement
        // Set the new position and open the menu
        sharedState.dropMenu();
        sharedState.position = position;
        sharedState.open = true;

        // Use defer to build the menu in the next frame, avoiding race conditions
        window.defer(cx, (window, cx) -> {
            final menu = PopupMenu.build(window, cx, (menu, window, cx) -> {
                if (builder == null) {
                    return menu;
                }
                return builder(menu, window, cx);
            });
            final triggerFocusHandle = sharedState.triggerFocusHandle;
            menu.update(cx, (menu, cx) -> {
                menu.setTriggerFocus(triggerFocusHandle, cx);
                menu.setPreviousFocus(previousFocusHandle, cx);
            });

            // Focus before the menu's first frame, not while prepainting it:
            // a frame reports one focused accessibility node, and the element
            // that held focus may already have claimed it by then.
            menu.read(cx).focusHandle.focus(window, cx);

            // Set up the subscription for dismiss handling. Rust holds a weak
            // reference to the shared state here, to avoid a reference cycle
            // (Haxe collects cycles).
            final subscription = window.subscribe(menu, DismissEvent, cx, (_, _, window, _) -> {
                sharedState.open = false;
                window.refresh();
            });

            // Update the shared state with the built menu and subscription
            sharedState.menuView = menu;
            sharedState.subscription = subscription;
            window.refresh();
        });
    }

    /**
     * The id of an interactive element (Rust `interactivity().element_id`):
     * a `Div`'s or a component `Button`'s, else null.
     */
    @:allow(gpui.component)
    static function interactiveElementId(element:Dynamic):Null<ElementId> {
        if (Std.isOfType(element, Div)) {
            return (element : Div).interactivity.elementId;
        }
        if (Std.isOfType(element, gpui.component.button.Button)) {
            return @:privateAccess (element : gpui.component.button.Button).id;
        }
        return null;
    }

    /**
     * Rust's `{:?}` of an `ElementId`.
     */
    @:allow(gpui.component)
    static function debugElementId(id:ElementId):String {
        return switch id {
            case View(entityId): 'View(EntityId($entityId))';
            case Integer(value): 'Integer($value)';
            case Name(name): 'Name("$name")';
            case NamedInteger(name, value): 'NamedInteger("$name", $value)';
            case CodeLocation(file, line): 'CodeLocation($file:$line)';
            case NamedChild(parent, name): 'NamedChild(${debugElementId(parent)}, "$name")';
        }
    }

    /**
     * Converts the wrapped element (an `Element` or a `RenderOnce`) into an `AnyElement`.
     */
    static function toAnyElement(element:Dynamic):AnyElement {
        if (Std.isOfType(element, Element)) {
            return (element : Element).intoAnyElement();
        }
        if (Std.isOfType(element, RenderOnce)) {
            final component:RenderOnce = element;
            final into:IntoElement = component;
            return into;
        }
        throw 'ContextMenu: the element must be an Element or a RenderOnce component';
    }

}

typedef MenuBuilder = (PopupMenu, Window, Context<PopupMenu>) -> PopupMenu;

/**
 * Rust's `Rc<Cell<bool>>`.
 */
private class CellBool {

    public var value:Bool;

    public function new(value:Bool) {
        this.value = value;
    }

}

/**
 * The open state shared by the triggers that use the same element state.
 */
class ContextMenuSharedState {

    public var menuView:Null<Entity<PopupMenu>> = null;

    public var open:Bool = false;

    public var position:Point = new Point(0., 0.);

    /**
     * Registered on this element's dispatch node every frame and never
     * focused, so the menu can resolve its shortcut hints against the
     * trigger's key contexts on the frame it opens: GPUI looks a handle up in
     * the previously rendered frame, where the menu's own element is not yet.
     */
    public var triggerFocusHandle:Null<FocusHandle> = null;

    public var subscription:Null<Subscription> = null;

    public function new() {}

    /**
     * Clears the menu view and its subscription. Rust drops the menu with
     * this, its only strong handle: the port destroys it.
     */
    public function dropMenu():Void {
        final menu = menuView;
        menuView = null;
        if (subscription != null) {
            subscription.dispose();
        }
        subscription = null;
        if (menu != null) {
            menu.intoAny().destroy();
        }
    }

}

/**
 * The element state of a `ContextMenu`.
 *
 * Triggers without an `ElementId` fall back to their code location, so
 * rows rendered from one call site share the element state and all see
 * the menu as open. Only the trigger that was pressed draws it (Rust's
 * `draws_menu`, kept per frame on the `ContextMenu` element): stacked copies
 * of one `PopupMenu` share an item's pending-click state, and the covered
 * copies clear it on mouse up before the visible one fires.
 */
class ContextMenuState implements gpui.Droppable {

    public final sharedState:ContextMenuSharedState = new ContextMenuSharedState();

    public function new() {}

    public function drop():Void {
        sharedState.dropMenu();
    }

}

/**
 * The deferred menu layer of one trigger.
 *
 * Every trigger that shares the open state carries one, but only the trigger
 * whose bounds contain the press builds and lays out the menu, so an open
 * menu is rendered once per frame rather than once per row.
 */
private class DeferredMenu extends Element {

    final draws:CellBool;

    final menuView:Entity<PopupMenu>;

    final position:Point;

    final anchor:Anchor;

    var menuElement:Null<AnyElement> = null;

    public function new(draws:CellBool, menuView:Entity<PopupMenu>, position:Point, anchor:Anchor) {
        this.draws = draws;
        this.menuView = menuView;
        this.position = position;
        this.anchor = anchor;
    }

    function buildMenu(window:Window):AnyElement {
        final viewport = window.viewportSize();
        return deferred(
            anchored().child(
                div()
                    .w(px(viewport.width))
                    .h(px(viewport.height))
                    .onScroll((_, _, cx) -> {
                        cx.stopPropagation();
                    })
                    .child(
                        anchored()
                            .position(position)
                            .snapToWindowWithMargin(gpui.Edges.all(px(8.)))
                            .anchor(anchor)
                            .child(menuView)
                    )
            )
        )
            .withPriority(gpui.base.Popup.POPUP_PRIORITY)
            .intoAnyElement();
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        // An empty absolute placeholder, where the menu's `anchored` root used
        // to sit, so the trigger's own layout is unchanged.
        final style = new Style();
        style.position = Absolute;
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (!draws.value) {
            return;
        }
        final menu = buildMenu(window);
        final viewport = window.viewportSize();
        menu.prepaintAsRoot(bounds.origin, new SizeOf<AvailableSpace>(Definite(viewport.width), Definite(viewport.height)), window, cx);
        menuElement = menu;
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (menuElement != null) {
            menuElement.paint(window, cx);
        }
    }

}

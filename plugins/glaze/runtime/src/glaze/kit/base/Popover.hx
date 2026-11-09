// Ported from gpui-kit 0.8.1: crates/base/src/popover.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.Bounds;
import glaze.Component;
import glaze.Context;
import glaze.DismissEvent;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Model;
import glaze.MouseButton;
import glaze.NoAction;
import glaze.Render;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.base.GlobalState.DeferredPopover;
import glaze.kit.base.Positioner.ResolvedPosition;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * State and focus lifecycle for an unstyled popover.
 *
 * Applications own trigger/content construction, positioning, appearance, and
 * animation. This state owns the controlled open lifecycle, dismissal, focus
 * capture and restoration, and deferred-popup registration.
 *
 * Emits `DismissEvent` to be dismissed (Rust `EventEmitter<DismissEvent>`).
 */
class PopoverState extends Model implements Render {

    final focusHandleValue:FocusHandle;

    var trackedFocusHandle:Null<FocusHandle> = null;

    var previousFocusHandle:Null<FocusHandle> = null;

    @observe var open:Bool;

    // Rust `on_open_change` (the observable `open` generates `onOpenChange`)
    var openChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    var dismissSubscription:Null<Subscription> = null;

    /**
     * Held while open, so that a state collected without being closed (this
     * lives in element state) takes its registration with it.
     */
    var deferredContext:Null<DeferredPopover> = null;

    public function new(defaultOpen:Bool, cx:App) {
        super();
        focusHandleValue = cx.focusHandle();
        open = defaultOpen;
    }

    public function isOpen():Bool {
        return open;
    }

    public function dismiss(window:Window, cx:Context<PopoverState>):Void {
        if (open) {
            toggleOpen(window, cx);
        }
    }

    public function show(window:Window, cx:Context<PopoverState>):Void {
        if (!open) {
            toggleOpen(window, cx);
        }
    }

    public function setOpen(open:Bool, cx:AppContext):Void {
        this.open = open;
        if (deferredContext != null) {
            // Rust drops the previous token by replacing it.
            deferredContext.release();
        }
        deferredContext = open ? GlobalState.registerDeferredPopover(cx) : null;
    }

    public function syncOpen(open:Bool, window:Window, cx:Context<PopoverState>):Void {
        transitionTo(open, false, window, cx);
    }

    public function toggleOpen(window:Window, cx:Context<PopoverState>):Void {
        transitionTo(!open, true, window, cx);
    }

    function transitionTo(opening:Bool, announce:Bool, window:Window, cx:Context<PopoverState>):Void {
        if (open == opening) {
            return;
        }
        if (opening) {
            previousFocusHandle = window.focused(cx.app);
        }
        setOpen(opening, cx.app);

        if (open) {
            // Weak: the subscription is stored on this state, so a strong
            // handle would keep the state, and its deferred-popover
            // registration, alive after its trigger is gone.
            final state = cx.weakEntity();
            (trackedFocusHandle != null ? trackedFocusHandle : focusHandleValue).focus(window, cx.app);

            if (dismissSubscription != null) dismissSubscription.dispose();
            dismissSubscription = window.subscribe(cx.entity(), DismissEvent, cx.app, (_, _, window, cx) -> {
                state.tryUpdate(cx, (state, cx) -> state.dismiss(window, cx));
                window.refresh();
            });
        }
        else {
            if (dismissSubscription != null) {
                dismissSubscription.dispose();
                dismissSubscription = null;
            }
            final previous = previousFocusHandle;
            previousFocusHandle = null;
            if (previous != null) {
                if (focusHandleValue.containsFocused(window, cx.app)) {
                    previous.focus(window, cx.app);
                }
            }
        }

        if (announce && openChangeHandler != null) {
            openChangeHandler(opening, window, cx.app);
        }
        // Rust `cx.notify()`: `open` is observable.
    }

    public function trackFocus(focusHandle:Null<FocusHandle>):Void {
        trackedFocusHandle = focusHandle;
    }

    public function setOnOpenChange(handler:Null<(Bool, Window, App) -> Void>):Void {
        openChangeHandler = handler;
    }

    public function onActionCancel(_:Cancel, window:Window, cx:Context<PopoverState>):Void {
        dismiss(window, cx);
    }

    /** Rust `Focusable::focus_handle`. */
    public function focusHandle(?cx:App):FocusHandle {
        return focusHandleValue;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

    override function destroy() {
        // Rust drops the subscription and the deferred-popover token with the state.
        if (dismissSubscription != null) {
            dismissSubscription.dispose();
            dismissSubscription = null;
        }
        if (deferredContext != null) {
            deferredContext.release();
            deferredContext = null;
        }
        super.destroy();
    }

}

/**
 * An unstyled popover owning trigger interaction, open state, dismissal, and focus.
 *
 * Enter and Space on the trigger toggle the popover. Inside its content, those
 * keys belong to the focused control instead; Escape dismisses the popover and
 * restores the previous focus.
 *
 * Its style applies to the trigger container: the element that takes part in
 * the parent layout and whose bounds the popup is anchored to.
 */
class Popover extends Component implements Styled {

    static inline final CONTEXT = 'Popover';

    static inline final CONTENT_CONTEXT = 'PopoverContent';

    public static function bindKeys(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('escape', new Cancel(), CONTEXT),
            new KeyBinding('enter', new Confirm(false), CONTEXT),
            new KeyBinding('space', new Confirm(false), CONTEXT),
            new KeyBinding('escape', new Cancel(), CONTENT_CONTEXT),
            // The content is still a descendant of the trigger's dispatch node.
            // Leave activation to its controls, not the trigger or an outer dialog.
            // More deeply scoped input bindings retain precedence.
            new KeyBinding('enter', new NoAction(), CONTENT_CONTEXT),
            new KeyBinding('space', new NoAction(), CONTENT_CONTEXT)
        ]);
    }

    final id:ElementId;

    final popoverStyle:StyleRefinement = new StyleRefinement();

    @prop var anchor:Anchor = Anchor.TopLeft;

    /**
     * Gap from the trigger along the anchor's outward direction, zero by default.
     */
    @prop var offset:Float = 0.;

    /**
     * Observe geometry to supply presentation such as a pointer arrow.
     */
    @prop var onPosition:Null<(ResolvedPosition, Bounds) -> Void> = null;

    @prop var defaultOpen:Bool = false;

    @prop var open:Null<Bool> = null;

    @prop var trackFocus:Null<FocusHandle> = null;

    /**
     * Supplies a trigger builder for higher-level presentation facades.
     */
    @prop var triggerWith:Null<(Bool, Window, App) -> AnyElement> = null;

    var contentBuilder:Null<(PopoverState, Window, Context<PopoverState>) -> AnyElement> = null;

    @prop var mouseButton:MouseButton = MouseButton.Left;

    @prop var overlayClosable:Bool = true;

    @prop var onOpenChange:Null<(Bool, Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return popoverStyle;
    }

    /**
     * Sets the trigger: a `Selectable` element, marked open while the
     * popover is open.
     */
    public function trigger(trigger:Selectable):Popover {
        triggerWith = (isOpen, _, _) -> {
            final open = trigger.isOpen();
            trigger.setOpen(open || isOpen);
            return selectableElement(trigger);
        };
        return this;
    }

    /**
     * A `Selectable` trigger as an element (Rust `T: Selectable + IntoElement`):
     * a component or an element.
     */
    public static function selectableElement(trigger:Selectable):AnyElement {
        if (Std.isOfType(trigger, RenderOnce)) {
            final component:RenderOnce = cast trigger;
            return (component : IntoElement);
        }
        final element:glaze.Element = cast trigger;
        return (element : IntoElement);
    }

    public function content(content:(PopoverState, Window, Context<PopoverState>) -> IntoElement):Popover {
        contentBuilder = (state, window, cx) -> content(state, window, cx);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final defaultOpen = this.defaultOpen;
        final state:Entity<PopoverState> = KeyedEntity.use(window, id, cx, (_, stateCx:Context<PopoverState>) -> new PopoverState(defaultOpen, stateCx.app));
        final trackedFocusHandle = this.trackFocus;
        final onOpenChange = this.onOpenChange;
        final openValue = this.open;
        state.update(cx, (state, stateCx) -> {
            state.trackFocus(trackedFocusHandle);
            state.setOnOpenChange(onOpenChange);
            if (openValue != null) {
                state.syncOpen(openValue, window, stateCx);
            }
            return null;
        });

        final open = (state : PopoverState).isOpen();
        final focusHandle = (state : PopoverState).focusHandle(cx);
        final trigger = triggerWith;
        if (trigger == null) {
            return div().id('empty');
        }
        final parentViewId = window.currentView();
        final popup = Popup.component(id, trigger(open, window, cx))
            .refineStyle(popoverStyle)
            .anchor(anchor)
            .offset(offset);
        final onPosition = this.onPosition;
        if (onPosition != null) {
            popup.onPosition(onPosition);
        }
        popup
            .keyContext(CONTEXT)
            .onAction(Confirm, (_, window, cx) -> {
                state.update(cx, (state, cx) -> state.toggleOpen(window, cx));
                cx.notify(parentViewId);
            })
            .onMouseDown(mouseButton, (_, window, cx) -> {
                cx.stopPropagation();
                state.update(cx, (state, cx) -> {
                    if (state.isOpen() == open) {
                        state.toggleOpen(window, cx);
                    }
                    return null;
                });
                cx.notify(parentViewId);
            });
        if (!open) {
            return popup;
        }

        final content = div()
            .id('content')
            // A popover surface is a non-modal dialog: it takes focus and is
            // dismissed with Escape. Rust exports `Role::Dialog` to assistive
            // technology (no accesskit in the port).
            .occlude()
            .tabGroup()
            .trackFocus(focusHandle)
            .keyContext(CONTENT_CONTEXT)
            .onAction(Cancel, (action, window, cx) -> state.update(cx, (state, cx) -> state.onActionCancel(action, window, cx)));
        final contentBuilder = this.contentBuilder;
        if (contentBuilder != null) {
            content.child(state.update(cx, (state, stateCx) -> contentBuilder(state, window, stateCx)));
        }
        if (overlayClosable) {
            content.onMouseDownOut((_, window, cx) -> {
                state.update(cx, (state, cx) -> state.dismiss(window, cx));
                cx.notify(parentViewId);
            });
        }
        return popup.content(content);
    }

}

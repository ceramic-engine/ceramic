// Ported from gpui-kit 0.8.1: crates/base/src/hover_card.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.Anchor;
import gpui.AnyElement;
import gpui.App;
import gpui.Context;
import gpui.Div;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.MouseButton;
import gpui.Render;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Task;
import gpui.Unit;
import gpui.Window;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * An unstyled popup with delayed hover behavior on desktop.
 * On iOS and Android, tapping toggles it and tapping outside dismisses it.
 *
 * Its style applies to the trigger container: the element that takes part in
 * the parent layout and whose bounds the card is anchored to. Delays are in
 * seconds.
 */
class HoverCard implements RenderOnce implements Styled {

    /** The error thrown by `trigger(null)`. */
    public static inline final NULL_TRIGGER_ERROR = 'HoverCard.trigger: the trigger element must not be null';

    final id:ElementId;

    final hoverCardStyle:StyleRefinement = new StyleRefinement();

    var anchorValue:Anchor = Anchor.TopCenter;

    @:allow(tests)
    var tapToOpen:Bool = gpui.base.Prelude.isMobile();

    var triggerElement:Null<AnyElement> = null;

    var contentBuilder:Null<(HoverCardState, Window, Context<HoverCardState>) -> Div> = null;

    var openDelayValue:Float = 0.6;

    var closeDelayValue:Float = 0.3;

    var onOpenChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return hoverCardStyle;
    }

    public function anchor(anchor:Anchor):HoverCard {
        anchorValue = anchor;
        return this;
    }

    /**
     * Set the trigger element. It is mandatory: a null trigger throws
     * instead of rendering a card nobody can open.
     */
    public function trigger(trigger:IntoElement):HoverCard {
        if (trigger == null) throw NULL_TRIGGER_ERROR;
        triggerElement = trigger;
        return this;
    }

    /**
     * The content builder, returning a stateful `Div` (Rust `Stateful<Div>`).
     */
    public function content(content:(HoverCardState, Window, Context<HoverCardState>) -> Div):HoverCard {
        contentBuilder = content;
        return this;
    }

    public function openDelay(duration:Float):HoverCard {
        openDelayValue = duration;
        return this;
    }

    public function closeDelay(duration:Float):HoverCard {
        closeDelayValue = duration;
        return this;
    }

    public function onOpenChange(callback:(Bool, Window, App) -> Void):HoverCard {
        onOpenChangeHandler = callback;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final openDelay = openDelayValue;
        final closeDelay = closeDelayValue;
        final state:Entity<HoverCardState> = KeyedEntity.use(window, id, cx, (_, _) -> new HoverCardState(openDelay, closeDelay));
        final onOpenChange = onOpenChangeHandler;
        state.update(cx, (state, _) -> state.sync(openDelay, closeDelay, onOpenChange));
        final open = (state : HoverCardState).isOpen();

        final trigger:AnyElement = triggerElement != null ? triggerElement : div().intoAnyElement();
        final triggerDiv = div()
            .id('trigger')
            .child(trigger);
        if (tapToOpen) {
            triggerDiv.onClick((_, window, cx) -> state.update(cx, (state, cx) -> {
                state.cancelTasks();
                // Toggle the state rendered by this trigger even if
                // outside dismissal handles the same release first.
                state.setOpen(!open, window, cx);
            }));
        }
        if (!tapToOpen) {
            triggerDiv.onHover((hovered, window, cx) -> state.update(cx, (state, cx) -> state.onTriggerHover(hovered, window, cx)));
        }
        final popup = new Popup(id, triggerDiv)
            .refineStyle(hoverCardStyle)
            .anchor(anchorValue);

        if (!open) {
            return popup;
        }

        final content = contentBuilder;
        if (content != null) {
            final hover = (hovered:Bool, window:Window, cx:App) -> state.update(cx, (state, cx) -> state.onContentHover(hovered, window, cx));
            final dismiss = (_, window:Window, cx:App) -> state.update(cx, (state, cx) -> {
                state.cancelTasks();
                state.setOpen(false, window, cx);
            });
            final tapToOpen = this.tapToOpen;
            popup.content(state.update(cx, (state, stateCx) -> {
                final element = content(state, window, stateCx);
                if (tapToOpen) {
                    element.onMouseUpOut(MouseButton.Left, dismiss);
                }
                if (!tapToOpen) {
                    element.onHover(hover);
                }
                return element;
            }));
        }
        return popup;
    }

}

/**
 * State exposed to a `HoverCard.content` builder.
 */
class HoverCardState extends Model implements Render {

    @observe var open:Bool = false;

    var openDelay:Float;

    var closeDelay:Float;

    // Rust `on_open_change` (the observable `open` generates `onOpenChange`)
    var openChangeHandler:Null<(Bool, Window, App) -> Void> = null;

    var openTask:Null<Task<Unit>> = null;

    var closeTask:Null<Task<Unit>> = null;

    var epoch:Int = 0;

    var isHoveringTrigger:Bool = false;

    var isHoveringContent:Bool = false;

    @:allow(gpui.base)
    function new(openDelay:Float, closeDelay:Float) {
        super();
        this.openDelay = openDelay;
        this.closeDelay = closeDelay;
    }

    public function isOpen():Bool {
        return open;
    }

    @:allow(gpui.base)
    function sync(openDelay:Float, closeDelay:Float, onOpenChange:Null<(Bool, Window, App) -> Void>):Void {
        this.openDelay = openDelay;
        this.closeDelay = closeDelay;
        this.openChangeHandler = onOpenChange;
    }

    function scheduleOpen(window:Window, cx:Context<HoverCardState>):Void {
        cancelTasks();
        final epoch = nextEpoch();
        final delay = openDelay;
        openTask = cx.spawn((this_, acx) -> acx.backgroundExecutor().timer(delay).then(_ -> {
            if (window.isDestroyed()) return;
            this_.tryUpdate(acx, (state, cx) -> {
                if (state.epoch == epoch) {
                    state.setOpen(true, window, cx);
                }
            });
        }));
    }

    function scheduleClose(window:Window, cx:Context<HoverCardState>):Void {
        cancelTasks();
        final epoch = nextEpoch();
        final delay = closeDelay;
        closeTask = cx.spawn((this_, acx) -> acx.backgroundExecutor().timer(delay).then(_ -> {
            if (window.isDestroyed()) return;
            this_.tryUpdate(acx, (state, cx) -> {
                if (state.epoch == epoch && !state.isHoveringTrigger && !state.isHoveringContent) {
                    state.setOpen(false, window, cx);
                }
            });
        }));
    }

    @:allow(gpui.base)
    function cancelTasks():Void {
        epoch += 1;
        // Rust drops the tasks, which cancels them.
        if (openTask != null) openTask.cancel();
        openTask = null;
        if (closeTask != null) closeTask.cancel();
        closeTask = null;
    }

    function nextEpoch():Int {
        epoch += 1;
        return epoch;
    }

    @:allow(gpui.base)
    function setOpen(open:Bool, window:Window, cx:Context<HoverCardState>):Void {
        if (this.open == open) {
            return;
        }

        this.open = open;
        // The change is announced from here rather than from the element,
        // because the delay timers outlive the `HoverCard` that carried the
        // handler: by the time the state flips, that element is long gone.
        final onOpenChange = openChangeHandler;
        if (onOpenChange != null) {
            onOpenChange(open, window, cx.app);
        }
    }

    @:allow(gpui.base)
    function onTriggerHover(hovering:Bool, window:Window, cx:Context<HoverCardState>):Void {
        isHoveringTrigger = hovering;
        if (hovering) {
            scheduleOpen(window, cx);
        }
        else if (!isHoveringContent) {
            scheduleClose(window, cx);
        }
    }

    @:allow(gpui.base)
    function onContentHover(hovering:Bool, window:Window, cx:Context<HoverCardState>):Void {
        isHoveringContent = hovering;
        if (hovering) {
            cancelTasks();
        }
        else if (!isHoveringTrigger) {
            scheduleClose(window, cx);
        }
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

    override function destroy() {
        cancelTasks();
        super.destroy();
    }

}

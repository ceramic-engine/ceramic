// Ported from gpui-kit 0.8.1: crates/base/src/hover_card.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Task;
import glaze.Unit;
import glaze.Window;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An unstyled popup with delayed hover behavior on desktop.
 * On iOS and Android, tapping toggles it and tapping outside dismisses it.
 *
 * Its style applies to the trigger container: the element that takes part in
 * the parent layout and whose bounds the card is anchored to. Delays are in
 * seconds.
 */
class HoverCard extends Component implements Styled {

    /** The error thrown by `trigger(null)`. */
    public static inline final NULL_TRIGGER_ERROR = 'HoverCard.trigger: the trigger element must not be null';

    final id:ElementId;

    final hoverCardStyle:StyleRefinement = new StyleRefinement();

    @prop var anchor:Anchor = Anchor.TopCenter;

    @:allow(tests)
    var tapToOpen:Bool = glaze.kit.base.Prelude.isMobile();

    var triggerElement:Null<AnyElement> = null;

    /**
     * The content builder, returning a stateful `Div` (Rust `Stateful<Div>`).
     */
    @prop var content:Null<(HoverCardState, Window, Context<HoverCardState>) -> Div> = null;

    @prop var openDelay:Float = 0.6;

    @prop var closeDelay:Float = 0.3;

    @prop var onOpenChange:Null<(Bool, Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return hoverCardStyle;
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

    public function render(window:Window, cx:App):IntoElement {
        final openDelay = this.openDelay;
        final closeDelay = this.closeDelay;
        final state:Entity<HoverCardState> = KeyedEntity.use(window, id, cx, (_, _) -> new HoverCardState(openDelay, closeDelay));
        final onOpenChange = this.onOpenChange;
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
        final popup = Popup.component(id, triggerDiv)
            .refineStyle(hoverCardStyle)
            .anchor(anchor);

        if (!open) {
            return popup;
        }

        final content = this.content;
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

    @:allow(glaze.kit.base)
    function new(openDelay:Float, closeDelay:Float) {
        super();
        this.openDelay = openDelay;
        this.closeDelay = closeDelay;
    }

    public function isOpen():Bool {
        return open;
    }

    @:allow(glaze.kit.base)
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

    @:allow(glaze.kit.base)
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

    @:allow(glaze.kit.base)
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

    @:allow(glaze.kit.base)
    function onTriggerHover(hovering:Bool, window:Window, cx:Context<HoverCardState>):Void {
        isHoveringTrigger = hovering;
        if (hovering) {
            scheduleOpen(window, cx);
        }
        else if (!isHoveringContent) {
            scheduleClose(window, cx);
        }
    }

    @:allow(glaze.kit.base)
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

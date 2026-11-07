// Ported from gpui-kit 0.8.1: crates/component/src/tooltip.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.tooltip;

import glaze.Action;
import glaze.AnyElement;
import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Bounds;
import glaze.Context;
import glaze.Div;
import glaze.ElementId;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.Model;
import glaze.ParentElement;
import glaze.MouseButton;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.Tooltip as BaseTooltip;
import glaze.kit.base.Tooltip.TooltipOverlay as BaseTooltipOverlay;
import glaze.kit.base.Tooltip.TooltipRequest as BaseTooltipRequest;
import glaze.kit.base.Tooltip.TooltipTransition as BaseTooltipTransition;
import glaze.kit.base.animation.EffectTransition;
import glaze.kit.base.animation.Easings;
import glaze.kit.WindowState;
import glaze.kit.kbd.Kbd;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.StyledExt;

/**
 * The content of a tooltip: rich `Text` (a plain string or a text view) or a
 * custom element.
 */
enum TooltipContext {

    Text(text:glaze.kit.text.Text);

    Element(builder:(Window, App) -> AnyElement);

}

/**
 * A Tooltip element that can display text or custom content,
 * with optional key binding information.
 */
class Tooltip extends Model implements Render implements Styled {

    public static function init(_:AppContext):Void {
        // No app-level init needed: TooltipOverlay is per-window via Root.
    }

    final tooltipStyle:StyleRefinement = new StyleRefinement();

    var content:TooltipContext;

    var keyBindingValue:Null<Kbd> = null;

    var actionValue:Null<{action:Action, context:Null<String>}> = null;

    /**
     * Create a Tooltip with a text content.
     */
    public function new(text:glaze.kit.text.Text.IntoText) {
        super();
        content = Text(text);
    }

    /**
     * Create a Tooltip with a custom element.
     */
    public static function element(builder:(Window, App) -> IntoElement):Tooltip {
        final tooltip = new Tooltip('');
        tooltip.content = Element((window, cx) -> builder(window, cx));
        return tooltip;
    }

    public inline function style():StyleRefinement {
        return tooltipStyle;
    }

    /**
     * Set Action to display key binding information for the tooltip if it exists.
     */
    public function action(action:Action, context:Null<String>):Tooltip {
        actionValue = {action: action, context: context};
        return this;
    }

    /**
     * Set KeyBinding information for the tooltip.
     */
    public function keyBinding(keyBinding:Null<Kbd>):Tooltip {
        keyBindingValue = keyBinding;
        return this;
    }

    /**
     * Build the tooltip and return it as an `AnyView`.
     */
    public function build(window:Window, cx:App):AnyView {
        return cx.newEntity((_:Context<Tooltip>) -> this);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final keyBinding:Null<Kbd> = if (keyBindingValue != null) {
            keyBindingValue;
        }
        else if (actionValue != null) {
            Kbd.bindingForAction(actionValue.action, actionValue.context, window);
        }
        else {
            null;
        };

        final theme = Theme.global(cx.app);
        final popup = new BaseTooltip('tooltip-popup')
            .hFlex()
            .fontFamily(theme.fontFamily)
            .m3()
            .bg(theme.tokens.popover.background)
            .textColor(theme.popoverForeground)
            .bg(theme.tokens.popover.background)
            .border1()
            .borderColor(theme.border)
            .shadowMd()
            .rounded(theme.radius)
            .justifyBetween()
            .py0p5()
            .px2()
            .textSm()
            .gap3()
            .refineStyle(tooltipStyle);
        final inner = div();
        switch content {
            case Text(text):
                inner.child(glaze.kit.text.Text.TextTools.intoAnyElement(text));
            case Element(builder):
                inner.child(builder(window, cx.app));
        }
        popup.child(inner);
        if (keyBinding != null) {
            popup.child(
                div()
                    .textXs()
                    .flexShrink0()
                    .textColor(theme.mutedForeground)
                    .child(keyBinding.appearance(false))
            );
        }
        // Wrap in a child, to ensure the left margin is applied to the tooltip
        return div().child(popup);
    }

/// Managed tooltip system

    /** Duration of the slide-down enter animation, in seconds. */
    static inline final ENTER_DURATION:Float = 0.15;

    /** Duration of the position-slide animation when switching tooltips, in seconds. */
    static inline final SLIDE_DURATION:Float = 0.2;

    @:allow(glaze.kit)
    @:allow(tests)
    static function renderTooltip(contentView:AnyView, transition:BaseTooltipTransition, _:Window, _:App):AnyElement {
        final element = div().child(contentView);
        return switch transition {
            case Switch(epoch, previous, current):
                final sameRow = Math.abs(current.origin.y - previous.origin.y) < 10.;
                if (!sameRow) {
                    element.intoAnyElement();
                }
                else {
                    final dx = current.center().x - previous.center().x;
                    new EffectTransition(SLIDE_DURATION)
                        .ease(Easings.easeInOutCubic)
                        .slideX(-dx, 0.)
                        .apply(element, ElementId.NamedInteger('tooltip-slide', epoch))
                        .intoAnyElement();
                }
            case Enter(epoch):
                new EffectTransition(ENTER_DURATION)
                    .ease(Easings.easeOutCubic)
                    .slideY(4., 0.)
                    .fade(0.0, 1.0)
                    .apply(element, ElementId.NamedInteger('tooltip-enter', epoch))
                    .intoAnyElement();
        }
    }

}

/**
 * Shared tooltip state that components (Button, Switch, Checkbox, Radio, etc.)
 * can embed to get `.tooltip()` support with minimal boilerplate.
 */
class ComponentTooltip {

    public var text:Null<{text:String, action:Null<{action:Action, context:Null<String>}>}> = null;

    public var builder:Null<(Window, App) -> AnyView> = null;

    /** Seconds (Rust `Duration`). */
    public var showDelay:Null<Float> = null;

    public function new() {}

    /**
     * The tooltip of a control that stores its text and show delay
     * (`tooltip(text)`, `tooltipShowDelay(seconds)`).
     */
    public static function of(text:Null<String>, showDelay:Null<Float>):ComponentTooltip {
        final tooltip = new ComponentTooltip();
        if (text != null) tooltip.text = {text: text, action: null};
        tooltip.showDelay = showDelay;
        return tooltip;
    }

    /**
     * Apply this tooltip to a stateful element: `parent` receives the
     * prepaint probe as a child, `interactive` (its stateful `Div`, Rust
     * `InteractiveElement::interactivity`) the listeners.
     */
    public function apply<T:ParentElement>(parent:T, interactive:Div):T {
        final showDelay = this.showDelay;
        final builder = this.builder;
        final text = this.text;
        if (builder != null) {
            ManagedTooltip.managedTooltipOn(parent, interactive, null, showDelay, (window, cx) -> builder(window, cx));
        }
        else if (text != null) {
            ManagedTooltip.managedTooltipOn(parent, interactive, null, showDelay, (window, cx) -> {
                final tooltip = new Tooltip(text.text);
                if (text.action != null) {
                    tooltip.action(text.action.action, text.action.context);
                }
                return tooltip.build(window, cx);
            });
        }
        return parent;
    }

}

/**
 * Keeps a tooltip trigger's identity alive while its element is rendered
 * (Rust `TooltipLifetime(Rc<()>)`, kept in element state; its weak handle
 * upgrades while the model is not destroyed).
 */
class TooltipLifetime extends Model {

    public function new() {
        super();
    }

    /** Rust `Weak::upgrade().is_some()`. */
    public static inline function isAlive(lifetime:Null<TooltipLifetime>):Bool {
        return lifetime != null && !lifetime.destroyed;
    }

}

private class TooltipTrigger {

    public var id:Null<GlobalElementId> = null;

    public var lifetime:Null<TooltipLifetime> = null;

    public var bounds:Bounds = new Bounds();

    public function new() {}

}

/**
 * The managed tooltip of a stateful `Div`, as a static extension:
 * `using glaze.kit.tooltip.Tooltip.ManagedTooltip;` (Rust's crate
 * private `ManagedTooltipExt`).
 */
class ManagedTooltip {

    public static function managedTooltip(self:Div, buildTooltip:(Window, App) -> AnyView):Div {
        return managedTooltipWith(self, null, null, buildTooltip);
    }

    public static function managedTooltipAt(self:Div, placement:Placement, buildTooltip:(Window, App) -> AnyView):Div {
        return managedTooltipWith(self, placement, null, buildTooltip);
    }

    public static function managedTooltipWith(self:Div, preferredPlacement:Null<Placement>, showDelay:Null<Float>, buildTooltip:(Window, App) -> AnyView):Div {
        return managedTooltipOn(self, self, preferredPlacement, showDelay, buildTooltip);
    }

    /**
     * Rust's `ManagedTooltipExt` on an element that delegates its
     * interactivity: the prepaint probe goes to `parent`'s children, the
     * listeners to `self`.
     */
    public static function managedTooltipOn<T:ParentElement>(parent:T, self:Div, preferredPlacement:Null<Placement>, showDelay:Null<Float>, buildTooltip:(Window, App) -> AnyView):T {
        final trigger = new TooltipTrigger();

        parent.onPrepaint((bounds, window, _) -> {
            final id = window.withGlobalId('managed-tooltip-trigger', (id, _) -> id);
            // GPUI retains keyed element state for cached subtrees too, and
            // drops it after a frame that no longer contains the trigger.
            final lifetime = window.withElementState(id, TooltipLifetime, (state, _) -> {
                if (state.value == null) {
                    state.value = new TooltipLifetime();
                }
                return state.value;
            });
            trigger.id = id;
            trigger.lifetime = lifetime;
            trigger.bounds = bounds;
        });
        self.onHover((hovered, window, cx) -> {
            final id = trigger.id;
            if (id == null) {
                return;
            }
            final bounds = trigger.bounds;
            // A press keeps the tooltip dismissed until the pointer leaves
            // the trigger. This also drops the hover-enter that a click
            // removing the trigger dispatches to the stale frame.
            if (hovered && WindowState.isTooltipTriggerPressed(bounds, window, cx)) {
                return;
            }
            final overlay = WindowState.tooltipOverlayForTrigger(id, trigger.lifetime, hovered, window, cx);
            if (overlay != null) {
                if (hovered) {
                    overlay.update(cx, (o, cx) -> {
                        final build = buildTooltip;
                        final request = new BaseTooltipRequest(bounds, (window, cx) -> build(window, cx));
                        if (preferredPlacement != null) request.withPlacement(preferredPlacement);
                        if (showDelay != null) request.withShowDelay(showDelay);
                        o.requestShow(request, window, cx);
                    });
                }
                else {
                    overlay.update(cx, (o, cx) -> o.requestHide(window, cx));
                }
            }
        });
        self.onMouseDown(MouseButton.Left, (_, window, cx) -> {
            WindowState.pressTooltipTrigger(trigger.bounds, window, cx);
            final overlay = WindowState.tooltipOverlay(window, cx);
            if (overlay != null) {
                overlay.update(cx, (overlay, cx) -> overlay.hide(cx));
            }
        });
        return parent;
    }

}

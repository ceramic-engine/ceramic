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
            .textColor(theme.tooltipForeground != null ? theme.tooltipForeground : theme.popoverForeground)
            .bg(theme.tokens.popover.background)
            .border1()
            .borderColor(theme.tooltipBorder != null ? theme.tooltipBorder : theme.border)
            .shadowMd()
            .rounded(theme.radius)
            .justifyBetween()
            .py0p5()
            .px2()
            .textSm()
            .gap3()
            .refineStyle(tooltipStyle);
        if (theme.tooltipBackground != null) popup.bg(theme.tooltipBackground);
        if (theme.tooltipGap != null) popup.m(px(theme.tooltipGap));
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
        final wrapper = div().child(popup);
        if (theme.tooltipArrow) {
            // The arrow is drawn after the popup, not inside it: a border is painted after the children of its
            // element, so an arrow inside the popup could not cover the border under its base. The popup tells
            // where it is: its margins may or may not be part of the wrapper
            final placed:{bounds:Null<Bounds>} = {bounds: null};
            popup.child(canvas((inside, _, _) -> {
                // What fills the popup is inside its 1 px border
                placed.bounds = new Bounds(new glaze.Point((inside.origin.x : Float) - 1., (inside.origin.y : Float) - 1.),
                    new glaze.Size(px((inside.size.width : Float) + 2.), px((inside.size.height : Float) + 2.)));
                return null;
            }, (_, _, _, _) -> {}).absolute().inset0());
            wrapper.relative().child(arrow(theme, window, placed));
        }
        return wrapper;
    }

    /**
     * The arrow of the popup: an element drawn after the popup, that
     * paints outside of it a triangle aimed at what the tooltip describes.
     * `placed` holds the bounds of the popup, known once it is laid out.
     *
     * The side comes from the positioner of the window's tooltip overlay,
     * which is the one that chose it (it flips the tooltip when it does not
     * fit), and is known when the popup paints.
     */
    static function arrow(theme:Theme, window:Window, placed:{bounds:Null<Bounds>}):IntoElement {
        final background = theme.tooltipBackground != null ? theme.tooltipBackground : theme.popover;
        final border = theme.tooltipBorder != null ? theme.tooltipBorder : theme.border;
        final radius:Float = theme.radius;
        return canvas((_, _, _) -> null, (_, _, window, cx) -> {
            final surface = placed.bounds;
            if (surface == null) return;
            final overlay = WindowState.tooltipOverlay(window, cx);
            if (overlay == null) return;
            final shown = overlay.read(cx);
            final trigger = shown.triggerBounds();
            final position = shown.position();
            if (trigger == null || position == null || position.placement == null) return;
            // The arrow never reaches further than the gap the popup keeps from what it describes
            final gap:Float = theme.tooltipGap != null ? theme.tooltipGap : window.remSize() * 0.75;
            final depth = Math.min(ARROW_DEPTH, Math.max(0, gap - 1));
            if (depth <= 0) return;
            final side = position.placement;
            final points = glaze.kit.popover.Popover.arrowPoints(surface, trigger, side, depth, radius);
            // The base of the arrow is on the outer edge of the popup. Its sides are drawn from the middle of
            // the 1 px border, and go on through it: the border and the sides are then one line that turns,
            // and what is filled between them hides the border under the arrow
            final inwardX:Float = switch side {
                case Right: 1.;
                case Left: -1.;
                case _: 0.;
            }
            final inwardY:Float = switch side {
                case Bottom: 1.;
                case Top: -1.;
                case _: 0.;
            }
            inline function onBorder(point:glaze.Point):glaze.Point {
                return new glaze.Point((point.x : Float) + inwardX * 0.5, (point.y : Float) + inwardY * 0.5);
            }
            final tip = onBorder(points[1]);
            // A side prolonged past its base point, to the inner edge of the border
            function foot(point:glaze.Point):glaze.Point {
                final base = onBorder(point);
                final along = 0.5 / depth;
                return new glaze.Point((base.x : Float) + ((base.x : Float) - (tip.x : Float)) * along, (base.y : Float) + ((base.y : Float) - (tip.y : Float)) * along);
            }
            final first = foot(points[0]);
            final last = foot(points[2]);
            final shape = glaze.PathBuilder.fill();
            shape.moveTo(first);
            shape.lineTo(tip);
            shape.lineTo(last);
            shape.close();
            final path = glaze.kit.popover.Popover.tryBuild(shape);
            if (path != null) window.paintPath(path, background);
            final outline = glaze.PathBuilder.stroke(px(1.));
            // The line stops in the middle of the border: further, its end would show under it
            outline.moveTo(onBorder(points[0]));
            outline.lineTo(tip);
            outline.lineTo(onBorder(points[2]));
            final stroke = glaze.kit.popover.Popover.tryBuild(outline);
            if (stroke != null) window.paintPath(stroke, border);
        }).absolute().inset0().sizeFull();
    }

    /**
     * Shows a tooltip for an area of the window, at once, without a hover:
     * for a gesture that tells its value while it lasts (a drag). It stays
     * until `hideShown` or until another tooltip takes its place.
     */
    public static function showAt(area:Bounds, text:String, window:Window, cx:App, ?placement:Placement):Void {
        final overlay = WindowState.tooltipOverlay(window, cx);
        if (overlay == null) return;
        overlay.update(cx, (shown, cx) -> {
            final request = new BaseTooltipRequest(area, (window, cx) -> new Tooltip(text).build(window, cx)).withShowDelay(0);
            if (placement != null) request.withPlacement(placement);
            shown.requestShow(request, window, cx);
        });
    }

    /** Hides at once the tooltip of the window, whatever showed it. */
    public static function hideShown(window:Window, cx:App):Void {
        final overlay = WindowState.tooltipOverlay(window, cx);
        if (overlay != null) overlay.update(cx, (shown, cx) -> shown.hide(cx));
    }

/// Managed tooltip system

    /** How far the arrow of a tooltip reaches out of its popup, in pixels. */
    static inline final ARROW_DEPTH:Float = 5.;

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

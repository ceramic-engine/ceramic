// Ported from gpui-kit 0.8.1: crates/component/src/carousel/mod.rs, crates/component/src/carousel/carousel.rs
// (Carousel, carousel_control, focus_after_pointer_click, axis_value, set_axis_value, snap_offset)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.carousel;

import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.Axis;
import gpui.ClickEvent;
import gpui.Droppable;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.ParentElement;
import gpui.Point;
import gpui.RenderOnce;
import gpui.ScrollHandle;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Subscription;
import gpui.Window;
import gpui.base.Actions.SelectDown;
import gpui.base.Actions.SelectFirst;
import gpui.base.Actions.SelectLast;
import gpui.base.Actions.SelectLeft;
import gpui.base.Actions.SelectRight;
import gpui.base.Actions.SelectUp;
import gpui.base.ComponentTraits.FocusableExt;
import gpui.component.I18n;
import gpui.component.IconName;
import gpui.component.Size;
import gpui.component.button.Button;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.ClickEvent.ClickEventTools;
using gpui.base.StyledExt;
using gpui.component.ThemeStyled;

/**
 * A composable carousel root.
 *
 * Add one `CarouselContent` and any optional controls as children. Every
 * part must share the same `CarouselState`.
 *
 * The GPUI port has no accessibility tree: the region role and its label
 * (`accessibilityLabel`) are kept but not exported.
 */
class Carousel implements RenderOnce implements Styled implements ParentElement implements FocusableExt {

    @:allow(gpui.component.carousel)
    static inline final CONTEXT:String = 'Carousel';

    /** Rust `carousel::init`: the navigation keys of the `Carousel` context. */
    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding('left', new SelectLeft(), CONTEXT),
            new KeyBinding('right', new SelectRight(), CONTEXT),
            new KeyBinding('up', new SelectUp(), CONTEXT),
            new KeyBinding('down', new SelectDown(), CONTEXT),
            new KeyBinding('home', new SelectFirst(), CONTEXT),
            new KeyBinding('end', new SelectLast(), CONTEXT),
        ]);
    }

    final id:ElementId;

    final state:Entity<CarouselState>;

    final carouselStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var accessibilityLabelValue:String;

    var focusRingEnabled:Bool = true;

    final childElements:Array<AnyElement> = [];

    /** Creates a Carousel bound to `state`. */
    public function new(id:ElementIdArg, state:Entity<CarouselState>) {
        this.id = id;
        this.state = state;
        accessibilityLabelValue = I18n.t('Carousel.label');
    }

    /** Sets the name announced for the carousel region. */
    public function accessibilityLabel(label:String):Carousel {
        accessibilityLabelValue = label;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Carousel {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Carousel {
        for (child in children) childElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return carouselStyle;
    }

    public function focusRing(enabled:Bool):Carousel {
        focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRingEnabled;
    }

    public function render(window:Window, cx:App):IntoElement {
        final observedState = state;
        final currentView = window.currentView();
        window.useKeyedState(ElementId.NamedInteger('carousel-state-observer', state.entityId()), cx,
            _ -> new CarouselSubscription(cx.observe(observedState, (_, cx) -> cx.notify(currentView))));
        final snapshot = state.read(cx);
        final axis = snapshot.axis();
        final frameSize = snapshot.frameSize();
        final focusHandle = snapshot.focusHandle(cx);
        final ringSuppressed = snapshot.isFocusRingSuppressed();
        final focusOutState = state;
        window.useKeyedState(ElementId.NamedInteger('carousel-focus-out', state.entityId()), cx,
            window -> new CarouselSubscription(window.onFocusOut(focusHandle, cx, (_, _, cx) -> {
                focusOutState.update(cx, (state, _) -> state.suppressFocusRing(false));
            })));
        final isFocused = focusHandle.isFocused(window);
        final focusVisible = isFocused && !ringSuppressed && focusRingEnabled;
        final state = this.state;

        inline function listenerFor<A>(f:(CarouselState, A, Window, gpui.Context<CarouselState>) -> Void):(A, Window, App) -> Void {
            return (action, window, cx) -> state.update(cx, (s, cx) -> f(s, action, window, cx));
        }

        final root = div()
            .id(id)
            .relative()
            .flex()
            .flexCol()
            .gap4()
            .trackFocus(focusHandle.tabStop(true))
            .keyContext(CONTEXT)
            .onMouseDown(Left, (_, window, cx) -> {
                // Runs before GPUI moves focus here. A child such as
                // Button that keeps focus has already prevented the default.
                if (!isFocused && !window.defaultPrevented()) {
                    state.update(cx, (state, _) -> state.suppressFocusRing(true));
                }
            })
            .onAction(SelectLeft, listenerFor((state, _, _, cx) -> {
                final handled = axis == Horizontal && state.selectPrevious(cx);
                if (!handled) {
                    cx.propagate();
                }
            }))
            .onAction(SelectRight, listenerFor((state, _, _, cx) -> {
                final handled = axis == Horizontal && state.selectNext(cx);
                if (!handled) {
                    cx.propagate();
                }
            }))
            .onAction(SelectUp, listenerFor((state, _, _, cx) -> {
                final handled = axis == Vertical && state.selectPrevious(cx);
                if (!handled) {
                    cx.propagate();
                }
            }))
            .onAction(SelectDown, listenerFor((state, _, _, cx) -> {
                final handled = axis == Vertical && state.selectNext(cx);
                if (!handled) {
                    cx.propagate();
                }
            }))
            .onAction(SelectFirst, listenerFor((state, _, _, cx) -> {
                if (!state.selectFirst(cx)) {
                    cx.propagate();
                }
            }))
            .onAction(SelectLast, listenerFor((state, _, _, cx) -> {
                if (!state.selectLast(cx)) {
                    cx.propagate();
                }
            }));
        root.extend(childElements);
        if (focusVisible && frameSize != null) {
            final theme = Theme.global(cx);
            root.child(div()
                .absolute()
                .top0()
                .left0()
                .w(gpui.Prelude.px(frameSize.width))
                .h(gpui.Prelude.px(frameSize.height))
                .border1()
                .borderColor(theme.transparent)
                .rounded(theme.radius)
                .focusRingStyle(window, cx));
        }
        return root.refineStyle(carouselStyle);
    }

    /**
     * Rust `carousel_control`: the previous or next button, absolutely
     * positioned around the content frame.
     */
    @:allow(gpui.component.carousel)
    static function carouselControl(state:Entity<CarouselState>, size:Size, style:StyleRefinement, accessibilityLabel:Null<String>,
            children:Array<AnyElement>, next:Bool, cx:App):IntoElement {
        final snapshot = state.read(cx);
        final axis = snapshot.axis();
        final frameSize = snapshot.frameSize();
        final focusHandle = snapshot.focusHandle(cx);
        final disabled = next ? !snapshot.hasNext() : !snapshot.hasPrevious();
        final name = next ? 'next' : 'previous';
        final defaultLabel = next ? I18n.t('Carousel.next') : I18n.t('Carousel.previous');
        final icon = switch [axis, next] {
            case [Horizontal, false]: IconName.ChevronLeft;
            case [Horizontal, true]: IconName.ChevronRight;
            case [Vertical, false]: IconName.ChevronUp;
            case [Vertical, true]: IconName.ChevronDown;
        };
        final label = accessibilityLabel != null ? accessibilityLabel : defaultLabel;
        final hasCustomContent = children.length > 0;
        final id = ElementId.NamedChild(ElementId.NamedInteger('carousel-control', state.entityId()), name);

        final wrapper = div()
            .absolute()
            .top0()
            .left0();
        if (frameSize != null) wrapper.w(gpui.Prelude.px(frameSize.width)).h(gpui.Prelude.px(frameSize.height));
        if (frameSize == null) wrapper.right0().bottom0();

        final button = new Button(id)
            .outline()
            .withSize(size);
        if (!hasCustomContent) button.icon(icon);
        button.accessibilityLabel(label)
            .tooltip(label)
            .disabled(disabled)
            .absolute()
            .roundedFullStyle(cx);
        if (axis == Horizontal && !next) button.rightFull().mr4().top0().bottom0().myAuto();
        if (axis == Horizontal && next) button.leftFull().ml4().top0().bottom0().myAuto();
        if (axis == Vertical && !next) button.bottomFull().mb4().left0().right0().mxAuto();
        if (axis == Vertical && next) button.topFull().mt4().left0().right0().mxAuto();
        if (!disabled) {
            button.onClick((event, window, cx) -> {
                state.update(cx, (state, cx) -> {
                    if (next) {
                        state.selectNext(cx);
                    }
                    else {
                        state.selectPrevious(cx);
                    }
                });
                focusAfterPointerClick(state, focusHandle, event, window, cx);
            });
        }
        button.extend(children);
        button.refineStyle(style);
        return wrapper.child(button);
    }

    /**
     * Moves keyboard focus to the carousel after a pointer click on one of its
     * controls, so the arrow keys keep working without drawing the ring. A
     * keyboard activation leaves focus on the control.
     */
    @:allow(gpui.component.carousel)
    static function focusAfterPointerClick(state:Entity<CarouselState>, focusHandle:FocusHandle, event:ClickEvent, window:Window, cx:App):Void {
        if (event.isKeyboard() || focusHandle.containsFocused(window, cx)) {
            return;
        }
        state.update(cx, (state, _) -> state.suppressFocusRing(true));
        window.focus(focusHandle, cx);
    }

    @:allow(gpui.component.carousel)
    static inline function axisValue(point:Point, axis:Axis):Float {
        return axis == Horizontal ? point.x : point.y;
    }

    /** Rust `set_axis_value` on a copy (points are immutable here). */
    @:allow(gpui.component.carousel)
    @:allow(tests)
    static function setAxisValue(point:Point, axis:Axis, value:Float):Point {
        return axis == Horizontal ? new Point(value, point.y) : new Point(point.x, value);
    }

    @:allow(gpui.component.carousel)
    static function snapOffset(handle:ScrollHandle, axis:Axis, index:Int):Null<Float> {
        final viewport = handle.bounds();
        final item = handle.boundsForItem(index);
        if (item == null) {
            return null;
        }
        final target = gpui.SpringMath.f32(axis == Horizontal ? viewport.left() - item.left() : viewport.top() - item.top());
        final max = Math.max(axisValue(handle.maxOffset(), axis), 0.);
        return gpui.util.MathUtil.clamp(target, -max, 0.);
    }

}

/**
 * Keeps a subscription alive while its keyed state lives (Rust
 * `CarouselStateObserver` and `CarouselFocusOut`): dropping the state drops
 * the subscription.
 */
@:allow(gpui.component.carousel)
private class CarouselSubscription implements Droppable {

    final subscription:Subscription;

    function new(subscription:Subscription) {
        this.subscription = subscription;
    }

    public function drop():Void {
        subscription.dispose();
    }

}

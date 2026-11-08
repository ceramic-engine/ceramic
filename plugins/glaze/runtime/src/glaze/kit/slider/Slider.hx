// Ported from gpui-kit 0.8.1: crates/component/src/slider.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.slider;

import glaze.AbsoluteLength;
import glaze.App;
import glaze.kit.base.Slider.IntoSliderValue;
import glaze.kit.base.Slider.SliderValue;
import glaze.kit.base.Slider.SliderEvent;
import glaze.kit.KeyedEntity;
import glaze.ElementIdArg;
import glaze.Context;
import glaze.Axis;
import glaze.Background;
import glaze.Component;
import glaze.Corners;
import glaze.DefiniteLength;
import glaze.ElementId;
import glaze.Entity;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Slider.SliderIndicator;
import glaze.kit.base.Slider.SliderState;
import glaze.kit.base.Slider.SliderThumb;
import glaze.kit.base.Slider.SliderTrack;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.AbsoluteLengthTools;
using glaze.kit.base.Slider.SliderValueTools;
using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * Pointer state of one thumb, written by its own listeners and read on the
 * next frame to size the ring (observable: no `notify` needed).
 */
private class ThumbInteraction extends Model {

    @observe public var hovered:Bool = false;

    @observe public var pressed:Bool = false;

    public function new() {
        super();
    }

    /**
     * The ring shows while the pointer is over the thumb, and stays while the
     * thumb is dragged: dragging moves the thumb under the pointer, so hover
     * alone drops out for a frame on every move and the ring would flicker.
     */
    public function isActive():Bool {
        return hovered || pressed;
    }

}

/**
 * The animated hover ring of one thumb.
 */
private class ThumbRing {

    /** Width of the translucent ring that grows outside a hovered thumb. */
    static inline final THUMB_RING_WIDTH:Float = 3.;

    /** Opacity of the fully grown thumb ring. */
    static inline final THUMB_RING_OPACITY:Float = 0.5;

    public final interaction:ThumbInteraction;

    public final width:Pixels;

    public final color:Hsla;

    /**
     * Samples the ring for the `start` or end thumb of the slider `id`.
     */
    public function new(id:Int, start:Bool, color:Hsla, window:Window, cx:App) {
        final channel = start ? 'start' : 'end';
        interaction = window.useKeyedState(ElementId.NamedChild(ElementId.NamedInteger('slider-thumb-ring', id), channel), cx, _ -> new ThumbInteraction()).read(cx).value;
        final progress = Motion.spring(TransitionId.named(ElementId.NamedInteger('slider-thumb-ring', id), channel), interaction.isActive() ? 1. : 0., Theme.global(cx).motionTokens().springControl, window, cx);
        this.width = f32(THUMB_RING_WIDTH * progress);
        this.color = color.alpha(f32(THUMB_RING_OPACITY * progress));
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}

/**
 * A Slider element.
 *
 * `SliderState`, `SliderValue`, `SliderEvent` and `SliderScale` are the Base
 * ones (`glaze.kit.base.Slider`).
 */
class Slider extends Component implements Styled {

    /**
     * The `SliderState` rendered: the one given to `component(state)` or
     * `Slider.component(state)`, or the one created by `component()` once the
     * slider was rendered (`null` before).
     */
    public var state(default, null):Null<Entity<SliderState>>;

    var axis:Axis = Axis.Horizontal;

    /**
     * The position of the `component()` call, the identity of the state
     * it creates when none is given (`null` when the state was given).
     */
    var keyedPos:Null<haxe.PosInfos> = null;

    /** `.at(key)`: the identity of the created state instead of the call position. */
    var keyedId:Null<ElementId> = null;

    var valueToPush:Null<SliderValue> = null;

    /** The minimum of the state created by `component()` (default 0). */
    @prop var min:Null<Float> = null;

    var maxValue:Null<Float> = null;

    var stepValue:Null<Float> = null;

    /**
     * Called with the value on each `SliderEvent.Change` of the state
     * created by `component()`: the value of a single value slider (the
     * start of a range). The handler of the latest render is the one
     * called; replacing it invalidates nothing.
     */
    @prop var onChange:Null<(Float) -> Void> = null;

    final sliderStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set the disabled state of the slider, default: false
     */
    @prop var disabled:Bool = false;

    /**
     * Sets the label exposed to accessibility clients.
     */
    @prop var accessibilityLabel:Null<String> = null;

    var reverseValue:Bool = false;

    /**
     * Create a new `Slider` element bound to the `SliderState`.
     */
    public function new(state:Entity<SliderState>) {
        super();
        this.state = state;
    }

    /**
     * Places a slider in a tree. With `state`, it is `Slider.component(state)`.
     * Without, the slider creates its `SliderState` the first time it is
     * rendered and keeps it as long as it is rendered, under the identity
     * of this call (its position in the code, or `.at(key)` in a loop); the
     * state is destroyed when the slider leaves the tree. `.min()`, `.max()`,
     * `.step()` and `.value(v)` are applied to the state when they differ
     * from its current ones, `.onChange(f)` is called with the value while
     * the user moves the slider (the latest `f` is kept, without
     * invalidation), and `.state` gives the entity once rendered.
     */
    public static function component(?state:Entity<SliderState>, ?pos:haxe.PosInfos):Slider {
        if (state != null) return new Slider(state);
        final slider = new Slider(null);
        slider.keyedPos = pos;
        return slider;
    }

    /**
     * The identity of the state created by `component()` without a state,
     * instead of the position of the call: needed when the call runs more
     * than once per render (a loop).
     */
    public function at(key:ElementIdArg):Slider {
        keyedId = key;
        return this;
    }

    /** The maximum of the state created by `component()` (default 100). */
    public function max(max:Float):Slider {
        maxValue = max;
        return this;
    }

    /** The step of the state created by `component()` (default 1). */
    public function step(step:Float):Slider {
        stepValue = step;
        return this;
    }

    /**
     * Pushes `value` into the state created by `component()` when it
     * differs from the state's value (a drag in progress is kept otherwise).
     */
    public function value(value:IntoSliderValue):Slider {
        valueToPush = value;
        return this;
    }

    /**
     * Creates or finds the state of a slider built by `component()` without
     * one, under the identity of the call, applies the range and the value
     * and installs the change handler (`KeyedEntity`).
     */
    function resolveKeyedState(window:Window, cx:App):Void {
        final key:ElementIdArg = keyedId != null ? keyedId : ElementId.CodeLocation(keyedPos.fileName, keyedPos.lineNumber);
        final keyed:KeyedEntity<SliderState, (Float) -> Void> = window.useKeyedState(key, cx, _ -> new KeyedEntity(cx.newEntity((_:Context<SliderState>) -> new SliderState()))).read(cx).value;
        final entity = keyed.entity;
        state = entity;
        keyed.handler = onChange;
        if (onChange != null) {
            keyed.subscribe(cx, SliderEvent, (entity, event, cx) -> {
                switch event {
                    case Change(value):
                        if (keyed.handler != null) keyed.handler(value.start());
                    case Release(_):
                }
            });
        }
        // Not tracked by the view being rendered (see `Select.resolveKeyedState`)
        tracker.Autorun.unobserve();
        final current = entity.read(cx);
        final minChanged = this.min != null && current.minValue() != this.min;
        final maxChanged = maxValue != null && current.maxValue() != maxValue;
        final stepChanged = stepValue != null && current.stepValue() != stepValue;
        final valueChanged = valueToPush != null && !Type.enumEq(current.value(), valueToPush);
        if (minChanged || maxChanged || stepChanged || valueChanged) {
            final min = this.min, max = maxValue, step = stepValue, value = valueToPush;
            entity.update(cx, (s, c) -> {
                if (minChanged) s.min(min);
                if (maxChanged) s.max(max);
                if (stepChanged) s.step(step);
                if (valueChanged) s.setValue(value, window, c);
            });
        }
        tracker.Autorun.reobserve();
    }

    public inline function style():StyleRefinement {
        return sliderStyle;
    }

    /**
     * As a horizontal slider.
     */
    public function horizontal():Slider {
        axis = Axis.Horizontal;
        return this;
    }

    /**
     * As a vertical slider.
     */
    public function vertical():Slider {
        axis = Axis.Vertical;
        return this;
    }

    /**
     * Reverse the filled (highlighted) side of the track, default: false.
     *
     * By default the track is filled from the min end to the thumb. With
     * `reverse`, the fill goes from the thumb to the max end instead, useful
     * when the slider represents a remaining amount (e.g. time left).
     *
     * This only changes the visual fill; values, events and interactions are
     * unaffected. It applies to single-value sliders and is ignored for range
     * sliders.
     */
    public function reverse():Slider {
        reverseValue = true;
        return this;
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    public function render(window:Window, cx:App):IntoElement {
        if (state == null) resolveKeyedState(window, cx);
        final theme = Theme.global(cx);
        final axis = this.axis;
        final current = state.read(cx);
        final isRange = current.value().isRange();
        final percentage = current.percentage();
        final barStart:DefiniteLength = reverseValue && !isRange ? glaze.Prelude.relative(percentage.end) : glaze.Prelude.relative(percentage.start);
        final barEnd:DefiniteLength = reverseValue && !isRange ? glaze.Prelude.relative(0.) : glaze.Prelude.relative(f32(1. - percentage.end));
        final remSize = window.remSize();

        final styleBg = sliderStyle.background != null ? sliderStyle.background.asSolid() : null;
        final barColor:Hsla = styleBg != null ? styleBg : theme.tokens.sliderBar.color;
        final textColor = sliderStyle.text != null ? sliderStyle.text.color : null;
        final thumbBg:Background = textColor != null ? Background.fromHsla(textColor) : theme.tokens.sliderThumb.background;
        // The track is a pill by default, and square when the theme squares its
        // corners. A caller's own corner radii still win.
        final defaultRadius = theme.radiusFull();
        inline function corner(value:Null<AbsoluteLength>):Pixels {
            return value != null ? value.toPixels(remSize) : defaultRadius;
        }
        final radius = new Corners(corner(sliderStyle.cornerRadiusTopLeft), corner(sliderStyle.cornerRadiusTopRight), corner(sliderStyle.cornerRadiusBottomRight), corner(sliderStyle.cornerRadiusBottomLeft));

        final ringColor = theme.ring;
        final entityId = state.entityId();
        final startRing = isRange ? new ThumbRing(entityId, true, ringColor, window, cx) : null;
        final endRing = new ThumbRing(entityId, false, ringColor, window, cx);

        final disabled = this.disabled;
        function thumb(position:DefiniteLength, start:Bool, ring:ThumbRing):SliderThumb {
            final thumb = SliderThumb.component(state).axis(axis).start(start).disabled(disabled);
            if (!disabled) {
                thumb.absolute();
                if (axis == Axis.Horizontal) thumb.top(glaze.Prelude.px(-5.)).left(position).ml(glaze.Prelude.px(-8.));
                if (axis == Axis.Vertical) thumb.bottom(position).left(glaze.Prelude.px(-5.)).mb(glaze.Prelude.px(-8.));
                thumb.flex().itemsCenter().justifyCenter().flexShrink0().roundedFullStyle(cx).bg(barColor.opacity(0.5)).size4().p(glaze.Prelude.px(1.));
                final interaction = ring.interaction;
                thumb.base
                    .onHover((entered, _, _) -> {
                        if (interaction.hovered != entered) interaction.hovered = entered;
                    })
                    // The base thumb stops propagation on mouse down to own
                    // the drag, so the press is read in the capture phase.
                    .captureAnyMouseDown((_, _, _) -> {
                        if (!interaction.pressed) interaction.pressed = true;
                    })
                    .captureAnyMouseUp((_, _, _) -> {
                        if (interaction.pressed) interaction.pressed = false;
                    })
                    .onMouseUpOut(Left, (_, _, _) -> {
                        if (interaction.pressed) interaction.pressed = false;
                    });
                // The ring grows outward from the thumb's edge: inset by its
                // own width so its inner edge sits flush against it.
                thumb.child(div()
                    .flexNone()
                    .absolute()
                    .top(glaze.Prelude.px(-ring.width))
                    .left(glaze.Prelude.px(-ring.width))
                    .right(glaze.Prelude.px(-ring.width))
                    .bottom(glaze.Prelude.px(-ring.width))
                    .roundedFullStyle(cx)
                    .border(ring.width)
                    .borderColor(ring.color));
                thumb.child(div().flexShrink0().sizeFull().roundedFullStyle(cx).bg(thumbBg));
            }
            return thumb;
        }

        final root = glaze.kit.base.Slider.component(state).axis(axis).disabled(disabled);
        if (accessibilityLabel != null) root.accessibilityLabel(accessibilityLabel);
        root.flex().flex1().itemsCenter().justifyCenter();
        if (axis == Axis.Vertical) root.h(glaze.Prelude.px(120.));
        if (axis == Axis.Horizontal) root.wFull();
        root.refineStyle(sliderStyle).bg(theme.transparent).textColor(theme.foreground);

        final track = SliderTrack.component(state).axis(axis).disabled(disabled).flex();
        if (axis == Axis.Horizontal) track.itemsCenter().h6().wFull();
        if (axis == Axis.Vertical) track.justifyCenter().w6().hFull();
        track.flexShrink0();

        final indicator = SliderIndicator.component(state).relative();
        if (axis == Axis.Horizontal) indicator.wFull().h1p5();
        if (axis == Axis.Vertical) indicator.hFull().w1p5();
        indicator.bg(barColor.opacity(0.2)).active(s -> s.bg(barColor.opacity(0.4))).cornerRadii(radius);
        final bar = div().absolute();
        if (axis == Axis.Horizontal) bar.hFull().left(barStart).right(barEnd);
        if (axis == Axis.Vertical) bar.wFull().bottom(barStart).top(barEnd);
        indicator.child(bar.bg(barColor).roundedFullStyle(cx));
        if (startRing != null) indicator.child(thumb(glaze.Prelude.relative(percentage.start), true, startRing));
        indicator.child(thumb(glaze.Prelude.relative(percentage.end), false, endRing));

        track.child(indicator);
        root.child(track);
        return root;
    }

}

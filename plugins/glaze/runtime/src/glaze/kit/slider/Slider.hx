// Ported from gpui-kit 0.8.1: crates/component/src/slider.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.slider;

import glaze.AbsoluteLength;
import glaze.App;
import glaze.Axis;
import glaze.Background;
import glaze.Corners;
import glaze.DefiniteLength;
import glaze.ElementId;
import glaze.Entity;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.RenderOnce;
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
class Slider implements RenderOnce implements Styled {

    final state:Entity<SliderState>;

    var axis:Axis = Axis.Horizontal;

    final sliderStyle:StyleRefinement = new StyleRefinement();

    var disabledValue:Bool = false;

    var accessibilityLabelValue:Null<String> = null;

    var reverseValue:Bool = false;

    /**
     * Create a new `Slider` element bound to the `SliderState`.
     */
    public function new(state:Entity<SliderState>) {
        this.state = state;
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
     * Set the disabled state of the slider, default: false
     */
    public function disabled(disabled:Bool):Slider {
        disabledValue = disabled;
        return this;
    }

    /**
     * Sets the label exposed to accessibility clients.
     */
    public function accessibilityLabel(label:String):Slider {
        accessibilityLabelValue = label;
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

        final disabled = disabledValue;
        function thumb(position:DefiniteLength, start:Bool, ring:ThumbRing):SliderThumb {
            final thumb = new SliderThumb(state).axis(axis).start(start).disabled(disabled);
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

        final root = new glaze.kit.base.Slider(state).axis(axis).disabled(disabled);
        if (accessibilityLabelValue != null) root.accessibilityLabel(accessibilityLabelValue);
        root.flex().flex1().itemsCenter().justifyCenter();
        if (axis == Axis.Vertical) root.h(glaze.Prelude.px(120.));
        if (axis == Axis.Horizontal) root.wFull();
        root.refineStyle(sliderStyle).bg(theme.transparent).textColor(theme.foreground);

        final track = new SliderTrack(state).axis(axis).disabled(disabled).flex();
        if (axis == Axis.Horizontal) track.itemsCenter().h6().wFull();
        if (axis == Axis.Vertical) track.justifyCenter().w6().hFull();
        track.flexShrink0();

        final indicator = new SliderIndicator(state).relative();
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

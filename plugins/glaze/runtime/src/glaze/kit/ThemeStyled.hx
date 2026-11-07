// Ported from gpui-kit 0.8.1: crates/component/src/styled.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit;

import glaze.AbsoluteLength;
import glaze.App;
import glaze.BoxShadow;
import glaze.Corners;
import glaze.Edges;
import glaze.Hsla;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.AbsoluteLengthTools;
using glaze.kit.base.StyledExt;

/**
 * Where a borderless element draws its 1px focus line when
 * `Theme.focusRing` is off.
 */
enum FocusLine {
    /** On the element's edge, in the `ring` colour. */
    Edge;
    /**
     * Inset from the edge, in the given colour. For filled elements, where
     * the `ring` colour can land close to the fill.
     */
    Inside(color:Hsla);
    /** Just outside the edge, in the `ring` colour. */
    Outside;
}

/**
 * Finished styles that read the theme, as a static extension:
 * `using glaze.kit.ThemeStyled;` (Rust `ThemeStyled`), plus the shadow
 * recipes shared by popups, toasts and raised controls.
 *
 * Separate from `glaze.kit.base.StyledExt`, which holds neutral helpers that make
 * no visual decisions.
 */
class ThemeStyled {

    static inline final FOCUS_RING_WIDTH:Pixels = 3.;

    static inline final FOCUS_RING_OPACITY:Float = 0.5;

    /** Gap between a borderless element's edge and a focus line drawn off it, in rem. */
    static inline final FOCUS_LINE_GAP:Float = 0.125;

    /**
     * Ink every layer of a surface's shadow carries: the `rgb(0 0 0 / 0.1)`
     * shadcn/ui spends at each elevation.
     */
    static inline final SURFACE_SHADOW_INK:Float = 0.1;

    /** Ink of the hairline ring standing in for a popover's border. */
    static inline final POPOVER_RING_INK:Float = 0.1;

    /**
     * The colour of a popup surface's hairline ring in this theme (black in
     * light mode, white in dark: it follows the foreground).
     */
    public static function popoverRing(cx:App):Hsla {
        return Theme.global(cx).foreground.alpha(POPOVER_RING_INK);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    static function clamp01(value:Float):Float {
        return value < 0. ? 0. : (value > 1. ? 1. : value);
    }

    /**
     * shadcn/ui's popup surface shadow (a hairline `ring` plus `shadow-md`)
     * at `strength` of its full ink. The blurred layers use Tailwind's radii
     * halved: CSS defines the blur radius as twice the gaussian's standard
     * deviation, GPUI's shader takes the deviation itself.
     */
    public static function popoverShadow(ring:Hsla, strength:Float):Array<BoxShadow> {
        final strength = clamp01(strength);
        final ink = hsla(0., 0., 0., f32(SURFACE_SHADOW_INK * strength));
        return [
            new BoxShadow(0., 0., ring.alpha(f32(ring.a * strength))).withBlurRadius(0.).withSpreadRadius(1.),
            new BoxShadow(0., 4., ink).withBlurRadius(3.).withSpreadRadius(-1.),
            new BoxShadow(0., 2., ink).withBlurRadius(2.).withSpreadRadius(-2.)
        ];
    }

    /**
     * shadcn/ui's `shadow-lg`, the elevation it lifts a toast to, at
     * `strength` of its full ink (no ring layer: a toast has a real border).
     */
    public static function toastShadow(strength:Float):Array<BoxShadow> {
        final ink = hsla(0., 0., 0., f32(SURFACE_SHADOW_INK * clamp01(strength)));
        return [
            new BoxShadow(0., 10., ink).withBlurRadius(7.5).withSpreadRadius(-3.),
            new BoxShadow(0., 4., ink).withBlurRadius(3.).withSpreadRadius(-4.)
        ];
    }

    /**
     * shadcn/ui's `shadow-sm`, the elevation of a control raised out of the
     * container it sits in (the active pill of a segmented tab bar).
     */
    public static function raisedShadow():Array<BoxShadow> {
        final ink = hsla(0., 0., 0., SURFACE_SHADOW_INK);
        return [
            new BoxShadow(0., 1., ink).withBlurRadius(1.5),
            new BoxShadow(0., 1., ink).withBlurRadius(1.).withSpreadRadius(-1.)
        ];
    }

    /**
     * Give this element the focus appearance the framework's own controls
     * use: its border tinted with the focus colour, and the ring outside it.
     * See `focusStyle`.
     */
    public static function focusRingStyle<T:Styled & ParentElement>(self:T, window:Window, cx:App):T {
        return focusStyle(self, Edge, window, cx);
    }

    /**
     * Give this element the surface, edge, shadow and radius of a popover.
     */
    public static function popoverStyle<T:Styled>(self:T, cx:App):T {
        final theme = Theme.global(cx);
        new StyleBuilder(self.style())
            .bg(theme.popover)
            .textColor(theme.popoverForeground)
            .shadow(popoverShadow(popoverRing(cx), 1.))
            .rounded(theme.radius);
        return self;
    }

    /**
     * Round this element as far as its size allows (a circle if it is
     * square, a pill if it is not) unless the theme squares its corners.
     */
    public static function roundedFullStyle<T:Styled>(self:T, cx:App):T {
        new StyleBuilder(self.style()).rounded(Theme.global(cx).radiusFull());
        return self;
    }

    static function borderWidths(style:StyleRefinement, remSize:Pixels):Edges {
        inline function width(value:Null<AbsoluteLength>):Float {
            return value != null ? value.toPixels(remSize) : 0.;
        }
        return new Edges(width(style.borderWidthTop), width(style.borderWidthRight), width(style.borderWidthBottom), width(style.borderWidthLeft));
    }

    static function cornerRadii(style:StyleRefinement, remSize:Pixels):Corners {
        inline function radius(value:Null<AbsoluteLength>):Float {
            return value != null ? value.toPixels(remSize) : 0.;
        }
        return new Corners(radius(style.cornerRadiusTopLeft), radius(style.cornerRadiusTopRight), radius(style.cornerRadiusBottomRight), radius(style.cornerRadiusBottomLeft));
    }

    static function cornerRadiiRefinement(radius:Corners):StyleRefinement {
        final style = new StyleRefinement();
        style.cornerRadiusTopLeft = AbsoluteLength.Pixels(radius.topLeft);
        style.cornerRadiusTopRight = AbsoluteLength.Pixels(radius.topRight);
        style.cornerRadiusBottomLeft = AbsoluteLength.Pixels(radius.bottomLeft);
        style.cornerRadiusBottomRight = AbsoluteLength.Pixels(radius.bottomRight);
        return style;
    }

    /**
     * Style a focused element as `focusRingStyle` does, with `line` choosing
     * where a borderless element draws its focus line.
     */
    public static function focusStyle<T:Styled & ParentElement>(element:T, line:FocusLine, window:Window, cx:App):T {
        final theme = Theme.global(cx);
        if (theme.focusRing) {
            new StyleBuilder(element.style()).borderColor(theme.ring);
            return focusRing(element, window, theme.ring.alpha(FOCUS_RING_OPACITY));
        }

        // The ring is painted outside the border, so a clipping ancestor cuts it
        // off. An application whose layout clips heavily turns it off in the theme
        // and keeps the tinted border, which takes no space.
        final remSize = window.remSize();
        final widths = borderWidths(element.style(), remSize);
        if (widths.top > 0 || widths.right > 0 || widths.bottom > 0 || widths.left > 0) {
            new StyleBuilder(element.style()).borderColor(theme.ring);
            return element;
        }

        final gap:Float = f32(remSize * FOCUS_LINE_GAP);
        var color = theme.ring;
        var inset:Float = 0.;
        switch line {
            case Edge:
            case Inside(c):
                color = c;
                inset = gap;
            case Outside:
                inset = -gap;
        }
        // Shrinking or growing the box by `inset` keeps the line concentric with
        // the element's own corners.
        final corners = cornerRadii(element.style(), remSize);
        final radius = new Corners(Math.max(corners.topLeft - inset, 0.), Math.max(corners.topRight - inset, 0.), Math.max(corners.bottomRight - inset, 0.), Math.max(corners.bottomLeft - inset, 0.));
        element.extend([
            div()
                .flexNone()
                .absolute()
                .top(px(inset))
                .left(px(inset))
                .right(px(inset))
                .bottom(px(inset))
                .border1()
                .borderColor(color)
                .refineStyle(cornerRadiiRefinement(radius))
                .intoAnyElement()
        ]);
        return element;
    }

    /**
     * Paint only the outside band, preserving translucent control backgrounds.
     */
    public static function focusRing<T:Styled & ParentElement>(element:T, window:Window, color:Hsla):T {
        final remSize = window.remSize();
        final widths = borderWidths(element.style(), remSize);
        final corners = cornerRadii(element.style(), remSize);
        final radius = new Corners(corners.topLeft + FOCUS_RING_WIDTH, corners.topRight + FOCUS_RING_WIDTH, corners.bottomRight + FOCUS_RING_WIDTH, corners.bottomLeft + FOCUS_RING_WIDTH);
        final inset:Float = FOCUS_RING_WIDTH;
        element.extend([
            div()
                .flexNone()
                .absolute()
                .top(px(-(inset + widths.top)))
                .left(px(-(inset + widths.left)))
                .right(px(-(inset + widths.right)))
                .bottom(px(-(inset + widths.bottom)))
                .border(FOCUS_RING_WIDTH)
                .borderColor(color)
                .refineStyle(cornerRadiiRefinement(radius))
                .intoAnyElement()
        ]);
        return element;
    }

}

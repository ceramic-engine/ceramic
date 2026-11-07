// Ported from gpui-kit 0.8.1: crates/base/src/styled.rs (StyledExt, RoleOverride)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.Corners;
import glaze.Edges;
import glaze.FocusHandle;
import glaze.FontWeight;
import glaze.Hsla;
import glaze.IntoDefiniteLength;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;

/**
 * Neutral style helpers on any `Styled` element, as a static extension:
 * `using glaze.kit.base.StyledExt;` then `div().hFlex().fontMedium()`.
 *
 * Rust provides them as default methods of a trait implemented for every
 * `Styled`. Haxe extensions only see `style()`, so each helper edits the
 * element's `StyleRefinement` (through a `StyleBuilder` when a generated
 * `Styled` method is reused) and returns the element itself.
 *
 * The free functions `hFlex()`, `vFlex()` and `boxShadow()` are in
 * `glaze.kit.base.Prelude`.
 */
class StyledExt {

    /**
     * Refines this element's style with `style` (Rust `refine_style`).
     */
    public static function refineStyle<T:Styled>(self:T, style:StyleRefinement):T {
        self.style().refine(style);
        return self;
    }

    /**
     * Lays children out in a row, centered on the cross axis.
     *
     * The centering is the desktop default for a row of controls, but it is
     * **not** the mirror image of `vFlex`, which leaves the cross axis
     * stretching: a column placed in a row takes its content's height and is
     * centered inside the row. Give a full-height column `hFull()` (or the
     * row `itemsStart()` / `itemsStretch()`) when it has to resolve against
     * the row's height.
     */
    public static function hFlex<T:Styled>(self:T):T {
        final style = self.style();
        style.display = glaze.Display.Flex;
        style.flexDirection = glaze.FlexDirection.Row;
        style.alignItems = glaze.AlignItems.Center;
        return self;
    }

    /**
     * Lays children out in a column, stretching them across the cross axis.
     *
     * Unlike `hFlex` this installs no cross-axis alignment, so a child
     * without a width fills the column.
     */
    public static function vFlex<T:Styled>(self:T):T {
        final style = self.style();
        style.display = glaze.Display.Flex;
        style.flexDirection = glaze.FlexDirection.Column;
        return self;
    }

    /**
     * Sets the four paddings (Rust `paddings(impl Into<Edges<L>>)`).
     */
    public static function paddings<T:Styled>(self:T, top:IntoDefiniteLength, right:IntoDefiniteLength, bottom:IntoDefiniteLength, left:IntoDefiniteLength):T {
        new StyleBuilder(self.style()).pt(top).pb(bottom).pl(left).pr(right);
        return self;
    }

    /**
     * Sets the four paddings from pixel edges.
     */
    public static function paddingsEdges<T:Styled>(self:T, edges:Edges):T {
        new StyleBuilder(self.style()).pt(glaze.Prelude.px(edges.top)).pb(glaze.Prelude.px(edges.bottom)).pl(glaze.Prelude.px(edges.left)).pr(glaze.Prelude.px(edges.right));
        return self;
    }

    /**
     * Sets the four margins (Rust `margins(impl Into<Edges<L>>)`).
     */
    public static function margins<T:Styled>(self:T, top:glaze.IntoLength, right:glaze.IntoLength, bottom:glaze.IntoLength, left:glaze.IntoLength):T {
        new StyleBuilder(self.style()).mt(top).mb(bottom).ml(left).mr(right);
        return self;
    }

    static function debugBorder<T:Styled>(self:T, color:Hsla):T {
        #if debug
        new StyleBuilder(self.style()).border1().borderColor(color);
        #end
        return self;
    }

    public static function debugRed<T:Styled>(self:T):T {
        return debugBorder(self, hsl(0., 72.2, 50.6));
    }

    public static function debugBlue<T:Styled>(self:T):T {
        return debugBorder(self, hsl(217.2, 91.2, 59.8));
    }

    public static function debugYellow<T:Styled>(self:T):T {
        return debugBorder(self, hsl(47.9, 95.8, 53.1));
    }

    public static function debugGreen<T:Styled>(self:T):T {
        return debugBorder(self, hsl(142.1, 70.6, 45.3));
    }

    public static function debugPink<T:Styled>(self:T):T {
        return debugBorder(self, hsl(330.4, 81.2, 60.4));
    }

    public static function debugFocused<T:Styled>(self:T, focusHandle:FocusHandle, window:Window, cx:App):T {
        #if debug
        if (focusHandle.containsFocused(window, cx)) {
            return debugBlue(self);
        }
        #end
        return self;
    }

    static inline function weight<T:Styled>(self:T, weight:FontWeight):T {
        self.style().textStyle().fontWeight = weight;
        return self;
    }

    public static function fontThin<T:Styled>(self:T):T return weight(self, FontWeight.THIN);

    public static function fontExtralight<T:Styled>(self:T):T return weight(self, FontWeight.EXTRA_LIGHT);

    public static function fontLight<T:Styled>(self:T):T return weight(self, FontWeight.LIGHT);

    public static function fontNormal<T:Styled>(self:T):T return weight(self, FontWeight.NORMAL);

    public static function fontMedium<T:Styled>(self:T):T return weight(self, FontWeight.MEDIUM);

    public static function fontSemibold<T:Styled>(self:T):T return weight(self, FontWeight.SEMIBOLD);

    public static function fontBold<T:Styled>(self:T):T return weight(self, FontWeight.BOLD);

    public static function fontExtrabold<T:Styled>(self:T):T return weight(self, FontWeight.EXTRA_BOLD);

    public static function fontBlack<T:Styled>(self:T):T return weight(self, FontWeight.BLACK);

    /**
     * Sets the four corner radii.
     */
    public static function cornerRadii<T:Styled>(self:T, radius:Corners):T {
        new StyleBuilder(self.style())
            .roundedTl(glaze.Prelude.px(radius.topLeft))
            .roundedTr(glaze.Prelude.px(radius.topRight))
            .roundedBl(glaze.Prelude.px(radius.bottomLeft))
            .roundedBr(glaze.Prelude.px(radius.bottomRight));
        return self;
    }

    static function hsl(hue:Float, saturation:Float, lightness:Float):Hsla {
        return glaze.Prelude.hsla(hue / 360., saturation / 100., lightness / 100., 1.);
    }

}

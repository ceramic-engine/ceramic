package tests;

import gpui.AbsoluteLength;
import gpui.AlignContent;
import gpui.AlignItems;
import gpui.CursorStyle;
import gpui.DefiniteLength;
import gpui.Display;
import gpui.Div;
import gpui.FlexDirection;
import gpui.FontWeight;
import gpui.GridPlacement;
import gpui.Length;
import gpui.Overflow;
import gpui.Position;
import gpui.Style;
import gpui.StyleRefinement;
import gpui.StyledMacro;
import gpui.TextOverflow;
import gpui.Visibility;
import gpui.WhiteSpace;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * Tests for `Style`, `StyleRefinement` (refineable behaviour) and the
 * `Styled` methods generated from the `gpui_macros` tables.
 */
class StyleTest extends TestCase {

    static function rem(value:Float):Length {
        return Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Rems(value)));
    }

    static function pixels(value:Float):Length {
        return Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(value)));
    }

    static function fraction(value:Float):Length {
        return Length.Definite(DefiniteLength.Fraction(value));
    }

    function assertLength(expected:Length, actual:Length, ?pos:haxe.PosInfos) {
        assertTrue(actual != null && expected.equals(actual), 'expected $expected but got $actual', pos);
    }

    function testDefaultStyle() {
        final style = new Style();
        assertEquals(Display.Block, style.display);
        assertEquals(Visibility.Visible, style.visibility);
        assertEquals(Overflow.Visible, style.overflowX);
        assertEquals(Position.Relative, style.position);
        assertEquals(FlexDirection.Row, style.flexDirection);
        assertEquals(0.0, style.flexGrow);
        assertEquals(1.0, style.flexShrink);
        assertLength(Length.Auto, style.sizeWidth);
        assertLength(Length.Auto, style.insetTop);
        assertLength(pixels(0), style.marginLeft);
        assertFalse(style.isSome(StyleRefinement.ALIGN_ITEMS));
        assertFalse(style.isSome(StyleRefinement.OPACITY));
        assertNull(style.background);
        assertNull(style.textStyle());
        assertEquals(0, style.boxShadow.length);
    }

    /**
     * Port of GPUI's `test_text_style_refinement` (style.rs).
     */
    function testTextStyleRefinement() {
        final style = new Style();
        style.refine(div().textSize(px(20.0)).style());
        style.refine(div().fontWeight(FontWeight.SEMIBOLD).style());

        assertTrue(style.textStyle().fontSize.equals(AbsoluteLength.Pixels(20.0)));
        assertEquals(FontWeight.SEMIBOLD, style.textStyle().fontWeight);
        assertTrue(style.textStyle().has(gpui.TextStyleRefinement.FONT_WEIGHT));
    }

    function testRefineOnlyAppliesSetFields() {
        final style = new Style();
        style.refine(div().flex().gap2().style());
        style.refine(div().flexCol().style());
        assertEquals(Display.Flex, style.display);
        assertEquals(FlexDirection.Column, style.flexDirection);
        assertTrue(style.gapWidth.equals(DefiniteLength.Absolute(AbsoluteLength.Rems(0.5))));

        // A later refinement overrides, an unset field keeps its value
        style.refine(div().block().itemsCenter().style());
        assertEquals(Display.Block, style.display);
        assertEquals(FlexDirection.Column, style.flexDirection);
        assertTrue(style.isSome(StyleRefinement.ALIGN_ITEMS));
        assertEquals(AlignItems.Center, style.alignItems);

        // Refinements merge into refinements (Cascade::merged)
        final merged = new StyleRefinement();
        merged.refine(div().p2().opacity(0.5).style());
        merged.refine(div().pt4().style());
        assertTrue(merged.paddingTop.equals(DefiniteLength.Absolute(AbsoluteLength.Rems(1.0))));
        assertTrue(merged.paddingLeft.equals(DefiniteLength.Absolute(AbsoluteLength.Rems(0.5))));
        assertTrue(merged.has(StyleRefinement.OPACITY));
        assertEquals(0.5, merged.opacity);
        assertFalse(merged.has(StyleRefinement.DISPLAY));
    }

    function testContentNormalUnsetsAlignContent() {
        final d = div().contentCenter();
        assertTrue(d.style().has(StyleRefinement.ALIGN_CONTENT));
        d.contentNormal();
        assertFalse(d.style().has(StyleRefinement.ALIGN_CONTENT));
    }

    /**
     * Spot checks against the tables of gpui_macros (styles.rs).
     */
    function testSpacingScale() {
        final s = div().gap2().style();
        assertTrue(s.gapWidth.equals(DefiniteLength.Absolute(AbsoluteLength.Rems(0.5))));
        assertTrue(s.gapHeight.equals(DefiniteLength.Absolute(AbsoluteLength.Rems(0.5))));

        final p = div().px0p5().style();
        assertTrue(p.paddingLeft.equals(DefiniteLength.Absolute(AbsoluteLength.Rems(0.125))));
        assertTrue(p.paddingRight.equals(DefiniteLength.Absolute(AbsoluteLength.Rems(0.125))));
        assertNull(p.paddingTop);

        assertLength(fraction(1.0), div().wFull().style().sizeWidth);
        assertLength(fraction(0.5), div().h1_2().style().sizeHeight);
        assertLength(fraction(1.0 / 3.0), div().size1_3().style().sizeWidth);
        assertLength(fraction(1.0 / 12.0), div().minW1_12().style().minSizeWidth);
        assertLength(pixels(1.0), div().wPx().style().sizeWidth);
        assertLength(rem(32.0), div().maxH128().style().maxSizeHeight);
        assertLength(Length.Auto, div().mxAuto().style().marginLeft);
        assertLength(rem(-0.5), div().mNeg2().style().marginBottom);
        assertLength(rem(-0.375), div().topNeg1p5().style().insetTop);
        assertLength(fraction(-0.5), div().leftNeg1_2().style().insetLeft);
        assertLength(pixels(0.0), div().inset0().style().insetRight);
        assertLength(rem(6.0), div().size24().style().sizeHeight);
        assertTrue(div().gapXNeg1().style().gapWidth.equals(DefiniteLength.Absolute(AbsoluteLength.Rems(-0.25))));
        assertNull(div().gapX1().style().gapHeight);
    }

    function testCustomLengthSetters() {
        assertLength(pixels(10), div().w(px(10)).style().sizeWidth);
        assertLength(rem(2), div().h(rems(2)).style().sizeHeight);
        assertLength(fraction(0.25), div().w(relative(0.25)).style().sizeWidth);
        assertTrue(div().p(px(3)).style().paddingBottom.equals(DefiniteLength.Absolute(AbsoluteLength.Pixels(3))));
        assertTrue(div().rounded(rems(1.5)).style().cornerRadiusBottomLeft.equals(AbsoluteLength.Rems(1.5)));
        assertTrue(div().borderX(px(2)).style().borderWidthRight.equals(AbsoluteLength.Pixels(2)));
        assertNull(div().borderX(px(2)).style().borderWidthTop);
    }

    function testCornersAndBorders() {
        final r = div().roundedMd().style();
        assertTrue(r.cornerRadiusTopLeft.equals(AbsoluteLength.Rems(0.375)));
        assertTrue(r.cornerRadiusBottomRight.equals(AbsoluteLength.Rems(0.375)));
        assertTrue(div().roundedFull().style().cornerRadiusTopRight.equals(AbsoluteLength.Pixels(9999)));
        assertTrue(div().roundedTl2xl().style().cornerRadiusTopLeft.equals(AbsoluteLength.Rems(1.0)));
        assertNull(div().roundedTl2xl().style().cornerRadiusTopRight);
        final b = div().roundedB3xl().style();
        assertTrue(b.cornerRadiusBottomLeft.equals(AbsoluteLength.Rems(1.5)));
        assertNull(b.cornerRadiusTopLeft);

        final border = div().border4().style();
        assertTrue(border.borderWidthTop.equals(AbsoluteLength.Pixels(4)));
        assertTrue(border.borderWidthLeft.equals(AbsoluteLength.Pixels(4)));
        assertTrue(div().borderY32().style().borderWidthBottom.equals(AbsoluteLength.Pixels(32)));
        assertNull(div().borderY32().style().borderWidthLeft);
    }

    function testShadowPresets() {
        final sm = div().shadowSm().style().boxShadow;
        assertEquals(2, sm.length);
        assertEquals(1.0, (sm[0].offset.y : Float));
        assertEquals(3.0, (sm[0].blurRadius : Float));
        assertEquals(-1.0, (sm[1].spreadRadius : Float));
        assertFloatEquals(0.1, sm[1].color.a);

        final xl2 = div().shadow2xl().style().boxShadow;
        assertEquals(1, xl2.length);
        assertEquals(25.0, (xl2[0].offset.y : Float));
        assertEquals(50.0, (xl2[0].blurRadius : Float));
        assertEquals(-12.0, (xl2[0].spreadRadius : Float));
        assertFloatEquals(0.25, xl2[0].color.a);

        assertEquals(0, div().shadowMd().shadowNone().style().boxShadow.length);
    }

    function testFlexAndAlignmentHelpers() {
        final s = div().flex1().style();
        assertEquals(1.0, s.flexGrow);
        assertEquals(1.0, s.flexShrink);
        assertLength(fraction(0), s.flexBasis);
        final none = div().flexNone().style();
        assertEquals(0.0, none.flexShrink);
        assertLength(Length.Auto, none.flexBasis);

        assertEquals(AlignItems.FlexStart, div().itemsStart().style().alignItems);
        assertEquals(AlignItems.Start, div().selfStart().style().alignSelf);
        assertEquals(AlignContent.SpaceBetween, div().justifyBetween().style().justifyContent);
        assertEquals(AlignContent.FlexEnd, div().contentEnd().style().alignContent);
        assertEquals(CursorStyle.PointingHand, div().cursorPointer().style().mouseCursor);
        assertEquals(CursorStyle.ResizeUpRightDownLeft, div().cursorNeswResize().style().mouseCursor);
        assertEquals(Visibility.Hidden, div().invisible().style().visibility);
        assertEquals(Display.None, div().hidden().style().display);
        assertEquals(Overflow.Hidden, div().overflowYHidden().style().overflowY);
        assertFalse(div().overflowYHidden().style().has(StyleRefinement.OVERFLOW_X));
    }

    function testTextHelpers() {
        final t = div().truncate().style();
        assertEquals(Overflow.Hidden, t.overflowX);
        assertEquals(WhiteSpace.Nowrap, t.textStyle().whiteSpace);
        assertTrue(Type.enumEq(TextOverflow.Truncate('…'), t.textStyle().textOverflow));
        assertTrue(div().textSm().style().textStyle().fontSize.equals(AbsoluteLength.Rems(0.875)));
        final u = div().textDecorationWavy().textDecoration2().style().textStyle().underline;
        assertTrue(u.wavy);
        assertEquals(2.0, (u.thickness : Float));
        assertEquals(3, div().lineClamp(3).style().textStyle().lineClamp);
    }

    function testGridHelpers() {
        final s = div().colSpan(2).rowStart(3).style();
        assertTrue(Type.enumEq(GridPlacement.Span(2), s.gridLocation.columnStart));
        assertTrue(Type.enumEq(GridPlacement.Span(2), s.gridLocation.columnEnd));
        assertTrue(Type.enumEq(GridPlacement.Line(3), s.gridLocation.rowStart));
        final full = div().colSpanFull().style();
        assertTrue(Type.enumEq(GridPlacement.Line(-1), full.gridLocation.columnEnd));
        assertEquals(4, div().gridCols(4).style().gridCols.repeat);
    }

    function testCamelCaseConversion() {
        assertEquals('gap2', StyledMacro.camelCase('gap_2'));
        assertEquals('px0p5', StyledMacro.camelCase('px_0p5'));
        assertEquals('wFull', StyledMacro.camelCase('w_full'));
        assertEquals('roundedMd', StyledMacro.camelCase('rounded_md'));
        assertEquals('w1_2', StyledMacro.camelCase('w_1_2'));
        assertEquals('mNeg0p5', StyledMacro.camelCase('m_neg_0p5'));
        assertEquals('gapX1_12', StyledMacro.camelCase('gap_x_1_12'));
        assertEquals('rounded2xl', StyledMacro.camelCase('rounded_2xl'));
    }

    function testOverflowMask() {
        final style = new Style();
        final bounds = bounds(point(10, 20), size(100, 50));
        assertNull(style.overflowMask(bounds, 16));

        style.refine(div().overflowHidden().border2().style());
        // Border without a color: the mask is the bounds
        final plain = style.overflowMask(bounds, 16).bounds;
        assertTrue(plain.equals(bounds), '$plain');

        style.refine(div().borderColor(red()).style());
        final mask = style.overflowMask(bounds, 16).bounds;
        assertTrue(mask.equals(gpui.Prelude.bounds(point(12, 22), size(96, 46))), '$mask');

        final xOnly = new Style();
        xOnly.refine(div().overflowXHidden().border2().borderColor(red()).style());
        // Like GPUI (style.rs): with only x hidden, the border insets the y axis of the mask
        final xMask = xOnly.overflowMask(bounds, 16).bounds;
        assertTrue(xMask.equals(gpui.Prelude.bounds(point(10, 22), size(100, 46))), '$xMask');
    }


    /**
     * `FluentBuilder` (`when_some`, `map`), `debug_selector` (records nothing
     * outside of debug test builds, like GPUI) and the default `child` /
     * `children` of `ParentElement` (`ParentElementTools`).
     */
    function testFluentBuilderAndParentElementDefaults() {
        final none:Null<Int> = null;
        assertEquals(null, div().whenSome(none, (d, v) -> d.w(px(v))).style().sizeWidth);
        final withSome = div().whenSome(7, (d, v) -> d.w(px(v)));
        assertTrue(Type.enumEq(withSome.style().sizeWidth, pixels(7)));
        final mapped = div().map(d -> d.h(px(3)));
        assertTrue(Type.enumEq(mapped.style().sizeHeight, pixels(3)));
        final selected = div();
        assertTrue(selected.debugSelector(() -> 'x') == selected);

        final track = new gpui.base.Progress.ProgressTrack();
        assertTrue(track.child('a').children(['b', 'c']) == track);
        final rendered = track.intoDiv();
        assertEquals(3, @:privateAccess rendered.childElements.length);
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/text/style.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.FontWeight;
import gpui.HighlightStyle;
import gpui.Hsla;
import gpui.Prelude.*;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.WhiteSpace;
import gpui.base.text.TextViewStyle;
import gpui.base.theme.ColorTokens;
import gpui.base.theme.Theme;
import testing.TestCase;

/**
 * Tests of `gpui.base.text.TextViewStyle` (Rust `text/style.rs`).
 *
 * `TextViewStyle.equals` stands for Rust's `PartialEq` (`==`/`!=`), and
 * `Hsla.equals` / `StyleRefinement.equals` for Rust's `assert_eq!` on those
 * types (never `==`, which in Haxe compares references).
 *
 * `tableBackground`, `inlineCodeHighlight`, `onTextColor`, `isInvertedBy`
 * and `fromColors` are `pub(crate)`/private in Rust; `TextViewStyle.hx`
 * exposes them to this package too (`@:allow(gpui.base.text, tests)`, the
 * same pattern used elsewhere in this port for `@:allow(..., tests)`) so
 * these tests can reach them.
 */
class TextStyleTest extends TestCase {

    function testSelectionLayoutFingerprintCoversCallbackTableAndThemeFields() {
        final base = TextViewStyle.defaultValue();
        final heading = base.clone().withHeading(_ -> StyleBuilder.build(s -> s.textSize(px(14.))));
        assertTrue(heading.equals(base.clone().withHeading(_ -> StyleBuilder.build(s -> s.textSize(px(14.))))));
        assertFalse(heading.equals(base.clone().withHeading(_ -> StyleBuilder.build(s -> s.textSize(px(28.))))));

        final table = new StyleRefinement();
        table.textStyle().whiteSpace = Nowrap;
        assertFalse(base.equals(base.clone().withTableCell(table)));

        assertFalse(base.equals(base.clone().withDark(true)));
        assertFalse(base.equals(base.clone().withInlineCodeStyle(StyleBuilder.build(s -> s.borderColor(red())))));
        assertFalse(base.equals(base.clone().withListStyle(StyleBuilder.build(s -> s.textColor(red())))));
        assertFalse(base.equals(base.clone().withBlockquoteStyle(StyleBuilder.build(s -> s.borderColor(red())))));
    }

    function testHeadingEqualitySkipsSharedCallbacksAndComparesDistinctOnes() {
        var calls = 0;
        final style = TextViewStyle.defaultValue().withHeading(_ -> {
            calls++;
            return StyleBuilder.build(s -> s.textSize(px(14.)));
        });

        assertTrue(style.equals(style.clone()));
        assertEquals(0, calls);
        assertFalse(style.equals(style.clone().withParagraphGap(rems(1.))));
        assertFalse(style.equals(style.clone().withDark(!style.isDark())));
        assertEquals(0, calls);

        final equal = style.clone().withHeading(_ -> StyleBuilder.build(s -> s.textSize(px(14.))));
        assertTrue(style.equals(equal));
        assertEquals(6, calls);

        calls = 0;
        final different = style.clone().withHeading(level -> StyleBuilder.build(s -> s.textSize(px(level == 6 ? 28. : 14.))));
        assertFalse(style.equals(different));
        assertEquals(6, calls);
    }

    function testDefaultStyleIsReadableWithoutAnApplicationTheme() {
        final style = TextViewStyle.defaultValue();

        assertEquals(1.0, style.foreground().a);
        assertEquals(1.0, style.link().a);
        assertTrue(style.selection().a > 0.0);
        assertNotNull(style.inlineCode().backgroundColor);
        assertTrue(style.codeBackground().a > 0.0);
        assertTrue(style.border().a > 0.0);
        assertNull(style.codeBlock().cornerRadiusTopLeft);
        assertNull(style.codeBlock().cornerRadiusTopRight);
        assertNull(style.codeBlock().cornerRadiusBottomLeft);
        assertNull(style.codeBlock().cornerRadiusBottomRight);
    }

    function testHeadingRefinementDefaultsEmptyAndResolvesByLevel() {
        final base = TextViewStyle.defaultValue();
        assertTrue(base.heading(1).equals(new StyleRefinement()));

        final style = base.clone().withHeading(level -> switch level {
            case 1: StyleBuilder.build(s -> s.pt(rems(1.)).pb(rems(0.5)));
            default: StyleBuilder.build(s -> s.pb(rems(0.25)));
        });

        assertTrue(style.heading(1).equals(StyleBuilder.build(s -> s.pt(rems(1.)).pb(rems(0.5)))));
        assertTrue(style.heading(2).equals(StyleBuilder.build(s -> s.pb(rems(0.25)))));
        assertFalse(style.equals(base));
    }

    function testInlineCodeFallsBackToTheCodeBackground() {
        final style = TextViewStyle.defaultValue()
            .withCodeBackground(rgb(0x123456).toHsla())
            .withInlineCode(new HighlightStyle());

        assertNotNull(style.inlineCodeHighlight().backgroundColor);
        assertTrue(style.inlineCodeHighlight().backgroundColor.equals(rgb(0x123456).toHsla()));
    }

    function testInlineCodeRefinementsRemainExplicitOnAnInvertedSurface() {
        final colors = ColorTokens.light();
        final plain = TextViewStyle.fromColors(colors, false);
        assertTrue(plain.inlineCodeStyle().equals(new StyleRefinement()));

        for (size in [Math.NaN, Math.POSITIVE_INFINITY, 0., -1.]) {
            final refined = plain.clone().withInlineCodeStyle(StyleBuilder.build(s -> s.textSize(px(size)))).inlineCodeStyle();
            assertNull(refined.textStyle().fontSize);
        }

        final refinement = StyleBuilder.build(s -> s.textSize(rems(1.)).bg(red()).border1().borderColor(blue()));
        final style = plain.withInlineCodeStyle(refinement.clone());
        assertTrue(style.inlineCodeStyle().equals(refinement));
        assertTrue(style.onTextColor(colors.primaryForeground).inlineCodeStyle().equals(refinement));
    }

    function testListAndBlockquoteRefinementsRemainExplicitOnAnInvertedSurface() {
        final colors = ColorTokens.light();
        final plain = TextViewStyle.fromColors(colors, false);
        assertTrue(plain.listStyle().equals(new StyleRefinement()));
        assertTrue(plain.blockquoteStyle().equals(new StyleRefinement()));

        final marker = StyleBuilder.build(s -> s.textColor(red()).fontWeight(FontWeight.BOLD));
        final quote = StyleBuilder.build(s -> s.borderL4().borderColor(blue()).bg(green()));
        final style = plain.withListStyle(marker.clone()).withBlockquoteStyle(quote.clone());
        assertTrue(style.listStyle().equals(marker));
        assertTrue(style.blockquoteStyle().equals(quote));

        final inverted = style.onTextColor(colors.primaryForeground);
        assertTrue(inverted.listStyle().equals(marker));
        assertTrue(inverted.blockquoteStyle().equals(quote));
    }

    function testTextColorOfAMatchingSurfaceOnlyReplacesTheBodyText() {
        final style = TextViewStyle.fromColors(ColorTokens.light(), false);
        final destructive = ColorTokens.light().destructive;

        final adapted = style.onTextColor(destructive);
        assertTrue(adapted.foreground().equals(destructive));
        assertTrue(adapted.link().equals(style.link()));
        assertTrue(adapted.mutedForeground().equals(style.mutedForeground()));
        assertTrue(adapted.codeBackground().equals(style.codeBackground()));
        assertNull(adapted.tableBackground());
        assertFalse(adapted.isDark());
    }

    function testTextColorOfAnInvertedSurfaceDerivesEveryColorFromIt() {
        final cases = [{colors: ColorTokens.light(), isDark: false}, {colors: ColorTokens.dark(), isDark: true}];
        for (c in cases) {
            final style = TextViewStyle.fromColors(c.colors, c.isDark);
            final text = c.colors.primaryForeground;

            final adapted = style.onTextColor(text);
            assertTrue(adapted.foreground().equals(text));
            assertTrue(adapted.link().equals(text));
            assertTrue(adapted.mutedForeground().equals(text.opacity(0.7)));
            assertTrue(adapted.codeBackground().equals(text.opacity(0.12)));
            assertNotNull(adapted.inlineCodeHighlight().backgroundColor);
            assertTrue(adapted.inlineCodeHighlight().backgroundColor.equals(text.opacity(0.12)));
            assertTrue(adapted.border().equals(text.opacity(0.2)));
            assertTrue(adapted.selection().equals(text.opacity(0.25)));

            final tableBackground = adapted.tableBackground();
            assertNotNull(tableBackground);
            if (tableBackground != null)
                assertTrue(tableBackground.equals(Hsla.transparentBlack()));

            final tableHeadColor = adapted.tableHead().textStyle().color;
            assertNotNull(tableHeadColor);
            if (tableHeadColor != null)
                assertTrue(tableHeadColor.equals(text));

            assertEquals(!c.isDark, adapted.isDark());
        }
    }

    function testFromThemeMapsBaseSemanticTokens() {
        final theme = new Theme();
        theme.tokens.colors.foreground = rgb(0x112233).toHsla();
        theme.tokens.colors.mutedForeground = rgb(0x445566).toHsla();
        theme.tokens.colors.primary = rgb(0x3366ff).toHsla();
        theme.tokens.colors.accent = rgb(0xddeeff).toHsla();
        theme.tokens.colors.border = rgb(0x778899).toHsla();
        theme.tokens.colors.selection = rgb(0x55a0fc).toHsla();

        final style = TextViewStyle.fromTheme(theme);
        assertTrue(style.foreground().equals(theme.tokens.colors.foreground));
        assertTrue(style.link().equals(theme.tokens.colors.primary));
        assertTrue(style.selection().equals(theme.tokens.colors.selection));
        assertTrue(style.codeBackground().equals(theme.tokens.colors.accent));
        assertTrue(style.border().equals(theme.tokens.colors.border));
    }

}

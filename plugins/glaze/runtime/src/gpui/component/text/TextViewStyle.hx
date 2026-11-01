// Ported from gpui-kit 0.8.1: crates/component/src/text/style.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.text;

import gpui.HighlightStyle;
import gpui.Pixels;
import gpui.Rems;
import gpui.StyleRefinement;

/**
 * TextViewStyle used to customize the style for the component `TextView`.
 *
 * This is the component-level style. It is folded onto the style the active
 * component `Theme` already derived, so a field left at its default keeps the
 * themed value rather than overriding it with a neutral one.
 */
class TextViewStyle {

    /** Gap of each paragraphs, default is 0.75 rem. */
    public var paragraphGap:Rems = 0.75;

    /**
     * Base font size for headings, default is 14px.
     *
     * Left at the default together with `headingFontSize`, headings follow the
     * text view's own scale, proportional to the body text.
     */
    public var headingBaseFontSize:Pixels = 14.;

    /**
     * Function to calculate heading font size based on heading level (1-6).
     *
     * The first parameter is the heading level (1-6), the second parameter is
     * the base font size.
     */
    public var headingFontSize:Null<(level:Int, base:Pixels) -> Pixels> = null;

    /**
     * Highlight theme for code blocks. Default: `HighlightTheme.defaultLight()`
     * (only used when the highlighter is on, see
     * `gpui.component.highlighter.Highlighter`).
     */
    public var highlightTheme:gpui.component.highlighter.HighlightTheme = gpui.component.highlighter.HighlightTheme.defaultLight();

    /**
     * The style refinement for code blocks.
     *
     * Set `overflowY` to `Scroll` with a max height here to scroll long code
     * inside the block.
     */
    public var codeBlock:StyleRefinement = new StyleRefinement();

    /**
     * Style refinement applied to the table container (the bordered wrapper in
     * wrap mode, the scroll viewport in horizontal-scroll mode).
     *
     * Set `overflowX` to `Scroll` here for adaptive table layout.
     */
    public var table:StyleRefinement = new StyleRefinement();

    /**
     * Style refinement applied to the header row (the first row) of a table,
     * on top of the `tableHead` background and foreground from the theme.
     */
    public var tableHead:StyleRefinement = new StyleRefinement();

    /** Style refinement applied to each table cell. */
    public var tableCell:StyleRefinement = new StyleRefinement();

    /**
     * The highlight style for inline code.
     *
     * Default is an empty `HighlightStyle`; the background color falls back
     * to the theme's `accent` when `null`.
     */
    public var inlineCode:HighlightStyle = new HighlightStyle();

    /** Whether content-specific rendering should use dark-mode assets. */
    public var isDark:Bool = false;

    public function new() {}

    /** Rust `TextViewStyle::default()`. */
    public static function defaultValue():TextViewStyle {
        return new TextViewStyle();
    }

    /** Rust `Clone`: the refinements are cloned, the heading resolver is shared. */
    public function clone():TextViewStyle {
        final style = new TextViewStyle();
        style.paragraphGap = paragraphGap;
        style.headingBaseFontSize = headingBaseFontSize;
        style.headingFontSize = headingFontSize;
        style.highlightTheme = highlightTheme;
        style.codeBlock = codeBlock.clone();
        style.table = table.clone();
        style.tableHead = tableHead.clone();
        style.tableCell = tableCell.clone();
        style.inlineCode = new HighlightStyle(inlineCode.color, inlineCode.fontWeight, inlineCode.fontStyle, inlineCode.backgroundColor,
            inlineCode.underline, inlineCode.strikethrough, inlineCode.fadeOut);
        style.isDark = isDark;
        return style;
    }

    /**
     * Rust `PartialEq`: two heading resolvers are compared on the sizes they
     * give for the six levels.
     */
    public function equals(other:Null<TextViewStyle>):Bool {
        if (other == null)
            return false;
        final headingsEqual = if (headingFontSize != null && other.headingFontSize != null) {
            var all = true;
            for (level in 1...7) {
                if (headingFontSize(level, headingBaseFontSize) != other.headingFontSize(level, other.headingBaseFontSize)) {
                    all = false;
                    break;
                }
            }
            all;
        }
        else {
            headingFontSize == null && other.headingFontSize == null;
        }
        return paragraphGap == other.paragraphGap && headingBaseFontSize == other.headingBaseFontSize && headingsEqual
            && highlightTheme.equals(other.highlightTheme) && codeBlock.equals(other.codeBlock) && table.equals(other.table) && tableHead.equals(other.tableHead)
            && tableCell.equals(other.tableCell) && inlineCode.equals(other.inlineCode) && isDark == other.isDark;
    }

    /** Set paragraph gap, default is 0.75 rem. */
    public function withParagraphGap(gap:Rems):TextViewStyle {
        final style = clone();
        style.paragraphGap = gap;
        return style;
    }

    /**
     * Set the function that resolves a heading's font size from its level
     * (1-6) and `headingBaseFontSize` (Rust `heading_font_size`).
     */
    public function withHeadingFontSize(f:(level:Int, base:Pixels) -> Pixels):TextViewStyle {
        final style = clone();
        style.headingFontSize = f;
        return style;
    }

    /**
     * Set style for code blocks (Rust `code_block`).
     *
     * Set `overflowY` to `Scroll` with a max height on the refinement to
     * scroll long code inside the block instead of growing it.
     */
    public function withCodeBlock(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.codeBlock = refinement;
        return style;
    }

    /** Set style for inline code spans (Rust `inline_code`). */
    public function withInlineCode(highlight:HighlightStyle):TextViewStyle {
        final style = clone();
        style.inlineCode = highlight;
        return style;
    }

    /**
     * Set extra style for the table container (Rust `table`).
     *
     * Set `overflowX` to `Scroll` on the refinement for adaptive layout: cells
     * wrap as the frame narrows, and once columns reach their minimum width
     * the table scrolls horizontally instead of shrinking further.
     */
    public function withTable(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.table = refinement;
        return style;
    }

    /** Set extra style for the table header row (Rust `table_head`). */
    public function withTableHead(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.tableHead = refinement;
        return style;
    }

    /**
     * Set extra style for each table cell (Rust `table_cell`).
     *
     * With the scroll table layout, a `nowrap` white space here keeps cells on
     * a single line and the table scrolls whenever the content is wider than
     * the frame.
     */
    public function withTableCell(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.tableCell = refinement;
        return style;
    }

}

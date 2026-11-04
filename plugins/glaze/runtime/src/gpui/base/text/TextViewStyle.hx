// Ported from gpui-kit 0.8.1: crates/base/src/text/style.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.AbsoluteLength;
import gpui.HighlightStyle;
import gpui.Hsla;
import gpui.Rems;
import gpui.StyleRefinement;
import gpui.base.theme.ColorTokens;
import gpui.base.theme.Theme;

using gpui.AbsoluteLengthTools;

/**
 * TextViewStyle used to customize the style for `TextView`.
 *
 * The fields are private because this type crosses the `gpui-base` seam:
 * build one with the `with*` methods and read it back through the accessors
 * of the same name, so a later field is an additive change rather than a
 * breaking one.
 *
 * The builders return a modified copy (Rust takes `mut self` by value, and
 * callers keep using the original after cloning it).
 */
class TextViewStyle {

    var foreground_:Hsla;
    var mutedForeground_:Hsla;
    var link_:Hsla;
    var selection_:Hsla;
    var codeBackground_:Hsla;
    var border_:Hsla;
    var paragraphGap_:Rems;
    var heading_:(Int) -> StyleRefinement;
    var codeBlock_:StyleRefinement;
    var table_:StyleRefinement;
    var tableHead_:StyleRefinement;
    var tableCell_:StyleRefinement;
    var inlineCode_:HighlightStyle;

    /** Explicit inline code refinements, applied after theme and surface colors. */
    var inlineCodeStyle_:StyleRefinement;

    /** Explicit list marker refinements, applied after theme and surface colors. */
    var listStyle_:StyleRefinement;

    /** Explicit blockquote refinements, applied after theme and surface colors. */
    var blockquoteStyle_:StyleRefinement;

    /**
     * The table body background, or the theme surface when `null`. Only
     * `onTextColor` sets it, to let a table on an inverted surface show that
     * surface.
     */
    var tableBackground_:Null<Hsla>;

    var isDark_:Bool;

    static function emptyHeading(_:Int):StyleRefinement {
        return new StyleRefinement();
    }

    function new() {}

    /** `TextViewStyle::default()`: the light palette. */
    public static function defaultValue():TextViewStyle {
        return fromColors(ColorTokens.light(), false);
    }

    /** Derives rich-text colors from Base semantic theme tokens. */
    public static function fromTheme(theme:Theme):TextViewStyle {
        return fromColors(theme.tokens.colors, theme.appearance == Dark);
    }

    /**
     * Derives rich-text colors from one palette.
     *
     * Rich text needs a handful of roles the palette does not name directly
     * (a code background, a link color), so they are mapped here once instead
     * of at every call site.
     */
    @:allow(gpui.base.text, tests)
    static function fromColors(colors:ColorTokens, isDark:Bool):TextViewStyle {
        final style = new TextViewStyle();
        style.foreground_ = colors.foreground;
        style.mutedForeground_ = colors.mutedForeground;
        style.link_ = colors.primary;
        style.selection_ = colors.selection;
        style.codeBackground_ = colors.accent;
        style.border_ = colors.border;
        style.paragraphGap_ = 0.75;
        style.heading_ = emptyHeading;
        style.codeBlock_ = new StyleRefinement();
        style.table_ = new StyleRefinement();
        style.tableHead_ = new StyleRefinement();
        style.tableCell_ = new StyleRefinement();
        style.inlineCode_ = new HighlightStyle(null, null, null, colors.accent);
        style.inlineCodeStyle_ = new StyleRefinement();
        style.listStyle_ = new StyleRefinement();
        style.blockquoteStyle_ = new StyleRefinement();
        style.tableBackground_ = null;
        style.isDark_ = isDark;
        return style;
    }

    /** Rust `Clone`: the refinements are cloned, the heading callback is shared. */
    public function clone():TextViewStyle {
        final style = new TextViewStyle();
        style.foreground_ = foreground_;
        style.mutedForeground_ = mutedForeground_;
        style.link_ = link_;
        style.selection_ = selection_;
        style.codeBackground_ = codeBackground_;
        style.border_ = border_;
        style.paragraphGap_ = paragraphGap_;
        style.heading_ = heading_;
        style.codeBlock_ = codeBlock_.clone();
        style.table_ = table_.clone();
        style.tableHead_ = tableHead_.clone();
        style.tableCell_ = tableCell_.clone();
        style.inlineCode_ = copyHighlight(inlineCode_);
        style.inlineCodeStyle_ = inlineCodeStyle_.clone();
        style.listStyle_ = listStyle_.clone();
        style.blockquoteStyle_ = blockquoteStyle_.clone();
        style.tableBackground_ = tableBackground_;
        style.isDark_ = isDark_;
        return style;
    }

    static function copyHighlight(style:HighlightStyle):HighlightStyle {
        return new HighlightStyle(style.color, style.fontWeight, style.fontStyle, style.backgroundColor, style.underline, style.strikethrough,
            style.fadeOut);
    }

    static inline function colorEq(a:Null<Hsla>, b:Null<Hsla>):Bool {
        return a == null ? b == null : b != null && a.equals(b);
    }

    /**
     * Rust `PartialEq`. Two different heading callbacks are compared on
     * their refinements for the six levels.
     */
    public function equals(other:Null<TextViewStyle>):Bool {
        if (other == null)
            return false;
        if (other == this)
            return true;
        return paragraphGap_ == other.paragraphGap_ && foreground_.equals(other.foreground_) && mutedForeground_.equals(other.mutedForeground_)
            && link_.equals(other.link_) && selection_.equals(other.selection_) && codeBackground_.equals(other.codeBackground_)
            && border_.equals(other.border_) && headingEquals(other) && codeBlock_.equals(other.codeBlock_) && table_.equals(other.table_)
            && tableHead_.equals(other.tableHead_) && tableCell_.equals(other.tableCell_) && inlineCode_.equals(other.inlineCode_)
            && inlineCodeStyle_.equals(other.inlineCodeStyle_) && listStyle_.equals(other.listStyle_)
            && blockquoteStyle_.equals(other.blockquoteStyle_) && colorEq(tableBackground_, other.tableBackground_) && isDark_ == other.isDark_;
    }

    function headingEquals(other:TextViewStyle):Bool {
        if (Reflect.compareMethods(heading_, other.heading_))
            return true;
        for (level in 1...7) {
            if (!heading_(level).equals(other.heading_(level)))
                return false;
        }
        return true;
    }

    /** Sets the default body-text color. */
    public function withForeground(color:Hsla):TextViewStyle {
        final style = clone();
        style.foreground_ = color;
        return style;
    }

    /** Sets the secondary text color. */
    public function withMutedForeground(color:Hsla):TextViewStyle {
        final style = clone();
        style.mutedForeground_ = color;
        return style;
    }

    /** Sets the link text color. */
    public function withLink(color:Hsla):TextViewStyle {
        final style = clone();
        style.link_ = color;
        return style;
    }

    /**
     * Sets the background painted behind selected text.
     *
     * Selection quads are painted under the glyphs, so this is normally a
     * translucent wash rather than a solid fill.
     */
    public function withSelection(color:Hsla):TextViewStyle {
        final style = clone();
        style.selection_ = color;
        return style;
    }

    /** Sets the background of fenced code blocks and table header rows. */
    public function withCodeBackground(color:Hsla):TextViewStyle {
        final style = clone();
        style.codeBackground_ = color;
        return style;
    }

    /** Sets the color of borders and horizontal rules. */
    public function withBorder(color:Hsla):TextViewStyle {
        final style = clone();
        style.border_ = color;
        return style;
    }

    /** Sets the gap between paragraphs. Defaults to 0.75 rem. */
    public function withParagraphGap(gap:Rems):TextViewStyle {
        final style = clone();
        style.paragraphGap_ = gap;
        return style;
    }

    /** Sets the style refinement for headings, selected by heading level (1-6). */
    public function withHeading(heading:(Int) -> StyleRefinement):TextViewStyle {
        final style = clone();
        style.heading_ = heading;
        return style;
    }

    /**
     * Sets the style refinement for code blocks.
     *
     * Set `overflowY` to `Overflow.Scroll` together with a max height to
     * scroll long code inside the block: it gets its own scrollbar, and wheel
     * input over it no longer scrolls an ancestor list until the code reaches
     * its edge.
     */
    public function withCodeBlock(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.codeBlock_ = refinement;
        return style;
    }

    /**
     * Sets the highlight style for inline code spans.
     *
     * When `backgroundColor` is `null`, the neutral code background is used,
     * which keeps `TextViewStyle.defaultValue()` usable without a theme.
     */
    public function withInlineCode(highlight:HighlightStyle):TextViewStyle {
        final style = clone();
        style.inlineCode_ = highlight;
        return style;
    }

    /**
     * Overrides inline code typography and its box presentation.
     *
     * Supports font family, size, features, fallbacks, weight, style, color,
     * underline and strikethrough, background, border widths/color/style,
     * corner radii, and padding. Sizes and padding resolve pixels/rem
     * against the window. Unspecified properties keep the existing defaults.
     * Box layout, margin, positioning, overflow, and interaction properties
     * are not used. Line height remains owned by the paragraph. Non-finite or
     * non-positive font sizes are ignored. Explicit refinements also take
     * precedence on inverted surfaces.
     */
    public function withInlineCodeStyle(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.inlineCodeStyle_ = normalizeInlineCodeStyle(refinement);
        return style;
    }

    /**
     * Refines the marker of a bullet or numbered list item.
     *
     * Applied to the marker column after its defaults: the muted text color,
     * a minimum width of the list indent, right-aligned text, and a right
     * padding of 0.3 times that indent. Text properties such as color, font
     * family, size, and weight style the bullet or number. The text color
     * also outlines an unchecked task-list checkbox; a checked one keeps the
     * link color. Unspecified properties keep the existing defaults, and
     * explicit refinements also take precedence on inverted surfaces.
     */
    public function withListStyle(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.listStyle_ = refinement;
        return style;
    }

    /**
     * Refines the blockquote container.
     *
     * Applied after its defaults: the muted text color, a 2px left border in
     * the border color, and a left padding of 0.9 times the body font size.
     * Border widths and color style the quote bar; text properties,
     * background, padding, and corner radii style the quote and its
     * contents. Child blocks keep properties they set explicitly, including
     * heading and table font sizes. Unspecified properties keep the existing
     * defaults, and explicit refinements also take precedence on inverted
     * surfaces.
     */
    public function withBlockquoteStyle(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.blockquoteStyle_ = refinement;
        return style;
    }

    /**
     * Sets the style refinement for the table container (the bordered
     * wrapper in wrap mode, the scroll viewport in horizontal-scroll mode).
     *
     * Set `overflowX: scroll` on the refinement for adaptive table layout:
     * columns fit their content when space allows, shrink (wrapping cell
     * text) down to a per-column floor when the frame is narrower, and below
     * that the table scrolls horizontally instead of squeezing further.
     */
    public function withTable(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.table_ = refinement;
        return style;
    }

    /**
     * Sets the style refinement for the header row (the first row) of a
     * table, applied on top of the header background and foreground.
     */
    public function withTableHead(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.tableHead_ = refinement;
        return style;
    }

    /**
     * Sets the style refinement for each table cell.
     *
     * With the scroll table layout, `whiteSpace: nowrap` here keeps cells on
     * a single line: columns then never shrink and the table scrolls as soon
     * as the content is wider than the frame.
     */
    public function withTableCell(refinement:StyleRefinement):TextViewStyle {
        final style = clone();
        style.tableCell_ = refinement;
        return style;
    }

    /** Sets whether content-specific assets should use their dark variant. */
    public function withDark(isDark:Bool):TextViewStyle {
        final style = clone();
        style.isDark_ = isDark;
        return style;
    }

    /** The default body-text color. */
    public inline function foreground():Hsla {
        return foreground_;
    }

    /** The secondary text color. */
    public inline function mutedForeground():Hsla {
        return mutedForeground_;
    }

    /** The link text color. */
    public inline function link():Hsla {
        return link_;
    }

    /** The background painted behind selected text. */
    public inline function selection():Hsla {
        return selection_;
    }

    /** The background of fenced code blocks and table header rows. */
    public inline function codeBackground():Hsla {
        return codeBackground_;
    }

    /** The color of borders and horizontal rules. */
    public inline function border():Hsla {
        return border_;
    }

    /** The gap between paragraphs. */
    public inline function paragraphGap():Rems {
        return paragraphGap_;
    }

    /** The style refinement for a heading at `level` (1-6). */
    public function heading(level:Int):StyleRefinement {
        return heading_(level);
    }

    /** The style refinement for code blocks. */
    public inline function codeBlock():StyleRefinement {
        return codeBlock_;
    }

    /** The style refinement for the table container. */
    public inline function table():StyleRefinement {
        return table_;
    }

    /** The style refinement for table header rows. */
    public inline function tableHead():StyleRefinement {
        return tableHead_;
    }

    /** The style refinement for table cells. */
    public inline function tableCell():StyleRefinement {
        return tableCell_;
    }

    /**
     * The highlight style for inline code, before the code-background
     * fallback in `inlineCodeHighlight` applies.
     */
    public inline function inlineCode():HighlightStyle {
        return inlineCode_;
    }

    /** Explicit inline code typography and box refinements. */
    public inline function inlineCodeStyle():StyleRefinement {
        return inlineCodeStyle_;
    }

    /** Explicit list marker refinements. */
    public inline function listStyle():StyleRefinement {
        return listStyle_;
    }

    /** Explicit blockquote refinements. */
    public inline function blockquoteStyle():StyleRefinement {
        return blockquoteStyle_;
    }

    /** Whether content-specific assets should use their dark variant. */
    public inline function isDark():Bool {
        return isDark_;
    }

    /** The table body background, when it is not the theme surface. */
    @:allow(gpui.base.text, tests)
    function tableBackground():Null<Hsla> {
        return tableBackground_;
    }

    /**
     * Returns the `HighlightStyle` to use for inline code, falling back to
     * the code background when no custom background was supplied.
     */
    @:allow(gpui.base.text, tests)
    function inlineCodeHighlight():HighlightStyle {
        final style = copyHighlight(inlineCode_);
        if (style.backgroundColor == null) {
            style.backgroundColor = codeBackground_;
        }
        return style;
    }

    /**
     * This style adapted to body text drawn in `color`, the text color a
     * container sets for its surface.
     *
     * The body text always takes `color`. When `color` is far from this
     * style's foreground in lightness, the surface is inverted from the one
     * this style was made for (a `primary` fill, say): the link, muted text,
     * code, border and selection colors would vanish on it, so they are all
     * derived from `color`, and `isDark` flips.
     */
    @:allow(gpui.base.text, tests)
    function onTextColor(color:Hsla):TextViewStyle {
        final style = withForeground(color);
        if (!isInvertedBy(color)) {
            return style;
        }

        final codeBackground = color.opacity(0.12);
        final tableHead = tableHead_.clone();
        tableHead.background = gpui.Background.fromHsla(codeBackground);
        tableHead.textStyle().color = color;
        final inlineCode = copyHighlight(inlineCode_);
        inlineCode.backgroundColor = codeBackground;
        final style = style.withMutedForeground(color.opacity(0.7))
            .withLink(color)
            .withSelection(color.opacity(0.25))
            .withCodeBackground(codeBackground)
            .withBorder(color.opacity(0.2))
            .withInlineCode(inlineCode)
            .withTableHead(tableHead)
            .withDark(!isDark_);
        style.tableBackground_ = Hsla.transparentBlack();
        return style;
    }

    /**
     * Whether body text in `color` sits on a surface inverted from the one
     * this style was made for.
     *
     * Mid-tone text such as a destructive red reads on either kind of
     * surface, so only a lightness gap wider than that counts as inverted.
     */
    @:allow(gpui.base.text, tests)
    function isInvertedBy(color:Hsla):Bool {
        final INVERTED_LIGHTNESS_GAP = 0.6;
        return Math.abs(f32(oklabLightness(color) - oklabLightness(foreground_))) > INVERTED_LIGHTNESS_GAP;
    }

    static inline function f32(value:Float):Float {
        return taffy.util.F32.fround(value);
    }

    /** The perceptual (Oklab) lightness of `color`, from 0 (black) to 1 (white). */
    static function oklabLightness(color:Hsla):Float {
        final rgb = color.toRgb();
        inline function linear(c:Float):Float {
            return c <= 0.04045 ? f32(c / 12.92) : f32(Math.pow(f32((c + 0.055) / 1.055), 2.4));
        }
        final r = linear(rgb.r);
        final g = linear(rgb.g);
        final b = linear(rgb.b);
        final l = cbrt(f32(f32(f32(0.41222146 * r) + f32(0.53633255 * g)) + f32(0.051445995 * b)));
        final m = cbrt(f32(f32(f32(0.2119035 * r) + f32(0.6806995 * g)) + f32(0.10739696 * b)));
        final s = cbrt(f32(f32(f32(0.08830246 * r) + f32(0.28171885 * g)) + f32(0.6299787 * b)));
        return f32(f32(f32(0.21045426 * l) + f32(0.7936178 * m)) - f32(0.004072047 * s));
    }

    static function cbrt(value:Float):Float {
        if (value == 0)
            return 0;
        final result = value < 0 ? -Math.pow(-value, 1 / 3) : Math.pow(value, 1 / 3);
        return f32(result);
    }

    /**
     * Drop an invalid font size before it can replace an inherited value or
     * make retained style equality fail every frame (NaN is never equal).
     */
    @:allow(gpui.base.text, tests)
    static function normalizeInlineCodeStyle(style:StyleRefinement):StyleRefinement {
        if (style.text != null && style.text.fontSize != null) {
            final size:Float = style.text.fontSize.toPixels(1.);
            if (!Math.isFinite(size) || size <= 0.) {
                style.text.fontSize = null;
            }
        }
        return style;
    }

}

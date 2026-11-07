// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The properties that can be used to style text in GPUI.
 *
 * `lineClamp` is `-1` when unset (Rust `None`), to avoid a boxed `Null<Int>`.
 */
class TextStyle {

    /**
     * The last styles composed from this one by a window, with the
     * refinements they were composed with (`Window.currentTextStyle`:
     * siblings with equal refinements share one style; four slots, reused in
     * turn, for the few variants of a list of siblings). Internal.
     */
    @:noCompletion public var childRefinement0:Null<TextStyleRefinement> = null;
    @:noCompletion public var childStyle0:Null<TextStyle> = null;
    @:noCompletion public var childRefinement1:Null<TextStyleRefinement> = null;
    @:noCompletion public var childStyle1:Null<TextStyle> = null;
    @:noCompletion public var childRefinement2:Null<TextStyleRefinement> = null;
    @:noCompletion public var childStyle2:Null<TextStyle> = null;
    @:noCompletion public var childRefinement3:Null<TextStyleRefinement> = null;
    @:noCompletion public var childStyle3:Null<TextStyle> = null;
    @:noCompletion public var nextChildSlot:Int = 0;

    /** The color of the text */
    public var color:Hsla;

    /** The font family to use */
    public var fontFamily:String;

    /** The font features to use */
    public var fontFeatures:FontFeatures;

    /** The fallback fonts to use */
    public var fontFallbacks:Null<FontFallbacks>;

    /** The font size to use, in pixels or rems. */
    public var fontSize:AbsoluteLength;

    /** The line height to use, in pixels or fractions */
    public var lineHeight:DefiniteLength;

    /** The font weight, e.g. bold */
    public var fontWeight:FontWeight;

    /** The font style, e.g. italic */
    public var fontStyle:FontStyle;

    /** The background color of the text */
    public var backgroundColor:Null<Hsla>;

    /** The underline style of the text */
    public var underline:Null<UnderlineStyle>;

    /** The strikethrough style of the text */
    public var strikethrough:Null<StrikethroughStyle>;

    /** How to handle whitespace in the text */
    public var whiteSpace:WhiteSpace;

    /** The text should be truncated if it overflows the width of the element */
    public var textOverflow:Null<TextOverflow>;

    /** How the text should be aligned within the element */
    public var textAlign:TextAlign;

    /** The number of lines to display before truncating the text, `-1` for no limit */
    public var lineClamp:Int;

    static final DEFAULT_COLOR:Hsla = Hsla.black();

    static final DEFAULT_FONT_SIZE:AbsoluteLength = AbsoluteLength.Rems(1.0);

    static final DEFAULT_LINE_HEIGHT:DefiniteLength = Prelude.phi();

    /**
     * Creates the default text style (Rust `TextStyle::default()`).
     */
    public function new() {
        #if glaze_count_allocations glaze.util.AllocationCounters.textStyles++; #end
        // The default values are immutable: shared by every style
        color = DEFAULT_COLOR;
        fontFamily = '.SystemUIFont';
        fontFeatures = FontFeatures.defaultValue();
        fontFallbacks = null;
        fontSize = DEFAULT_FONT_SIZE;
        lineHeight = DEFAULT_LINE_HEIGHT;
        fontWeight = FontWeight.NORMAL;
        fontStyle = Normal;
        backgroundColor = null;
        underline = null;
        strikethrough = null;
        whiteSpace = Normal;
        textOverflow = null;
        textAlign = Left;
        lineClamp = -1;
    }

    /**
     * Applies the fields set in the given refinement.
     */
    public function refine(refinement:TextStyleRefinement):Void {
        if (refinement == null)
            return;
        if (refinement.color != null) color = refinement.color;
        if (refinement.fontFamily != null) fontFamily = refinement.fontFamily;
        if (refinement.fontFeatures != null) fontFeatures = refinement.fontFeatures;
        if (refinement.fontFallbacks != null) fontFallbacks = refinement.fontFallbacks;
        if (refinement.fontSize != null) fontSize = refinement.fontSize;
        if (refinement.lineHeight != null) lineHeight = refinement.lineHeight;
        if (refinement.has(TextStyleRefinement.FONT_WEIGHT)) fontWeight = refinement.fontWeight;
        if (refinement.has(TextStyleRefinement.FONT_STYLE)) fontStyle = refinement.fontStyle;
        if (refinement.backgroundColor != null) backgroundColor = refinement.backgroundColor;
        if (refinement.underline != null) underline = refinement.underline;
        if (refinement.strikethrough != null) strikethrough = refinement.strikethrough;
        if (refinement.has(TextStyleRefinement.WHITE_SPACE)) whiteSpace = refinement.whiteSpace;
        if (refinement.textOverflow != null) textOverflow = refinement.textOverflow;
        if (refinement.has(TextStyleRefinement.TEXT_ALIGN)) textAlign = refinement.textAlign;
        if (refinement.has(TextStyleRefinement.LINE_CLAMP)) lineClamp = refinement.lineClamp;
    }

    /**
     * The fields of this style that differ from `refinement` (Rust
     * `Refineable::subtract`, generated by `#[derive(Refineable)]`): a field
     * that is not optional is kept unless `refinement` sets it to the same
     * value; an optional field is kept unless it equals `refinement`'s.
     * `style.subtract(new TextStyleRefinement())` turns the whole style into
     * a refinement.
     */
    public function subtract(refinement:TextStyleRefinement):TextStyleRefinement {
        final result = new TextStyleRefinement();
        inline function eqHsla(a:Null<Hsla>, b:Null<Hsla>) return a == null ? b == null : b != null && a.equals(b);
        if (!(refinement.color != null && color.equals(refinement.color))) result.color = color;
        if (!(refinement.fontFamily != null && fontFamily == refinement.fontFamily)) result.fontFamily = fontFamily;
        if (!(refinement.fontFeatures != null && fontFeatures.equals(refinement.fontFeatures))) result.fontFeatures = fontFeatures;
        if (!(fontFallbacks == null ? refinement.fontFallbacks == null : refinement.fontFallbacks != null && fontFallbacks.equals(refinement.fontFallbacks)))
            result.fontFallbacks = fontFallbacks;
        if (!(refinement.fontSize != null && fontSize.equals(refinement.fontSize))) result.fontSize = fontSize;
        if (!(refinement.lineHeight != null && lineHeight.equals(refinement.lineHeight))) result.lineHeight = lineHeight;
        if (!(refinement.has(TextStyleRefinement.FONT_WEIGHT) && fontWeight == refinement.fontWeight)) result.fontWeight = fontWeight;
        if (!(refinement.has(TextStyleRefinement.FONT_STYLE) && fontStyle == refinement.fontStyle)) result.fontStyle = fontStyle;
        if (!eqHsla(backgroundColor, refinement.backgroundColor)) result.backgroundColor = backgroundColor;
        if (!(underline == null ? refinement.underline == null : refinement.underline != null && underline.equals(refinement.underline)))
            result.underline = underline;
        if (!(strikethrough == null ? refinement.strikethrough == null : refinement.strikethrough != null && strikethrough.equals(refinement.strikethrough)))
            result.strikethrough = strikethrough;
        if (!(refinement.has(TextStyleRefinement.WHITE_SPACE) && whiteSpace == refinement.whiteSpace)) result.whiteSpace = whiteSpace;
        if (!Type.enumEq(textOverflow, refinement.textOverflow)) result.textOverflow = textOverflow;
        if (!(refinement.has(TextStyleRefinement.TEXT_ALIGN) && textAlign == refinement.textAlign)) result.textAlign = textAlign;
        if (lineClamp != -1 && !(refinement.has(TextStyleRefinement.LINE_CLAMP) && refinement.lineClamp == lineClamp)) result.lineClamp = lineClamp;
        return result;
    }

    /**
     * Create a new text style with the given highlighting applied
     * (modifies and returns this style: call it on a `clone()`).
     */
    public function highlight(style:HighlightStyle):TextStyle {
        if (style.fontWeight != null) {
            fontWeight = style.fontWeight;
        }
        if (style.fontStyle != null) {
            fontStyle = style.fontStyle;
        }
        if (style.color != null) {
            color = color.blend(style.color);
        }
        if (style.fadeOut != null) {
            color = color.fadeOut(style.fadeOut);
        }
        if (style.backgroundColor != null) {
            backgroundColor = style.backgroundColor;
        }
        if (style.underline != null) {
            underline = style.underline;
        }
        if (style.strikethrough != null) {
            strikethrough = style.strikethrough;
        }
        return this;
    }

    /**
     * Get the font configured for this text style.
     */
    public function font():Font {
        return new Font(fontFamily, fontFeatures, fontFallbacks, fontWeight, fontStyle);
    }

    /**
     * Convert this text style into a `TextRun`, for the given length of the text.
     */
    public function toRun(len:Int):TextRun {
        return new TextRun(len, font(), color, backgroundColor, underline, strikethrough);
    }

    /**
     * Returns the rounded line height in pixels.
     */
    public function lineHeightInPixels(remSize:Pixels):Pixels {
        return glaze.util.MathUtil.round(lineHeight.toPixels(fontSize, remSize));
    }

    /**
     * The style composed from `parent` (this style, or `null` on the slots of
     * a window's first level, see `Window.textStyleRootSlots`) in the given
     * frame of `window` with a refinement equal to `refinement`, if one of
     * the child slots holds it (a slot counts while its refinement was last
     * composed with that parent, in that frame, into the slot's style: a
     * refinement changed and composed again since then no longer matches).
     * Internal (`Window.currentTextStyle`).
     */
    @:noCompletion public function composedChild(refinement:TextStyleRefinement, parent:Null<TextStyle>, frame:Int, window:Window):Null<TextStyle> {
        var sibling = childRefinement0;
        if (sibling != null && sibling.composedFrame == frame && sibling.composedWindow == window
            && sibling.composedParent == parent && sibling.composedStyle == childStyle0 && sibling.equals(refinement))
            return childStyle0;
        sibling = childRefinement1;
        if (sibling != null && sibling.composedFrame == frame && sibling.composedWindow == window
            && sibling.composedParent == parent && sibling.composedStyle == childStyle1 && sibling.equals(refinement))
            return childStyle1;
        sibling = childRefinement2;
        if (sibling != null && sibling.composedFrame == frame && sibling.composedWindow == window
            && sibling.composedParent == parent && sibling.composedStyle == childStyle2 && sibling.equals(refinement))
            return childStyle2;
        sibling = childRefinement3;
        if (sibling != null && sibling.composedFrame == frame && sibling.composedWindow == window
            && sibling.composedParent == parent && sibling.composedStyle == childStyle3 && sibling.equals(refinement))
            return childStyle3;
        return null;
    }

    /**
     * Remember `style`, composed from this one with `refinement`, in the next
     * child slot. Internal (`Window.currentTextStyle`).
     */
    @:noCompletion public function rememberChild(refinement:TextStyleRefinement, style:TextStyle):Void {
        switch nextChildSlot {
            case 0:
                childRefinement0 = refinement;
                childStyle0 = style;
            case 1:
                childRefinement1 = refinement;
                childStyle1 = style;
            case 2:
                childRefinement2 = refinement;
                childStyle2 = style;
            default:
                childRefinement3 = refinement;
                childStyle3 = style;
        }
        nextChildSlot = (nextChildSlot + 1) & 3;
    }

    public function clone():TextStyle {
        final result = new TextStyle();
        result.color = color;
        result.fontFamily = fontFamily;
        result.fontFeatures = fontFeatures;
        result.fontFallbacks = fontFallbacks;
        result.fontSize = fontSize;
        result.lineHeight = lineHeight;
        result.fontWeight = fontWeight;
        result.fontStyle = fontStyle;
        result.backgroundColor = backgroundColor;
        result.underline = underline;
        result.strikethrough = strikethrough;
        result.whiteSpace = whiteSpace;
        result.textOverflow = textOverflow;
        result.textAlign = textAlign;
        result.lineClamp = lineClamp;
        return result;
    }

    public function equals(other:TextStyle):Bool {
        if (other == null) return false;
        inline function eqHsla(a:Null<Hsla>, b:Null<Hsla>) return a == null ? b == null : a.equals(b);
        return color.equals(other.color)
            && fontFamily == other.fontFamily
            && fontFeatures.equals(other.fontFeatures)
            && (fontFallbacks == null ? other.fontFallbacks == null : fontFallbacks.equals(other.fontFallbacks))
            && fontSize.equals(other.fontSize)
            && lineHeight.equals(other.lineHeight)
            && fontWeight == other.fontWeight
            && fontStyle == other.fontStyle
            && eqHsla(backgroundColor, other.backgroundColor)
            && (underline == null ? other.underline == null : underline.equals(other.underline))
            && (strikethrough == null ? other.strikethrough == null : strikethrough.equals(other.strikethrough))
            && whiteSpace == other.whiteSpace
            && Type.enumEq(textOverflow, other.textOverflow)
            && textAlign == other.textAlign
            && lineClamp == other.lineClamp;
    }

}

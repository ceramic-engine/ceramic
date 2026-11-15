// Ported from gpui-kit 0.8.1: crates/base/src/text/inline.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Additions without upstream equivalent (rich text, G12): the nullable fields `box`, `fontSizeAbsolute`,
// `fontSizeRelative`, `letterSpacingPx`, `letterSpacingEm`, `textTransform`, `opacity`, `transformation` and
// `animation`. Left null, every computation below is gpui-kit's.
package glaze.kit.base.text;

import glaze.Edges;
import glaze.FontFeatures;
import glaze.HighlightStyle;
import glaze.Hsla;
import glaze.Pixels;
import glaze.Range;
import glaze.StyleRefinement;
import glaze.TextRun;
import glaze.TextStyle;

using glaze.AbsoluteLengthTools;
using glaze.DefiniteLengthTools;

/**
 * The style applied to one range of inline text.
 *
 * A `HighlightStyle` carries no font family, so the family an inline code
 * span is set in rides beside it; `null` keeps the family of the enclosing
 * text style.
 *
 * Also holds the free highlight functions of inline.rs
 * (`combineHighlights`, `fadeHighlights`, `textRuns`, `codeInsetsOf`,
 * `textSizeRanges`).
 */
class InlineHighlight {

    @:allow(glaze.kit.base.text)
    var style:HighlightStyle;

    @:allow(glaze.kit.base.text)
    var fontFamily:Null<String> = null;

    @:allow(glaze.kit.base.text)
    var fontSizeScale:Null<Float> = null;

    /** Typography and box refinements for an inline code span. */
    @:allow(glaze.kit.base.text)
    var codeStyle:Null<StyleRefinement> = null;

    /**
     * A box around the span: background, border, corner radii, paddings and
     * margins of the refinement (the vertical margins only make the line
     * taller, they do not move the box). The span is then one unbreakable pill. Unlike the code chip,
     * nothing is implied: no default padding, and square corners unless the
     * box rounds them.
     */
    public var box:Null<StyleRefinement> = null;

    /** The font size of the span in pixels; wins over `fontSizeRelative`. */
    public var fontSizeAbsolute:Null<Pixels> = null;

    /** The font size of the span as a part of the paragraph's (`1.2` for 120 %). */
    public var fontSizeRelative:Null<Float> = null;

    /** Space added after each character, in pixels; wins over `letterSpacingEm`. */
    public var letterSpacingPx:Null<Float> = null;

    /** Space added after each character, in em of the span's font size. */
    public var letterSpacingEm:Null<Float> = null;

    /**
     * The case the span is shown in. The flow shows the text it is given:
     * whoever builds the items applies the transform first, with
     * `InlineMotion.transformText`, which remaps the ranges when a length
     * changes.
     */
    public var textTransform:Null<InlineMotion.InlineTextTransform> = null;

    /** The opacity of the span (text, decorations and box), 1 when null. */
    public var opacity:Null<Float> = null;

    /** A fixed transformation of the span, painted without changing the layout. */
    public var transformation:Null<glaze.Transformation> = null;

    /**
     * An animation of the span, sampled when it is painted. Only whether
     * there is one, and whether it is per character, takes part in `equals`
     * and so in the layout key of a flow: an animated flow is never laid out
     * again for a frame of its animation.
     */
    public var animation:Null<InlineMotion.InlineAnimation> = null;

    /**
     * Moves the span up from the baseline of its line, in pixels (down when
     * negative); wins over `baselineShiftEm`. The line grows to hold the
     * moved span, as with CSS `vertical-align: <length>`.
     */
    public var baselineShiftPx:Null<Float> = null;

    /** The same in em of the span's font size (`0.06`, or `0.4` for a superscript). */
    public var baselineShiftEm:Null<Float> = null;

    /**
     * The line height of the span in pixels; wins over `lineHeightRelative`.
     * The span then takes part in the height of its line with this height,
     * centered on its glyphs, instead of the height of its glyphs; the
     * line is never smaller than the paragraph's own line height. A `box`
     * is as tall as this height (plus its paddings and borders) when it is
     * taller than the glyphs.
     */
    public var lineHeightPx:Null<Float> = null;

    /** The same as a multiple of the span's font size (`1.6`). */
    public var lineHeightRelative:Null<Float> = null;

    /** Whether one of the rich text fields is set (then the span is its own fragment). */
    @:allow(glaze.kit.base.text)
    inline function isRich():Bool {
        return box != null || transformation != null || animation != null
            || baselineShiftPx != null || baselineShiftEm != null || lineHeightPx != null || lineHeightRelative != null;
    }

    /** The baseline shift of the span in pixels (up when positive), for a font size of `emSize`. */
    @:allow(glaze.kit.base.text)
    function baselineShiftFor(emSize:Float):Float {
        if (baselineShiftPx != null) return taffy.util.F32.fround(baselineShiftPx);
        if (baselineShiftEm != null) return taffy.util.F32.fround(baselineShiftEm * emSize);
        return 0.;
    }

    /** The line height of the span in pixels for a font size of `emSize`, `null` when it has none of its own. */
    @:allow(glaze.kit.base.text)
    function lineHeightFor(emSize:Float):Null<Float> {
        if (lineHeightPx != null) return taffy.util.F32.fround(Math.max(lineHeightPx, 0.));
        if (lineHeightRelative != null) return taffy.util.F32.fround(Math.max(lineHeightRelative, 0.) * emSize);
        return null;
    }

    /** The top and bottom margins of a generic `box` in pixels (`left` and `right` are zero). */
    @:allow(glaze.kit.base.text)
    function boxVerticalMargins(fontSize:Pixels, remSize:Pixels):Edges {
        final style = box;
        if (style == null || (style.marginTop == null && style.marginBottom == null)) return new Edges();
        inline function margin(length:Null<glaze.Length>):Float {
            return switch length {
                case null: 0.;
                case Definite(definite): Math.max(definite.toPixels(glaze.AbsoluteLength.Pixels(fontSize), remSize), 0);
                case _: 0.;
            }
        }
        return new Edges(margin(style.marginTop), 0, margin(style.marginBottom), 0);
    }

    /** Whether the span measures differently from body text of its family. */
    @:allow(glaze.kit.base.text)
    inline function measuresApart():Bool {
        return box != null || fontSizeAbsolute != null || fontSizeRelative != null || letterSpacingPx != null || letterSpacingEm != null
            || (animation != null && animation.isPerCharacter());
    }

    function copyRich(to:InlineHighlight):InlineHighlight {
        to.box = box != null ? box.clone() : null;
        to.fontSizeAbsolute = fontSizeAbsolute;
        to.fontSizeRelative = fontSizeRelative;
        to.letterSpacingPx = letterSpacingPx;
        to.letterSpacingEm = letterSpacingEm;
        to.baselineShiftPx = baselineShiftPx;
        to.baselineShiftEm = baselineShiftEm;
        to.lineHeightPx = lineHeightPx;
        to.lineHeightRelative = lineHeightRelative;
        to.textTransform = textTransform;
        to.opacity = opacity;
        to.transformation = transformation;
        to.animation = animation;
        return to;
    }

    function sameRich(other:InlineHighlight):Bool {
        return (box == null ? other.box == null : box.equals(other.box))
            && fontSizeAbsolute == other.fontSizeAbsolute && fontSizeRelative == other.fontSizeRelative
            && letterSpacingPx == other.letterSpacingPx && letterSpacingEm == other.letterSpacingEm
            && baselineShiftPx == other.baselineShiftPx && baselineShiftEm == other.baselineShiftEm
            && lineHeightPx == other.lineHeightPx && lineHeightRelative == other.lineHeightRelative
            && textTransform == other.textTransform && opacity == other.opacity
            && (transformation == null ? other.transformation == null : transformation.equals(other.transformation))
            // The descriptor itself is left out, see `animation`.
            && (animation == null) == (other.animation == null)
            && (animation == null || animation.isPerCharacter() == other.animation.isPerCharacter());
    }

    /** The letter spacing of the span in pixels, for a font size of `emSize`. */
    @:allow(glaze.kit.base.text)
    function letterSpacingFor(emSize:Float):Float {
        if (letterSpacingPx != null) return letterSpacingPx;
        if (letterSpacingEm != null) return taffy.util.F32.fround(letterSpacingEm * emSize);
        return 0.;
    }

    public function new(?style:HighlightStyle, ?fontFamily:String, ?fontSizeScale:Float, ?codeStyle:StyleRefinement) {
        this.style = style != null ? style : new HighlightStyle();
        this.fontFamily = fontFamily;
        this.fontSizeScale = fontSizeScale;
        this.codeStyle = codeStyle;
    }

    /** `From<HighlightStyle>`. */
    public static inline function fromStyle(style:HighlightStyle):InlineHighlight {
        return new InlineHighlight(style);
    }

    public function clone():InlineHighlight {
        return copyRich(new InlineHighlight(copyStyle(style), fontFamily, fontSizeScale, codeStyle != null ? codeStyle.clone() : null));
    }

    static function copyStyle(s:HighlightStyle):HighlightStyle {
        return new HighlightStyle(s.color, s.fontWeight, s.fontStyle, s.backgroundColor, s.underline != null ? s.underline.clone() : null,
            s.strikethrough != null ? s.strikethrough.clone() : null, s.fadeOut);
    }

    public function equals(other:Null<InlineHighlight>):Bool {
        return other != null && style.equals(other.style) && fontFamily == other.fontFamily && fontSizeScale == other.fontSizeScale
            && (codeStyle == null ? other.codeStyle == null : codeStyle.equals(other.codeStyle)) && sameRich(other);
    }

    @:allow(glaze.kit.base.text)
    function fontSize(body:Pixels, remSize:Pixels):Pixels {
        if (fontSizeAbsolute != null) {
            return fontSizeAbsolute;
        }
        if (fontSizeRelative != null) {
            return body * fontSizeRelative;
        }
        if (codeStyle != null && codeStyle.text != null && codeStyle.text.fontSize != null) {
            final size:Float = codeStyle.text.fontSize.toPixels(remSize);
            if (Math.isFinite(size) && size > 0)
                return size;
        }
        return body * (fontSizeScale != null ? fontSizeScale : 1.);
    }

    /** Insets used by shaping, wrapping, painting, and table measurement alike. */
    @:allow(glaze.kit.base.text)
    function codeInsets(fontSize:Pixels, remSize:Pixels):Edges {
        if (fontSizeScale == null) {
            return box != null ? boxInsets(fontSize, remSize) : new Edges();
        }
        var top:Float = 0;
        var bottom:Float = 0;
        var left:Float = InlineFlow.INLINE_CODE_PADDING;
        var right:Float = InlineFlow.INLINE_CODE_PADDING;
        final style = codeStyle;
        if (style != null) {
            inline function inset(current:Float, padding:Null<glaze.DefiniteLength>, border:Null<glaze.AbsoluteLength>):Float {
                if (padding != null) {
                    current = Math.max(padding.toPixels(glaze.AbsoluteLength.Pixels(fontSize), remSize), 0);
                }
                if (border != null) {
                    current += Math.max(border.toPixels(remSize), 0);
                }
                return current;
            }
            top = inset(top, style.paddingTop, style.borderWidthTop);
            right = inset(right, style.paddingRight, style.borderWidthRight);
            bottom = inset(bottom, style.paddingBottom, style.borderWidthBottom);
            left = inset(left, style.paddingLeft, style.borderWidthLeft);
        }
        return new Edges(top, right, bottom, left);
    }

    /** The insets of a generic `box`: padding, border and horizontal margin on each side. */
    function boxInsets(fontSize:Pixels, remSize:Pixels):Edges {
        final style = box;
        inline function inset(padding:Null<glaze.DefiniteLength>, border:Null<glaze.AbsoluteLength>):Float {
            var value:Float = 0;
            if (padding != null) value = Math.max(padding.toPixels(glaze.AbsoluteLength.Pixels(fontSize), remSize), 0);
            if (border != null) value += Math.max(border.toPixels(remSize), 0);
            return value;
        }
        final margins = boxMargins(fontSize, remSize);
        return new Edges(inset(style.paddingTop, style.borderWidthTop), inset(style.paddingRight, style.borderWidthRight) + margins.right,
            inset(style.paddingBottom, style.borderWidthBottom), inset(style.paddingLeft, style.borderWidthLeft) + margins.left);
    }

    /** The horizontal margins of a generic `box` (top and bottom are zero). */
    @:allow(glaze.kit.base.text)
    function boxMargins(fontSize:Pixels, remSize:Pixels):Edges {
        final style = box;
        if (style == null) return new Edges();
        inline function margin(length:Null<glaze.Length>):Float {
            return switch length {
                case null: 0.;
                case Definite(definite): Math.max(definite.toPixels(glaze.AbsoluteLength.Pixels(fontSize), remSize), 0);
                case _: 0.;
            }
        }
        return new Edges(0, margin(style.marginRight), 0, margin(style.marginLeft));
    }

    /** Layers `other` over this one, the way `HighlightStyle.highlight` does. */
    @:allow(glaze.kit.base.text)
    function highlight(other:InlineHighlight):InlineHighlight {
        final result = new InlineHighlight(style.highlight(other.style), fontFamily, fontSizeScale, codeStyle);
        if (other.fontFamily != null) {
            result.fontFamily = other.fontFamily;
        }
        if (other.fontSizeScale != null) {
            result.fontSizeScale = other.fontSizeScale;
        }
        if (other.codeStyle != null) {
            result.codeStyle = other.codeStyle.clone();
        }
        copyRich(result);
        if (other.box != null) result.box = other.box.clone();
        if (other.fontSizeAbsolute != null) result.fontSizeAbsolute = other.fontSizeAbsolute;
        if (other.fontSizeRelative != null) result.fontSizeRelative = other.fontSizeRelative;
        if (other.letterSpacingPx != null) result.letterSpacingPx = other.letterSpacingPx;
        if (other.letterSpacingEm != null) result.letterSpacingEm = other.letterSpacingEm;
        if (other.baselineShiftPx != null) result.baselineShiftPx = other.baselineShiftPx;
        if (other.baselineShiftEm != null) result.baselineShiftEm = other.baselineShiftEm;
        if (other.lineHeightPx != null) result.lineHeightPx = other.lineHeightPx;
        if (other.lineHeightRelative != null) result.lineHeightRelative = other.lineHeightRelative;
        if (other.textTransform != null) result.textTransform = other.textTransform;
        if (other.opacity != null) result.opacity = other.opacity;
        if (other.transformation != null) result.transformation = other.transformation;
        if (other.animation != null) result.animation = other.animation;
        return result;
    }

    /**
     * Merges two highlight lists over one text into non-overlapping ranges,
     * cutting at every endpoint of every input range. Same sweep as
     * `gpui::combine_highlights`, for `InlineHighlight` payloads.
     */
    public static function combineHighlights(a:Array<RangedHighlight>, b:Array<RangedHighlight>):Array<RangedHighlight> {
        final positions:Array<Int> = [];
        final ids:Array<Int> = [];
        final starts:Array<Bool> = [];
        final highlights:Array<InlineHighlight> = [];
        for (list in [a, b]) {
            for (item in list) {
                if (!item.range.isEmpty()) {
                    final id = highlights.length;
                    positions.push(item.range.start);
                    ids.push(id);
                    starts.push(true);
                    positions.push(item.range.end);
                    ids.push(id);
                    starts.push(false);
                    highlights.push(item.highlight);
                }
            }
        }
        // `sort_unstable_by_key(position)`: the order of equal positions does
        // not change the result, since ranges between them are empty.
        final order = [for (i in 0...positions.length) i];
        order.sort((x, y) -> {
            final d = positions[x] - positions[y];
            d != 0 ? d : x - y;
        });

        final combined:Array<RangedHighlight> = [];
        final active:Array<Int> = [];
        var ix = 0;
        for (i in order) {
            final position = positions[i];
            if (position > ix && active.length > 0) {
                var style = new InlineHighlight();
                for (id in active) {
                    style = style.highlight(highlights[id]);
                }
                combined.push(new RangedHighlight(new Range(ix, position), style));
            }
            ix = position;
            if (starts[i]) {
                active.push(ids[i]);
            } else {
                final id = ids[i];
                var k = 0;
                while (k < active.length) {
                    if (active[k] == id)
                        active.splice(k, 1);
                    else
                        k++;
                }
            }
        }
        return combined;
    }

    /**
     * Layers a streamed fade-in over `highlights`: text inside each fade
     * range loses that share of its color, and a highlight background or
     * decoration color fades with it so an inline code chip or a link
     * underline does not appear before its text.
     */
    public static function fadeHighlights(highlights:Array<RangedHighlight>, fades:Array<RangedFade>):Array<RangedHighlight> {
        if (fades.length == 0) {
            return highlights;
        }
        final fadeHighlights = [
            for (fade in fades)
                new RangedHighlight(fade.range, new InlineHighlight(new HighlightStyle(null, null, null, null, null, null, fade.fadeOut)))
        ];
        final combined = combineHighlights(highlights, fadeHighlights);
        // GPUI fades only the glyph color, so explicit decoration colors fade
        // here too, or a link underline would show before its text does.
        for (item in combined) {
            final highlight = item.highlight;
            final fadeOut = highlight.style.fadeOut;
            if (fadeOut == null)
                continue;
            final code = highlight.codeStyle;
            if (code != null) {
                if (code.background != null) {
                    code.background = code.background.opacity(1. - fadeOut);
                }
                if (code.borderColor != null) {
                    code.borderColor = code.borderColor.fadeOut(fadeOut);
                }
            }
            final style = highlight.style;
            if (style.backgroundColor != null)
                style.backgroundColor = style.backgroundColor.fadeOut(fadeOut);
            if (style.underline != null && style.underline.color != null) {
                style.underline = style.underline.clone();
                style.underline.color = style.underline.color.fadeOut(fadeOut);
            }
            if (style.strikethrough != null && style.strikethrough.color != null) {
                style.strikethrough = style.strikethrough.clone();
                style.strikethrough.color = style.strikethrough.color.fadeOut(fadeOut);
            }
        }
        return combined;
    }

    /**
     * Builds the `TextRun`s for `textLen` bytes of inline text: each
     * highlight refines `defaultStyle` over its range, and a highlight that
     * names a font family shapes its run in that family.
     */
    public static function textRuns(textLen:Int, defaultStyle:TextStyle, highlights:Array<RangedHighlight>, ?emSize:Float):Array<TextRun> {
        final runs:Array<TextRun> = [];
        var ix = 0;
        for (item in highlights) {
            final range = item.range;
            final highlight = item.highlight;
            if (ix < range.start) {
                runs.push(defaultStyle.clone().toRun(range.start - ix));
            }
            final style = defaultStyle.clone().highlight(highlight.style);
            final code = highlight.codeStyle;
            if (code != null) {
                // Font size is handled by the shaped fragment, not by a TextRun.
                if (code.text != null && code.text.fontFeatures != null)
                    style.fontFeatures = code.text.fontFeatures;
                if (code.text != null && code.text.fontFallbacks != null)
                    style.fontFallbacks = code.text.fontFallbacks;
            }
            var run = style.toRun(range.len());
            if (highlight.fontFamily != null) {
                run.font = run.font.clone();
                run.font.family = highlight.fontFamily;
            }
            // Rich text additions; a highlight without them leaves the run as it is.
            if (highlight.letterSpacingPx != null || highlight.letterSpacingEm != null) {
                // `emSize` is the size the run is shaped at; without it, the size of the style.
                final em:Float = emSize != null ? emSize : defaultStyle.fontSize.toPixels(16.);
                run = run.withLetterSpacing(highlight.letterSpacingFor(em));
            }
            if (highlight.opacity != null) {
                final opacity = highlight.opacity;
                run.color = run.color.opacity(opacity);
                if (run.backgroundColor != null) run.backgroundColor = run.backgroundColor.opacity(opacity);
                if (run.underline != null && run.underline.color != null) {
                    run.underline = run.underline.clone();
                    run.underline.color = run.underline.color.opacity(opacity);
                }
                if (run.strikethrough != null && run.strikethrough.color != null) {
                    run.strikethrough = run.strikethrough.clone();
                    run.strikethrough.color = run.strikethrough.color.opacity(opacity);
                }
            }
            runs.push(run);
            ix = range.end;
        }
        if (ix < textLen) {
            runs.push(defaultStyle.toRun(textLen - ix));
        }
        return runs;
    }

    /** The insets of the first inline code highlight (Rust free `code_insets`). */
    public static function codeInsetsOf(highlights:Array<RangedHighlight>, fontSize:Pixels, remSize:Pixels):Edges {
        for (item in highlights) {
            if (item.highlight.fontSizeScale != null || item.highlight.box != null)
                return item.highlight.codeInsets(fontSize, remSize);
        }
        return new Edges();
    }

    /**
     * Splits text into contiguous ranges sharing one font size. GPUI runs
     * can vary the font but not its size, so each range needs its own shaped
     * line. Returns `(range, scale)` pairs as `RangedFade` (the float is the
     * scale here).
     */
    public static function textSizeRanges(textLen:Int, highlights:Array<RangedHighlight>, fontSize:Pixels, remSize:Pixels):Array<RangedFade> {
        final ranges:Array<Range> = [];
        final scales:Array<Float> = [];
        final codes:Array<Bool> = [];
        // A boxed, transformed or animated span is a fragment of its own:
        // `groups` holds its position in `highlights`, -1 for the others.
        final groups:Array<Int> = [];
        var group = -1;
        function push(range:Range, scale:Float, code:Bool) {
            if (range.isEmpty())
                return;
            final last = ranges.length - 1;
            groups.push(group);
            if (last >= 0 && scales[last] == scale && codes[last] == code && ranges[last].end == range.start && groups[groups.length - 2] == group) {
                groups.pop();
                ranges[last] = new Range(ranges[last].start, range.end);
            } else {
                ranges.push(range);
                scales.push(scale);
                codes.push(code);
            }
        }
        var cursor = 0;
        for (ix in 0...highlights.length) {
            final item = highlights[ix];
            push(new Range(cursor, item.range.start), 1., false);
            group = item.highlight.isRich() ? ix : -1;
            push(item.range, taffy.util.F32.fround(item.highlight.fontSize(fontSize, remSize) / fontSize), item.highlight.fontSizeScale != null);
            group = -1;
            cursor = item.range.end;
        }
        push(new Range(cursor, textLen), 1., false);
        return [for (i in 0...ranges.length) new RangedFade(ranges[i], scales[i])];
    }

}

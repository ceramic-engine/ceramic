// Ported from gpui-kit 0.8.1: crates/base/src/text/inline.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
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
        return new InlineHighlight(copyStyle(style), fontFamily, fontSizeScale, codeStyle != null ? codeStyle.clone() : null);
    }

    static function copyStyle(s:HighlightStyle):HighlightStyle {
        return new HighlightStyle(s.color, s.fontWeight, s.fontStyle, s.backgroundColor, s.underline != null ? s.underline.clone() : null,
            s.strikethrough != null ? s.strikethrough.clone() : null, s.fadeOut);
    }

    public function equals(other:Null<InlineHighlight>):Bool {
        return other != null && style.equals(other.style) && fontFamily == other.fontFamily && fontSizeScale == other.fontSizeScale
            && (codeStyle == null ? other.codeStyle == null : codeStyle.equals(other.codeStyle));
    }

    @:allow(glaze.kit.base.text)
    function fontSize(body:Pixels, remSize:Pixels):Pixels {
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
            return new Edges();
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
    public static function textRuns(textLen:Int, defaultStyle:TextStyle, highlights:Array<RangedHighlight>):Array<TextRun> {
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
            final run = style.toRun(range.len());
            if (highlight.fontFamily != null) {
                run.font = run.font.clone();
                run.font.family = highlight.fontFamily;
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
            if (item.highlight.fontSizeScale != null)
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
        function push(range:Range, scale:Float, code:Bool) {
            if (range.isEmpty())
                return;
            final last = ranges.length - 1;
            if (last >= 0 && scales[last] == scale && codes[last] == code && ranges[last].end == range.start) {
                ranges[last] = new Range(ranges[last].start, range.end);
            } else {
                ranges.push(range);
                scales.push(scale);
                codes.push(code);
            }
        }
        var cursor = 0;
        for (item in highlights) {
            push(new Range(cursor, item.range.start), 1., false);
            push(item.range, taffy.util.F32.fround(item.highlight.fontSize(fontSize, remSize) / fontSize), item.highlight.fontSizeScale != null);
            cursor = item.range.end;
        }
        push(new Range(cursor, textLen), 1., false);
        return [for (i in 0...ranges.length) new RangedFade(ranges[i], scales[i])];
    }

}

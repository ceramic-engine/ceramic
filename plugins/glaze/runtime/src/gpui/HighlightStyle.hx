// Ported from gpui-pre 0.3.10: src/style.rs (HighlightStyle, combine_highlights)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A highlight style to apply, similar to a `TextStyle` except
 * for a single font, uniformly sized and spaced text.
 *
 * Every field is optional (`null` when unset).
 */
@:structInit
class HighlightStyle {

    /** The color of the text */
    public var color:Null<Hsla> = null;

    /** The font weight, e.g. bold */
    public var fontWeight:Null<FontWeight> = null;

    /** The font style, e.g. italic */
    public var fontStyle:Null<FontStyle> = null;

    /** The background color of the text */
    public var backgroundColor:Null<Hsla> = null;

    /** The underline style of the text */
    public var underline:Null<UnderlineStyle> = null;

    /** The strikethrough style of the text */
    public var strikethrough:Null<StrikethroughStyle> = null;

    /** Similar to the CSS `opacity` property, this will cause the text to be less vibrant. */
    public var fadeOut:Null<Float> = null;

    public function new(?color:Hsla, ?fontWeight:FontWeight, ?fontStyle:FontStyle, ?backgroundColor:Hsla, ?underline:UnderlineStyle, ?strikethrough:StrikethroughStyle, ?fadeOut:Float) {
        this.color = color;
        this.fontWeight = fontWeight;
        this.fontStyle = fontStyle;
        this.backgroundColor = backgroundColor;
        this.underline = underline;
        this.strikethrough = strikethrough;
        this.fadeOut = fadeOut;
    }

    /** Create a highlight style with just a color (Rust `HighlightStyle::color`). */
    public static function ofColor(color:Hsla):HighlightStyle {
        return new HighlightStyle(color);
    }

    /** Create a highlight style with just a font weight. */
    public static function ofFontWeight(fontWeight:FontWeight):HighlightStyle {
        return new HighlightStyle(null, fontWeight);
    }

    /** Create a highlight style with just a font style. */
    public static function ofFontStyle(fontStyle:FontStyle):HighlightStyle {
        return new HighlightStyle(null, null, fontStyle);
    }

    /** `From<&TextStyle>` */
    public static function fromTextStyle(other:TextStyle):HighlightStyle {
        return new HighlightStyle(other.color, other.fontWeight, other.fontStyle, other.backgroundColor, other.underline, other.strikethrough);
    }

    /**
     * Blend this highlight style with another.
     * Non-continuous properties, like font_weight and font_style, are overwritten.
     */
    public function highlight(other:HighlightStyle):HighlightStyle {
        var resultColor = color;
        if (other.color != null) {
            resultColor = color != null ? color.blend(other.color) : other.color;
        }
        var resultFade = fadeOut;
        if (other.fadeOut != null) {
            resultFade = fadeOut != null ? gpui.util.MathUtil.clamp(fadeOut * (1.0 + other.fadeOut), 0.0, 1.0) : other.fadeOut;
        }
        return new HighlightStyle(
            resultColor,
            other.fontWeight != null ? other.fontWeight : fontWeight,
            other.fontStyle != null ? other.fontStyle : fontStyle,
            other.backgroundColor != null ? other.backgroundColor : backgroundColor,
            other.underline != null ? other.underline : underline,
            other.strikethrough != null ? other.strikethrough : strikethrough,
            resultFade
        );
    }

    public function equals(other:HighlightStyle):Bool {
        inline function eqHsla(a:Null<Hsla>, b:Null<Hsla>) return a == null ? b == null : a.equals(b);
        return other != null && eqHsla(color, other.color) && fontWeight == other.fontWeight && fontStyle == other.fontStyle
            && eqHsla(backgroundColor, other.backgroundColor)
            && (underline == null ? other.underline == null : underline.equals(other.underline))
            && (strikethrough == null ? other.strikethrough == null : strikethrough.equals(other.strikethrough))
            && fadeOut == other.fadeOut;
    }

    /**
     * Combine and merge the highlights and ranges in the two lists. Ranges
     * are UTF-8 byte ranges `[start, end)`.
     */
    public static function combineHighlights(a:Array<TextHighlight>, b:Array<TextHighlight>):Array<TextHighlight> {
        final endpoints:Array<{position:Int, id:Int, isStart:Bool}> = [];
        final highlights:Array<HighlightStyle> = [];
        for (list in [a, b]) {
            for (entry in list) {
                if (entry.end > entry.start) {
                    final id = highlights.length;
                    endpoints.push({position: entry.start, id: id, isStart: true});
                    endpoints.push({position: entry.end, id: id, isStart: false});
                    highlights.push(entry.style);
                }
            }
        }
        // Stable sort by position (Rust sorts unstably by position only, the
        // result does not depend on the order of equal endpoints)
        haxe.ds.ArraySort.sort(endpoints, (x, y) -> x.position - y.position);

        final result:Array<TextHighlight> = [];
        final active:Array<Int> = [];
        var ix = 0;
        for (endpoint in endpoints) {
            final prevIndex = ix;
            ix = endpoint.position;
            if (ix > prevIndex && active.length > 0) {
                var current = new HighlightStyle();
                final sorted = active.copy();
                sorted.sort((x, y) -> x - y);
                for (id in sorted) {
                    current = current.highlight(highlights[id]);
                }
                result.push(new TextHighlight(prevIndex, ix, current));
            }
            if (endpoint.isStart) {
                active.push(endpoint.id);
            }
            else {
                active.remove(endpoint.id);
            }
        }
        return result;
    }

}

/**
 * A highlight applied to a UTF-8 byte range `[start, end)` of a text
 * (Rust `(Range<usize>, HighlightStyle)`).
 */
class TextHighlight {

    public var start:Int;

    public var end:Int;

    public var style:HighlightStyle;

    public function new(start:Int, end:Int, style:HighlightStyle) {
        this.start = start;
        this.end = end;
        this.style = style;
    }

}

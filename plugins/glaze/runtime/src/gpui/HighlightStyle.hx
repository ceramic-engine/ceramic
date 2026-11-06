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
        // Typed endpoints (anonymous structures are read by field name and
        // box their numbers on hxcpp)
        final endpoints:Array<HighlightEndpoint> = [];
        final highlights:Array<HighlightStyle> = [];
        for (l in 0...2) {
            final list = l == 0 ? a : b;
            for (entry in list) {
                if (entry.end > entry.start) {
                    final id = highlights.length;
                    endpoints.push(new HighlightEndpoint(entry.start, id, true));
                    endpoints.push(new HighlightEndpoint(entry.end, id, false));
                    highlights.push(entry.style);
                }
            }
        }
        // Stable sort by position (Rust sorts unstably by position only, the
        // result does not depend on the order of equal endpoints)
        HighlightEndpoint.sortByPosition(endpoints);

        final result:Array<TextHighlight> = [];
        final active:Array<Int> = [];
        // The active ids in ascending order, one array for the whole call
        final sorted:Array<Int> = [];
        var ix = 0;
        for (endpoint in endpoints) {
            final prevIndex = ix;
            ix = endpoint.position;
            if (ix > prevIndex && active.length > 0) {
                var current = new HighlightStyle();
                // `active.copy()` sorted, by insertion (no comparator closure,
                // the ids are distinct and few)
                sorted.resize(0);
                for (i in 0...active.length) {
                    final id = active[i];
                    var j = sorted.length;
                    sorted.push(id);
                    while (j > 0 && sorted[j - 1] > id) {
                        sorted[j] = sorted[j - 1];
                        j--;
                    }
                    sorted[j] = id;
                }
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

/** An endpoint of `HighlightStyle.combineHighlights` */
private class HighlightEndpoint {

    public final position:Int;

    public final id:Int;

    public final isStart:Bool;

    public inline function new(position:Int, id:Int, isStart:Bool) {
        this.position = position;
        this.id = id;
        this.isStart = isStart;
    }

    /**
     * Stable sort by position (the order of `haxe.ds.ArraySort.sort` with
     * `x.position - y.position`), typed: a merge sort without a function value
     */
    public static function sortByPosition(items:Array<HighlightEndpoint>):Void {
        final count = items.length;
        if (count < 2)
            return;
        var source = items;
        var target:Array<HighlightEndpoint> = [];
        target.resize(count);
        var width = 1;
        while (width < count) {
            var start = 0;
            while (start < count) {
                final mid = start + width < count ? start + width : count;
                final end = start + 2 * width < count ? start + 2 * width : count;
                var i = start;
                var j = mid;
                var k = start;
                while (i < mid && j < end) {
                    // Ties take the left run first (stable)
                    if (source[j].position < source[i].position) {
                        target[k++] = source[j++];
                    }
                    else {
                        target[k++] = source[i++];
                    }
                }
                while (i < mid)
                    target[k++] = source[i++];
                while (j < end)
                    target[k++] = source[j++];
                start = end;
            }
            final swap = source;
            source = target;
            target = swap;
            width *= 2;
        }
        if (source != items) {
            for (n in 0...count)
                items[n] = source[n];
        }
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

// Ported from gpui-kit 0.8.1: crates/base/src/plot/label.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot;

import glaze.App;
import glaze.Bounds;
import glaze.FontWeight;
import glaze.Hsla;
import glaze.Pixels;
import glaze.Point;
import glaze.ShapedLine;
import glaze.SpringMath;
import glaze.TextAlign;
import glaze.TextRun;
import glaze.Window;
import glaze.util.Utf8;

/**
 * Labels a plot draws (Rust `PlotLabel` and the free functions and
 * constants of `plot::label`).
 */
class PlotLabel {

    /**
     * The default label font size, in pixels, of `Text` and `AxisText`.
     */
    public static inline final TEXT_SIZE:Float = 10.;

    /** The default gap, in pixels, between a label and what it labels. */
    public static inline final TEXT_GAP:Float = 2.;

    /** The default height, in pixels, a label line takes: `TEXT_SIZE` plus `TEXT_GAP`. */
    public static inline final TEXT_HEIGHT:Float = TEXT_SIZE + TEXT_GAP;

    final items:Array<Text>;

    public function new(?items:Array<Text>) {
        this.items = items != null ? items : [];
    }

    /** Paint the Label. */
    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        for (item in items) {
            final origin = Plot.originPoint(item.origin.x, item.origin.y, bounds.origin);
            final line = shapeLabel(item.text, item.fontSize, item.color, window);
            final width:Float = line.width();
            final aligned = switch item.align {
                case Left: origin;
                case Right: new Point(f(origin.x - width), origin.y);
                case _: new Point(f(origin.x - f(width / 2.)), origin.y);
            };
            line.paint(aligned, item.fontSize, item.align, null, window.textPainter());
        }
    }

    static function shapeLabel(text:String, fontSize:Pixels, color:Hsla, window:Window):ShapedLine {
        final run = new TextRun(Utf8.byteLength(text), window.textStyle().font(), color, null, null, null);
        return window.textSystem().shapeLine(text, fontSize, [run]);
    }

    /**
     * Returns the rendered width of `text` at `fontSize` using the window's
     * current text style. Used for layout calculations that need to reserve
     * space for labels before the scale ranges are fixed.
     */
    public static function measureTextWidth(text:String, fontSize:Pixels, window:Window):Float {
        if (text.length == 0) {
            return 0.;
        }
        return shapeLabel(text, fontSize, new Hsla(0., 0., 0., 1.), window).width();
    }

    /**
     * Truncate `text` with a trailing ellipsis so it fits within `maxWidth`
     * at `fontSize`. Returns `text` unchanged when it already fits; returns
     * just the ellipsis when not even one character fits. `maxWidth <= 0` is
     * treated as "no budget" and returns `text` unchanged.
     */
    public static function truncateTextToWidth(text:String, fontSize:Pixels, maxWidth:Float, window:Window):String {
        if (maxWidth <= 0. || measureTextWidth(text, fontSize, window) <= maxWidth) {
            return text;
        }

        final ELLIPSIS = '…';
        // Byte offsets of every char boundary after the first char; cutting
        // at `cuts[k]` keeps the first `k + 1` chars.
        final codePoints:Array<Int> = [];
        final byteOffsets:Array<Int> = [];
        final count = Utf8.decode(text, codePoints, byteOffsets);
        final cuts = [for (i in 1...count) byteOffsets[i]];

        // Binary search the largest prefix whose text + ellipsis still fits.
        var best:Null<Int> = null;
        var lo = 0;
        var hi = cuts.length;
        while (lo < hi) {
            final mid = Std.int((lo + hi) / 2);
            final candidate = Utf8.substring(text, 0, cuts[mid]) + ELLIPSIS;
            if (measureTextWidth(candidate, fontSize, window) <= maxWidth) {
                best = mid;
                lo = mid + 1;
            }
            else {
                hi = mid;
            }
        }

        return best != null ? Utf8.substring(text, 0, cuts[best]) + ELLIPSIS : ELLIPSIS;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

/**
 * A label `PlotLabel` draws: its text, where it sits relative to the plot
 * origin and how it is drawn (Rust `plot::label::Text`). `fontSize`
 * defaults to `TEXT_SIZE`. The font weight is recorded but, like the
 * original, not used when painting.
 */
class Text {

    public final text:String;

    public final origin:Point;

    public final color:Hsla;

    public var fontSize:Pixels = PlotLabel.TEXT_SIZE;

    public var fontWeight:FontWeight = FontWeight.NORMAL;

    public var align:TextAlign = Left;

    public function new(text:String, origin:Point, color:Hsla) {
        this.text = text;
        this.origin = new Point(SpringMath.f32(origin.x), SpringMath.f32(origin.y));
        this.color = color;
    }

    /** Set the font size of the Text. */
    public function withFontSize(fontSize:Pixels):Text {
        this.fontSize = fontSize;
        return this;
    }

    /** Set the font weight of the Text. */
    public function withFontWeight(fontWeight:FontWeight):Text {
        this.fontWeight = fontWeight;
        return this;
    }

    /** Set the alignment of the Text. */
    public function withAlign(align:TextAlign):Text {
        this.align = align;
        return this;
    }

}

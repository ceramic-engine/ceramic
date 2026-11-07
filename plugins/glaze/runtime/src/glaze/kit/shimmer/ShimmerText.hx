// Ported from gpui-kit 0.8.1: crates/component/src/shimmer.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.shimmer;

import glaze.Animation;
import glaze.App;
import glaze.Bounds;
import glaze.ContentMask;
import glaze.Element;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.GlobalElementId;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.LayoutId;
import glaze.LineLayout;
import glaze.Pixels;
import glaze.Point;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.StyledText;
import glaze.TextAlign;
import glaze.WrapBoundary;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.AnimationExt;
using glaze.kit.base.StyledExt;
using glaze.kit.theme.Colorize;

/**
 * The half width of a shimmer band: a fraction of the text width, or pixels.
 */
enum ShimmerSpread {
    Relative(fraction:Float);
    Absolute(length:Pixels);
}

/**
 * How a shimmer moves: duration (seconds), highlight color, band spread,
 * direction and repetition.
 */
class ShimmerStyle {

    static inline final DEFAULT_SHIMMER_SPREAD:Float = 0.3;

    public var durationValue(default, null):Float = 2.;

    public var highlightColorValue(default, null):Null<Hsla> = null;

    public var spreadValue(default, null):ShimmerSpread = Relative(DEFAULT_SHIMMER_SPREAD);

    public var reverseValue(default, null):Bool = false;

    public var onceValue(default, null):Bool = false;

    public function new() {}

    function copy():ShimmerStyle {
        final style = new ShimmerStyle();
        style.durationValue = durationValue;
        style.highlightColorValue = highlightColorValue;
        style.spreadValue = spreadValue;
        style.reverseValue = reverseValue;
        style.onceValue = onceValue;
        return style;
    }

    /** Duration of a sweep, at least 1ms. */
    public function duration(duration:Float):ShimmerStyle {
        final style = copy();
        style.durationValue = Math.max(duration, 0.001);
        return style;
    }

    public function highlightColor(color:IntoHsla):ShimmerStyle {
        final style = copy();
        style.highlightColorValue = color;
        return style;
    }

    /**
     * Band half width: a relative fraction is clamped to 0.05..1, a length
     * is at least 1px; non finite values are ignored.
     */
    public function spread(spread:ShimmerSpread):ShimmerStyle {
        final style = copy();
        switch spread {
            case Relative(fraction) if (Math.isFinite(fraction)):
                style.spreadValue = Relative(fraction < 0.05 ? 0.05 : (fraction > 1. ? 1. : fraction));
            case Absolute(length) if (Math.isFinite(length)):
                style.spreadValue = Absolute(Math.max(length, 1.));
            case _:
        }
        return style;
    }

    public function reverse(reverse:Bool):ShimmerStyle {
        final style = copy();
        style.reverseValue = reverse;
        return style;
    }

    public function once(once:Bool):ShimmerStyle {
        final style = copy();
        style.onceValue = once;
        return style;
    }

    @:allow(glaze.kit)
    function animation():Animation {
        return ShimmerText.loadingAnimation(durationValue, onceValue);
    }

}

/**
 * Text with a highlight band sweeping across its glyphs (plain text under
 * reduced motion).
 */
class ShimmerText implements RenderOnce implements Styled {

    public static inline final SHIMMER_LAYER_COUNT:Int = 12;

    static inline final MIN_HIGHLIGHT_LIGHTNESS_GAP:Float = 0.1;

    @:allow(tests)
    final text:String;

    @:allow(tests)
    final shimmerTextStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var shimmerStyle:ShimmerStyle = new ShimmerStyle();

    @:allow(tests)
    var idValue:Null<ElementId> = null;

    public function new(text:String) {
        this.text = text;
    }

    public function id(id:ElementIdArg):ShimmerText {
        idValue = id;
        return this;
    }

    public function withShimmerStyle(style:ShimmerStyle):ShimmerText {
        shimmerStyle = style;
        return this;
    }

    public function duration(duration:Float):ShimmerText {
        shimmerStyle = shimmerStyle.duration(duration);
        return this;
    }

    public function highlightColor(color:IntoHsla):ShimmerText {
        shimmerStyle = shimmerStyle.highlightColor(color);
        return this;
    }

    public function spread(spread:ShimmerSpread):ShimmerText {
        shimmerStyle = shimmerStyle.spread(spread);
        return this;
    }

    public function reverse(reverse:Bool):ShimmerText {
        shimmerStyle = shimmerStyle.reverse(reverse);
        return this;
    }

    public function once(once:Bool):ShimmerText {
        shimmerStyle = shimmerStyle.once(once);
        return this;
    }

    public inline function style():StyleRefinement {
        return shimmerTextStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final id:ElementId = idValue != null ? idValue : ElementId.Name(text);
        final container = div().minW0().refineStyle(shimmerTextStyle);

        if (cx.reduceMotion()) {
            return container.child(new StyledText(text));
        }

        final tokens = Theme.global(cx).semanticTokens();
        final reverse = shimmerStyle.reverseValue;
        final glyphs = new ShimmerGlyphs(new StyledText(text), shimmerStyle.highlightColorValue, tokens.colors.background, tokens.colors.foreground,
            Theme.global(cx).isDark(), shimmerStyle.spreadValue);
        return container.child(glyphs.withAnimation(id, shimmerStyle.animation(), (glyphs, phase) -> {
            glyphs.phase = reverse ? 1. - phase : phase;
            return glyphs;
        }));
    }

    public static function loadingAnimation(duration:Float, once:Bool):Animation {
        return once ? new Animation(duration) : new Animation(duration).repeatSynced();
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    @:allow(glaze.kit.shimmer, tests)
    static function shimmerHighlightColor(text:Hsla, background:Hsla, foreground:Hsla, dark:Bool, overrideColor:Null<Hsla>):Hsla {
        var highlight = overrideColor;
        if (highlight == null) {
            var target = dark ? foreground : background;
            final opposite = dark ? background : foreground;
            if (Math.abs(target.l - text.l) < MIN_HIGHLIGHT_LIGHTNESS_GAP) {
                target = opposite;
            }
            highlight = text.mixOklab(target, 0.2);
        }
        final peakOpacity = dark ? f32(0.6) : f32(0.75);
        final layerOpacity = f32(1. - Math.pow(f32(1. - peakOpacity), f32(1. / SHIMMER_LAYER_COUNT)));
        return highlight.opacity(layerOpacity);
    }

    @:allow(glaze.kit.shimmer, tests)
    static function shimmerBandBounds(bounds:Bounds, phase:Float, spread:ShimmerSpread, layer:Int):Null<Bounds> {
        final width = bounds.size.width;
        if (width <= 0. || bounds.size.height <= 0. || layer >= SHIMMER_LAYER_COUNT) {
            return null;
        }
        final halfWidth = switch spread {
            case Relative(fraction): f32(width * fraction);
            case Absolute(length): length;
        };
        final padding = f32(f32(halfWidth / width) + 0.05);
        final center = f32(f32(phase * f32(1. + f32(padding * 2.)) - padding) * width);
        final radius = f32(halfWidth * f32(1. - f32(layer / SHIMMER_LAYER_COUNT)));
        final left = Math.max(f32(center - radius), 0.);
        final right = Math.min(f32(center + radius), width);
        return right > left ? new Bounds(new Point(bounds.origin.x + left, bounds.origin.y), new glaze.Size(f32(right - left), bounds.size.height)) : null;
    }

    @:allow(glaze.kit.shimmer)
    static function shimmerAlignedOriginX(origin:Point, alignWidth:Float, previousGlyphX:Float, align:TextAlign, layout:LineLayout, nextWrap:Null<WrapBoundary>):Float {
        final lineEnd = nextWrap != null ? layout.runs[nextWrap.runIx].glyphs[nextWrap.glyphIx].position.x : layout.width;
        final lineWidth = lineEnd - previousGlyphX;
        return switch align {
            case Left: origin.x;
            case Center: (origin.x * 2. + alignWidth - lineWidth) / 2.;
            case Right: origin.x + alignWidth - lineWidth;
        }
    }

}

/**
 * The text element painting the highlight layers over its glyphs.
 */
class ShimmerGlyphs extends Element {

    final text:StyledText;

    final highlightColor:Null<Hsla>;

    final background:Hsla;

    final foreground:Hsla;

    final dark:Bool;

    final spread:ShimmerSpread;

    public var phase:Float = 0.;

    public function new(text:StyledText, highlightColor:Null<Hsla>, background:Hsla, foreground:Hsla, dark:Bool, spread:ShimmerSpread) {
        this.text = text;
        this.highlightColor = highlightColor;
        this.background = background;
        this.foreground = foreground;
        this.dark = dark;
        this.spread = spread;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return text.requestLayout(id, window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        text.prepaint(id, bounds, window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        text.paint(id, bounds, window, cx);
        paintHighlight(bounds, window, cx);
    }

    function paintHighlight(bounds:Bounds, window:Window, cx:App):Void {
        final masks:Array<ContentMask> = [];
        for (layer in 0...ShimmerText.SHIMMER_LAYER_COUNT) {
            final band = ShimmerText.shimmerBandBounds(bounds, phase, spread, layer);
            if (band != null) masks.push(new ContentMask(band));
        }
        if (masks.length == 0)
            return;

        final textStyle = window.textStyle();
        final color = ShimmerText.shimmerHighlightColor(textStyle.color, background, foreground, dark, highlightColor);
        final layout = text.layout();
        final lineHeight = layout.lineHeight();
        final textAlign = textStyle.textAlign;
        var lineOriginY = bounds.origin.y;

        window.paintLayer(bounds, window -> {
            for (wrappedLine in layout.lineLayouts()) {
                final line = wrappedLine.unwrappedLayout;
                final baselineY = (lineHeight - line.ascent - line.descent) / 2. + line.ascent;
                final wraps = wrappedLine.wrapBoundaries;
                var wrapIx = 0;
                final lineOrigin = new Point(bounds.origin.x, lineOriginY);
                var glyphX = ShimmerText.shimmerAlignedOriginX(lineOrigin, bounds.size.width, 0., textAlign, line, wraps.length > 0 ? wraps[0] : null);
                var glyphY = lineOriginY;
                var previousX = 0.;

                for (runIndex in 0...line.runs.length) {
                    final run = line.runs[runIndex];
                    final glyphSize = cx.textSystem().boundingBox(run.fontId, line.fontSize).size;
                    for (glyphIndex in 0...run.glyphs.length) {
                        final glyph = run.glyphs[glyphIndex];
                        glyphX += glyph.position.x - previousX;
                        if (wrapIx < wraps.length && wraps[wrapIx].runIx == runIndex && wraps[wrapIx].glyphIx == glyphIndex) {
                            wrapIx++;
                            glyphX = ShimmerText.shimmerAlignedOriginX(lineOrigin, bounds.size.width, glyph.position.x, textAlign, line,
                                wrapIx < wraps.length ? wraps[wrapIx] : null);
                            glyphY += lineHeight;
                        }
                        previousX = glyph.position.x;
                        if (glyph.isEmoji)
                            continue;

                        final glyphBounds = new Bounds(new Point(glyphX, glyphY), glyphSize);
                        final paintOrigin = new Point(glyphX, glyphY + baselineY + glyph.position.y);
                        for (mask in masks) {
                            if (!glyphBounds.intersects(mask.bounds))
                                continue;
                            window.withContentMask(mask, window -> {
                                window.paintGlyph(paintOrigin, run.fontId, glyph.id, line.fontSize, color);
                                return null;
                            });
                        }
                    }
                }
                lineOriginY += wrappedLine.size(lineHeight).height;
            }
            return null;
        });
    }

}

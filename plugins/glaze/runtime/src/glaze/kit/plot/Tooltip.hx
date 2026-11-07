// Ported from gpui-kit 0.8.1: crates/component/src/plot/tooltip.rs, crates/component/src/plot/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.plot;

import glaze.AnyElement;
import glaze.App;
import glaze.Div;
import glaze.ElementId;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.Point;
import glaze.RenderOnce;
import glaze.Size;
import glaze.SpringMath;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.base.plot.PlotHover;
import glaze.kit.theme.Colorize;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.hFlex;
import glaze.kit.base.Prelude.vFlex;

using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * Which lines a `CrossLine` draws.
 */
enum abstract CrossLineAxis(Int) {

    /** The default. */
    var Vertical = 0;

    var Horizontal = 1;

    var Both = 2;

    /** Returns true if the cross line axis is vertical or both. */
    public inline function showVertical():Bool {
        final self:CrossLineAxis = cast this;
        return self == Vertical || self == Both;
    }

    /** Returns true if the cross line axis is horizontal or both. */
    public inline function showHorizontal():Bool {
        final self:CrossLineAxis = cast this;
        return self == Horizontal || self == Both;
    }

}

/**
 * The crosshair of a chart's tooltip: a dashed hairline (or a solid band)
 * through a point.
 */
class CrossLine implements RenderOnce {

    @:allow(glaze.kit.plot)
    var point:Point;

    /**
     * Span `(start, length)` of the vertical line along the y axis; a null
     * length spans the full height.
     */
    var verticalStart:Float = 0.;

    var verticalLength:Null<Float> = null;

    /**
     * Span `(start, length)` of the horizontal line along the x axis; a null
     * length spans the full width.
     */
    var horizontalStart:Float = 0.;

    var horizontalLength:Null<Float> = null;

    /** Band thickness perpendicular to the line (solid band mode only). */
    var thickness:Pixels = 1.;

    /** `true` (default) draws a dashed hairline; `false` a solid band of `thickness`. */
    var dashed:Bool = true;

    @:allow(glaze.kit.plot)
    var direction:CrossLineAxis = Vertical;

    public function new(point:Point) {
        this.point = point;
    }

    /**
     * Render a solid translucent highlight band of `thickness` (centered on
     * `point`) instead of the default dashed hairline.
     */
    public function band(thickness:Pixels):CrossLine {
        this.thickness = SpringMath.f32(thickness);
        dashed = false;
        return this;
    }

    /** Set the cross line axis to horizontal. */
    public function horizontal():CrossLine {
        direction = Horizontal;
        return this;
    }

    /** Set the cross line axis to both. */
    public function both():CrossLine {
        direction = Both;
        return this;
    }

    /** Set the vertical line's length along the y axis (from the top edge). */
    public function height(height:Float):CrossLine {
        verticalLength = SpringMath.f32(height);
        return this;
    }

    /** Set the horizontal line's length along the x axis (from the left edge). */
    public function width(width:Float):CrossLine {
        horizontalLength = SpringMath.f32(width);
        return this;
    }

    /**
     * Confine the vertical line to `[start, start + length]` along the y
     * axis, so it stays within the plot area.
     */
    public function span(start:Float, length:Float):CrossLine {
        verticalStart = SpringMath.f32(start);
        verticalLength = SpringMath.f32(length);
        return this;
    }

    /**
     * Confine the horizontal line to `[start, start + length]` along the x
     * axis, so it stays within the plot area.
     */
    public function hSpan(start:Float, length:Float):CrossLine {
        horizontalStart = SpringMath.f32(start);
        horizontalLength = SpringMath.f32(length);
        return this;
    }

    /**
     * Build a single line along one axis: `vertical` runs top to bottom at
     * the data point's `x`; otherwise left to right at its `y`.
     */
    function line(vertical:Bool, cx:App):Div {
        final theme = Theme.global(cx);
        final color = dashed ? Colorize.mix(theme.border, theme.foreground, 0.8) : theme.foreground.opacity(0.08);
        // The dashed hairline is a zero-width strip drawn entirely by its 1px border.
        final thickness:Float = dashed ? 0. : this.thickness;
        final start = vertical ? verticalStart : horizontalStart;
        final length = vertical ? verticalLength : horizontalLength;

        var el = div().absolute();
        if (vertical) {
            el = el.left(px(f(point.x - f(thickness * 0.5)))).w(px(thickness)).top(px(start));
            el = length != null ? el.h(px(length)) : el.hFull();
        }
        else {
            el = el.top(px(f(point.y - f(thickness * 0.5)))).h(px(thickness)).left(px(start));
            el = length != null ? el.w(px(length)) : el.wFull();
        }

        if (dashed) {
            el = vertical ? el.borderL1() : el.borderT1();
            return el.borderDashed().borderColor(color);
        }
        return el.bg(color);
    }

    public function render(window:Window, cx:App):IntoElement {
        final result = div().sizeFull().absolute().top0().left0();
        if (direction.showVertical()) {
            result.child(line(true, cx));
        }
        if (direction.showHorizontal()) {
            result.child(line(false, cx));
        }
        return result;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

/**
 * A dot marking a hovered data point, with an optional translucent halo.
 */
class Dot implements RenderOnce {

    @:allow(glaze.kit.plot)
    var point:Point;

    var sizeValue:Pixels = 6.;

    var strokeValue:Hsla = transparentBlack();

    var fillValue:Hsla = transparentBlack();

    /** Diameter of the translucent ring behind the dot; null draws no ring. */
    @:allow(glaze.kit.plot)
    var haloValue:Null<Float> = null;

    public function new(point:Point) {
        this.point = point;
    }

    /** Set the size of the dot. */
    public function size(size:Pixels):Dot {
        sizeValue = SpringMath.f32(size);
        return this;
    }

    /**
     * Draw a translucent ring of the fill color, `size` across, behind the
     * dot. In a `Tooltip` the ring grows out of the dot as the hover fades
     * in.
     */
    public function halo(size:Pixels):Dot {
        haloValue = SpringMath.f32(size);
        return this;
    }

    /** Set the stroke of the dot. */
    public function stroke(stroke:IntoHsla):Dot {
        strokeValue = stroke;
        return this;
    }

    /** Set the fill of the dot. */
    public function fill(fill:IntoHsla):Dot {
        fillValue = fill;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final borderWidth = 1.;
        final offset = f(f(sizeValue / 2.) - f(borderWidth / 2.));

        final dot = div()
            .absolute()
            .w(px(sizeValue))
            .h(px(sizeValue))
            .roundedFull()
            .border(px(borderWidth))
            .borderColor(strokeValue)
            .bg(fillValue)
            .left(px(f(point.x - offset)))
            .top(px(f(point.y - offset)));

        final result = div().absolute().top0().left0();
        // The ring paints first so it sits behind the dot, both centered on
        // the point.
        if (haloValue != null) {
            final halo:Float = haloValue;
            result.child(div()
                .absolute()
                .size(px(halo))
                .roundedFull()
                .bg(fillValue.opacity(0.2))
                .left(px(f(point.x - f(halo / 2.))))
                .top(px(f(point.y - f(halo / 2.)))));
        }
        return result.child(dot);
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

/**
 * A single labelled row in a `Tooltip`: an optional colored swatch, a muted
 * label, and a value.
 */
@:allow(glaze.kit)
@:allow(tests)
class TooltipRow {

    public final color:Null<Hsla>;

    public final label:String;

    public final value:String;

    public var valueColor:Null<Hsla> = null;

    public function new(color:Null<Hsla>, label:String, value:String) {
        this.color = color;
        this.label = label;
        this.value = value;
    }

}

/**
 * The hover overlay of a chart: a crosshair, dots, and a box that follows
 * the cursor with a title and rows (or freeform children).
 */
class Tooltip implements RenderOnce implements Styled implements ParentElement {

    /** The spring ids a tooltip glides its crosshair with, within the plot's scope. */
    static inline final GLIDE:String = '__plot-tooltip-glide';

    final base:Div;

    var gapValue:Pixels = 0.;

    var crossLineValue:Null<CrossLine> = null;

    var dotsValue:Null<Array<Dot>> = null;

    var appearanceValue:Bool = true;

    @:allow(glaze.kit)
    @:allow(tests)
    var titleValue:Null<String> = null;

    @:allow(glaze.kit)
    @:allow(tests)
    final rows:Array<TooltipRow> = [];

    /** Cursor position the box hugs (relative to the plot origin). */
    final cursor:Point;

    /**
     * Plot size, used to flip the box toward the center near each edge so
     * it never overflows the near side.
     */
    final within:Size;

    /** Opacity of the whole overlay when set; see `progress`. */
    var progressValue:Null<Float> = null;

    /** Whether the crosshair and dots glide between data; see `glide`. */
    var glideValue:Bool = true;

    /**
     * Create a tooltip whose box follows the cursor at `cursor` within a
     * `within`-sized plot.
     */
    public function new(cursor:Point, within:Size) {
        // The same row rhythm the structured content lays out with.
        base = vFlex().gapY1();
        this.cursor = cursor;
        this.within = within;
    }

    /**
     * Glide the crosshair and dots between data, or snap them to each
     * datum. Default is true.
     */
    public function glide(glide:Bool):Tooltip {
        glideValue = glide;
        return this;
    }

    /**
     * Fade the whole overlay (crosshair, dots and box) to `progress`
     * (`0..=1`), instead of following the plot's hover.
     */
    public function progress(progress:Float):Tooltip {
        progressValue = progress < 0. ? 0. : (progress > 1. ? 1. : progress);
        return this;
    }

    /** Set a bold title row shown at the top of the tooltip (e.g. the hovered x value). */
    public function title(title:String):Tooltip {
        titleValue = title;
        return this;
    }

    /** Append a series row: a colored swatch, a muted `label`, and a right-aligned `value`. */
    public function row(color:IntoHsla, label:String, value:String):Tooltip {
        rows.push(new TooltipRow(color, label, value));
        return this;
    }

    /**
     * Append a row without a swatch, for a figure no series on the plot
     * draws, such as a total or a ratio.
     */
    public function plainRow(label:String, value:String):Tooltip {
        rows.push(new TooltipRow(null, label, value));
        return this;
    }

    /**
     * Color the value of the row added last. Call it right after the row it
     * colors; before any row it does nothing.
     */
    public function valueColor(color:IntoHsla):Tooltip {
        if (rows.length > 0) {
            rows[rows.length - 1].valueColor = color;
        }
        return this;
    }

    /** Set the gap of the tooltip. */
    public function gap(gap:Pixels):Tooltip {
        gapValue = SpringMath.f32(gap);
        return this;
    }

    /** Set the cross line of the tooltip. */
    public function crossLine(crossLine:CrossLine):Tooltip {
        crossLineValue = crossLine;
        return this;
    }

    /** Set the dots of the tooltip. */
    public function dots(dots:Iterable<Dot>):Tooltip {
        dotsValue = glaze.util.Iterables.toArray(dots);
        return this;
    }

    /** Set the appearance of the tooltip. */
    public function appearance(appearance:Bool):Tooltip {
        appearanceValue = appearance;
        return this;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        base.extend(elements);
    }

    public function child(child:IntoElement):Tooltip {
        if (child != null) base.child(child);
        return this;
    }

    /**
     * Whether the rows keep a swatch slot: when any has a swatch, so a plain
     * row's label lines up with the series labels.
     */
    @:allow(tests)
    static function hasSwatches(rows:Array<TooltipRow>):Bool {
        for (row in rows) {
            if (row.color != null) return true;
        }
        return false;
    }

    public function render(window:Window, cx:App):IntoElement {
        // Rendered within the plot's element scope, so this is the fade the
        // plot tracked for it this frame; fully opaque outside a plot.
        final trackedProgress = PlotHover.hoverProgress(window, cx);
        final entering = PlotHover.isHoverEntering(window, cx);
        final progress:Float = progressValue != null ? progressValue : trackedProgress;
        final theme = Theme.global(cx);

        if (glideValue) {
            final policy = PlotHover.pointerSpring(cx).withTravel(!entering);
            if (crossLineValue != null) {
                final line = crossLineValue;
                if (line.direction.showVertical()) {
                    line.point = new Point(Motion.spring(TransitionId.named(GLIDE, 'x'), line.point.x, policy, window, cx), line.point.y);
                }
                if (line.direction.showHorizontal()) {
                    line.point = new Point(line.point.x, Motion.spring(TransitionId.named(GLIDE, 'y'), line.point.y, policy, window, cx));
                }
            }
            if (dotsValue != null) {
                for (i in 0...dotsValue.length) {
                    final dot = dotsValue[i];
                    dot.point = new Point(
                        Motion.spring(ElementId.NamedInteger('__plot-hover-dot-x', i), dot.point.x, policy, window, cx),
                        Motion.spring(ElementId.NamedInteger('__plot-hover-dot-y', i), dot.point.y, policy, window, cx)
                    );
                }
            }
        }
        // The ring grows out of the dot as the hover fades in.
        if (dotsValue != null) {
            for (dot in dotsValue) {
                if (dot.haloValue != null) {
                    dot.haloValue = SpringMath.f32(dot.haloValue * progress);
                }
            }
        }

        // Structured content (title + rows) takes precedence over freeform `base` children.
        var content:Div;
        if (titleValue != null || rows.length > 0) {
            final swatched = hasSwatches(rows);
            content = vFlex().gap1();
            if (titleValue != null) {
                content.child(div().fontSemibold().child(titleValue));
            }
            for (row in rows) {
                final label = hFlex().itemsCenter().gap1p5();
                if (swatched) {
                    final swatch = div().size2().rounded(glaze.Prelude.px(SpringMath.f32(theme.radius / 2.)));
                    if (row.color != null) swatch.bg(row.color);
                    label.child(swatch);
                }
                label.child(div().textColor(theme.mutedForeground).child(row.label));
                final value = div();
                if (row.valueColor != null) value.textColor(row.valueColor);
                value.child(row.value);
                content.child(hFlex().itemsCenter().justifyBetween().gap3().child(label).child(value));
            }
        }
        else {
            content = base;
        }
        // One size for every tooltip, structured or freeform, boxed or bare.
        content = content.textXs();

        final result = div().sizeFull().absolute().top0().left0().opacity(progress);
        if (crossLineValue != null) {
            result.child(crossLineValue);
        }
        if (dotsValue != null) {
            result.children([for (dot in dotsValue) (dot : IntoElement)]);
        }

        // Only the box is deferred: it can overflow the plot bounds and must
        // paint above sibling content, while the crosshair and dots stay in
        // the plot's own layer. A deferred draw paints outside this
        // element's opacity, so the box carries the fade itself.
        if (!appearanceValue) {
            content = content.sizeFull().relative().opacity(progress);
        }
        else {
            // Default min width only applies when the caller hasn't set one.
            final minWUnset = content.style().minSizeWidth == null;
            content = content.absolute().opacity(progress);
            if (minWUnset) content = content.minW(glaze.Prelude.px(150.));
            content = content.popoverStyle(cx).p2();
            // The box hugs the cursor, flipping toward the center near each
            // edge so it never overflows the near side.
            content = cursor.x < SpringMath.f32(within.width * 0.5)
                ? content.left(glaze.Prelude.px(SpringMath.f32(cursor.x + gapValue)))
                : content.right(glaze.Prelude.px(SpringMath.f32(SpringMath.f32(within.width - cursor.x) + gapValue)));
            content = cursor.y < SpringMath.f32(within.height * 0.5)
                ? content.top(glaze.Prelude.px(SpringMath.f32(cursor.y + gapValue)))
                : content.bottom(glaze.Prelude.px(SpringMath.f32(SpringMath.f32(within.height - cursor.y) + gapValue)));
        }
        return result.child(deferred(content));
    }

}

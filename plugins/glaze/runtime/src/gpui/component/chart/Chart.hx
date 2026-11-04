// Ported from gpui-kit 0.8.1: crates/component/src/chart/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.chart;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.ContentMask;
import gpui.ElementId;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.Point;
import gpui.Size;
import gpui.SpringMath;
import gpui.TextAlign;
import gpui.Window;
import gpui.base.plot.Grid;
import gpui.base.plot.PlotAppear;
import gpui.base.plot.PlotAxis.AxisLabelPlacement;
import gpui.base.plot.PlotAxis.AxisText;
import gpui.base.plot.PlotLabel;
import gpui.base.plot.PlotLabel.Text;
import gpui.base.plot.scale.ScaleBand;
import gpui.base.plot.scale.ScaleLinear;
import gpui.base.plot.scale.ScalePoint;
import gpui.component.plot.Tooltip;
import gpui.component.theme.Theme;
import gpui.util.MathUtil;

/**
 * The helpers the charts of `gpui.component.chart` share (Rust
 * `chart/mod.rs`).
 */
class Chart {

    /** The size of the dot marking the hovered data point. */
    public static inline final HOVER_DOT_SIZE:Float = 8.;

    /**
     * The ring behind the hovered dot at full focus; a `Tooltip` grows it
     * out of the dot as the hover fades in.
     */
    public static inline final HOVER_HALO_SIZE:Float = 20.;

    /**
     * The height the charts reserve under the plot for x-axis labels, which
     * they draw at the default `TEXT_SIZE`.
     */
    public static inline final AXIS_GAP:Float = PlotLabel.TEXT_SIZE + PlotLabel.TEXT_GAP * 4.;

    /**
     * The widest a bar or candle is by default, in pixels, however few bands
     * share the width.
     */
    public static inline final MAX_BAND_WIDTH:Float = 30.;

    /**
     * The least space kept beside the plot for value-axis tick labels drawn
     * outside it, in pixels; wider labels widen it.
     */
    public static inline final VALUE_AXIS_GAP:Float = 32.;

    /**
     * The `ElementId` a chart carries when the caller names none: the
     * source location it was constructed at (Rust `#[track_caller]`; Haxe's
     * position has no column, so two charts built on one line share it).
     */
    public static function callerId(pos:haxe.PosInfos):ElementId {
        return pos != null ? ElementId.CodeLocation(pos.fileName, pos.lineNumber) : ElementId.Name('chart');
    }

    /**
     * The mask a chart that draws in from the left paints its series under
     * while it appears: everything left of `progress` of the way across the
     * plot, which starts `left` into `bounds`. It bleeds by half a hover
     * dot, and there is no mask once the appear is done.
     */
    public static function revealMask(bounds:Bounds, left:Float, progress:Float):Null<ContentMask> {
        if (progress >= 1.) {
            return null;
        }
        final bleed = f(HOVER_DOT_SIZE / 2.);
        final right = f(bounds.origin.x + bounds.size.width);
        final bottom = f(bounds.origin.y + bounds.size.height);
        final start = f(f(bounds.origin.x + f(left)) - bleed);
        final end = f(start + f(f(f(right + bleed) - start) * Math.max(progress, 0.)));
        return new ContentMask(fromCorners(new Point(f(bounds.origin.x - bleed), f(bounds.origin.y - bleed)), new Point(end, f(bottom + bleed))));
    }

    /**
     * How many points the x axis of a point chart is laid out for:
     * `pointCount`, or the data's own length when that is unset or smaller.
     */
    public static function axisPointCount(pointCount:Null<Int>, dataLen:Int):Int {
        final count:Int = pointCount != null ? pointCount : dataLen;
        return count > dataLen ? count : dataLen;
    }

    /**
     * The x range a point scale spreads `dataLen` points over, when the axis
     * is laid out for `pointCount` of them across `width` pixels from
     * `start`. The data takes the leading points.
     */
    public static function pointRange(start:Float, width:Float, dataLen:Int, pointCount:Int):Array<Float> {
        final end = pointCount > 1 ? f(f(f(width) * (dataLen > 0 ? dataLen - 1 : 0)) / (pointCount - 1)) : f(width);
        return [f(start), f(f(start) + end)];
    }

    /**
     * The y scale of a point chart, from `height` less the bottom `padding`
     * up to the top `padding`. A pinned `domain` maps its ends onto that
     * range; otherwise the scale fits `values` from zero.
     */
    public static function pointValueScale(values:Iterable<Float>, domain:Null<Array<Float>>, height:Float, padding:Array<Float>):{scale:ScaleLinear, extent:ValueExtent} {
        final top = f(padding[0]);
        final bottom = f(padding[1]);
        final domainValues:Array<Float> = domain != null ? [domain[0], domain[1]] : {
            final list = [for (v in values) v];
            list.push(0.);
            list;
        };
        var lo = 1.7976931348623157e308;
        var hi = -1.7976931348623157e308;
        for (v in domainValues) {
            lo = Math.min(lo, v);
            hi = Math.max(hi, v);
        }
        final base = f(f(height) - bottom);
        final extent = new ValueExtent(lo, hi, base, top);
        return {scale: new ScaleLinear(domainValues, [base, top]), extent: extent};
    }

    /**
     * The gutter value-axis tick `labels` drawn outside the plot need: the
     * widest label and the gap before the plot, and never less than
     * `VALUE_AXIS_GAP`.
     */
    public static function valueAxisGap(labels:Iterable<String>, window:Window):Float {
        var gap = VALUE_AXIS_GAP;
        for (label in labels) {
            gap = Math.max(gap, f(PlotLabel.measureTextWidth(label, PlotLabel.TEXT_SIZE, window) + PlotLabel.TEXT_GAP * 2.));
        }
        return gap;
    }

    /** The default tick label: whole numbers bare, the rest to one decimal. */
    public static function formatTick(value:Float):String {
        if (Math.abs(value - MathUtil.round(value)) < 0.001) {
            return ChartFormat.fixed(value, 0);
        }
        return ChartFormat.fixed(value, 1);
    }

    /**
     * Which of `len` items carry a category label: `labelCount` of them
     * evenly spread from the first to the last when set, otherwise every
     * `tickMargin`-th.
     */
    public static function labeledItems(len:Int, labelCount:Null<Int>, tickMargin:Int):Array<Bool> {
        if (labelCount != null) {
            final labeled = [for (_ in 0...len) false];
            final count:Int = labelCount;
            if (count == 0) {}
            else if (count == 1) {
                if (len > 0) labeled[0] = true;
            }
            else if (count >= len) {
                for (i in 0...len) labeled[i] = true;
            }
            else {
                for (k in 0...count) {
                    final ix = Std.int(MathUtil.round(f(f(k * (len - 1)) / (count - 1))));
                    labeled[ix] = true;
                }
            }
            return labeled;
        }
        return [for (i in 0...len) (i + 1) % tickMargin == 0];
    }

    /**
     * The mask a point chart paints its series under once its y axis is
     * pinned, so a value outside the pinned domain stops at the plot area.
     * It bleeds by half a hover dot.
     */
    public static function pinnedPlotMask(bounds:Bounds, height:Float):ContentMask {
        final bleed = f(HOVER_DOT_SIZE / 2.);
        return new ContentMask(fromCorners(
            new Point(f(bounds.origin.x - bleed), f(bounds.origin.y - bleed)),
            new Point(f(f(bounds.origin.x + bounds.size.width) + bleed), f(f(bounds.origin.y + f(height)) + bleed))
        ));
    }

    /**
     * Build x-axis labels for point-based scales (`LineChart`, `AreaChart`),
     * on an axis laid out for `pointCount` points. A label on the first point
     * is left-aligned, one on the last is right-aligned, and the rest are
     * centered.
     */
    public static function buildPointXLabels<T>(data:Array<T>, xFn:(T) -> String, xScale:ScalePoint<String>, pointCount:Int, labeled:Array<Bool>, color:Hsla):Array<AxisText> {
        final result:Array<AxisText> = [];
        for (i in 0...data.length) {
            if (!(i < labeled.length && labeled[i])) continue;
            final xTick = xScale.tickAt(i);
            if (xTick == null) continue;
            final align:TextAlign = if (i == 0 && pointCount == 1) Center else if (i == 0) Left else if (i == pointCount - 1) Right else Center;
            result.push(new AxisText(xFn(data[i]), xTick, color).withAlign(align));
        }
        return result;
    }

    /**
     * Build axis labels for band-based scales (`BarChart`,
     * `CandlestickChart`): the tick is the centre of each band.
     */
    public static function buildBandLabels<T>(data:Array<T>, xFn:(T) -> String, xScale:ScaleBand<String>, bandWidth:Float, labeled:Array<Bool>, color:Hsla):Array<AxisText> {
        final result:Array<AxisText> = [];
        for (i in 0...data.length) {
            if (!(i < labeled.length && labeled[i])) continue;
            final xTick = xScale.tick(xFn(data[i]));
            if (xTick == null) continue;
            result.push(new AxisText(xFn(data[i]), f(xTick + f(bandWidth / 2.)), color).withAlign(Center));
        }
        return result;
    }

    /** `Bounds::from_corners` in `f32`. */
    public static inline function fromCorners(topLeft:Point, bottomRight:Point):Bounds {
        return new Bounds(topLeft, new Size(f(bottomRight.x - topLeft.x), f(bottomRight.y - topLeft.y)));
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

/**
 * A chart's appear: whether its data draws in the first time it is
 * painted, the key that replays it, and how far it has drawn in this frame.
 */
class ChartAppear {

    var enabled:Bool = true;

    var generationValue:String = '0';

    var current:PlotAppear = PlotAppear.complete();

    public function new() {}

    public function setEnabled(enabled:Bool):Void {
        this.enabled = enabled;
    }

    /** Rust hashes the key into the generation. */
    public function setKey(key:String):Void {
        generationValue = 'key:' + key;
    }

    /**
     * The generation a chart hands `Plot.appearGeneration`, or null when it
     * opted out, so no appear is tracked and no frames are asked for.
     */
    public function generation():Null<String> {
        return enabled ? generationValue : null;
    }

    public function update(appear:PlotAppear):Void {
        current = appear;
    }

    public function get():PlotAppear {
        return current;
    }

}

/**
 * The value range a y scale spans and the pixel range it maps onto, kept in
 * `f64` so tick labels can read the value at any height of the plot.
 */
class ValueExtent {

    final lo:Float;

    final hi:Float;

    final bottom:Float;

    final top:Float;

    public function new(lo:Float, hi:Float, bottom:Float, top:Float) {
        this.lo = lo;
        this.hi = hi;
        this.bottom = SpringMath.f32(bottom);
        this.top = SpringMath.f32(top);
    }

    /** The value the scale puts at pixel `y`. */
    public function valueAt(y:Float):Float {
        if (bottom == top) {
            return lo;
        }
        return lo + (hi - lo) * SpringMath.f32(SpringMath.f32(bottom - y) / SpringMath.f32(bottom - top));
    }

    /** The pixel the scale puts `value` at, or null for a scale with no extent. */
    public function positionOf(value:Float):Null<Float> {
        if (hi == lo) {
            return null;
        }
        return SpringMath.f32(bottom - SpringMath.f32(SpringMath.f32((value - lo) / (hi - lo)) * SpringMath.f32(bottom - top)));
    }

}

/**
 * One tooltip row of a series chart: its swatch, name and value.
 */
typedef ChartTooltipRow = {
    swatch:Hsla,
    name:String,
    value:Float
}

/**
 * What a series chart (`LineChart`, `AreaChart`, `BarChart`, `RadarChart`,
 * `CandlestickChart`) writes in its hover tooltip, and the builders the
 * five charts forward to it.
 */
class TooltipContent<T> {

    var title:Null<(T) -> String> = null;

    var value:Null<(T, Int, Float) -> String> = null;

    var valueColor:Null<(T, Int, Float) -> Hsla> = null;

    var content:Null<(T, Window, App) -> AnyElement> = null;

    public function new() {}

    public function setTitle(title:(T) -> String):Void {
        this.title = title;
    }

    public function setValue(value:(T, Int, Float) -> String):Void {
        this.value = value;
    }

    public function setValueColor(color:(T, Int, Float) -> Hsla):Void {
        this.valueColor = color;
    }

    public function setContent(content:(T, Window, App) -> IntoElement):Void {
        this.content = (d, window, cx) -> content(d, window, cx).intoAnyElement();
    }

    /**
     * The title for datum `d`: the caller's, or `fallback`, the chart's own,
     * which a chart may not have.
     */
    @:allow(tests)
    function titleText(d:T, fallback:Null<String>):Null<String> {
        return title != null ? title(d) : fallback;
    }

    /** The value text of row `ix`: the caller's, or the raw number. */
    @:allow(tests)
    function valueText(d:T, ix:Int, value:Float):String {
        return this.value != null ? this.value(d, ix, value) : ChartFormat.display64(value);
    }

    /**
     * Write the content of `tooltip` for datum `d`: the caller's own content
     * when it renders one, otherwise the chart's `title`, if it has one, and
     * one row per `(swatch, name, value)`. Neither is built when the caller
     * renders, and null from `rows` means a row has no value to show.
     */
    public function apply(tooltip:Tooltip, d:T, title:() -> Null<String>, rows:() -> Null<Array<ChartTooltipRow>>, window:Window, cx:App):Null<Tooltip> {
        if (content != null) {
            return tooltip.child(content(d, window, cx));
        }
        final titleText = titleText(d, title());
        var result = titleText != null ? tooltip.title(titleText) : tooltip;
        final list = rows();
        if (list == null) {
            return null;
        }
        for (ix in 0...list.length) {
            final row = list[ix];
            result = result.row(row.swatch, row.name, valueText(d, ix, row.value));
            if (valueColor != null) {
                result = result.valueColor(valueColor(d, ix, row.value));
            }
        }
        return result;
    }

}

/**
 * The grid, value-axis labels and reference lines a point chart
 * (`LineChart`, `AreaChart`) draws, and the builders both charts forward to
 * it.
 */
class PointAxes {

    public var yAxis:Bool = false;

    public var yAxisLabelPlacement:AxisLabelPlacement = Outside;

    public var yTickCount:Int = 5;

    public var yTickFormat:Null<(Float) -> String> = null;

    public var xTickCount:Null<Int> = null;

    public var gridColumns:Int = 0;

    public var gridDashed:Bool = true;

    /** `(top, bottom)` */
    public var yPadding:Array<Float> = [10., 0.];

    public var referenceLines:Array<Float> = [];

    /** The value-axis gutter measured in `prepaint`; see `Chart.valueAxisGap`. */
    var yLabelGap:Float = Chart.VALUE_AXIS_GAP;

    public function new() {}

    /**
     * Where the plot starts along x: past the value-axis gutter when the
     * labels sit outside it.
     */
    public function plotLeft():Float {
        return yAxis && yAxisLabelPlacement == Outside ? yLabelGap : 0.;
    }

    /**
     * Measure the gutter the y labels need outside the plot, before the x
     * scale is laid out past it.
     */
    public function measureYLabels(extent:ValueExtent, height:Float, window:Window):Void {
        if (yAxis && yAxisLabelPlacement == Outside) {
            yLabelGap = Chart.valueAxisGap([for (label in yTickLabels(extent, height)) label.text], window);
        }
    }

    /** Each y tick's position and the label text for the value there. */
    function yTickLabels(extent:ValueExtent, height:Float):Array<{y:Float, text:String}> {
        return [
            for (y in tickPositions(height)) {
                final value = extent.valueAt(y);
                {y: y, text: yTickFormat != null ? yTickFormat(value) : Chart.formatTick(value)};
            }
        ];
    }

    /**
     * The plot area within `bounds`: past the value-axis gutter and above
     * the x axis at `height`.
     */
    public function plotBounds(bounds:Bounds, height:Float):Bounds {
        final left = plotLeft();
        return new Bounds(new Point(f(bounds.origin.x + left), bounds.origin.y), new Size(f(bounds.size.width - left), f(height)));
    }

    /**
     * The y ticks, evenly spaced in pixels from the top edge (0) to the
     * baseline (`height`), both included.
     */
    @:allow(tests)
    function tickPositions(height:Float):Array<Float> {
        final count = yTickCount > 2 ? yTickCount : 2;
        return [for (i in 0...count) f(f(f(height) * i) / (count - 1))];
    }

    /**
     * Paint the grid: a line at every y tick but the baseline, which the x
     * axis draws, and `gridColumns` evenly spaced vertical lines from the
     * left edge.
     */
    public function paintGrid(bounds:Bounds, height:Float, window:Window, cx:App):Void {
        final plot = plotBounds(bounds, height);
        final rows = tickPositions(height);
        rows.pop();
        final width = plot.size.width;
        final columns = [for (i in 0...gridColumns) f(f(width * i) / gridColumns)];
        var grid = new Grid().y(rows).x(columns).stroke(Theme.global(cx).chartGrid);
        if (gridDashed) {
            grid = grid.dashArray([4., 2.]);
        }
        grid.paint(plot, window);
    }

    /**
     * Paint a dashed line across the plot at each reference value, darker
     * than the grid so it reads apart from a dashed grid line.
     */
    public function paintReferenceLines(extent:ValueExtent, bounds:Bounds, height:Float, window:Window, cx:App):Void {
        final rows:Array<Float> = [];
        for (v in referenceLines) {
            final y = extent.positionOf(v);
            if (y != null && y >= 0. && y <= height) {
                rows.push(y);
            }
        }
        if (rows.length == 0) {
            return;
        }
        new Grid()
            .y(rows)
            .stroke(Theme.global(cx).mutedForeground)
            .dashArray([4., 2.])
            .paint(plotBounds(bounds, height), window);
    }

    /** Paint a tick label at every y tick, reading the value the scale puts there. */
    public function paintYLabels(extent:ValueExtent, bounds:Bounds, height:Float, window:Window, cx:App):Void {
        if (!yAxis) {
            return;
        }
        final color = Theme.global(cx).mutedForeground;
        final labels = [
            for (label in yTickLabels(extent, height)) {
                final y = label.y;
                switch yAxisLabelPlacement {
                    // Beside its grid line, above it but for the top one,
                    // which would leave the plot.
                    case Inside:
                        final top = y < PlotLabel.TEXT_HEIGHT ? f(y + PlotLabel.TEXT_GAP) : f(y - PlotLabel.TEXT_HEIGHT);
                        new Text(label.text, new Point(PlotLabel.TEXT_GAP, top), color);
                    case Outside:
                        final max = Math.max(f(height - PlotLabel.TEXT_SIZE), 0.);
                        final raw = f(y - PlotLabel.TEXT_SIZE / 2.);
                        final top = raw < 0. ? 0. : (raw > max ? max : raw);
                        new Text(label.text, new Point(f(yLabelGap - PlotLabel.TEXT_GAP * 2.), top), color).withAlign(Right);
                }
            }
        ];
        new PlotLabel(labels).paint(bounds, window, cx);
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

// Ported from gpui-kit 0.8.1: crates/component/src/chart/line_chart.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.chart;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Point;
import glaze.Size;
import glaze.SpringMath;
import glaze.Window;
import glaze.kit.base.plot.Curve;
import glaze.kit.base.plot.PathCache.PathCaches;
import glaze.kit.base.plot.Plot;
import glaze.kit.base.plot.PlotAppear;
import glaze.kit.base.plot.PlotAxis;
import glaze.kit.base.plot.PlotAxis.AxisLabelPlacement;
import glaze.kit.base.plot.TooltipState;
import glaze.kit.base.plot.scale.ScaleLinear;
import glaze.kit.base.plot.scale.ScalePoint;
import glaze.kit.base.plot.shape.Line;
import glaze.kit.chart.Chart.ChartAppear;
import glaze.kit.chart.Chart.PointAxes;
import glaze.kit.chart.Chart.TooltipContent;
import glaze.kit.chart.Chart.ValueExtent;
import glaze.kit.plot.Tooltip;
import glaze.kit.plot.Tooltip.CrossLine;
import glaze.kit.plot.Tooltip.Dot;
import glaze.kit.theme.Theme;

/**
 * A line chart: one series of `Float` values over categorical x values
 * (Rust `LineChart<T, X, Y>`: `X` is a `String` and `Y` a `Float` here).
 */
class LineChart<T> extends Plot {

    final data:Array<T>;

    var xFn:Null<(T) -> String> = null;

    var yFn:Null<(T) -> Float> = null;

    @prop var stroke:Null<Hsla> = null;

    var curveValue:Curve = Natural;

    var dotValue:Bool = false;

    @prop var tickMargin:Int = 1;

    /** Show or hide the x-axis line and labels. Default is true. */
    @prop var xAxis:Bool = true;

    @prop var grid:Bool = true;

    var yDomainValue:Null<Array<Float>> = null;

    /** Lay the x axis out for `count` evenly spaced points instead of the data's own length. */
    @prop var pointCount:Null<Int> = null;

    final axes:PointAxes = new PointAxes();

    @prop var id:ElementId;

    /** Turn this chart's interactive layer (hitbox, crosshair, tooltip) on or off. On by default. */
    @prop var interactive:Bool = true;

    final appearValue:ChartAppear = new ChartAppear();

    /** Set the series name shown in the hover tooltip row (e.g. "Desktop"). */
    @prop var name:Null<String> = null;

    final tooltipContentValue:TooltipContent<T> = new TooltipContent();

    public function new(data:Iterable<T>, ?pos:haxe.PosInfos) {
        super();
        this.data = glaze.util.Iterables.toArray(data);
        id = Chart.callerId(pos);
    }

    /**
     * Name this chart's `ElementId`, replacing the default taken from the
     * construction site. The id must be unique among siblings.
     */
    public function id(id:ElementIdArg):LineChart<T> {
        this.id = id;
        return this;
    }

    /** Draw the data in the first time this chart is painted. On by default. */
    public function appear(appear:Bool):LineChart<T> {
        appearValue.setEnabled(appear);
        return this;
    }

    /** Draw the data in again whenever `key` changes. */
    public function appearKey(key:String):LineChart<T> {
        appearValue.setKey(key);
        return this;
    }

    /** Set the hover tooltip's title for a datum, instead of its x value. */
    public function tooltipTitle(title:(T) -> String):LineChart<T> {
        tooltipContentValue.setTitle(title);
        return this;
    }

    /** Set the text of the tooltip row's value; the raw number by default. */
    public function tooltipValue(value:(T, Float) -> String):LineChart<T> {
        tooltipContentValue.setValue((d, _, v) -> value(d, v));
        return this;
    }

    /** Color the tooltip row's value; the tooltip's text color by default. */
    public function tooltipValueColor(color:(T, Float) -> IntoHsla):LineChart<T> {
        tooltipContentValue.setValueColor((d, _, v) -> (color(d, v) : Hsla));
        return this;
    }

    /** Draw the tooltip box's content for a datum yourself, in place of the title and rows. */
    public function tooltipContent(content:(T, Window, App) -> IntoElement):LineChart<T> {
        tooltipContentValue.setContent(content);
        return this;
    }

    public function x(x:(T) -> String):LineChart<T> {
        xFn = x;
        return this;
    }

    public function y(y:(T) -> Float):LineChart<T> {
        yFn = y;
        return this;
    }

    public function stroke(stroke:IntoHsla):LineChart<T> {
        this.stroke = stroke;
        return this;
    }

    public function natural():LineChart<T> {
        curveValue = Natural;
        return this;
    }

    public function linear():LineChart<T> {
        curveValue = Linear;
        return this;
    }

    public function stepAfter():LineChart<T> {
        curveValue = StepAfter;
        return this;
    }

    public function dot():LineChart<T> {
        dotValue = true;
        return this;
    }

    /**
     * Pin the y axis to `min..=max` instead of fitting the line from zero.
     * The line is clipped to the plot.
     */
    public function yDomain(min:Float, max:Float):LineChart<T> {
        yDomainValue = [min, max];
        return this;
    }

    /** Show the y axis's tick labels. Default is false. */
    public function yAxis(yAxis:Bool):LineChart<T> {
        axes.yAxis = yAxis;
        return this;
    }

    /** Set where the y-axis tick labels sit. Default is `Outside`. */
    public function yAxisLabelPlacement(placement:AxisLabelPlacement):LineChart<T> {
        axes.yAxisLabelPlacement = placement;
        return this;
    }

    /** Set how many ticks the y axis carries (at least 2). Default is 5. */
    public function yTickCount(count:Int):LineChart<T> {
        axes.yTickCount = count > 2 ? count : 2;
        return this;
    }

    /** Set the text of each y-axis tick label from the value at its tick. */
    public function yTickFormat(format:(Float) -> String):LineChart<T> {
        axes.yTickFormat = format;
        return this;
    }

    /** Label `count` of the x values, spread evenly from the first to the last. */
    public function xTickCount(count:Int):LineChart<T> {
        axes.xTickCount = count;
        return this;
    }

    /** Divide the plot into `count` columns with vertical grid lines. Default is 0. */
    public function gridColumns(count:Int):LineChart<T> {
        axes.gridColumns = count;
        return this;
    }

    /** Draw the grid dashed or solid. Default is true. */
    public function gridDashed(dashed:Bool):LineChart<T> {
        axes.gridDashed = dashed;
        return this;
    }

    /** Draw a dashed line across the plot at `value`. Call again for more lines. */
    public function referenceLine(value:Float):LineChart<T> {
        axes.referenceLines.push(value);
        return this;
    }

    /** Set the space kept clear above the highest value and below the lowest. Default is 10px and 0. */
    public function yPadding(top:Float, bottom:Float):LineChart<T> {
        axes.yPadding = [top, bottom];
        return this;
    }

    function axisGap():Float {
        return xAxis ? Chart.AXIS_GAP : 0.;
    }

    /**
     * Build the x (point) and y (linear) scales for the given bounds, shared
     * by `paint` and `tooltipState`. Null when the accessors are not set.
     */
    @:allow(tests)
    function scales(bounds:Bounds):Null<{x:ScalePoint<String>, y:ScaleLinear, extent:ValueExtent}> {
        if (xFn == null || yFn == null) {
            return null;
        }
        final xFn = this.xFn;
        final yFn = this.yFn;
        final width = bounds.size.width;
        final height = f(bounds.size.height - axisGap());
        final len = data.length;
        final x = new ScalePoint([for (v in data) xFn(v)], Chart.pointRange(axes.plotLeft(), f(width - axes.plotLeft()), len, Chart.axisPointCount(pointCount, len)));
        final y = Chart.pointValueScale([for (v in data) yFn(v)], yDomainValue, height, axes.yPadding);
        return {x: x, y: y.scale, extent: y.extent};
    }

    override public function prepaint(bounds:Bounds, window:Window, cx:App):Array<AnyElement> {
        // The y labels' gutter is measured before the x scale is laid out past it.
        final scales = scales(bounds);
        if (scales != null) {
            axes.measureYLabels(scales.extent, f(bounds.size.height - axisGap()), window);
        }
        return [];
    }

    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        if (xFn == null || yFn == null) {
            return;
        }
        final xFn = this.xFn;
        final yFn = this.yFn;
        final scales = scales(bounds);
        if (scales == null) {
            return;
        }
        final theme = Theme.global(cx);
        final height = f(bounds.size.height - axisGap());

        // The axis runs under the plot only, clear of a value-axis gutter, so
        // its labels shift back by the gutter the x scale already includes.
        final left = axes.plotLeft();
        final axisBounds = new Bounds(new Point(f(bounds.origin.x + left), bounds.origin.y), new Size(f(bounds.size.width - left), bounds.size.height));
        var axis = new PlotAxis().stroke(theme.border);
        if (xAxis) {
            final pointCount = Chart.axisPointCount(this.pointCount, data.length);
            final labeled = Chart.labeledItems(pointCount, axes.xTickCount, tickMargin);
            final labels = Chart.buildPointXLabels(data, xFn, scales.x, pointCount, labeled, theme.mutedForeground);
            for (label in labels) {
                label.tick = f(label.tick - left);
            }
            axis = axis.x(height).xLabel(labels);
        }
        axis.paint(axisBounds, window, cx);

        if (grid) {
            axes.paintGrid(bounds, height, window, cx);
        }

        // Draw line
        final stroke:Hsla = this.stroke != null ? this.stroke : theme.chart2;
        // The x domain holds one entry per datum, so a point's x is its
        // index's tick.
        final xScale = scales.x;
        final yScale = scales.y;
        final data = this.data;
        var line = new Line<Int>()
            .data([for (i in 0...data.length) i])
            .x(i -> xScale.tickAt(i))
            .y(i -> yScale.tick(yFn(data[i])))
            .stroke(stroke)
            .curve(curveValue)
            .strokeWidth(2.);

        if (dotValue) {
            line = line.dot().dotSize(8.).dotFill(stroke);
        }

        final mask = yDomainValue != null ? Chart.pinnedPlotMask(bounds, height) : null;
        // The line draws in from the left under a mask, so its shape, and the
        // cached path, stay the same on every frame of the appear.
        final reveal = Chart.revealMask(bounds, left, appearValue.get().progress());
        window.withContentMask(mask, window -> {
            window.withContentMask(reveal, window -> {
                final caches = PathCaches.forPaint('line', window, cx);
                line.paintCached(bounds, caches.slot(0), window);
                return true;
            });
            return true;
        });

        axes.paintReferenceLines(scales.extent, bounds, height, window, cx);
        axes.paintYLabels(scales.extent, bounds, height, window, cx);
    }

    override public function plotId():Null<ElementId> {
        return id;
    }

    override public function isInteractive():Bool {
        return interactive;
    }

    override public function updateAppear(appear:PlotAppear, window:Window, cx:App):Void {
        appearValue.update(appear);
    }

    override public function appearGeneration():Null<String> {
        return appearValue.generation();
    }

    override public function tooltipState(position:Point, bounds:Bounds, cx:App):Null<TooltipState> {
        if (yFn == null) {
            return null;
        }
        final scales = scales(bounds);
        if (scales == null) {
            return null;
        }

        // Ignore the x-axis label gutter so hovering the labels doesn't show a tooltip.
        if (position.y > f(bounds.size.height - axisGap()) || position.x < axes.plotLeft()) {
            return null;
        }

        final index = scales.x.nearestIndex(position.x);
        if (index >= data.length) {
            return null;
        }
        final d = data[index];
        final xTick = scales.x.tickAt(index);
        if (xTick == null) {
            return null;
        }
        final yTick = scales.y.tick(yFn(d));
        if (yTick == null) {
            return null;
        }

        return new TooltipState(index, new Point(xTick, position.y), [new Point(xTick, yTick)]);
    }

    override public function tooltip(state:TooltipState, cursor:Point, bounds:Bounds, window:Window, cx:App):Null<AnyElement> {
        if (xFn == null || yFn == null) {
            return null;
        }
        final xFn = this.xFn;
        final yFn = this.yFn;
        if (state.index >= data.length) {
            return null;
        }
        final d = data[state.index];
        final theme = Theme.global(cx);
        final stroke:Hsla = this.stroke != null ? this.stroke : theme.chart2;
        final name = this.name != null ? this.name : '';
        if (state.dots.length == 0) {
            return null;
        }
        final dot = state.dots[0];

        // Follow the cursor; the crosshair and dot glide to the data point.
        final tooltip = Tooltip.component(cursor, bounds.size)
            .gap(8.)
            // Confine the crosshair to the plot area so it doesn't cross the x-axis.
            .crossLine(CrossLine.component(state.crossLine).height(f(bounds.size.height - axisGap())))
            .dots([
                Dot.component(dot)
                    .size(Chart.HOVER_DOT_SIZE)
                    .halo(Chart.HOVER_HALO_SIZE)
                    .stroke(theme.background)
                    .fill(stroke)
            ]);

        final result = tooltipContentValue.apply(tooltip, d, () -> xFn(d), () -> [{swatch: stroke, name: name, value: yFn(d)}], window, cx);
        return result != null ? (result : IntoElement).intoAnyElement() : null;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

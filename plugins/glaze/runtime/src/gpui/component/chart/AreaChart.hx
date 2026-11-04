// Ported from gpui-kit 0.8.1: crates/component/src/chart/area_chart.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.chart;

import gpui.AnyElement;
import gpui.Background;
import gpui.IntoBackground;
import gpui.App;
import gpui.Bounds;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.IntoHsla;
import gpui.Point;
import gpui.Size;
import gpui.SpringMath;
import gpui.Window;
import gpui.base.plot.Curve;
import gpui.base.plot.PathCache.PathCaches;
import gpui.base.plot.Plot;
import gpui.base.plot.PlotAppear;
import gpui.base.plot.PlotAxis;
import gpui.base.plot.PlotAxis.AxisLabelPlacement;
import gpui.base.plot.TooltipState;
import gpui.base.plot.scale.ScaleLinear;
import gpui.base.plot.scale.ScalePoint;
import gpui.base.plot.shape.Area;
import gpui.component.chart.Chart.ChartAppear;
import gpui.component.chart.Chart.PointAxes;
import gpui.component.chart.Chart.TooltipContent;
import gpui.component.chart.Chart.ValueExtent;
import gpui.component.plot.Tooltip;
import gpui.component.plot.Tooltip.CrossLine;
import gpui.component.plot.Tooltip.Dot;
import gpui.component.theme.Theme;

/**
 * An area chart: one or more series of `Float` values over categorical x
 * values, each filled down to the baseline (Rust `AreaChart<T, X, Y>`).
 * Every `y`, `stroke`, `fill` and curve builder call adds the next series'.
 */
class AreaChart<T> extends Plot {

    final data:Array<T>;

    var xFn:Null<(T) -> String> = null;

    final yFns:Array<(T) -> Float> = [];

    final strokes:Array<Hsla> = [];

    final curves:Array<Curve> = [];

    final fills:Array<Background> = [];

    final names:Array<String> = [];

    final tooltipContentValue:TooltipContent<T> = new TooltipContent();

    var tickMarginValue:Int = 1;

    var xAxisValue:Bool = true;

    var gridValue:Bool = true;

    var yDomainValue:Null<Array<Float>> = null;

    var pointCountValue:Null<Int> = null;

    final axes:PointAxes = new PointAxes();

    var idValue:ElementId;

    var interactiveValue:Bool = true;

    final appearValue:ChartAppear = new ChartAppear();

    public function new(data:Iterable<T>, ?pos:haxe.PosInfos) {
        super();
        this.data = [for (d in data) d];
        idValue = Chart.callerId(pos);
    }

    /** Name this chart's `ElementId`, replacing the default taken from the construction site. */
    public function id(id:ElementIdArg):AreaChart<T> {
        idValue = id;
        return this;
    }

    /** Turn this chart's interactive layer on or off. On by default. */
    public function interactive(interactive:Bool):AreaChart<T> {
        interactiveValue = interactive;
        return this;
    }

    /** Draw the data in the first time this chart is painted. On by default. */
    public function appear(appear:Bool):AreaChart<T> {
        appearValue.setEnabled(appear);
        return this;
    }

    /** Draw the data in again whenever `key` changes. */
    public function appearKey(key:String):AreaChart<T> {
        appearValue.setKey(key);
        return this;
    }

    /** Add the name of the next series, shown in its tooltip row. */
    public function name(name:String):AreaChart<T> {
        names.push(name);
        return this;
    }

    /** Set the hover tooltip's title for a datum, instead of its x value. */
    public function tooltipTitle(title:(T) -> String):AreaChart<T> {
        tooltipContentValue.setTitle(title);
        return this;
    }

    /**
     * Set the text of each tooltip row's value; the raw number by default.
     * The function receives the datum, the row's (series') index and the value.
     */
    public function tooltipValue(value:(T, Int, Float) -> String):AreaChart<T> {
        tooltipContentValue.setValue(value);
        return this;
    }

    /** Color each tooltip row's value; the tooltip's text color by default. */
    public function tooltipValueColor(color:(T, Int, Float) -> IntoHsla):AreaChart<T> {
        tooltipContentValue.setValueColor((d, ix, v) -> (color(d, ix, v) : Hsla));
        return this;
    }

    /** Draw the tooltip box's content for a datum yourself, in place of the title and rows. */
    public function tooltipContent(content:(T, Window, App) -> IntoElement):AreaChart<T> {
        tooltipContentValue.setContent(content);
        return this;
    }

    public function x(x:(T) -> String):AreaChart<T> {
        xFn = x;
        return this;
    }

    public function y(y:(T) -> Float):AreaChart<T> {
        yFns.push(y);
        return this;
    }

    public function stroke(stroke:IntoHsla):AreaChart<T> {
        strokes.push(stroke);
        return this;
    }

    public function fill(fill:IntoBackground):AreaChart<T> {
        fills.push(fill);
        return this;
    }

    public function natural():AreaChart<T> {
        curves.push(Natural);
        return this;
    }

    public function linear():AreaChart<T> {
        curves.push(Linear);
        return this;
    }

    public function stepAfter():AreaChart<T> {
        curves.push(StepAfter);
        return this;
    }

    public function tickMargin(tickMargin:Int):AreaChart<T> {
        tickMarginValue = tickMargin;
        return this;
    }

    /** Show or hide the x-axis line and labels. Default is true. */
    public function xAxis(xAxis:Bool):AreaChart<T> {
        xAxisValue = xAxis;
        return this;
    }

    public function grid(grid:Bool):AreaChart<T> {
        gridValue = grid;
        return this;
    }

    /** Pin the y axis to `min..=max` instead of fitting every series from zero. */
    public function yDomain(min:Float, max:Float):AreaChart<T> {
        yDomainValue = [min, max];
        return this;
    }

    /** Lay the x axis out for `count` evenly spaced points instead of the data's own length. */
    public function pointCount(count:Int):AreaChart<T> {
        pointCountValue = count;
        return this;
    }

    /** Show the y axis's tick labels. Default is false. */
    public function yAxis(yAxis:Bool):AreaChart<T> {
        axes.yAxis = yAxis;
        return this;
    }

    /** Set where the y-axis tick labels sit. Default is `Outside`. */
    public function yAxisLabelPlacement(placement:AxisLabelPlacement):AreaChart<T> {
        axes.yAxisLabelPlacement = placement;
        return this;
    }

    /** Set how many ticks the y axis carries (at least 2). Default is 5. */
    public function yTickCount(count:Int):AreaChart<T> {
        axes.yTickCount = count > 2 ? count : 2;
        return this;
    }

    /** Set the text of each y-axis tick label from the value at its tick. */
    public function yTickFormat(format:(Float) -> String):AreaChart<T> {
        axes.yTickFormat = format;
        return this;
    }

    /** Label `count` of the x values, spread evenly from the first to the last. */
    public function xTickCount(count:Int):AreaChart<T> {
        axes.xTickCount = count;
        return this;
    }

    /** Divide the plot into `count` columns with vertical grid lines. Default is 0. */
    public function gridColumns(count:Int):AreaChart<T> {
        axes.gridColumns = count;
        return this;
    }

    /** Draw the grid dashed or solid. Default is true. */
    public function gridDashed(dashed:Bool):AreaChart<T> {
        axes.gridDashed = dashed;
        return this;
    }

    /** Draw a dashed line across the plot at `value`. Call again for more lines. */
    public function referenceLine(value:Float):AreaChart<T> {
        axes.referenceLines.push(value);
        return this;
    }

    /** Set the space kept clear above the highest value and below the lowest. */
    public function yPadding(top:Float, bottom:Float):AreaChart<T> {
        axes.yPadding = [top, bottom];
        return this;
    }

    function axisGap():Float {
        return xAxisValue ? Chart.AXIS_GAP : 0.;
    }

    /**
     * Build the x (point) and y (linear) scales for the given bounds. Null
     * when there is no x accessor or no series.
     */
    @:allow(tests)
    function scales(bounds:Bounds):Null<{x:ScalePoint<String>, y:ScaleLinear, extent:ValueExtent}> {
        if (xFn == null || yFns.length == 0) {
            return null;
        }
        final xFn = this.xFn;
        final width = bounds.size.width;
        final height = f(bounds.size.height - axisGap());
        final len = data.length;
        final x = new ScalePoint([for (v in data) xFn(v)], Chart.pointRange(axes.plotLeft(), f(width - axes.plotLeft()), len, Chart.axisPointCount(pointCountValue, len)));
        final values = [for (v in data) for (yFn in yFns) yFn(v)];
        final y = Chart.pointValueScale(values, yDomainValue, height, axes.yPadding);
        return {x: x, y: y.scale, extent: y.extent};
    }

    override public function prepaint(bounds:Bounds, window:Window, cx:App):Array<AnyElement> {
        final scales = scales(bounds);
        if (scales != null) {
            axes.measureYLabels(scales.extent, f(bounds.size.height - axisGap()), window);
        }
        return [];
    }

    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        if (xFn == null) {
            return;
        }
        final xFn = this.xFn;
        final scales = scales(bounds);
        if (scales == null) {
            return;
        }
        final theme = Theme.global(cx);
        final height = f(bounds.size.height - axisGap());

        final left = axes.plotLeft();
        final axisBounds = new Bounds(new Point(f(bounds.origin.x + left), bounds.origin.y), new Size(f(bounds.size.width - left), bounds.size.height));
        var axis = new PlotAxis().stroke(theme.border);
        if (xAxisValue) {
            final pointCount = Chart.axisPointCount(pointCountValue, data.length);
            final labeled = Chart.labeledItems(pointCount, axes.xTickCount, tickMarginValue);
            final labels = Chart.buildPointXLabels(data, xFn, scales.x, pointCount, labeled, theme.mutedForeground);
            for (label in labels) {
                label.tick = f(label.tick - left);
            }
            axis = axis.x(height).xLabel(labels);
        }
        axis.paint(axisBounds, window, cx);

        if (gridValue) {
            axes.paintGrid(bounds, height, window, cx);
        }

        // Draw area
        final defaultFill = Background.fromHsla(theme.chart2.opacity(0.4));
        final defaultStroke = theme.chart2;
        final xScale = scales.x;
        final yScale = scales.y;
        final data = this.data;
        final indices = [for (i in 0...data.length) i];
        final areas = [
            for (i in 0...yFns.length) {
                final yFn = yFns[i];
                final fill = i < fills.length ? fills[i] : defaultFill;
                final stroke = i < strokes.length ? strokes[i] : defaultStroke;
                final curve:Curve = i < curves.length ? curves[i] : (curves.length > 0 ? curves[0] : Natural);
                new Area<Int>()
                    // One x domain entry per datum: project by index, not by lookup.
                    .data(indices)
                    .x(i -> xScale.tickAt(i))
                    .y0(height)
                    .y1(i -> yScale.tick(yFn(data[i])))
                    .stroke(stroke)
                    .curve(curve)
                    .fill(fill);
            }
        ];

        final mask = yDomainValue != null ? Chart.pinnedPlotMask(bounds, height) : null;
        // The areas draw in from the left under a mask, so their shapes, and
        // the cached paths, stay the same on every frame of the appear.
        final reveal = Chart.revealMask(bounds, left, appearValue.get().progress());
        window.withContentMask(mask, window -> {
            window.withContentMask(reveal, window -> {
                final caches = PathCaches.forPaint('areas', window, cx);
                for (i in 0...areas.length) {
                    final pair = caches.slotPair(i);
                    areas[i].paintCached(bounds, pair[0], pair[1], window);
                }
                return true;
            });
            return true;
        });

        axes.paintReferenceLines(scales.extent, bounds, height, window, cx);
        axes.paintYLabels(scales.extent, bounds, height, window, cx);
    }

    override public function plotId():Null<ElementId> {
        return idValue;
    }

    override public function isInteractive():Bool {
        return interactiveValue;
    }

    override public function updateAppear(appear:PlotAppear, window:Window, cx:App):Void {
        appearValue.update(appear);
    }

    override public function appearGeneration():Null<String> {
        return appearValue.generation();
    }

    override public function tooltipState(position:Point, bounds:Bounds, cx:App):Null<TooltipState> {
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

        // One dot per series at the hovered x.
        final dots:Array<Point> = [];
        for (yFn in yFns) {
            final y = scales.y.tick(yFn(d));
            if (y != null) {
                dots.push(new Point(xTick, y));
            }
        }

        return new TooltipState(index, new Point(xTick, position.y), dots);
    }

    override public function tooltip(state:TooltipState, cursor:Point, bounds:Bounds, window:Window, cx:App):Null<AnyElement> {
        if (xFn == null) {
            return null;
        }
        final xFn = this.xFn;
        if (state.index >= data.length) {
            return null;
        }
        final d = data[state.index];
        final theme = Theme.global(cx);
        final defaultColor = theme.chart2;
        final dotStroke = theme.background;
        final color = (i:Int) -> i < strokes.length ? strokes[i] : defaultColor;

        // Follow the cursor; the crosshair and dots glide to the data point.
        final tooltip = new Tooltip(cursor, bounds.size)
            .gap(8.)
            // Confine the crosshair to the plot area so it doesn't cross the x-axis.
            .crossLine(new CrossLine(state.crossLine).height(f(bounds.size.height - axisGap())))
            .dots([
                for (i in 0...state.dots.length)
                    new Dot(state.dots[i])
                        .size(Chart.HOVER_DOT_SIZE)
                        .halo(Chart.HOVER_HALO_SIZE)
                        .stroke(dotStroke)
                        .fill(color(i))
            ]);

        final result = tooltipContentValue.apply(tooltip, d, () -> xFn(d), () -> [
            // One row per series: swatch + label + value.
            for (i in 0...yFns.length) {swatch: color(i), name: i < names.length ? names[i] : '', value: yFns[i](d)}
        ], window, cx);
        return result != null ? (result : IntoElement).intoAnyElement() : null;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

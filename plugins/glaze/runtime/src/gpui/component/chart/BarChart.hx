// Ported from gpui-kit 0.8.1: crates/component/src/chart/bar_chart.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.chart;

import gpui.AnyElement;
import gpui.App;
import gpui.Background;
import gpui.Bounds;
import gpui.Corners;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Hsla;
import gpui.IntoBackground;
import gpui.IntoElement;
import gpui.IntoHsla;
import gpui.LinearColorStop;
import gpui.Pixels;
import gpui.Point;
import gpui.Size;
import gpui.SpringMath;
import gpui.TextAlign;
import gpui.Window;
import gpui.base.motion.TransitionId;
import gpui.base.plot.Grid;
import gpui.base.plot.Plot;
import gpui.base.plot.PlotAppear;
import gpui.base.plot.PlotAxis;
import gpui.base.plot.PlotAxis.AxisLabelPlacement;
import gpui.base.plot.PlotAxis.AxisLabelSide;
import gpui.base.plot.PlotAxis.AxisText;
import gpui.base.plot.PlotHover;
import gpui.base.plot.PlotLabel;
import gpui.base.plot.PlotLabel.Text;
import gpui.base.plot.TooltipState;
import gpui.base.plot.scale.ScaleBand;
import gpui.base.plot.scale.ScaleLinear;
import gpui.base.plot.shape.Bar;
import gpui.base.plot.shape.Bar.BarAlignment;
import gpui.component.chart.Chart.ChartAppear;
import gpui.component.chart.Chart.TooltipContent;
import gpui.component.plot.Tooltip;
import gpui.component.plot.Tooltip.CrossLine;
import gpui.component.theme.Theme;

import gpui.Prelude.linearGradient;

/**
 * The hover a bar chart paints, sampled once per frame in `updateHover`.
 */
private class BarHover {

    /** Cross-axis center of the highlight band, gliding between bars. */
    public final center:Float;

    /** How far the hover has faded in. */
    public final focus:Float;

    public function new(center:Float, focus:Float) {
        this.center = center;
        this.focus = focus;
    }

}

/**
 * A bar chart: one bar per datum along a band axis (Rust
 * `BarChart<T, B, V>`: the band `B` is a `String` and the value `V` a
 * `Float` here).
 *
 * `fillGradient` receives the chart's data range as two numbers (Rust
 * passes a `RangeInclusive<f32>`).
 */
class BarChart<T> extends Plot {

    /** How much the bars away from the hovered one fade, as a share of their opacity. */
    static final HOVER_DIM:Float = SpringMath.f32(0.45);

    /** `f32::EPSILON` */
    static inline final F32_EPSILON:Float = 1.1920928955078125e-7;

    final data:Array<T>;

    var bandFn:Null<(T) -> String> = null;

    var valueFn:Null<(T) -> Float> = null;

    var fillFn:Null<(T, Bounds, Bounds, BarAlignment) -> Background> = null;

    var fillGradientFn:Null<(T, Float, Float, (Float) -> Float) -> Array<LinearColorStop>> = null;

    var tickMarginValue:Int = 1;

    var labelFn:Null<(T) -> String> = null;

    var labelColorFn:Null<(T) -> Hsla> = null;

    var labelAxisValue:Bool = true;

    var valueAxisValue:Bool = false;

    var valueAxisLabelPlacementValue:AxisLabelPlacement = Outside;

    var valueTickCountValue:Int = 5;

    var valueTickFormatFn:Null<(Float) -> String> = null;

    var bandCountValue:Null<Int> = null;

    var bandTickCountValue:Null<Int> = null;

    var gridValue:Bool = true;

    var gridDashedValue:Bool = true;

    var alignmentValue:BarAlignment = Bottom;

    var cornerRadiiValue:Corners = Corners.all(0.);

    var paddingInnerValue:Float = 0.4;

    var paddingOuterValue:Float = 0.2;

    var maxBandWidthValue:Float = Chart.MAX_BAND_WIDTH;

    var minLengthValue:Float = 0.;

    var idValue:ElementId;

    var interactiveValue:Bool = true;

    final appearValue:ChartAppear = new ChartAppear();

    var nameValue:Null<String> = null;

    final tooltipContentValue:TooltipContent<T> = new TooltipContent();

    /**
     * The label gaps `(band side, value end side)` of horizontal bars,
     * measured in `prepaint` for the frame.
     */
    var horizontalGaps:Array<Float> = [0., 0.];

    /** The value-axis gutter of vertical bars, measured in `prepaint`. */
    var valueLabelGap:Float = Chart.VALUE_AXIS_GAP;

    var hover:Null<BarHover> = null;

    public function new(data:Iterable<T>, ?pos:haxe.PosInfos) {
        super();
        this.data = [for (d in data) d];
        idValue = Chart.callerId(pos);
    }

    /** Name this chart's `ElementId`, replacing the default taken from the construction site. */
    public function id(id:ElementIdArg):BarChart<T> {
        idValue = id;
        return this;
    }

    /** Turn this chart's interactive layer on or off. On by default. */
    public function interactive(interactive:Bool):BarChart<T> {
        interactiveValue = interactive;
        return this;
    }

    /** Draw the data in the first time this chart is painted. On by default. */
    public function appear(appear:Bool):BarChart<T> {
        appearValue.setEnabled(appear);
        return this;
    }

    /** Draw the data in again whenever `key` changes. */
    public function appearKey(key:String):BarChart<T> {
        appearValue.setKey(key);
        return this;
    }

    /** Set the series name shown in the hover tooltip row. */
    public function name(name:String):BarChart<T> {
        nameValue = name;
        return this;
    }

    /** Set the hover tooltip's title for a datum, instead of its band. */
    public function tooltipTitle(title:(T) -> String):BarChart<T> {
        tooltipContentValue.setTitle(title);
        return this;
    }

    /** Set the text of the tooltip row's value; the raw number by default. */
    public function tooltipValue(value:(T, Float) -> String):BarChart<T> {
        tooltipContentValue.setValue((d, _, v) -> value(d, v));
        return this;
    }

    /** Color the tooltip row's value; the tooltip's text color by default. */
    public function tooltipValueColor(color:(T, Float) -> IntoHsla):BarChart<T> {
        tooltipContentValue.setValueColor((d, _, v) -> (color(d, v) : Hsla));
        return this;
    }

    /** Draw the tooltip box's content for a datum yourself, in place of the title and rows. */
    public function tooltipContent(content:(T, Window, App) -> IntoElement):BarChart<T> {
        tooltipContentValue.setContent(content);
        return this;
    }

    public function band(band:(T) -> String):BarChart<T> {
        bandFn = band;
        return this;
    }

    public function value(value:(T) -> Float):BarChart<T> {
        valueFn = value;
        return this;
    }

    /**
     * Set the fill of each bar from the datum, its frame, the chart's frame
     * (both relative to the chart origin) and the alignment. Replaces a
     * `fillGradient`.
     */
    public function fill(fill:(T, Bounds, Bounds, BarAlignment) -> IntoBackground):BarChart<T> {
        fillFn = (t, bar, chart, alignment) -> (fill(t, bar, chart, alignment) : Background);
        fillGradientFn = null;
        return this;
    }

    /**
     * Set a two-stop gradient per bar from the datum, the chart's data range
     * (`lo`, `hi`) and a function mapping a chart value to the bar's own
     * `0..1`. Replaces a `fill`.
     */
    public function fillGradient(fill:(T, Float, Float, (Float) -> Float) -> Array<LinearColorStop>):BarChart<T> {
        fillGradientFn = fill;
        fillFn = null;
        return this;
    }

    public function tickMargin(tickMargin:Int):BarChart<T> {
        tickMarginValue = tickMargin;
        return this;
    }

    public function label(label:(T) -> String):BarChart<T> {
        labelFn = label;
        return this;
    }

    public function labelColor(color:(T) -> IntoHsla):BarChart<T> {
        labelColorFn = t -> (color(t) : Hsla);
        return this;
    }

    public function labelAxis(labelAxis:Bool):BarChart<T> {
        labelAxisValue = labelAxis;
        return this;
    }

    public function valueAxis(valueAxis:Bool):BarChart<T> {
        valueAxisValue = valueAxis;
        return this;
    }

    public function valueTickCount(count:Int):BarChart<T> {
        valueTickCountValue = count > 2 ? count : 2;
        return this;
    }

    public function valueAxisLabelPlacement(placement:AxisLabelPlacement):BarChart<T> {
        valueAxisLabelPlacementValue = placement;
        return this;
    }

    public function valueTickFormat(format:(Float) -> String):BarChart<T> {
        valueTickFormatFn = format;
        return this;
    }

    public function bandCount(count:Int):BarChart<T> {
        bandCountValue = count;
        return this;
    }

    public function bandTickCount(count:Int):BarChart<T> {
        bandTickCountValue = count;
        return this;
    }

    public function grid(grid:Bool):BarChart<T> {
        gridValue = grid;
        return this;
    }

    public function gridDashed(dashed:Bool):BarChart<T> {
        gridDashedValue = dashed;
        return this;
    }

    public function alignment(alignment:BarAlignment):BarChart<T> {
        alignmentValue = alignment;
        return this;
    }

    public function cornerRadii(cornerRadii:Corners):BarChart<T> {
        cornerRadiiValue = cornerRadii;
        return this;
    }

    public function paddingInner(padding:Float):BarChart<T> {
        paddingInnerValue = padding;
        return this;
    }

    public function paddingOuter(padding:Float):BarChart<T> {
        paddingOuterValue = padding;
        return this;
    }

    public function maxBandWidth(width:Pixels):BarChart<T> {
        maxBandWidthValue = width;
        return this;
    }

    public function minLength(length:Float):BarChart<T> {
        minLengthValue = length;
        return this;
    }

    @:allow(tests)
    function bandScale(bounds:Bounds):Null<ScaleBand<String>> {
        if (bandFn == null) {
            return null;
        }
        final bandFn = this.bandFn;
        final bandExtent = alignmentValue.isHorizontal() ? bounds.size.height : bounds.size.width;
        // Value-axis labels eat into the band extent at one end;
        // `bandOffset` shifts the bands away from that end when it is the
        // leading one.
        final extent = Math.max(f(bandExtent - valueAxisGap()), 0.);
        return new ScaleBand([for (v in data) bandFn(v)], [0., extent])
            .bandCount(bandCountValue != null ? bandCountValue : 0)
            .maxBandWidth(maxBandWidthValue)
            .paddingInner(paddingInnerValue)
            .paddingOuter(paddingOuterValue);
    }

    function bandOffset():Float {
        return alignmentValue.isHorizontal() ? 0. : valueAxisGap();
    }

    function valueScale(bounds:Bounds):Null<{scale:ScaleLinear, baseline:Float, far:Float}> {
        if (valueFn == null) {
            return null;
        }
        final valueFn = this.valueFn;
        final valueDim = alignmentValue.isHorizontal() ? bounds.size.width : bounds.size.height;
        final axisGap = labelAxisValue ? Chart.AXIS_GAP : 0.;
        // Vertical bars keep a line of text clear past the tallest bar when
        // they carry value labels, so the label above it stays inside the
        // chart.
        final farGap = labelFn != null ? PlotLabel.TEXT_HEIGHT : 10.;
        final bandGap = alignmentValue.isHorizontal() ? horizontalGaps[0] : axisGap;
        final valueEndGap = alignmentValue.isHorizontal() ? horizontalGaps[1] : farGap;
        // The baseline, and the far edge opposite it.
        var baseline:Float;
        var far:Float;
        switch alignmentValue {
            case Bottom:
                baseline = f(valueDim - axisGap);
                far = farGap;
            case Top:
                baseline = axisGap;
                far = f(valueDim - farGap);
            case Left:
                baseline = bandGap;
                far = f(valueDim - valueEndGap);
            case Right:
                baseline = f(valueDim - bandGap);
                far = valueEndGap;
        }
        final values = [for (v in data) valueFn(v)];
        values.push(0.);
        return {scale: new ScaleLinear(values, [baseline, far]), baseline: baseline, far: far};
    }

    @:allow(tests)
    function barFrame(d:T, bandScale:ScaleBand<String>, bounds:Bounds):Null<Bounds> {
        if (bandFn == null || valueFn == null) {
            return null;
        }
        final value = valueScale(bounds);
        if (value == null) {
            return null;
        }
        final zeroTick = value.scale.tick(0.);
        final zero = zeroTick != null ? zeroTick : value.baseline;
        final tick = bandScale.tick(bandFn(d));
        if (tick == null) {
            return null;
        }
        final cross = f(tick + bandOffset());
        final end = barEnd(value.scale, valueFn(d), zero, alignmentValue, minLengthValue);
        if (end == null) {
            return null;
        }
        final lo = Math.min(end, zero);
        final length = Math.abs(f(end - zero));
        final bandWidth = bandScale.bandWidth();
        return alignmentValue.isHorizontal()
            ? new Bounds(new Point(lo, cross), new Size(length, bandWidth))
            : new Bounds(new Point(cross, lo), new Size(bandWidth, length));
    }

    /** The data range `fillGradient` reads, the same for every bar. */
    function gradientRange():Array<Float> {
        if (valueFn == null) {
            return [0., 0.];
        }
        var lo = 0.;
        var hi = 0.;
        for (v in data) {
            final value = f(valueFn(v));
            lo = Math.min(lo, value);
            hi = Math.max(hi, value);
        }
        return [lo, hi];
    }

    /**
     * The color a tooltip row shows for datum `d`: its bar's, the first
     * stop of a gradient, or the default fill when `fill` returns a
     * gradient, whose stops can't be read back.
     */
    @:allow(tests)
    function barColor(d:T, frame:Bounds, bounds:Bounds, cx:App):Hsla {
        final theme = Theme.global(cx);
        final fallback = theme.chart2;
        if (fillGradientFn != null) {
            final value = valueFn != null ? f(valueFn(d)) : 0.;
            final range = gradientRange();
            return barGradient(fillGradientFn, d, value, range)[0].color;
        }
        if (fillFn == null) {
            return fallback;
        }
        final chartBounds = new Bounds(new Point(0, 0), new Size(bounds.size.width, bounds.size.height));
        final solid = fillFn(d, frame, chartBounds, alignmentValue).asSolid();
        return solid != null ? solid : fallback;
    }

    /**
     * The gutter the value-axis labels take along the band axis: none unless
     * they are shown outside the plot.
     */
    @:allow(tests)
    function valueAxisGap():Float {
        if (!valueAxisValue || valueAxisLabelPlacementValue != Outside) {
            return 0.;
        }
        // Below the plot for horizontal bars, where the gap is a line of text tall.
        return alignmentValue.isHorizontal() ? Chart.VALUE_AXIS_GAP : valueLabelGap;
    }

    /** The bands the band axis is laid out for: the data's, or the band count when larger. */
    @:allow(tests)
    function bandSlots():Int {
        final count:Int = bandCountValue != null ? bandCountValue : 0;
        return count > data.length ? count : data.length;
    }

    /**
     * The value-axis tick label text, from the domain maximum at the far end
     * down to the minimum at the baseline, matching the value scale.
     */
    @:allow(tests)
    function valueTickLabels():Array<String> {
        if (valueFn == null) {
            return [];
        }
        // The data plus zero, as `valueScale` spans.
        var lo = 0.;
        var hi = 0.;
        for (v in data) {
            final value = f(valueFn(v));
            lo = Math.min(lo, value);
            hi = Math.max(hi, value);
        }
        final steps = valueTickCountValue - 1;
        return [
            for (i in 0...valueTickCountValue) {
                final value = f(hi - f(f(f(hi - lo) * i) / steps));
                valueTickFormatFn != null ? valueTickFormatFn(value) : Chart.formatTick(value);
            }
        ];
    }

    /**
     * Label gaps `(band side, value end side)` reserved along the value axis
     * for horizontal bars, measured from the actual label text.
     */
    function measureHorizontalGaps(window:Window):Array<Float> {
        if (bandFn == null) {
            return [0., 0.];
        }
        final fontSize = PlotLabel.TEXT_SIZE;
        var bandGap = 0.;
        if (labelAxisValue) {
            var widest = 0.;
            for (v in data) {
                widest = Math.max(widest, PlotLabel.measureTextWidth(bandFn(v), fontSize, window));
            }
            bandGap = f(widest + PlotLabel.TEXT_GAP * 2.);
        }
        var valueEndGap = PlotLabel.TEXT_GAP * 4.;
        if (labelFn != null) {
            var widest = 0.;
            for (v in data) {
                widest = Math.max(widest, PlotLabel.measureTextWidth(labelFn(v), fontSize, window));
            }
            valueEndGap = f(widest + PlotLabel.TEXT_GAP * 2.);
        }
        return [bandGap, valueEndGap];
    }

    /**
     * The extent `(start, length)` of the bars along the value axis, which
     * the hover is confined to so the axis labels never show a tooltip.
     */
    function valueExtent(bounds:Bounds):Array<Float> {
        if (alignmentValue.isHorizontal()) {
            final bandGap = horizontalGaps[0];
            final valueEndGap = horizontalGaps[1];
            final length = Math.max(f(f(bounds.size.width - bandGap) - valueEndGap), 0.);
            final start = alignmentValue == Left ? bandGap : valueEndGap;
            return [start, length];
        }
        final axisGap = labelAxisValue ? Chart.AXIS_GAP : 0.;
        final length = f(bounds.size.height - axisGap);
        final start = alignmentValue == Top ? axisGap : 0.;
        return [start, length];
    }

    /** Whether the cursor is over a bar's row or column rather than the axis labels. */
    function isOverBars(position:Point, bounds:Bounds):Bool {
        final extent = valueExtent(bounds);
        final start = extent[0];
        final end = f(start + extent[1]);
        if (alignmentValue.isHorizontal()) {
            final valueLabelsTop = f(bounds.size.height - Chart.VALUE_AXIS_GAP);
            return position.x >= start && position.x <= end && !(valueAxisGap() > 0. && position.y > valueLabelsTop);
        }
        return position.y >= start && position.y <= end && position.x >= bandOffset();
    }

    override public function prepaint(bounds:Bounds, window:Window, cx:App):Array<AnyElement> {
        horizontalGaps = alignmentValue.isHorizontal() ? measureHorizontalGaps(window) : [0., 0.];
        if (valueAxisValue && !alignmentValue.isHorizontal()) {
            valueLabelGap = Chart.valueAxisGap(valueTickLabels(), window);
        }
        return [];
    }

    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        if (bandFn == null || valueFn == null) {
            return;
        }
        final bandFn = this.bandFn;
        final valueFn = this.valueFn;
        final theme = Theme.global(cx);

        final totalWidth = bounds.size.width;
        final totalHeight = bounds.size.height;
        final alignment = alignmentValue;
        final isHorizontal = alignment.isHorizontal();

        // Band scale spans the full extent perpendicular to the value axis,
        // shared with the tooltip so the bars and the hover crosshair stay
        // aligned.
        final bandScale = bandScale(bounds);
        if (bandScale == null) {
            return;
        }
        final bandWidth = bandScale.bandWidth();

        final valueScaleResult = valueScale(bounds);
        if (valueScaleResult == null) {
            return;
        }
        final valueScale = valueScaleResult.scale;
        final baseline = valueScaleResult.baseline;
        final far = valueScaleResult.far;

        // Where zero sits along the value axis. Bars grow from here rather
        // than from the geometric baseline, so negative values extend to the
        // opposite side.
        final zeroTick = valueScale.tick(0.);
        final zeroPixel:Float = zeroTick != null ? zeroTick : baseline;
        final bandOffset = this.bandOffset();

        // Grid lines and the zero line span their bounds edge to edge, so
        // they are painted into bounds inset by the value-axis gap.
        final valueAxisGap = this.valueAxisGap();
        final plotBounds = isHorizontal
            ? new Bounds(bounds.origin, new Size(bounds.size.width, f(bounds.size.height - valueAxisGap)))
            : new Bounds(new Point(f(bounds.origin.x + valueAxisGap), bounds.origin.y), new Size(f(bounds.size.width - valueAxisGap), bounds.size.height));

        // Draw band axis (with categorical labels).
        var axis = new PlotAxis().stroke(theme.border);
        if (labelAxisValue) {
            switch alignment {
                case Bottom | Top:
                    axis = axis.x(zeroPixel);

                    // Labels are placed one at a time rather than through
                    // `xLabel`, because a chart with negative values needs
                    // them on either side of the zero line.
                    final labeled = Chart.labeledItems(bandSlots(), bandTickCountValue, tickMarginValue);
                    final labels:Array<Text> = [];
                    for (i in 0...data.length) {
                        if (!labeled[i]) continue;
                        final d = data[i];
                        final bandX = bandScale.tick(bandFn(d));
                        if (bandX == null) continue;
                        final value = f(valueFn(d));
                        final labelY = labelBelowZeroLine(value, alignment)
                            ? f(zeroPixel + PlotLabel.TEXT_GAP)
                            : f(f(zeroPixel - PlotLabel.TEXT_GAP) - PlotLabel.TEXT_SIZE);
                        labels.push(new Text(bandFn(d), new Point(f(f(bandX + bandOffset) + f(bandWidth / 2.)), labelY), theme.mutedForeground).withAlign(Center));
                    }
                    new PlotLabel(labels).paint(bounds, window, cx);
                case Left | Right:
                    final labels = Chart.buildBandLabels(data, bandFn, bandScale, bandWidth, Chart.labeledItems(bandSlots(), bandTickCountValue, tickMarginValue), theme.mutedForeground);
                    final side:AxisLabelSide = alignment == Left ? Start : End;
                    final align:TextAlign = alignment == Left ? Right : Left;
                    axis = axis.y(zeroPixel).yLabelSide(side).yLabel([for (t in labels) t.withAlign(align)]);
            }
        }
        axis.paint(plotBounds, window, cx);

        final valueTicks = valueTickPositions(far, baseline, valueTickCountValue);
        final steps = valueTicks.length - 1;

        // Draw grid, excluding the line at the baseline.
        if (gridValue) {
            var grid = new Grid().stroke(theme.chartGrid);
            if (gridDashedValue) {
                grid = grid.dashArray([4., 2.]);
            }
            final lines = valueTicks.slice(0, steps);
            grid = isHorizontal ? grid.x(lines) : grid.y(lines);
            grid.paint(plotBounds, window);
        }

        // Labels inside the plot are painted after the bars, so no bar covers them.
        var insideLabels:Null<PlotLabel> = null;
        if (valueAxisValue) {
            // Ticks run from `far` (the domain maximum) to `baseline` (the
            // minimum), so the labels walk the domain in the same direction.
            final color = theme.mutedForeground;
            final texts = valueTickLabels();
            switch valueAxisLabelPlacementValue {
                // The labels go in the gap `bandScale` kept clear for them.
                case Outside:
                    final labels = [for (i in 0...texts.length) new AxisText(texts[i], valueTicks[i], color)];
                    final valueAxis = isHorizontal
                        ? new PlotAxis().xAxis(false).x(f(totalHeight - Chart.VALUE_AXIS_GAP)).xLabel([for (t in labels) t.withAlign(Center)])
                        : new PlotAxis().yAxis(false).y(f(valueAxisGap - PlotLabel.TEXT_GAP * 2.)).yLabel([for (t in labels) t.withAlign(Right)]);
                    valueAxis.paint(bounds, window, cx);
                // Over the plot beside each grid line.
                case Inside:
                    final labels = [
                        for (i in 0...texts.length) {
                            final tick = valueTicks[i];
                            if (isHorizontal) {
                                new Text(texts[i], new Point(tick, f(totalHeight - PlotLabel.TEXT_HEIGHT)), color).withAlign(Center);
                            }
                            else {
                                final top = tick < PlotLabel.TEXT_HEIGHT ? f(tick + PlotLabel.TEXT_GAP) : f(tick - PlotLabel.TEXT_HEIGHT);
                                new Text(texts[i], new Point(PlotLabel.TEXT_GAP, top), color);
                            }
                        }
                    ];
                    insideLabels = new PlotLabel(labels);
            }
        }

        // Draw bars.
        final defaultFill = Background.fromHsla(theme.chart2);
        final fill = fillFn;
        final fillGradient = fillGradientFn;
        final labelColor = theme.foreground;
        final labelColorFn = this.labelColorFn;
        final minLength = minLengthValue;

        // Chart bounds in pixel space, with origin (0, 0) and the full chart
        // extent, passed to `fill` functions.
        final chartBounds = new Bounds(new Point(0, 0), new Size(totalWidth, totalHeight));

        // Chart data range in f32, passed to `fillGradient`.
        final chartRange = gradientRange();

        // The hovered bar keeps its color while the others fade behind it.
        final hover = this.hover;
        final step = Math.max(bandScale.step(), F32_EPSILON);
        final emphasis = (frame:Bounds) -> {
            if (hover == null) {
                return 1.;
            }
            final center = isHorizontal ? f(frame.origin.y + f(frame.size.height / 2.)) : f(frame.origin.x + f(frame.size.width / 2.));
            final distance = Math.min(f(Math.abs(f(center - hover.center)) / step), 1.);
            return f(1. - f(f(HOVER_DIM * hover.focus) * distance));
        };

        // Every bar grows out of the zero line together as the chart appears.
        final appear = appearValue.get().progress();

        var bar = new Bar<T>()
            .data(data)
            .alignment(alignment)
            .bandWidth(bandWidth)
            .cross(d -> {
                final t = bandScale.tick(bandFn(d));
                t != null ? f(t + bandOffset) : null;
            })
            .base(_ -> zeroPixel)
            .value(d -> {
                final end = barEnd(valueScale, valueFn(d), zeroPixel, alignment, minLength);
                end != null ? f(zeroPixel + f(f(end - zeroPixel) * appear)) : null;
            })
            .cornerRadii(cornerRadiiValue);

        if (fillGradient != null) {
            bar = bar.fill((d, frame, alignment) -> {
                final v = f(valueFn(d));
                final stops = barGradient(fillGradient, d, v, chartRange);
                final bg:Background = linearGradient(alignment.gradientAngle(), stops[0], stops[1]);
                return bg.opacity(emphasis(frame));
            });
        }
        else if (fill != null) {
            bar = bar.fill((d, frame, alignment) -> fill(d, frame, chartBounds, alignment).opacity(emphasis(frame)));
        }
        else {
            bar = bar.fill((_, frame, _) -> defaultFill.opacity(emphasis(frame)));
        }

        if (labelFn != null) {
            final label = labelFn;
            final textAlign:TextAlign = switch alignment {
                case Bottom | Top: Center;
                case Left: Left;
                case Right: Right;
            };
            bar = bar.label((d, p) -> {
                // A value label rides the end of its bar and fades in with it.
                final color = (labelColorFn != null ? labelColorFn(d) : labelColor).opacity(appear);
                return [new Text(label(d), p, color).withAlign(textAlign)];
            });
        }

        bar.paint(bounds, window, cx);
        if (insideLabels != null) {
            insideLabels.paint(bounds, window, cx);
        }
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
        if (bandFn == null || valueFn == null) {
            return null;
        }
        final bandFn = this.bandFn;

        // Skip the tooltip when the cursor is over the axis labels, not a bar.
        if (!isOverBars(position, bounds)) {
            return null;
        }

        final isHorizontal = alignmentValue.isHorizontal();
        final bandScale = bandScale(bounds);
        if (bandScale == null) {
            return null;
        }
        final bandWidth = bandScale.bandWidth();

        final bandOffset = this.bandOffset();
        final cursorBand = isHorizontal ? position.y : position.x;
        final index = bandScale.nearestIndex(f(cursorBand - bandOffset));
        if (index >= data.length) {
            return null;
        }
        final d = data[index];
        final tick = bandScale.tick(bandFn(d));
        if (tick == null) {
            return null;
        }
        final center = f(f(tick + bandOffset) + f(bandWidth / 2.));

        // Vertical bars: vertical crosshair at the bar's x. Horizontal bars:
        // horizontal crosshair at the bar's y.
        final crossLine = isHorizontal ? new Point(position.x, center) : new Point(center, position.y);

        return new TooltipState(index, crossLine, []);
    }

    override public function updateHover(hover:Null<PlotHover>, window:Window, cx:App):Void {
        if (hover == null) {
            this.hover = null;
            return;
        }
        // The band slides to the hovered bar; on the first hovered frame it
        // adopts the bar instead of travelling from where the last hover
        // ended.
        final target = alignmentValue.isHorizontal() ? hover.state().crossLine.y : hover.state().crossLine.x;
        final center = hover.glide(TransitionId.named('bar-chart', 'band'), target, window, cx);
        this.hover = new BarHover(center, hover.progress());
    }

    override public function tooltip(state:TooltipState, cursor:Point, bounds:Bounds, window:Window, cx:App):Null<AnyElement> {
        if (bandFn == null || valueFn == null) {
            return null;
        }
        final bandFn = this.bandFn;
        final valueFn = this.valueFn;
        if (state.index >= data.length) {
            return null;
        }
        final d = data[state.index];
        final name = nameValue != null ? nameValue : '';

        // Highlight the hovered bar with a translucent band the width of the
        // bar, confined to the plot area and centered where the band has
        // glided to.
        final bandScale = bandScale(bounds);
        if (bandScale == null) {
            return null;
        }
        final bandWidth = bandScale.bandWidth();
        final center = hover == null
            ? state.crossLine
            : (alignmentValue.isHorizontal() ? new Point(state.crossLine.x, hover.center) : new Point(hover.center, state.crossLine.y));
        final extent = valueExtent(bounds);
        final crossLine = alignmentValue.isHorizontal()
            ? new CrossLine(center).horizontal().hSpan(extent[0], extent[1]).band(bandWidth)
            : new CrossLine(center).span(extent[0], extent[1]).band(bandWidth);

        var frame = barFrame(d, bandScale, bounds);
        if (frame == null) {
            frame = new Bounds();
        }
        final swatch = barColor(d, frame, bounds, cx);

        // Follow the cursor; `updateHover` already glides the band.
        final tooltip = new Tooltip(cursor, bounds.size).glide(false).gap(8.).crossLine(crossLine);

        final result = tooltipContentValue.apply(tooltip, d, () -> bandFn(d), () -> [{swatch: swatch, name: name, value: valueFn(d)}], window, cx);
        return result != null ? (result : IntoElement).intoAnyElement() : null;
    }

    /**
     * The end a bar showing `value` reaches along the value axis, at least
     * `minLength` pixels from `zero`.
     */
    static function barEnd(scale:ScaleLinear, value:Float, zero:Float, alignment:BarAlignment, minLength:Float):Null<Float> {
        final tick = scale.tick(value);
        if (tick == null) {
            return null;
        }
        return extendToMinLength(tick, zero, value < 0., alignment, minLength);
    }

    /**
     * Push a bar's value end away from `zero` until the bar is `min` pixels
     * long, in the direction its value grows for `alignment`.
     */
    @:allow(tests)
    static function extendToMinLength(tick:Float, zero:Float, negative:Bool, alignment:BarAlignment, min:Float):Float {
        min = f(min);
        if (Math.abs(f(tick - zero)) >= min) {
            return tick;
        }
        final growsTowardOrigin = alignment == Bottom || alignment == Right;
        return growsTowardOrigin != negative ? f(zero - min) : f(zero + min);
    }

    /**
     * The two stops `fill` gives datum `d` with bar value `value`, mapped
     * from the chart's `range` onto the bar and clipped to it.
     */
    static function barGradient<T>(fill:(T, Float, Float, (Float) -> Float) -> Array<LinearColorStop>, d:T, value:Float, range:Array<Float>):Array<LinearColorStop> {
        final barLo = Math.min(value, 0.);
        final barSpan = Math.max(f(Math.max(value, 0.) - barLo), F32_EPSILON);
        final chartToBar = (chartValue:Float) -> f(f(chartValue - barLo) / barSpan);
        return clipStopsToBar(fill(d, range[0], range[1], chartToBar));
    }

    /**
     * Clip a two-stop gradient to bar-local `[0, 1]`, interpolating colors
     * at the clip points so the on-bar gradient matches the (possibly
     * broader) gradient the caller defined.
     */
    @:allow(tests)
    static function clipStopsToBar(stops:Array<LinearColorStop>):Array<LinearColorStop> {
        final a = stops[0];
        final b = stops[1];
        final p0 = f(a.percentage);
        final p1 = f(b.percentage);
        final lerp = (t:Float) -> new Hsla(
            f(a.color.h + f(f(b.color.h - a.color.h) * t)),
            f(a.color.s + f(f(b.color.s - a.color.s) * t)),
            f(a.color.l + f(f(b.color.l - a.color.l) * t)),
            f(a.color.a + f(f(b.color.a - a.color.a) * t))
        );
        final span = f(p1 - p0);
        final sample = (target:Float) -> Math.abs(span) < F32_EPSILON ? a.color : lerp(f(f(target - p0) / span));
        final clamp = (p:Float) -> p < 0. ? 0. : (p > 1. ? 1. : p);
        final newA = p0 >= 0. && p0 <= 1. ? a : new LinearColorStop(sample(clamp(p0)), clamp(p0));
        final newB = p1 >= 0. && p1 <= 1. ? b : new LinearColorStop(sample(clamp(p1)), clamp(p1));
        return [newA, newB];
    }

    /**
     * Whether a vertical bar's category label belongs below the zero line:
     * on the side the bar leaves empty. A zero-length bar counts as
     * positive.
     */
    @:allow(tests)
    static function labelBelowZeroLine(value:Float, alignment:BarAlignment):Bool {
        return (value < 0.) == (alignment == Top);
    }

    /**
     * `count` evenly spaced tick positions along the value axis, from `far`
     * (the value domain's maximum) through `baseline` (its minimum).
     */
    @:allow(tests)
    static function valueTickPositions(far:Float, baseline:Float, count:Int):Array<Float> {
        final steps = count - 1;
        return [for (i in 0...count) f(far + f(f(f(baseline - far) * i) / steps))];
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

// Ported from gpui-kit 0.8.1: crates/component/src/chart/candlestick_chart.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.chart;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Pixels;
import glaze.Point;
import glaze.SpringMath;
import glaze.Window;
import glaze.kit.base.plot.Grid;
import glaze.kit.base.plot.Plot;
import glaze.kit.base.plot.PlotAppear;
import glaze.kit.base.plot.PlotAxis;
import glaze.kit.base.plot.TooltipState;
import glaze.kit.base.plot.scale.ScaleBand;
import glaze.kit.base.plot.scale.ScaleLinear;
import glaze.kit.I18n;
import glaze.kit.chart.Chart.ChartAppear;
import glaze.kit.chart.Chart.TooltipContent;
import glaze.kit.plot.Tooltip;
import glaze.kit.plot.Tooltip.CrossLine;
import glaze.kit.theme.Theme;

import glaze.Prelude.fill;

/**
 * A candlestick chart: one open, high, low and close candle per datum
 * (Rust `CandlestickChart<T, X, Y>`: `X` is a `String` and `Y` a `Float`
 * here).
 */
class CandlestickChart<T> extends Plot {

    final data:Array<T>;

    var xFn:Null<(T) -> String> = null;

    var openFn:Null<(T) -> Float> = null;

    var highFn:Null<(T) -> Float> = null;

    var lowFn:Null<(T) -> Float> = null;

    var closeFn:Null<(T) -> Float> = null;

    var tickMarginValue:Int = 1;

    var bodyWidthRatioValue:Float = SpringMath.f32(0.8);

    var maxBandWidthValue:Float = Chart.MAX_BAND_WIDTH;

    var xAxisValue:Bool = true;

    var gridValue:Bool = true;

    var bullishValue:Null<Hsla> = null;

    var bearishValue:Null<Hsla> = null;

    var idValue:ElementId;

    var interactiveValue:Bool = true;

    final appearValue:ChartAppear = new ChartAppear();

    final tooltipContentValue:TooltipContent<T> = new TooltipContent();

    public function new(data:Iterable<T>, ?pos:haxe.PosInfos) {
        super();
        this.data = glaze.util.Iterables.toArray(data);
        idValue = Chart.callerId(pos);
    }

    /** Name this chart's `ElementId`, replacing the default taken from the construction site. */
    public function id(id:ElementIdArg):CandlestickChart<T> {
        idValue = id;
        return this;
    }

    /** Turn this chart's interactive layer on or off. On by default. */
    public function interactive(interactive:Bool):CandlestickChart<T> {
        interactiveValue = interactive;
        return this;
    }

    /** Draw the data in the first time this chart is painted. On by default. */
    public function appear(appear:Bool):CandlestickChart<T> {
        appearValue.setEnabled(appear);
        return this;
    }

    /** Draw the data in again whenever `key` changes. */
    public function appearKey(key:String):CandlestickChart<T> {
        appearValue.setKey(key);
        return this;
    }

    /** Set the hover tooltip's title for a datum, instead of its x value. */
    public function tooltipTitle(title:(T) -> String):CandlestickChart<T> {
        tooltipContentValue.setTitle(title);
        return this;
    }

    /** Set the text of each tooltip row's value (open, high, low, close); the raw number by default. */
    public function tooltipValue(value:(T, Int, Float) -> String):CandlestickChart<T> {
        tooltipContentValue.setValue(value);
        return this;
    }

    /** Color each tooltip row's value; the tooltip's text color by default. */
    public function tooltipValueColor(color:(T, Int, Float) -> IntoHsla):CandlestickChart<T> {
        tooltipContentValue.setValueColor((d, ix, v) -> (color(d, ix, v) : Hsla));
        return this;
    }

    /** Draw the tooltip box's content for a datum yourself, in place of the title and rows. */
    public function tooltipContent(content:(T, Window, App) -> IntoElement):CandlestickChart<T> {
        tooltipContentValue.setContent(content);
        return this;
    }

    public function x(x:(T) -> String):CandlestickChart<T> {
        xFn = x;
        return this;
    }

    public function open(open:(T) -> Float):CandlestickChart<T> {
        openFn = open;
        return this;
    }

    public function high(high:(T) -> Float):CandlestickChart<T> {
        highFn = high;
        return this;
    }

    public function low(low:(T) -> Float):CandlestickChart<T> {
        lowFn = low;
        return this;
    }

    public function close(close:(T) -> Float):CandlestickChart<T> {
        closeFn = close;
        return this;
    }

    public function tickMargin(tickMargin:Int):CandlestickChart<T> {
        tickMarginValue = tickMargin;
        return this;
    }

    public function bodyWidthRatio(ratio:Float):CandlestickChart<T> {
        bodyWidthRatioValue = f(ratio);
        return this;
    }

    public function maxBandWidth(width:Pixels):CandlestickChart<T> {
        maxBandWidthValue = width;
        return this;
    }

    public function xAxis(xAxis:Bool):CandlestickChart<T> {
        xAxisValue = xAxis;
        return this;
    }

    public function grid(grid:Bool):CandlestickChart<T> {
        gridValue = grid;
        return this;
    }

    public function bullish(color:IntoHsla):CandlestickChart<T> {
        bullishValue = color;
        return this;
    }

    public function bearish(color:IntoHsla):CandlestickChart<T> {
        bearishValue = color;
        return this;
    }

    function candleColors(cx:App):Array<Hsla> {
        final theme = Theme.global(cx);
        return [bullishValue != null ? bullishValue : theme.chartBullish, bearishValue != null ? bearishValue : theme.chartBearish];
    }

    function xScale(bounds:Bounds):Null<ScaleBand<String>> {
        if (xFn == null) {
            return null;
        }
        final xFn = this.xFn;
        return new ScaleBand([for (v in data) xFn(v)], [0., bounds.size.width])
            .maxBandWidth(maxBandWidthValue)
            .paddingInner(0.4)
            .paddingOuter(0.2);
    }

    function plotHeight(bounds:Bounds):Float {
        return f(bounds.size.height - (xAxisValue ? Chart.AXIS_GAP : 0.));
    }

    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        if (xFn == null || openFn == null || highFn == null || lowFn == null || closeFn == null) {
            return;
        }
        final xFn = this.xFn;
        final openFn = this.openFn;
        final highFn = this.highFn;
        final lowFn = this.lowFn;
        final closeFn = this.closeFn;
        final theme = Theme.global(cx);

        final height = plotHeight(bounds);

        // X scale
        final x = xScale(bounds);
        if (x == null) {
            return;
        }
        final bandWidth = x.bandWidth();

        // Y scale
        final allValues = [for (d in data) for (v in [highFn(d), lowFn(d), openFn(d), closeFn(d)]) v];
        final y = new ScaleLinear(allValues, [height, 10.]);

        // Draw X axis
        var axis = new PlotAxis().stroke(theme.border);
        if (xAxisValue) {
            final labels = Chart.buildBandLabels(data, xFn, x, bandWidth, Chart.labeledItems(data.length, null, tickMarginValue), theme.mutedForeground);
            axis = axis.x(height).xLabel(labels);
        }
        axis.paint(bounds, window, cx);

        // Draw grid
        if (gridValue) {
            new Grid()
                .y([for (i in 0...4) f(f(height * i) / 4.0)])
                .stroke(theme.border)
                .dashArray([4., 2.])
                .paint(bounds, window);
        }

        // Draw candlesticks
        final colors = candleColors(cx);
        final bullish = colors[0];
        final bearish = colors[1];
        final origin = bounds.origin;

        // The candles draw in from the left under a mask.
        final reveal = Chart.revealMask(bounds, 0., appearValue.get().progress());
        window.withContentMask(reveal, window -> {
            for (d in data) {
                final xTick = x.tick(xFn(d));
                if (xTick == null) continue;

                // Get OHLC values for the current data point
                final open = openFn(d);
                final high = highFn(d);
                final low = lowFn(d);
                final close = closeFn(d);

                // Convert values to pixel coordinates
                final openY = y.tick(open);
                final highY = y.tick(high);
                final lowY = y.tick(low);
                final closeY = y.tick(close);
                if (openY == null || highY == null || lowY == null || closeY == null) continue;

                // Determine if bullish (close > open) or bearish (close < open)
                final isBullish = close > open;
                final color = isBullish ? bullish : bearish;

                // Calculate candlestick body dimensions
                final centerX = f(xTick + f(bandWidth / 2.));
                final bodyWidth = f(bandWidth * bodyWidthRatioValue);
                final bodyLeft = f(centerX - f(bodyWidth / 2.));
                final bodyRight = f(centerX + f(bodyWidth / 2.));

                // Draw wick (high to low line): a 1px quad, so no stroke to tessellate.
                final wickTop = Math.min(highY, lowY);
                final wickBottom = Math.max(highY, lowY);
                final wickBounds = Chart.fromCorners(Plot.originPoint(f(centerX - 0.5), wickTop, origin), Plot.originPoint(f(centerX + 0.5), wickBottom, origin));
                window.paintQuad(fill(wickBounds, color));

                // Draw body (open to close rectangle): for bullish the top is
                // the close and the bottom the open, for bearish the reverse.
                final top = isBullish ? closeY : openY;
                final bottom = isBullish ? openY : closeY;

                final bodyBounds = Chart.fromCorners(Plot.originPoint(bodyLeft, top, origin), Plot.originPoint(bodyRight, bottom, origin));
                window.paintQuad(fill(bodyBounds, color));
            }
            return true;
        });
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
        if (xFn == null) {
            return null;
        }
        final xFn = this.xFn;
        final x = xScale(bounds);
        if (x == null) {
            return null;
        }

        // Ignore the x-axis label gutter so hovering the labels doesn't show a tooltip.
        if (position.y > plotHeight(bounds)) {
            return null;
        }

        final index = x.nearestIndex(position.x);
        if (index >= data.length) {
            return null;
        }
        final d = data[index];
        final tick = x.tick(xFn(d));
        if (tick == null) {
            return null;
        }
        final center = f(tick + f(x.bandWidth() / 2.));

        return new TooltipState(index, new Point(center, position.y), []);
    }

    override public function tooltip(state:TooltipState, cursor:Point, bounds:Bounds, window:Window, cx:App):Null<AnyElement> {
        if (xFn == null || openFn == null || highFn == null || lowFn == null || closeFn == null || state.index >= data.length) {
            return null;
        }
        final xFn = this.xFn;
        final highFn = this.highFn;
        final lowFn = this.lowFn;
        final d = data[state.index];
        final open = openFn(d);
        final close = closeFn(d);
        final colors = candleColors(cx);
        final color = close > open ? colors[0] : colors[1];

        // Highlight the hovered candle with a translucent band the width of
        // its slot, confined to the plot area above the axis labels.
        final x = xScale(bounds);
        if (x == null) {
            return null;
        }
        final crossLine = new CrossLine(state.crossLine).span(0., plotHeight(bounds)).band(x.bandWidth());

        final tooltip = new Tooltip(cursor, bounds.size).gap(8.).crossLine(crossLine);
        final result = tooltipContentValue.apply(tooltip, d, () -> xFn(d), () -> [
            {swatch: color, name: I18n.t('Chart.open'), value: open},
            {swatch: color, name: I18n.t('Chart.high'), value: highFn(d)},
            {swatch: color, name: I18n.t('Chart.low'), value: lowFn(d)},
            {swatch: color, name: I18n.t('Chart.close'), value: close},
        ], window, cx);
        return result != null ? (result : IntoElement).intoAnyElement() : null;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

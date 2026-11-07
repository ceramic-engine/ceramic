// Ported from gpui-kit 0.8.1: crates/base/src/plot/axis.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.plot;

import gpui.App;
import gpui.Background;
import gpui.Bounds;
import gpui.FontWeight;
import gpui.Hsla;
import gpui.IntoBackground;
import gpui.PathBuilder;
import gpui.Pixels;
import gpui.Point;
import gpui.SpringMath;
import gpui.TextAlign;
import gpui.Window;
import gpui.base.plot.PlotLabel.Text;

/**
 * Which side of an axis line the tick labels render on.
 */
enum abstract AxisLabelSide(Int) {

    /** X-axis: labels below the line. Y-axis: labels right of the line. (Default.) */
    var End = 0;

    /** X-axis: labels above the line. Y-axis: labels left of the line. */
    var Start = 1;

}

/**
 * Where a chart draws the tick labels of its value axis.
 */
enum abstract AxisLabelPlacement(Int) {

    /** In a gutter beside the plot, which the plot shrinks to make room for. (Default.) */
    var Outside = 0;

    /**
     * Over the plot's edge, beside the grid line each label reads, so the
     * plot keeps its full size.
     */
    var Inside = 1;

}

/**
 * A tick label on a `PlotAxis`: its text, where along the axis it sits and
 * how it is drawn. `fontSize` defaults to `TEXT_SIZE`.
 */
class AxisText {

    public final text:String;

    public var tick:Pixels;

    public final color:Hsla;

    public var fontSize:Pixels = PlotLabel.TEXT_SIZE;

    public var align:TextAlign = Left;

    public function new(text:String, tick:Pixels, color:Hsla) {
        this.text = text;
        this.tick = SpringMath.f32(tick);
        this.color = color;
    }

    public function withFontSize(fontSize:Pixels):AxisText {
        this.fontSize = fontSize;
        return this;
    }

    public function withAlign(align:TextAlign):AxisText {
        this.align = align;
        return this;
    }

}

/**
 * Axis lines and their tick labels.
 *
 * The builders only record values: where the lines sit, which side their
 * labels take and the labels themselves are combined when the axis paints,
 * so they can be set in any order.
 */
class PlotAxis {

    /**
     * The x-axis gutter for labels at the default `TEXT_SIZE` (deprecated in
     * gpui-kit 0.7.0: use `axisGutter`).
     */
    public static inline final AXIS_GAP:Float = 18.;

    var xValue:Null<Float> = null;

    var xLabels:Array<AxisText> = [];

    var xAxisValue:Bool = true;

    var xLabelSideValue:AxisLabelSide = End;

    var yValue:Null<Float> = null;

    var yLabels:Array<AxisText> = [];

    var yAxisValue:Bool = false;

    var yLabelSideValue:AxisLabelSide = End;

    var strokeValue:Background = Background.fromHsla(new Hsla());

    public function new() {}

    /**
     * The space below (or above) an x-axis line that tick labels of
     * `fontSize` need: the gap `PlotAxis` leaves between the line and the
     * labels, the labels themselves, and a trailing gap.
     */
    public static function axisGutter(fontSize:Pixels):Float {
        return SpringMath.f32(fontSize + PlotLabel.TEXT_GAP * 4.);
    }

    /**
     * Place the x-axis line at `position` from the top of the plot. Without
     * it the x-axis draws neither its line nor its labels.
     */
    public function x(position:Pixels):PlotAxis {
        xValue = SpringMath.f32(position);
        return this;
    }

    /** Show or hide the x-axis line; its labels are drawn either way. Default is true. */
    public function xAxis(xAxis:Bool):PlotAxis {
        xAxisValue = xAxis;
        return this;
    }

    /** Set the tick labels of the x-axis. */
    public function xLabel(labels:Iterable<AxisText>):PlotAxis {
        xLabels = gpui.util.Iterables.toArray(labels);
        return this;
    }

    /** Set which side of the x-axis line tick labels render on. */
    public function xLabelSide(side:AxisLabelSide):PlotAxis {
        xLabelSideValue = side;
        return this;
    }

    /**
     * Place the y-axis line at `position` from the left of the plot. Without
     * it the y-axis draws neither its line nor its labels.
     */
    public function y(position:Pixels):PlotAxis {
        yValue = SpringMath.f32(position);
        return this;
    }

    /** Show or hide the y-axis line; its labels are drawn either way. Default is false. */
    public function yAxis(yAxis:Bool):PlotAxis {
        yAxisValue = yAxis;
        return this;
    }

    /** Set the tick labels of the y-axis. */
    public function yLabel(labels:Iterable<AxisText>):PlotAxis {
        yLabels = gpui.util.Iterables.toArray(labels);
        return this;
    }

    /** Set which side of the y-axis line tick labels render on. */
    public function yLabelSide(side:AxisLabelSide):PlotAxis {
        yLabelSideValue = side;
        return this;
    }

    /** Set the stroke of the axis lines. */
    public function stroke(stroke:IntoBackground):PlotAxis {
        strokeValue = stroke;
        return this;
    }

    /** The x-axis labels placed against the line at `x`. */
    @:allow(tests)
    function xTexts(x:Float):Array<Text> {
        return [
            for (t in xLabels) {
                final y = switch xLabelSideValue {
                    case End: f(x + PlotLabel.TEXT_GAP * 3.);
                    case Start: f(x - (PlotLabel.TEXT_GAP + PlotLabel.TEXT_HEIGHT));
                };
                axisText(t, new Point(t.tick, y));
            }
        ];
    }

    /** The y-axis labels placed against the line at `y`. */
    @:allow(tests)
    function yTexts(y:Float):Array<Text> {
        return [
            for (t in yLabels) {
                final x = switch yLabelSideValue {
                    case End: f(y + PlotLabel.TEXT_GAP);
                    case Start: f(y - PlotLabel.TEXT_GAP);
                };
                axisText(t, new Point(x, f(t.tick - PlotLabel.TEXT_SIZE / 2.)));
            }
        ];
    }

    function drawAxis(startPoint:Point, endPoint:Point, window:Window):Void {
        final builder = PathBuilder.stroke(1.);
        builder.moveTo(startPoint);
        builder.lineTo(endPoint);
        final path = Plot.buildPath(builder);
        if (path != null) {
            window.paintPath(path, strokeValue);
        }
    }

    /** Paint the Axis. */
    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        final origin = bounds.origin;

        if (xValue != null) {
            final x:Float = xValue;
            if (xAxisValue) {
                drawAxis(Plot.originPoint(0., x, origin), Plot.originPoint(bounds.size.width, x, origin), window);
            }
            new PlotLabel(xTexts(x)).paint(bounds, window, cx);
        }

        if (yValue != null) {
            final y:Float = yValue;
            if (yAxisValue) {
                drawAxis(Plot.originPoint(y, 0., origin), Plot.originPoint(y, bounds.size.height, origin), window);
            }
            new PlotLabel(yTexts(y)).paint(bounds, window, cx);
        }
    }

    /** `label` as the text `PlotLabel` draws at `origin`. */
    static function axisText(label:AxisText, origin:Point):Text {
        return new Text(label.text, origin, label.color)
            .withFontSize(label.fontSize)
            .withFontWeight(FontWeight.NORMAL)
            .withAlign(label.align);
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

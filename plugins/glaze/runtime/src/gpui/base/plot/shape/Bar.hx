// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/bar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.plot.shape;

import gpui.App;
import gpui.Background;
import gpui.Bounds;
import gpui.Corners;
import gpui.IntoBackground;
import gpui.PaintQuad;
import gpui.Point;
import gpui.Size;
import gpui.SpringMath;
import gpui.Window;
import gpui.base.plot.Plot;
import gpui.base.plot.PlotLabel;
import gpui.base.plot.PlotLabel.Text;

import gpui.Prelude.black;

/**
 * Alignment of bars within a `Bar` shape, controlling both the orientation
 * (vertical vs horizontal) and the side where the baseline lives.
 */
enum abstract BarAlignment(Int) {

    /** Vertical bars with the baseline at the bottom; bars grow upward. The default. */
    var Bottom = 0;

    /** Vertical bars with the baseline at the top; bars grow downward. */
    var Top = 1;

    /** Horizontal bars with the baseline at the left; bars grow rightward. */
    var Left = 2;

    /** Horizontal bars with the baseline at the right; bars grow leftward. */
    var Right = 3;

    public inline function isHorizontal():Bool {
        final self:BarAlignment = cast this;
        return self == Left || self == Right;
    }

    public inline function isVertical():Bool {
        return !isHorizontal();
    }

    /**
     * Linear-gradient angle (in degrees) that runs from the bar's base to
     * its tip for this alignment. `0` points upward; angles increase
     * clockwise.
     */
    public function gradientAngle():Float {
        return switch (cast this : BarAlignment) {
            case Bottom: 0.;
            case Top: 180.;
            case Left: 90.;
            case Right: 270.;
        }
    }

}

/**
 * Bars over data: each datum gives a cross-axis position, a baseline and a
 * value end (in pixels relative to the plot bounds).
 */
class Bar<T> {

    var dataValues:Array<T> = [];

    var alignmentValue:BarAlignment = Bottom;

    var crossFn:T->Null<Float> = _ -> null;

    var bandWidthValue:Float = 0.;

    var baseFn:T->Float = _ -> 0.;

    var valueFn:T->Null<Float> = _ -> null;

    var fillFn:(T, Bounds, BarAlignment) -> Background = (_, _, _) -> Background.fromHsla(black());

    var labelFn:Null<(T, Point) -> Array<Text>> = null;

    var cornerRadiiValue:Corners = Corners.all(0.);

    public function new() {}

    /** Set the data of the Bar. */
    public function data(data:Iterable<T>):Bar<T> {
        dataValues = [for (v in data) v];
        return this;
    }

    /** Set the alignment of the Bar. Default is `Bottom`. */
    public function alignment(alignment:BarAlignment):Bar<T> {
        alignmentValue = alignment;
        return this;
    }

    /**
     * Set the cross-axis position of each bar (in pixels): the x coordinate
     * of vertical bars, the y coordinate of horizontal ones.
     */
    public function cross(cross:T->Null<Float>):Bar<T> {
        crossFn = cross;
        return this;
    }

    /** Set the band width of the Bar (the bar thickness along the cross axis). */
    public function bandWidth(bandWidth:Float):Bar<T> {
        bandWidthValue = SpringMath.f32(bandWidth);
        return this;
    }

    /** Set the baseline position of each bar (in pixels along the value axis). */
    public function base(base:T->Float):Bar<T> {
        baseFn = base;
        return this;
    }

    /** Set the value-end position of each bar (in pixels along the value axis). */
    public function value(value:T->Null<Float>):Bar<T> {
        valueFn = value;
        return this;
    }

    /**
     * Set the fill of each bar. The function receives the datum, the bar's
     * painted frame (relative to the plot bounds origin) and the bar's
     * alignment. The background is used verbatim.
     */
    public function fill(fill:(T, Bounds, BarAlignment) -> IntoBackground):Bar<T> {
        fillFn = (v, frame, alignment) -> (fill(v, frame, alignment) : Background);
        return this;
    }

    /** Set the label of the Bar. */
    public function label(label:(T, Point) -> Array<Text>):Bar<T> {
        labelFn = label;
        return this;
    }

    /**
     * Set the corner radii applied to every bar rectangle.
     */
    public function cornerRadii(cornerRadii:Corners):Bar<T> {
        cornerRadiiValue = cornerRadii;
        return this;
    }

    @:allow(tests)
    function path(bounds:Bounds):{graph:Array<PaintQuad>, labels:PlotLabel} {
        final origin = bounds.origin;
        final graph:Array<PaintQuad> = [];
        final labels:Array<Text> = [];

        for (v in dataValues) {
            final crossValue = crossFn(v);
            if (crossValue == null) continue;
            final valueValue = valueFn(v);
            if (valueValue == null) continue;
            final cross = f(crossValue);
            final value = f(valueValue);
            final base = f(baseFn(v));

            final bw = bandWidthValue;
            var frame:Bounds;
            var p1:Point;
            var p2:Point;
            if (alignmentValue.isVertical()) {
                final x0 = cross;
                final x1 = f(cross + bw);
                final yMin = Math.min(value, base);
                final yMax = Math.max(value, base);
                frame = new Bounds(new Point(x0, yMin), new Size(f(x1 - x0), f(yMax - yMin)));
                p1 = Plot.originPoint(x0, yMin, origin);
                p2 = Plot.originPoint(x1, yMax, origin);
            }
            else {
                final y0 = cross;
                final y1 = f(cross + bw);
                final xMin = Math.min(value, base);
                final xMax = Math.max(value, base);
                frame = new Bounds(new Point(xMin, y0), new Size(f(xMax - xMin), f(y1 - y0)));
                p1 = Plot.originPoint(xMin, y0, origin);
                p2 = Plot.originPoint(xMax, y1, origin);
            }

            final bg = fillFn(v, frame, alignmentValue);
            final quad = gpui.Prelude.fill(fromCorners(p1, p2), bg);
            quad.cornerRadii = cornerRadiiValue;
            graph.push(quad);

            if (labelFn != null) {
                final labelOrigin = labelOriginOf(alignmentValue, cross, base, value, bw);
                for (text in labelFn(v, labelOrigin)) {
                    labels.push(text);
                }
            }
        }

        return {graph: graph, labels: new PlotLabel(labels)};
    }

    /** Paint the Bar. */
    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        final result = path(bounds);
        for (quad in result.graph) {
            window.paintQuad(quad);
        }
        result.labels.paint(bounds, window, cx);
    }

    /**
     * Origin point for a bar label, positioned outside the bar at the value
     * end (Rust `label_origin`).
     */
    static function labelOriginOf(alignment:BarAlignment, cross:Float, base:Float, value:Float, bandWidth:Float):Point {
        return switch alignment {
            case Bottom:
                final cx = f(cross + f(bandWidth / 2.));
                // Normal: value < base (bar grows up). Label above bar end.
                value <= base ? new Point(cx, f(value - PlotLabel.TEXT_HEIGHT)) : new Point(cx, f(value + PlotLabel.TEXT_GAP));
            case Top:
                final cx = f(cross + f(bandWidth / 2.));
                // Normal: value > base (bar grows down). Label below bar end.
                value >= base ? new Point(cx, f(value + PlotLabel.TEXT_GAP)) : new Point(cx, f(value - PlotLabel.TEXT_HEIGHT));
            case Left:
                // Vertical centering: text origin is the top of the glyph cell.
                final cy = f(f(cross + f(bandWidth / 2.)) - PlotLabel.TEXT_SIZE / 2.);
                value >= base ? new Point(f(value + PlotLabel.TEXT_GAP), cy) : new Point(f(value - PlotLabel.TEXT_GAP), cy);
            case Right:
                final cy = f(f(cross + f(bandWidth / 2.)) - PlotLabel.TEXT_SIZE / 2.);
                value <= base ? new Point(f(value - PlotLabel.TEXT_GAP), cy) : new Point(f(value + PlotLabel.TEXT_GAP), cy);
        }
    }

    /** `Bounds::from_corners` in `f32`. */
    public static inline function fromCorners(topLeft:Point, bottomRight:Point):Bounds {
        return new Bounds(new Point(topLeft.x, topLeft.y), new Size(f(bottomRight.x - topLeft.x), f(bottomRight.y - topLeft.y)));
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

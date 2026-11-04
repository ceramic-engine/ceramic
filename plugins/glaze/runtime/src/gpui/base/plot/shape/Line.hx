// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/line.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-shape/line
package gpui.base.plot.shape;

import gpui.Background;
import gpui.Bounds;
import gpui.Corners;
import gpui.Edges;
import gpui.Hsla;
import gpui.IntoBackground;
import gpui.IntoHsla;
import gpui.PaintQuad;
import gpui.Path;
import gpui.PathBuilder;
import gpui.Pixels;
import gpui.Point;
import gpui.Size;
import gpui.SpringMath;
import gpui.Window;
import gpui.base.plot.Curve;
import gpui.base.plot.PathCache;
import gpui.base.plot.PathCache.ShapeKey;
import gpui.base.plot.Plot;

import gpui.Prelude.quad;
import gpui.Prelude.transparentBlack;

/**
 * A line through data points (positions in pixels relative to the plot
 * bounds), with optional dots.
 */
class Line<T> {

    var dataValues:Array<T> = [];

    var xFn:(T) -> Null<Float> = _ -> null;

    var yFn:(T) -> Null<Float> = _ -> null;

    var strokeValue:Background = new Background();

    var strokeWidthValue:Float = 1.;

    var curveValue:Curve = Natural;

    var dotValue:Bool = false;

    var dotSizeValue:Float = 4.;

    var dotFillValue:Background = Background.fromHsla(transparentBlack());

    var dotStrokeValue:Null<Hsla> = null;

    public function new() {}

    /** Set the data of the Line. */
    public function data(data:Iterable<T>):Line<T> {
        dataValues = [for (v in data) v];
        return this;
    }

    /** Set the x of the Line. */
    public function x(x:(T) -> Null<Float>):Line<T> {
        xFn = x;
        return this;
    }

    /** Set the y of the Line. */
    public function y(y:(T) -> Null<Float>):Line<T> {
        yFn = y;
        return this;
    }

    /** Set the stroke color of the Line. */
    public function stroke(stroke:IntoBackground):Line<T> {
        strokeValue = stroke;
        return this;
    }

    /** Set the stroke width of the Line. */
    public function strokeWidth(strokeWidth:Pixels):Line<T> {
        strokeWidthValue = SpringMath.f32(strokeWidth);
        return this;
    }

    /** Set how the Line connects its points. Defaults to `Natural`. */
    public function curve(curve:Curve):Line<T> {
        curveValue = curve;
        return this;
    }

    /** Draw a dot on every point. */
    public function dot():Line<T> {
        dotValue = true;
        return this;
    }

    /** Set the size of the dots on the Line. */
    public function dotSize(dotSize:Pixels):Line<T> {
        dotSizeValue = SpringMath.f32(dotSize);
        return this;
    }

    /** Set the fill of the dots on the Line. */
    public function dotFill(fill:IntoBackground):Line<T> {
        dotFillValue = fill;
        return this;
    }

    /**
     * Set the 1px border color of the dots on the Line. Defaults to the dot
     * fill when it is a solid color.
     */
    public function dotStroke(stroke:IntoHsla):Line<T> {
        dotStrokeValue = stroke;
        return this;
    }

    /** Paint the dots on the Line. */
    function paintDot(dot:Point):PaintQuad {
        final solid = dotFillValue.asSolid();
        final border:Hsla = dotStrokeValue != null ? dotStrokeValue : (solid != null ? solid : new Hsla());
        return quad(new Bounds(dot, new Size(dotSizeValue, dotSizeValue)), Corners.all(f(dotSizeValue / 2.)), dotFillValue, Edges.all(1.), border, Solid);
    }

    /** The projected points relative to `origin`, and the dot quads to paint. */
    @:allow(tests)
    function dots(origin:Point):{dots:Array<Point>, paintDots:Array<PaintQuad>} {
        final dots:Array<Point> = [];
        final paintDots:Array<PaintQuad> = [];

        for (v in dataValues) {
            final xTick = xFn(v);
            final yTick = yFn(v);

            if (xTick != null && yTick != null) {
                final x = f(xTick);
                final y = f(yTick);
                final pos = Plot.originPoint(x, y, origin);

                if (dotValue) {
                    final dotRadius = f(dotSizeValue / 2.);
                    final dotPos = Plot.originPoint(f(x - dotRadius), f(y - dotRadius), origin);
                    paintDots.push(paintDot(dotPos));
                }

                dots.push(pos);
            }
        }

        return {dots: dots, paintDots: paintDots};
    }

    /** The stroke through `dots`. */
    function buildPath(dots:Array<Point>):Null<Path> {
        final builder = PathBuilder.stroke(strokeWidthValue);

        if (dots.length == 0) {
            return null;
        }

        if (dots.length == 1) {
            builder.moveTo(dots[0]);
            return Plot.buildPath(builder);
        }

        curvePath(builder, dots, curveValue);
        return Plot.buildPath(builder);
    }

    /**
     * Draw `points` with `curve` into `builder` (shared with `Area`, which
     * draws the same curve into two builders).
     */
    @:allow(gpui.base.plot.shape)
    static function curvePath(builder:PathBuilder, points:Array<Point>, curve:Curve):Void {
        builder.moveTo(points[0]);
        switch curve {
            case Natural:
                final n = points.length;
                for (i in 0...n - 1) {
                    final p0 = i == 0 ? points[0] : points[i - 1];
                    final p1 = points[i];
                    final p2 = points[i + 1];
                    final p3 = i + 2 < n ? points[i + 2] : points[n - 1];

                    // Catmull-Rom to Bezier
                    final c1 = new Point(f(p1.x + f(f(p2.x - p0.x) / 6.0)), f(p1.y + f(f(p2.y - p0.y) / 6.0)));
                    final c2 = new Point(f(p2.x - f(f(p3.x - p1.x) / 6.0)), f(p2.y - f(f(p3.y - p1.y) / 6.0)));

                    builder.cubicBezierTo(p2, c1, c2);
                }
            case Linear:
                for (i in 1...points.length) {
                    builder.lineTo(points[i]);
                }
            case StepAfter:
                for (i in 0...points.length - 1) {
                    builder.lineTo(new Point(points[i + 1].x, points[i].y));
                    // Don't draw the vertical line for the last point
                    if (i < points.length - 2) {
                        builder.lineTo(points[i + 1]);
                    }
                }
        }
    }

    @:allow(tests)
    function path(bounds:Bounds):{path:Null<Path>, dots:Array<PaintQuad>} {
        final result = dots(bounds.origin);
        return {path: buildPath(result.dots), dots: result.paintDots};
    }

    /**
     * Paint the Line, reusing the stroke tessellated by an earlier paint
     * while the projected points, stroke width and curve style are
     * unchanged. Use this from a plot that keeps a `PathCache` per line.
     */
    public function paintCached(bounds:Bounds, cache:PathCache, window:Window):Void {
        final local = dots(new Point(0, 0));
        final key = new ShapeKey('line:' + curveValue.toInt() + ':' + ShapeKey.bits(strokeWidthValue));
        for (dot in local.dots) {
            key.point(dot);
        }
        final path = cache.get(key.finish(), bounds.origin, () -> buildPath(local.dots));
        if (path != null) {
            window.paintPath(path, strokeValue);
        }
        // Dots are quads: cheap, and positioned at this frame's origin.
        for (dot in local.paintDots) {
            dot.bounds = new Bounds(new Point(f(dot.bounds.origin.x + bounds.origin.x), f(dot.bounds.origin.y + bounds.origin.y)), dot.bounds.size);
            window.paintQuad(dot);
        }
    }

    /** Paint the Line. */
    public function paint(bounds:Bounds, window:Window):Void {
        final result = path(bounds);
        if (result.path != null) {
            window.paintPath(result.path, strokeValue);
        }
        for (dot in result.dots) {
            window.paintQuad(dot);
        }
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

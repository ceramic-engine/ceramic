// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/radial_line.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-shape/radial-line
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
import gpui.base.plot.Plot;

import gpui.Prelude.quad;
import gpui.Prelude.transparentBlack;

/**
 * A radial line generator, like `d3.lineRadial`.
 *
 * Points are placed around the center of the plot bounds. The `angle`
 * accessor returns the angle in radians, with 0 at 12 o'clock and positive
 * angles proceeding clockwise. The `radius` accessor returns the distance
 * (in pixels) from the center. Both receive the datum and its index.
 *
 * Call `closed` to connect the last point back to the first (like
 * `d3.curveLinearClosed`), and `fill` to fill the enclosed polygon, e.g.
 * for radar charts.
 */
class RadialLine<T> {

    var dataValues:Array<T> = [];

    var angleFn:(T, Int) -> Null<Float> = (_, _) -> null;

    var radiusFn:(T, Int) -> Null<Float> = (_, _) -> null;

    var closedValue:Bool = false;

    var fillValue:Null<Background> = null;

    var strokeValue:Background = new Background();

    var strokeWidthValue:Float = 1.;

    var dotValue:Bool = false;

    var dotSizeValue:Float = 4.;

    var dotFillValue:Background = Background.fromHsla(transparentBlack());

    var dotStrokeValue:Null<Hsla> = null;

    public function new() {}

    /** Set the data of the RadialLine. */
    public function data(data:Iterable<T>):RadialLine<T> {
        dataValues = [for (v in data) v];
        return this;
    }

    /** Set the angle accessor of the RadialLine. */
    public function angle(angle:(T, Int) -> Null<Float>):RadialLine<T> {
        angleFn = angle;
        return this;
    }

    /** Set the radius accessor of the RadialLine. */
    public function radius(radius:(T, Int) -> Null<Float>):RadialLine<T> {
        radiusFn = radius;
        return this;
    }

    /** Connect the last point back to the first, like `d3.curveLinearClosed`. */
    public function closed():RadialLine<T> {
        closedValue = true;
        return this;
    }

    /**
     * Set the fill color of the polygon enclosed by the RadialLine. The fill
     * path is always closed, regardless of `closed`.
     */
    public function fill(fill:IntoBackground):RadialLine<T> {
        fillValue = fill;
        return this;
    }

    /** Set the stroke color of the RadialLine. */
    public function stroke(stroke:IntoBackground):RadialLine<T> {
        strokeValue = stroke;
        return this;
    }

    /** Set the stroke width of the RadialLine. */
    public function strokeWidth(strokeWidth:Pixels):RadialLine<T> {
        strokeWidthValue = SpringMath.f32(strokeWidth);
        return this;
    }

    /** Draw a dot on every point. */
    public function dot():RadialLine<T> {
        dotValue = true;
        return this;
    }

    /** Set the size of the dots on the RadialLine. */
    public function dotSize(dotSize:Pixels):RadialLine<T> {
        dotSizeValue = SpringMath.f32(dotSize);
        return this;
    }

    /** Set the fill of the dots on the RadialLine. */
    public function dotFill(fill:IntoBackground):RadialLine<T> {
        dotFillValue = fill;
        return this;
    }

    /**
     * Set the 1px border color of the dots on the RadialLine. Defaults to
     * the dot fill when it is a solid color.
     */
    public function dotStroke(stroke:IntoHsla):RadialLine<T> {
        dotStrokeValue = stroke;
        return this;
    }

    /** Paint a dot on the RadialLine. */
    function paintDot(dot:Point):PaintQuad {
        final solid = dotFillValue.asSolid();
        final border:Hsla = dotStrokeValue != null ? dotStrokeValue : (solid != null ? solid : new Hsla());
        return quad(new Bounds(dot, new Size(dotSizeValue, dotSizeValue)), Corners.all(f(dotSizeValue / 2.)), dotFillValue, Edges.all(1.), border, Solid);
    }

    /** Resolve the data to points around the center of the bounds. */
    @:allow(tests)
    function points(bounds:Bounds):Array<Point> {
        final centerX = f(bounds.origin.x + f(bounds.size.width / 2.));
        final centerY = f(bounds.origin.y + f(bounds.size.height / 2.));

        final result:Array<Point> = [];
        for (i in 0...dataValues.length) {
            final v = dataValues[i];
            final rawAngle = angleFn(v, i);
            if (rawAngle == null) continue;
            final angle = f(f(rawAngle) - Arc.HALF_PI);
            final rawRadius = radiusFn(v, i);
            if (rawRadius == null) continue;
            final radius = f(rawRadius);
            result.push(new Point(f(centerX + f(radius * Arc.cos(angle))), f(centerY + f(radius * Arc.sin(angle)))));
        }
        return result;
    }

    @:allow(tests)
    function path(bounds:Bounds):{fill:Null<Path>, stroke:Null<Path>, dots:Array<PaintQuad>} {
        final points = points(bounds);
        final paintDots:Array<PaintQuad> = [];

        if (dotValue) {
            final dotRadius = f(dotSizeValue / 2.);
            for (p in points) {
                paintDots.push(paintDot(new Point(f(p.x - dotRadius), f(p.y - dotRadius))));
            }
        }

        if (points.length == 0) {
            return {fill: null, stroke: null, dots: paintDots};
        }

        var fillPath:Null<Path> = null;
        if (fillValue != null && points.length >= 3) {
            final builder = PathBuilder.fill();
            builder.addPolygon(points, true);
            fillPath = Plot.buildPath(builder);
        }

        final builder = PathBuilder.stroke(strokeWidthValue);
        builder.moveTo(points[0]);
        for (i in 1...points.length) {
            builder.lineTo(points[i]);
        }
        if (closedValue && points.length > 2) {
            builder.close();
        }

        return {fill: fillPath, stroke: Plot.buildPath(builder), dots: paintDots};
    }

    /** Paint the RadialLine. */
    public function paint(bounds:Bounds, window:Window):Void {
        final result = path(bounds);

        if (result.fill != null && fillValue != null) {
            window.paintPath(result.fill, fillValue);
        }
        if (result.stroke != null) {
            window.paintPath(result.stroke, strokeValue);
        }
        for (dot in result.dots) {
            window.paintQuad(dot);
        }
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

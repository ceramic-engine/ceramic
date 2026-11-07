// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/area.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-shape/area
package glaze.kit.base.plot.shape;

import glaze.Background;
import glaze.Bounds;
import glaze.IntoBackground;
import glaze.Path;
import glaze.PathBuilder;
import glaze.Point;
import glaze.SpringMath;
import glaze.Window;
import glaze.kit.base.plot.Curve;
import glaze.kit.base.plot.PathCache;
import glaze.kit.base.plot.PathCache.ShapeKey;
import glaze.kit.base.plot.Plot;

/**
 * An area under a line through data points, filled down to `y0`, with the
 * line stroked on top.
 */
class Area<T> {

    var dataValues:Array<T> = [];

    var xFn:(T) -> Null<Float> = _ -> null;

    var y0Value:Null<Float> = null;

    var y1Fn:(T) -> Null<Float> = _ -> null;

    var fillValue:Background = new Background();

    var strokeValue:Background = new Background();

    var curveValue:Curve = Natural;

    public function new() {}

    /** Set the data of the Area. */
    public function data(data:Iterable<T>):Area<T> {
        dataValues = glaze.util.Iterables.toArray(data);
        return this;
    }

    /** Set the x of the Area. */
    public function x(x:(T) -> Null<Float>):Area<T> {
        xFn = x;
        return this;
    }

    /** Set the y0 of the Area. */
    public function y0(y0:Float):Area<T> {
        y0Value = SpringMath.f32(y0);
        return this;
    }

    /** Set the y1 of the Area. */
    public function y1(y1:(T) -> Null<Float>):Area<T> {
        y1Fn = y1;
        return this;
    }

    /** Set the fill color of the Area. */
    public function fill(fill:IntoBackground):Area<T> {
        fillValue = fill;
        return this;
    }

    /** Set the stroke color of the Area. */
    public function stroke(stroke:IntoBackground):Area<T> {
        strokeValue = stroke;
        return this;
    }

    /** Set how the Area's top line connects its points. Defaults to `Natural`. */
    public function curve(curve:Curve):Area<T> {
        curveValue = curve;
        return this;
    }

    @:allow(tests)
    function path(bounds:Bounds):{area:Null<Path>, line:Null<Path>} {
        final origin = bounds.origin;
        final areaBuilder = PathBuilder.fill();
        final lineBuilder = PathBuilder.stroke(1.);

        final points:Array<Point> = [];

        var firstXTick:Null<Float> = null;
        var lastXTick:Null<Float> = null;
        for (index in 0...dataValues.length) {
            final v = dataValues[index];
            if (index == 0) {
                firstXTick = xFn(v);
            }
            if (index == dataValues.length - 1) {
                lastXTick = xFn(v);
            }
            final xTick = xFn(v);
            final yTick = y1Fn(v);

            if (xTick != null && yTick != null) {
                points.push(Plot.originPoint(f(xTick), f(yTick), origin));
            }
        }

        if (points.length == 0) {
            return {area: null, line: null};
        }

        if (points.length == 1) {
            areaBuilder.moveTo(points[0]);
            lineBuilder.moveTo(points[0]);
            return {area: Plot.buildPath(areaBuilder), line: Plot.buildPath(lineBuilder)};
        }

        Line.curvePath(areaBuilder, points, curveValue);
        Line.curvePath(lineBuilder, points, curveValue);

        // Close path
        if (firstXTick != null && lastXTick != null && y0Value != null) {
            areaBuilder.lineTo(Plot.originPoint(f(lastXTick), y0Value, bounds.origin));
            areaBuilder.lineTo(Plot.originPoint(f(firstXTick), y0Value, bounds.origin));
            areaBuilder.close();
        }

        return {area: Plot.buildPath(areaBuilder), line: Plot.buildPath(lineBuilder)};
    }

    /**
     * Paint the Area, reusing the fill and stroke tessellated by an earlier
     * paint while the projected points, baseline and curve style are
     * unchanged. `fill` and `line` are the two caches this area keeps
     * together; see `Line.paintCached`.
     */
    public function paintCached(bounds:Bounds, fill:PathCache, line:PathCache, window:Window):Void {
        final key = new ShapeKey('area:' + curveValue.toInt() + ':' + ShapeKey.bits(y0Value));
        for (v in dataValues) {
            final x = xFn(v);
            final y = y1Fn(v);
            if (x != null && y != null) {
                key.f32(f(x)).f32(f(y));
            }
        }
        final keyString = key.finish();
        final local = new Bounds(new Point(0, 0), bounds.size);
        // One miss builds both paths; the second cache takes the stroke from
        // the stash instead of building again.
        var strokePath:Null<Path> = null;
        var stashed = false;
        final fillPath = fill.get(keyString, bounds.origin, () -> {
            final result = path(local);
            strokePath = result.line;
            stashed = true;
            return result.area;
        });
        final linePath = line.get(keyString, bounds.origin, () -> {
            if (stashed) {
                stashed = false;
                return strokePath;
            }
            return path(local).line;
        });
        if (fillPath != null) {
            window.paintPath(fillPath, fillValue);
        }
        if (linePath != null) {
            window.paintPath(linePath, strokeValue);
        }
    }

    /** Paint the Area. */
    public function paint(bounds:Bounds, window:Window):Void {
        final result = path(bounds);
        if (result.area != null) {
            window.paintPath(result.area, fillValue);
        }
        if (result.line != null) {
            window.paintPath(result.line, strokeValue);
        }
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

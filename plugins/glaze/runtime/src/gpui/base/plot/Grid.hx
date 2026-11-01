// Ported from gpui-kit 0.8.1: crates/base/src/plot/grid.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.plot;

import gpui.Background;
import gpui.Bounds;
import gpui.IntoBackground;
import gpui.Point;
import gpui.Size;
import gpui.SpringMath;
import gpui.Window;

import gpui.Prelude.fill;

/**
 * Axis-aligned grid lines across a plot, at the given x and y positions.
 */
class Grid {

    var xValues:Array<Float> = [];

    var yValues:Array<Float> = [];

    var strokeValue:Background = new Background();

    var dashArrayValue:Null<Array<Float>> = null;

    public function new() {}

    /** Set the positions of the vertical lines, from the left of the plot. */
    public function x(x:Iterable<Float>):Grid {
        xValues = [for (v in x) f(v)];
        return this;
    }

    /** Set the positions of the horizontal lines, from the top of the plot. */
    public function y(y:Iterable<Float>):Grid {
        yValues = [for (v in y) f(v)];
        return this;
    }

    /** Set the stroke of the grid lines. */
    public function stroke(stroke:IntoBackground):Grid {
        strokeValue = stroke;
        return this;
    }

    /** Set the dash array of the grid lines. */
    public function dashArray(dashArray:Array<Float>):Grid {
        dashArrayValue = [for (v in dashArray) f(v)];
        return this;
    }

    function points(bounds:Bounds):Array<Array<Point>> {
        final size = bounds.size;
        final origin = bounds.origin;
        final result:Array<Array<Point>> = [];
        for (x in xValues) {
            result.push([Plot.originPoint(x, 0., origin), Plot.originPoint(x, size.height, origin)]);
        }
        for (y in yValues) {
            result.push([Plot.originPoint(0., y, origin), Plot.originPoint(size.width, y, origin)]);
        }
        return result;
    }

    /**
     * Paint the Grid.
     *
     * Grid lines are axis-aligned, so each one (or each dash of one) is a
     * 1px quad rather than a stroked path.
     */
    public function paint(bounds:Bounds, window:Window):Void {
        for (line in points(bounds)) {
            for (segment in dashSegments(line[0], line[1], dashArrayValue)) {
                window.paintQuad(fill(lineBounds(segment[0], segment[1]), strokeValue));
            }
        }
    }

    /**
     * The box a 1px stroke of the axis-aligned line `start`-`end` covers:
     * centred on the coordinate, as `PathBuilder.stroke(1)` draws it.
     */
    @:allow(tests)
    static function lineBounds(start:Point, end:Point):Bounds {
        final half = 0.5;
        if (start.x == end.x) {
            final top = Math.min(start.y, end.y);
            return new Bounds(new Point(f(start.x - half), top), new Size(1., f(Math.max(start.y, end.y) - top)));
        }
        else {
            final left = Math.min(start.x, end.x);
            return new Bounds(new Point(left, f(start.y - half)), new Size(f(Math.max(start.x, end.x) - left), 1.));
        }
    }

    /**
     * Splits the line `start`-`end` into the dashes of `dashArray`, walked
     * from `start` with the SVG `stroke-dasharray` rules `PathBuilder`
     * follows: values alternate dash and gap, and an odd-length array repeats
     * to an even one. Without a dash array the whole line is one segment.
     */
    @:allow(tests)
    static function dashSegments(start:Point, end:Point, dashArray:Null<Array<Float>>):Array<Array<Point>> {
        if (dashArray == null || dashArray.length == 0) {
            return [[start, end]];
        }
        final dx = f(end.x - start.x);
        final dy = f(end.y - start.y);
        final length = f(Math.sqrt(f(f(dx * dx) + f(dy * dy))));
        var allNonPositive = true;
        for (dash in dashArray) {
            if (dash > 0.) allNonPositive = false;
        }
        if (length <= 0. || allNonPositive) {
            return [[start, end]];
        }
        final at = (distance:Float) -> {
            final t = f(distance / length);
            return new Point(f(start.x + f(dx * t)), f(start.y + f(dy * t)));
        };
        final patternLen = dashArray.length % 2 == 1 ? dashArray.length * 2 : dashArray.length;
        final segments:Array<Array<Point>> = [];
        var position = 0.;
        var index = 0;
        while (position < length) {
            final dash = Math.max(dashArray[index % dashArray.length], 0.);
            final next = Math.min(f(position + dash), length);
            if (index % 2 == 0 && next > position) {
                segments.push([at(position), at(next)]);
            }
            position = next;
            index = (index + 1) % patternLen;
        }
        return segments;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

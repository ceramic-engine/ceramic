// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/arc.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://d3js.org/d3-shape/arc
package gpui.base.plot.shape;

import gpui.Bounds;
import gpui.IntoBackground;
import gpui.Path;
import gpui.PathBuilder;
import gpui.Point;
import gpui.SpringMath;
import gpui.Window;
import gpui.base.plot.PathCache;
import gpui.base.plot.PathCache.ShapeKey;
import gpui.base.plot.Plot;
import gpui.util.MathUtil;

/**
 * One slice of a `Pie`: its datum and the angles it spans, in radians with
 * 0 at 12 o'clock and positive angles proceeding clockwise.
 */
class ArcData<T> {

    public final data:T;

    public final index:Int;

    public final value:Float;

    public var startAngle:Float;

    public var endAngle:Float;

    public var padAngle:Float;

    /**
     * A slice of `data` from `startAngle` to `endAngle`, with no padding.
     * Set the remaining fields directly when they matter, e.g. `padAngle`.
     */
    public function new(data:T, index:Int, value:Float, startAngle:Float, endAngle:Float) {
        this.data = data;
        this.index = index;
        this.value = SpringMath.f32(value);
        this.startAngle = SpringMath.f32(startAngle);
        this.endAngle = SpringMath.f32(endAngle);
        this.padAngle = 0.;
    }

    public function toString():String {
        return 'ArcData { index: $index, value: $value, start_angle: $startAngle, end_angle: $endAngle, pad_angle: $padAngle }';
    }

}

/**
 * An arc generator, like `d3.arc`.
 */
class Arc {

    /** `std::f32::consts::PI` */
    public static inline final PI:Float = 3.1415927410125732;

    /** `std::f32::consts::TAU` */
    public static inline final TAU:Float = 6.2831854820251465;

    /** `PI / 2.` in `f32` */
    public static inline final HALF_PI:Float = 1.5707963705062866;

    /** `1e-12` as an `f32` */
    static final EPSILON:Float = SpringMath.f32(1e-12);

    @:allow(tests)
    var innerRadiusValue:Float = 0.;

    @:allow(tests)
    var outerRadiusValue:Float = 0.;

    public function new() {}

    /** Set the inner radius of the Arc. */
    public function innerRadius(innerRadius:Float):Arc {
        innerRadiusValue = f(innerRadius);
        return this;
    }

    /** Set the outer radius of the Arc. */
    public function outerRadius(outerRadius:Float):Arc {
        outerRadiusValue = f(outerRadius);
        return this;
    }

    /** Get the centroid of the Arc. */
    public function centroid<T>(arc:ArcData<T>):Point {
        final startAngle = f(arc.startAngle - HALF_PI);
        final endAngle = f(arc.endAngle - HALF_PI);
        final r = f(f(innerRadiusValue + outerRadiusValue) / 2.);
        final a = f(f(startAngle + endAngle) / 2.);
        return new Point(f(r * f(Math.cos(a))), f(r * f(Math.sin(a))));
    }

    @:allow(tests)
    function path<T>(arc:ArcData<T>, bounds:Bounds):Null<Path> {
        final startAngle = f(arc.startAngle - HALF_PI);
        final endAngle = f(arc.endAngle - HALF_PI);
        final da = f(endAngle - startAngle);
        // Leave some pad angle for full circle. If not, the path start and
        // end will be the same point.
        final padAngle = da >= PI ? f(0.0001) : arc.padAngle;
        final r0 = Math.max(innerRadiusValue, 0.);
        final r1 = Math.max(outerRadiusValue, 0.);

        // Calculate the center point.
        final centerX = f(bounds.origin.x + f(bounds.size.width / 2.));
        final centerY = f(bounds.origin.y + f(bounds.size.height / 2.));

        // Angle difference.
        if (r1 < EPSILON || Math.abs(da) < EPSILON) {
            return null;
        }

        // Handle pad angle.
        var a0Outer:Float;
        var a1Outer:Float;
        var a0Inner:Float;
        var a1Inner:Float;
        if (r0 > EPSILON && padAngle > 0.0) {
            final padWidth = f(r1 * padAngle);
            final padAngleOuter = f(padWidth / r1);
            var padAngleInner = f(padWidth / r0);
            final maxInnerPad = f(da * 0.8);
            if (padAngleInner > maxInnerPad) {
                padAngleInner = maxInnerPad;
            }
            a0Outer = f(startAngle + f(padAngleOuter * 0.5));
            a1Outer = f(endAngle - f(padAngleOuter * 0.5));
            a0Inner = f(startAngle + f(padAngleInner * 0.5));
            a1Inner = f(endAngle - f(padAngleInner * 0.5));
        }
        else {
            final pad = f(padAngle * 0.5);
            a0Outer = f(startAngle + pad);
            a1Outer = f(endAngle - pad);
            a0Inner = f(startAngle + pad);
            a1Inner = f(endAngle - pad);
        }

        final daOuter = f(a1Outer - a0Outer);
        if (daOuter <= 0.) {
            return null;
        }

        // Calculate the start and end points of the outer arc.
        final x01 = f(centerX + f(r1 * cos(a0Outer)));
        final y01 = f(centerY + f(r1 * sin(a0Outer)));
        final x11 = f(centerX + f(r1 * cos(a1Outer)));
        final y11 = f(centerY + f(r1 * sin(a1Outer)));

        final builder = PathBuilder.fill();

        // Move to the start point of the outer arc.
        builder.moveTo(new Point(x01, y01));

        // Draw the outer arc.
        final largeArc = Math.abs(f(a1Outer - a0Outer)) > PI;
        builder.arcTo(new Point(r1, r1), 0., largeArc, true, new Point(x11, y11));

        if (r0 > EPSILON) {
            // End point of the inner arc.
            final x10 = f(centerX + f(r0 * cos(a1Inner)));
            final y10 = f(centerY + f(r0 * sin(a1Inner)));
            builder.lineTo(new Point(x10, y10));

            // Draw the inner arc.
            final x00 = f(centerX + f(r0 * cos(a0Inner)));
            final y00 = f(centerY + f(r0 * sin(a0Inner)));
            final largeArcInner = Math.abs(f(a1Inner - a0Inner)) > PI;
            builder.arcTo(new Point(r0, r0), 0., largeArcInner, false, new Point(x00, y00));
        }
        else {
            // If there is no inner radius, draw a line to the center.
            builder.lineTo(new Point(centerX, centerY));
        }

        return Plot.buildPath(builder);
    }

    /**
     * Whether the cursor at `position` (relative to the bounds origin) is on
     * this arc's slice: within its angles and between this arc's radii.
     */
    public function contains<T>(arc:ArcData<T>, position:Point, bounds:Bounds):Bool {
        final dx = f(position.x - f(bounds.size.width / 2.));
        final dy = f(position.y - f(bounds.size.height / 2.));
        final radius = hypot(dx, dy);
        final r0 = Math.max(innerRadiusValue, 0.);
        final r1 = Math.max(outerRadiusValue, 0.);
        if (radius < r0 || radius > r1) {
            return false;
        }

        // Screen angle -> pie angle (0 at 12 o'clock, clockwise), in [0, TAU).
        final angle = remEuclid(f(f(Math.atan2(dy, dx)) + HALF_PI), f(2. * PI));
        return angle >= arc.startAngle && angle < arc.endAngle;
    }

    /**
     * Paint the Arc, reusing the path tessellated by an earlier paint while
     * its angles, radii and the bounds size are unchanged.
     *
     * To paint one slice at other radii (e.g. lifted on hover), build
     * another `Arc` with those radii.
     */
    public function paintCached<T>(arc:ArcData<T>, fill:IntoBackground, bounds:Bounds, cache:PathCache, window:Window):Void {
        final key = new ShapeKey('arc:' + ShapeKey.bits(bounds.size.width) + ':' + ShapeKey.bits(bounds.size.height))
            .f32(arc.startAngle)
            .f32(arc.endAngle)
            .f32(arc.padAngle)
            .f32(innerRadiusValue)
            .f32(outerRadiusValue)
            .finish();
        final local = new Bounds(new Point(0, 0), bounds.size);
        final path = cache.get(key, bounds.origin, () -> this.path(arc, local));
        if (path != null) {
            window.paintPath(path, fill);
        }
    }

    /** Paint the Arc. */
    public function paint<T>(arc:ArcData<T>, fill:IntoBackground, bounds:Bounds, window:Window):Void {
        final path = this.path(arc, bounds);
        if (path != null) {
            window.paintPath(path, fill);
        }
    }

    /** `f32::cos` */
    public static inline function cos(a:Float):Float {
        return SpringMath.f32(Math.cos(a));
    }

    /** `f32::sin` */
    public static inline function sin(a:Float):Float {
        return SpringMath.f32(Math.sin(a));
    }

    /** `f32::hypot` */
    public static inline function hypot(x:Float, y:Float):Float {
        return SpringMath.f32(Math.sqrt(x * x + y * y));
    }

    /** `f32::rem_euclid` */
    public static inline function remEuclid(a:Float, b:Float):Float {
        return SpringMath.f32(MathUtil.remEuclid(a, b));
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

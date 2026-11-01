// Adapted from lyon, the tessellation library GPUI uses for its paths:
// lyon_path 1.0.19 (builder.rs: WithSvg, path.rs: BuilderImpl, transforms),
// lyon_geom 1.0.19 (arc.rs, quadratic_bezier.rs, cubic_bezier.rs, line.rs),
// lyon_tessellation 1.0.21 (event_queue.rs, fill.rs: intersections,
// stroke.rs, math_utils.rs) and lyon_algorithms 1.0.21 (measure.rs), and
// from euclid 0.22.14 (trig.rs fast_atan2, transform2d.rs, rotation.rs).
// lyon: Copyright (c) 2013 Nicolas Silva, licensed under MIT OR Apache-2.0
// (used here under MIT). euclid: Copyright (c) 2013 The Servo Project
// Developers, licensed under MIT OR Apache-2.0 (used here under MIT).
// Modified: translated from Rust to Haxe for Ceramic, reduced to what GPUI's
// PathBuilder uses (gpui-pre 0.3.10: src/path_builder.rs). See NOTICE.md.
package gpui;

import gpui.Path.LineCap;
import gpui.Path.LineJoin;
import gpui.Path.StrokeOptions;

/**
 * lyon's geometry, as used by GPUI's `PathBuilder`, with exact `f32`
 * semantics: every intermediate value is rounded to `f32` in the same order
 * as the Rust code (`f()`), and the few computations lyon does in `f64`
 * (fill intersections, cap and miter clip lines) are done in `f64` then
 * rounded. The results are bit identical to lyon's vertices (checked
 * against the vertices dumped from GPUI, see `PathTessellatorTest`).
 *
 * - `LyonPath`: the recorded path (`lyon::path::Path`, built like lyon's
 *   `WithSvg` builder by `PathBuilder`), transformed like `Path::transformed`.
 * - `fillPolygons()`: the outline that lyon's fill tessellator triangulates:
 *   curves flattened like its event queue, and a vertex inserted where edges
 *   cross, computed like its sweep line.
 * - `dashed()`: GPUI's dashing (`PathMeasurements` and `PathSampler`).
 * - `stroke()`: lyon's stroke tessellator (fixed line width): the same
 *   vertices and triangles.
 */
class PathTessellator {

    /** Rounds to the nearest `f32` */
    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

    /** `f32::consts::PI` */
    public static final PI_F32:Float = SpringMath.f32(Math.PI);

    /** `f32::consts::FRAC_PI_2` */
    static final FRAC_PI_2_F32:Float = SpringMath.f32(Math.PI / 2);

    /** `f32::consts::FRAC_PI_4` */
    static final FRAC_PI_4_F32:Float = SpringMath.f32(Math.PI / 4);

    /** `f32::EPSILON` */
    static inline final EPSILON_F32:Float = 1.1920928955078125e-7;

    /** The degrees to radians factor of `f32::to_radians` (`PI / 180.0` in `f32`) */
    static final RADS_PER_DEG:Float = SpringMath.f32(SpringMath.f32(Math.PI) / 180);

    /** Rust `f32::to_radians` */
    public static inline function toRadians(degrees:Float):Float {
        return f(degrees * RADS_PER_DEG);
    }

    /** Rust `f32::signum` */
    static inline function signum(v:Float):Float {
        return v > 0 ? 1.0 : (v < 0 ? -1.0 : (1 / v < 0 ? -1.0 : 1.0));
    }

/// euclid

    /** euclid `Trig::fast_atan2` for `f32` */
    public static function fastAtan2(y:Float, x:Float):Float {
        final xAbs = Math.abs(x);
        final yAbs = Math.abs(y);
        final a = f(Math.min(xAbs, yAbs) / Math.max(xAbs, yAbs));
        final s = f(a * a);
        var result = f(f(f(f(f(f(f(f(-0.0464964749) * s) + f(0.15931422)) * s) - f(0.327622764)) * s) * a) + a);
        if (yAbs > xAbs)
            result = f(FRAC_PI_2_F32 - result);
        if (x < 0.0)
            result = f(PI_F32 - result);
        if (y < 0.0)
            result = -result;
        return result;
    }

    /** euclid `Transform2D::rotation` (`[m11, m12, m21, m22, m31, m32]`) */
    public static function rotation(radians:Float):Array<Float> {
        final cos = f(Math.cos(radians));
        final sin = f(Math.sin(radians));
        return [cos, sin, -sin, cos, 0, 0];
    }

    /** euclid `Transform2D::then`: `a` then `b` */
    public static function then(a:Array<Float>, b:Array<Float>):Array<Float> {
        return [
            f(f(a[0] * b[0]) + f(a[1] * b[2])),
            f(f(a[0] * b[1]) + f(a[1] * b[3])),
            f(f(a[2] * b[0]) + f(a[3] * b[2])),
            f(f(a[2] * b[1]) + f(a[3] * b[3])),
            f(f(f(a[4] * b[0]) + f(a[5] * b[2])) + b[4]),
            f(f(f(a[4] * b[1]) + f(a[5] * b[3])) + b[5])
        ];
    }

/// lyon_geom: flattening

    /** f32 values of i^4 for i in 1..25 (`flattened_segments_wang`) */
    static final WANG_LUT:Array<Float> = [for (i in 1...25) i * i * i * i];

    static function wangCount(err4:Float):Float {
        if (err4 <= 331776.0) {
            for (i in 0...24) {
                if (err4 <= WANG_LUT[i])
                    return i + 1;
            }
        }
        return Math.max(f(Math.sqrt(f(Math.sqrt(err4)))), 1);
    }

    /**
     * lyon `QuadraticBezierSegment::for_each_flattened_with_t`: calls
     * `cb(x, y, t)` for the end of each line segment (`t` is `t.end`).
     */
    public static function flattenQuad(fx:Float, fy:Float, cx:Float, cy:Float, tx:Float, ty:Float, tolerance:Float, cb:(x:Float, y:Float, t:Float) -> Void):Void {
        // flattened_segments_wang
        final lx = f(f(f(fx - f(cx * 2)) + tx) * 2);
        final ly = f(f(f(fy - f(cy * 2)) + ty) * 2);
        final d = f(1 / f(8 * tolerance));
        final err4 = f(f(f(f(lx * lx) + f(ly * ly)) * d) * d);
        final n = wangCount(err4);
        final step = f(1 / n);
        var t0 = 0.0;
        // polynomial_form
        final a1x = f(f(cx - fx) * 2);
        final a1y = f(f(cy - fy) * 2);
        final a2x = f(f(fx + tx) - f(cx * 2));
        final a2y = f(f(fy + ty) - f(cy * 2));
        final count = Std.int(n) - 1;
        for (_ in 0...count) {
            final t1 = f(t0 + step);
            final t2 = f(t1 * t1);
            cb(f(f(fx + f(a1x * t1)) + f(a2x * t2)), f(f(fy + f(a1y * t1)) + f(a2y * t2)), t1);
            t0 = t1;
        }
        cb(tx, ty, 1.0);
    }

    /** Same as `flattenQuad()` for a cubic curve. */
    public static function flattenCubic(fx:Float, fy:Float, c1x:Float, c1y:Float, c2x:Float, c2y:Float, tx:Float, ty:Float, tolerance:Float, cb:(x:Float, y:Float, t:Float) -> Void):Void {
        final v1x = f(f(f(fx - f(c1x * 2)) + c2x) * 6);
        final v1y = f(f(f(fy - f(c1y * 2)) + c2y) * 6);
        final v2x = f(f(f(c1x - f(c2x * 2)) + tx) * 6);
        final v2y = f(f(f(c1y - f(c2y * 2)) + ty) * 6);
        final l = Math.max(f(f(v1x * v1x) + f(v1y * v1y)), f(f(v2x * v2x) + f(v2y * v2y)));
        final d = f(1 / f(8 * tolerance));
        final err4 = f(f(l * d) * d);
        final n = wangCount(err4);
        final step = f(1 / n);
        var t0 = 0.0;
        final a1x = f(f(c1x - fx) * 3);
        final a1y = f(f(c1y - fy) * 3);
        final a2x = f(f(f(fx * 3) - f(c1x * 6)) + f(c2x * 3));
        final a2y = f(f(f(fy * 3) - f(c1y * 6)) + f(c2y * 3));
        final a3x = f(f(tx - fx) + f(f(c1x - c2x) * 3));
        final a3y = f(f(ty - fy) + f(f(c1y - c2y) * 3));
        final count = Std.int(n) - 1;
        for (_ in 0...count) {
            final t1 = f(t0 + step);
            var t2 = t1;
            var x = f(fx + f(a1x * t2));
            var y = f(fy + f(a1y * t2));
            t2 = f(t2 * t1);
            x = f(x + f(a2x * t2));
            y = f(y + f(a2y * t2));
            t2 = f(t2 * t1);
            x = f(x + f(a3x * t2));
            y = f(y + f(a3y * t2));
            cb(x, y, t1);
            t0 = t1;
        }
        cb(tx, ty, 1.0);
    }

/// lyon_tessellation: fill

    /** lyon's sweep order: `a` comes after `b` */
    public static inline function isAfter(ax:Float, ay:Float, bx:Float, by:Float):Bool {
        return ay > by || (ay == by && ax > bx);
    }

    /**
     * The polygons covered by lyon's fill tessellation of `path`: one list
     * of `x, y` per sub-path (closed implicitly), with curves flattened like
     * lyon's fill event queue (from their top end) and a vertex inserted at
     * each crossing of two edges, where lyon's sweep line inserts it.
     */
    public static function fillPolygons(path:LyonPath, tolerance:Float):Array<Array<Float>> {
        final polygons:Array<Array<Float>> = [];
        var current:Null<Array<Float>> = null;
        var cx = 0.0;
        var cy = 0.0;
        final tmp:Array<Float> = [];
        inline function push(x:Float, y:Float) {
            final n = current.length;
            if (current[n - 2] != x || current[n - 1] != y) {
                current.push(x);
                current.push(y);
            }
        }
        final pts = path.points;
        var k = 0;
        for (verb in path.verbs) {
            switch verb {
                case LyonPath.BEGIN:
                    cx = pts[k++];
                    cy = pts[k++];
                    current = [cx, cy];
                    polygons.push(current);
                case LyonPath.LINE:
                    cx = pts[k++];
                    cy = pts[k++];
                    push(cx, cy);
                case LyonPath.QUAD:
                    final qx = pts[k++], qy = pts[k++], tx = pts[k++], ty = pts[k++];
                    tmp.resize(0);
                    if (isAfter(cx, cy, tx, ty)) {
                        // Swapped so that it goes downwards, then put back in path order
                        flattenQuad(tx, ty, qx, qy, cx, cy, tolerance, (x, y, _) -> { tmp.push(x); tmp.push(y); });
                        var i = tmp.length - 4;
                        while (i >= 0) {
                            push(tmp[i], tmp[i + 1]);
                            i -= 2;
                        }
                        push(tx, ty);
                    }
                    else {
                        flattenQuad(cx, cy, qx, qy, tx, ty, tolerance, (x, y, _) -> push(x, y));
                    }
                    cx = tx;
                    cy = ty;
                case LyonPath.CUBIC:
                    final c1x = pts[k++], c1y = pts[k++], c2x = pts[k++], c2y = pts[k++], tx = pts[k++], ty = pts[k++];
                    tmp.resize(0);
                    if (isAfter(cx, cy, tx, ty)) {
                        flattenCubic(tx, ty, c2x, c2y, c1x, c1y, cx, cy, tolerance, (x, y, _) -> { tmp.push(x); tmp.push(y); });
                        var i = tmp.length - 4;
                        while (i >= 0) {
                            push(tmp[i], tmp[i + 1]);
                            i -= 2;
                        }
                        push(tx, ty);
                    }
                    else {
                        flattenCubic(cx, cy, c1x, c1y, c2x, c2y, tx, ty, tolerance, (x, y, _) -> push(x, y));
                    }
                    cx = tx;
                    cy = ty;
                case LyonPath.CLOSE:
                    k += 2;
                case _:
            }
        }

        // Closing duplicates and empty sub-paths
        var i = polygons.length - 1;
        while (i >= 0) {
            final poly = polygons[i];
            var n = poly.length;
            while (n >= 4 && poly[n - 2] == poly[0] && poly[n - 1] == poly[1]) {
                poly.pop();
                poly.pop();
                n -= 2;
            }
            if (n < 4)
                polygons.splice(i, 1);
            i--;
        }

        splitAtIntersections(polygons);
        return polygons;
    }

    /**
     * Inserts the vertices lyon's fill tessellator adds where edges cross
     * (`FillTessellator::handle_intersections` and `process_intersection`):
     * a sweep from top to bottom; at each event, the edges that start there
     * are checked against the active edges, the intersection is computed in
     * `f64` on the edge below (from the current position) and rounded to
     * `f32`, and both edges are split there (their lower parts become new
     * events, checked again when the sweep reaches them).
     *
     * Not emulated: coincident edges merging and edges split by a vertex
     * lying exactly on them (no vertex is added in either case).
     */
    static function splitAtIntersections(polygons:Array<Array<Float>>):Void {
        // Source edges: polygon index, edge index
        final sweep = new FillSweep();
        for (pi in 0...polygons.length) {
            final poly = polygons[pi];
            final n = Std.int(poly.length / 2);
            for (i in 0...n) {
                final j = (i + 1) % n;
                sweep.addEdge(poly[i * 2], poly[i * 2 + 1], poly[j * 2], poly[j * 2 + 1], sweep.sources.length);
                sweep.sources.push([]);
            }
        }
        if (!sweep.run())
            return;
        var e = 0;
        for (pi in 0...polygons.length) {
            final poly = polygons[pi];
            final n = Std.int(poly.length / 2);
            final out:Array<Float> = [];
            for (i in 0...n) {
                final x0 = poly[i * 2], y0 = poly[i * 2 + 1];
                out.push(x0);
                out.push(y0);
                final list = sweep.sources[e + i];
                if (list.length > 0) {
                    final j = (i + 1) % n;
                    final dx = poly[j * 2] - x0, dy = poly[j * 2 + 1] - y0;
                    final count = Std.int(list.length / 2);
                    final order = [for (k in 0...count) k];
                    inline function key(k:Int):Float return (list[k * 2] - x0) * dx + (list[k * 2 + 1] - y0) * dy;
                    order.sort((a, b) -> key(a) < key(b) ? -1 : (key(a) > key(b) ? 1 : 0));
                    for (k in order) {
                        final x = list[k * 2], y = list[k * 2 + 1];
                        if ((x != x0 || y != y0) && (out[out.length - 2] != x || out[out.length - 1] != y)) {
                            out.push(x);
                            out.push(y);
                        }
                    }
                }
            }
            e += n;
            polygons[pi] = out;
        }
    }

/// lyon_geom: arcs

    /** euclid `Rotation2D::transform_point` (`(x cos - y sin, y cos + x sin)`) */
    static inline function rotX(x:Float, y:Float, cos:Float, sin:Float):Float {
        return f(f(x * cos) - f(y * sin));
    }

    static inline function rotY(x:Float, y:Float, cos:Float, sin:Float):Float {
        return f(f(y * cos) + f(x * sin));
    }

/// lyon_algorithms: dashes

    /**
     * GPUI's dashing (`PathBuilder::tessellate_stroke`): the path is measured
     * (`PathMeasurements::from_path(path, 0.01)`) and each dash is extracted
     * with `PathSampler::split_range` (normalized ranges) into a new path.
     */
    public static function dashed(path:LyonPath, dashArray:Array<Float>):LyonPath {
        final sampler = new PathSampler(path, 0.01);
        final builder = new LyonPath();
        final totalLength = sampler.length();
        final count = dashArray.length;
        var pos = 0.0;
        var dashIndex = 0;
        while (pos < totalLength) {
            final dashLength = f(dashArray[dashIndex % count]);
            final nextPos = Math.min(f(pos + dashLength), totalLength);
            if (dashIndex % 2 == 0) {
                final start = f(pos / totalLength);
                final end = f(nextPos / totalLength);
                sampler.splitRange(start, end, builder);
            }
            pos = nextPos;
            dashIndex++;
        }
        return builder;
    }

/// lyon_tessellation: stroke

    /** lyon `StrokeTessellator::tessellate_path` with a fixed line width */
    public static function stroke(path:LyonPath, options:StrokeOptions):StrokeGeometry {
        final builder = new StrokeBuilder(options);
        final pts = path.points;
        var k = 0;
        var cx = 0.0;
        var cy = 0.0;
        for (verb in path.verbs) {
            switch verb {
                case LyonPath.BEGIN:
                    cx = pts[k++];
                    cy = pts[k++];
                    builder.beginFw(cx, cy);
                case LyonPath.LINE:
                    cx = pts[k++];
                    cy = pts[k++];
                    builder.lineToFw(cx, cy);
                case LyonPath.QUAD:
                    final qx = pts[k++], qy = pts[k++], tx = pts[k++], ty = pts[k++];
                    builder.quadraticBezierToFw(cx, cy, qx, qy, tx, ty);
                    cx = tx;
                    cy = ty;
                case LyonPath.CUBIC:
                    final c1x = pts[k++], c1y = pts[k++], c2x = pts[k++], c2y = pts[k++], tx = pts[k++], ty = pts[k++];
                    builder.cubicBezierToFw(cx, cy, c1x, c1y, c2x, c2y, tx, ty);
                    cx = tx;
                    cy = ty;
                case LyonPath.END:
                    builder.end(false);
                case LyonPath.CLOSE:
                    k += 2;
                    builder.end(true);
                case _:
            }
        }
        return builder.output;
    }

    /** lyon `compute_normal` (math_utils.rs), in `f32` */
    public static function computeNormal(v1x:Float, v1y:Float, v2x:Float, v2y:Float, out:Array<Float>):Void {
        final epsilon = f(1e-4);
        final n1x = -v1y;
        final n1y = v1x;
        final v12x = f(v1x + v2x);
        final v12y = f(v1y + v2y);
        final sq = f(f(v12x * v12x) + f(v12y * v12y));
        if (sq < epsilon) {
            out[0] = 0;
            out[1] = 0;
            return;
        }
        final len = f(Math.sqrt(sq));
        final tx = f(v12x / len);
        final ty = f(v12y / len);
        final nx = -ty;
        final ny = tx;
        final invLen = f(f(nx * n1x) + f(ny * n1y));
        if (Math.abs(invLen) < epsilon) {
            out[0] = n1x;
            out[1] = n1y;
            return;
        }
        out[0] = f(nx / invLen);
        out[1] = f(ny / invLen);
    }

    /** `f32` length of a vector (euclid `length`: `square_length().sqrt()`) */
    public static inline function length(x:Float, y:Float):Float {
        return f(Math.sqrt(f(f(x * x) + f(y * y))));
    }

    /** `f32` square length of a vector */
    public static inline function squareLength(x:Float, y:Float):Float {
        return f(f(x * x) + f(y * y));
    }

    /**
     * lyon_geom `Line::intersection` in `f64` (lines given by a point and a
     * vector), rounded to `f32`. Returns false when the lines are parallel.
     */
    public static function lineIntersection(p1x:Float, p1y:Float, v1x:Float, v1y:Float, p2x:Float, p2y:Float, v2x:Float, v2y:Float, out:Array<Float>):Bool {
        final det = v1x * v2y - v1y * v2x;
        if (Math.abs(det) <= 2.220446049250313e-16)
            return false;
        final invDet = 1.0 / det;
        final selfP2x = p1x + v1x, selfP2y = p1y + v1y;
        final otherP2x = p2x + v2x, otherP2y = p2y + v2y;
        final a = p1x * selfP2y - p1y * selfP2x;
        final b = p2x * otherP2y - p2y * otherP2x;
        out[0] = f((b * v1x - a * v2x) * invDet);
        out[1] = f((b * v1y - a * v2y) * invDet);
        return true;
    }

}

/**
 * A recorded lyon path (`lyon::path::Path`): verbs and `f32` points.
 * `CLOSE` also stores the first point of the sub-path, like lyon.
 */
class LyonPath {

    public static inline final BEGIN = 0;
    public static inline final LINE = 1;
    public static inline final QUAD = 2;
    public static inline final CUBIC = 3;
    public static inline final END = 4;
    public static inline final CLOSE = 5;

    public final verbs:Array<Int> = [];

    public final points:Array<Float> = [];

    var firstX:Float = 0;

    var firstY:Float = 0;

    public function new() {}

    public function begin(x:Float, y:Float):Void {
        firstX = x;
        firstY = y;
        verbs.push(BEGIN);
        points.push(x);
        points.push(y);
    }

    public function end(close:Bool):Void {
        if (close) {
            points.push(firstX);
            points.push(firstY);
        }
        verbs.push(close ? CLOSE : END);
    }

    public function lineTo(x:Float, y:Float):Void {
        verbs.push(LINE);
        points.push(x);
        points.push(y);
    }

    public function quadraticBezierTo(cx:Float, cy:Float, x:Float, y:Float):Void {
        verbs.push(QUAD);
        points.push(cx);
        points.push(cy);
        points.push(x);
        points.push(y);
    }

    public function cubicBezierTo(c1x:Float, c1y:Float, c2x:Float, c2y:Float, x:Float, y:Float):Void {
        verbs.push(CUBIC);
        points.push(c1x);
        points.push(c1y);
        points.push(c2x);
        points.push(c2y);
        points.push(x);
        points.push(y);
    }

    /**
     * lyon `Path::transformed` with a euclid `Transform2D`
     * (`[m11, m12, m21, m22, m31, m32]`, row vectors).
     */
    public function transformed(m:Array<Float>):LyonPath {
        final result = new LyonPath();
        for (v in verbs)
            result.verbs.push(v);
        var i = 0;
        while (i < points.length) {
            final x = points[i];
            final y = points[i + 1];
            result.points.push(SpringMath.f32(SpringMath.f32(SpringMath.f32(x * m[0]) + SpringMath.f32(y * m[2])) + m[4]));
            result.points.push(SpringMath.f32(SpringMath.f32(SpringMath.f32(x * m[1]) + SpringMath.f32(y * m[3])) + m[5]));
            i += 2;
        }
        return result;
    }

}

/**
 * The output of `PathTessellator.stroke()`: lyon's stroke vertices
 * (`x, y` pairs, logical pixels) and triangles (3 indices each).
 */
class StrokeGeometry {

    public final vertices:Array<Float> = [];

    public final indices:Array<Int> = [];

    public function new() {}

    public inline function vertexCount():Int {
        return vertices.length >> 1;
    }

}

/**
 * The sweep line of lyon's fill tessellator, reduced to the handling of
 * intersections (see `PathTessellator.splitAtIntersections()`).
 */
private class FillSweep {

    /** Inserted points (`x, y`) of each source edge */
    public final sources:Array<Array<Float>> = [];

    /** Pending edges, by event position: from (top), to, winding, source */
    final events:Array<SweepEdge> = [];

    final active:Array<SweepEdge> = [];

    var found:Bool = false;

    public function new() {}

    public function addEdge(x0:Float, y0:Float, x1:Float, y1:Float, source:Int):Void {
        if (x0 == x1 && y0 == y1)
            return;
        if (PathTessellator.isAfter(x0, y0, x1, y1))
            insert(new SweepEdge(x1, y1, x0, y0, -1, source));
        else
            insert(new SweepEdge(x0, y0, x1, y1, 1, source));
    }

    /** Inserts an edge in the event queue (sorted by its top, stable) */
    function insert(edge:SweepEdge):Void {
        var lo = 0;
        var hi = events.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            final e = events[mid];
            if (PathTessellator.isAfter(edge.fromX, edge.fromY, e.fromX, e.fromY) || (edge.fromX == e.fromX && edge.fromY == e.fromY))
                lo = mid + 1;
            else
                hi = mid;
        }
        events.insert(lo, edge);
    }

    /** Runs the sweep. Returns true when at least one vertex was inserted. */
    public function run():Bool {
        // Vertex positions: tops of pending edges and ends of active edges
        while (events.length > 0 || active.length > 0) {
            // Next event position
            var px = Math.POSITIVE_INFINITY;
            var py = Math.POSITIVE_INFINITY;
            if (events.length > 0) {
                px = events[0].fromX;
                py = events[0].fromY;
            }
            for (a in active) {
                if (PathTessellator.isAfter(px, py, a.toX, a.toY)) {
                    px = a.toX;
                    py = a.toY;
                }
            }
            if (px == Math.POSITIVE_INFINITY)
                break;

            // Edges below: the pending edges starting here, sorted like lyon
            // (`sort_edges_below`, by slope)
            final below:Array<SweepEdge> = [];
            while (events.length > 0 && events[0].fromX == px && events[0].fromY == py)
                below.push(events.shift());
            for (e in below)
                e.sortKey = SpringMath.f32(SpringMath.f32(e.toX - px) / Math.max(SpringMath.f32(e.toY - py), 1.1754943508222875e-38));
            below.sort((a, b) -> a.sortKey < b.sortKey ? -1 : (a.sortKey > b.sortKey ? 1 : 0));

            // Edges above: the active edges ending here (skipped by the checks)
            for (a in active)
                a.above = a.toX == px && a.toY == py;

            for (edgeBelow in below)
                handleIntersections(px, py, edgeBelow);

            // Update the active edges
            var i = active.length - 1;
            while (i >= 0) {
                if (active[i].above)
                    active.splice(i, 1);
                i--;
            }
            for (e in below)
                active.push(e);
        }
        return found;
    }

    function handleIntersections(px:Float, py:Float, edgeBelow:SweepEdge):Void {
        final belowMinX = Math.min(px, edgeBelow.toX);
        final belowMaxX = Math.max(px, edgeBelow.toX);
        var tbMin = 1.0;
        var best:Null<SweepEdge> = null;
        var bestTa = 0.0;
        for (activeEdge in active) {
            if (activeEdge.above)
                continue;
            if (belowMinX > Math.max(activeEdge.fromX, activeEdge.toX))
                continue;
            if (belowMaxX < Math.min(activeEdge.fromX, activeEdge.toX))
                continue;
            // LineSegment::intersection_t in f64, active edge first
            final ax = activeEdge.fromX, ay = activeEdge.fromY, bx = activeEdge.toX, by = activeEdge.toY;
            final cx = px, cy = py, dx = edgeBelow.toX, dy = edgeBelow.toY;
            if ((bx == dx && by == dy) || (ax == cx && ay == cy) || (ax == dx && ay == dy) || (bx == cx && by == cy))
                continue;
            final v1x = bx - ax, v1y = by - ay;
            final v2x = dx - cx, v2y = dy - cy;
            final cross = v1x * v2y - v1y * v2x;
            if (cross == 0)
                continue;
            final sign = cross > 0 ? 1.0 : -1.0;
            final absCross = Math.abs(cross);
            final v3x = cx - ax, v3y = cy - ay;
            final t = (v3x * v2y - v3y * v2x) * sign;
            final u = (v3x * v1y - v3y * v1x) * sign;
            if (t < 0 || t > absCross || u < 0 || u > absCross)
                continue;
            final ta = t / absCross;
            final tb = u / absCross;
            if (tb < tbMin && tb > 0.0 && ta > 0.0 && ta <= 1.0) {
                tbMin = tb;
                best = activeEdge;
                bestTa = ta;
            }
        }
        if (best != null)
            processIntersection(px, py, best, edgeBelow, tbMin);
    }

    function processIntersection(px:Float, py:Float, activeEdge:SweepEdge, edgeBelow:SweepEdge, tb:Float):Void {
        // below_segment.sample(tb) in f64, rounded to f32
        final oneT = 1.0 - tb;
        var ix = SpringMath.f32(oneT * px + tb * edgeBelow.toX);
        var iy = SpringMath.f32(oneT * py + tb * edgeBelow.toY);

        if (ix == px && iy == py) {
            // The active edge now starts at the current position
            record(activeEdge.source, ix, iy);
            activeEdge.fromX = ix;
            activeEdge.fromY = iy;
            return;
        }

        if (!PathTessellator.isAfter(ix, iy, px, py))
            iy = nextAfterUp(py);

        inline function isNear(ax:Float, ay:Float, bx:Float, by:Float):Bool {
            return PathTessellator.squareLength(SpringMath.f32(ax - bx), SpringMath.f32(ay - by)) < SpringMath.f32(0.000000001);
        }
        if (isNear(ix, iy, edgeBelow.toX, edgeBelow.toY)) {
            ix = edgeBelow.toX;
            iy = edgeBelow.toY;
        }
        else if (isNear(ix, iy, activeEdge.toX, activeEdge.toY)) {
            ix = activeEdge.toX;
            iy = activeEdge.toY;
        }

        if ((activeEdge.toX != ix || activeEdge.toY != iy) && (activeEdge.fromX != ix || activeEdge.fromY != iy)) {
            if (PathTessellator.isAfter(activeEdge.toX, activeEdge.toY, ix, iy))
                insert(new SweepEdge(ix, iy, activeEdge.toX, activeEdge.toY, activeEdge.winding, activeEdge.source));
            else
                insert(new SweepEdge(activeEdge.toX, activeEdge.toY, ix, iy, -activeEdge.winding, activeEdge.source));
            record(activeEdge.source, ix, iy);
            activeEdge.toX = ix;
            activeEdge.toY = iy;
        }

        if ((edgeBelow.toX != ix || edgeBelow.toY != iy) && (px != ix || py != iy)) {
            if (PathTessellator.isAfter(edgeBelow.toX, edgeBelow.toY, ix, iy))
                insert(new SweepEdge(ix, iy, edgeBelow.toX, edgeBelow.toY, edgeBelow.winding, edgeBelow.source));
            else
                insert(new SweepEdge(edgeBelow.toX, edgeBelow.toY, ix, iy, -edgeBelow.winding, edgeBelow.source));
            record(edgeBelow.source, ix, iy);
            edgeBelow.toX = ix;
            edgeBelow.toY = iy;
        }
    }

    function record(source:Int, x:Float, y:Float):Void {
        final list = sources[source];
        var i = 0;
        while (i < list.length) {
            if (list[i] == x && list[i + 1] == y)
                return;
            i += 2;
        }
        list.push(x);
        list.push(y);
        found = true;
    }

    /** Rust `f32::next_after(f32::INFINITY)` */
    static function nextAfterUp(v:Float):Float {
        final bits = haxe.io.FPHelper.floatToI32(v);
        if (v == 0)
            return haxe.io.FPHelper.i32ToFloat(1);
        return haxe.io.FPHelper.i32ToFloat(v > 0 ? bits + 1 : bits - 1);
    }

}

private class SweepEdge {

    public var fromX:Float;
    public var fromY:Float;
    public var toX:Float;
    public var toY:Float;
    public final winding:Int;
    public final source:Int;
    public var sortKey:Float = 0;
    public var above:Bool = false;

    public function new(fromX:Float, fromY:Float, toX:Float, toY:Float, winding:Int, source:Int) {
        this.fromX = fromX;
        this.fromY = fromY;
        this.toX = toX;
        this.toY = toY;
        this.winding = winding;
        this.source = source;
    }

}

/**
 * lyon_algorithms `PathMeasurements` and `PathSampler` (sampling by
 * distance), reduced to `split_range` with normalized ranges.
 */
private class PathSampler {

    /** Events: verb, from (x, y), then the segment points */
    final kinds:Array<Int> = [];
    final segPoints:Array<Array<Float>> = [];

    /** Edges: distance, event index, t */
    final edgeDistance:Array<Float> = [];
    final edgeIndex:Array<Int> = [];
    final edgeT:Array<Float> = [];

    var cursor:Int = 0;

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

    public function new(path:LyonPath, tolerance:Float) {
        tolerance = Math.max(tolerance, f(1e-4));
        tolerance = f(tolerance);
        final pts = path.points;
        var k = 0;
        var cx = 0.0, cy = 0.0, firstX = 0.0, firstY = 0.0;
        var distance = 0.0;
        for (verb in path.verbs) {
            final index = kinds.length;
            switch verb {
                case LyonPath.BEGIN:
                    cx = firstX = pts[k++];
                    cy = firstY = pts[k++];
                    kinds.push(LyonPath.BEGIN);
                    segPoints.push([cx, cy]);
                    pushEdge(distance, index, 1.0);
                case LyonPath.LINE:
                    final tx = pts[k++], ty = pts[k++];
                    distance = f(distance + PathTessellator.length(f(cx - tx), f(cy - ty)));
                    kinds.push(LyonPath.LINE);
                    segPoints.push([cx, cy, tx, ty]);
                    pushEdge(distance, index, 1.0);
                    cx = tx;
                    cy = ty;
                case LyonPath.QUAD:
                    final qx = pts[k++], qy = pts[k++], tx = pts[k++], ty = pts[k++];
                    kinds.push(LyonPath.QUAD);
                    segPoints.push([cx, cy, qx, qy, tx, ty]);
                    var px = cx, py = cy;
                    PathTessellator.flattenQuad(cx, cy, qx, qy, tx, ty, tolerance, (x, y, t) -> {
                        distance = f(distance + PathTessellator.length(f(x - px), f(y - py)));
                        pushEdge(distance, index, t);
                        px = x;
                        py = y;
                    });
                    cx = tx;
                    cy = ty;
                case LyonPath.CUBIC:
                    final c1x = pts[k++], c1y = pts[k++], c2x = pts[k++], c2y = pts[k++], tx = pts[k++], ty = pts[k++];
                    kinds.push(LyonPath.CUBIC);
                    segPoints.push([cx, cy, c1x, c1y, c2x, c2y, tx, ty]);
                    var px = cx, py = cy;
                    PathTessellator.flattenCubic(cx, cy, c1x, c1y, c2x, c2y, tx, ty, tolerance, (x, y, t) -> {
                        distance = f(distance + PathTessellator.length(f(x - px), f(y - py)));
                        pushEdge(distance, index, t);
                        px = x;
                        py = y;
                    });
                    cx = tx;
                    cy = ty;
                case LyonPath.CLOSE:
                    k += 2;
                    distance = f(distance + PathTessellator.length(f(cx - firstX), f(cy - firstY)));
                    kinds.push(LyonPath.CLOSE);
                    segPoints.push([cx, cy, firstX, firstY]);
                    pushEdge(distance, index, 1.0);
                    cx = firstX;
                    cy = firstY;
                case _:
                    kinds.push(LyonPath.END);
                    segPoints.push([]);
            }
        }
    }

    function pushEdge(distance:Float, index:Int, t:Float):Void {
        edgeDistance.push(distance);
        edgeIndex.push(index);
        edgeT.push(t);
    }

    public function length():Float {
        return edgeDistance.length == 0 ? 0.0 : edgeDistance[edgeDistance.length - 1];
    }

    public function splitRange(start:Float, end:Float, output:LyonPath):Void {
        final length = length();
        start = f(start * length);
        end = f(end * length);
        start = Math.max(start, 0.0);
        end = Math.max(end, start);
        start = Math.min(start, length);
        end = Math.min(end, length);
        if (!(start < end))
            return;

        // sample_impl(start, Distance).position
        sampleAt(start, output);
        final ptr1 = cursor;
        final seg1 = edgeIndex[cursor];
        moveCursor(end);
        final ptr2 = cursor;
        final seg2 = edgeIndex[cursor];

        final inSubpath = [true];
        if (seg1 == seg2) {
            cursor = ptr1;
            final tBegin = t(start);
            cursor = ptr2;
            final tEnd = t(end);
            addSegment(seg1, tBegin, tEnd, true, output, inSubpath);
        }
        else {
            cursor = ptr1;
            addSegment(seg1, t(start), 1.0, true, output, inSubpath);
            for (seg in (seg1 + 1)...seg2)
                addSegment(seg, 0, 1, false, output, inSubpath);
            cursor = ptr2;
            addSegment(seg2, 0.0, t(end), true, output, inSubpath);
        }
        output.end(false);
    }

    function sampleAt(dist:Float, output:LyonPath):Void {
        final length = length();
        dist = Math.min(Math.max(dist, 0.0), length);
        moveCursor(dist);
        final tt = t(dist);
        final p = segPoints[edgeIndex[cursor]];
        final out = [0.0, 0.0];
        sampleSegment(kinds[edgeIndex[cursor]], p, tt, out);
        output.begin(out[0], out[1]);
    }

    function inBounds(dist:Float):Bool {
        return cursor != 0 && edgeDistance[cursor - 1] <= dist && dist <= edgeDistance[cursor];
    }

    function moveCursor(dist:Float):Void {
        if (dist == 0.0) {
            cursor = 1;
            return;
        }
        if (inBounds(dist))
            return;

        inline function floorLog2(num:Int):Int {
            var r = -1;
            var n = num;
            while (n > 0) {
                n >>= 1;
                r++;
            }
            return r;
        }
        function partitionPoint(first:Int, last:Int, pred:Int->Bool):Int {
            var l = first;
            var r = last;
            while (l < r) {
                final mid = (l + r) >> 1;
                if (pred(mid))
                    l = mid + 1;
                else
                    r = mid;
            }
            return l;
        }

        final start = edgeDistance[cursor];
        if (start < dist) {
            final len = f(length() - start);
            final num = edgeDistance.length - cursor - 1;
            if (f(f(f(dist - start) / len) * num) < floorLog2(num)) {
                while (true) {
                    cursor++;
                    if (dist <= edgeDistance[cursor])
                        break;
                }
            }
            else {
                cursor = partitionPoint(cursor + 1, edgeDistance.length, p -> edgeDistance[p] < dist);
            }
        }
        else {
            final len = start;
            final num = cursor + 1;
            if (f(f(f(start - dist) / len) * num) < floorLog2(num)) {
                while (true) {
                    cursor--;
                    if (cursor == 0 || edgeDistance[cursor - 1] < dist)
                        break;
                }
            }
            else {
                cursor = partitionPoint(0, cursor, p -> edgeDistance[p] < dist);
            }
        }
    }

    function t(dist:Float):Float {
        final prevDistance = edgeDistance[cursor - 1];
        final curDistance = edgeDistance[cursor];
        final length = f(curDistance - prevDistance);
        if (length == 0.0)
            return 0.0;
        final tBegin = edgeIndex[cursor - 1] == edgeIndex[cursor] ? edgeT[cursor - 1] : 0.0;
        final tEnd = edgeT[cursor];
        return f(tBegin + f(f(tEnd - tBegin) * f(f(dist - prevDistance) / length)));
    }

    /** `segment.sample(t)` (Bernstein forms of lyon_geom) */
    static function sampleSegment(kind:Int, p:Array<Float>, t:Float, out:Array<Float>):Void {
        switch kind {
            case LyonPath.LINE | LyonPath.CLOSE:
                final oneT = f(1 - t);
                out[0] = f(f(oneT * p[0]) + f(t * p[2]));
                out[1] = f(f(oneT * p[1]) + f(t * p[3]));
            case LyonPath.QUAD:
                final t2 = f(t * t);
                final oneT = f(1 - t);
                final oneT2 = f(oneT * oneT);
                for (c in 0...2)
                    out[c] = f(f(f(p[c] * oneT2) + f(f(f(p[2 + c] * 2) * oneT) * t)) + f(p[4 + c] * t2));
            case LyonPath.CUBIC:
                final t2 = f(t * t);
                final t3 = f(t2 * t);
                final oneT = f(1 - t);
                final oneT2 = f(oneT * oneT);
                final oneT3 = f(oneT2 * oneT);
                for (c in 0...2)
                    out[c] = f(f(f(f(p[c] * oneT3) + f(f(f(p[2 + c] * 3) * oneT2) * t)) + f(f(f(p[4 + c] * 3) * oneT) * t2)) + f(p[6 + c] * t3));
            case _:
        }
    }

    function addSegment(ptr:Int, t0:Float, t1:Float, hasRange:Bool, dest:LyonPath, inSubpath:Array<Bool>):Void {
        final kind = kinds[ptr];
        final p = segPoints[ptr];
        switch kind {
            case LyonPath.LINE | LyonPath.CLOSE:
                var fx = p[0], fy = p[1], tx = p[2], ty = p[3];
                if (hasRange) {
                    // LineSegment::split_range: from.lerp(to, t)
                    final a = [0.0, 0.0];
                    final b = [0.0, 0.0];
                    sampleSegment(LyonPath.LINE, p, t0, a);
                    sampleSegment(LyonPath.LINE, p, t1, b);
                    fx = a[0];
                    fy = a[1];
                    tx = b[0];
                    ty = b[1];
                }
                if (!inSubpath[0]) {
                    dest.end(false);
                    dest.begin(fx, fy);
                }
                dest.lineTo(tx, ty);
            case LyonPath.QUAD:
                var q = p;
                if (hasRange) {
                    // QuadraticBezierSegment::split_range
                    final from = [0.0, 0.0];
                    final to = [0.0, 0.0];
                    sampleSegment(LyonPath.QUAD, p, t0, from);
                    sampleSegment(LyonPath.QUAD, p, t1, to);
                    final dt = f(t1 - t0);
                    final oneT = f(1 - t0);
                    final q2:Array<Float> = [from[0], from[1], 0, 0, to[0], to[1]];
                    for (c in 0...2) {
                        final a = f(p[2 + c] - p[c]);
                        final b = f(p[4 + c] - p[2 + c]);
                        // Vector lerp: a * one_t + b * t
                        q2[2 + c] = f(from[c] + f(f(f(a * oneT) + f(b * t0)) * dt));
                    }
                    q = q2;
                }
                if (!inSubpath[0]) {
                    dest.end(false);
                    dest.begin(q[0], q[1]);
                }
                dest.quadraticBezierTo(q[2], q[3], q[4], q[5]);
            case LyonPath.CUBIC:
                var c3 = p;
                if (hasRange) {
                    // CubicBezierSegment::split_range
                    final from = [0.0, 0.0];
                    final to = [0.0, 0.0];
                    sampleSegment(LyonPath.CUBIC, p, t0, from);
                    sampleSegment(LyonPath.CUBIC, p, t1, to);
                    final d:Array<Float> = [
                        f(p[2] - p[0]), f(p[3] - p[1]),
                        f(p[4] - p[2]), f(p[5] - p[3]),
                        f(p[6] - p[4]), f(p[7] - p[5])
                    ];
                    final dt = f(t1 - t0);
                    final d0 = [0.0, 0.0];
                    final d1 = [0.0, 0.0];
                    sampleSegment(LyonPath.QUAD, d, t0, d0);
                    sampleSegment(LyonPath.QUAD, d, t1, d1);
                    c3 = [
                        from[0], from[1],
                        f(from[0] + f(d0[0] * dt)), f(from[1] + f(d0[1] * dt)),
                        f(to[0] - f(d1[0] * dt)), f(to[1] - f(d1[1] * dt)),
                        to[0], to[1]
                    ];
                }
                if (!inSubpath[0]) {
                    dest.end(false);
                    dest.begin(c3[0], c3[1]);
                }
                dest.cubicBezierTo(c3[2], c3[3], c3[4], c3[5], c3[6], c3[7]);
            case _:
        }
        inSubpath[0] = kind != LyonPath.END && kind != LyonPath.BEGIN;
    }

}

/** Side points of an endpoint (lyon `SidePoints`) */
private class SidePoints {

    public var prevX:Float = Math.NaN;
    public var prevY:Float = Math.NaN;
    public var nextX:Float = Math.NaN;
    public var nextY:Float = Math.NaN;
    public var hasSingle:Bool = false;
    public var singleX:Float = Math.NaN;
    public var singleY:Float = Math.NaN;
    public var prevVertex:Int = -1;
    public var nextVertex:Int = -1;

    public function new() {}

    public function copy():SidePoints {
        final c = new SidePoints();
        c.prevX = prevX;
        c.prevY = prevY;
        c.nextX = nextX;
        c.nextY = nextY;
        c.hasSingle = hasSingle;
        c.singleX = singleX;
        c.singleY = singleY;
        c.prevVertex = prevVertex;
        c.nextVertex = nextVertex;
        return c;
    }

}

/** lyon `EndpointData` (copied by value where Rust copies it) */
private class EndpointData {

    public var x:Float = 0;
    public var y:Float = 0;
    public var halfWidth:Float = Math.NaN;
    public var advancement:Float = Math.NaN;
    public var lineJoin:LineJoin = Miter;
    public var sidePoints:Array<SidePoints> = [new SidePoints(), new SidePoints()];
    public var fold:Array<Bool> = [false, false];
    public var isFlatteningStep:Bool = false;

    public function new() {}

    public function copy():EndpointData {
        final c = new EndpointData();
        c.x = x;
        c.y = y;
        c.halfWidth = halfWidth;
        c.advancement = advancement;
        c.lineJoin = lineJoin;
        c.sidePoints = [sidePoints[0].copy(), sidePoints[1].copy()];
        c.fold = [fold[0], fold[1]];
        c.isFlatteningStep = isFlatteningStep;
        return c;
    }

}

/**
 * lyon `StrokeBuilderImpl`, fixed line width code paths (`*_fw`), with a
 * `BuffersBuilder` collecting `StrokeVertex::position()`.
 */
private class StrokeBuilder {

    static inline final SIDE_POSITIVE = 0;
    static inline final SIDE_NEGATIVE = 1;

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

    public final output = new StrokeGeometry();

    final options:StrokeOptions;

    final lineWidth:Float;

    final miterLimit:Float;

    final tolerance:Float;

    /** PointBuffer: up to 3 endpoints */
    final points:Array<EndpointData> = [null, null, null];
    var pbStart:Int = 0;
    var pbCount:Int = 0;

    final firsts:Array<EndpointData> = [];

    var subPathStartAdvancement:Float = 0.0;

    final squareMergeThreshold:Float;

    var mayNeedEmptyCap:Bool = false;

    // StrokeVertexData
    var vPosX:Float = 0;
    var vPosY:Float = 0;
    var vHalfWidth:Float;
    var vNormalX:Float = 0;
    var vNormalY:Float = 0;

    final tmp:Array<Float> = [0, 0];

    public function new(options:StrokeOptions) {
        this.options = options;
        lineWidth = f(options.lineWidth);
        miterLimit = f(options.miterLimit);
        tolerance = f(options.tolerance);
        squareMergeThreshold = Math.max(Math.min(f(f(tolerance * tolerance) * 0.5), f(f(lineWidth * lineWidth) * f(0.05))), f(1e-8));
        vHalfWidth = f(lineWidth * 0.5);
    }

/// PointBuffer

    function pbPush(p:EndpointData):Void {
        if (pbCount < 3) {
            points[pbCount] = p;
            pbCount++;
            return;
        }
        points[pbStart] = p;
        pbStart++;
        if (pbStart == 3)
            pbStart = 0;
    }

    inline function pbGet(idx:Int):EndpointData {
        return points[(idx + pbStart) % 3];
    }

    inline function pbLast():EndpointData {
        return pbGet(pbCount - 1);
    }

    inline function pbClear():Void {
        pbCount = 0;
        pbStart = 0;
    }

/// Output

    /** `StrokeVertex::position()`: position on path + normal * half width */
    function addVertex():Int {
        final id = output.vertexCount();
        output.vertices.push(f(vPosX + f(vNormalX * vHalfWidth)));
        output.vertices.push(f(vPosY + f(vNormalY * vHalfWidth)));
        return id;
    }

    inline function addTriangle(a:Int, b:Int, c:Int):Void {
        output.indices.push(a);
        output.indices.push(b);
        output.indices.push(c);
    }

/// Builder

    function newEndpoint(x:Float, y:Float):EndpointData {
        final e = new EndpointData();
        e.x = x;
        e.y = y;
        e.halfWidth = f(lineWidth * 0.5);
        e.lineJoin = options.lineJoin;
        return e;
    }

    public function beginFw(x:Float, y:Float):Void {
        mayNeedEmptyCap = false;
        final e = newEndpoint(x, y);
        e.advancement = subPathStartAdvancement;
        fixedWidthStepImpl(e);
    }

    public function lineToFw(x:Float, y:Float):Void {
        fixedWidthStepImpl(newEndpoint(x, y));
    }

    public function quadraticBezierToFw(fx:Float, fy:Float, cx:Float, cy:Float, tx:Float, ty:Float):Void {
        inline function step(x:Float, y:Float, isFlatteningStep:Bool) {
            final e = newEndpoint(x, y);
            e.isFlatteningStep = isFlatteningStep;
            fixedWidthStepImpl(e);
        }
        // flatten_quad
        final tSplit = findSharpTurn(fx, fy, cx, cy, tx, ty);
        if (tSplit != null) {
            final t:Float = tSplit;
            // QuadraticBezierSegment::split
            final oneT = f(1 - t);
            final oneT2 = f(oneT * oneT);
            final t2 = f(t * t);
            final sx = f(f(f(fx * oneT2) + f(f(f(cx * 2) * oneT) * t)) + f(tx * t2));
            final sy = f(f(f(fy * oneT2) + f(f(f(cy * 2) * oneT) * t)) + f(ty * t2));
            final c0x = f(f(oneT * fx) + f(t * cx));
            final c0y = f(f(oneT * fy) + f(t * cy));
            final c1x = f(f(oneT * cx) + f(t * tx));
            final c1y = f(f(oneT * cy) + f(t * ty));
            PathTessellator.flattenQuad(fx, fy, c0x, c0y, sx, sy, tolerance, (x, y, te) -> step(x, y, te != 1.0));
            PathTessellator.flattenQuad(sx, sy, c1x, c1y, tx, ty, tolerance, (x, y, te) -> step(x, y, te != 1.0));
        }
        else {
            PathTessellator.flattenQuad(fx, fy, cx, cy, tx, ty, tolerance, (x, y, te) -> step(x, y, te != 1.0));
        }
    }

    public function cubicBezierToFw(fx:Float, fy:Float, c1x:Float, c1y:Float, c2x:Float, c2y:Float, tx:Float, ty:Float):Void {
        PathTessellator.flattenCubic(fx, fy, c1x, c1y, c2x, c2y, tx, ty, tolerance, (x, y, te) -> {
            final e = newEndpoint(x, y);
            e.isFlatteningStep = te != 1.0;
            fixedWidthStepImpl(e);
        });
    }

    public function end(close:Bool):Void {
        mayNeedEmptyCap = mayNeedEmptyCap || (close && pbCount == 1);
        if (close && pbCount > 2)
            closeSubPath();
        else
            endWithCaps();
        pbClear();
        firsts.resize(0);
    }

    /** lyon `find_sharp_turn` */
    static function findSharpTurn(fx:Float, fy:Float, cx:Float, cy:Float, tx:Float, ty:Float):Null<Float> {
        final bx = f(tx - fx), by = f(ty - fy);
        final vx = f(cx - fx), vy = f(cy - fy);
        final nx = -by, ny = bx;
        final vDotB = f(f(vx * bx) + f(vy * by));
        final vDotN = f(f(vx * nx) + f(vy * ny));
        var lx = bx, ly = by;
        if ((vDotB >= 0.0 && vDotB <= f(f(bx * bx) + f(by * by))) || f(Math.abs(vDotN) * 2.0) >= Math.abs(vDotB)) {
            if (f(PathTessellator.squareLength(bx, by) * 30.0) > PathTessellator.squareLength(vx, vy))
                return null;
            lx = vx;
            ly = vy;
        }
        final angle = -PathTessellator.fastAtan2(ly, lx);
        final cos = f(Math.cos(angle));
        final sin = f(Math.sin(angle));
        // Rotated curve: from (0, 0), ctrl = rot(v), to = rot(baseline)
        final rcx = f(f(vx * cos) - f(vy * sin));
        final rtx = f(f(bx * cos) - f(by * sin));
        // local_x_extremum_t
        final div = f(f(0 - f(2 * rcx)) + rtx);
        if (div == 0.0)
            return null;
        final t = f(f(0 - rcx) / div);
        if (t > 0.0 && t < 1.0)
            return t;
        return null;
    }

    inline function pointsAreTooClose(ax:Float, ay:Float, bx:Float, by:Float):Bool {
        return PathTessellator.squareLength(f(ax - bx), f(ay - by)) < squareMergeThreshold;
    }

    function fixedWidthStepImpl(next:EndpointData):Bool {
        final count = pbCount;

        if (count > 0) {
            final last = pbLast();
            if (pointsAreTooClose(last.x, last.y, next.x, next.y)) {
                if (count == 1)
                    mayNeedEmptyCap = true;
                return false;
            }

            if (count == 1) {
                final first = last;
                final ex = f(next.x - first.x);
                final ey = f(next.y - first.y);
                final length = PathTessellator.length(ex, ey);
                if (Math.isNaN(next.advancement))
                    next.advancement = f(first.advancement + length);
                final tx = f(ex / length);
                final ty = f(ey / length);
                final nx = f(-ty * next.halfWidth);
                final ny = f(tx * next.halfWidth);
                first.sidePoints[SIDE_POSITIVE].nextX = f(first.x + nx);
                first.sidePoints[SIDE_POSITIVE].nextY = f(first.y + ny);
                first.sidePoints[SIDE_NEGATIVE].nextX = f(first.x - nx);
                first.sidePoints[SIDE_NEGATIVE].nextY = f(first.y - ny);
            }
        }

        if (count > 1) {
            final prev = pbGet(count - 2);
            final join = pbGet(count - 1);

            vPosX = join.x;
            vPosY = join.y;
            vHalfWidth = join.halfWidth;

            var fastPath = false;
            if (join.isFlatteningStep) {
                final v0x = f(join.x - prev.x), v0y = f(join.y - prev.y);
                final v1x = f(next.x - join.x), v1y = f(next.y - join.y);
                fastPath = f(f(v0x * v1x) + f(v0y * v1y)) > 0.0;
            }
            if (fastPath) {
                join.lineJoin = Miter;
                flattenedStep(prev, join, next);
            }
            else {
                computeJoinSidePositionsFixedWidth(prev, join, next);
                addJoinBaseVertices(join, SIDE_NEGATIVE);
                addJoinBaseVertices(join, SIDE_POSITIVE);
            }

            if (count > 2)
                addEdgeTriangles(prev, join);

            tessellateJoin(join);

            if (count == 2) {
                firsts.push(prev.copy());
                firsts.push(join.copy());
            }
        }

        pbPush(next);
        return true;
    }

    function computeJoinSidePositionsFixedWidth(prev:EndpointData, join:EndpointData, next:EndpointData):Void {
        var ptx = f(join.x - prev.x), pty = f(join.y - prev.y);
        var ntx = f(next.x - join.x), nty = f(next.y - join.y);
        final prevLength = PathTessellator.length(ptx, pty);
        final nextLength = PathTessellator.length(ntx, nty);
        ptx = f(ptx / prevLength);
        pty = f(pty / prevLength);
        ntx = f(ntx / nextLength);
        nty = f(nty / nextLength);

        if (Math.isNaN(join.advancement))
            join.advancement = f(prev.advancement + prevLength);

        PathTessellator.computeNormal(ptx, pty, ntx, nty, tmp);
        final normalX = tmp[0], normalY = tmp[1];
        final cross = f(f(ptx * nty) - f(pty * ntx));
        final frontSide = cross >= 0.0 ? SIDE_NEGATIVE : SIDE_POSITIVE;
        final frontNormalX = cross >= 0.0 ? -normalX : normalX;
        final frontNormalY = cross >= 0.0 ? -normalY : normalY;
        final backSide = 1 - frontSide;

        final extrudedX = f(frontNormalX * vHalfWidth);
        final extrudedY = f(frontNormalY * vHalfWidth);
        final unclippedMiter = (join.lineJoin == Miter || join.lineJoin == MiterClip) && !miterLimitIsExceeded(frontNormalX, frontNormalY);

        var fold = false;
        final angleIsSharp = f(f(ntx * ptx) + f(nty * pty)) < 0.0;
        if (!unclippedMiter && angleIsSharp) {
            final dNext = f(f(f(extrudedX * -ntx) + f(extrudedY * -nty)) - nextLength);
            final dPrev = f(f(f(extrudedX * ptx) + f(extrudedY * pty)) - prevLength);
            if (Math.min(dNext, dPrev) > 0.0 || PathTessellator.squareLength(normalX, normalY) < f(1e-5)) {
                join.fold[frontSide] = true;
                fold = true;
            }
        }

        final n0x = f(-pty * vHalfWidth), n0y = f(ptx * vHalfWidth);
        final n1x = f(-nty * vHalfWidth), n1y = f(ntx * vHalfWidth);
        final pos = join.sidePoints[SIDE_POSITIVE];
        final neg = join.sidePoints[SIDE_NEGATIVE];
        pos.prevX = f(join.x + n0x);
        pos.prevY = f(join.y + n0y);
        pos.nextX = f(join.x + n1x);
        pos.nextY = f(join.y + n1y);
        neg.prevX = f(join.x - n0x);
        neg.prevY = f(join.y - n0y);
        neg.nextX = f(join.x - n1x);
        neg.nextY = f(join.y - n1y);

        if (!fold) {
            final mx = f(normalX * vHalfWidth);
            final my = f(normalY * vHalfWidth);
            final miterX = [f(join.x + mx), f(join.x - mx)];
            final miterY = [f(join.y + my), f(join.y - my)];
            final back = join.sidePoints[backSide];
            back.hasSingle = true;
            back.singleX = miterX[backSide];
            back.singleY = miterY[backSide];
            final front = join.sidePoints[frontSide];
            if (unclippedMiter) {
                front.hasSingle = true;
                front.singleX = miterX[frontSide];
                front.singleY = miterY[frontSide];
            }
            else if (join.lineJoin == MiterClip) {
                final pn = [f(front.prevX - join.x), f(front.prevY - join.y)];
                final nn = [f(front.nextX - join.x), f(front.nextY - join.y)];
                getClipIntersections(pn, nn, frontNormalX, frontNormalY, f(miterLimit * vHalfWidth));
                front.prevX = f(join.x + pn[0]);
                front.prevY = f(join.y + pn[1]);
                front.nextX = f(join.x + nn[0]);
                front.nextY = f(join.y + nn[1]);
            }
        }
    }

    /** lyon `get_clip_intersections` (the results replace `prev` and `next`) */
    static function getClipIntersections(prev:Array<Float>, next:Array<Float>, nx:Float, ny:Float, clipDistance:Float):Void {
        final len = PathTessellator.length(nx, ny);
        final cpx:Float = f(f(nx / len) * clipDistance);
        final cpy:Float = f(f(ny / len) * clipDistance);
        // tangent(v) = (-v.y, v.x)
        final out = [0.0, 0.0];
        final px = prev[0], py = prev[1];
        if (PathTessellator.lineIntersection(cpx, cpy, -ny, nx, px, py, -py, px, out)) {
            prev[0] = out[0];
            prev[1] = out[1];
        }
        else {
            prev[0] = nx;
            prev[1] = ny;
        }
        final qx = next[0], qy = next[1];
        if (PathTessellator.lineIntersection(cpx, cpy, -ny, nx, qx, qy, -qy, qx, out)) {
            next[0] = out[0];
            next[1] = out[1];
        }
        else {
            next[0] = nx;
            next[1] = ny;
        }
    }

    inline function miterLimitIsExceeded(nx:Float, ny:Float):Bool {
        return PathTessellator.squareLength(nx, ny) > f(f(miterLimit * miterLimit) * 4.0);
    }

    function flattenedStep(prev:EndpointData, join:EndpointData, next:EndpointData):Bool {
        final pex = f(join.x - prev.x), pey = f(join.y - prev.y);
        final prevLength = PathTessellator.length(pex, pey);
        final ptx = f(pex / prevLength), pty = f(pey / prevLength);
        final nex = f(next.x - join.x), ney = f(next.y - join.y);
        final nextLength = PathTessellator.length(nex, ney);
        final ntx = f(nex / nextLength), nty = f(ney / nextLength);
        PathTessellator.computeNormal(ptx, pty, ntx, nty, tmp);
        final normalX = tmp[0], normalY = tmp[1];

        if (Math.isNaN(join.advancement))
            join.advancement = f(prev.advancement + prevLength);
        if (Math.isNaN(next.advancement))
            next.advancement = f(join.advancement + nextLength);

        final p0x = f(join.x + f(normalX * vHalfWidth));
        final p0y = f(join.y + f(normalY * vHalfWidth));
        final pos = join.sidePoints[SIDE_POSITIVE];
        pos.prevX = pos.nextX = pos.singleX = p0x;
        pos.prevY = pos.nextY = pos.singleY = p0y;
        pos.hasSingle = true;

        final p1x = f(join.x - f(normalX * vHalfWidth));
        final p1y = f(join.y - f(normalY * vHalfWidth));
        final neg = join.sidePoints[SIDE_NEGATIVE];
        neg.prevX = neg.nextX = neg.singleX = p1x;
        neg.prevY = neg.nextY = neg.singleY = p1y;
        neg.hasSingle = true;

        final v0x = f(p0x - prev.sidePoints[SIDE_POSITIVE].nextX), v0y = f(p0y - prev.sidePoints[SIDE_POSITIVE].nextY);
        final v1x = f(p1x - prev.sidePoints[SIDE_NEGATIVE].nextX), v1y = f(p1y - prev.sidePoints[SIDE_NEGATIVE].nextY);
        if (f(f(pex * v0x) + f(pey * v0y)) < 0.0 && f(f(pex * v1x) + f(pey * v1y)) < 0.0)
            return true;

        vNormalX = normalX;
        vNormalY = normalY;
        final posVertex = addVertex();
        vNormalX = -normalX;
        vNormalY = -normalY;
        final negVertex = addVertex();

        pos.prevVertex = pos.nextVertex = posVertex;
        neg.prevVertex = neg.nextVertex = negVertex;
        return false;
    }

    function addEdgeTriangles(p0:EndpointData, p1:EndpointData):Void {
        var p0Neg = p0.sidePoints[SIDE_NEGATIVE].nextVertex;
        var p0Pos = p0.sidePoints[SIDE_POSITIVE].nextVertex;
        var p1Neg = p1.sidePoints[SIDE_NEGATIVE].prevVertex;
        var p1Pos = p1.sidePoints[SIDE_POSITIVE].prevVertex;

        if (p0.fold[SIDE_POSITIVE])
            p0Neg = p0.sidePoints[SIDE_POSITIVE].prevVertex;
        if (p0.fold[SIDE_NEGATIVE])
            p0Pos = p0.sidePoints[SIDE_NEGATIVE].prevVertex;
        if (p1.fold[SIDE_POSITIVE])
            p1Neg = p1.sidePoints[SIDE_POSITIVE].nextVertex;
        if (p1.fold[SIDE_NEGATIVE])
            p1Pos = p1.sidePoints[SIDE_NEGATIVE].nextVertex;

        if (p0Neg == p1Pos)
            return;
        if (p0Neg != p0Pos && p0Pos != p1Pos)
            addTriangle(p0Neg, p0Pos, p1Pos);
        if (p0Neg != p1Neg && p1Pos != p1Neg)
            addTriangle(p0Neg, p1Pos, p1Neg);
    }

    function tessellateJoin(join:EndpointData):Void {
        final pos = join.sidePoints[SIDE_POSITIVE];
        final neg = join.sidePoints[SIDE_NEGATIVE];
        final sideNeedsJoin = [
            !pos.hasSingle && !join.fold[SIDE_NEGATIVE],
            !neg.hasSingle && !join.fold[SIDE_POSITIVE]
        ];

        if (!join.fold[SIDE_POSITIVE] && !join.fold[SIDE_NEGATIVE]) {
            if (sideNeedsJoin[0] && sideNeedsJoin[1]) {
                addTriangle(pos.prevVertex, pos.nextVertex, neg.nextVertex);
                addTriangle(pos.prevVertex, neg.nextVertex, neg.prevVertex);
            }
            else if (!sideNeedsJoin[0] && sideNeedsJoin[1]) {
                addTriangle(neg.prevVertex, pos.prevVertex, neg.nextVertex);
            }
            else if (sideNeedsJoin[0] && !sideNeedsJoin[1]) {
                addTriangle(neg.prevVertex, pos.prevVertex, pos.nextVertex);
            }
        }

        for (side in 0...2) {
            if (!sideNeedsJoin[side])
                continue;
            if (join.lineJoin == Round)
                tessellateRoundJoin(join, side);
        }
    }

    function tessellateRoundJoin(join:EndpointData, side:Int):Void {
        final cx = join.x, cy = join.y;
        final radius = join.halfWidth;
        final sp = join.sidePoints[side];
        final snx = f(sp.prevX - cx), sny = f(sp.prevY - cy);
        final enx = f(sp.nextX - cx), eny = f(sp.nextY - cy);
        var startVertex = sp.prevVertex;
        var endVertex = sp.nextVertex;
        final angleSign = side == SIDE_NEGATIVE ? 1.0 : -1.0;
        var startAngle = PathTessellator.fastAtan2(sny, snx);
        var diff = angleTo(startAngle, PathTessellator.fastAtan2(eny, enx));
        if (f(diff * angleSign) < 0.0)
            diff = f(angleSign * f(f(2.0 * PathTessellator.PI_F32) - Math.abs(diff)));
        var endAngle = f(startAngle + diff);
        if (side == SIDE_NEGATIVE) {
            final a = startAngle;
            startAngle = endAngle;
            endAngle = a;
            final v = startVertex;
            startVertex = endVertex;
            endVertex = v;
        }
        final numSubdivisions = numArcSubdivisions(radius, tolerance, diff);
        tessellateArc(startAngle, endAngle, startVertex, endVertex, numSubdivisions);
    }

    /** euclid `Angle::angle_to`: `2 d % max - d` with `d = (to - from) % max` */
    static function angleTo(a:Float, b:Float):Float {
        final max = f(PathTessellator.PI_F32 * 2);
        // The f64 remainder of two f32 values is exact
        final d = f(b - a) % max;
        return f((f(2 * d) % max) - d);
    }

    static function numArcSubdivisions(radius:Float, tolerance:Float, angle:Float):Int {
        // circle_flattening_step
        final tol = Math.min(tolerance, radius);
        final step = f(2.0 * f(Math.acos(f(f(radius - tol) / radius))));
        final numSegments = Math.ceil(f(Math.abs(angle) / step));
        final l = f(Math.log(numSegments) / Math.log(2));
        if (Math.isNaN(l) || l < 0)
            return 0;
        final r = gpui.util.MathUtil.round(l);
        return Std.int(Math.min(r, 16));
    }

    function tessellateArc(a0:Float, a1:Float, va:Int, vb:Int, numRecursions:Int):Void {
        if (numRecursions == 0)
            return;
        final mid = f(f(a0 + a1) * 0.5);
        vNormalX = f(Math.cos(mid));
        vNormalY = f(Math.sin(mid));
        final vertex = addVertex();
        addTriangle(va, vertex, vb);
        tessellateArc(a0, mid, va, vertex, numRecursions - 1);
        tessellateArc(mid, a1, vertex, vb, numRecursions - 1);
    }

    function addJoinBaseVertices(join:EndpointData, side:Int):Void {
        final sp = join.sidePoints[side];
        if (sp.hasSingle) {
            vNormalX = f(f(sp.singleX - join.x) / join.halfWidth);
            vNormalY = f(f(sp.singleY - join.y) / join.halfWidth);
            final vertex = addVertex();
            sp.prevVertex = vertex;
            sp.nextVertex = vertex;
        }
        else {
            vNormalX = f(f(sp.prevX - join.x) / join.halfWidth);
            vNormalY = f(f(sp.prevY - join.y) / join.halfWidth);
            final prevVertex = addVertex();
            vNormalX = f(f(sp.nextX - join.x) / join.halfWidth);
            vNormalY = f(f(sp.nextY - join.y) / join.halfWidth);
            final nextVertex = addVertex();
            sp.prevVertex = prevVertex;
            sp.nextVertex = nextVertex;
        }
    }

    function closeSubPath():Void {
        if (pbCount == 1)
            tessellateEmptyCap();
        if (pbCount <= 2)
            return;

        final p = firsts[0].copy();
        final advancement = p.advancement;
        p.advancement = Math.NaN;
        final segmentAdded = fixedWidthStepImpl(p);
        if (!segmentAdded) {
            final last = pbLast();
            last.x = p.x;
            last.y = p.y;
        }

        if (firsts.length >= 2) {
            final p2 = firsts[1].copy();
            fixedWidthStepImpl(p2);

            final p0 = pbGet(pbCount - 2);
            final p1 = pbGet(pbCount - 1);
            vPosX = p0.x;
            vPosY = p0.y;
            vHalfWidth = p0.halfWidth;
            for (side in 0...2) {
                final sp = p0.sidePoints[side];
                if (sp.hasSingle) {
                    vNormalX = f(f(sp.singleX - p0.x) / p0.halfWidth);
                    vNormalY = f(f(sp.singleY - p0.y) / p0.halfWidth);
                }
                else {
                    vNormalX = f(f(sp.nextX - p0.x) / p0.halfWidth);
                    vNormalY = f(f(sp.nextY - p0.y) / p0.halfWidth);
                }
                sp.nextVertex = addVertex();
            }
            addEdgeTriangles(p0, p1);
        }
    }

    function tessellateEmptyCap():Void {
        final point = pbGet(0);
        vHalfWidth = point.halfWidth;
        switch options.startCap {
            case Square:
                vPosX = point.x;
                vPosY = point.y;
                final normals = [1.0, 1.0, 1.0, -1.0, -1.0, -1.0, -1.0, 1.0];
                final ids = [];
                for (i in 0...4) {
                    vNormalX = normals[i * 2];
                    vNormalY = normals[i * 2 + 1];
                    ids.push(addVertex());
                }
                addTriangle(ids[0], ids[1], ids[2]);
                addTriangle(ids[0], ids[2], ids[3]);
            case Round:
                vPosX = point.x;
                vPosY = point.y;
                final radius = vHalfWidth;
                vNormalX = -1.0;
                vNormalY = 0.0;
                final left = addVertex();
                vNormalX = 1.0;
                vNormalY = 0.0;
                final right = addVertex();
                tessellateRoundCap(point.x, point.y, radius, -1.0, 0.0, left, right, 0.0, 1.0, true);
                tessellateRoundCap(point.x, point.y, radius, 1.0, 0.0, right, left, 0.0, -1.0, false);
            case Butt:
        }
    }

    function tessellateRoundCap(cx:Float, cy:Float, radius:Float, snx:Float, sny:Float, startVertex:Int, endVertex:Int, enx:Float, eny:Float, isStart:Bool):Void {
        if (radius < tolerance)
            return;
        final startAngle = PathTessellator.fastAtan2(sny, snx);
        final diff = angleTo(startAngle, PathTessellator.fastAtan2(eny, enx));
        final midAngle = f(startAngle + diff);
        final endAngle = f(midAngle + diff);
        final numSubdivisions = numArcSubdivisions(radius, tolerance, diff);
        vPosX = cx;
        vPosY = cy;
        vHalfWidth = radius;
        final len = PathTessellator.length(enx, eny);
        vNormalX = f(enx / len);
        vNormalY = f(eny / len);
        final midVertex = addVertex();
        addTriangle(startVertex, midVertex, endVertex);
        tessellateArc(startAngle, midAngle, startVertex, midVertex, numSubdivisions);
        tessellateArc(midAngle, endAngle, midVertex, endVertex, numSubdivisions);
    }

    function endWithCaps():Void {
        final count = pbCount;
        if (mayNeedEmptyCap && count == 1) {
            tessellateEmptyCap();
            return;
        }
        if (count >= 2) {
            var p0 = pbGet(count - 2).copy();
            var p1 = pbGet(count - 1).copy();
            final ex = f(p1.x - p0.x), ey = f(p1.y - p0.y);
            final len = PathTessellator.length(ex, ey);
            final tx = f(ex / len), ty = f(ey / len);
            final nx = f(-ty * p1.halfWidth), ny = f(tx * p1.halfWidth);
            p1.sidePoints[SIDE_POSITIVE].prevX = f(p1.x + nx);
            p1.sidePoints[SIDE_POSITIVE].prevY = f(p1.y + ny);
            p1.sidePoints[SIDE_NEGATIVE].prevX = f(p1.x - nx);
            p1.sidePoints[SIDE_NEGATIVE].prevY = f(p1.y - ny);

            final isFirst = count == 2;
            tessellateLastEdge(p0, p1, isFirst);
            subPathStartAdvancement = p1.advancement;

            if (count > 2) {
                p0 = firsts[0];
                p1 = firsts[1];
            }
            tessellateFirstEdge(p0, p1);
        }
    }

    function tessellateLastEdge(p0:EndpointData, p1:EndpointData, isFirstEdge:Bool):Void {
        final vx = f(p1.x - p0.x), vy = f(p1.y - p0.y);
        p1.advancement = f(p0.advancement + PathTessellator.length(vx, vy));
        vPosX = p1.x;
        vPosY = p1.y;
        vHalfWidth = p1.halfWidth;

        final out = [0.0, 0.0];
        for (side in 0...2) {
            final sp = p1.sidePoints[side];
            final sideX = sp.prevX, sideY = sp.prevY;
            final clip:Null<Float> = switch options.endCap {
                case Square: p1.halfWidth;
                case Butt: 0.0;
                case Round: null;
            };
            if (clip != null) {
                final len = PathTessellator.length(vx, vy);
                final nx = f(vx / len), ny = f(vy / len);
                final cpx = f(p1.x + f(nx * clip)), cpy = f(p1.y + f(ny * clip));
                final svx = f(sideX - p0.sidePoints[side].nextX), svy = f(sideY - p0.sidePoints[side].nextY);
                if (PathTessellator.lineIntersection(cpx, cpy, -ny, nx, sideX, sideY, svx, svy, out)) {
                    sp.prevX = out[0];
                    sp.prevY = out[1];
                }
            }
            vNormalX = f(f(sp.prevX - p1.x) / p1.halfWidth);
            vNormalY = f(f(sp.prevY - p1.y) / p1.halfWidth);
            sp.prevVertex = addVertex();
        }

        if (!isFirstEdge)
            addEdgeTriangles(p0, p1);

        if (options.endCap == Round) {
            final pos = p1.sidePoints[SIDE_POSITIVE];
            tessellateRoundCap(p1.x, p1.y, p1.halfWidth, f(pos.prevX - p1.x), f(pos.prevY - p1.y), pos.prevVertex, p1.sidePoints[SIDE_NEGATIVE].prevVertex, vx, vy, false);
        }
    }

    function tessellateFirstEdge(first:EndpointData, second:EndpointData):Void {
        vPosX = first.x;
        vPosY = first.y;
        vHalfWidth = first.halfWidth;

        final out = [0.0, 0.0];
        for (side in 0...2) {
            final sp = first.sidePoints[side];
            var sideX = sp.nextX, sideY = sp.nextY;
            final clip:Null<Float> = switch options.startCap {
                case Square: first.halfWidth;
                case Butt: 0.0;
                case Round: null;
            };
            if (clip != null) {
                final dx = f(first.x - second.x), dy = f(first.y - second.y);
                final len = PathTessellator.length(dx, dy);
                final nx = f(dx / len), ny = f(dy / len);
                final cpx = f(first.x + f(nx * clip)), cpy = f(first.y + f(ny * clip));
                final svx = f(sideX - second.sidePoints[side].prevX), svy = f(sideY - second.sidePoints[side].prevY);
                if (PathTessellator.lineIntersection(cpx, cpy, -ny, nx, sideX, sideY, svx, svy, out)) {
                    sideX = out[0];
                    sideY = out[1];
                }
            }
            vNormalX = f(f(sideX - first.x) / first.halfWidth);
            vNormalY = f(f(sideY - first.y) / first.halfWidth);
            sp.nextVertex = addVertex();
        }

        addEdgeTriangles(first, second);

        if (options.startCap == Round) {
            final neg = first.sidePoints[SIDE_NEGATIVE];
            tessellateRoundCap(first.x, first.y, first.halfWidth, f(neg.nextX - first.x), f(neg.nextY - first.y), neg.nextVertex, first.sidePoints[SIDE_POSITIVE].nextVertex, f(first.x - second.x), f(first.y - second.y), true);
        }
    }

}

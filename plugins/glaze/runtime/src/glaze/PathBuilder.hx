// Ported from gpui-pre 0.3.10: src/path_builder.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// lyon's SVG path builder (lyon_path 1.0.19: builder.rs, WithSvg) and arcs
// (lyon_geom 1.0.19: arc.rs) are adapted here, with euclid 0.22.14
// (transform2d.rs, rotation.rs). lyon: Copyright (c) 2013 Nicolas Silva,
// licensed under MIT OR Apache-2.0 (used here under MIT). euclid: Copyright
// (c) 2013 The Servo Project Developers, licensed under MIT OR Apache-2.0
// (used here under MIT).
package glaze;

import glaze.Path.FillOptions;
import glaze.Path.StrokeOptions;
import glaze.PathTessellator.LyonPath;

/**
 * Style of a path built by `PathBuilder`.
 */
enum PathStyle {
    Stroke(options:StrokeOptions);
    Fill(options:FillOptions);
}

/**
 * A path builder, to paint filled or stroked paths with `Window.paintPath()`.
 *
 * Like GPUI, the commands are recorded like lyon's SVG path builder (arcs
 * become the same quadratic curves), in `f32`, and `build()` tessellates
 * them with the port of lyon in `PathTessellator` (bit identical vertices):
 *
 * - strokes: lyon's stroke tessellation, kept as the path `vertices`
 *   (triangles), like GPUI;
 * - fills: GPUI keeps lyon's fill triangles; the port keeps the outline they
 *   cover instead (`fillPolygons`: lyon's flattened curves and the vertices
 *   lyon inserts where edges cross, with the fill rule), which covers the
 *   same samples, and leaves `vertices` empty.
 *
 * `Window.paintPath()` rasterizes them like GPUI's Metal renderer (see
 * `PathRasterizer`). The bounds are those of lyon's vertices.
 */
class PathBuilder {

    // lyon's `Verb` order (`end_if_needed` compares them)
    static inline final VERB_LINE = 0;
    static inline final VERB_QUAD = 1;
    static inline final VERB_CUBIC = 2;
    static inline final VERB_BEGIN = 3;
    static inline final VERB_CLOSE = 4;
    static inline final VERB_END = 5;

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

    /** The recorded path (lyon `BuilderImpl`) */
    final raw = new LyonPath();

    // lyon `WithSvg` state
    var firstX:Float = 0;
    var firstY:Float = 0;
    var currentX:Float = 0;
    var currentY:Float = 0;
    var needMoveTo:Bool = true;
    var isEmpty:Bool = true;
    var lastCmd:Int = VERB_END;

    /** euclid `Transform2D` (`[m11, m12, m21, m22, m31, m32]`) or null */
    var transformMatrix:Null<Array<Float>> = null;

    /** The style of the path (fill or stroke) */
    public var style:PathStyle;

    var dashArrayValue:Null<Array<Float>> = null;

    public function new(?style:PathStyle) {
        this.style = style != null ? style : Fill(new FillOptions());
    }

    /** Creates a new path builder for a stroked path of the given width. */
    public static function stroke(width:Pixels):PathBuilder {
        return new PathBuilder(Stroke(new StrokeOptions().withLineWidth(width)));
    }

    /** Creates a new path builder for a filled path. */
    public static function fill():PathBuilder {
        return new PathBuilder();
    }

    /** Sets the style of the path. */
    public function withStyle(style:PathStyle):PathBuilder {
        this.style = style;
        return this;
    }

    /**
     * Sets the dash array of the stroke. If an odd number of values is
     * provided, the list is repeated to yield an even number of values.
     */
    public function dashArray(dashArray:Array<Pixels>):PathBuilder {
        final array:Array<Float> = [for (v in dashArray) f(v)];
        if (array.length % 2 == 1) {
            for (v in dashArray)
                array.push(f(v));
        }
        dashArrayValue = array;
        return this;
    }

    /** Move the current point to the given point. */
    public function moveTo(to:Point):Void {
        svgMoveTo(f(to.x), f(to.y));
    }

    /** Draw a straight line from the current point to the given point. */
    public function lineTo(to:Point):Void {
        svgLineTo(f(to.x), f(to.y));
    }

    /** Draw a quadratic curve from the current point to the given point, using the given control point. */
    public function curveTo(to:Point, ctrl:Point):Void {
        final x = f(to.x);
        final y = f(to.y);
        if (beginIfNeeded(x, y))
            return;
        currentX = x;
        currentY = y;
        lastCmd = VERB_QUAD;
        raw.quadraticBezierTo(f(ctrl.x), f(ctrl.y), x, y);
    }

    /** Adds a cubic Bezier to the path. */
    public function cubicBezierTo(to:Point, controlA:Point, controlB:Point):Void {
        final x = f(to.x);
        final y = f(to.y);
        if (beginIfNeeded(x, y))
            return;
        currentX = x;
        currentY = y;
        lastCmd = VERB_CUBIC;
        raw.cubicBezierTo(f(controlA.x), f(controlA.y), f(controlB.x), f(controlB.y), x, y);
    }

    /**
     * Adds an elliptical arc (SVG semantics). `xRotation` is in degrees.
     * Like lyon's SVG builder, the arc is converted to quadratic curves
     * (at most a quarter of pi each).
     */
    public function arcTo(radii:Point, xRotation:Pixels, largeArc:Bool, sweep:Bool, to:Point):Void {
        svgArcTo(f(radii.x), f(radii.y), PathTessellator.toRadians(f(xRotation)), largeArc, sweep, f(to.x), f(to.y));
    }

    /**
     * Equivalent to `arcTo` in relative coordinates.
     */
    public function relativeArcTo(radii:Point, xRotation:Pixels, largeArc:Bool, sweep:Bool, to:Point):Void {
        svgArcTo(f(radii.x), f(radii.y), PathTessellator.toRadians(f(xRotation)), largeArc, sweep, f(currentX + f(to.x)), f(currentY + f(to.y)));
    }

    /** Adds a polygon. */
    public function addPolygon(points:Array<Point>, closed:Bool):Void {
        if (points.length == 0)
            return;
        moveTo(points[0]);
        for (i in 1...points.length)
            lineTo(points[i]);
        if (closed)
            close();
    }

    /** Close the current sub-path. */
    public function close():Void {
        if (needMoveTo)
            return;
        currentX = firstX;
        currentY = firstY;
        needMoveTo = true;
        lastCmd = VERB_CLOSE;
        raw.end(true);
    }

/// lyon WithSvg

    function svgMoveTo(x:Float, y:Float):Void {
        endIfNeeded();
        raw.begin(x, y);
        isEmpty = false;
        needMoveTo = false;
        firstX = currentX = x;
        firstY = currentY = y;
        lastCmd = VERB_BEGIN;
    }

    function svgLineTo(x:Float, y:Float):Void {
        if (beginIfNeeded(x, y))
            return;
        currentX = x;
        currentY = y;
        lastCmd = VERB_LINE;
        raw.lineTo(x, y);
    }

    /**
     * lyon `begin_if_needed`: inserts a move to when needed. Returns true
     * when the command must be skipped (the very first command of a path
     * that is not a move to only moves to its end point).
     */
    function beginIfNeeded(x:Float, y:Float):Bool {
        if (!needMoveTo)
            return false;
        if (isEmpty) {
            svgMoveTo(x, y);
            return true;
        }
        svgMoveTo(firstX, firstY);
        return false;
    }

    inline function endIfNeeded():Void {
        if (lastCmd <= VERB_BEGIN)
            raw.end(false);
    }

    /** lyon `WithSvg::arc_to` and `SvgArc::to_arc` (`Arc::from_svg_arc`) */
    function svgArcTo(radiusX:Float, radiusY:Float, xRotation:Float, largeArc:Bool, sweep:Bool, toX:Float, toY:Float):Void {
        final fromX = currentX;
        final fromY = currentY;
        final eps = 1.1920928955078125e-7; // f32::EPSILON
        if (Math.abs(radiusX) <= eps || Math.abs(radiusY) <= eps || (fromX == toX && fromY == toY)) {
            svgLineTo(toX, toY);
            return;
        }

        var rx = Math.abs(radiusX);
        var ry = Math.abs(radiusY);
        final twoPi = f(PathTessellator.PI_F32 * 2);
        // The f64 remainder of two f32 values is exact
        final xr = xRotation % twoPi;
        final cosPhi = f(Math.cos(xr));
        final sinPhi = f(Math.sin(xr));
        final hdX = f(f(fromX - toX) / 2);
        final hdY = f(f(fromY - toY) / 2);
        final hsX = f(f(fromX + toX) / 2);
        final hsY = f(f(fromY + toY) / 2);
        final px = f(f(cosPhi * hdX) + f(sinPhi * hdY));
        final py = f(f(-sinPhi * hdX) + f(cosPhi * hdY));
        final rf = f(f(f(px * px) / f(rx * rx)) + f(f(py * py) / f(ry * ry)));
        if (rf > 1) {
            final scale = f(Math.sqrt(rf));
            rx = f(rx * scale);
            ry = f(ry * scale);
        }
        final rxry = f(rx * ry);
        final rxpy = f(rx * py);
        final rypx = f(ry * px);
        final sumOfSq = f(f(rxpy * rxpy) + f(rypx * rypx));
        final signCoe = largeArc == sweep ? -1.0 : 1.0;
        final coe = f(signCoe * f(Math.sqrt(Math.abs(f(f(f(rxry * rxry) - sumOfSq) / sumOfSq)))));
        final transformedCx = f(f(coe * rxpy) / ry);
        final transformedCy = f(f(-coe * rypx) / rx);
        final centerX = f(f(f(cosPhi * transformedCx) - f(sinPhi * transformedCy)) + hsX);
        final centerY = f(f(f(sinPhi * transformedCx) + f(cosPhi * transformedCy)) + hsY);
        final startAngle = PathTessellator.fastAtan2(f(f(py - transformedCy) / ry), f(f(px - transformedCx) / rx));
        final endAngle = PathTessellator.fastAtan2(f(f(-py - transformedCy) / ry), f(f(-px - transformedCx) / rx));
        var sweepAngle = f(endAngle - startAngle) % twoPi;
        if (sweep && sweepAngle < 0)
            sweepAngle = f(sweepAngle + twoPi);
        else if (!sweep && sweepAngle > 0)
            sweepAngle = f(sweepAngle - twoPi);

        svgArc(centerX, centerY, rx, ry, sweepAngle, xRotation);
    }

    /** lyon `WithSvg::arc` and `arc_to_quadratic_beziers_with_t` */
    function svgArc(centerX:Float, centerY:Float, rx:Float, ry:Float, sweepAngle:Float, xRotation:Float):Void {
        // euclid ApproxEq (f32 epsilon 1e-6)
        final approxEps = f(1.0e-6);
        if (Math.abs(f(currentX - centerX)) < approxEps && Math.abs(f(currentY - centerY)) < approxEps)
            return;

        final startAngle = f(PathTessellator.fastAtan2(f(currentY - centerY), f(currentX - centerX)) - xRotation);
        final cosR = f(Math.cos(xRotation));
        final sinR = f(Math.sin(xRotation));
        final out = [0.0, 0.0];
        // sample_ellipse: Rotation2D(x_rotation).transform_point(rx cos a, ry sin a)
        inline function ellipse(angle:Float) {
            final ex = f(rx * f(Math.cos(angle)));
            final ey = f(ry * f(Math.sin(angle)));
            out[0] = f(centerX + f(f(ex * cosR) - f(ey * sinR)));
            out[1] = f(centerY + f(f(ey * cosR) + f(ex * sinR)));
        }

        // arc.from(): sample(0)
        ellipse(f(startAngle + f(sweepAngle * 0)));
        final startX = out[0];
        final startY = out[1];
        if (needMoveTo) {
            svgMoveTo(startX, startY);
        }
        else if (PathTessellator.squareLength(f(startX - currentX), f(startY - currentY)) > f(0.01)) {
            raw.lineTo(startX, startY);
        }

        // arc_to_quadratic_beziers_with_t
        final sign = sweepAngle > 0 ? 1.0 : (sweepAngle < 0 ? -1.0 : (1 / sweepAngle < 0 ? -1.0 : 1.0));
        final absSweep = Math.min(Math.abs(sweepAngle), f(PathTessellator.PI_F32 * 2));
        final nSteps = Math.ceil(f(absSweep / f(Math.PI / 4)));
        final step = f(f(absSweep / nSteps) * sign);
        final alpha = f(Math.tan(f(step * 0.5)));
        final n = Std.int(nSteps);
        for (i in 0...n) {
            final a1 = f(startAngle + f(step * i));
            final a2 = f(startAngle + f(step * (i + 1)));
            ellipse(a1);
            final fromX = out[0];
            final fromY = out[1];
            ellipse(a2);
            final toX = out[0];
            final toY = out[1];
            // tangent_at_angle: Rotation2D(x_rotation).transform_vector(-rx sin a, ry cos a)
            final tx = f(-rx * f(Math.sin(a1)));
            final ty = f(ry * f(Math.cos(a1)));
            final ctrlX = f(fromX + f(f(f(tx * cosR) - f(ty * sinR)) * alpha));
            final ctrlY = f(fromY + f(f(f(ty * cosR) + f(tx * sinR)) * alpha));
            raw.quadraticBezierTo(ctrlX, ctrlY, toX, toY);
            currentX = toX;
            currentY = toY;
        }
    }

/// Transforms

    /**
     * Applies a transform to the path (row vector convention like lyon:
     * `x' = a x + c y + e`, `y' = b x + d y + f`).
     */
    public function transform(a:Float, b:Float, c:Float, d:Float, e:Float, ff:Float):Void {
        transformMatrix = [f(a), f(b), f(c), f(d), f(e), f(ff)];
    }

    /** Apply a translation to the path (after the current transform). */
    public function translate(to:Point):Void {
        final translation = [1.0, 0.0, 0.0, 1.0, f(to.x), f(to.y)];
        transformMatrix = transformMatrix != null ? PathTessellator.then(transformMatrix, translation) : translation;
    }

    /** Apply a scale to the path (after the current transform). */
    public function scale(scale:Float):Void {
        final s = f(scale);
        final scaling = [s, 0.0, 0.0, s, 0.0, 0.0];
        transformMatrix = transformMatrix != null ? PathTessellator.then(transformMatrix, scaling) : scaling;
    }

    /** Apply a rotation, in degrees, to the path (after the current transform). */
    public function rotate(angle:Float):Void {
        final rotation = PathTessellator.rotation(PathTessellator.toRadians(f(angle)));
        transformMatrix = transformMatrix != null ? PathTessellator.then(transformMatrix, rotation) : rotation;
    }

/// Build

    /** The recorded lyon path (transformed), as `build()` tessellates it. */
    public function lyonPath():LyonPath {
        var path = new LyonPath();
        for (v in raw.verbs)
            path.verbs.push(v);
        for (p in raw.points)
            path.points.push(p);
        if (lastCmd <= VERB_BEGIN)
            path.verbs.push(LyonPath.END);
        if (transformMatrix != null)
            path = path.transformed(transformMatrix);
        return path;
    }

    /**
     * Builds the path. Throws if the path cannot be built.
     */
    public function build():Path {
        var path = lyonPath();
        switch style {
            case Stroke(options):
                if (dashArrayValue != null)
                    path = PathTessellator.dashed(path, dashArrayValue);
                final geometry = PathTessellator.stroke(path, options);
                final result = buildPath(geometry);
                result.stroke = options;
                return result;
            case Fill(options):
                final polygons = PathTessellator.fillPolygons(path, f(options.tolerance));
                final result = fillPath(polygons);
                result.fillPolygons = polygons;
                result.fillRule = options.fillRule;
                return result;
        }
    }

    /** Rust `build_path`: a path made of the tessellation triangles. */
    static function buildPath(geometry:PathTessellator.StrokeGeometry):Path {
        final vertices = geometry.vertices;
        if (vertices.length == 0)
            return new Path(new Point(0, 0));
        final path = new Path(new Point(vertices[0], vertices[1]));
        final indices = geometry.indices;
        var i = 0;
        while (i + 2 < indices.length) {
            final a = indices[i] * 2;
            final b = indices[i + 1] * 2;
            final c = indices[i + 2] * 2;
            path.pushTriangle(
                new Point(vertices[a], vertices[a + 1]),
                new Point(vertices[b], vertices[b + 1]),
                new Point(vertices[c], vertices[c + 1])
            );
            i += 3;
        }
        return path;
    }

    /**
     * The path of a fill: no triangles (see the class documentation), the
     * bounds of lyon's vertices, starting at the first one of its sweep.
     */
    static function fillPath(polygons:Array<Array<Float>>):Path {
        var firstX = Math.POSITIVE_INFINITY;
        var firstY = Math.POSITIVE_INFINITY;
        for (poly in polygons) {
            var i = 0;
            while (i < poly.length) {
                if (PathTessellator.isAfter(firstX, firstY, poly[i], poly[i + 1])) {
                    firstX = poly[i];
                    firstY = poly[i + 1];
                }
                i += 2;
            }
        }
        if (firstX == Math.POSITIVE_INFINITY)
            return new Path(new Point(0, 0));
        final path = new Path(new Point(firstX, firstY));
        for (poly in polygons) {
            var i = 0;
            while (i < poly.length) {
                path.unionBounds(poly[i], poly[i + 1]);
                i += 2;
            }
        }
        return path;
    }

}

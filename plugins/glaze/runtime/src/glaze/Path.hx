// Ported from gpui-pre 0.3.10: src/scene.rs (Path, PathVertex)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A line made up of a series of vertices and control points (Rust
 * `Path<Pixels>`), painted with `Window.paintPath()`.
 *
 * Like GPUI, a path is a list of triangles (`moveTo`, `lineTo`, `curveTo`
 * push the triangles of a fan, quadratic curves use Loop-Blinn coordinates
 * in `st`), with positions and bounds in `f32` like GPUI. Stroked paths
 * made by `PathBuilder` hold lyon's stroke triangles, like GPUI. Filled
 * paths made by `PathBuilder` hold the outline lyon's fill tessellation
 * covers instead of its triangles (`fillPolygons`, with `fillRule`), and no
 * `vertices`. `PathRasterizer` reproduces the 4x MSAA rasterization of
 * GPUI's Metal renderer from them.
 */
class Path {

    /**
     * Bounds of the vertices (logical pixels). Kept as four values while
     * the path grows (a `Bounds` per vertex otherwise), made on demand.
     */
    public var bounds(get, set):Bounds;

    var boundsLeft:Float = 0;
    var boundsTop:Float = 0;
    var boundsWidth:Float = 0;
    var boundsHeight:Float = 0;
    var boundsObject:Null<Bounds> = null;

    function get_bounds():Bounds {
        var result = boundsObject;
        if (result == null) {
            result = new Bounds(new Point(boundsLeft, boundsTop), new Size(boundsWidth, boundsHeight));
            boundsObject = result;
        }
        return result;
    }

    function set_bounds(value:Bounds):Bounds {
        boundsLeft = value.origin.x;
        boundsTop = value.origin.y;
        boundsWidth = value.size.width;
        boundsHeight = value.size.height;
        boundsObject = value;
        return value;
    }

    /** Triangles: 3 vertices each */
    public final vertices:Array<PathVertex> = [];

    /** The content mask (set by `Window.paintPath()`) */
    public var contentMask:Null<ContentMask> = null;

    /** The color (set by `Window.paintPath()`) */
    public var color:Null<Background> = null;

    /**
     * The polygons covered by lyon's fill tessellation of a filled path made
     * by `PathBuilder` (`x, y` lists in logical pixels, closed implicitly),
     * or `null` for a path made of triangles.
     */
    public var fillPolygons:Null<Array<Array<Float>>> = null;

    /** Fill rule of `fillPolygons` */
    public var fillRule:FillRule = NonZero;

    /** Stroke options of a stroked path made by `PathBuilder` */
    public var stroke:Null<StrokeOptions> = null;

    var start:Point;

    var current:Point;

    var contourCount:Int = 0;

    /**
     * Create a new path with the given starting point.
     */
    public function new(start:Point) {
        start = new Point(SpringMath.f32(start.x), SpringMath.f32(start.y));
        this.start = start;
        this.current = start;
        this.bounds = new Bounds(start, new Size(0, 0));
    }

    /**
     * Move the start, current point to the given point.
     */
    public function moveTo(to:Point):Void {
        contourCount += 1;
        start = to;
        current = to;
    }

    /**
     * Draw a straight line from the current point to the given point.
     */
    public function lineTo(to:Point):Void {
        contourCount += 1;
        if (contourCount > 1) {
            pushTriangle(start, current, to, 0, 1, 0, 1, 0, 1);
        }
        current = to;
    }

    /**
     * Draw a curve from the current point to the given point, using the given control point.
     */
    public function curveTo(to:Point, ctrl:Point):Void {
        contourCount += 1;
        if (contourCount > 1) {
            pushTriangle(start, current, to, 0, 1, 0, 1, 0, 1);
        }
        pushTriangle(current, ctrl, to, 0, 0, 0.5, 0, 1, 1);
        current = to;
    }

    /**
     * Push a triangle to the Path (positions, then the `st` coordinates of
     * each vertex: (0, 1) everywhere for a solid triangle).
     */
    public function pushTriangle(a:Point, b:Point, c:Point, s0:Float = 0, t0:Float = 1, s1:Float = 0, t1:Float = 1, s2:Float = 0, t2:Float = 1):Void {
        a = new Point(SpringMath.f32(a.x), SpringMath.f32(a.y));
        b = new Point(SpringMath.f32(b.x), SpringMath.f32(b.y));
        c = new Point(SpringMath.f32(c.x), SpringMath.f32(c.y));
        unionBounds(a.x, a.y);
        unionBounds(b.x, b.y);
        unionBounds(c.x, c.y);
        vertices.push(new PathVertex(a, s0, t0));
        vertices.push(new PathVertex(b, s1, t1));
        vertices.push(new PathVertex(c, s2, t2));
    }

    /**
     * `bounds.union(Bounds { origin: (x, y), size: 0 })` in `f32`, like
     * GPUI (`from_corners(min of origins, max of bottom right corners)`).
     */
    @:allow(glaze.PathBuilder)
    function unionBounds(x:Float, y:Float):Void {
        final ox = boundsLeft;
        final oy = boundsTop;
        final right = Math.max(SpringMath.f32(ox + boundsWidth), x);
        final bottom = Math.max(SpringMath.f32(oy + boundsHeight), y);
        final left = Math.min(ox, x);
        final top = Math.min(oy, y);
        boundsLeft = left;
        boundsTop = top;
        boundsWidth = SpringMath.f32(right - left);
        boundsHeight = SpringMath.f32(bottom - top);
        boundsObject = null;
    }

    /**
     * Returns the bounds clipped by the content mask.
     */
    public function clippedBounds():Bounds {
        return contentMask != null ? bounds.intersect(contentMask.bounds) : bounds;
    }

}

/**
 * A vertex of a `Path`: a position and Loop-Blinn coordinates.
 */
class PathVertex {

    public final xyPosition:Point;

    public final s:Float;

    public final t:Float;

    public inline function new(xyPosition:Point, s:Float, t:Float) {
        this.xyPosition = xyPosition;
        this.s = s;
        this.t = t;
    }

}

/**
 * The fill rule of a filled path (lyon `FillRule`).
 */
enum abstract FillRule(Int) {
    var EvenOdd = 0;
    var NonZero = 1;
}

/**
 * Line cap of a stroke (lyon `LineCap`).
 */
enum abstract LineCap(Int) {
    var Butt = 0;
    var Square = 1;
    var Round = 2;
}

/**
 * Line join of a stroke (lyon `LineJoin`).
 */
enum abstract LineJoin(Int) {
    var Miter = 0;
    var MiterClip = 1;
    var Round = 2;
    var Bevel = 3;
}

/**
 * Options of a filled path (lyon `FillOptions`).
 */
@:structInit
class FillOptions {

    /** Maximum allowed distance to the path when building an approximation */
    public var tolerance:Float = 0.1;

    public var fillRule:FillRule = EvenOdd;

    public function new(tolerance:Float = 0.1, fillRule:FillRule = EvenOdd) {
        this.tolerance = tolerance;
        this.fillRule = fillRule;
    }

    public function withFillRule(fillRule:FillRule):FillOptions {
        return new FillOptions(tolerance, fillRule);
    }

    public function withTolerance(tolerance:Float):FillOptions {
        return new FillOptions(tolerance, fillRule);
    }

}

/**
 * Options of a stroked path (lyon `StrokeOptions`).
 */
@:structInit
class StrokeOptions {

    public var startCap:LineCap = Butt;

    public var endCap:LineCap = Butt;

    public var lineJoin:LineJoin = Miter;

    public var lineWidth:Float = 1.0;

    public var miterLimit:Float = 4.0;

    public var tolerance:Float = 0.1;

    public function new(lineWidth:Float = 1.0, lineJoin:LineJoin = Miter, startCap:LineCap = Butt, endCap:LineCap = Butt, miterLimit:Float = 4.0, tolerance:Float = 0.1) {
        this.lineWidth = lineWidth;
        this.lineJoin = lineJoin;
        this.startCap = startCap;
        this.endCap = endCap;
        this.miterLimit = miterLimit;
        this.tolerance = tolerance;
    }

    public function withLineWidth(width:Float):StrokeOptions {
        return new StrokeOptions(width, lineJoin, startCap, endCap, miterLimit, tolerance);
    }

    public function withLineJoin(join:LineJoin):StrokeOptions {
        return new StrokeOptions(lineWidth, join, startCap, endCap, miterLimit, tolerance);
    }

    public function withLineCap(cap:LineCap):StrokeOptions {
        return new StrokeOptions(lineWidth, lineJoin, cap, cap, miterLimit, tolerance);
    }

    public function withMiterLimit(limit:Float):StrokeOptions {
        return new StrokeOptions(lineWidth, lineJoin, startCap, endCap, limit, tolerance);
    }

}

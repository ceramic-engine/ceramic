package ceramic;

import clipper.Clipper;
import clipper.ClipperCore;
import clipper.ClipperOffset.EndType;
import clipper.ClipperOffset.JoinType;
import clipper.ClipperTriangulation.TriangulateResult;

using ceramic.Extensions;

/**
 * Display lines composed of multiple segments, curves and paths.
 *
 * Line extends Mesh to efficiently render stroked paths with configurable
 * thickness, joins, and caps. It automatically generates the necessary
 * triangles to represent the line with proper corners and end caps.
 *
 * Features:
 * - Variable thickness lines
 * - Miter, bevel, and round joins for corners
 * - Butt, square, and round caps for line ends
 * - Automatic loop closing
 * - Efficient triangle-based rendering
 *
 * The line is defined by a series of points in a flat array format:
 * [x0, y0, x1, y1, x2, y2, ...]
 *
 * Common uses:
 * - Drawing paths and routes
 * - Graph visualization
 * - UI decorations and dividers
 * - Debug visualization
 * - Vector graphics
 *
 * ```haxe
 * // Create a simple line
 * var line = new Line();
 * line.points = [
 *     10, 10,    // Start point
 *     50, 30,    // Middle point
 *     90, 10     // End point
 * ];
 * line.thickness = 3;
 * line.color = Color.RED;
 *
 * // Create a closed shape
 * var shape = new Line();
 * shape.points = [
 *     0, 0,
 *     100, 0,
 *     100, 100,
 *     0, 100,
 *     0, 0      // Close to start
 * ];
 * shape.loop = true;
 * shape.join = MITER;
 * shape.thickness = 2;
 * ```
 *
 * @see Mesh
 * @see LineJoin
 * @see LineCap
 */
class Line extends Mesh {
    // Static reusable arrays to prevent allocations
    static var _path:Path64 = null;
    static var _paths:Paths64 = null;
    static var _tmpVertices:Array<Float> = null;

    // Scale factor for float-to-int64 conversion
    // 100000 = 5 decimal places of precision (sub-pixel accuracy)
    static inline var SCALE:Float = 100000.0;
    static inline var INV_SCALE:Float = 1.0 / 100000.0;

    /**
     * Line points as a flat array of coordinates.
     *
     * Format: [x0, y0, x1, y1, x2, y2, ...]
     *
     * Points define the path the line follows. The line will be
     * stroked along this path with the specified thickness.
     *
     * Note: when editing array content without reassigning it,
     * `contentDirty` must be set to `true` to update the line.
     *
     * ```haxe
     * line.points = [0, 0, 100, 50, 200, 0]; // V-shaped line
     *
     * // Modifying existing array
     * line.points[2] = 150; // Change x1
     * line.contentDirty = true; // Must set to update
     * ```
     */
    public var points(default, set):Array<Float> = null;

    inline function set_points(points:Array<Float>):Array<Float> {
        this.points = points;
        contentDirty = true;
        return points;
    }

    /**
     * The limit before miters turn into bevels.
     *
     * When join is MITER, sharp corners can create very long points.
     * This parameter controls when those sharp corners get cut off
     * and rendered as square joins instead.
     *
     * The miter limit is compared against the cosine of the angle
     * between adjacent edges. Internally, if `cos(angle) > 2/miterLimit² - 1`,
     * a miter join is used; otherwise a square join is used.
     *
     * Practical values:
     * - miterLimit = 2: Angles up to ~120° get mitered, sharper angles get squared
     * - miterLimit = 4: Angles up to ~150° get mitered
     * - miterLimit = 10: Almost all angles get mitered, only extremely sharp angles get squared
     *
     * Lower values create more square corners, higher values allow sharper miter points.
     *
     * Default: 4
     */
    public var miterLimit(default, set):Float = 4;

    inline function set_miterLimit(miterLimit:Float):Float {
        if (this.miterLimit == miterLimit)
            return miterLimit;
        this.miterLimit = miterLimit;
        contentDirty = true;
        return miterLimit;
    }

    /**
     * The line thickness in pixels.
     *
     * Determines how wide the stroked line appears.
     * The line is centered on the path defined by points.
     *
     * Default: 1
     */
    public var thickness(default, set):Float = 1;

    inline function set_thickness(thickness:Float):Float {
        if (this.thickness == thickness)
            return thickness;
        this.thickness = thickness;
        contentDirty = true;
        return thickness;
    }

    /**
     * The join type for line corners.
     *
     * - MITER: Sharp corners (limited by miterLimit)
     * - BEVEL: Flat corners
     * - ROUND: Rounded corners
     *
     * MITER creates pointed corners but can extend far on acute angles.
     * BEVEL creates a flat edge between the two line segments.
     * ROUND creates smooth circular arcs at corners.
     *
     * Default: BEVEL
     */
    public var join(default, set):LineJoin = BEVEL;

    inline function set_join(join:LineJoin):LineJoin {
        if (this.join == join)
            return join;
        this.join = join;
        contentDirty = true;
        return join;
    }

    /**
     * The cap type for line ends.
     *
     * - BUTT: Line ends exactly at the point (default)
     * - SQUARE: Line extends past the point by half thickness
     * - ROUND: Semicircular cap
     *
     * SQUARE caps make lines appear slightly longer but can
     * look better when lines meet at their endpoints.
     * ROUND caps create smooth semicircular ends.
     *
     * Default: BUTT
     */
    public var cap(default, set):LineCap = BUTT;

    inline function set_cap(cap:LineCap):LineCap {
        if (this.cap == cap)
            return cap;
        this.cap = cap;
        contentDirty = true;
        return cap;
    }

    /**
     * Whether to close the line into a loop.
     *
     * If true and the first and last points are close enough,
     * connects them with proper joining. Creates closed shapes
     * from open paths.
     *
     * Useful for drawing polygons, closed curves, and shapes.
     *
     * Default: false
     */
    public var loop(default, set):Bool = false;

    inline function set_loop(loop:Bool):Bool {
        if (this.loop == loop)
            return loop;
        this.loop = loop;
        contentDirty = true;
        return loop;
    }

    /**
     * Density multiplier for round joins and caps.
     *
     * Controls the smoothness of ROUND joins and caps.
     * Higher values create smoother curves with more triangles.
     * Lower values create rougher curves with fewer triangles.
     *
     * The number of segments is calculated based on the arc angle
     * and this density multiplier. At 1.0, a full circle uses
     * approximately 90 segments.
     *
     * Default: 1.0
     */
    public var roundDensity(default, set):Float = 1.0;

    inline function set_roundDensity(roundDensity:Float):Float {
        if (this.roundDensity == roundDensity)
            return roundDensity;
        this.roundDensity = roundDensity;
        contentDirty = true;
        return roundDensity;
    }

    /**
     * Whether to automatically compute size from line points.
     *
     * When true, the line's width and height are set to encompass
     * all points. This ensures proper bounds for hit testing and
     * culling, but adds a small computation overhead.
     *
     * Set to false if you manually manage the line's size.
     *
     * Default: true
     */
    public var autoComputeSize(default, set):Bool = true;

    inline function set_autoComputeSize(autoComputeSize:Bool):Bool {
        if (this.autoComputeSize == autoComputeSize)
            return autoComputeSize;
        this.autoComputeSize = autoComputeSize;
        if (autoComputeSize)
            computeSize();
        return autoComputeSize;
    }

    /**
     * Generates the line geometry from points and settings.
     *
     * Uses Clipper2 to inflate the path and ceramic.Triangulate
     * to create triangulated geometry representing the stroked path.
     * This is called automatically when the line properties change.
     */
    override function computeContent() {
        if (points != null && points.length >= 4) {
            // Initialize static arrays if needed
            if (_path == null)
                _path = new Path64();
            if (_paths == null)
                _paths = new Paths64();
            if (_tmpVertices == null)
                _tmpVertices = [];

            // Clear and reuse the path array
            _path.resize(0);

            // Convert ceramic points to Clipper2 Path64
            var i = 0;
            while (i < points.length - 1) {
                var x = points.unsafeGet(i) * SCALE;
                var y = points.unsafeGet(i + 1) * SCALE;
                _path.push(Point64.fromFloats(x, y));
                i += 2;
            }

            // Map ceramic enums to Clipper2 enums
            var joinType:JoinType = switch (join) {
                case MITER: JoinType.Miter;
                case BEVEL: JoinType.Bevel;
                case ROUND: JoinType.Round;
            };

            // EndType.Joined for loops (strokes a closed path)
            // EndType.Butt/Square/Round for open paths (caps at endpoints)
            var endType:EndType = if (loop) {
                EndType.Joined;
            } else
                switch (cap) {
                    case BUTT: EndType.Butt;
                    case SQUARE: EndType.Square;
                    case ROUND: EndType.Round;
                };

            // Prepare paths wrapper (reuse array, just update content)
            _paths.resize(0);
            _paths.push(_path);

            // Inflate the path using Clipper2
            var delta = thickness * 0.5 * SCALE;
            // arcTolerance controls smoothness of round joins/caps
            // Target: 1 segment per pixel of circumference at roundDensity=1.0
            // stepsPer360 = PI * thickness * roundDensity (circumference in pixels)
            // arcTolerance = delta * (1 - cos(PI / stepsPer360))
            var stepsPer360 = Math.PI * thickness * roundDensity;
            var arcTolerance = delta * (1 - Math.cos(Math.PI / stepsPer360));
            var inflated = Clipper.inflatePaths(_paths, delta, joinType, endType, miterLimit, arcTolerance);

            // Convert inflated paths to vertices and triangulate
            buildMeshFromInflatedPaths(inflated, loop);
        }

        if (autoComputeSize)
            computeSize();

        contentDirty = false;
    }

    function buildMeshFromInflatedPaths(paths:Paths64, hasHoles:Bool) {
        if (vertices == null)
            vertices = [];
        if (indices == null)
            indices = [];

        // Clear existing data (resize to 0, no reallocation)
        vertices.resize(0);
        indices.resize(0);
        _tmpVertices.resize(0);

        if (hasHoles) {
            // For looped paths, EndType.Joined produces outer + inner polygons (holes).
            // Use Clipper2's Constrained Delaunay Triangulation which handles holes correctly.
            var triResult = Clipper.triangulate(paths, true);
            if (triResult.result == TriangulateResult.Success) {
                // Each path in solution is a triangle (3 points)
                var vertexIndex = 0;
                for (triangle in triResult.solution) {
                    if (triangle.length >= 3) {
                        // Add the 3 vertices
                        for (j in 0...3) {
                            var pt = triangle[j];
                            vertices.push(InternalClipper.toFloat(pt.x) * INV_SCALE);
                            vertices.push(InternalClipper.toFloat(pt.y) * INV_SCALE);
                        }
                        // Add triangle indices
                        indices.push(vertexIndex);
                        indices.push(vertexIndex + 1);
                        indices.push(vertexIndex + 2);
                        vertexIndex += 3;
                    }
                }
            }
        } else {
            // For open paths, use faster ear-clipping triangulation
            // (no holes to worry about - just a single polygon)
            for (path in paths) {
                if (path.length < 3)
                    continue;

                // Track starting vertex index for this polygon
                var startVertex = Std.int(_tmpVertices.length / 2);

                // Convert Path64 to flat float array for triangulation
                for (pt in path) {
                    _tmpVertices.push(InternalClipper.toFloat(pt.x) * INV_SCALE);
                    _tmpVertices.push(InternalClipper.toFloat(pt.y) * INV_SCALE);
                }

                // Triangulate this polygon using ceramic's ear-clipping
                Triangulate.triangulate(_tmpVertices, startVertex, path.length, indices);
            }

            // Copy temp vertices to mesh vertices
            for (i in 0..._tmpVertices.length) {
                vertices.push(_tmpVertices[i]);
            }
        }
    }

    /**
     * Computes the line's bounding box from its points.
     *
     * Finds the maximum x and y coordinates to set the line's
     * width and height. Called automatically when autoComputeSize
     * is true and content changes.
     */
    override function computeSize() {
        if (points != null && points.length >= 2) {
            var maxX:Float = 0;
            var maxY:Float = 0;
            var i = 0;
            var lenMinus1 = points.length - 1;
            while (i < lenMinus1) {
                var x = points.unsafeGet(i);
                if (x > maxX)
                    maxX = x;
                i++;
                var y = points.unsafeGet(i);
                if (y > maxY)
                    maxY = y;
                i++;
            }
            // Account for line thickness
            var halfThickness = thickness * 0.5;
            size(maxX + halfThickness, maxY + halfThickness);
        } else {
            size(0, 0);
        }
    }
}

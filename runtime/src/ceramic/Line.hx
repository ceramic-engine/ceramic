package ceramic;

import polyline.Stroke;

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
 * - Miter and bevel joins for corners
 * - Butt and square caps for line ends
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

    static var _stroke:Stroke = new Stroke();

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
     * If the miter length would exceed thickness * miterLimit,
     * the corner is rendered as a bevel instead.
     * 
     * Lower values create more bevels, higher values allow sharper corners.
     * 
     * Default: 10
     */
    public var miterLimit(default, set):Float = 10;
    inline function set_miterLimit(miterLimit:Float):Float {
        if (this.miterLimit == miterLimit) return miterLimit;
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
        if (this.thickness == thickness) return thickness;
        this.thickness = thickness;
        contentDirty = true;
        return thickness;
    }

    /**
     * The join type for line corners.
     * 
     * - MITER: Sharp corners (limited by miterLimit)
     * - BEVEL: Flat corners
     * 
     * MITER creates pointed corners but can extend far on acute angles.
     * BEVEL creates a flat edge between the two line segments.
     * 
     * Default: BEVEL
     */
    public var join(default, set):LineJoin = BEVEL;
    inline function set_join(join:LineJoin):LineJoin {
        if (this.join == join) return join;
        this.join = join;
        contentDirty = true;
        return join;
    }

    /**
     * The cap type for line ends.
     * 
     * - BUTT: Line ends exactly at the point (default)
     * - SQUARE: Line extends past the point by half thickness
     * 
     * SQUARE caps make lines appear slightly longer but can
     * look better when lines meet at their endpoints.
     * 
     * Default: BUTT
     */
    public var cap(default, set):LineCap = BUTT;
    inline function set_cap(cap:LineCap):LineCap {
        if (this.cap == cap) return cap;
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
        if (this.loop == loop) return loop;
        this.loop = loop;
        contentDirty = true;
        return loop;
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
        if (this.autoComputeSize == autoComputeSize) return autoComputeSize;
        this.autoComputeSize = autoComputeSize;
        if (autoComputeSize)
            computeSize();
        return autoComputeSize;
    }

    /**
     * Generates the line geometry from points and settings.
     * 
     * Uses the polyline library to create triangulated geometry
     * representing the stroked path. This is called automatically
     * when the line properties change.
     */
    override function computeContent() {

        if (points != null && points.length >= 4) {

            _stroke.miterLimit = miterLimit;
            _stroke.thickness = thickness;
            _stroke.join = join;
            _stroke.cap = cap;
            _stroke.canLoop = loop;

            if (vertices == null)
                vertices = [];

            if (indices == null)
                indices = [];

            _stroke.build(points, vertices, indices);
        }

        if (autoComputeSize)
            computeSize();

        contentDirty = false;

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
            size(maxX, maxY);
        }
        else {
            size(0, 0);
        }

    }

}

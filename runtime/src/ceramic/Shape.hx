package ceramic;

#if plugin_nape
import nape.geom.Vec2;
import nape.geom.Vec2List;
import nape.shape.Polygon;
#end

using ceramic.Extensions;

/**
 * A visual for drawing arbitrary 2D shapes with automatic triangulation.
 *
 * Shape extends Mesh but provides a simpler interface for defining polygons.
 * You only need to provide the outline points, and Shape automatically
 * triangulates them into triangles for rendering.
 *
 * Features:
 * - Automatic triangulation of concave polygons
 * - Support for complex shapes with holes (using advanced triangulation)
 * - Auto-computation of size from points
 * - Integration with Nape physics for collision shapes
 * - Efficient updates when shape changes
 *
 * The shape is defined by a series of points forming a closed polygon.
 * Points should be provided in counter-clockwise order for proper rendering.
 *
 * @example
 * ```haxe
 * // Create a triangle
 * var shape = new Shape();
 * shape.points = [
 *     50, 0,    // Top point
 *     0, 100,   // Bottom left
 *     100, 100  // Bottom right
 * ];
 * shape.color = Color.BLUE; // Fill color
 *
 * // Create a star shape
 * var star = new Shape();
 * var points = [];
 * for (i in 0...10) {
 *     var angle = i * Math.PI / 5;
 *     var radius = (i % 2 == 0) ? 50 : 25;
 *     points.push(Math.cos(angle) * radius + 50);
 *     points.push(Math.sin(angle) * radius + 50);
 * }
 * star.points = points;
 * star.color = Color.YELLOW; // Fill color
 * ```
 *
 * @see Mesh
 * @see Triangulate
 */
class Shape extends Mesh {

    /**
     * A flat array of vertex coordinates describing the shape outline.
     * Format: [x0, y0, x1, y1, x2, y2, ...]
     *
     * Setting this property automatically triggers triangulation.
     * When modifying the array contents directly (without reassigning),
     * you must set `contentDirty = true` to update the shape.
     *
     * Points should be in counter-clockwise order for proper rendering.
     * The shape is automatically closed (last point connects to first).
     */
    public var points(get, set):Array<Float>;
    inline function get_points():Array<Float> {
        return vertices;
    }
    inline function set_points(points:Array<Float>):Array<Float> {
        this.vertices = points;
        contentDirty = true;
        return points;
    }

    /**
     * If true, width and height are automatically computed from shape points.
     * This ensures the shape's bounds always match its actual geometry.
     * Set to false if you want to manually control the shape's size.
     * Default is true.
     */
    public var autoComputeSize(default, set):Bool = true;
    inline function set_autoComputeSize(autoComputeSize:Bool):Bool {
        if (this.autoComputeSize == autoComputeSize) return autoComputeSize;
        this.autoComputeSize = autoComputeSize;
        if (autoComputeSize)
            computeSize();
        return autoComputeSize;
    }

    override function get_width():Float {
        if (autoComputeSize && contentDirty) {
            computeContent();
        }
        return super.get_width();
    }

    override function get_height():Float {
        if (autoComputeSize && contentDirty) {
            computeContent();
        }
        return super.get_height();
    }

    /**
     * Recomputes the shape's triangulation from its points.
     * Called automatically when points change or contentDirty is true.
     *
     * This method:
     * 1. Triangulates the shape points into triangles
     * 2. Updates the mesh indices
     * 3. Optionally recomputes size from points
     *
     * Override to implement custom triangulation strategies.
     */
    override function computeContent() {

        if (vertices != null && vertices.length >= 6) {

            if (indices == null)
                indices = [];

            Triangulate.triangulate(vertices, indices);
        }

        if (autoComputeSize)
            computeSize();

        contentDirty = false;

    }

#if plugin_nape

    /**
     * Initialize Nape physics body for this shape.
     * Creates a physics body that matches the visual shape for accurate collisions.
     *
     * If no collision shape is provided, automatically creates a polygon
     * matching the shape's points.
     *
     * @param type Physics body type (STATIC for walls, DYNAMIC for moving objects, KINEMATIC for controlled movement)
     * @param space Nape physics space (uses default if not provided)
     * @param shape Custom collision shape (auto-generated from points if null)
     * @param shapes Array of collision shapes for complex bodies
     * @param material Physics material defining friction, elasticity, etc.
     * @return VisualNapePhysics component for further configuration
     */
    override function initNapePhysics(
        type:ceramic.NapePhysicsBodyType,
        ?space:nape.space.Space,
        ?shape:nape.shape.Shape,
        ?shapes:Array<nape.shape.Shape>,
        ?material:nape.phys.Material
    ):VisualNapePhysics {

        if (nape != null) {
            nape.destroy();
            nape = null;
        }

        if (contentDirty) {
            computeContent();
        }

        if (shape == null && (shapes == null || shapes.length == 0)) {
            var shapePoints = new Vec2List();
            var len = points.length;
            var i = 0;
            var w2 = width * 0.5;
            var h2 = height * 0.5;
            while (i < len - 1) {
                var iB = i + 1;
                shapePoints.push(Vec2.weak(
                    points.unsafeGet(i) - w2,
                    points.unsafeGet(iB) - h2
                ));
                i += 2;
            }
            shape = new Polygon(shapePoints);
        }

        return super.initNapePhysics(type, space, shape, shapes, material);

    }

#end

}

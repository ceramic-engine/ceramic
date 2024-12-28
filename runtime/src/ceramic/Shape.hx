package ceramic;

#if plugin_nape
import nape.geom.Vec2;
import nape.geom.Vec2List;
import nape.shape.Polygon;
#end

using ceramic.Extensions;

/**
 * Draw shapes by triangulating vertices automatically, with optional holes in it.
 */
class Shape extends Mesh {

    /**
     * A flat array of vertex coordinates to describe the shape.
     * `points = ...` is identical to `vertices = ... ; contentDirty = true ;`
     * Note: when editing array content without reassigning it,
     * `contentDirty` must be set to `true` to let the shape being updated accordingly.
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
     * If set to `true`, width and heigh will be computed from shape points.
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
     * Init nape physics body bound to this visual.
     * @param type Physics body type (`STATIC`, `KINEMATIC` or `DYNAMIC`)
     * @param space (optional) Related nape spaces. Will use default space if not provided.
     * @param shape (optional) Shape used for this body. Default is a polygon matching shape points.
     * @param shapes (optional) Array of shapes used for this body.
     * @param material (optional) A custom material to use with this body.
     * @return A `VisualNapePhysics` instance
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

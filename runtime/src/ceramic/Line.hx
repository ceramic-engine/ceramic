package ceramic;

import polyline.Stroke;

using ceramic.Extensions;

/**
 * Display lines composed of multiple segments, curves...
 */
@editable({
    implicitSize: true,
    highlight: {
        points: 'points',
        minPoints: 2,
        maxPoints: 999999999
    },
    disable: ['texture', 'vertices', 'indices', 'uvs']
})
class Line extends Mesh {

    static var _stroke:Stroke = new Stroke();

    /**
     * Line points.
     * Note: when editing array content without reassigning it,
     * `contentDirty` must be set to `true` to let the line being updated accordingly.
     */
    public var points(default, set):Array<Float> = null;
    inline function set_points(points:Array<Float>):Array<Float> {
        this.points = points;
        contentDirty = true;
        return points;
    }

    /**
     * The limit before miters turn into bevels. Default 10
     */
    public var miterLimit(default, set):Float = 10;
    inline function set_miterLimit(miterLimit:Float):Float {
        if (this.miterLimit == miterLimit) return miterLimit;
        this.miterLimit = miterLimit;
        contentDirty = true;
        return miterLimit;
    }

    /**
     * The line thickness
     */
    public var thickness(default, set):Float = 1;
    inline function set_thickness(thickness:Float):Float {
        if (this.thickness == thickness) return thickness;
        this.thickness = thickness;
        contentDirty = true;
        return thickness;
    }

    /**
     * The join type, can be `MITER` or `BEVEL`. Default `BEVEL`
     */
    public var join(default, set):LineJoin = BEVEL;
    inline function set_join(join:LineJoin):LineJoin {
        if (this.join == join) return join;
        this.join = join;
        contentDirty = true;
        return join;
    }

    /**
     * The cap type. Can be `BUTT` or `SQUARE`. Default `BUTT`
     */
    public var cap(default, set):LineCap = BUTT;
    inline function set_cap(cap:LineCap):LineCap {
        if (this.cap == cap) return cap;
        this.cap = cap;
        contentDirty = true;
        return cap;
    }

    /**
     * If `loop` is `true`, will try to join the first and last
     * points together if they are identical. Default `false`
     */
    public var loop(default, set):Bool = false;
    inline function set_loop(loop:Bool):Bool {
        if (this.loop == loop) return loop;
        this.loop = loop;
        contentDirty = true;
        return loop;
    }

    /**
     * If set to `true`, width and heigh will be computed from line points.
     */
    public var autoComputeSize(default, set):Bool = true;
    inline function set_autoComputeSize(autoComputeSize:Bool):Bool {
        if (this.autoComputeSize == autoComputeSize) return autoComputeSize;
        this.autoComputeSize = autoComputeSize;
        if (autoComputeSize)
            computeSize();
        return autoComputeSize;
    }

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

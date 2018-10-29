package ceramic;

using ceramic.Extensions;

/** A rectangle visual that display a border */
class Border extends Mesh {

    @:noCompletion public var autoComputeVertices(default,set):Bool = true;
    inline function set_autoComputeVertices(autoComputeVertices:Bool):Bool {
        if (this.autoComputeVertices == autoComputeVertices) return autoComputeVertices;
        this.autoComputeVertices = autoComputeVertices;
        if (autoComputeVertices) {
            computeVertices();
        }
        return autoComputeVertices;
    }

    override function set_width(width:Float):Float {
        super.set_width(width);
        if (autoComputeVertices) computeVertices();
        return width;
    }

    override function set_height(height:Float):Float {
        super.set_height(height);
        if (autoComputeVertices) computeVertices();
        return height;
    }

    public var borderPosition(default,set):BorderPosition = MIDDLE;
    inline function set_borderPosition(borderPosition:BorderPosition):BorderPosition {
        if (this.borderPosition == borderPosition) return borderPosition;
        this.borderPosition = borderPosition;
        if (autoComputeVertices) computeVertices();
        return borderPosition;
    }

    public var borderSize(default,set):Float = 1;
    inline function set_borderSize(borderSize:Float):Float {
        if (this.borderSize == borderSize) return borderSize;
        this.borderSize = borderSize;
        if (autoComputeVertices) computeVertices();
        return borderSize;
    }

    public function new() {

        super();

        vertices = [
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0
        ];

        indices = [
            // Top border
            0, 1, 5,
            0, 5, 2,
            // Right border
            4, 5, 9,
            4, 9, 8,
            // Bottom border
            6, 9, 11,
            6, 11, 10,
            // Left border
            2, 3, 7,
            2, 7, 6
        ];

        computeVertices();

    } //new

    function computeVertices() {

        var outer = 0.5;
        var inner = 0.5;

        if (borderPosition == OUTSIDE) {
            outer = 1.0;
            inner = 0.0;
        }
        else if (borderPosition == INSIDE) {
            outer = 0.0;
            inner = 1.0;
        }

        outer *= borderSize;
        inner *= borderSize;

        var w = width;
        var h = height;
        var tmp:Float;

        // 0
        vertices.unsafeSet(0, -outer);
        vertices.unsafeSet(1, -outer);
        // 1
        tmp = w + outer;
        vertices.unsafeSet(2, tmp);
        vertices.unsafeSet(3, -outer);
        // 2
        vertices.unsafeSet(4, -outer);
        vertices.unsafeSet(5, inner);
        // 3
        vertices.unsafeSet(6, inner);
        vertices.unsafeSet(7, inner);
        // 4
        tmp = w - inner;
        vertices.unsafeSet(8, tmp);
        vertices.unsafeSet(9, inner);
        // 5
        tmp = w + outer;
        vertices.unsafeSet(10, tmp);
        vertices.unsafeSet(11, inner);

        // 6
        vertices.unsafeSet(12, -outer);
        tmp = h - inner;
        vertices.unsafeSet(13, tmp);
        // 7
        vertices.unsafeSet(14, inner);
        tmp = h - inner;
        vertices.unsafeSet(15, tmp);
        // 8
        tmp = w - inner;
        vertices.unsafeSet(16, tmp);
        tmp = h - inner;
        vertices.unsafeSet(17, tmp);
        // 9
        tmp = w + outer;
        vertices.unsafeSet(18, tmp);
        tmp = h - inner;
        vertices.unsafeSet(19, tmp);
        // 10
        vertices.unsafeSet(20, -outer);
        tmp = h + outer;
        vertices.unsafeSet(21, tmp);
        // 11
        tmp = w + outer;
        vertices.unsafeSet(22, tmp);
        tmp = h + outer;
        vertices.unsafeSet(23, tmp);

    } //computeVertices

} //Mesh

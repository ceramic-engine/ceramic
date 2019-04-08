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

    @:noCompletion public var autoComputeColors(default,set):Bool = true;
    inline function set_autoComputeColors(autoComputeColors:Bool):Bool {
        if (this.autoComputeColors == autoComputeColors) return autoComputeColors;
        this.autoComputeColors = autoComputeColors;
        if (autoComputeColors) {
            computeColors();
        }
        return autoComputeColors;
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

    public var borderTopSize(default,set):Float = -1;
    inline function set_borderTopSize(borderTopSize:Float):Float {
        if (this.borderTopSize == borderTopSize) return borderTopSize;
        this.borderTopSize = borderTopSize;
        if (autoComputeVertices) computeVertices();
        return borderTopSize;
    }

    public var borderBottomSize(default,set):Float = -1;
    inline function set_borderBottomSize(borderBottomSize:Float):Float {
        if (this.borderBottomSize == borderBottomSize) return borderBottomSize;
        this.borderBottomSize = borderBottomSize;
        if (autoComputeVertices) computeVertices();
        return borderBottomSize;
    }

    public var borderLeftSize(default,set):Float = -1;
    inline function set_borderLeftSize(borderLeftSize:Float):Float {
        if (this.borderLeftSize == borderLeftSize) return borderLeftSize;
        this.borderLeftSize = borderLeftSize;
        if (autoComputeVertices) computeVertices();
        return borderLeftSize;
    }

    public var borderRightSize(default,set):Float = -1;
    inline function set_borderRightSize(borderRightSize:Float):Float {
        if (this.borderRightSize == borderRightSize) return borderRightSize;
        this.borderRightSize = borderRightSize;
        if (autoComputeVertices) computeVertices();
        return borderRightSize;
    }

    public var borderColor(default,set):Color = Color.GRAY;
    inline function set_borderColor(borderColor:Color):Color {
        if (this.borderColor == borderColor) return borderColor;
        this.borderColor = borderColor;
        if (autoComputeColors) computeColors();
        return borderColor;
    }

    public var borderTopColor(default,set):Color = Color.NONE;
    inline function set_borderTopColor(borderTopColor:Color):Color {
        if (this.borderTopColor == borderTopColor) return borderTopColor;
        this.borderTopColor = borderTopColor;
        if (autoComputeColors) computeColors();
        return borderTopColor;
    }

    public var borderBottomColor(default,set):Color = Color.NONE;
    inline function set_borderBottomColor(borderBottomColor:Color):Color {
        if (this.borderBottomColor == borderBottomColor) return borderBottomColor;
        this.borderBottomColor = borderBottomColor;
        if (autoComputeColors) computeColors();
        return borderBottomColor;
    }

    public var borderLeftColor(default,set):Color = Color.NONE;
    inline function set_borderLeftColor(borderLeftColor:Color):Color {
        if (this.borderLeftColor == borderLeftColor) return borderLeftColor;
        this.borderLeftColor = borderLeftColor;
        if (autoComputeColors) computeColors();
        return borderLeftColor;
    }

    public var borderRightColor(default,set):Color = Color.NONE;
    inline function set_borderRightColor(borderRightColor:Color):Color {
        if (this.borderRightColor == borderRightColor) return borderRightColor;
        this.borderRightColor = borderRightColor;
        if (autoComputeColors) computeColors();
        return borderRightColor;
    }

    public function new() {

        super();

        colorMapping = MeshColorMapping.INDICES;

        vertices = [
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
            0, 1, 2,
            2, 1, 3,
            // Right border
            3, 1, 5,
            5, 1, 7,
            // Bottom border
            4, 5, 6,
            6, 5, 7,
            // Left border
            0, 2, 6,
            6, 2, 4
        ];

        colors = [
            // Top border
            0, 0, 0,
            0, 0, 0,
            // Right border
            0, 0, 0,
            0, 0, 0,
            // Bottom border
            0, 0, 0,
            0, 0, 0,
            // Left border
            0, 0, 0,
            0, 0, 0
        ];

        computeVertices();

    } //new

    function computeColors() {

        var topColor = new AlphaColor(borderTopColor != Color.NONE ? borderTopColor : borderColor);
        var bottomColor = new AlphaColor(borderBottomColor != Color.NONE ? borderBottomColor : borderColor);
        var leftColor = new AlphaColor(borderLeftColor != Color.NONE ? borderLeftColor : borderColor);
        var rightColor = new AlphaColor(borderRightColor != Color.NONE ? borderRightColor : borderColor);

        colors.unsafeSet(0, topColor);
        colors.unsafeSet(1, topColor);
        colors.unsafeSet(2, topColor);
        colors.unsafeSet(3, topColor);
        colors.unsafeSet(4, topColor);
        colors.unsafeSet(5, topColor);

        colors.unsafeSet(6, rightColor);
        colors.unsafeSet(7, rightColor);
        colors.unsafeSet(8, rightColor);
        colors.unsafeSet(9, rightColor);
        colors.unsafeSet(10, rightColor);
        colors.unsafeSet(11, rightColor);

        colors.unsafeSet(12, bottomColor);
        colors.unsafeSet(13, bottomColor);
        colors.unsafeSet(14, bottomColor);
        colors.unsafeSet(15, bottomColor);
        colors.unsafeSet(16, bottomColor);
        colors.unsafeSet(17, bottomColor);

        colors.unsafeSet(18, leftColor);
        colors.unsafeSet(19, leftColor);
        colors.unsafeSet(20, leftColor);
        colors.unsafeSet(21, leftColor);
        colors.unsafeSet(22, leftColor);
        colors.unsafeSet(23, leftColor);

    } //computeColors

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
        vertices.unsafeSet(4, inner);
        vertices.unsafeSet(5, inner);
        // 3
        tmp = w - inner;
        vertices.unsafeSet(6, tmp);
        vertices.unsafeSet(7, inner);

        // 4
        vertices.unsafeSet(8, inner);
        tmp = h - inner;
        vertices.unsafeSet(9, tmp);
        // 5
        tmp = w - inner;
        vertices.unsafeSet(10, tmp);
        tmp = h - inner;
        vertices.unsafeSet(11, tmp);
        // 6
        vertices.unsafeSet(12, -outer);
        tmp = h + outer;
        vertices.unsafeSet(13, tmp);
        // 7
        tmp = w + outer;
        vertices.unsafeSet(14, tmp);
        tmp = h + outer;
        vertices.unsafeSet(15, tmp);

    } //computeVertices

} //Mesh

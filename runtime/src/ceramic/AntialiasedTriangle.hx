package ceramic;

using ceramic.Extensions;

/**
 * A variant of `Triangle` using a bit more vertices to simulate antialiasing (without multisampling)
 */
class AntialiasedTriangle extends Mesh {

/// Overrides

    override function set_width(width:Float):Float {
        super.set_width(width);

        updateVertices();
        return width;

    }

    override function set_height(height:Float):Float {
        super.set_height(height);

        updateVertices();
        return height;

    }

    public var antialiasing(default, set):Float = 1;
    function set_antialiasing(antialiasing:Float):Float {
        if (this.antialiasing != antialiasing) {
            this.antialiasing = antialiasing;
            updateVertices();
        }
        return antialiasing;
    }

    override function set_color(color:Color):Color {
        if (colors == null) colors = [0, 0, 0, 0, 0, 0];
        colors.unsafeSet(0, new AlphaColor(color, 255));
        colors.unsafeSet(1, new AlphaColor(color, 255));
        colors.unsafeSet(2, new AlphaColor(color, 255));
        colors.unsafeSet(3, new AlphaColor(color, 0));
        colors.unsafeSet(4, new AlphaColor(color, 0));
        colors.unsafeSet(5, new AlphaColor(color, 0));
        return color;
    }

/// Lifecycle

    public function new() {

        super();

        vertices = [
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0
        ];
        indices = [
            0, 1, 2,
            0, 1, 4,
            0, 3, 4,
            1, 2, 4,
            2, 4, 5,
            0, 2, 3,
            2, 3, 5
        ];
        colorMapping = VERTICES;
        color = Color.WHITE;

    }

    inline function updateVertices() {

        vertices.unsafeSet(0, 0.0);
        vertices.unsafeSet(1, height);

        vertices.unsafeSet(2, width * 0.5);
        vertices.unsafeSet(3, 0.0);

        vertices.unsafeSet(4, width);
        vertices.unsafeSet(5, height);

        vertices.unsafeSet(6, -antialiasing);
        vertices.unsafeSet(7, height + antialiasing);

        vertices.unsafeSet(8, width * 0.5);
        vertices.unsafeSet(9, -antialiasing);

        vertices.unsafeSet(10, width + antialiasing);
        vertices.unsafeSet(11, height + antialiasing);

    }

}

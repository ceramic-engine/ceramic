package ceramic;

using ceramic.Extensions;

/**
 * A simple colored triangle, to fulfill all your triangle-shaped needs.
 * The triangle is facing top and fits exactly in `width` and `height`
 */
class Triangle extends Mesh {

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

/// Lifecycle

    public function new() {

        super();

        vertices = [
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0
        ];
        indices = [0, 1, 2];
        color = Color.WHITE;

    }

    inline function updateVertices() {

        vertices.unsafeSet(0, 0.0);
        vertices.unsafeSet(1, height);

        vertices.unsafeSet(2, width * 0.5);
        vertices.unsafeSet(3, 0.0);

        vertices.unsafeSet(4, width);
        vertices.unsafeSet(5, height);

    }

}

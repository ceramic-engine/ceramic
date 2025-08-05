package ceramic;

using ceramic.Extensions;

/**
 * A specialized triangle shape that simulates antialiasing using additional vertices.
 * 
 * This class creates a smooth-edged triangle without requiring multisampling or hardware antialiasing.
 * It achieves this by adding extra vertices around the edges with alpha transparency,
 * creating a gradient effect that simulates antialiased edges.
 * 
 * The triangle uses 6 vertices instead of the typical 3:
 * - 3 inner vertices forming the main triangle (fully opaque)
 * - 3 outer vertices extending beyond the triangle bounds (fully transparent)
 * 
 * ```haxe
 * var triangle = new AntialiasedTriangle();
 * triangle.size(200, 150);
 * triangle.color = Color.RED;
 * triangle.antialiasing = 2; // 2-pixel antialiasing border
 * triangle.pos(100, 100);
 * ```
 * 
 * @see Triangle For a simpler triangle without antialiasing
 * @see Mesh The base class for custom geometry
 */
class AntialiasedTriangle extends Mesh {

/// Overrides

    /**
     * Sets the width of the triangle.
     * Automatically updates the vertex positions to match the new width.
     * 
     * @param width The new width in pixels
     * @return The new width value
     */
    override function set_width(width:Float):Float {
        super.set_width(width);

        updateVertices();
        return width;

    }

    /**
     * Sets the height of the triangle.
     * Automatically updates the vertex positions to match the new height.
     * 
     * @param height The new height in pixels
     * @return The new height value
     */
    override function set_height(height:Float):Float {
        super.set_height(height);

        updateVertices();
        return height;

    }

    /**
     * The width of the antialiasing border in pixels.
     * Higher values create a smoother but wider gradient edge.
     * Default value is 1 pixel.
     * 
     * Common values:
     * - 0.5: Very subtle antialiasing
     * - 1.0: Standard antialiasing (default)
     * - 2.0: Strong antialiasing for larger triangles
     */
    public var antialiasing(default, set):Float = 1;
    function set_antialiasing(antialiasing:Float):Float {
        if (this.antialiasing != antialiasing) {
            this.antialiasing = antialiasing;
            updateVertices();
        }
        return antialiasing;
    }

    /**
     * Sets the color of the triangle.
     * The inner vertices get full opacity while outer vertices get zero opacity,
     * creating the antialiasing gradient effect.
     * 
     * @param color The color to apply to the triangle
     * @return The new color value
     */
    override function set_color(color:Color):Color {
        if (colors == null) colors = [0, 0, 0, 0, 0, 0];
        else if (colors.length != 6) colors.setArrayLength(6);
        colors.unsafeSet(0, new AlphaColor(color, 255));
        colors.unsafeSet(1, new AlphaColor(color, 255));
        colors.unsafeSet(2, new AlphaColor(color, 255));
        colors.unsafeSet(3, new AlphaColor(color, 0));
        colors.unsafeSet(4, new AlphaColor(color, 0));
        colors.unsafeSet(5, new AlphaColor(color, 0));
        return color;
    }

/// Lifecycle

    /**
     * Creates a new antialiased triangle.
     * Initializes the mesh with 6 vertices and the appropriate indices
     * for rendering the antialiased edges.
     */
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

    /**
     * Updates the vertex positions based on current width, height, and antialiasing values.
     * 
     * The vertex layout is:
     * - Vertices 0,1,2: Inner triangle vertices (opaque)
     * - Vertices 3,4,5: Outer vertices for antialiasing (transparent)
     * 
     * The outer vertices are positioned beyond the triangle bounds by the antialiasing amount.
     */
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

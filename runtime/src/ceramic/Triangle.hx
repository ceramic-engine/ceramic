package ceramic;

using ceramic.Extensions;

/**
 * A simple colored triangle shape that fits within the specified dimensions.
 *
 * Triangle extends Mesh to provide an easy way to create triangular graphics.
 * The triangle points upward and automatically adjusts its vertices when
 * width or height changes.
 *
 * Vertex layout:
 * - Bottom-left corner at (0, height)
 * - Top center at (width/2, 0)
 * - Bottom-right corner at (width, height)
 *
 * Common uses:
 * - UI arrows and indicators
 * - Play buttons
 * - Direction indicators
 * - Simple decorative elements
 * - Tooltips and speech bubble tails
 *
 * ```haxe
 * // Create a simple triangle
 * var triangle = new Triangle();
 * triangle.size(50, 40);
 * triangle.color = Color.RED;
 *
 * // Create a play button icon
 * var playButton = new Triangle();
 * playButton.size(30, 30);
 * playButton.rotation = 90; // Point right
 * playButton.color = Color.WHITE;
 *
 * // Animated direction indicator
 * var arrow = new Triangle();
 * arrow.size(20, 30);
 * arrow.anchor(0.5, 0.5);
 * arrow.color = Color.YELLOW;
 * app.onUpdate(this, delta -> {
 *     arrow.y = arrow.y + Math.sin(Timer.now * 2) * 2;
 * });
 * ```
 *
 * @see Mesh
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

    /**
     * Creates a new triangle.
     *
     * The triangle is initialized with white color and
     * vertices that will be positioned based on width/height.
     */
    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        vertices = [
            0.0, 0.0,
            0.0, 0.0,
            0.0, 0.0
        ];
        indices = [0, 1, 2];
        color = Color.WHITE;

    }

    /**
     * Updates vertex positions based on current width and height.
     *
     * Positions the three vertices to form an upward-pointing
     * triangle that fits exactly within the bounds.
     */
    inline function updateVertices() {

        vertices.unsafeSet(0, 0.0);
        vertices.unsafeSet(1, height);

        vertices.unsafeSet(2, width * 0.5);
        vertices.unsafeSet(3, 0.0);

        vertices.unsafeSet(4, width);
        vertices.unsafeSet(5, height);

    }

}

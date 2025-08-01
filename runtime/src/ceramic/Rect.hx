package ceramic;

/**
 * Represents a rectangular area defined by position and dimensions.
 * 
 * Rect is a simple data structure for storing rectangular bounds,
 * commonly used for collision detection, viewport definitions, texture
 * regions, and UI layout calculations. The rectangle is defined by its
 * top-left corner (x, y) and its dimensions (width, height).
 * 
 * The @:structInit metadata allows convenient struct-style initialization:
 * ```haxe
 * // Different ways to create rectangles
 * var rect1 = new Rect(10, 20, 100, 50);
 * var rect2:Rect = {x: 10, y: 20, width: 100, height: 50};
 * var rect3 = new Rect(); // Defaults to (0, 0, 0, 0)
 * 
 * // Common usage patterns
 * var bounds = new Rect(visual.x, visual.y, visual.width, visual.height);
 * var viewport:Rect = {x: 0, y: 0, width: screen.width, height: screen.height};
 * 
 * // Accessing properties
 * var right = rect.x + rect.width;
 * var bottom = rect.y + rect.height;
 * var area = rect.width * rect.height;
 * ```
 * 
 * Note: This class does not include utility methods for intersection,
 * containment, or other geometric operations. Use GeometryUtils for
 * such calculations.
 * 
 * @see ceramic.GeometryUtils For rectangle intersection and containment tests
 * @see ceramic.Visual For visual bounds
 * @see ceramic.Screen For screen viewport
 */
@:structInit
class Rect {

    /**
     * The X coordinate of the rectangle's top-left corner.
     * In screen coordinates, this represents the horizontal position.
     */
    public var x:Float;

    /**
     * The Y coordinate of the rectangle's top-left corner.
     * In screen coordinates, this represents the vertical position.
     */
    public var y:Float;

    /**
     * The width of the rectangle.
     * Should typically be positive for a valid rectangle.
     */
    public var width:Float;

    /**
     * The height of the rectangle.
     * Should typically be positive for a valid rectangle.
     */
    public var height:Float;

    /**
     * Returns a string representation of this rectangle.
     * Format: "Rect(x, y, width, height)" with the actual numeric values.
     * 
     * @return String representation of the rectangle
     */
    function toString():String {

        return 'Rect($x, $y, $width, $height)';

    }

    /**
     * Creates a new Rect instance with the specified position and dimensions.
     * 
     * @param x The X coordinate of the top-left corner (default: 0)
     * @param y The Y coordinate of the top-left corner (default: 0)
     * @param width The width of the rectangle (default: 0)
     * @param height The height of the rectangle (default: 0)
     */
    public function new(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0) {

        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;

    }

}

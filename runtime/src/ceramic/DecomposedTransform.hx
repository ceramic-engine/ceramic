package ceramic;

/**
 * Decomposed transform holds rotation, translation, scale, skew and pivot informations.
 * Provided by Transform.decompose() method.
 * Angles are in radians.
 * 
 * This class represents a 2D transformation broken down into its individual
 * components, making it easier to understand and manipulate complex transformations.
 * It's particularly useful for animation, debugging, and converting between
 * different transformation representations.
 * 
 * ## Components
 * 
 * - **Translation**: x, y position
 * - **Rotation**: Angle in radians
 * - **Scale**: Horizontal and vertical scaling factors
 * - **Skew**: Horizontal and vertical shearing
 * - **Pivot**: Center point for transformations
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Decompose a transform matrix
 * var transform = new Transform();
 * transform.translate(100, 50);
 * transform.rotate(Math.PI / 4);
 * transform.scale(2, 1.5);
 * 
 * var decomposed = new DecomposedTransform();
 * transform.decompose(decomposed);
 * 
 * trace('Position: ${decomposed.x}, ${decomposed.y}');
 * trace('Rotation: ${decomposed.rotation} radians');
 * trace('Scale: ${decomposed.scaleX}, ${decomposed.scaleY}');
 * ```
 * 
 * @see ceramic.Transform For matrix operations and decomposition
 * @see ceramic.Visual For applying transforms to visuals
 */
class DecomposedTransform {

    /**
     * Creates a new decomposed transform with default values.
     * All values are initialized to identity transform.
     */
    inline public function new() {}

    /**
     * X coordinate of the pivot point.
     * The pivot is the center point around which rotation and scaling occur.
     * Default: 0
     */
    public var pivotX:Float = 0;

    /**
     * Y coordinate of the pivot point.
     * The pivot is the center point around which rotation and scaling occur.
     * Default: 0
     */
    public var pivotY:Float = 0;

    /**
     * X position (horizontal translation).
     * This is the final position after all transformations are applied.
     * Default: 0
     */
    public var x:Float = 0;

    /**
     * Y position (vertical translation).
     * This is the final position after all transformations are applied.
     * Default: 0
     */
    public var y:Float = 0;

    /**
     * Rotation angle in radians.
     * Positive values rotate clockwise.
     * Default: 0
     * 
     * @example
     * ```haxe
     * decomposed.rotation = Math.PI / 2; // 90 degrees
     * decomposed.rotation = Math.PI;     // 180 degrees
     * ```
     */
    public var rotation:Float = 0;

    /**
     * Horizontal scaling factor.
     * Values > 1 stretch horizontally, < 1 compress.
     * Negative values flip horizontally.
     * Default: 1
     */
    public var scaleX:Float = 1;

    /**
     * Vertical scaling factor.
     * Values > 1 stretch vertically, < 1 compress.
     * Negative values flip vertically.
     * Default: 1
     */
    public var scaleY:Float = 1;

    /**
     * Horizontal skew angle in radians.
     * Shears the shape horizontally.
     * Default: 0
     */
    public var skewX:Float = 0;

    /**
     * Vertical skew angle in radians.
     * Shears the shape vertically.
     * Default: 0
     */
    public var skewY:Float = 0;

    /**
     * Returns a string representation of the decomposed transform.
     * Useful for debugging and logging transformation values.
     * 
     * @return String in format: "(pos=x,y pivot=px,py rotation=r scale=sx,sy skew=skx,sky)"
     */
    function toString():String {
        return '(pos=$x,$y pivot=$pivotX,$pivotY rotation=$rotation scale=${(scaleX == scaleY ? '' + scaleX : scaleX + ',' + scaleY)} skew=$skewX,$skewY)';
    }

}

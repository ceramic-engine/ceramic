package ceramic;

/**
 * A mutable 3D point class with automatic object pooling for memory efficiency.
 * 
 * Point represents a position in 3D space with x, y, and z coordinates.
 * For 2D operations, simply ignore the z component (defaults to 0).
 * The class includes built-in object pooling to reduce garbage collection
 * pressure in performance-critical applications.
 * 
 * Usage patterns:
 * ```haxe
 * // Create a new point (allocated from pool if available)
 * var point = Point.get(100, 200);        // 2D point at (100, 200, 0)
 * var point3d = Point.get(10, 20, 30);    // 3D point at (10, 20, 30)
 * 
 * // Use the point
 * visual.x = point.x;
 * visual.y = point.y;
 * 
 * // Return to pool when done
 * point.recycle();
 * 
 * // Direct construction (bypasses pool)
 * var permanent = new Point(50, 75);
 * 
 * // Struct initialization syntax
 * var p:Point = {x: 100, y: 200, z: 0};
 * ```
 * 
 * Important: Always call `recycle()` on pooled points when done to return
 * them to the pool. Points created with `new` should not be recycled.
 * 
 * @see ceramic.ReadOnlyPoint For immutable point access
 * @see ceramic.Transform For transformation matrices
 * @see ceramic.GeometryUtils For point-based calculations
 */
@:structInit
class Point {

    /**
     * The X coordinate of the point.
     * In screen coordinates, this typically represents the horizontal position.
     */
    public var x:Float = 0;

    /**
     * The Y coordinate of the point.
     * In screen coordinates, this typically represents the vertical position.
     */
    public var y:Float = 0;

    /**
     * The Z coordinate of the point.
     * Used for 3D positioning or depth sorting. Defaults to 0 for 2D usage.
     */
    public var z:Float = 0;

    /**
     * Returns a string representation of this point.
     * Format: "Point(x, y, z)" where x, y, z are the coordinate values.
     * 
     * @return String representation of the point
     */
    function toString():String {

        return 'Point($x, $y, $z)';

    }

    /**
     * Creates a new Point instance with the specified coordinates.
     * 
     * Note: For memory efficiency, consider using `Point.get()` instead,
     * which uses object pooling.
     * 
     * @param x The X coordinate (default: 0)
     * @param y The Y coordinate (default: 0) 
     * @param z The Z coordinate (default: 0)
     */
    public function new(x:Float = 0, y:Float = 0, z:Float = 0) {

        this.x = x;
        this.y = y;
        this.z = z;

    }

    /**
     * Returns this point to the object pool for reuse.
     * 
     * After calling recycle(), this point should not be used anymore.
     * The coordinates are reset to (0, 0, 0) before returning to the pool.
     * 
     * Important: Only call this on points obtained via `Point.get()`.
     * Do not recycle points created with `new Point()`.
     * 
     * Example:
     * ```haxe
     * var temp = Point.get(100, 200);
     * // Use the point...
     * temp.recycle(); // Return to pool
     * // Don't use temp after this!
     * ```
     */
    public function recycle():Void {

        this.x = 0;
        this.y = 0;
        this.z = 0;
        pool.recycle(this);

    }

    /**
     * Gets a Point instance from the object pool or creates a new one.
     * 
     * This method should be preferred over `new Point()` for temporary points
     * as it reuses objects from a pool, reducing garbage collection pressure.
     * Remember to call `recycle()` on the returned point when done.
     * 
     * Example:
     * ```haxe
     * var cursor = Point.get(mouse.x, mouse.y);
     * processPosition(cursor);
     * cursor.recycle();
     * ```
     * 
     * @param x The X coordinate (default: 0)
     * @param y The Y coordinate (default: 0)
     * @param z The Z coordinate (default: 0)
     * @return A Point instance with the specified coordinates
     */
    public inline static function get(x:Float = 0, y:Float = 0, z:Float = 0):Point {

        var point = pool.get();

        if (point == null) {
            point = new Point(x, y, z);
        }
        else {
            point.x = x;
            point.y = y;
            point.z = z;
        }

        return point;

    }

    /**
     * Internal object pool for efficient Point allocation.
     * Managed automatically by get() and recycle() methods.
     */
    static var pool = new Pool<Point>();

}

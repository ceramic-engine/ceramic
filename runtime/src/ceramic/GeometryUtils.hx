package ceramic;

/**
 * A collection of static utility functions for 2D geometric calculations.
 * 
 * GeometryUtils provides essential geometric operations commonly needed in 2D games
 * and applications, including point-in-shape tests, distance calculations, angle
 * computations, and polygon analysis.
 * 
 * All methods are static and optimized for performance, making them suitable for
 * real-time applications like collision detection, input handling, and visual effects.
 * 
 * Common use cases:
 * - Hit testing: Determine if a mouse/touch point is inside a shape
 * - Collision detection: Check if circles or other shapes intersect
 * - Movement: Calculate distances and angles for object positioning
 * - Rendering: Determine winding order for proper triangle rendering
 * 
 * Example usage:
 * ```haxe
 * // Check if mouse is inside a triangle
 * if (GeometryUtils.pointInTriangle(mouseX, mouseY, v1.x, v1.y, v2.x, v2.y, v3.x, v3.y)) {
 *     trace("Mouse is inside triangle!");
 * }
 * 
 * // Calculate distance between two points
 * var dist = GeometryUtils.distance(player.x, player.y, enemy.x, enemy.y);
 * if (dist < 50) {
 *     trace("Enemy is nearby!");
 * }
 * 
 * // Get angle between player and target
 * var angle = GeometryUtils.angleTo(player.x, player.y, target.x, target.y);
 * player.rotation = angle;
 * ```
 * 
 * @see ceramic.Visual For shape rendering
 * @see ceramic.Transform For coordinate transformations
 * @see ceramic.Triangulate For polygon triangulation
 */
class GeometryUtils {

    /**
     * Tests whether a point lies inside a triangle using the sign method.
     * 
     * This method uses the sign of the cross product to determine if a point is on the
     * same side of all three edges of the triangle. It handles edge cases where the
     * point lies exactly on an edge.
     * 
     * @param x The x-coordinate of the point to test
     * @param y The y-coordinate of the point to test
     * @param ax The x-coordinate of the first triangle vertex
     * @param ay The y-coordinate of the first triangle vertex
     * @param bx The x-coordinate of the second triangle vertex
     * @param by The y-coordinate of the second triangle vertex
     * @param cx The x-coordinate of the third triangle vertex
     * @param cy The y-coordinate of the third triangle vertex
     * @return `true` if the point is inside or on the edge of the triangle, `false` otherwise
     */
    public static function pointInTriangle(x:Float, y:Float, ax:Float, ay:Float, bx:Float, by:Float, cx:Float, cy:Float):Bool {

        inline function sign(x:Float, y:Float, ax:Float, ay:Float, bx:Float, by:Float):Float {
            return (x - bx) * (ay - by) - (ax - bx) * (y - by);
        }

        var d1:Float = sign(x, y, ax, ay, bx, by);
        var d2:Float = sign(x, y, bx, by, cx, cy);
        var d3:Float = sign(x, y, cx, cy, ax, ay);

        var hasNeg:Bool = (d1 < 0) || (d2 < 0) || (d3 < 0);
        var hasPos:Bool = (d1 > 0) || (d2 > 0) || (d3 > 0);

        return !(hasNeg && hasPos);

    }

    /**
     * Tests whether a point lies inside an axis-aligned rectangle.
     * 
     * The rectangle is defined by its top-left corner position and dimensions.
     * Points exactly on the left or top edges are considered inside, while points
     * on the right or bottom edges are considered outside.
     * 
     * @param x The x-coordinate of the point to test
     * @param y The y-coordinate of the point to test
     * @param rectX The x-coordinate of the rectangle's top-left corner
     * @param rectY The y-coordinate of the rectangle's top-left corner
     * @param rectWidth The width of the rectangle
     * @param rectHeight The height of the rectangle
     * @return `true` if the point is inside the rectangle, `false` otherwise
     */
    public static function pointInRectangle(x:Float, y:Float, rectX:Float, rectY:Float, rectWidth:Float, rectHeight:Float):Bool {

        if (x < rectX)
            return false;
        if (y < rectY)
            return false;
        if (x >= rectX + rectWidth)
            return false;
        if (y >= rectY + rectHeight)
            return false;

        return true;

    }

    /**
     * Tests whether a point lies inside or on a circle.
     * 
     * Uses the squared distance formula to avoid the expensive square root operation,
     * making this method very efficient for collision detection.
     * 
     * @param x The x-coordinate of the point to test
     * @param y The y-coordinate of the point to test
     * @param cx The x-coordinate of the circle's center
     * @param cy The y-coordinate of the circle's center
     * @param radius The radius of the circle
     * @return `true` if the point is inside or on the circle, `false` otherwise
     */
    public static inline function pointInCircle(x:Float, y:Float, cx:Float, cy:Float, radius:Float):Bool {

        return ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius);

    }

    /**
     * Tests whether two circles intersect or touch.
     * 
     * Two circles intersect if the distance between their centers is less than or
     * equal to the sum of their radii. This method uses squared distances to avoid
     * the expensive square root operation.
     * 
     * @param x0 The x-coordinate of the first circle's center
     * @param y0 The y-coordinate of the first circle's center
     * @param r0 The radius of the first circle
     * @param x1 The x-coordinate of the second circle's center
     * @param y1 The y-coordinate of the second circle's center
     * @param r1 The radius of the second circle
     * @return `true` if the circles intersect or touch, `false` otherwise
     */
    public static function intersectCircles(x0:Float, y0:Float, r0:Float, x1:Float, y1:Float, r1:Float):Bool {

        // Calculate the squared distance between the two circles' centers
        var dx = x1 - x0;
        var dy = y1 - y0;
        var distanceSquared = dx * dx + dy * dy;

        // Calculate the squared sum of the radii
        var radiiSum = r0 + r1;
        var radiiSumSquared = radiiSum * radiiSum;

        // The circles intersect if the squared distance between their centers is less than or equal to the squared sum of their radii
        return distanceSquared <= radiiSumSquared;

    }

    /**
     * Calculates the Euclidean distance between two points.
     * 
     * This method computes the actual distance value using the square root of the
     * sum of squared differences. For performance-critical code where you only need
     * to compare distances, consider using `squareDistance()` instead.
     * 
     * @param x1 The x-coordinate of the first point
     * @param y1 The y-coordinate of the first point
     * @param x2 The x-coordinate of the second point
     * @param y2 The y-coordinate of the second point
     * @return The distance between the two points
     */
    public static inline function distance(x1:Float, y1:Float, x2:Float, y2:Float):Float {

        var dx:Float = x2 - x1;
        var dy:Float = y2 - y1;

        return Math.sqrt(dx * dx + dy * dy);

    }

    /**
     * Calculates the squared Euclidean distance between two points.
     * 
     * This method returns the square of the distance, avoiding the expensive square
     * root operation. It's ideal for comparing distances or checking if a distance
     * is within a threshold, as the relative ordering is preserved.
     * 
     * Example:
     * ```haxe
     * // Instead of:
     * if (distance(x1, y1, x2, y2) < 100) { ... }
     * 
     * // Use:
     * if (squareDistance(x1, y1, x2, y2) < 100 * 100) { ... }
     * ```
     * 
     * @param x1 The x-coordinate of the first point
     * @param y1 The y-coordinate of the first point
     * @param x2 The x-coordinate of the second point
     * @param y2 The y-coordinate of the second point
     * @return The squared distance between the two points
     */
    public static inline function squareDistance(x1:Float, y1:Float, x2:Float, y2:Float):Float {

        var dx:Float = x2 - x1;
        var dy:Float = y2 - y1;

        return dx * dx + dy * dy;

    }

    /**
     * Calculates the angle from one point to another in degrees.
     * 
     * The angle is measured clockwise from the positive Y-axis (up), making 0° point
     * upward, 90° point right, 180° point down, and 270° point left. This convention
     * matches Ceramic's visual rotation system.
     * 
     * @param x0 The x-coordinate of the starting point
     * @param y0 The y-coordinate of the starting point
     * @param x1 The x-coordinate of the target point
     * @param y1 The y-coordinate of the target point
     * @return The angle in degrees (0-360), measured clockwise from up
     */
    public static function angleTo(x0:Float, y0:Float, x1:Float, y1:Float):Float {

        var result = Utils.radToDeg(Math.atan2(y1 - y0, x1 - x0)) + 90;
        if (result < 0)
            result += 360.0;
        else if (result >= 360.0)
            result -= 360.0;
        return result;

    }

    /**
     * Calculates the shortest angular difference between two angles in degrees.
     * 
     * This method always returns the shortest path between two angles, which will
     * be between -180 and 180 degrees. Positive values indicate clockwise rotation,
     * negative values indicate counter-clockwise rotation.
     * 
     * Example:
     * ```haxe
     * angleDelta(350, 10) // Returns 20 (not 340)
     * angleDelta(10, 350) // Returns -20 (not -340)
     * ```
     * 
     * @param angle0 The starting angle in degrees
     * @param angle1 The target angle in degrees
     * @return The angular difference in degrees (-180 to 180)
     */
    public static function angleDelta(angle0:Float, angle1:Float):Float {

        angle0 = inline clampDegrees(angle0);
        angle1 = inline clampDegrees(angle1);

        // Always choose shortest path (<= 180 degrees)
        var delta = angle1 - angle0;
        if (delta > 180) {
            angle1 -= 360;
        }
        else if (delta < -180) {
            angle1 += 360;
        }

        return angle1 - angle0;

    }

    /**
     * Normalizes an angle to be within the range [0, 360).
     * 
     * This method wraps angles to ensure they fall within the standard 0-360 degree
     * range. Negative angles are wrapped to their positive equivalents, and angles
     * greater than or equal to 360 are reduced by multiples of 360.
     * 
     * Examples:
     * ```haxe
     * clampDegrees(-90)  // Returns 270
     * clampDegrees(450)  // Returns 90
     * clampDegrees(360)  // Returns 0
     * ```
     * 
     * @param deg The angle in degrees to normalize
     * @return The normalized angle in the range [0, 360)
     */
    public static function clampDegrees(deg:Float):Float {

        // Clamp between 0-360
        while (deg < 0) {
            deg += 360;
        }
        while (deg >= 360) {
            deg -= 360;
        }

        return deg;

    }

    /**
     * Converts an angle in degrees to a unit direction vector.
     * 
     * The resulting vector has a magnitude of 1 and points in the direction of the
     * given angle. The angle is measured clockwise from the positive Y-axis (up),
     * matching Ceramic's visual rotation system.
     * 
     * Example:
     * ```haxe
     * var direction = new Point();
     * GeometryUtils.angleDirection(0, direction);   // direction = (0, -1) - pointing up
     * GeometryUtils.angleDirection(90, direction);  // direction = (1, 0)  - pointing right
     * GeometryUtils.angleDirection(180, direction); // direction = (0, 1)  - pointing down
     * ```
     * 
     * @param angle The angle in degrees (0° = up, 90° = right, etc.)
     * @param result The Point object to store the resulting direction vector
     * @return The result object for method chaining
     */
    public static function angleDirection(angle:Float, result:Point):Point {

        var phi = Utils.degToRad((angle - 90));
        result.x = Math.cos(phi);
        result.y = Math.sin(phi);
        return result;

    }

    /**
     * Determines the winding order of a polygon's vertices.
     * 
     * This method uses the shoelace formula to calculate the signed area of the polygon.
     * The sign of the area indicates the winding order: negative for clockwise,
     * positive for counter-clockwise.
     * 
     * Winding order is important for:
     * - Determining front/back faces in rendering
     * - Proper triangulation of polygons
     * - Collision detection algorithms
     * 
     * @param vertices Array of polygon vertices in the format [x0,y0,x1,y1,x2,y2,...]
     * @param offset Starting index in the vertices array (must be even)
     * @param count Number of array elements to process (must be even, minimum 6 for a triangle)
     * @return `true` if vertices are ordered clockwise, `false` if counter-clockwise
     */
    public static function isClockwise(vertices:Array<Float>, offset:Int, count:Int):Bool {
        if (count <= 2) return false;

        var area:Float = 0;
        var last:Int = offset + count - 2;
        var x1:Float = vertices[last];
        var y1:Float = vertices[last + 1];

        var i:Int = offset;
        while (i <= last) {
            var x2:Float = vertices[i];
            var y2:Float = vertices[i + 1];
            area += x1 * y2 - x2 * y1;
            x1 = x2;
            y1 = y2;
            i += 2;
        }

        return area < 0;
    }

}

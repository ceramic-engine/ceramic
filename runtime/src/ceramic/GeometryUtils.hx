package ceramic;

/**
 * Geometry-related utilities.
 */
class GeometryUtils {

    /**
     * Returns `true` if the point `(x,y)` is inside the given (a,b,c) triangle
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
     * Returns `true` if the point `(x,y)` is inside the given (rectX, rectY, rectWidth, rectHeight) rectangle
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
     * Returns `true` if the point `(x,y)` is inside the given (cx, cy, radius) circle
     */
    public static inline function pointInCircle(x:Float, y:Float, cx:Float, cy:Float, radius:Float):Bool {

        return ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius);

    }

    /**
     * Returns the distance between point (x1, y1) and point (x2, y2)
     */
    public static inline function distance(x1:Float, y1:Float, x2:Float, y2:Float):Float {

        var dx:Float = x2 - x1;
        var dy:Float = y2 - y1;

        return Math.sqrt(dx * dx + dy * dy);

    }

    /**
     * Returns the square of the distance between point (x1, y1) and point (x2, y2)
     * It is expected to be used to simply compare two different distances when you
     * don't need the actual distance value (that needs sqrt call).
     */
    public static inline function squareDistance(x1:Float, y1:Float, x2:Float, y2:Float):Float {

        var dx:Float = x2 - x1;
        var dy:Float = y2 - y1;

        return dx * dx + dy * dy;

    }

    /**
     * Returns the angle between (x0, y0) and (x1, y1) in degrees.
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
     * Returns the delta between `angle0` and `angle1`, all values being angles in degrees.
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
     * Clamp an degrees (angle) value between 0 (included) and 360 (excluded)
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
     * Set the given result's `x` and `y` values so that it's a vector representing
     * a direction matching the angle (in degrees)
     * @param angle The angle to compute the direction from
     * @param result The vector (a `Point` object) receiving the result
     */
    public static function angleDirection(angle:Float, result:Point):Point {

        var phi = Utils.degToRad((angle - 90));
        result.x = Math.cos(phi);
        result.y = Math.sin(phi);
        return result;

    }

}

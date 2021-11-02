package ceramic;

/**
 * Geometry-related utilities.
 */
class GeometryUtils {

    /**
     * Returns `true` if the point `(x,y)` is inside the given (a,b,c) triangle
     */
    public static inline function pointInTriangle(x:Float, y:Float, ax:Float, ay:Float, bx:Float, by:Float, cx:Float, cy:Float):Bool {

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
     * Returns the distance between point (x1, y1) and point (x2, y2)
     */
    public static inline function distance(x1:Float, y1:Float, x2:Float, y2:Float):Float {

        var dx:Float = x2 - x1;
        var dy:Float = y2 - y1;

        return Math.sqrt(dx * dx + dy * dy);

    }
}

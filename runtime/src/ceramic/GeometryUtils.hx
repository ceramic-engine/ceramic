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

}

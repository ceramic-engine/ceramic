package ceramic;

/** Geometry-related utilities. */
class GeometryUtils {

    /** Returns `true` if the point `(x,y)` is inside the given (a,b,c) triangle */
    public static inline function pointInTriangle(x:Float, y:Float, ax:Float, ay:Float, bx:Float, by:Float, cx:Float, cy:Float):Bool {
        return (cx - x) * (ay - y) - (ax - x) * (cy - y) >= 0 &&
               (ax - x) * (by - y) - (bx - x) * (ay - y) >= 0 &&
               (bx - x) * (cy - y) - (cx - x) * (by - y) >= 0;
    }

}

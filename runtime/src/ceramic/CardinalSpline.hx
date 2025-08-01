package ceramic;

// Ported from cardinal-spline-js (https://github.com/gdenisov/cardinal-spline-js/blob/2b4a7935e16ed2a231742ede801dc7750a0ac264/src/curve_calc.js)
// Curve calc function for canvas 2.3.1
// Epistemex (c) 2013-2014
// License: MIT

using ceramic.Extensions;

/**
 * Cardinal spline interpolation for smooth curves through control points.
 * 
 * This class provides utilities for creating smooth curves that pass through
 * a series of control points using Cardinal spline interpolation. Cardinal
 * splines are a type of cubic Hermite spline where tangents are calculated
 * automatically from neighboring points.
 * 
 * ## Features
 * 
 * - **Smooth Interpolation**: Creates C1 continuous curves through all points
 * - **Adjustable Tension**: Control curve tightness (0 = sharp, 1 = loose)
 * - **Variable Resolution**: Specify segments between points for quality
 * - **Closed Curves**: Option to create continuous loops
 * - **Performance Optimized**: Pre-cached calculations for efficiency
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Define control points [x1,y1, x2,y2, ...]
 * var points = [100,100, 200,150, 300,100, 400,200];
 * 
 * // Generate smooth curve points
 * var smooth = CardinalSpline.getCurvePoints(
 *     points,
 *     0.5,    // tension
 *     20,     // segments per curve
 *     false   // not closed
 * );
 * 
 * // Draw the smooth curve
 * var line = new Line();
 * line.points = smooth;
 * ```
 * 
 * ## Algorithm
 * 
 * Cardinal splines use the positions of four consecutive points (P0, P1, P2, P3)
 * to calculate the curve between P1 and P2. The tangent at each point is
 * determined by the vector between its neighbors, scaled by the tension parameter.
 * 
 * @see ceramic.Line For rendering spline curves
 * @see ceramic.Shape For filled shapes with spline boundaries
 */
class CardinalSpline {

    /**
     * Cached hermite basis function values for performance.
     * Reused across multiple spline calculations.
     */
    static var cache:Array<Float> = [];

    /**
     * Calculates an array containing points representing a cardinal spline through given point array.
     * Points must be arranged as: [x1, y1, x2, y2, ..., xn, yn].
     *
     * The points for the cardinal spline are returned as a new array.
     *
     * @param points Point array containing at least 2 points (4 values).
     *               Format: [x1, y1, x2, y2, ..., xn, yn]
     * @param tension Curve tension parameter. Default: 0.5
     *                - 0.0 = sharp corners (Catmull-Rom spline)
     *                - 0.5 = balanced curve
     *                - 1.0 = loose curve
     *                - Can exceed [0,1] for special effects
     * @param numSegments Number of interpolated points between each pair of control points.
     *                    Higher values create smoother curves. Default: 25
     * @param close Whether to connect the last point back to the first, creating a closed loop.
     *              Default: false
     * @param result Optional array to store results in (avoids allocation).
     *               Will be resized as needed.
     * @return Array containing interpolated points [x1,y1, x2,y2, ...]
     *         Length = (numPoints-1) * numSegments * 2 + 2 (+ extra for closed)
     * 
     * @example
     * ```haxe
     * // Create a smooth curve through 4 points
     * var controlPoints = [
     *     100, 100,  // Point 1
     *     200, 50,   // Point 2  
     *     300, 150,  // Point 3
     *     400, 100   // Point 4
     * ];
     * 
     * var smoothCurve = CardinalSpline.getCurvePoints(
     *     controlPoints,
     *     0.5,   // Medium tension
     *     30     // 30 segments between points
     * );
     * ```
     */
    public static function getCurvePoints(
        points:Array<Float>,
        tension:Float = 0.5,
        numSegments:Int = 25,
        close:Bool = false,
        ?result:Array<Float>) {

        var pts:Array<Float> = [].concat(points);
        var l:Int = points.length;
        var rPos:Int = 0;
        var rLen:Int = (l-2) * numSegments + 2 + (close ? 2 * numSegments : 0);

        if (result == null)
            result = [];
        result.setArrayLength(rLen);

        var cacheLen:Int = (numSegments + 2) * 4;
        if (cache.length < cacheLen)
            cache.setArrayLength(cacheLen);
        var cachePtr = 4;

        if (close) {
            // Insert end point as first point
            pts.unshift(points[l - 1]);
            pts.unshift(points[l - 2]);
            // First point as last point
            pts.push(points.unsafeGet(0));
            pts.push(points.unsafeGet(1));
        }
        else {
            // Copy 1. point and insert at beginning
            pts.unshift(points.unsafeGet(1));
            pts.unshift(points.unsafeGet(0));
            // Duplicate end-points
            pts.push(points[l - 2]);
            pts.push(points[l - 1]);
        }

        // Cache inner-loop calculations as they are based on t alone
        cache.unsafeSet(0, 1);
        cache.unsafeSet(1, 0);
        cache.unsafeSet(2, 0);
        cache.unsafeSet(3, 0);

        for (i in 1...numSegments) {

            var st:Float = i / numSegments;
            var st2 = st * st;
            var st3 = st2 * st;
            var st23 = st3 * 2;
            var st32 = st2 * 3;

            cache.unsafeSet(cachePtr, st23 - st32 + 1);
            cachePtr++;
            cache.unsafeSet(cachePtr, st32 - st23);
            cachePtr++;
            cache.unsafeSet(cachePtr, st3 - 2 * st2 + st);
            cachePtr++;
            cache.unsafeSet(cachePtr, st3 - st2);
            cachePtr++;
        }

        cache.unsafeSet(cachePtr, 0);
        cachePtr++;
        cache.unsafeSet(cachePtr, 1);
        cachePtr++;
        cache.unsafeSet(cachePtr, 0);
        cachePtr++;
        cache.unsafeSet(cachePtr, 0);
        cachePtr++;

        // Calc. points
        rPos = parse(pts, cache, l, tension, numSegments, result, rPos);

        if (close) {
            // l = points.length;
            pts.setArrayLength(8);
            // Second last and last
            pts.unsafeSet(0, points[l - 4]);
            pts.unsafeSet(1, points[l - 3]);
            pts.unsafeSet(2, points[l - 2]);
            pts.unsafeSet(3, points[l - 1]);
            // First and second
            pts.unsafeSet(4, points.unsafeGet(0));
            pts.unsafeSet(5, points.unsafeGet(1));
            pts.unsafeSet(6, points.unsafeGet(2));
            pts.unsafeSet(7, points.unsafeGet(3));

            rPos = parse(pts, cache, 4, tension, numSegments, result, rPos);
        }

        // Add last point
        l = close ? 0 : points.length - 2;
        result.unsafeSet(rPos, points.unsafeGet(l));
        rPos++;
        result.unsafeSet(rPos, points[l+1]);

        return result;

    }

    /**
     * Internal function that performs the actual spline interpolation.
     * Uses cached hermite basis functions for performance.
     * 
     * @param pts Extended point array with duplicated endpoints
     * @param cache Pre-calculated hermite basis function values
     * @param l Original point array length
     * @param tension Spline tension parameter
     * @param numSegments Segments between control points
     * @param result Output array for interpolated points
     * @param rPos Current position in result array
     * @return Updated position in result array
     */
    inline private static function parse(pts:Array<Float>, cache:Array<Float>, l:Int, tension:Float, numSegments:Int, result:Array<Float>, rPos:Int):Int {

        var i:Int = 2;
        var t:Int = 0;
        var n:Int = 0;
        while (i < l) {

            n = i;
            var pt1:Float = pts.unsafeGet(n);
            n++;
            var pt2:Float = pts.unsafeGet(n);
            n++;
            var pt3:Float = pts.unsafeGet(n);
            n++;
            var pt4:Float = pts.unsafeGet(n);

            n = i - 2;
            var t1x:Float = (pt3 - pts.unsafeGet(n)) * tension;
            n++;
            var t1y:Float = (pt4 - pts.unsafeGet(n)) * tension;
            n = i + 4;
            var t2x:Float = (pts.unsafeGet(n) - pt1) * tension;
            n++;
            var t2y:Float = (pts.unsafeGet(n) - pt2) * tension;

            t = 0;
            while (t < numSegments) {

                var c:Int = t << 2; // t * 4;

                var c1 = cache.unsafeGet(c);
                c++;
                var c2 = cache.unsafeGet(c);
                c++;
                var c3 = cache.unsafeGet(c);
                c++;
                var c4 = cache.unsafeGet(c);

                var res:Float = c1 * pt1 + c2 * pt3 + c3 * t1x + c4 * t2x;
                result.unsafeSet(rPos, res);
                rPos++;
                res = c1 * pt2 + c2 * pt4 + c3 * t1y + c4 * t2y;
                result.unsafeSet(rPos, res);
                rPos++;

                t++;
            }

            i += 2;
        }

        return rPos;

    }

}

package ceramic;

// Ported from cardinal-spline-js (https://github.com/gdenisov/cardinal-spline-js/blob/2b4a7935e16ed2a231742ede801dc7750a0ac264/src/curve_calc.js)
// Curve calc function for canvas 2.3.1
// Epistemex (c) 2013-2014
// License: MIT

using ceramic.Extensions;

class CardinalSpline {

    static var cache:Array<Float> = [];

    /**
     * Calculates an array containing points representing a cardinal spline through given point array.
     * Points must be arranged as: [x1, y1, x2, y2, ..., xn, yn].
     *
     * The points for the cardinal spline are returned as a new array.
     *
     * @param points Point array
     * @param tension [0.5] Typically between [0.0, 1.0] but can be exceeded
     * @param numSegments [25] Number of segments between two points (line resolution)
     * @param close [false] Close the ends making the line continuous
     * @param result (optional) The resulting array
     * @returns New array with the calculated points that were added to the path
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

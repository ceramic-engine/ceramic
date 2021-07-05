package ceramic;

import ceramic.Assert.*;

using ceramic.Extensions;

/**
 * Bezier curve easing, ported from https://github.com/gre/bezier-easing
 * then extended to work with both cubic and quadratic settings
 */
class BezierEasing {

    static var SPLINE_TABLE_SIZE = 11;
    static var SAMPLE_STEP_SIZE = 1.0 / (SPLINE_TABLE_SIZE - 1.0);
    static var NEWTON_ITERATIONS = 4;
    static var NEWTON_MIN_SLOPE = 0.001;
    static var SUBDIVISION_PRECISION = 0.0000001;
    static var SUBDIVISION_MAX_ITERATIONS = 10;
    static var TWO_THIRD = 2.0 / 3.0;

    static var CACHE_SIZE:Int = 10000;

    var linearEasing = false;

    var sampleValues:Array<Float>;

    var cached:Bool = false;

    var quadratic:Bool = false;

    var mQuadraticX1:Float;

    var mQuadraticX2:Float;

    var mX1:Float;
    
    var mY1:Float;

    var mX2:Float;

    var mY2:Float;

    /**
     * Create a new instance with the given arguments.
     * If only `x1` and `y1` are provided, the curve is treated as quadratic.
     * If all four values `x1`, `y1`, `x2`, `y2` are provided,
     * the curve is treated as cubic.
     */
    public function new(x1:Float, y1:Float, ?x2:Float, ?y2:Float) {

        inline configure(x1, y1, x2, y2);

    }

    /**
     * Configure the instance with the given arguments.
     * If only `x1` and `y1` are provided, the curve is treated as quadratic.
     * If all four values `x1`, `y1`, `x2`, `y2` are provided,
     * the curve is treated as cubic.
     */
    public function configure(x1:Float, y1:Float, ?x2:Float, ?y2:Float) {

        // If this instance was part of the cache,
        // it should be removed as its settings will change
        if (cached)
            removeFromCache(mX1, mY1, mX2, mY2);

        if (x2 == null || y2 == null) {
            this.quadratic = true;
            this.mQuadraticX1 = x1;
            this.mQuadraticX2 = x2;
            this.mX1 = quadraticToCubicCP1(x1);
            this.mY1 = quadraticToCubicCP1(y1);
            this.mX2 = quadraticToCubicCP2(x1);
            this.mY2 = quadraticToCubicCP2(y1);
        }
        else {
            this.quadratic = false;
            this.mX1 = x1;
            this.mY1 = y1;
            this.mX2 = x2;
            this.mY2 = y2;
        }

        assert((0 <= mX1 && mX1 <= 1 && 0 <= mX2 && mX2 <= 1), 'bezier x values must be in [0, 1] range');

        if (mX1 == mY1 && mX2 == mY2) {
            linearEasing = true;
        }
        else {
            // Precompute samples table
            if (sampleValues == null)
                sampleValues = [];
            for (i in 0...SPLINE_TABLE_SIZE) {
                sampleValues[i] = calcBezier(i * SAMPLE_STEP_SIZE, mX1, mX2);
            }
        }

    }

    public function ease(x:Float):Float {

        if (x == 0) return 0;
        if (x == 1) return 1;
        return calcBezier(getTForX(x), mY1, mY2);

    }

    inline function getTForX(aX:Float):Float {

        var intervalStart = 0.0;
        var currentSample = 1;
        var lastSample = SPLINE_TABLE_SIZE - 1;

        while (currentSample != lastSample && sampleValues[currentSample] <= aX) {
            intervalStart += SAMPLE_STEP_SIZE;
            currentSample++;
        }
        currentSample--;

        // Interpolate to provide an initial guess for t
        var dist = (aX - sampleValues[currentSample]) / (sampleValues[currentSample + 1] - sampleValues[currentSample]);
        var guessForT:Float = intervalStart + dist * SAMPLE_STEP_SIZE;

        var initialSlope = getSlope(guessForT, mX1, mX2); 
        if (initialSlope >= NEWTON_MIN_SLOPE) {
            return newtonRaphsonIterate(aX, guessForT, mX1, mX2);
        } else if (initialSlope == 0.0) {
            return guessForT;
        } else {
            return binarySubdivide(aX, intervalStart, intervalStart + SAMPLE_STEP_SIZE, mX1, mX2);
        }

    }

    /**
     * Returns x(t) given t, x1, and x2, or y(t) given t, y1, and y2
     */
    inline function calcBezier(aT:Float, aA1:Float, aA2:Float) {

        return ((A(aA1, aA2) * aT + B(aA1, aA2)) * aT + C(aA1)) * aT;

    }

    /**
     * Returns dx/dt given t, x1, and x2, or dy/dt given t, y1, and y2
     */
    inline function getSlope(aT:Float, aA1:Float, aA2:Float) {
        
        return 3.0 * A(aA1, aA2) * aT * aT + 2.0 * B(aA1, aA2) * aT + C(aA1);
        
    }

    inline function binarySubdivide(aX:Float, aA:Float, aB:Float, mX1:Float, mX2:Float) {

        var currentX:Float;
        var currentT:Float;
        var i = 0;

        do {
            currentT = aA + (aB - aA) / 2.0;
            currentX = calcBezier(currentT, mX1, mX2) - aX;
            if (currentX > 0.0) {
                aB = currentT;
            } else {
                aA = currentT;
            }
        } while (Math.abs(currentX) > SUBDIVISION_PRECISION && ++i < SUBDIVISION_MAX_ITERATIONS);

        return currentT;

    }

    function newtonRaphsonIterate(aX:Float, aGuessT:Float, mX1:Float, mX2:Float) {

        for (i in 0...NEWTON_ITERATIONS) {
            var currentSlope = getSlope(aGuessT, mX1, mX2);
            if (currentSlope == 0.0) {
                return aGuessT;
            }
            var currentX = calcBezier(aGuessT, mX1, mX2) - aX;
            aGuessT -= currentX / currentSlope;
        }

        return aGuessT;

    }

    inline function A(aA1:Float, aA2:Float) { return 1.0 - 3.0 * aA2 + 3.0 * aA1; }
    inline function B(aA1:Float, aA2:Float) { return 3.0 * aA2 - 6.0 * aA1; }
    inline function C(aA1:Float)            { return 3.0 * aA1; }

    inline static function quadraticToCubicCP1(p:Float):Float {

        return TWO_THIRD * p;
        
    }

    inline static function quadraticToCubicCP2(p:Float):Float {

        return 1.0 + TWO_THIRD * (p - 1.0);
        
    }

    /// Cache

    static var cachedInstances:IntMap<Array<BezierEasing>> = null;

    static var numCachedInstances:Int = 0;

    function removeFromCache(x1:Float, y1:Float, x2:Float, y2:Float):Void {

        cached = false;

        var key = cacheKey(x1, y1, x2, y2);
        if (cachedInstances != null) {
            var list = cachedInstances.getInline(key);
            if (list != null) {
                if (list.length == 1 && list.unsafeGet(0) == this) {
                    cachedInstances.remove(key);
                }
                else {
                    list.remove(this);
                }
            }
        }

    }

    inline static function cacheKey(x1:Float, y1:Float, x2:Float, y2:Float):Int {

        var floatKey = x1 * 100 + y1 * 1000 + x2 * 10000 + y2 * 100000;
        return Std.int(floatKey);

    }

    public static function clearCache():Void {

        cachedInstances = null;
        numCachedInstances = 0;

    }

    /**
     * Get or create a `BezierEasing` instance with the given parameters.
     * Created instances are cached and reused.
     */
    public static function get(x1:Float, y1:Float, ?x2:Float, ?y2:Float):BezierEasing {

        var quadratic = (x2 == null || y2 == null);

        var _x1:Float = quadratic ? quadraticToCubicCP1(x1) : x1;
        var _y1:Float = quadratic ? quadraticToCubicCP1(y1) : y1;
        var _x2:Float = quadratic ? quadraticToCubicCP2(x1) : x2;
        var _y2:Float = quadratic ? quadraticToCubicCP2(y1) : y2;

        var result:BezierEasing = null;

        var key = cacheKey(_x1, _y1, _x2, _y2);
        if (cachedInstances == null) {
            cachedInstances = new IntMap<Array<BezierEasing>>();
        }
        var list = cachedInstances.getInline(key);
        if (list == null) {
            if (numCachedInstances >= CACHE_SIZE) {
                clearCache();
            }
            // No list matching key, create new list with new instance
            result = new BezierEasing(_x1, _y1, _x2, _y2);
            cachedInstances.set(key, [result]);
            numCachedInstances++;
        }
        else {
            // Look for an existing instance, starting from the latest added
            var i = list.length - 1;
            while (i >= 0) {
                var instance = list.unsafeGet(i);
                if (instance.mX1 == _x1 && instance.mY1 == _y1
                && instance.mX2 == _x2 && instance.mY2 == _y2) {
                    // Found it! reuse instance
                    result = instance;
                    break;
                }
                i--;
            }
            if (result == null) {
                // Nothing found, create a new instance
                result = new BezierEasing(x1, y1, x2, y2);
                result.cached = true;
                list.push(result);
            }
        }

        return result;

    }

}

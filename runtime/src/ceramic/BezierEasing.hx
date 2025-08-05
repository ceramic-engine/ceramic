package ceramic;

import ceramic.Assert.*;

using ceramic.Extensions;

/**
 * High-performance Bezier curve easing for smooth animations.
 * 
 * This class implements cubic and quadratic Bezier easing functions with optimized
 * performance through pre-computed sample tables and intelligent caching. Based on
 * the implementation from https://github.com/gre/bezier-easing, extended to support
 * both cubic and quadratic curves.
 * 
 * ## Features
 * 
 * - **Cubic Bezier**: Standard CSS-style cubic-bezier(x1, y1, x2, y2)
 * - **Quadratic Bezier**: Simplified two-point control
 * - **Performance Optimized**: Pre-computed samples and Newton-Raphson iteration
 * - **Instance Caching**: Automatic reuse of common easing functions
 * - **Linear Detection**: Automatically optimizes linear easings
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Create cubic bezier (CSS-style)
 * var easeInOut = new BezierEasing(0.42, 0, 0.58, 1);
 * var progress = easeInOut.ease(0.5); // Returns ~0.5
 * 
 * // Create quadratic bezier (single control point)
 * var easeQuad = new BezierEasing(0.5, 0.8);
 * 
 * // Use cached instances for better performance
 * var cached = BezierEasing.get(0.25, 0.1, 0.25, 1); // ease-out
 * 
 * // Common easing curves
 * var easeIn = BezierEasing.get(0.42, 0, 1, 1);
 * var easeOut = BezierEasing.get(0, 0, 0.58, 1);
 * var easeInOut = BezierEasing.get(0.42, 0, 0.58, 1);
 * ```
 * 
 * ## Performance Notes
 * 
 * - First call pre-computes 11 sample points
 * - Subsequent calls use Newton-Raphson method (4 iterations max)
 * - Linear easings bypass all calculations
 * - Cache stores up to 10,000 instances
 * 
 * @see ceramic.Easing For pre-defined easing functions
 * @see ceramic.Tween For animation implementation
 */
class BezierEasing {

    /** Number of pre-computed samples for faster lookup */
    static var SPLINE_TABLE_SIZE = 11;
    
    /** Distance between each sample point */
    static var SAMPLE_STEP_SIZE = 1.0 / (SPLINE_TABLE_SIZE - 1.0);
    
    /** Maximum iterations for Newton-Raphson method */
    static var NEWTON_ITERATIONS = 4;
    
    /** Minimum slope to use Newton-Raphson (below this, use subdivision) */
    static var NEWTON_MIN_SLOPE = 0.001;
    
    /** Precision threshold for binary subdivision */
    static var SUBDIVISION_PRECISION = 0.0000001;
    
    /** Maximum iterations for binary subdivision */
    static var SUBDIVISION_MAX_ITERATIONS = 10;
    
    /** Constant for quadratic to cubic conversion */
    static var TWO_THIRD = 2.0 / 3.0;

    /** Maximum number of cached instances before clearing cache */
    static var CACHE_SIZE:Int = 10000;

    /** Whether this easing is linear (optimization flag) */
    var linearEasing = false;

    /** Pre-computed sample values for performance */
    var sampleValues:Array<Float>;

    /** Whether this instance is stored in the cache */
    var cached:Bool = false;

    /** Whether this is a quadratic (vs cubic) curve */
    var quadratic:Bool = false;

    /** Original quadratic X1 value (before conversion) */
    var mQuadraticX1:Float;

    /** Original quadratic X2 value (before conversion) */
    var mQuadraticX2:Float;

    /** First control point X coordinate (0-1) */
    var mX1:Float;

    /** First control point Y coordinate */
    var mY1:Float;

    /** Second control point X coordinate (0-1) */
    var mX2:Float;

    /** Second control point Y coordinate */
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
            linearEasing = false;
            // Precompute samples table
            if (sampleValues == null)
                sampleValues = [];
            for (i in 0...SPLINE_TABLE_SIZE) {
                sampleValues[i] = calcBezier(i * SAMPLE_STEP_SIZE, mX1, mX2);
            }
        }

    }

    /**
     * Calculates the eased value for the given progress.
     * 
     * @param x Progress value from 0 to 1
     * @return Eased value (typically 0 to 1, but can overshoot)
     * 
     * ```haxe
     * var easing = new BezierEasing(0.42, 0, 0.58, 1);
     * tween.progress = easing.ease(elapsed / duration);
     * ```
     */
    public function ease(x:Float):Float {

        if (linearEasing) return x;
        if (x == 0) return 0;
        if (x == 1) return 1;
        return calcBezier(getTForX(x), mY1, mY2);

    }

    /**
     * Finds the t parameter for a given x value using the pre-computed samples.
     * Uses Newton-Raphson iteration when slope is sufficient, otherwise falls
     * back to binary subdivision.
     */
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
     * Calculates the bezier curve value at parameter t.
     * 
     * @param aT The t parameter (0-1)
     * @param aA1 First control point coordinate
     * @param aA2 Second control point coordinate
     * @return The curve value at t
     */
    inline function calcBezier(aT:Float, aA1:Float, aA2:Float) {

        return ((A(aA1, aA2) * aT + B(aA1, aA2)) * aT + C(aA1)) * aT;

    }

    /**
     * Calculates the derivative (slope) of the bezier curve at parameter t.
     * 
     * @param aT The t parameter (0-1)
     * @param aA1 First control point coordinate
     * @param aA2 Second control point coordinate
     * @return The slope at t
     */
    inline function getSlope(aT:Float, aA1:Float, aA2:Float) {

        return 3.0 * A(aA1, aA2) * aT * aT + 2.0 * B(aA1, aA2) * aT + C(aA1);

    }

    /**
     * Uses binary subdivision to find t for a given x when Newton-Raphson
     * is not suitable (low slope).
     */
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

    /**
     * Uses Newton-Raphson iteration to quickly converge on the t value
     * for a given x coordinate.
     */
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

    /** Bezier coefficient A for cubic formula */
    inline function A(aA1:Float, aA2:Float) { return 1.0 - 3.0 * aA2 + 3.0 * aA1; }
    
    /** Bezier coefficient B for cubic formula */
    inline function B(aA1:Float, aA2:Float) { return 3.0 * aA2 - 6.0 * aA1; }
    
    /** Bezier coefficient C for cubic formula */
    inline function C(aA1:Float)            { return 3.0 * aA1; }

    /**
     * Converts a quadratic control point to the first cubic control point.
     */
    inline static function quadraticToCubicCP1(p:Float):Float {

        return TWO_THIRD * p;

    }

    /**
     * Converts a quadratic control point to the second cubic control point.
     */
    inline static function quadraticToCubicCP2(p:Float):Float {

        return 1.0 + TWO_THIRD * (p - 1.0);

    }

    /// Cache

    /** Map of cached instances by parameter hash */
    static var cachedInstances:IntMap<Array<BezierEasing>> = null;

    /** Current number of cached instances */
    static var numCachedInstances:Int = 0;

    /**
     * Removes this instance from the cache when its parameters change.
     */
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

    /**
     * Generates a hash key for caching based on control points.
     * Note: This is a simple hash that may have collisions.
     */
    inline static function cacheKey(x1:Float, y1:Float, x2:Float, y2:Float):Int {

        var floatKey = x1 * 10000 + y1 * 100000 + x2 * 1000000 + y2 * 10000000;
        return Std.int(floatKey);

    }

    /**
     * Clears all cached BezierEasing instances.
     * 
     * Call this if you need to free memory or have created
     * many temporary easing functions.
     */
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

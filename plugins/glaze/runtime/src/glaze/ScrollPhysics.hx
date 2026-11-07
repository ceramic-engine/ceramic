// Ported from gpui-pre 0.3.10: src/gestures.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * How free scrolling decelerates after a fling.
 *
 * This models deceleration only. Boundary behavior (bouncing, edge glow,
 * clamping) is the scroll container's policy: the container is the one that
 * knows its extents.
 */
@:using(glaze.ScrollPhysics.ScrollPhysicsTools)
enum ScrollPhysics {

    /**
     * Exponential velocity decay, the `UIScrollView` model:
     * `velocity(t) = v0 * decayPerMs^ms`. `UIScrollView`'s normal
     * deceleration rate is `0.998`.
     */
    Exponential(decayPerMs:Float);

    /**
     * The friction spline of Android's `OverScroller`: fling duration and
     * distance follow a logarithmic deceleration law, and progress along the
     * fling follows a cubic-Bezier ease-out curve. Transcribed from AOSP's
     * `SplineOverScroller` (Apache-2.0). `friction` is the scroll friction
     * coefficient (`0.015` on Android), `pixelsPerInch` the display density
     * in the coordinate space the fling runs in.
     */
    FrictionSpline(friction:Float, pixelsPerInch:Float);

}

/**
 * The methods of `ScrollPhysics`.
 */
class ScrollPhysicsTools {

    /**
     * Momentum below this speed, in pixels per second, is imperceptible. The
     * exponential model, which never mathematically stops, treats reaching
     * this speed as the end of the fling.
     */
    public static inline final MOMENTUM_STOP_VELOCITY:Float = 10.;

    /** iOS scroll feel: `UIScrollView`'s normal deceleration rate. */
    public static function ios():ScrollPhysics {
        return Exponential(0.998);
    }

    /**
     * Android scroll feel: `OverScroller` with stock friction, at Android's
     * nominal density of 160 density-independent pixels per inch.
     */
    public static function android():ScrollPhysics {
        return FrictionSpline(0.015, 160.);
    }

    /**
     * How long a fling released at `speed` pixels per second coasts before
     * it stops, in seconds.
     */
    public static function flingDuration(physics:ScrollPhysics, speed:Float):Float {
        return switch physics {
            case Exponential(decayPerMs):
                if (speed <= MOMENTUM_STOP_VELOCITY) {
                    0.;
                }
                else {
                    final milliseconds = Math.log(MOMENTUM_STOP_VELOCITY / speed) / Math.log(decayPerMs);
                    milliseconds / 1000.;
                }
            case FrictionSpline(friction, pixelsPerInch):
                if (speed <= 0.) {
                    0.;
                }
                else {
                    final deceleration = FrictionSplineModel.deceleration(speed, friction, pixelsPerInch);
                    Math.exp(deceleration / (FrictionSplineModel.decelerationRate() - 1.));
                }
        }
    }

    /**
     * Distance traveled `elapsed` seconds into a fling released at `speed`
     * pixels per second, in pixels along the fling direction. Evaluated in
     * closed form so the trajectory is independent of tick timing.
     */
    public static function flingDistance(physics:ScrollPhysics, speed:Float, elapsed:Float):Float {
        final duration = flingDuration(physics, speed);
        if (duration == 0.) {
            return 0.;
        }
        if (elapsed > duration) elapsed = duration;
        return switch physics {
            case Exponential(decayPerMs):
                final milliseconds = elapsed * 1000.;
                (speed / 1000.) * (Math.pow(decayPerMs, milliseconds) - 1.) / Math.log(decayPerMs);
            case FrictionSpline(friction, pixelsPerInch):
                final deceleration = FrictionSplineModel.deceleration(speed, friction, pixelsPerInch);
                final rate = FrictionSplineModel.decelerationRate();
                final totalDistance = friction * FrictionSplineModel.physicalCoefficient(pixelsPerInch) * Math.exp(rate / (rate - 1.) * deceleration);
                final progress = elapsed / duration;
                totalDistance * FrictionSplineModel.distanceCoefficient(progress);
        }
    }

}

/**
 * The fling model of Android's `OverScroller.SplineOverScroller`,
 * transcribed from AOSP (Apache-2.0) (Rust module `friction_spline`).
 */
@:allow(glaze)
class FrictionSplineModel {

    static inline final NB_SAMPLES:Int = 100;
    static inline final INFLEXION:Float = 0.35;
    static inline final START_TENSION:Float = 0.5;
    static inline final END_TENSION:Float = 1.0;
    static inline final P1:Float = START_TENSION * INFLEXION;
    static inline final P2:Float = 1.0 - END_TENSION * (1.0 - INFLEXION);

    static var splinePosition:Null<Array<Float>> = null;

    /** Android's `DECELERATION_RATE`: `ln(0.78) / ln(0.9)`. */
    public static function decelerationRate():Float {
        return Math.log(0.78) / Math.log(0.9);
    }

    /**
     * `SPLINE_POSITION` from AOSP's static initializer: fractional fling
     * distance sampled at 100 evenly spaced fractions of the fling duration.
     */
    public static function splinePositionSamples():Array<Float> {
        if (splinePosition != null)
            return splinePosition;
        final samples = [for (_ in 0...NB_SAMPLES + 1) 0.];
        var xMin = 0.;
        for (i in 0...NB_SAMPLES) {
            final alpha = i / NB_SAMPLES;
            var xMax = 1.;
            var x = 0.;
            var coefficient = 0.;
            while (true) {
                x = xMin + (xMax - xMin) / 2.;
                coefficient = 3. * x * (1. - x);
                final time = coefficient * ((1. - x) * P1 + x * P2) + x * x * x;
                if (Math.abs(time - alpha) < 1e-5) {
                    break;
                }
                if (time > alpha) {
                    xMax = x;
                }
                else {
                    xMin = x;
                }
            }
            samples[i] = coefficient * ((1. - x) * START_TENSION + x) + x * x * x;
        }
        samples[NB_SAMPLES] = 1.;
        splinePosition = samples;
        return samples;
    }

    /**
     * `SensorManager.GRAVITY_EARTH * 39.37 in/m * ppi * 0.84`, AOSP's
     * `mPhysicalCoeff`.
     */
    public static function physicalCoefficient(pixelsPerInch:Float):Float {
        return 9.80665 * 39.37 * pixelsPerInch * 0.84;
    }

    /** AOSP's `getSplineDeceleration`. */
    public static function deceleration(speed:Float, friction:Float, pixelsPerInch:Float):Float {
        return Math.log(INFLEXION * speed / (friction * physicalCoefficient(pixelsPerInch)));
    }

    /**
     * Fraction of the total fling distance covered at fraction `time` of the
     * fling duration: table lookup plus linear interpolation.
     */
    public static function distanceCoefficient(time:Float):Float {
        if (time >= 1.) {
            return 1.;
        }
        final samples = splinePositionSamples();
        var index = Std.int(NB_SAMPLES * time);
        if (index > NB_SAMPLES - 1) index = NB_SAMPLES - 1;
        if (index < 0) index = 0;
        final timeLower = index / NB_SAMPLES;
        final timeUpper = (index + 1) / NB_SAMPLES;
        final distanceLower = samples[index];
        final distanceUpper = samples[index + 1];
        final velocityCoefficient = (distanceUpper - distanceLower) / (timeUpper - timeLower);
        return distanceLower + (time - timeLower) * velocityCoefficient;
    }

    /** Test helper: the Bezier's time and position at `parameter`. */
    public static function bezierTimeAndPosition(parameter:Float):{time:Float, position:Float} {
        final coefficient = 3. * parameter * (1. - parameter);
        final cubed = parameter * parameter * parameter;
        return {
            time: coefficient * ((1. - parameter) * P1 + parameter * P2) + cubed,
            position: coefficient * ((1. - parameter) * START_TENSION + parameter) + cubed
        };
    }

}

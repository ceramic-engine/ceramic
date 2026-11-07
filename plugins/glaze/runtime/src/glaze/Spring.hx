// Ported from gpui-pre 0.3.10: src/spring.rs (constants, sampled_easing and private helpers)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

import glaze.SpringMath.*;
import glaze.util.MathUtil;

/**
 * Free functions and constants of GPUI's spring module.
 *
 * Durations are seconds as `Float`. `std::time::Duration` holds whole
 * nanoseconds, so `durationFromSecs` rounds to the nearest nanosecond like
 * `Duration::from_secs_f32`, and `Duration::MAX` is `DURATION_MAX`.
 * Computations are done in `f32` like GPUI (see `SpringMath`).
 */
class Spring {

    public static inline final CRITICAL_DAMPING_TOLERANCE:Float = 1e-4;

    public static inline final DEFAULT_SPRING_EPSILON:Float = 0.001;

    /**
     * `1.0 - CRITICAL_DAMPING_TOLERANCE` in `f32`: below, a spring is underdamped.
     */
    public static final UNDERDAMPED_LIMIT:Float = f32(1.0 - f32(CRITICAL_DAMPING_TOLERANCE));

    /**
     * `1.0 + CRITICAL_DAMPING_TOLERANCE` in `f32`: above, a spring is overdamped.
     */
    public static final OVERDAMPED_LIMIT:Float = f32(1.0 + f32(CRITICAL_DAMPING_TOLERANCE));

    /**
     * `Duration::MAX` in seconds (2^64, its value as f64 and as f32).
     */
    public static inline final DURATION_MAX:Float = 18446744073709551616.0;

    /**
     * Adapts a spring starting at zero with no velocity to GPUI's duration-based easing API.
     *
     * The returned easing can overshoot the normalized 0..1 output range. Retargeting
     * this duration-based form restarts the spring; use `SpringConfig.step` when
     * preserving velocity matters.
     */
    public static function sampledEasing(config:SpringConfig, epsilon:Float):SpringSampledEasing {

        final initialState = new SpringState(0.0, 0.0);
        final duration = config.settleTime(initialState, 1.0, epsilon);
        final durationSeconds = durationAsSecsF32(duration);

        return new SpringSampledEasing(duration, progress -> {
            final progress = f32(progress);
            if (progress <= 0.0) {
                0.0;
            }
            else if (progress >= 1.0) {
                1.0;
            }
            else {
                config.step(initialState, 1.0, f32(progress * durationSeconds)).position;
            }
        });

    }

    @:allow(glaze.SpringConfig)
    static function envelopeDecayStart(constant:Float, linear:Float, decay:Float):Float {

        if (linear == 0.0) {
            return 0.0;
        }
        else {
            return MathUtil.max(f32(f32(1.0 / decay) - f32(constant / linear)), 0.0);
        }

    }

    @:allow(glaze.SpringConfig)
    static inline function envelopeBelow(position:Float, velocity:Float, positionThreshold:Float, velocityThreshold:Float):Bool {

        return position <= positionThreshold && velocity <= velocityThreshold;

    }

    /**
     * Rust's `find_settle_time`. The envelope comparison against the position and
     * velocity thresholds is done by `isBelowThreshold` (built by the caller with
     * `envelopeBelow`), which avoids returning a tuple per evaluation.
     */
    @:allow(glaze.SpringConfig)
    static function findSettleTime(decayStart:Float, naturalFrequency:Float, isBelowThreshold:(Float) -> Bool):Float {

        if (isBelowThreshold(decayStart)) {
            return durationFromSecs(decayStart);
        }

        var lowerBound = decayStart;
        var upperBound = MathUtil.max(decayStart, f32(1.0 / naturalFrequency));
        while (!isBelowThreshold(upperBound)) {
            lowerBound = upperBound;
            upperBound = f32(upperBound * 2.0);
            if (!Math.isFinite(upperBound)) {
                return DURATION_MAX;
            }
        }

        for (_ in 0...32) {
            final midpoint = f32(f32(lowerBound + upperBound) / 2.0);
            if (isBelowThreshold(midpoint)) {
                upperBound = midpoint;
            }
            else {
                lowerBound = midpoint;
            }
        }

        return durationFromSecs(upperBound);

    }

    /**
     * `Duration::as_secs_f32`: `(secs as f32) + (nanos as f32) / 1e9`.
     */
    public static function durationAsSecsF32(duration:Float):Float {

        final secs = Math.ffloor(duration);
        final nanos = Math.fround((duration - secs) * 1e9);
        return f32(f32(secs) + f32(f32(nanos) / 1e9));

    }

    /**
     * Converts seconds to a duration like GPUI's `duration_from_secs`:
     * `DURATION_MAX` when not finite or too large, zero when not positive,
     * otherwise rounded to the nearest nanosecond.
     */
    public static function durationFromSecs(seconds:Float):Float {

        // DURATION_MAX is also `Duration::MAX.as_secs_f32()`
        if (!Math.isFinite(seconds) || seconds >= DURATION_MAX) {
            return DURATION_MAX;
        }
        else if (seconds <= 0.0) {
            return 0.0;
        }
        else {
            return Math.ffloor(seconds * 1e9 + 0.5) / 1e9;
        }

    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/motion/timing.rs (SignedDuration)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

/**
 * A delay that may be negative, as CSS allows: a negative delay starts a
 * motion that far inside its active interval. Durations are in seconds.
 */
@:using(gpui.base.motion.SignedDuration.SignedDurationTools)
enum SignedDuration {
    Positive(seconds:Float);
    Negative(seconds:Float);
}

class SignedDurationTools {

    /**
     * Rust's `SignedDuration::ZERO`, also the default.
     */
    public static final ZERO:SignedDuration = Positive(0.0);

    public static inline function positive(seconds:Float):SignedDuration {
        return Positive(seconds);
    }

    public static inline function negative(seconds:Float):SignedDuration {
        return Negative(seconds);
    }

    /**
     * The time spent in the active interval after `elapsedNanos`, in whole
     * nanoseconds, or `-1` while a positive delay has not elapsed (Rust `None`).
     */
    @:allow(gpui.base.motion)
    static function activeElapsedNanos(delay:SignedDuration, elapsedNanos:Float):Float {
        return switch delay {
            case Positive(seconds):
                final delayNanos = MotionTime.nanos(seconds);
                elapsedNanos >= delayNanos ? elapsedNanos - delayNanos : -1.0;
            case Negative(seconds):
                elapsedNanos + MotionTime.nanos(seconds);
        }
    }

}

/**
 * Accepts a `SignedDuration` or a `Float` of seconds (a positive delay),
 * like Rust's `impl Into<SignedDuration>`.
 */
abstract IntoSignedDuration(SignedDuration) from SignedDuration to SignedDuration {

    @:from static inline function fromSeconds(seconds:Float):IntoSignedDuration {
        return cast SignedDuration.Positive(seconds);
    }

}

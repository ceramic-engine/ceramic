// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (the `Duration` and `Instant` arithmetic of motion)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.motion;

import glaze.SpringMath.f32;

/**
 * Duration helpers shared by the motion types.
 *
 * The public motion API takes durations and instants as `Float` seconds (Rust
 * `Duration` / `Instant`). Rust compares and subtracts them as whole
 * nanoseconds, so a step that ends exactly at a frame reports `Finished` on
 * that frame. Summing seconds in `Float` would sometimes land a nanosecond
 * short (`0.12 - 0.02 < 0.1`), so motion converts seconds to whole
 * nanoseconds (stored in a `Float`, exact up to about 104 days) before any
 * arithmetic, and back with `seconds()`.
 */
class MotionTime {

    /**
     * Converts seconds to whole nanoseconds, rounded to the nearest.
     * Negative values saturate to zero, like a `Duration`.
     */
    public static inline function nanos(seconds:Float):Float {

        return seconds <= 0 ? 0.0 : Math.ffloor(seconds * 1e9 + 0.5);

    }

    /**
     * Converts whole nanoseconds back to seconds.
     */
    public static inline function seconds(nanos:Float):Float {

        return nanos / 1e9;

    }

    /**
     * Rust's `Duration::as_secs_f32()`: `secs as f32 + nanos as f32 / 1e9`, in `f32`.
     */
    public static function asSecsF32(nanos:Float):Float {

        final secs = Math.ffloor(nanos / 1e9);
        final subsec = nanos - secs * 1e9;
        return f32(f32(secs) + f32(f32(subsec) / 1e9));

    }

    /**
     * Rust's `Duration::mul_f64()`, rounded to the nearest nanosecond.
     */
    public static inline function mulF64(nanos:Float, factor:Float):Float {

        final product = nanos * factor;
        return product <= 0 ? 0.0 : Math.ffloor(product + 0.5);

    }

}

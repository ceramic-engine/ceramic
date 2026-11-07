// Ported from gpui-pre 0.3.10: src/elements/animation.rs (mod easing)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

import glaze.SpringMath.*;

/**
 * Easing functions, mapping a normalized time to an animated value.
 *
 * Like GPUI, they compute in `f32` (emulated with `SpringMath`, in the same
 * operation order as the Rust code). Checked against values dumped from GPUI
 * in `AnimationTest`.
 */
class Easing {

    /**
     * `std::f32::consts::PI`.
     */
    static final PI_F32:Float = f32(Math.PI);

    /**
     * The linear easing function, or delta itself.
     */
    public static function linear(delta:Float):Float {

        return delta;

    }

    /**
     * The quadratic easing function, delta * delta.
     */
    public static function quadratic(delta:Float):Float {

        return f32(f32(delta) * f32(delta));

    }

    /**
     * The quadratic ease-in-out function, which starts and ends slowly but speeds up in the middle.
     */
    public static function easeInOut(delta:Float):Float {

        final delta = f32(delta);
        if (delta < 0.5) {
            return f32(f32(2.0 * delta) * delta);
        }
        else {
            final x = f32(f32(-2.0 * delta) + 2.0);
            return f32(1.0 - f32(f32(x * x) / 2.0));
        }

    }

    /**
     * The Quint ease-out function, which starts quickly and decelerates to a stop.
     */
    public static function easeOutQuint():(Float) -> Float {

        return easeOutQuintValue;

    }

    static function easeOutQuintValue(delta:Float):Float {

        final x = f32(1.0 - f32(delta));
        // Rust: (1.0 - delta).powi(5), computed by LLVM (and compiler-rt's
        // __powisf2) by repeated squaring: x * ((x * x) * (x * x))
        final x2 = f32(x * x);
        return f32(1.0 - f32(x * f32(x2 * x2)));

    }

    /**
     * Apply the given easing function, first in the forward direction and then in the reverse direction.
     */
    public static function bounce(easing:(Float) -> Float):(Float) -> Float {

        return delta -> {
            final delta = f32(delta);
            if (delta < 0.5) {
                easing(f32(delta * 2.0));
            }
            else {
                easing(f32(f32(1.0 - delta) * 2.0));
            }
        };

    }

    /**
     * A custom easing function for pulsating alpha that slows down as it approaches 0.1.
     */
    public static function pulsatingBetween(min:Float, max:Float):(Float) -> Float {

        final min = f32(min);
        final range = f32(f32(max) - min);

        return delta -> {
            // Use a combination of sine and cubic functions for a more natural breathing rhythm
            final t = sinF32(f32(f32(f32(delta) * 2.0) * PI_F32));
            final breath = f32(f32(f32(f32(t * t) * t) + t) / 2.0);

            // Map the breath to our desired alpha range
            final normalizedAlpha = f32(f32(breath + 1.0) / 2.0);

            f32(min + f32(normalizedAlpha * range));
        };

    }

}

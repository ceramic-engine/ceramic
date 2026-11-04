// Ported from gpui-kit 0.8.1: crates/base/src/animation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.animation;

import gpui.SpringMath.f32;
import gpui.util.MathUtil;

/**
 * Easing helpers of gpui-base: a CSS-like `cubic-bezier` and cubic presets.
 *
 * Like the Rust code, everything computes in `f32` (emulated with
 * `SpringMath.f32`, in the same operation order).
 */
class Easings {

    static final SOLVE_EPSILON:Float = f32(1e-6);

    /**
     * A cubic bezier function like CSS `cubic-bezier`. Builder:
     * https://cubic-bezier.com
     *
     * The output is clamped to `[0, 1]`, as `Animation.withEasing` callers
     * expect: solver and rounding errors are clamped away.
     */
    public static function cubicBezier(x1:Float, y1:Float, x2:Float, y2:Float):(Float) -> Float {

        final x1 = f32(x1);
        final y1 = f32(y1);
        final x2 = f32(x2);
        final y2 = f32(y2);
        return t -> MathUtil.clamp(sampleCubicBezier(x1, y1, x2, y2, t), 0.0, 1.0);

    }

    /**
     * `cubicBezier` without the output clamp, so y control points outside
     * `0..=1` keep their anticipation and overshoot. Input progress stays clamped.
     */
    public static function unclampedCubicBezier(x1:Float, y1:Float, x2:Float, y2:Float):(Float) -> Float {

        final x1 = f32(x1);
        final y1 = f32(y1);
        final x2 = f32(x2);
        final y2 = f32(y2);
        return t -> sampleCubicBezier(x1, y1, x2, y2, t);

    }

    /**
     * Samples the unclamped cubic bezier at `t` without building a closure
     * (used by `gpui.base.motion.Easing`). Control points must already be `f32`.
     */
    public static function sampleCubicBezier(x1:Float, y1:Float, x2:Float, y2:Float, t:Float):Float {

        // Polynomial form of the unit bezier, where p0 = (0, 0) and p3 = (1, 1).
        final cx = f32(3.0 * x1);
        final cy = f32(3.0 * y1);
        final bx = f32(f32(3.0 * f32(x2 - x1)) - cx);
        final by = f32(f32(3.0 * f32(y2 - y1)) - cy);
        final ax = f32(f32(1.0 - cx) - bx);
        final ay = f32(f32(1.0 - cy) - by);

        // `t` is elapsed progress along x, not the curve parameter: solve
        // `x(s) = t` before sampling y, otherwise the curve reads much slower
        // than the same control points do in CSS.
        final t = MathUtil.clamp(f32(t), 0.0, 1.0);
        return samplePolynomial(ay, by, cy, solveS(ax, bx, cx, t));

    }

    static inline function samplePolynomial(a:Float, b:Float, c:Float, t:Float):Float {

        return f32(f32(f32(f32(f32(a * t) + b) * t) + c) * t);

    }

    static inline function slopePolynomial(a:Float, b:Float, c:Float, t:Float):Float {

        return f32(f32(f32(f32(f32(3.0 * a) * t) + f32(2.0 * b)) * t) + c);

    }

    /**
     * Solves `x(s) = t` for the curve parameter `s`: Newton first, then bisection.
     */
    static function solveS(ax:Float, bx:Float, cx:Float, t:Float):Float {

        var s = t;
        for (_ in 0...8) {
            final error = f32(samplePolynomial(ax, bx, cx, s) - t);
            if (Math.abs(error) < SOLVE_EPSILON) {
                return s;
            }
            final slope = slopePolynomial(ax, bx, cx, s);
            if (Math.abs(slope) < SOLVE_EPSILON) {
                break;
            }
            s = MathUtil.clamp(f32(s - f32(error / slope)), 0.0, 1.0);
        }

        var low = 0.0;
        var high = 1.0;
        var s = t;
        for (_ in 0...32) {
            final x = samplePolynomial(ax, bx, cx, s);
            if (Math.abs(f32(x - t)) < SOLVE_EPSILON) {
                break;
            }
            if (x < t) {
                low = s;
            }
            else {
                high = s;
            }
            s = f32(f32(low + high) / 2.0);
        }
        return s;

    }

    // Easing presets

    /**
     * Cubic ease-out: fast start, slow end. Good for enter animations.
     */
    public static function easeOutCubic(t:Float):Float {

        final t = MathUtil.clamp(f32(t), 0.0, 1.0);
        final x = f32(1.0 - t);
        return f32(1.0 - f32(f32(x * x) * x));

    }

    /**
     * Cubic ease-in: slow start, fast end. Good for exit animations.
     */
    public static function easeInCubic(t:Float):Float {

        final t = MathUtil.clamp(f32(t), 0.0, 1.0);
        return f32(f32(t * t) * t);

    }

    /**
     * Cubic ease-in-out: slow start and end. Good for position transitions.
     */
    public static function easeInOutCubic(t:Float):Float {

        final t = MathUtil.clamp(f32(t), 0.0, 1.0);
        if (t < 0.5) {
            return f32(f32(f32(4.0 * t) * t) * t);
        }
        else {
            final x = f32(f32(-2.0 * t) + 2.0);
            return f32(1.0 - f32(f32(f32(x * x) * x) / 2.0));
        }

    }

}

package gpui;

/**
 * Single precision (`f32`) emulation for the spring and interpolation math.
 *
 * GPUI computes springs in `f32`. Some of its formulas cancel large terms
 * (`target + m00 * displacement + ...` near the target, `slow_root - fast_root`
 * near critical damping), and the results then depend on `f32` rounding: in f64
 * they differ from GPUI by up to 2e-5, and the bisection of `settle_time` can
 * land on the other side of the tolerance (the ported test
 * `settle_time_is_conservative_for_every_damping_regime` fails in plain f64).
 *
 * So the port rounds every operation to `f32`, in the same order as the Rust
 * code: `+ - * / sqrt` computed in f64 then rounded give the exact `f32`
 * result, and the transcendental functions (`exp`, `sin`, `cos`, `hypot`) give
 * the correctly rounded `f32` value, which matches the platform `libm` `f32`
 * functions used by Rust in all the reference samples.
 *
 * This helper only exists for the animation code; it could move to
 * `gpui.util.MathUtil` if other modules need it.
 */
class SpringMath {

    /**
     * Rounds a value to the nearest `f32` (overflowing to infinity like an `f32`).
     */
    #if (cpp || cs || hl || js) inline #end
    public static function f32(value:Float):Float {

        #if js
        return js.Syntax.code('Math.fround({0})', value);
        #elseif cpp
        return untyped __cpp__('((double)(float)({0}))', value);
        #elseif cs
        return untyped __cs__('((double)(float)({0}))', value);
        #elseif hl
        final single:hl.F32 = value;
        return single;
        #else
        return haxe.io.FPHelper.i32ToFloat(haxe.io.FPHelper.floatToI32(value));
        #end

    }

    public static inline function expF32(value:Float):Float {

        return f32(Math.exp(value));

    }

    public static inline function sinF32(value:Float):Float {

        return f32(Math.sin(value));

    }

    public static inline function cosF32(value:Float):Float {

        return f32(Math.cos(value));

    }

    public static inline function sqrtF32(value:Float):Float {

        return f32(Math.sqrt(value));

    }

    /**
     * Rust's `f32::hypot`.
     */
    public static inline function hypotF32(x:Float, y:Float):Float {

        return f32(Math.sqrt(x * x + y * y));

    }

    /**
     * Rust's `f32::rem_euclid`.
     */
    public static inline function remEuclidF32(a:Float, b:Float):Float {

        // The f64 remainder of two f32 values is exact, hence already an f32
        final r = a % b;
        return r < 0.0 ? f32(r + Math.abs(b)) : r;

    }

    /**
     * `Interpolate for f32`: `from + (to - from) * phase` in `f32`.
     */
    public static inline function lerpF32(from:Float, to:Float, phase:Float):Float {

        return f32(from + f32(f32(to - from) * phase));

    }

}

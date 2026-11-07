// Ported from gpui-pre 0.3.10: src/spring.rs (AnimationPhase, Interpolate)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.SpringMath.*;
import gpui.util.MathUtil;

/**
 * A potentially overshooting coordinate within an animation.
 *
 * Phases are not restricted to 0..1. Multi-stage animations can assign each
 * stage its own coordinate and interpolate over ranges such as 1..=2.
 *
 * Rust's `Interpolate` trait (implemented for `f32`, `Pixels`, `Rems`, `Rgba`
 * and `Hsla`) becomes overloads of the `interpolate*` methods: `Float` covers
 * `Pixels` and `Rems`. The static `lerp` functions are the trait implementations.
 * Rust's `RangeInclusive<f32>` arguments become `start` and `end`.
 *
 * The interpolations are computed in `f32` like GPUI (see `SpringMath`): this
 * matters for `Hsla`, whose hue wraps to exactly 0 where f64 would give 0.99999999.
 */
abstract AnimationPhase(Float) from Float to Float {

    public inline function new(value:Float) {

        this = value;

    }

    /**
     * The unbounded phase coordinate (the tuple field `.0` in Rust).
     */
    public var value(get, never):Float;

    inline function get_value():Float {

        return this;

    }

    /**
     * `From<bool>`: 1 for `true`, 0 for `false`.
     */
    public static inline function fromBool(value:Bool):AnimationPhase {

        return new AnimationPhase(value ? 1.0 : 0.0);

    }

    /**
     * Restricts this phase to the bounds of a range.
     */
    public inline function clamp(start:Float, end:Float):AnimationPhase {

        final start = f32(start);
        final end = f32(end);
        return new AnimationPhase(MathUtil.clamp(f32(this), MathUtil.min(start, end), MathUtil.max(start, end)));

    }

    /**
     * Interpolates between values using 0 and 1 as their phase coordinates.
     */
    public overload extern inline function interpolate(from:Float, to:Float):Float {

        return lerp(from, to, this);

    }

    public overload extern inline function interpolate(from:Rgba, to:Rgba):Rgba {

        return lerpRgba(from, to, this);

    }

    public overload extern inline function interpolate(from:Hsla, to:Hsla):Hsla {

        return lerpHsla(from, to, this);

    }

    /**
     * Interpolates between values without extrapolating beyond 0 and 1.
     */
    public overload extern inline function interpolateClamped(from:Float, to:Float):Float {

        return lerp(from, to, MathUtil.clamp(this, 0.0, 1.0));

    }

    public overload extern inline function interpolateClamped(from:Rgba, to:Rgba):Rgba {

        return lerpRgba(from, to, MathUtil.clamp(this, 0.0, 1.0));

    }

    public overload extern inline function interpolateClamped(from:Hsla, to:Hsla):Hsla {

        return lerpHsla(from, to, MathUtil.clamp(this, 0.0, 1.0));

    }

    /**
     * Interpolates between values assigned to arbitrary phase coordinates.
     */
    public overload extern inline function interpolateBetween(start:Float, end:Float, from:Float, to:Float):Float {

        return lerp(from, to, phaseBetween(this, start, end));

    }

    public overload extern inline function interpolateBetween(start:Float, end:Float, from:Rgba, to:Rgba):Rgba {

        return lerpRgba(from, to, phaseBetween(this, start, end));

    }

    public overload extern inline function interpolateBetween(start:Float, end:Float, from:Hsla, to:Hsla):Hsla {

        return lerpHsla(from, to, phaseBetween(this, start, end));

    }

    /**
     * Interpolates over arbitrary phase coordinates without extrapolating.
     */
    public overload extern inline function interpolateBetweenClamped(start:Float, end:Float, from:Float, to:Float):Float {

        return lerp(from, to, phaseBetweenClamped(this, start, end));

    }

    public overload extern inline function interpolateBetweenClamped(start:Float, end:Float, from:Rgba, to:Rgba):Rgba {

        return lerpRgba(from, to, phaseBetweenClamped(this, start, end));

    }

    public overload extern inline function interpolateBetweenClamped(start:Float, end:Float, from:Hsla, to:Hsla):Hsla {

        return lerpHsla(from, to, phaseBetweenClamped(this, start, end));

    }

    static function phaseBetween(phase:Float, start:Float, end:Float):Float {

        final phase = f32(phase);
        final start = f32(start);
        final end = f32(end);
        if (start == end) {
            return phase < start ? 0.0 : 1.0;
        }
        return f32(f32(phase - start) / f32(end - start));

    }

    static function phaseBetweenClamped(phase:Float, start:Float, end:Float):Float {

        return MathUtil.clamp(phaseBetween(phase, start, end), 0.0, 1.0);

    }

    /**
     * `Interpolate for f32` (also `Pixels` and `Rems`): resolves the value at `phase`,
     * where 0 is `from` and 1 is `to`.
     */
    public static inline function lerp(from:Float, to:Float, phase:Float):Float {

        return lerpF32(f32(from), f32(to), f32(phase));

    }

    /**
     * `Interpolate for Rgba`: component-wise.
     */
    public static function lerpRgba(from:Rgba, to:Rgba, phase:Float):Rgba {

        return new Rgba(
            lerp(from.r, to.r, phase),
            lerp(from.g, to.g, phase),
            lerp(from.b, to.b, phase),
            lerp(from.a, to.a, phase)
        );

    }

    /**
     * `Interpolate for Hsla`: takes the shortest path around the hue circle.
     */
    public static function lerpHsla(from:Hsla, to:Hsla, phase:Float):Hsla {

        final phase = f32(phase);
        final fromH = f32(from.h);
        final hueDelta = f32(remEuclidF32(f32(f32(f32(to.h) - fromH) + 0.5), 1.0) - 0.5);
        return new Hsla(
            remEuclidF32(f32(fromH + f32(hueDelta * phase)), 1.0),
            lerp(from.s, to.s, phase),
            lerp(from.l, to.l, phase),
            lerp(from.a, to.a, phase)
        );

    }

}

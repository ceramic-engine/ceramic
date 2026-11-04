// Ported from gpui-kit 0.8.1: crates/base/src/motion/easing.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

import gpui.SpringMath.f32;
import gpui.base.animation.Easings;
import gpui.util.MathUtil;

/**
 * The point at which a stepped easing jumps.
 */
enum abstract StepPosition(Int) {
    var JumpStart = 0;
    var JumpEnd = 1;
    var JumpNone = 2;
    var JumpBoth = 3;
}

/**
 * One output and its optional input position in a CSS-like `linear()` curve.
 */
class LinearStop {

    public final output:Float;

    public final input:Null<Float>;

    /**
     * A stop whose input position is filled in from its neighbours.
     */
    public inline function new(output:Float, ?input:Float) {
        this.output = output;
        this.input = input;
    }

    /**
     * A stop at an explicit input position.
     */
    public static inline function at(output:Float, input:Float):LinearStop {
        return new LinearStop(output, input);
    }

}

/**
 * Invalid easing configuration, thrown by the `Easing` factories (Rust `Result`).
 */
@:using(gpui.base.motion.Easing.EasingErrorTools)
enum EasingError {
    /**
     * Retained for source compatibility. New validation reports
     * `InvalidBezierControlPoint`.
     */
    InvalidBezierX;
    InvalidBezierControlPoint;
    InvalidStepCount;
    InvalidLinearStops;
}

class EasingErrorTools {

    /**
     * The error message (Rust `Display`).
     */
    public static function message(error:EasingError):String {
        return switch error {
            case InvalidBezierX | InvalidBezierControlPoint:
                'cubic Bézier control points must be finite and x must be within 0..=1';
            case InvalidStepCount:
                'step easing requires a valid step count';
            case InvalidLinearStops:
                'linear easing stops are invalid';
        }
    }

}

/**
 * The variants of `Easing` (Rust enum `Easing`). Match on `easing.kind()`.
 */
enum EasingKind {
    Linear;
    Ease;
    EaseIn;
    EaseOut;
    EaseInOut;
    CubicBezier(x1:Float, y1:Float, x2:Float, y2:Float);
    Steps(count:Int, position:StepPosition);
    /** Stop inputs and outputs, of the same length. */
    LinearStops(inputs:Array<Float>, outputs:Array<Float>);
    Custom(easing:(Float) -> Float);
}

/**
 * A cheap, shareable CSS-compatible easing policy.
 *
 * An abstract over `EasingKind`, so that the validating factories
 * (`cubicBezier`, `steps`, `linearStops`) live next to the variants as in
 * Rust: `Easing.Linear`, `Easing.EaseOut`, `Easing.steps(4, JumpEnd)`,
 * `Easing.custom(t -> t)`. The factories throw an `EasingError` where Rust
 * returns `Err`. The default (`defaultValue()`) is `EaseOut`.
 */
abstract Easing(EasingKind) from EasingKind to EasingKind {

    public static final Linear:Easing = EasingKind.Linear;

    public static final Ease:Easing = EasingKind.Ease;

    public static final EaseIn:Easing = EasingKind.EaseIn;

    public static final EaseOut:Easing = EasingKind.EaseOut;

    public static final EaseInOut:Easing = EasingKind.EaseInOut;

    public static inline function defaultValue():Easing {
        return EaseOut;
    }

    /**
     * The variant, to pattern match on.
     */
    public inline function kind():EasingKind {
        return this;
    }

    /**
     * A custom curve (Rust `Easing::Custom`).
     */
    public static inline function custom(easing:(Float) -> Float):Easing {
        return EasingKind.Custom(easing);
    }

    /**
     * A CSS `cubic-bezier()`. Throws `InvalidBezierControlPoint` unless every
     * control point is finite and both x are within `0..=1`.
     */
    public static function cubicBezier(x1:Float, y1:Float, x2:Float, y2:Float):Easing {
        if (!Math.isFinite(x1) || !Math.isFinite(x2) || !(x1 >= 0.0 && x1 <= 1.0) || !(x2 >= 0.0 && x2 <= 1.0) || !Math.isFinite(y1) || !Math.isFinite(y2)) {
            throw EasingError.InvalidBezierControlPoint;
        }
        return EasingKind.CubicBezier(f32(x1), f32(y1), f32(x2), f32(y2));
    }

    /**
     * A CSS `steps()`. Throws `InvalidStepCount` for zero steps, or a single
     * step with `JumpNone`.
     */
    public static function steps(count:Int, position:StepPosition):Easing {
        if (count <= 0) {
            throw EasingError.InvalidStepCount;
        }
        if (position == JumpNone && count == 1) {
            throw EasingError.InvalidStepCount;
        }
        return EasingKind.Steps(count, position);
    }

    /**
     * A CSS `linear()` curve. Omitted inputs are spread evenly between their
     * neighbours; the first and last default to 0 and 1. Throws
     * `InvalidLinearStops` for fewer than two stops, non-finite values, inputs
     * outside `0..=1` or decreasing inputs.
     */
    public static function linearStops(stops:Array<LinearStop>):Easing {
        if (stops.length < 2) {
            throw EasingError.InvalidLinearStops;
        }
        for (stop in stops) {
            if (!Math.isFinite(stop.output) || (stop.input != null && !Math.isFinite(stop.input))) {
                throw EasingError.InvalidLinearStops;
            }
        }

        final count = stops.length;
        final inputs:Array<Null<Float>> = [for (stop in stops) stop.input];
        final outputs:Array<Float> = [for (stop in stops) f32(stop.output)];
        if (inputs[0] == null) {
            inputs[0] = 0.0;
        }
        final last = count - 1;
        if (inputs[last] == null) {
            inputs[last] = 1.0;
        }

        var anchor = 0;
        while (anchor < last) {
            var next = anchor + 1;
            while (next <= last && inputs[next] == null) {
                next++;
            }
            if (next > last) {
                throw EasingError.InvalidLinearStops;
            }
            final from:Float = f32(inputs[anchor]);
            final to:Float = f32(inputs[next]);
            if (!(from >= 0.0 && from <= 1.0) || !(to >= 0.0 && to <= 1.0) || to < from) {
                throw EasingError.InvalidLinearStops;
            }
            final span:Float = next - anchor;
            for (offset in 0...(next - anchor - 1)) {
                inputs[anchor + 1 + offset] = f32(from + f32(f32(f32(to - from) * (offset + 1)) / span));
            }
            anchor = next;
        }

        return EasingKind.LinearStops([for (input in inputs) f32(input)], outputs);
    }

    /**
     * Map elapsed `progress`, clamped to `0..=1`, through the curve.
     *
     * The output may leave `0..=1`: a cubic Bézier with y control points
     * outside that range anticipates or overshoots, and linear stops or a
     * custom curve may do the same. Clamp the result where it drives an
     * opacity or a color.
     */
    public function sample(progress:Float):Float {
        final progress = MathUtil.clamp(f32(progress), 0.0, 1.0);
        return switch this {
            case EasingKind.Linear: progress;
            case EasingKind.Ease: clamped(0.25, 0.1, 0.25, 1.0, progress);
            case EasingKind.EaseIn: clamped(0.42, 0.0, 1.0, 1.0, progress);
            case EasingKind.EaseOut: clamped(0.0, 0.0, 0.58, 1.0, progress);
            case EasingKind.EaseInOut: clamped(0.42, 0.0, 0.58, 1.0, progress);
            case EasingKind.CubicBezier(x1, y1, x2, y2):
                Easings.sampleCubicBezier(x1, y1, x2, y2, progress);
            case EasingKind.Steps(count, position):
                final count:Float = count;
                var jumps = count;
                var offset = 0.0;
                switch position {
                    case JumpStart:
                        offset = 1.0;
                    case JumpEnd:
                    case JumpNone:
                        jumps = count - 1.0;
                    case JumpBoth:
                        jumps = count + 1.0;
                        offset = 1.0;
                }
                f32(MathUtil.clamp(Math.ffloor(f32(progress * count)) + offset, 0.0, jumps) / jumps);
            case EasingKind.LinearStops(inputs, outputs):
                // partition_point: the first input above progress
                var upper = 0;
                while (upper < inputs.length && inputs[upper] <= progress) {
                    upper++;
                }
                if (upper == 0) {
                    outputs[0];
                }
                else if (upper == inputs.length) {
                    outputs[outputs.length - 1];
                }
                else {
                    final x0 = inputs[upper - 1];
                    final y0 = outputs[upper - 1];
                    final x1 = inputs[upper];
                    final y1 = outputs[upper];
                    if (x0 == x1) {
                        y1;
                    }
                    else {
                        f32(y0 + f32(f32(y1 - y0) * f32(f32(progress - x0) / f32(x1 - x0))));
                    }
                }
            case EasingKind.Custom(easing): easing(progress);
        }
    }

    static inline function clamped(x1:Float, y1:Float, x2:Float, y2:Float, progress:Float):Float {
        return MathUtil.clamp(Easings.sampleCubicBezier(f32(x1), f32(y1), f32(x2), f32(y2), progress), 0.0, 1.0);
    }

    public function toString():String {
        return switch this {
            case EasingKind.Custom(_): 'Custom(..)';
            case other: Std.string(other);
        }
    }

}

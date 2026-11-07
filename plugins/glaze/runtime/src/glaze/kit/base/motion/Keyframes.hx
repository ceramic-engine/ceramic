// Ported from gpui-kit 0.8.1: crates/base/src/motion/keyframes.rs (Keyframe, KeyframeError, Keyframes)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.motion;

import glaze.SpringMath.f32;
import glaze.util.MathUtil;

/**
 * One value of a `Keyframes` track at an `offset` in `0..=1`, with the easing
 * of the segment that starts at it (linear by default).
 */
class Keyframe<T> {

    public var offset:Float;

    public var value:T;

    public var easing:Easing;

    public function new(offset:Float, value:T) {
        this.offset = offset;
        this.value = value;
        this.easing = Easing.Linear;
    }

    /**
     * Sets the easing of the segment starting at this keyframe.
     */
    public function ease(easing:Easing):Keyframe<T> {
        this.easing = easing;
        return this;
    }

}

/**
 * Why a keyframe track was rejected.
 */
enum KeyframeError {
    TooFewFrames;
    OffsetNotFinite;
    OffsetOutOfRange;
    OffsetsNotMonotonic;
    MissingEndpoint;
}

/**
 * A validated keyframe track: at least two frames, offsets within `0..=1`,
 * non-decreasing, starting at 0 and ending at 1.
 *
 * Values are interpolated with the `Interpolator` given at construction
 * (Rust `T: Interpolate`).
 */
class Keyframes<T> {

    final frames:Array<Keyframe<T>>;

    final interpolator:Interpolator<T>;

    function new(frames:Array<Keyframe<T>>, interpolator:Interpolator<T>) {
        this.frames = frames;
        this.interpolator = interpolator;
    }

    /**
     * Validates and builds a track. Throws a `KeyframeError` (Rust `Err`).
     */
    public static function tryNew<T>(frames:Array<Keyframe<T>>, interpolator:Interpolator<T>):Keyframes<T> {
        if (frames.length < 2) {
            throw KeyframeError.TooFewFrames;
        }
        for (frame in frames) {
            if (!Math.isFinite(frame.offset)) {
                throw KeyframeError.OffsetNotFinite;
            }
        }
        for (frame in frames) {
            if (!(frame.offset >= 0.0 && frame.offset <= 1.0)) {
                throw KeyframeError.OffsetOutOfRange;
            }
        }
        for (i in 1...frames.length) {
            if (frames[i - 1].offset > frames[i].offset) {
                throw KeyframeError.OffsetsNotMonotonic;
            }
        }
        if (frames[0].offset != 0.0 || frames[frames.length - 1].offset != 1.0) {
            throw KeyframeError.MissingEndpoint;
        }
        return new Keyframes(frames.copy(), interpolator);
    }

    /**
     * A `Float` track (`Interpolators.FLOAT`).
     */
    public static function tryNewFloat(frames:Array<Keyframe<Float>>):Keyframes<Float> {
        return tryNew(frames, Interpolators.FLOAT);
    }

    /**
     * The value at `progress`, clamped to `0..=1`.
     */
    public function sample(progress:Float):T {
        final progress = MathUtil.clamp(f32(progress), 0.0, 1.0);
        // partition_point: the first frame above progress
        var upper = 0;
        while (upper < frames.length && frames[upper].offset <= progress) {
            upper++;
        }
        if (upper == 0) {
            return frames[0].value;
        }
        if (upper == frames.length) {
            return frames[frames.length - 1].value;
        }
        final from = frames[upper - 1];
        final to = frames[upper];
        if (from.offset == to.offset) {
            return to.value;
        }
        final segment = f32(f32(progress - f32(from.offset)) / f32(f32(to.offset) - f32(from.offset)));
        return interpolator.interpolate(from.value, to.value, from.easing.sample(segment));
    }

    public inline function len():Int {
        return frames.length;
    }

    public inline function isEmpty():Bool {
        return frames.length == 0;
    }

}

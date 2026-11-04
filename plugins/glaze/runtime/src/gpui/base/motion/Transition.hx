// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (Transition)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

import gpui.SpringMath.f32;
import gpui.base.motion.SignedDuration.IntoSignedDuration;
import gpui.base.motion.SignedDuration.SignedDurationTools;
import gpui.base.animation.Easings;

/**
 * CSS-like timing policy for a target-value transition.
 *
 * This type is intentionally separate from
 * `gpui.base.animation.EffectTransition`, which applies concrete fade, slide,
 * and size effects to an element. A value transition never chooses a visual
 * property for the caller.
 *
 * Durations are in seconds (Rust `Duration`). Immutable: the builders return
 * a modified copy, as Rust's builders consume a cloned value.
 */
class Transition {

    /**
     * The duration, in whole nanoseconds (see `MotionTime`).
     */
    @:allow(gpui.base)
    var durationNanos(default, null):Float;

    var delayValue:SignedDuration;

    var easingValue:Easing;

    public function new(duration:Float) {
        this.durationNanos = MotionTime.nanos(duration);
        this.delayValue = Positive(0.0);
        this.easingValue = Easing.custom(Easings.easeOutCubic);
    }

    /**
     * The duration, in seconds.
     */
    public inline function duration():Float {
        return MotionTime.seconds(durationNanos);
    }

    public function delay(delay:IntoSignedDuration):Transition {
        return new Transition(0).init(durationNanos, delay, easingValue);
    }

    public function ease(easing:(Float) -> Float):Transition {
        return new Transition(0).init(durationNanos, delayValue, Easing.custom(easing));
    }

    public function easing(easing:Easing):Transition {
        return new Transition(0).init(durationNanos, delayValue, easing);
    }

    function init(durationNanos:Float, delay:SignedDuration, easing:Easing):Transition {
        this.durationNanos = durationNanos;
        this.delayValue = delay;
        this.easingValue = easing;
        return this;
    }

    @:allow(gpui.base)
    inline function sample(progress:Float):Float {
        return easingValue.sample(progress);
    }

    /**
     * The easing curve, for a caller that samples one timeline at several
     * offsets, such as a staggered plot appear.
     */
    public inline function curve():Easing {
        return easingValue;
    }

    /**
     * The progress after `elapsedNanos` over `durationNanos` (Rust returns it
     * with the status; see `progressStatus`).
     */
    @:allow(gpui.base)
    function progressValue(elapsedNanos:Float, durationNanos:Float):Float {
        final activeElapsed = SignedDurationTools.activeElapsedNanos(delayValue, elapsedNanos);
        if (activeElapsed < 0) {
            return 0.0;
        }
        if (durationNanos == 0 || activeElapsed >= durationNanos) {
            return 1.0;
        }
        return f32(MotionTime.asSecsF32(activeElapsed) / MotionTime.asSecsF32(durationNanos));
    }

    /**
     * The status after `elapsedNanos` over `durationNanos`.
     */
    @:allow(gpui.base)
    function progressStatus(elapsedNanos:Float, durationNanos:Float):MotionStatus {
        final activeElapsed = SignedDurationTools.activeElapsedNanos(delayValue, elapsedNanos);
        if (activeElapsed < 0) {
            return Delayed;
        }
        if (durationNanos == 0 || activeElapsed >= durationNanos) {
            return Finished;
        }
        return Running;
    }

    /**
     * The elapsed time (nanoseconds) at which the progress over the
     * transition's own duration first reports `Finished`.
     */
    @:allow(gpui.base)
    function finishesAfterNanos():Float {
        return switch delayValue {
            case Positive(delay): MotionTime.nanos(delay) + durationNanos;
            case Negative(delay):
                final remaining = durationNanos - MotionTime.nanos(delay);
                remaining > 0 ? remaining : 0.0;
        }
    }

}

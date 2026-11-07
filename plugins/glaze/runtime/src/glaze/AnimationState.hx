// Ported from gpui-pre 0.3.10: src/elements/animation.rs (AnimationState, AnimationElement::request_layout)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

import glaze.SpringMath.f32;

/**
 * The element state of an `AnimationElement`, kept across frames under the
 * element id, plus the time-based part of `AnimationElement::request_layout`
 * as a pure function of the clock (`advance()`).
 *
 * Times are in seconds, read from `cx.backgroundExecutor().now()` so that
 * tests can drive them with the `TestDispatcher` clock.
 */
class AnimationState {

    /**
     * When the current animation of the chain started.
     */
    public var start:Float;

    /**
     * Index of the current animation of the chain.
     */
    public var animationIx:Int;

    /**
     * Whether a throttled re-render (see `Animation.withMaxFps`) is
     * already scheduled, so overlapping renders don't stack extra timers.
     * (GPUI shares an `Rc<Cell<bool>>` with the timer task; the task can
     * capture this state object instead.)
     */
    public var delayedFramePending:Bool;

    /**
     * Result of the last `advance()`: the animation to render.
     * It is the index before any chaining done by that call.
     */
    public var frameAnimationIx:Int = 0;

    /**
     * Result of the last `advance()`: the normalized time, before easing.
     */
    public var frameProgress:Float = 0.0;

    /**
     * Result of the last `advance()`: the eased value given to the animator.
     */
    public var frameDelta:Float = 0.0;

    /**
     * Result of the last `advance()`: whether the animation chain is finished,
     * in which case no other frame needs to be requested.
     */
    public var frameDone:Bool = false;

    /**
     * Creates the state of a newly mounted element, at time `now`.
     */
    public function new(now:Float) {

        this.start = now;
        this.animationIx = 0;
        this.delayedFramePending = false;

    }

    /**
     * Computes the animation to render at time `now`, its eased value and whether
     * the chain is done. Results are written in the `frame*` fields.
     *
     * @param animations The animation chain (not empty).
     * @param now Current time in seconds (`cx.backgroundExecutor().now()`).
     * @param syncedEpoch The `App` clock origin of synced animations (`cx.synced_animation_epoch`).
     * @param reduceMotion `cx.reduceMotion()`: render a static frame (end state for oneshot
     *   animations, start state for repeating ones) and stop.
     */
    public function advance(animations:Array<Animation>, now:Float, syncedEpoch:Float, reduceMotion:Bool):Void {

        var animationIx:Int;
        var delta:Float;
        var done:Bool;

        if (reduceMotion) {
            animationIx = animations.length - 1;
            delta = animations[animationIx].oneshot ? 1.0 : 0.0;
            done = true;
        }
        else {
            animationIx = this.animationIx;
            final animation = animations[animationIx];
            final duration = animation.duration;

            final elapsed = if (animation.synced && duration != 0.0) {
                // GPUI reduces the elapsed nanoseconds modulo the duration before the
                // f32 conversion. The f64 remainder of seconds is exact for its inputs.
                (now - syncedEpoch) % duration;
            }
            else {
                now - this.start;
            }
            // Rust: elapsed.as_secs_f32() / duration.as_secs_f32()
            delta = f32(Spring.durationAsSecsF32(elapsed) / Spring.durationAsSecsF32(duration));

            done = false;
            if (delta > 1.0) {
                if (animation.oneshot) {
                    if (animationIx >= animations.length - 1) {
                        done = true;
                    }
                    else {
                        this.start = now;
                        this.animationIx++;
                    }
                    delta = 1.0;
                }
                else {
                    delta %= 1.0;
                }
            }
        }

        frameAnimationIx = animationIx;
        frameProgress = delta;
        frameDelta = animations[animationIx].easing(delta);
        frameDone = done;

    }

}

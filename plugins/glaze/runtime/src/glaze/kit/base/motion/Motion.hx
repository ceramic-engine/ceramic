// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (transition, transition_with_status, animate_keyframes, spring)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

import gpui.App;
import gpui.AppContext;
import gpui.SpringMath.f32;
import gpui.SpringState;
import gpui.SpringTarget;
import gpui.Window;
import gpui.base.motion.Timing.MotionPhase;
import gpui.util.MathUtil;

/**
 * Keyed, render-time motion: CSS-like transitions, keyframe playback and
 * springs toward application-owned targets.
 *
 * Call these while rendering an element: their state is element state keyed
 * by the `TransitionId` within the element being rendered, kept while the
 * element keeps sampling it every frame, and they request an animation frame
 * while the motion runs. Base components opt into motion explicitly; nothing
 * installs default motion.
 *
 * Generic values: Rust bounds the value type with `Interpolate + PartialEq`.
 * Here `transition` / `transitionWithStatus` animate a `Float` (also
 * `Pixels` and `Rems`), and the `...Of` variants take an `Interpolator<T>`
 * for any other type (see `Interpolators`).
 *
 * Time comes from `cx.backgroundExecutor().now()` (seconds), so tests drive
 * it with the `TestDispatcher` clock. Under `cx.reduceMotion()` every motion
 * adopts its target at once and requests no frame.
 *
 * ```haxe
 * final opacity = Motion.transition(TransitionId.named('panel', 'opacity'), open ? 1.0 : 0.0,
 *     new Transition(0.15).easing(Easing.EaseOut), window, cx);
 * final height = Motion.spring(TransitionId.named('panel', 'height'), targetHeight,
 *     new Spring(0.3).withEpsilon(0.1), window, cx);
 * ```
 */
class Motion {

    /**
     * Returns the current value for a CSS-like transition toward `target`.
     *
     * State is keyed by `id`. The first value is adopted immediately; later
     * target changes transition from the value sampled at that instant.
     */
    public static inline function transition(id:TransitionId, target:Float, policy:Transition, window:Window, cx:AppContext):Float {
        return transitionWithStatusOf(id, target, Interpolators.FLOAT, policy, window, cx).value;
    }

    /**
     * `transition`, with the status of the motion.
     */
    public static inline function transitionWithStatus(id:TransitionId, target:Float, policy:Transition, window:Window, cx:AppContext):MotionValue<Float> {
        return transitionWithStatusOf(id, target, Interpolators.FLOAT, policy, window, cx);
    }

    /**
     * `transition` for any type, interpolated and compared by `interpolator`.
     * A channel id must identify one value type within the element.
     */
    public static inline function transitionOf<T>(id:TransitionId, target:T, interpolator:Interpolator<T>, policy:Transition, window:Window, cx:AppContext):T {
        return transitionWithStatusOf(id, target, interpolator, policy, window, cx).value;
    }

    /**
     * `transitionWithStatus` for any type, interpolated and compared by `interpolator`.
     */
    public static function transitionWithStatusOf<T>(id:TransitionId, target:T, interpolator:Interpolator<T>, policy:Transition, window:Window, cx:AppContext):MotionValue<T> {
        final now = MotionTime.nanos(cx.backgroundExecutor().now());
        final box = id.child('__base-transition-state').stateBox(window, ValueTransition);
        var state:ValueTransition<T> = cast box.value;
        if (state == null) {
            state = new ValueTransition<T>(target, target, now, 1.0, policy.durationNanos);
            box.value = cast state;
        }

        final snapshotFrom = state.from;
        final snapshotTarget = state.target;
        final snapshotStartedAt = state.startedAt;
        final snapshotReversingFactor = state.reversingFactor;
        final snapshotDuration = state.durationNanos;

        if (cx.reduceMotion() || policy.durationNanos == 0) {
            if (!interpolator.equals(snapshotFrom, target) || !interpolator.equals(snapshotTarget, target)) {
                state.from = target;
                state.target = target;
                state.startedAt = now;
                state.reversingFactor = 1.0;
                state.durationNanos = policy.durationNanos;
            }
            return new MotionValue(target, Finished);
        }

        final elapsed = saturatingSince(now, snapshotStartedAt);
        final progress = policy.progressValue(elapsed, snapshotDuration);
        var status = policy.progressStatus(elapsed, snapshotDuration);
        final eased = policy.sample(progress);
        final sampled = interpolator.interpolate(snapshotFrom, snapshotTarget, eased);

        var value:T;
        if (!interpolator.equals(snapshotTarget, target)) {
            final reversing = interpolator.equals(target, snapshotFrom);
            final reversingFactor = reversing
                ? MathUtil.clamp(f32(f32(eased * snapshotReversingFactor) + f32(1.0 - snapshotReversingFactor)), 0.0, 1.0)
                : 1.0;
            final duration = MotionTime.mulF64(policy.durationNanos, reversingFactor);
            state.from = sampled;
            state.target = target;
            state.startedAt = now;
            state.reversingFactor = reversingFactor;
            state.durationNanos = duration;
            final initialProgress = policy.progressValue(0, duration);
            value = interpolator.interpolate(sampled, target, policy.sample(initialProgress));
            status = policy.progressStatus(0, duration);
        }
        else {
            value = sampled;
            if (interpolator.equals(snapshotFrom, snapshotTarget)) {
                status = Idle;
            }
        }
        if (status.isActive()) {
            window.requestAnimationFrame();
        }
        return new MotionValue(value, status);
    }

    /**
     * Samples a keyed keyframe playback and requests frames while it is active.
     *
     * The stable `id` owns the playback's start time. Re-rendering with the
     * same id continues that playback; it does not restart when `keyframes` or
     * `timing` is reconstructed. To replay a sequence, include an
     * application-owned generation in the id, for example
     * `TransitionId.named('notification-enter', '$generation')`.
     */
    public static function animateKeyframes<T>(id:TransitionId, keyframes:Keyframes<T>, timing:Timing, window:Window, cx:AppContext):MotionValue<T> {
        final now = MotionTime.nanos(cx.backgroundExecutor().now());
        final box = id.child('__base-transition-state').child('__keyframes').stateBox(window, KeyframePlayback);
        if (box.value == null) {
            box.value = new KeyframePlayback(now);
        }
        final startedAt = box.value.startedAt;

        if (cx.reduceMotion()) {
            return new MotionValue(keyframes.sample(1.0), Finished);
        }

        final sample = timing.sampleNanos(saturatingSince(now, startedAt));
        final status:MotionStatus = switch sample.phase {
            case Before: Delayed;
            case Active: Running;
            case After: Finished;
        }
        if (status.isActive()) {
            window.requestAnimationFrame();
        }
        return new MotionValue(keyframes.sample(sample.directedProgress), status);
    }

    /**
     * Returns the current value for a spring travelling toward `target`.
     *
     * State is keyed by `id` exactly as `transition` keys its own. The first
     * value is adopted immediately; later target changes preserve both the
     * current position and the current velocity, so an interrupted spring is
     * redirected rather than restarted. A channel id must identify one value
     * within the element.
     */
    public static function spring(id:TransitionId, target:Float, policy:Spring, window:Window, cx:AppContext):Float {
        return springPosition(id, f32(target), policy, window, cx);
    }

    /**
     * `spring` toward a `SpringTarget`, projected into its output (Rust
     * `spring<T: SpringTarget>`).
     */
    public static function springTo<O>(id:TransitionId, target:SpringTarget<O>, policy:Spring, window:Window, cx:AppContext):O {
        return target.resolve(springPosition(id, f32(target.target()), policy, window, cx));
    }

    static function springPosition(id:TransitionId, targetPosition:Float, policy:Spring, window:Window, cx:AppContext):Float {
        final now = MotionTime.nanos(cx.backgroundExecutor().now());
        final box = id.child('__base-transition-state').stateBox(window, SpringTransition);
        var state = box.value;
        if (state == null) {
            state = new SpringTransition(new SpringState(targetPosition, 0.0), targetPosition, now);
            box.value = state;
        }

        final snapshotState = state.state;
        final snapshotTarget = state.target;
        final snapshotUpdatedAt = state.updatedAt;
        final atRestOnTarget = snapshotState.position == targetPosition && snapshotState.velocity == 0.0;

        // The overwhelmingly common case: a spring nothing is currently moving.
        // It has no state to advance and no frame to ask for. Resting writes
        // nothing, so `updatedAt` goes stale for as long as the rest lasts; the
        // next retarget then steps a zero displacement at zero velocity over
        // that whole gap, which leaves the value where it is.
        if (atRestOnTarget) {
            return targetPosition;
        }

        if (cx.reduceMotion() || !policy.travel || policy.responseNanos == 0) {
            state.settle(targetPosition, now);
            return targetPosition;
        }

        // Advance over the frame that just elapsed, which the previous target
        // governed, before adopting the new one for the frame to come.
        final elapsed = MotionTime.asSecsF32(saturatingSince(now, snapshotUpdatedAt));
        final config = policy.config();
        final stepped = config.step(snapshotState, snapshotTarget, elapsed);

        if (config.isSettled(stepped, targetPosition, policy.epsilon())) {
            state.settle(targetPosition, now);
            return targetPosition;
        }

        state.state = stepped;
        state.target = targetPosition;
        state.updatedAt = now;
        window.requestAnimationFrame();
        return stepped.position;
    }

    /**
     * Rust's `Instant::saturating_duration_since`, in nanoseconds.
     */
    @:allow(gpui.base)
    static inline function saturatingSince(now:Float, earlier:Float):Float {
        return now > earlier ? now - earlier : 0.0;
    }

}

/**
 * The keyed state of `Motion.transitionWithStatusOf`.
 */
@:keep
private class ValueTransition<T> {

    public var from:T;

    public var target:T;

    public var startedAt:Float;

    public var reversingFactor:Float;

    public var durationNanos:Float;

    public function new(from:T, target:T, startedAt:Float, reversingFactor:Float, durationNanos:Float) {
        this.from = from;
        this.target = target;
        this.startedAt = startedAt;
        this.reversingFactor = reversingFactor;
        this.durationNanos = durationNanos;
    }

}

/**
 * The keyed state of `Motion.animateKeyframes`.
 */
@:keep
private class KeyframePlayback {

    public final startedAt:Float;

    public function new(startedAt:Float) {
        this.startedAt = startedAt;
    }

}

/**
 * The keyed state of `Motion.spring`.
 */
@:keep
private class SpringTransition {

    public var state:SpringState;

    public var target:Float;

    public var updatedAt:Float;

    public function new(state:SpringState, target:Float, updatedAt:Float) {
        this.state = state;
        this.target = target;
        this.updatedAt = updatedAt;
    }

    public function settle(target:Float, now:Float):Void {
        this.state = new SpringState(target, 0.0);
        this.target = target;
        this.updatedAt = now;
    }

}

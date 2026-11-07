// Ported from gpui-kit 0.8.1: crates/base/src/motion/presence.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.motion;

import glaze.App;
import glaze.AppContext;
import glaze.SpringMath.f32;
import glaze.Window;
import glaze.kit.base.animation.Lerp;
import glaze.util.MathUtil;

/**
 * Where an element whose presence is animated stands.
 */
enum abstract PresencePhase(Int) {
    var Entering = 0;
    var Present = 1;
    var Exiting = 2;
    var Absent = 3;

    public function toString():String {
        return switch (cast this : PresencePhase) {
            case Entering: 'Entering';
            case Present: 'Present';
            case Exiting: 'Exiting';
            case Absent: 'Absent';
        }
    }
}

/**
 * One sample of a `Presence`: its phase, its progress from absent (0) to
 * present (1), and the status of the transition.
 */
class PresenceSample {

    public final phase:PresencePhase;

    public final progress:Float;

    public final status:MotionStatus;

    public inline function new(phase:PresencePhase, progress:Float, status:MotionStatus) {
        this.phase = phase;
        this.progress = progress;
        this.status = status;
    }

    /**
     * Whether the element should still be rendered: everything but `Absent`,
     * so an exiting element stays mounted until its exit has run.
     */
    public inline function shouldRender():Bool {
        return phase != Absent;
    }

    public function toString():String {
        return 'PresenceSample(phase: ${phase.toString()}, progress: $progress, status: ${status.toString()})';
    }

}

/**
 * Animates an element in and out as `present` changes, keeping it mounted
 * while it exits. Without a transition (the default) it switches at once.
 *
 * Its keyed state works like `Motion.transition` over a 0..1 progress: an
 * exit interrupted by a re-entry reverses from where it is, over a
 * proportionally shorter duration.
 */
class Presence {

    final id:TransitionId;

    final present:Bool;

    var policy:Transition;

    public function new(id:TransitionId, present:Bool) {
        this.id = id;
        this.present = present;
        this.policy = new Transition(0);
    }

    public function transition(transition:Transition):Presence {
        this.policy = transition;
        return this;
    }

    public function sample(window:Window, cx:AppContext):PresenceSample {
        final now = MotionTime.nanos(cx.backgroundExecutor().now());
        final target = present ? 1.0 : 0.0;
        final box = id.child('__presence').stateBox(window, PresenceState);
        var state = box.value;
        if (state == null) {
            state = new PresenceState(0.0, target, now, 1.0, policy.durationNanos);
            box.value = state;
        }

        final snapshotFrom = state.from;
        final snapshotTarget = state.target;
        final snapshotStartedAt = state.startedAt;
        final snapshotReversingFactor = state.reversingFactor;
        final snapshotDuration = state.durationNanos;

        if (cx.reduceMotion() || policy.durationNanos == 0) {
            if (snapshotFrom != target || snapshotTarget != target) {
                state.from = target;
                state.target = target;
                state.startedAt = now;
                state.reversingFactor = 1.0;
                state.durationNanos = policy.durationNanos;
            }
            return stableSample(present);
        }

        final elapsed = Motion.saturatingSince(now, snapshotStartedAt);
        final progress = policy.progressValue(elapsed, snapshotDuration);
        var status = policy.progressStatus(elapsed, snapshotDuration);
        final eased = policy.sample(progress);
        final sampled = Lerp.float(snapshotFrom, snapshotTarget, eased);

        var value:Float;
        if (snapshotTarget != target) {
            final reversing = target == snapshotFrom;
            final reversingFactor = reversing
                ? MathUtil.clamp(f32(f32(eased * snapshotReversingFactor) + f32(1.0 - snapshotReversingFactor)), 0.0, 1.0)
                : 1.0;
            final duration = MotionTime.mulF64(policy.durationNanos, reversingFactor);
            state.from = sampled;
            state.target = target;
            state.startedAt = now;
            state.reversingFactor = reversingFactor;
            state.durationNanos = duration;
            final initial = policy.progressValue(0, duration);
            value = Lerp.float(sampled, target, policy.sample(initial));
            status = policy.progressStatus(0, duration);
        }
        else {
            value = sampled;
        }

        if (status.isActive()) {
            window.requestAnimationFrame();
        }

        if (status == Finished) {
            return stableSample(present);
        }
        return new PresenceSample(present ? Entering : Exiting, value, status);
    }

    static function stableSample(present:Bool):PresenceSample {
        return new PresenceSample(present ? Present : Absent, present ? 1.0 : 0.0, Finished);
    }

}

@:keep
private class PresenceState {

    public var from:Float;

    public var target:Float;

    public var startedAt:Float;

    public var reversingFactor:Float;

    public var durationNanos:Float;

    public function new(from:Float, target:Float, startedAt:Float, reversingFactor:Float, durationNanos:Float) {
        this.from = from;
        this.target = target;
        this.startedAt = startedAt;
        this.reversingFactor = reversingFactor;
        this.durationNanos = durationNanos;
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/motion/sequence.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

import gpui.App;
import gpui.AppContext;
import gpui.Window;

/**
 * One target of a `Sequence` and the transition that reaches it.
 */
class SequenceStep<T> {

    final stepTarget:T;

    final stepTransition:Transition;

    public function new(target:T, transition:Transition) {
        this.stepTarget = target;
        this.stepTransition = transition;
    }

    public inline function target():T {
        return stepTarget;
    }

    public inline function transition():Transition {
        return stepTransition;
    }

}

/**
 * What a `Sequence` reports for the current frame.
 */
class SequenceSample<T> {

    final sampled:T;

    final stepIndex:Int;

    final motionStatus:MotionStatus;

    public inline function new(value:T, step:Int, status:MotionStatus) {
        this.sampled = value;
        this.stepIndex = step;
        this.motionStatus = status;
    }

    /**
     * The interpolated value for this frame.
     */
    public inline function value():T {
        return sampled;
    }

    public inline function intoValue():T {
        return sampled;
    }

    /**
     * The index of the step being played. A finished sequence reports its
     * last step; an empty one reports `0`.
     */
    public inline function step():Int {
        return stepIndex;
    }

    /**
     * The status of the step being played. `Finished` is reported only once
     * the last step has completed: a step that hands over to the next one
     * reports that next step's `Delayed` or `Running` instead.
     */
    public inline function status():MotionStatus {
        return motionStatus;
    }

    public inline function isFinished():Bool {
        return motionStatus == Finished;
    }

    inline function isActive():Bool {
        return motionStatus.isActive();
    }

    public function toString():String {
        return 'SequenceSample(value: $sampled, step: $stepIndex, status: ${motionStatus.toString()})';
    }

}

/**
 * A chain of value transitions, each starting when the previous one ends.
 *
 * A sequence begins at `from` on the frame it is first sampled and runs its
 * steps in order. A step ends at an absolute instant (its start plus its
 * delay and duration) and the next step starts at that same instant, so a
 * frame that lands past a boundary samples the next step where it would have
 * been rather than starting it late. Steps of zero duration complete within
 * the frame that reaches them.
 *
 * State is keyed by `id` exactly as `Motion.transition` keys its own, and
 * the sequence plays once per key. Re-rendering with the same id continues
 * it; to replay, include an application-owned generation in the id.
 *
 * A step's target and transition are captured when the step starts. Handing
 * the step being played a different target restarts the sequence: it begins
 * again at its first step from the value sampled at that instant, as a
 * retargeted transition continues from its current value. Steps other than
 * the one being played are read when the sequence reaches them and are not
 * compared, so a change to an earlier step has no effect on its own. A
 * sequence does not reverse; play a second sequence back to the start under
 * its own key when that is wanted.
 *
 * Under reduced motion the sequence adopts its last target at once, reports
 * `Finished`, and requests no frame.
 *
 * Values are interpolated and compared with the given `Interpolator`
 * (`Interpolators.FLOAT` for a `Float`).
 */
class Sequence<T> {

    final id:TransitionId;

    final fromValue:T;

    final interpolator:Interpolator<T>;

    final stepList:Array<SequenceStep<T>> = [];

    /**
     * Starts a sequence at `from`, with no steps yet.
     */
    public function new(id:TransitionId, from:T, interpolator:Interpolator<T>) {
        this.id = id;
        this.fromValue = from;
        this.interpolator = interpolator;
    }

    /**
     * Appends a step that transitions to `target` once the previous step ends.
     */
    public function withStep(target:T, transition:Transition):Sequence<T> {
        stepList.push(new SequenceStep(target, transition));
        return this;
    }

    /**
     * Appends steps built elsewhere, in order.
     */
    public function withSteps(steps:Iterable<SequenceStep<T>>):Sequence<T> {
        gpui.util.Iterables.append(stepList, steps);
        return this;
    }

    public inline function from():T {
        return fromValue;
    }

    public inline function steps():Array<SequenceStep<T>> {
        return stepList;
    }

    /**
     * Samples the sequence and requests a frame while a step is active.
     */
    public function sample(window:Window, cx:AppContext):SequenceSample<T> {
        if (stepList.length == 0) {
            return new SequenceSample(fromValue, 0, Idle);
        }
        final lastStep = stepList.length - 1;
        final last = stepList[lastStep];

        final now = MotionTime.nanos(cx.backgroundExecutor().now());
        final box = id.child('__sequence').stateBox(window, SequenceState);
        if (box.value == null) {
            box.value = cast SequenceState.start(0, fromValue, stepList, now);
        }

        if (cx.reduceMotion()) {
            final settled:SequenceState<T> = cast box.value;
            if (settled.step != lastStep || !interpolator.equals(settled.from, last.target())) {
                box.value = cast SequenceState.start(lastStep, last.target(), stepList, now);
            }
            return new SequenceSample(last.target(), lastStep, Finished);
        }

        final snapshot:SequenceState<T> = cast box.value;
        final progress = snapshot.progressValue(now);
        final status = snapshot.progressStatus(now);
        final retargeted = snapshot.step > lastStep || !interpolator.equals(stepList[snapshot.step].target(), snapshot.target);
        final handingOver = status == Finished && snapshot.step < lastStep;

        if (!retargeted && !handingOver) {
            final sample = new SequenceSample(snapshot.value(progress, interpolator), snapshot.step, status);
            if (status.isActive()) {
                window.requestAnimationFrame();
            }
            return sample;
        }

        // Only a boundary or a restart writes state. A restart begins the new
        // sequence's first step from the value the old one had reached, which
        // is where the eye is. A hand-over starts the next step at the instant
        // the finished one ended, not at `now`, so a frame that lands past
        // the boundary does not start the step late.
        var next = retargeted
            ? SequenceState.start(0, snapshot.value(progress, interpolator), stepList, now)
            : snapshot.handOver(stepList);
        while (next.step < lastStep && next.progressStatus(now) == Finished) {
            next = next.handOver(stepList);
        }
        final nextStatus = next.progressStatus(now);
        final value = next.value(next.progressValue(now), interpolator);
        box.value = cast next;
        if (nextStatus.isActive()) {
            window.requestAnimationFrame();
        }
        return new SequenceSample(value, next.step, nextStatus);
    }

}

/**
 * The step a sequence is playing, complete enough to sample without the
 * caller's steps: those are only needed to hand over to the next one.
 */
@:keep
private class SequenceState<T> {

    public final step:Int;

    public final from:T;

    public final target:T;

    public final transition:Transition;

    public final startedAt:Float;

    public function new(step:Int, from:T, target:T, transition:Transition, startedAt:Float) {
        this.step = step;
        this.from = from;
        this.target = target;
        this.transition = transition;
        this.startedAt = startedAt;
    }

    public static function start<T>(step:Int, from:T, steps:Array<SequenceStep<T>>, startedAt:Float):SequenceState<T> {
        return new SequenceState(step, from, steps[step].target(), steps[step].transition(), startedAt);
    }

    public function progressValue(now:Float):Float {
        return transition.progressValue(Motion.saturatingSince(now, startedAt), transition.durationNanos);
    }

    public function progressStatus(now:Float):MotionStatus {
        return transition.progressStatus(Motion.saturatingSince(now, startedAt), transition.durationNanos);
    }

    public function value(progress:Float, interpolator:Interpolator<T>):T {
        return interpolator.interpolate(from, target, transition.sample(progress));
    }

    /**
     * Starts the next step where this finished one ended. The caller has
     * checked that this step is finished and is not the last.
     */
    public function handOver(steps:Array<SequenceStep<T>>):SequenceState<T> {
        return start(step + 1, target, steps, startedAt + transition.finishesAfterNanos());
    }

}

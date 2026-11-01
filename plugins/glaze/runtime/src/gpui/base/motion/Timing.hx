// Ported from gpui-kit 0.8.1: crates/base/src/motion/timing.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

import gpui.SpringMath.f32;
import gpui.base.motion.SignedDuration.IntoSignedDuration;
import gpui.base.motion.SignedDuration.SignedDurationTools;

/**
 * How many times a timing plays (Rust `u64` count).
 */
enum IterationCount {
    Finite(count:Int);
    Infinite;
}

/**
 * The direction of each iteration of a timing, as CSS `animation-direction`.
 */
enum abstract PlaybackDirection(Int) {
    var Normal = 0;
    var Reverse = 1;
    var Alternate = 2;
    var AlternateReverse = 3;
}

/**
 * Where a timing sample falls: before, inside or after its active interval.
 */
enum abstract MotionPhase(Int) {
    var Before = 0;
    var Active = 1;
    var After = 2;

    public function toString():String {
        return switch (cast this : MotionPhase) {
            case Before: 'Before';
            case Active: 'Active';
            case After: 'After';
        }
    }
}

/**
 * One sample of a `Timing`.
 */
class TimingSample {

    public final phase:MotionPhase;

    /** The eased progress of the current iteration, in its direction. */
    public final directedProgress:Float;

    public final iteration:Int;

    public final active:Bool;

    public final finished:Bool;

    public inline function new(phase:MotionPhase, directedProgress:Float, iteration:Int, active:Bool, finished:Bool) {
        this.phase = phase;
        this.directedProgress = directedProgress;
        this.iteration = iteration;
        this.active = active;
        this.finished = finished;
    }

}

/**
 * A CSS-like animation timing: delay, duration, iteration count, direction
 * and easing. Durations are in seconds (Rust `Duration`).
 *
 * Immutable: the builders return a modified copy, as Rust's builders
 * consume a cloned value.
 */
class Timing {

    var delayValue:SignedDuration;

    var durationNanos:Float;

    var iterationCount:IterationCount;

    var playbackDirection:PlaybackDirection;

    var easing:Easing;

    public function new(duration:Float) {
        this.delayValue = Positive(0.0);
        this.durationNanos = MotionTime.nanos(duration);
        this.iterationCount = Finite(1);
        this.playbackDirection = Normal;
        this.easing = Easing.Linear;
    }

    /**
     * The duration of one iteration, in seconds.
     */
    public inline function duration():Float {
        return MotionTime.seconds(durationNanos);
    }

    function copy():Timing {
        final timing = new Timing(0);
        timing.durationNanos = durationNanos;
        timing.delayValue = delayValue;
        timing.iterationCount = iterationCount;
        timing.playbackDirection = playbackDirection;
        timing.easing = easing;
        return timing;
    }

    public function delay(delay:IntoSignedDuration):Timing {
        final timing = copy();
        timing.delayValue = delay;
        return timing;
    }

    public function iterations(iterations:IterationCount):Timing {
        final timing = copy();
        timing.iterationCount = iterations;
        return timing;
    }

    public function direction(direction:PlaybackDirection):Timing {
        final timing = copy();
        timing.playbackDirection = direction;
        return timing;
    }

    public function ease(easing:Easing):Timing {
        final timing = copy();
        timing.easing = easing;
        return timing;
    }

    /**
     * Samples the timing `elapsed` seconds after it started.
     */
    public inline function sample(elapsed:Float):TimingSample {
        return sampleNanos(MotionTime.nanos(elapsed));
    }

    @:allow(gpui.base.motion)
    function sampleNanos(elapsedNanos:Float):TimingSample {
        final activeElapsed = SignedDurationTools.activeElapsedNanos(delayValue, elapsedNanos);
        if (activeElapsed < 0) {
            return new TimingSample(Before, easing.sample(directed(0, 0.0)), 0, false, false);
        }

        final finiteIterations:Int = switch iterationCount {
            case Finite(count): count;
            case Infinite: -1;
        }
        if (durationNanos == 0 || finiteIterations == 0) {
            return afterSample(finiteIterations < 0 ? 1 : finiteIterations);
        }

        if (finiteIterations >= 0 && activeElapsed >= durationNanos * finiteIterations) {
            return afterSample(finiteIterations);
        }

        final iterationValue = Math.ffloor(activeElapsed / durationNanos);
        final iteration:Int = iterationValue > 2147483647.0 ? 2147483647 : Std.int(iterationValue);
        final iterationNanos = activeElapsed % durationNanos;
        final progress = f32(iterationNanos / durationNanos);
        return new TimingSample(Active, easing.sample(directed(iteration, progress)), iteration, true, false);
    }

    function afterSample(count:Int):TimingSample {
        final iteration = count > 0 ? count - 1 : 0;
        return new TimingSample(After, easing.sample(directed(iteration, 1.0)), iteration, false, true);
    }

    function directed(iteration:Int, progress:Float):Float {
        final reverse = switch playbackDirection {
            case Normal: false;
            case Reverse: true;
            case Alternate: iteration % 2 == 1;
            case AlternateReverse: iteration % 2 == 0;
        }
        return reverse ? f32(1.0 - progress) : progress;
    }

}

// Ported from gpui-pre 0.3.10: src/platform/test/dispatcher.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A deterministic dispatcher for tests, with a manual clock.
 *
 * - `dispatch` queues work, run by `tick()` or `runUntilParked()`;
 * - `dispatchAfter` registers a timer, run by `advanceClock()` (which steps
 *   through due timers like GPUI's test scheduler).
 *
 * Unlike GPUI's scheduler, `runUntilParked()` never advances the clock by itself:
 * tests (and animation tests later) control time explicitly.
 */
class TestDispatcher implements PlatformDispatcher {

    var time:Float = 0;

    final runnables:Array<() -> Void> = [];

    var runnablesHead:Int = 0;

    final timers:Array<TestTimer> = [];

    var nextTimerSeq:Int = 0;

    public function new() {}

    public function dispatch(runnable:() -> Void):Void {
        runnables.push(runnable);
    }

    public function dispatchAfter(seconds:Float, runnable:() -> Void):() -> Void {
        final timer = new TestTimer(time + seconds, nextTimerSeq++, runnable);
        // Keep timers sorted by time, then by creation order
        var index = timers.length;
        while (index > 0 && timers[index - 1].time > timer.time) {
            index--;
        }
        timers.insert(index, timer);
        return () -> {
            if (timers.remove(timer)) {
                timer.runnable = null;
            }
        };
    }

    public function now():Float {
        return time;
    }

    /**
     * Moves time forward like GPUI's `TestScheduler::advance_clock`: runs the
     * queued runnables, then steps the clock to each timer due before the
     * target and runs what it wakes (so a timer re-armed by its own task
     * fires again within the same advance), and finally sets the clock to
     * the target without running anything more.
     */
    public function advanceClock(seconds:Float):Void {
        final target = time + seconds;
        while (true) {
            runUntilParked();
            if (timers.length > 0 && timers[0].time <= target) {
                if (timers[0].time > time)
                    time = timers[0].time;
                fireDueTimers();
            } else {
                break;
            }
        }
        if (target > time)
            time = target;
    }

    /**
     * Makes the timers due at the current time runnable.
     */
    function fireDueTimers():Void {
        while (timers.length > 0 && timers[0].time <= time) {
            final timer = timers.shift();
            if (timer.runnable != null) {
                runnables.push(timer.runnable);
                timer.runnable = null;
            }
        }
    }

    /**
     * Moves time to the next timer, if any, and makes it runnable.
     * Returns `false` when there is no pending timer.
     */
    public function advanceClockToNextTimer():Bool {
        if (timers.length == 0)
            return false;
        if (timers[0].time > time)
            time = timers[0].time;
        fireDueTimers();
        return true;
    }

    /**
     * Runs one queued runnable. Returns `false` if there was none.
     */
    public function tick():Bool {
        if (runnablesHead >= runnables.length) {
            runnables.resize(0);
            runnablesHead = 0;
            return false;
        }
        final runnable = runnables[runnablesHead];
        runnables[runnablesHead] = null;
        runnablesHead++;
        runnable();
        return true;
    }

    /**
     * Runs queued runnables until none is left (timers that are not due stay pending).
     */
    public function runUntilParked():Void {
        while (tick()) {}
    }

    /**
     * `true` when runnables are queued.
     */
    public function hasPendingRunnables():Bool {
        return runnablesHead < runnables.length;
    }

    /**
     * Number of timers that are not due yet.
     */
    public function pendingTimerCount():Int {
        return timers.length;
    }

}

private class TestTimer {

    public final time:Float;

    public final seq:Int;

    public var runnable:Null<() -> Void>;

    public function new(time:Float, seq:Int, runnable:() -> Void) {
        this.time = time;
        this.seq = seq;
        this.runnable = runnable;
    }

}

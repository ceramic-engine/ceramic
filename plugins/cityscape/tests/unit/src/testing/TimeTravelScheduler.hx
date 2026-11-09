// New code for Cityscape (not a port): a virtual clock for the tests,
// standing for vscode's `runWithFakedTimers` (src/vs/base/test/common/timeTravelScheduler.ts).
package testing;

import cityscape.base.common.Async;

private class ScheduledTask {
    public final time:Float;
    public final id:Int;
    public final run:() -> Void;
    public var cancelled = false;

    public function new(time:Float, id:Int, run:() -> Void) {
        this.time = time;
        this.id = id;
        this.run = run;
    }
}

/**
 * Replaces `Async.setTimeout` while installed: the timeouts are queued on a
 * virtual clock and run in the order of their time (then of their
 * scheduling) when the test asks, advancing the clock to each one, like
 * vscode's `TimeTravelScheduler` with `useFakeTimers`. Everything that
 * goes through `Async` (Monaco's `Delayer`, `RunOnceScheduler`,
 * `TimeoutTimer`) is on this clock.
 */
class TimeTravelScheduler {

    /** The virtual time, in milliseconds. */
    public var now(default, null):Float = 0;

    final tasks:Array<ScheduledTask> = [];
    var lastId = 0;

    public function new() {}

    function schedule(fn:() -> Void, delay:Float):() -> Void {
        final task = new ScheduledTask(now + Math.max(0, delay), ++lastId, fn);
        tasks.push(task);
        return () -> task.cancelled = true;
    }

    /** Whether a timeout is waiting. */
    public function hasScheduledTasks():Bool {
        for (task in tasks) {
            if (!task.cancelled) {
                return true;
            }
        }
        return false;
    }

    /**
     * Runs the next timeout (advancing the clock to it); false when there
     * is none.
     */
    public function runNext():Bool {
        var next:Null<ScheduledTask> = null;
        var i = tasks.length - 1;
        while (i >= 0) {
            final task = tasks[i];
            if (task.cancelled) {
                tasks.splice(i, 1);
            }
            else if (next == null || task.time < next.time || (task.time == next.time && task.id < next.id)) {
                next = task;
            }
            i--;
        }
        if (next == null) {
            return false;
        }
        tasks.remove(next);
        now = next.time;
        next.run();
        return true;
    }

    /**
     * Runs the timeouts until `condition` is true (checked before each
     * one) or there is none left; at most `maxTasks` of them.
     */
    public function runUntil(condition:() -> Bool, maxTasks:Int = 10000):Void {
        var count = 0;
        while (!condition() && count < maxTasks && runNext()) {
            count++;
        }
    }

    /** Runs all the timeouts (at most `maxTasks`). */
    public function runAll(maxTasks:Int = 10000):Void {
        runUntil(() -> false, maxTasks);
    }

    /**
     * vscode's `runWithFakedTimers`: `body` runs with the virtual clock
     * installed (it drives it with `runUntil`), removed afterwards.
     */
    public static function runWithFakedTimers(body:(scheduler:TimeTravelScheduler) -> Void):Void {
        final scheduler = new TimeTravelScheduler();
        final previous = Async._testSetTimeout;
        Async._testSetTimeout = scheduler.schedule;
        try {
            body(scheduler);
        }
        catch (e:Dynamic) {
            Async._testSetTimeout = previous;
            throw e;
        }
        Async._testSetTimeout = previous;
    }

}

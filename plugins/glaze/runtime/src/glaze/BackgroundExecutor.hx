// Ported from gpui-pre 0.3.10: src/executor.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import tracker.Autorun;

/**
 * A pointer to the executor that is currently running,
 * for spawning background tasks.
 *
 * There are no threads for now: background work runs on the main thread,
 * dispatched like foreground work. Real threads may come later through
 * `ceramic.Runner` on targets that have them; code ported from GPUI should
 * already only touch `Send` data in background closures.
 */
class BackgroundExecutor {

    /**
     * The dispatcher used to schedule work.
     */
    public final dispatcher:PlatformDispatcher;

    public function new(dispatcher:PlatformDispatcher) {
        this.dispatcher = dispatcher;
    }

    /**
     * Enqueues the given computation to be run, returning a task of its result.
     * Unlike `ForegroundExecutor.spawn`, the closure returns a plain value: Rust
     * background futures are almost always plain computations. A closure that
     * only has side effects should end with `Unit.unit` (a `Task<Void>` cannot be
     * awaited on native targets, see `Unit`).
     */
    public function spawn<R>(f:() -> R):Task<R> {
        final task = new Task<R>();
        dispatcher.dispatch(() -> {
            if (!task.isPending)
                return;
            var value:Dynamic = null;
            Autorun.unobserve();
            try {
                value = f();
            }
            catch (e:Dynamic) {
                Autorun.reobserve();
                task.rejectWith(e);
                return;
            }
            Autorun.reobserve();
            task.resolveDynamic(value);
        });
        return task;
    }

    /**
     * Get the current time, in seconds. Use this instead of a system clock
     * so that tests can use a fake clock.
     */
    public function now():Float {
        return dispatcher.now();
    }

    /**
     * Returns a task that will complete after the given duration in seconds.
     */
    public function timer(seconds:Float):Task<Unit> {
        if (seconds <= 0) {
            return Task.done();
        }
        final task = new Task<Unit>();
        task.cancelHook = dispatcher.dispatchAfter(seconds, () -> task.resolveDynamic(Unit.unit));
        return task;
    }

    /**
     * Whether the executor runs on a `TestDispatcher`.
     */
    public function isTest():Bool {
        return Std.isOfType(dispatcher, TestDispatcher);
    }

    /**
     * In tests, move time forward. This does not run any tasks, but does make timers ready.
     */
    public function advanceClock(seconds:Float):Void {
        testDispatcher().advanceClock(seconds);
    }

    /**
     * In tests, run one task.
     */
    public function tick():Bool {
        return testDispatcher().tick();
    }

    /**
     * In tests, run tasks until none is runnable.
     */
    public function runUntilParked():Void {
        testDispatcher().runUntilParked();
    }

    function testDispatcher():TestDispatcher {
        if (!Std.isOfType(dispatcher, TestDispatcher)) {
            throw 'This executor does not use a TestDispatcher';
        }
        return cast dispatcher;
    }

}

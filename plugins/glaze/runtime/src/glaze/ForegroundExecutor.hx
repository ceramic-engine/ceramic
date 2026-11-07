// Ported from gpui-pre 0.3.10: src/executor.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import tracker.Autorun;

/**
 * A pointer to the executor that is currently running,
 * for spawning tasks on the main thread.
 */
class ForegroundExecutor {

    /**
     * The dispatcher used to schedule work.
     */
    public final dispatcher:PlatformDispatcher;

    public function new(dispatcher:PlatformDispatcher) {
        this.dispatcher = dispatcher;
    }

    /**
     * Enqueues the given async block to be run on the main thread.
     *
     * The closure stands for the body of an `async move` block: it runs later
     * (never synchronously) and returns the task it ends with, typically a chain of
     * `then` / `andThen`. Return `Task.ready(value)` or `Task.done()` when nothing
     * is awaited. `null` is accepted and means `Task.done()` (the result is then `null`).
     */
    public function spawn<R>(f:() -> Task<R>):Task<R> {
        final task = new Task<R>();
        dispatcher.dispatch(() -> {
            if (!task.isPending)
                return;
            var inner:Task<R> = null;
            Autorun.unobserve();
            try {
                inner = f();
            }
            catch (e:Dynamic) {
                Autorun.reobserve();
                task.rejectWith(e);
                return;
            }
            Autorun.reobserve();
            if (inner == null) {
                task.resolveDynamic(null);
            }
            else if (!task.isPending) {
                inner.cancel();
            }
            else {
                task.follow(inner);
            }
        });
        return task;
    }

}

// Ported from gpui-pre 0.3.10: src/executor.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import tracker.Autorun;

/**
 * Task is a primitive that allows work to happen in the background.
 *
 * Haxe 4.3 has no coroutines, so a task is callback based. Porting an
 * `async move` block is mechanical:
 *
 * - `x.await` followed by more code becomes `x.andThen(value -> ...)` when the
 *   rest awaits again, `x.then(value -> ...)` otherwise (`x.map(value -> ...)`
 *   when the block produces a value);
 * - tasks that produce nothing are `Task<Unit>` (Rust `Task<()>`), never
 *   `Task<Void>` (see `Unit`);
 * - the `?` operator becomes an exception: any exception thrown by a continuation
 *   fails the task (`WeakEntity.update` throws `EntityReleasedError`), and the
 *   following continuations are skipped;
 * - `Task::ready(value)` is `Task.ready(value)`, `join_all` is `Task.all`;
 * - dropping a task is `cancel()`. Tasks spawned through a `Context` are owned
 *   by its entity and cancelled when the entity is destroyed, unless detached.
 *
 * Continuations run synchronously when the awaited task completes, with tracker
 * capture disabled.
 */
class Task<T> extends AnyTask {

    var result:Null<T> = null;

    /**
     * Creates a pending task. Complete it with `resolve` or `reject`
     * (this stands for Rust's oneshot channels used as futures).
     */
    public function new() {
        super();
    }

    /**
     * The value of the task once ready, `null` otherwise
     * (Rust: `now_or_never`).
     */
    public var value(get, never):Null<T>;
    inline function get_value():Null<T> {
        return result;
    }

    /**
     * Completes the task with the given value.
     */
    public function resolve(value:T):Void {
        resolveDynamic(value);
    }

    /**
     * Fails the task with the given error.
     */
    public function reject(error:Dynamic):Void {
        rejectWith(error);
    }

    @:allow(gpui)
    function resolveDynamic(value:Dynamic):Void {
        if (state != Pending)
            return;
        result = value;
        state = Ready;
        cancelHook = null;
        complete();
    }

    /**
     * Completes this task the same way as `other`, once `other` completes.
     */
    @:allow(gpui)
    function follow(other:Task<T>):Void {
        final prevHook = cancelHook;
        cancelHook = () -> {
            if (prevHook != null) prevHook();
            other.cancel();
        };
        other.onComplete(() -> {
            switch other.state {
                case Ready: resolveDynamic(other.result);
                case Failed: rejectWith(other.error);
                case Cancelled: cancel();
                case Pending:
            }
        });
    }

    /**
     * Runs `f` with the value once the task is ready (the rest of an `async` block
     * after an `.await`). The returned task is ready when `f` has run. Failure
     * and cancellation are propagated. Use `map` to produce a value.
     */
    public function then(f:T->Void):Task<Unit> {
        final out = new Task<Unit>();
        out.cancelHook = cancel;
        onComplete(() -> {
            switch state {
                case Ready:
                    Autorun.unobserve();
                    try {
                        f(result);
                    }
                    catch (e:Dynamic) {
                        Autorun.reobserve();
                        out.rejectWith(unwrapError(e));
                        return;
                    }
                    Autorun.reobserve();
                    out.resolveDynamic(Unit.unit);
                case Failed:
                    out.rejectWith(error);
                case Cancelled | Pending:
                    out.cancel();
            }
        });
        return out;
    }

    /**
     * Runs `f` with the value once the task is ready and returns a task of its
     * result (an `.await` whose value is transformed). Failure and cancellation
     * are propagated.
     */
    public function map<U>(f:T->U):Task<U> {
        final out = new Task<U>();
        out.cancelHook = cancel;
        onComplete(() -> {
            switch state {
                case Ready:
                    var value:Dynamic = null;
                    Autorun.unobserve();
                    try {
                        value = f(result);
                    }
                    catch (e:Dynamic) {
                        Autorun.reobserve();
                        out.rejectWith(unwrapError(e));
                        return;
                    }
                    Autorun.reobserve();
                    out.resolveDynamic(value);
                case Failed:
                    out.rejectWith(error);
                case Cancelled | Pending:
                    out.cancel();
            }
        });
        return out;
    }

    /**
     * Runs `f` with the value once the task is ready, then waits for the task it
     * returns (an `.await` followed by more awaits). `f` may return `null` when
     * there is nothing more to wait for (the result is then `null`).
     */
    public function andThen<U>(f:T->Task<U>):Task<U> {
        final out = new Task<U>();
        out.cancelHook = cancel;
        onComplete(() -> {
            switch state {
                case Ready:
                    var next:Task<U> = null;
                    Autorun.unobserve();
                    try {
                        next = f(result);
                    }
                    catch (e:Dynamic) {
                        Autorun.reobserve();
                        out.rejectWith(unwrapError(e));
                        return;
                    }
                    Autorun.reobserve();
                    if (out.state != Pending) {
                        if (next != null) next.cancel();
                    }
                    else if (next == null) {
                        out.resolveDynamic(null);
                    }
                    else {
                        out.cancelHook = null;
                        out.follow(next);
                    }
                case Failed:
                    out.rejectWith(error);
                case Cancelled | Pending:
                    out.cancel();
            }
        });
        return out;
    }

    /**
     * Recovers from a failure: when the task fails, the returned task is ready
     * with the value returned by `f` (Rust: `unwrap_or_else` on a `Result`).
     */
    public function catchError(f:Dynamic->T):Task<T> {
        final out = new Task<T>();
        out.cancelHook = cancel;
        onComplete(() -> {
            switch state {
                case Ready:
                    out.resolveDynamic(result);
                case Failed:
                    var value:Dynamic = null;
                    Autorun.unobserve();
                    try {
                        value = f(error);
                    }
                    catch (e:Dynamic) {
                        Autorun.reobserve();
                        out.rejectWith(unwrapError(e));
                        return;
                    }
                    Autorun.reobserve();
                    out.resolveDynamic(value);
                case Cancelled | Pending:
                    out.cancel();
            }
        });
        return out;
    }

    /**
     * A task that is already ready with the given value (Rust: `Task::ready`).
     */
    public static function ready<T>(value:T):Task<T> {
        final task = new Task<T>();
        task.resolveDynamic(value);
        return task;
    }

    /**
     * A `Task<Unit>` that is already ready: what an `async` block that awaits
     * nothing returns.
     */
    public static function done():Task<Unit> {
        final task = new Task<Unit>();
        task.resolveDynamic(Unit.unit);
        return task;
    }

    /**
     * A task that already failed with the given error.
     */
    public static function failed<T>(error:Dynamic):Task<T> {
        final task = new Task<T>();
        task.listeners = [];
        task.rejectWith(error);
        task.listeners = null;
        return task;
    }

    /**
     * Waits for every task and gives their values in order (Rust: `join_all`,
     * short-circuiting on the first failure like `try_join_all`). Cancelling the
     * returned task cancels the pending ones.
     */
    public static function all<T>(tasks:Array<Task<T>>):Task<Array<T>> {
        final out = new Task<Array<T>>();
        final values:Array<T> = [for (_ in 0...tasks.length) null];
        var remaining = tasks.length;
        out.cancelHook = () -> {
            for (task in tasks) task.cancel();
        };
        if (remaining == 0) {
            out.resolveDynamic(values);
            return out;
        }
        for (i in 0...tasks.length) {
            final task = tasks[i];
            task.onComplete(() -> {
                if (out.state != Pending)
                    return;
                switch task.state {
                    case Ready:
                        values[i] = task.result;
                        remaining--;
                        if (remaining == 0) out.resolveDynamic(values);
                    case Failed:
                        out.cancelHook = null;
                        out.rejectWith(task.error);
                        for (other in tasks) other.cancel();
                    case Cancelled | Pending:
                        out.cancel();
                }
            });
        }
        return out;
    }

    static function unwrapError(e:Dynamic):Dynamic {
        if (Std.isOfType(e, haxe.ValueException)) {
            return (e : haxe.ValueException).value;
        }
        return e;
    }

}

// Ported from vscode src/vs/base/common/async.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Promise;

/**
 * Module functions of async.ts. Timers go through Ceramic (`ceramic.Timer`),
 * which runs them in the app loop on every target. Monaco's
 * `runWhenGlobalIdle` is replaced by the background work scheduler of the
 * `Cityscape` context (`cityscape.common.services.BackgroundScheduler`).
 */
class Async {

    /**
     * `setTimeout(fn, delay)` (milliseconds); the returned function cancels it.
     */
    public static function setTimeout(fn:() -> Void, delay:Float):() -> Void {
        // Parameter hints (step 7, cs7-rest-snip): the virtual clock of the tests
        final schedule = _testSetTimeout;
        if (schedule != null) {
            return schedule(fn, delay);
        }
        #if cityscape_debug_counters
        DebugCounters.timers++;
        var pending = true;
        final cancel = ceramic.Timer.delay(null, delay / 1000.0, () -> {
            if (pending) {
                pending = false;
                DebugCounters.timers--;
            }
            fn();
        });
        return () -> {
            if (pending) {
                pending = false;
                DebugCounters.timers--;
            }
            cancel();
        };
        #else
        return ceramic.Timer.delay(null, delay / 1000.0, fn);
        #end
    }

    /**
     * Replaces `setTimeout` while set (tests only: the virtual clock of
     * `testing.TimeTravelScheduler`, vscode's `runWithFakedTimers`). Not
     * editor state: a test sets it and clears it before it returns.
     */
    @:noCompletion public static var _testSetTimeout:Null<(fn:() -> Void, delay:Float) -> (() -> Void)> = null;

    /**
     * Monaco's `createCancelablePromise`: the promise of `callback`,
     * rejected with a `CancellationError` when cancelled before it settles
     * (the token given to `callback` is cancelled too).
     */
    public static function createCancelablePromise<T>(callback:(token:cityscape.base.common.Cancellation.CancellationToken) -> Promise<T>):CancelablePromise<T> {
        final source = new cityscape.base.common.Cancellation.CancellationTokenSource();
        final thenable = callback(source.token);
        var isCancelled = false;
        final promise = new Promise<T>((resolve, reject) -> {
            var subscription:Null<IDisposable> = null;
            subscription = source.token.onCancellationRequested(() -> {
                isCancelled = true;
                if (subscription != null) {
                    subscription.dispose();
                }
                reject(new CancellationError());
            });
            thenable.done(value -> {
                if (subscription != null) {
                    subscription.dispose();
                }
                source.dispose();
                if (!isCancelled) {
                    resolve(value);
                }
            }, err -> {
                if (subscription != null) {
                    subscription.dispose();
                }
                source.dispose();
                reject(err);
            });
        });
        return new CancelablePromise<T>(promise, source);
    }

}

/**
 * A helper that runs a function once after a delay, the last scheduled call
 * winning (Monaco's `RunOnceScheduler`).
 */
class RunOnceScheduler implements IDisposable {

    var runner:Null<() -> Void>;

    var cancelTimeout:Null<() -> Void> = null;

    var timeout:Float;

    /**
     * @param delay in milliseconds, like Monaco
     */
    public function new(runner:() -> Void, delay:Float) {
        this.runner = runner;
        this.timeout = delay;
    }

    /**
     * Dispose RunOnceScheduler
     */
    public function dispose():Void {
        cancel();
        runner = null;
    }

    /**
     * Cancel current scheduled runner (if any).
     */
    public function cancel():Void {
        if (isScheduled()) {
            final c = cancelTimeout;
            cancelTimeout = null;
            c();
        }
    }

    /**
     * Cancel previous runner (if any) & schedule a new runner.
     */
    public function schedule(?delay:Float):Void {
        cancel();
        cancelTimeout = Async.setTimeout(onTimeout, delay != null ? delay : timeout);
    }

    public var delay(get, set):Float;

    inline function get_delay():Float {
        return timeout;
    }

    inline function set_delay(value:Float):Float {
        return timeout = value;
    }

    /**
     * Returns true if scheduled.
     */
    public function isScheduled():Bool {
        return cancelTimeout != null;
    }

    public function flush():Void {
        if (isScheduled()) {
            cancel();
            doRun();
        }
    }

    function onTimeout():Void {
        cancelTimeout = null;
        if (runner != null) {
            doRun();
        }
    }

    function doRun():Void {
        if (runner != null) {
            runner();
        }
    }

}

/**
 * A timeout that can be set, replaced and cancelled (Monaco's
 * `TimeoutTimer`).
 */
class TimeoutTimer implements IDisposable {

    var _cancel:Null<() -> Void> = null;
    var _isDisposed = false;
    var _runner:Null<() -> Void> = null;

    public function new(?runner:() -> Void, ?timeout:Float) {
        if (runner != null && timeout != null) {
            this.setIfNotSet(runner, timeout);
        }
    }

    public function dispose():Void {
        this.cancel();
        this._isDisposed = true;
    }

    public function cancel():Void {
        if (this._cancel != null) {
            final c = this._cancel;
            this._cancel = null;
            this._runner = null;
            c();
        }
    }

    /**
     * @param timeout in milliseconds, like Monaco
     */
    public function cancelAndSet(runner:() -> Void, timeout:Float):Void {
        if (this._isDisposed) {
            throw 'Calling \'cancelAndSet\' on a disposed TimeoutTimer';
        }

        this.cancel();
        this._runner = runner;
        this._cancel = Async.setTimeout(() -> {
            this._cancel = null;
            this._runner = null;
            runner();
        }, timeout);
    }

    /**
     * @param timeout in milliseconds, like Monaco
     */
    public function setIfNotSet(runner:() -> Void, timeout:Float):Void {
        if (this._isDisposed) {
            throw 'Calling \'setIfNotSet\' on a disposed TimeoutTimer';
        }

        if (this._cancel != null) {
            // timer is already set
            return;
        }
        this._runner = runner;
        this._cancel = Async.setTimeout(() -> {
            this._cancel = null;
            this._runner = null;
            runner();
        }, timeout);
    }

    /**
     * Runs the pending runner at once (not in Monaco: tests use it instead
     * of waiting).
     */
    public function flush():Void {
        final runner = this._runner;
        if (this._cancel != null && runner != null) {
            this.cancel();
            runner();
        }
    }

}

/**
 * Delays the execution of a task until a delay passed without a new
 * trigger, the last triggered task winning (Monaco's `Delayer`, without its
 * promise: the task runs from a Ceramic timer).
 */
class Delayer implements IDisposable {

    final defaultDelay:Float;
    var cancelTimeout:Null<() -> Void> = null;
    var task:Null<() -> Void> = null;

    /**
     * @param defaultDelay in milliseconds, like Monaco
     */
    public function new(defaultDelay:Float) {
        this.defaultDelay = defaultDelay;
    }

    public function trigger(task:() -> Void, ?delay:Float):Void {
        this.task = task;
        cancelTimer();
        this.cancelTimeout = Async.setTimeout(() -> {
            this.cancelTimeout = null;
            final t = this.task;
            this.task = null;
            if (t != null) {
                t();
            }
        }, delay != null ? delay : defaultDelay);
    }

    public function isTriggered():Bool {
        return cancelTimeout != null;
    }

    /**
     * Runs the pending task now (tests).
     */
    public function flush():Void {
        if (isTriggered()) {
            final t = this.task;
            cancel();
            if (t != null) {
                t();
            }
        }
    }

    function cancelTimer():Void {
        if (cancelTimeout != null) {
            final c = cancelTimeout;
            cancelTimeout = null;
            c();
        }
    }

    public function cancel():Void {
        cancelTimer();
        task = null;
    }

    public function dispose():Void {
        cancel();
    }

}

// Parameter hints (step 7, cs7-rest-snip)

/**
 * A promise that can be cancelled (Monaco's `CancelablePromise`, made by
 * `Async.createCancelablePromise`): `promise` is the promise, `cancel`
 * cancels the work.
 */
class CancelablePromise<T> {

    public final promise:Promise<T>;
    final source:cityscape.base.common.Cancellation.CancellationTokenSource;

    public function new(promise:Promise<T>, source:cityscape.base.common.Cancellation.CancellationTokenSource) {
        this.promise = promise;
        this.source = source;
    }

    public function cancel():Void {
        source.cancel();
        source.dispose();
    }

}

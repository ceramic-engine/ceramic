// Ported from vscode src/vs/base/common/async.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Lifecycle.IDisposable;

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
        return ceramic.Timer.delay(null, delay / 1000.0, fn);
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
        this._cancel = Async.setTimeout(() -> {
            this._cancel = null;
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
        this._cancel = Async.setTimeout(() -> {
            this._cancel = null;
            runner();
        }, timeout);
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

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

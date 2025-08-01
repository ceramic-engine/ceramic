package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * Timer system for scheduling delayed and periodic callbacks.
 *
 * The Timer class provides a central timing system that tracks application time
 * and allows scheduling callbacks to run after delays or at regular intervals.
 * All timers are synchronized with the main application update loop.
 *
 * Time tracking:
 * - `Timer.now`: Application time in seconds since startup
 * - `Timer.timestamp`: Unix timestamp synchronized with application time
 *
 * Basic usage:
 * ```haxe
 * // Run callback after 2 seconds
 * Timer.delay(this, 2.0, () -> {
 *     trace("2 seconds elapsed");
 * });
 *
 * // Run callback every 0.5 seconds
 * var cancel = Timer.interval(this, 0.5, () -> {
 *     trace("Tick!");
 * });
 *
 * // Cancel the interval later
 * cancel();
 * ```
 *
 * Timers are automatically cancelled when their owner entity is destroyed,
 * preventing memory leaks and null reference errors.
 */
class Timer {

    static var callbacks:Array<TimerCallback> = [];
    static var next:Float = 999999999;

    /**
     * Current time, relative to app.
     * (number of active seconds since app was started)
     *
     * This value is incremented by the frame delta each update,
     * providing a consistent time reference for the entire application.
     */
    public static var now(default,null):Float = 0;

    /**
     * Current unix time synchronized with ceramic Timer.
     * `Timer.now` and `Timer.timestamp` are guaranteed to get incremented
     * exactly at the same rate, except when app frame real delta > 1s
     * (number of seconds since January 1st, 1970)
     *
     * Useful for timestamping events or synchronizing with external systems.
     */
    public static var timestamp(get,null):Float;
    inline static function get_timestamp():Float {
        return startTimestamp + now;
    }

    /**
     * The unix timestamp when the application started.
     * Used as the base for calculating the current timestamp.
     */
    public static var startTimestamp(default,null):Float = Date.now().getTime() / 1000.0;

    /**
     * Internal method called by App to update timer state.
     * @param delta The frame time delta in seconds
     * @param realDelta The real time delta in seconds (unaffected by time scale)
     */
    @:allow(ceramic.App)
    static function update(delta:Float, realDelta:Float):Void {

        now += delta;
        timestamp += realDelta;

        if (next <= now) {
            ceramic.App.app.beginUpdateCallbacks.push(flush);
        }

    }

    /**
     * Process all pending timer callbacks that are ready to execute.
     * Called automatically when timer callbacks are due.
     */
    static function flush():Void {

        next = 999999999;
        var prevCallbacks = callbacks;
        callbacks = [];

        for (i in 0...prevCallbacks.length) {
            var callback = prevCallbacks.unsafeGet(i);

            if (!callback.cleared) {
                #if !ceramic_legacy_timer
                if (callback.owner == null || !callback.owner.destroyed) {
                #end
                    if (callback.time <= now) {
                        if (callback.interval >= 0) {
                            while (callback.time <= now && !callback.cleared) {
                                #if ceramic_check_handlers
                                try {
                                #end
                                    callback.callback();
                                #if ceramic_check_handlers
                                }
                                catch (e:Dynamic) {
                                    log.error('Error in timer callback: ' + e);
                                }
                                #end
                                if (callback.interval == 0) break;
                                callback.time += callback.interval;
                            }
                            if (!callback.cleared) {
                                callbacks.push(callback);
                                next = Math.min(callback.time, next);
                            }
                        }
                        else {
                            #if ceramic_check_handlers
                            try {
                            #end
                                callback.callback();
                            #if ceramic_check_handlers
                            }
                            catch (e:Dynamic) {
                                log.error('Error in timer callback: ' + e);
                            }
                            #end
                        }
                    }
                    else {
                        callbacks.push(callback);
                        next = Math.min(callback.time, next);
                    }
                #if !ceramic_legacy_timer
                }
                else {

                    callback.cleared = true;
                }
                #end
            }
        }

    }

// Public API

    /**
     * Execute a callback after the given delay in seconds.
     *
     * @param owner Optional entity that owns this timer. If provided and the entity
     *              is destroyed, the timer is automatically cancelled.
     * @param seconds The delay in seconds before executing the callback
     * @param callback The function to execute after the delay
     * @return A function that can be called to cancel this timer delay
     *
     * Example:
     * ```haxe
     * // Simple delay
     * Timer.delay(this, 1.0, () -> trace("1 second passed"));
     *
     * // With cancellation
     * var cancel = Timer.delay(this, 5.0, () -> startBossFight());
     * // Cancel if player dies
     * if (playerDied) cancel();
     * ```
     */
    inline public static function delay(#if ceramic_optional_owner ?owner:Entity #else owner:Null<Entity> #end, seconds:Float, callback:Void->Void):Void->Void {

        return schedule(owner, seconds, callback, -1);

    }

    /**
     * Execute a callback periodically at the given interval in seconds.
     *
     * @param owner Optional entity that owns this timer. If provided and the entity
     *              is destroyed, the timer is automatically cancelled.
     * @param seconds The interval in seconds between each callback execution
     * @param callback The function to execute at each interval
     * @return A function that can be called to cancel this timer interval
     *
     * Example:
     * ```haxe
     * // Update every frame (60 FPS)
     * Timer.interval(this, 1/60, () -> updatePhysics());
     *
     * // Spawn enemy every 2 seconds
     * var spawnTimer = Timer.interval(this, 2.0, () -> spawnEnemy());
     *
     * // Stop spawning after 10 seconds
     * Timer.delay(this, 10.0, () -> spawnTimer());
     * ```
     */
    inline public static function interval(#if ceramic_optional_owner ?owner:Entity #else owner:Null<Entity> #end, seconds:Float, callback:Void->Void):Void->Void {

        return schedule(owner, seconds, callback, seconds);

    }

    /**
     * Internal method to schedule a timer callback.
     * @param owner The entity that owns this timer (for auto-cleanup)
     * @param seconds Initial delay before first execution
     * @param callback The function to execute
     * @param interval For repeating timers, the interval between executions. -1 for one-shot timers.
     * @return A function to cancel the timer
     */
    private static function schedule(owner:Entity, seconds:Float, callback:Void->Void, interval:Float):Void->Void {

        // Check handler
        #if ceramic_check_handlers
        if (!Reflect.isFunction(callback)) {
            throw callback + " is not a function!";
        }
        #end

        Assert.assert(callback != null, "Callback must not be null!");

        var time = now + seconds;
        next = Math.min(time, next);

        var timerCallback = new TimerCallback();

        #if ceramic_legacy_timer

        var clearScheduled:Void->Void = null;
        clearScheduled = function() {
            timerCallback.cleared = true;
        };

        var scheduled:Void->Void = null;
        scheduled = function() {
            if (timerCallback.cleared) {
                return;
            }
            if (owner != null && owner.destroyed) {
                timerCallback.cleared = true;
                return;
            }
            callback();
        }

        timerCallback.callback = scheduled;
        timerCallback.time = time;
        timerCallback.interval = interval;

        callbacks.push(timerCallback);

        return clearScheduled;

        #else

        timerCallback.owner = owner;
        timerCallback.callback = callback;
        timerCallback.time = time;
        timerCallback.interval = interval;

        callbacks.push(timerCallback);

        return timerCallback.clear;

        #end

    }

}

/**
 * Internal data structure representing a scheduled timer callback.
 * Tracks the callback function, timing information, and cancellation state.
 */
class TimerCallback {

    /**
     * The entity that owns this timer. If the owner is destroyed,
     * the timer is automatically cancelled.
     */
    public var owner:Entity = null;

    /**
     * The callback function to execute when the timer fires.
     */
    public var callback:Void->Void = null;

    /**
     * The next time (in Timer.now units) when this callback should execute.
     */
    public var time:Float = 0;

    /**
     * For repeating timers, the interval between executions.
     * -1 indicates a one-shot timer.
     */
    public var interval:Float = -1;

    /**
     * Whether this timer has been cancelled and should no longer execute.
     */
    public var cleared:Bool = false;

    public function new() {}

    /**
     * Cancel this timer callback.
     * The callback will not execute again after calling this method.
     */
    public function clear():Void {
        cleared = true;
    }

}

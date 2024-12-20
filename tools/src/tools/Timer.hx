package tools;

import timestamp.Timestamp;

// Substantial portion of this code taken from Ceramic runtime's Timer implementation:
// https://github.com/ceramic-engine/ceramic/blob/8b39d547407f1a8989ce97fc30c38b3f1d95d309/runtime/src/ceramic/Timer.hx

class Timer {

    var callbacks:Array<TimerCallback> = [];

    var next:Float = 999999999;

    public function new() {}

    /**
     * Current time, relative to app.
     * (number of active seconds since app was started)
     */
    public var now(default, null):Float = 0;

    /**
     * Current unix time synchronized with  Timer.
     * `Timer.now` and `Timer.timestamp` are garanteed to get incremented
     * exactly at the same rate, except when app frame real delta > 1s
     * (number of seconds since January 1st, 1970)
     */
    public var timestamp(get, null):Float;

    inline function get_timestamp():Float {
        return startTimestamp + now;
    }

    public var startTimestamp(default, null):Float = Timestamp.now();

    @:noCompletion public function update():Void {

        final delta = Timestamp.now() - timestamp;

        now += delta;
        timestamp += delta;

        if (next <= now) {
            flush();
        }

    }

    function flush():Void {

        next = 999999999;
        var prevCallbacks = callbacks;
        callbacks = [];

        for (i in 0...prevCallbacks.length) {
            var callback = prevCallbacks[i];

            if (!callback.cleared) {
                if (callback.time <= now) {
                    if (callback.interval >= 0) {
                        while (callback.time <= now && !callback.cleared) {
                            #if timer_check_handlers
                            try {
                            #end
                                callback.callback();
                            #if timer_check_handlers
                            }
                            catch (e:Dynamic) {
                                .log.error('Error in timer callback: ' + e);
                            }
                            #end
                            if (callback.interval == 0)
                                break;
                            callback.time += callback.interval;
                        }
                        if (!callback.cleared) {
                            callbacks.push(callback);
                            next = Math.min(callback.time, next);
                        }
                    }
                    else {
                        #if timer_check_handlers
                        try {
                        #end
                            callback.callback();
                        #if timer_check_handlers
                        }
                        catch (e:Dynamic) {
                            .log.error('Error in timer callback: ' + e);
                        }
                        #end
                    }
                }
                else {
                    callbacks.push(callback);
                    next = Math.min(callback.time, next);
                }
            }
        }

    }

    // Public API

    /**
     * Execute a callback after the given delay in seconds.
     * @return a function to cancel this timer delay
     */
    inline public function delay(seconds:Float, callback:Void->Void):Void->Void {

        return schedule(seconds, callback, -1);

    }

    /**
     * Execute a callback periodically at the given interval in seconds.
     * @return a function to cancel this timer interval
     */
    inline public function interval(seconds:Float, callback:Void->Void):Void->Void {

        return schedule(seconds, callback, seconds);

    }

    private function schedule(seconds:Float, callback:Void->Void, interval:Float):Void->Void {

        // Check handler
        #if timer_check_handlers
        if (!Reflect.isFunction(callback)) {
            throw callback + " is not a function!";
        }
        #end

        if (callback == null)
            throw "Callback must not be null!";

        var time = now + seconds;
        next = Math.min(time, next);

        var timerCallback = new TimerCallback();

        timerCallback.callback = callback;
        timerCallback.time = time;
        timerCallback.interval = interval;

        callbacks.push(timerCallback);

        return timerCallback.clear;

    }

}

class TimerCallback {

    public var rnd:Int = -1;

    public var callback:() -> Void = null;

    public var time:Float = 0;

    public var interval:Float = -1;

    public var cleared:Bool = false;

    public function new() {}

    public function clear():Void {
        cleared = true;
        rnd = Std.random(9999) + 10;
    }

}

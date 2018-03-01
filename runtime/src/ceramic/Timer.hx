package ceramic;

class Timer {

    static var callbacks:Array<TimerCallback> = [];
    static var next:Float = 999999999;

    /** Current time, relative to app.
        (number of active seconds since app was started) */
    public static var now:Float = 0;

    @:allow(ceramic.App)
    static function update(delta:Float):Void {

        now += delta;

        if (next <= now) {

            next = 999999999;
            var prevCallbacks = callbacks;
            callbacks = [];

            for (callback in prevCallbacks) {
                if (callback.time <= now) {
                    callback.callback();
                    callback.called = true;
                }
                else {
                    callbacks.push(callback);
                    next = Math.min(callback.time, next);
                }
            }
        }

    } //update

// Public API

    public static function delay(seconds:Float, callback:Void->Void):Void {

        var time = now + seconds;
        next = Math.min(time, next);

        callbacks.push(new TimerCallback(callback, time));

    } //delay

    public static function interval(seconds:Float, callback:Void->Void):Void->Void {

        var stop = false;

        var clearInterval = function() {
            stop = true;
        };

        var tick:Void->Void = null;
        tick = function() {
            if (stop) return;
            callback();
            if (!stop) delay(seconds, tick);
        }
        
        delay(seconds, tick);

        return clearInterval;

    } //interval

} //Timer

class TimerCallback {

    public var callback:Void->Void;
    public var time:Float;
    public var called:Bool = false;

    public function new(callback:Void->Void, time:Float) {

        this.callback = callback;
        this.time = time;

    } //new

} //TimerCallback

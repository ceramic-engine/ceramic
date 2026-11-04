package ceramic;

/**
 * Key repeat for a backend whose platform layer gives no repeated key down
 * events (Unity's Input System): like the system, only the last pressed key
 * repeats, first after `delay` seconds, then every `interval` seconds, until
 * it is released or another key is pressed.
 */
class KeyRepeatTimer {

    /** Seconds before the first repeat. */
    public var delay:Float;

    /** Seconds between two repeats. */
    public var interval:Float;

    /** Most repeats returned by one `update()` (a long frame does not flood the app). */
    public var maxPerUpdate:Int = 8;

    /** The key that repeats (an id chosen by the backend), or -1. */
    public var key(default, null):Int = -1;

    var elapsed:Float = 0;

    var next:Float = 0;

    public function new(delay:Float = 0.5, interval:Float = 0.033) {

        this.delay = delay;
        this.interval = interval;

    }

    /** A key was pressed: it becomes the key that repeats. */
    public function press(key:Int):Void {

        this.key = key;
        elapsed = 0;
        next = delay;

    }

    /** A key was released: the repeat stops if it was the key that repeats. */
    public function release(key:Int):Void {

        if (this.key == key) {
            this.key = -1;
        }

    }

    /** Stops the repeat. */
    public function stop():Void {

        key = -1;

    }

    /**
     * Advances the time of the key that repeats.
     * @param delta Seconds since the previous update
     * @return The number of repeats to emit now
     */
    public function update(delta:Float):Int {

        if (key == -1 || delta <= 0) return 0;

        elapsed += delta;
        if (elapsed < next) return 0;

        final step = interval > 0.001 ? interval : 0.001;
        var count = Math.floor((elapsed - next) / step) + 1;
        next += count * step;
        if (count > maxPerUpdate) {
            count = maxPerUpdate;
        }
        return count;

    }

}

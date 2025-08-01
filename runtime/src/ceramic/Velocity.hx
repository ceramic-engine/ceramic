package ceramic;

/**
 * A velocity tracker that calculates speed based on position changes over time.
 * 
 * This class tracks position samples over a time window and calculates velocity
 * based on the distance traveled divided by the elapsed time. It's commonly used
 * for touch/drag interactions to determine fling velocity or for any motion
 * that needs velocity tracking.
 * 
 * The tracker automatically prunes old samples outside a 150ms window to ensure
 * velocity calculations remain responsive to recent motion.
 * 
 * Example usage:
 * ```haxe
 * var velocity = new Velocity();
 * 
 * // During drag/motion updates
 * velocity.add(currentPosition);
 * 
 * // When motion ends
 * var speed = velocity.get(); // pixels per second
 * 
 * // Apply inertia based on velocity
 * if (Math.abs(speed) > threshold) {
 *     startInertiaAnimation(speed);
 * }
 * ```
 */
class Velocity {

    /**
     * Array storing position samples.
     */
    var positions:Array<Float> = [];

    /**
     * Array storing the time (in seconds) when each position was recorded.
     */
    var times:Array<Float> = [];

    /**
     * Create a new velocity tracker.
     */
    public function new() {

    }
    
    /**
     * Reset the velocity tracker, clearing all position and time samples.
     * After calling this, get() will return 0 until new samples are added.
     */
    public function reset():Void {

        // Remove all values
        var len = times.length;
        while (len > 0) {
            times.shift();
            positions.shift();
            len--;
        }

    }

    /**
     * Add a position sample to the velocity tracker.
     * 
     * @param position The current position value (e.g., x or y coordinate)
     * @param minusDelta Optional time offset in seconds to subtract from the current time.
     *                   Useful when the position data is slightly delayed.
     */
    public function add(position:Float, minusDelta:Float = 0):Void {

        var now = Timer.now - minusDelta;

        positions.push(position);
        times.push(now);

        prune(now - 0.15);

    }

    /**
     * Calculate the current velocity based on recent position samples.
     * 
     * The velocity is calculated as the distance between the first and last samples
     * divided by the time elapsed, using samples from the last 150ms.
     * 
     * @return The velocity in units per second (e.g., pixels per second).
     *         Returns 0 if there are fewer than 2 samples.
     */
    public function get():Float {

        var now = Timer.now;

        prune(now - 0.15);

        var len = times.length;
        if (len < 2) return 0;

        var distance = positions[len - 1] - positions[0];
        var time = times[len - 1] - times[0];

        if (time <= 0) return 0;

        return distance / Math.max(0.15, time);

    }

/// Internal

    /**
     * Remove position samples older than the specified time.
     * This keeps the velocity calculation based on recent motion only.
     * 
     * @param expireTime The time threshold - samples older than this are removed
     */
    function prune(expireTime:Float):Void {

        // Remove expired values
        var len = times.length;
        while (len > 0 && times[0] <= expireTime) {
            times.shift();
            positions.shift();
            len--;
        }

    }

/// Print

    /**
     * Get a string representation of the current velocity.
     * 
     * @return The current velocity as a string
     */
    function toString():String {

        return '' + get();

    }

} // Velocity

package ceramic;

using ceramic.Extensions;

/**
 * A utility class for calculating frames per second (FPS) using a rolling average.
 * 
 * ComputeFps maintains a circular buffer of recent frame times and calculates
 * the average FPS over a configurable number of frames. This provides a more
 * stable FPS reading than calculating from individual frame deltas.
 * 
 * ## Features
 * 
 * - **Rolling Average**: Smooths out FPS spikes and dips
 * - **Configurable Window**: Choose how many frames to average
 * - **Capped Maximum**: FPS capped at 999 to prevent display issues
 * - **Lightweight**: Minimal memory overhead with fixed buffer
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var fpsCounter = new ComputeFps(30); // Average over 30 frames
 * 
 * // In your update loop
 * function update(delta:Float) {
 *     fpsCounter.addFrame(delta);
 *     trace('Current FPS: ' + fpsCounter.fps);
 * }
 * ```
 * 
 * @see ceramic.App#fps For the engine's built-in FPS counter
 */
class ComputeFps {

    /**
     * Circular buffer storing recent frame delta times.
     * Size is fixed at construction.
     */
    var frames:Array<Float>;

    /**
     * Current position in the circular buffer.
     * Wraps around when reaching the buffer size.
     */
    var index:Int = 0;

    /**
     * Number of frames to average over.
     * Larger values provide more stable readings.
     */
    var size:Int;

    /**
     * The current calculated frames per second.
     * 
     * This value is updated each time addFrame() is called and represents
     * the average FPS over the last 'size' frames. Read-only from outside
     * the class.
     * 
     * Range: 0-999
     */
    public var fps(default, null):Int = 0;

    /**
     * Creates a new FPS calculator.
     * 
     * @param size Number of frames to use for the rolling average.
     *             Larger values provide smoother results but slower response
     *             to FPS changes. Default: 10
     * 
     * ```haxe
     * // Quick response (10 frames)
     * var fpsFast = new ComputeFps(10);
     * 
     * // Smooth reading (60 frames)
     * var fpsSmooth = new ComputeFps(60);
     * ```
     */
    public function new(size:Int = 10) {

        this.size = size;

        frames = [];
        for (i in 0...size) {
            frames.push(0);
        }

    }

    /**
     * Records a frame and updates the FPS calculation.
     * 
     * Call this method once per frame with the time elapsed since the last frame.
     * The FPS value is automatically updated based on the rolling average of
     * recent frame times.
     * 
     * @param delta Time elapsed since last frame in seconds (e.g., 0.016 for 60 FPS)
     * 
     * ```haxe
     * // In your game loop
     * var lastTime = Timer.now();
     * 
     * function update() {
     *     var currentTime = Timer.now();
     *     var delta = currentTime - lastTime;
     *     lastTime = currentTime;
     *     
     *     fpsCounter.addFrame(delta);
     *     // fpsCounter.fps now contains updated FPS
     * }
     * ```
     */
    public function addFrame(delta:Float) {

        frames.unsafeSet(index, delta);
        index = (index + 1) % size;

        var newFps = 0.0;
        for (i in 0...size) {
            newFps += frames.unsafeGet(i);
        }
        if (newFps > 0) {
            newFps = size / newFps;
        }
        else {
            newFps = 0;
        }

        this.fps = Math.round(Math.min(999, newFps));

    }

}

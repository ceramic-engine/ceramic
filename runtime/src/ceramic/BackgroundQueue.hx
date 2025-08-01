package ceramic;

#if (cpp || cs)
#if (haxe_ver < 4)
import cpp.vm.Mutex;
#else
import sys.thread.Mutex;
#end
#end

/**
 * A thread-safe queue for executing functions serially in a background thread.
 * 
 * BackgroundQueue provides a mechanism to offload work from the main thread while ensuring
 * that queued functions execute one at a time in the order they were scheduled. This is
 * useful for operations that should not block the main thread but need to maintain
 * sequential execution order.
 * 
 * ## Features
 * 
 * - **Serial Execution**: Functions are executed one after another, never in parallel
 * - **Thread Safety**: Safe to schedule functions from any thread
 * - **Platform Adaptive**: Falls back to main thread execution on platforms without threading
 * - **Automatic Cleanup**: Stops background thread when destroyed
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var queue = new BackgroundQueue();
 * 
 * // Schedule work to run in background
 * queue.schedule(() -> {
 *     // Perform expensive computation
 *     var result = processLargeDataSet();
 *     
 *     // Post result back to main thread
 *     app.onceImmediate(() -> {
 *         updateUI(result);
 *     });
 * });
 * 
 * // Multiple operations execute in order
 * queue.schedule(() -> loadFile("data1.json"));
 * queue.schedule(() -> loadFile("data2.json"));
 * queue.schedule(() -> processAllData());
 * ```
 * 
 * ## Platform Support
 * 
 * - **C++/C#**: Uses native threading with mutex synchronization
 * - **JavaScript/Other**: Falls back to immediate execution on main thread
 * 
 * @see ceramic.Runner
 */
#if (android && clay_sdl)
@:headerCode('#include "linc_sdl.h"')
#end
class BackgroundQueue extends Entity {

    /**
     * Time interval between each checks to see if there is something to run.
     * Lower values provide more responsive execution at the cost of higher CPU usage.
     * 
     * Default: 0.1 seconds (100ms)
     */
    public var checkInterval:Float = 0.1;

    /**
     * Whether this queue is running functions in a background thread.
     * False on platforms without threading support.
     */
    var runsInBackground:Bool = false;

    /**
     * Flag to signal the background thread to stop.
     * Set to true when destroy() is called.
     */
    var stop:Bool = false;

    /**
     * Queue of functions waiting to be executed.
     * Protected by mutex on threaded platforms.
     */
    var pending:Array<Void->Void> = [];

    #if (cpp || cs)
    /**
     * Mutex for thread-safe access to the pending queue.
     * Only available on platforms with threading support.
     */
    var mutex:Mutex;
    #end

    /**
     * Creates a new background queue.
     * 
     * On platforms with threading support (C++/C#), starts a background thread
     * that polls for work at the specified interval.
     * 
     * @param checkInterval Time in seconds between queue checks (default: 0.1)
     */
    public function new(checkInterval:Float = 0.1) {

        super();

        this.checkInterval = 0.1;

        #if (cpp || cs)
        mutex = new Mutex();
        runsInBackground = true;
        Runner.runInBackground(internalRunInBackground);
        #end

    }

    /**
     * Schedules a function to be executed in the background queue.
     * 
     * Functions are executed in the order they are scheduled, with each function
     * completing before the next one starts. On platforms without threading,
     * the function is executed immediately on the main thread.
     * 
     * @param fn The function to execute in the background
     * 
     * @example
     * ```haxe
     * queue.schedule(() -> {
     *     // This runs in background thread
     *     var data = loadLargeFile();
     *     processData(data);
     * });
     * ```
     */
    public function schedule(fn:Void->Void):Void {

        #if (cpp || cs)

        // Run in background with ceramic.Runner
        mutex.acquire();
        pending.push(fn);
        mutex.release();

        #else

        // Defer in main thread if background threading is not available
        ceramic.App.app.onceImmediate(fn);

        #end

    }

    #if (cpp || cs)

    /**
     * The main loop of the background thread.
     * 
     * Continuously checks for pending functions and executes them serially.
     * Sleeps for checkInterval when no work is available to reduce CPU usage.
     * 
     * Platform-specific initialization:
     * - Android: Attaches thread to JNI for Java calls
     * - C#: Sets thread culture for consistent formatting
     */
    private function internalRunInBackground():Void {

        #if (android && clay_sdl)
        // This lets us attach thread to JNI.
        // Required because some JNI calls could be done in background
        untyped __cpp__('SDL_GetAndroidJNIEnv()');
        #end

        #if cs
        untyped __cs__('global::System.Threading.Thread.CurrentThread.CurrentCulture = global::System.Globalization.CultureInfo.CreateSpecificCulture("en-GB")');
        #end

        while (!stop) {
            var shouldSleep = true;

            mutex.acquire();
            if (pending.length > 0) {
                var fn = pending.pop();
                mutex.release();

                shouldSleep = false;
                fn();
            }
            else {
                mutex.release();
            }

            if (shouldSleep) {
                Sys.sleep(checkInterval);
            }
        }

    }

    #end

    /**
     * Destroys the background queue and stops its thread.
     * 
     * Sets the stop flag which causes the background thread to exit its
     * main loop. Any pending functions that have not yet started will
     * not be executed.
     */
    override function destroy():Void {

        super.destroy();

        stop = true;

    }

}

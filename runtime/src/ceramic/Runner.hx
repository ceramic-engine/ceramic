package ceramic;

// Original source: https://gist.github.com/underscorediscovery/e66e72ec702bdcedf5af45f8f4712109

#if (cpp || cs)
#if (haxe_ver < 4)
    import cpp.vm.Thread;
    import cpp.vm.Deque;
#else
    import sys.thread.Thread;
    import sys.thread.Deque;
#end
#end

import ceramic.Shortcuts.*;

/**
 * Cross-platform thread management utility for executing code on main and background threads.
 * 
 * Runner provides a simple interface for thread management in Ceramic, supporting both
 * platforms with native threading (C++/C#) and single-threaded environments (JS/Web).
 * It ensures safe execution of code on the main thread from background threads and
 * vice versa.
 * 
 * Key features:
 * - Main thread callback execution from background threads
 * - Background thread creation on supported platforms
 * - Graceful fallback to deferred execution on single-threaded platforms
 * - Thread-safe queue for main thread callbacks
 * 
 * Platform behavior:
 * - **C++/C#**: Full threading support with real background threads
 * - **JS/Web**: Emulates background execution using immediate callbacks
 * 
 * Usage example:
 * ```haxe
 * // Initialize on app start (main thread)
 * Runner.init();
 * 
 * // In your main loop
 * Runner.tick();
 * 
 * // Run heavy computation in background
 * Runner.runInBackground(() -> {
 *     var result = performHeavyCalculation();
 *     // Update UI on main thread
 *     Runner.runInMain(() -> {
 *         updateUI(result);
 *     });
 * });
 * ```
 * 
 * @see App
 * @see System
 */
class Runner {

    #if (cpp || cs)

    /**
     * Reference to the main thread.
     * Set during initialization to identify the primary thread for callback execution.
     */
    static var mainThread:Thread;

    /**
     * Thread-safe queue for storing callbacks to be executed on the main thread.
     * Background threads push callbacks here, and the main thread processes them during tick().
     */
    static var queue:Deque<Void->Void>;

    #end

    /**
     * Checks if the current thread is the main thread.
     * 
     * This method is useful for determining execution context and ensuring
     * thread-safe operations. On single-threaded platforms, this always
     * returns true.
     * 
     * @return `true` if executing on the main thread, `false` otherwise
     */
    public inline static function currentIsMainThread():Bool {
        
        #if (cpp || cs)
        return mainThread == null || mainThread == Thread.current();
        #else
        return true;
        #end

    }

    /**
     * Initializes the Runner system on the main thread.
     * 
     * This method must be called from the main thread before using any other
     * Runner functionality. It sets up the internal queue for thread communication
     * and marks the calling thread as the main thread.
     * 
     * Typically called during application initialization.
     * 
     * @see App#new
     */
    @:noCompletion public static function init() {
        #if (cpp || cs)
        queue = new Deque<Void->Void>();
        mainThread = Thread.current();
        #end
    }

    /**
     * Processes pending callbacks on the main thread.
     * 
     * This method should be called periodically from the main thread (typically
     * in the main loop) to execute any callbacks queued by background threads.
     * It processes all pending callbacks in the queue without blocking.
     * 
     * On single-threaded platforms, this is a no-op as callbacks are handled
     * through immediate execution.
     * 
     * @see App#update
     */
    @:noCompletion public static function tick():Void {

        #if (cpp || cs)
        var more = true;
        var count = 0;

        while (more) {
            var item = queue.pop(false);
            if (item != null) {
                count++; item(); item = null;
            } else {
                more = false; break;
            }
        }
        #end

    }

    /**
     * Checks if background execution is emulated on the current platform.
     * 
     * Some platforms (like JavaScript/Web) don't support true threading, so
     * background execution is emulated using deferred callbacks on the main thread.
     * This method helps code adapt to platform capabilities.
     * 
     * @return `true` if background threads are emulated (JS/Web), `false` if real threads are available (C++/C#)
     */
    inline public static function isEmulatingBackgroundWithMain():Bool {

        #if (cpp || cs)
        return false;
        #else
        return true;
        #end

    }

    /**
     * Schedules a function to run on the main thread.
     * 
     * This method queues the given function for execution on the main thread.
     * The function will be executed during the next `tick()` call. This is
     * particularly useful for updating UI or accessing main-thread-only resources
     * from background threads.
     * 
     * The call is non-blocking and doesn't wait for the function to complete.
     * 
     * Example:
     * ```haxe
     * Runner.runInMain(() -> {
     *     myVisual.alpha = 0.5; // Safe UI update
     * });
     * ```
     * 
     * @param _fn The function to execute on the main thread
     */
    public static function runInMain(_fn:Void->Void) {

        #if (cpp || cs)
        queue.push(_fn);
        #else
        app.onceImmediate(_fn);
        #end

    }

    /**
     * Executes a function on a background thread.
     * 
     * On platforms with threading support (C++/C#), this creates a new thread
     * to execute the function. On single-threaded platforms (JS/Web), the
     * function is scheduled for deferred execution on the main thread.
     * 
     * This is useful for offloading heavy computations or I/O operations
     * without blocking the main thread.
     * 
     * Example:
     * ```haxe
     * Runner.runInBackground(() -> {
     *     // Heavy computation
     *     var data = processLargeDataset();
     *     
     *     // Return result to main thread
     *     Runner.runInMain(() -> {
     *         handleProcessedData(data);
     *     });
     * });
     * ```
     * 
     * @param fn The function to execute in the background
     */
    public static function runInBackground(fn:Void->Void):Void {

        #if (cpp || cs)
        Thread.create(fn);
        #else
        app.onceImmediate(fn);
        #end

    }

}
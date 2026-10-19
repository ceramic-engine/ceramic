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

#if (android && cpp)
@:cppFileCode('
#include <sched.h>
#include <stdio.h>
#include <unistd.h>
#include <mutex>
#include <string>
#include <vector>

namespace ceramic_thread_cores {

    static std::mutex mutex;
    static bool initialized = false;
    static bool available = false;
    static cpu_set_t all;
    static cpu_set_t slow;
    static cpu_set_t fast;
    static cpu_set_t fastest;
    static std::string description;

    static long maxFrequency(int cpu) {
        char path[128];
        snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpu%d/cpufreq/cpuinfo_max_freq", cpu);
        FILE* file = fopen(path, "r");
        if (file == nullptr) return -1;
        long value = -1;
        if (fscanf(file, "%ld", &value) != 1) value = -1;
        fclose(file);
        return value;
    }

    static std::string list(cpu_set_t* set, int count) {
        std::string result;
        for (int i = 0; i < count; i++) {
            if (!CPU_ISSET(i, set)) continue;
            if (!result.empty()) result += ",";
            result += std::to_string(i);
        }
        return result;
    }

    // The clusters, from the maximum frequency of each core
    static void init() {
        initialized = true;
        int count = (int)sysconf(_SC_NPROCESSORS_CONF);
        if (count <= 0 || count > CPU_SETSIZE) return;
        std::vector<long> frequencies(count);
        long lowest = -1;
        long highest = -1;
        for (int i = 0; i < count; i++) {
            frequencies[i] = maxFrequency(i);
            if (frequencies[i] <= 0) return;
            if (lowest < 0 || frequencies[i] < lowest) lowest = frequencies[i];
            if (frequencies[i] > highest) highest = frequencies[i];
        }
        if (lowest == highest) return;
        CPU_ZERO(&all);
        CPU_ZERO(&slow);
        CPU_ZERO(&fast);
        CPU_ZERO(&fastest);
        for (int i = 0; i < count; i++) {
            CPU_SET(i, &all);
            if (frequencies[i] == lowest) CPU_SET(i, &slow);
            else CPU_SET(i, &fast);
            if (frequencies[i] == highest) CPU_SET(i, &fastest);
        }
        available = true;
        description = "slow=" + list(&slow, count) + " fast=" + list(&fast, count) + " fastest=" + list(&fastest, count);
    }

    static bool apply(int cores, bool* first) {
        std::lock_guard<std::mutex> lock(mutex);
        *first = !initialized;
        if (!initialized) init();
        if (!available) return false;
        cpu_set_t* set = cores == 1 ? &slow : cores == 2 ? &fast : cores == 3 ? &fastest : &all;
        // The kernel keeps the cores the app is allowed (its cpuset) out of the ones asked
        return sched_setaffinity(0, sizeof(cpu_set_t), set) == 0;
    }

    static const char* describe() {
        std::lock_guard<std::mutex> lock(mutex);
        return available ? description.c_str() : "one cluster or unknown";
    }

}
')
#end

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

    /**
     * Makes the calling thread run on the given kind of cores (see `ThreadCores`), on
     * Android devices whose cores are not all the same. Returns `true` if the choice was
     * applied, `false` where it has no effect (other platforms, cores all the same, cores
     * not allowed to the app right now).
     *
     * Android may reset the cores of the threads of the app when it goes to the
     * background and comes back: a long-lived thread should apply its choice again from
     * time to time, for instance before each piece of work (the call is cheap).
     */
    public static function setThreadCores(cores:ThreadCores):Bool {

        #if (android && cpp)
        var first = false;
        final applied:Bool = untyped __cpp__('::ceramic_thread_cores::apply({0}, &{1})', (cores:Int), first);
        if (first) {
            final description:String = untyped __cpp__('::String(::ceramic_thread_cores::describe())');
            runInMain(() -> log.info('Thread cores: ' + description));
        }
        return applied;
        #else
        return false;
        #end

    }

}
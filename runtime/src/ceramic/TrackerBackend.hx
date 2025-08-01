package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * Backend adapter that bridges the Tracker observable framework with Ceramic's backend services.
 * 
 * TrackerBackend provides a unified interface for the Tracker framework to access
 * platform-specific functionality through Ceramic's backend system. It handles
 * threading, persistence, logging, timers, and file system operations in a
 * platform-agnostic way.
 * 
 * This class is used internally by the Tracker framework and typically doesn't
 * need to be accessed directly by application code. It ensures that observable
 * objects and reactive systems can leverage Ceramic's full feature set.
 * 
 * Key responsibilities:
 * - **Scheduling**: Immediate callbacks and background execution
 * - **Persistence**: String-based key-value storage
 * - **Logging**: Warning, error, and success messages
 * - **Threading**: Background and main thread execution
 * - **Timers**: Intervals and delayed callbacks
 * - **File System**: Storage directory and path operations
 * 
 * @see tracker.Observable
 * @see tracker.Tracker
 * @see BackgroundQueue
 */
class TrackerBackend {

    /**
     * Queue for managing background task execution.
     * Handles scheduling and execution of tasks on background threads when available.
     */
    var backgroundQueue:BackgroundQueue;

    /**
     * Creates a new TrackerBackend instance.
     * Initializes the background queue for task scheduling.
     */
    public function new() {

        backgroundQueue = new BackgroundQueue();

    }

    /**
     * Schedules a callback to run on the next frame or event loop iteration.
     * 
     * The callback is queued and will be executed during the next update cycle.
     * This is useful for deferring operations that should happen after the current
     * call stack completes.
     * 
     * @param handleImmediate The callback to schedule for immediate execution
     */
    inline public function onceImmediate(handleImmediate:Void->Void):Void {

        app.onceImmediate(handleImmediate);

    }

    /**
     * Read a string for the given key
     * @param key the key to use
     * @return String or null of no string was found
     */
    inline public function readString(key:String):String {

        return app.backend.io.readString(key);

    }

    /**
     * Save a string for the given key
     * @param key the key to use
     * @param str the string to save
     * @return Bool `true` if the save was successful
     */
    inline public function saveString(key:String, str:String):Bool {

        return app.backend.io.saveString(key, str);

    }

    /**
     * Append a string on the given key. If the key doesn't exist,
     * creates a new one with the string to append.
     * @param key the key to use
     * @param str the string to append
     * @return Bool `true` if the save was successful
     */
    inline public function appendString(key:String, str:String):Bool {

        return app.backend.io.appendString(key, str);

    }

    /**
     * Log a warning message
     * @param message the warning message
     */
    inline public function warning(message:Dynamic, ?pos:haxe.PosInfos):Void {

        log.warning(message, pos);

    }

    /**
     * Log an error message
     * @param error the error message
     */
    inline public function error(error:Dynamic, ?pos:haxe.PosInfos):Void {

        log.error(error, pos);

    }

    /**
     * Log a success message
     * @param message the success message
     */
    inline public function success(message:Dynamic, ?pos:haxe.PosInfos):Void {

        log.success(message, pos);

    }

    /**
     * Executes a callback on a background thread when available.
     * 
     * On platforms with threading support, the callback runs on a separate thread.
     * On single-threaded platforms (like web), the callback is queued and executed
     * on the main thread to maintain compatibility.
     * 
     * Use this for CPU-intensive operations that shouldn't block the UI.
     * 
     * @param callback The function to execute in the background
     */
    inline public function runInBackground(callback:Void->Void):Void {

        backgroundQueue.schedule(callback);

    }

    /**
     * Schedules a callback to run on the main thread.
     * 
     * If called from a background thread, the callback is queued for execution
     * on the main thread. If already on the main thread, the callback may be
     * executed immediately or queued depending on the implementation.
     * 
     * Essential for updating UI or accessing main-thread-only resources from
     * background threads.
     * 
     * @param callback The function to execute on the main thread
     */
    inline public function runInMain(callback:Void->Void):Void {

        Runner.runInMain(callback);

    }

    /**
     * Execute a callback periodically at the given interval in seconds.
     * @param owner The entity that owns this interval
     * @param seconds The time in seconds between each call
     * @param callback The callback to call
     * @return Void->Void A callback to cancel the interval
     */
    inline public function interval(owner:Entity, seconds:Float, callback:Void->Void):Void->Void {

        return Timer.interval(owner, seconds, callback);

    }

    /**
     * Execute a callback after the given delay in seconds.
     * @param owner The entity that owns this delayed call
     * @param seconds The time in seconds of delay before the call
     * @param callback The callback to call
     * @return Void->Void A callback to cancel the delayed call
     */
    inline public function delay(owner:Entity, seconds:Float, callback:Void->Void):Void->Void {

        return Timer.delay(owner, seconds, callback);

    }

    /**
     * Gets the platform-specific storage directory for persistent data.
     * 
     * Returns a writable directory path where the application can store
     * user data, save files, and preferences. The location varies by platform:
     * - Desktop: User's app data directory
     * - Mobile: App's private storage
     * - Web: May return null (use other storage methods)
     * 
     * @return The storage directory path, or null if not available
     */
    inline public function storageDirectory():Null<String> {

        return app.backend.info.storageDirectory();

    }

    /**
     * Joins multiple path segments into a single path string.
     * 
     * Handles platform-specific path separators and resolves relative paths.
     * Useful for building file paths in a cross-platform way.
     * 
     * Example:
     * ```haxe
     * pathJoin(["assets", "images", "player.png"]); // "assets/images/player.png"
     * ```
     * 
     * @param paths Array of path segments to join
     * @return The combined path with appropriate separators
     */
    inline public function pathJoin(paths:Array<String>):String {

        return ceramic.Path.join(paths);

    }

}

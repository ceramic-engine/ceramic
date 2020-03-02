package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

class TrackerBackend {

    var backgroundQueue:BackgroundQueue;

    public function new() {

        backgroundQueue = new BackgroundQueue();

    }

    /**
     * Schedule immediate callback. These callbacks need to be flushed at some point by the backend
     * @param handleImmediate the callback to schedule
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
     * Run the given callback in background, if there is any background thread available
     * on this backend. Run it on the main thread otherwise like any other code
     * @param callback 
     */
    inline public function runInBackground(callback:Void->Void):Void {

        backgroundQueue.schedule(callback);

    }

    /**
     * Run the given callback in main thread
     * @param callback 
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

}

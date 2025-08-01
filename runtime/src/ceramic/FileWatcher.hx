package ceramic;

#if (sys || hxnodejs || nodejs || node)
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Cross-platform file monitoring system for hot-reloading and file change detection.
 * 
 * FileWatcher provides a unified API for monitoring file changes across different platforms
 * including native (sys), Node.js, and Electron environments. It periodically checks for
 * file modifications and notifies registered callbacks when changes are detected.
 * 
 * The watcher can operate in two modes:
 * - Content checking mode (default): Compares actual file content to detect changes
 * - Timestamp mode: Only checks modification time (faster but less reliable)
 * 
 * This implementation is compatible with the interpret.Watcher interface, allowing it
 * to be used with scripting and hot-reload systems.
 * 
 * Example:
 * ```haxe
 * var watcher = new FileWatcher();
 * var stopWatching = watcher.watch("config.json", function(content) {
 *     trace("Config file changed: " + content);
 * });
 * 
 * // Later, to stop watching:
 * stopWatching();
 * ```
 * 
 * @see ceramic.Entity
 */
class FileWatcher extends Entity #if interpret implements interpret.Watcher #end {

    /**
     * The interval in seconds between file checks.
     * Lower values provide faster detection but use more CPU.
     * Default: 1.0 second
     */
    public static var UPDATE_INTERVAL:Float = 1.0;

    #if web
    static var testedElectronAvailability:Bool = false;
    static var electron:Dynamic = null;
    #end

    /**
     * Whether to compare actual file content or just modification times.
     * 
     * When true (default), the watcher reads and compares file content to detect
     * changes, which is more reliable but slower. When false, only modification
     * timestamps are checked, which is faster but may miss some changes.
     */
    var checkContent:Bool = true;

    /**
     * Map of file paths to their watched state information.
     */
    var watched:Map<String,WatchedFile> = new Map();

    /**
     * Accumulator for time since last file check.
     */
    var timeSinceLastCheck:Float = 0.0;

    public function new() {

        super();

        #if (web && ceramic_use_electron)
        if (!testedElectronAvailability) {
            testedElectronAvailability = true;
            try {
                electron = ceramic.Platform.resolveElectron();
            }
            catch (e:Dynamic) {}
        }
        #end

        ceramic.App.app.onUpdate(this, tick);

    }

    /**
     * Checks if file watching is supported on the current platform.
     * 
     * @return True if the platform supports file watching, false otherwise
     */
    public function canWatch():Bool {

        #if (!sys && !hxnodejs && !nodejs && !node)

        #if web
        if (electron == null) {
        #end
            return false;
        #if web
        }
        else {
            return true;
        }
        #end

        #else
        return true;
        #end

    }

    /**
     * Starts watching a file for changes.
     * 
     * Multiple callbacks can be registered for the same file. Each callback
     * receives the new file content when a change is detected.
     * 
     * Example:
     * ```haxe
     * var stop = watcher.watch("data.txt", function(content) {
     *     trace("File updated with content: " + content);
     * });
     * ```
     * 
     * @param path The file path to watch
     * @param onUpdate Callback function that receives the new file content
     * @return A function that stops watching when called
     */
    public function watch(path:String, onUpdate:String->Void):Void->Void {

        if (!canWatch()) {
            trace('[warning] Cannot watch file at path $path with StandardWatcher on this target');
            return function() {};
        }

        var watchedFile = watched.get(path);
        if (watchedFile == null) {
            watchedFile = new WatchedFile();
            watched.set(path, watchedFile);
        }
        watchedFile.updateCallbacks.push(onUpdate);

        var stopped = false;
        var stopWatching = function() {
            if (stopped) return;
            stopped = true;
            var watchedFile = watched.get(path);
            watchedFile.updateCallbacks.remove(onUpdate);
            if (watchedFile.updateCallbacks.length == 0) {
                watched.remove(path);
            }
        };

        return stopWatching;

    }

    override public function destroy() {

        super.destroy();

        ceramic.App.app.offUpdate(tick);

    }

/// Internal

    /**
     * Update tick called by the app's update loop.
     * Checks all watched files for changes at the configured interval.
     */

    function tick(delta:Float) {

        if (destroyed) return;

        timeSinceLastCheck += delta;
        if (timeSinceLastCheck < UPDATE_INTERVAL) return;
        timeSinceLastCheck = 0.0;

        if (!canWatch()) return;

        for (path in watched.keys()) {
            if (isFile(path)) {
                var mtime = lastModified(path);
                var watchedFile = watched.get(path);
                if (watchedFile.mtime != -1 && mtime > watchedFile.mtime) {
                    // File modification time has changed
                    watchedFile.mtime = mtime;
                    if (checkContent) {
                        var content = getContent(path);

                        if (content != watchedFile.content) {
                            watchedFile.content = content;

                            // File content has changed, notify
                            for (i in 0...watchedFile.updateCallbacks.length) {
                                watchedFile.updateCallbacks[i](watchedFile.content);
                            }
                        }
                    }
                    else {
                        // File modification time is enough to notify
                        for (i in 0...watchedFile.updateCallbacks.length) {
                            watchedFile.updateCallbacks[i](watchedFile.content);
                        }
                    }

                }
                else if (watchedFile.mtime == -1) {
                    // Fetch modification time and content to compare it later
                    watchedFile.mtime = mtime;
                    watchedFile.content = getContent(path);
                }
            }
            #if interpret_debug_watch
            else {
                trace('[warning] Cannot watch file because it does not exist or is not a file: $path');
            }
            #end
        }

    }

    /**
     * Checks if a path points to a regular file (not a directory).
     * 
     * @param path The path to check
     * @return True if the path is a file, false otherwise
     */
    function isFile(path:String):Bool {

        #if (sys || hxnodejs || nodejs || node)
        return FileSystem.exists(path) && !FileSystem.isDirectory(path);
        #elseif web
        if (electron != null) {
            var fs = ceramic.Platform.nodeRequire('fs');
            return fs.existsSync(path);
        }
        else {
            return false;
        }
        #else
        return false;
        #end

    }

    /**
     * Gets the last modification time of a file.
     * 
     * @param path The file path
     * @return Modification time in milliseconds since epoch, or -1 if unavailable
     */
    function lastModified(path:String):Float {

        #if (sys || hxnodejs || nodejs || node)
        var stat = FileSystem.stat(path);
        if (stat == null) return -1;
        return stat.mtime.getTime();
        #elseif web
        if (electron != null) {
            var fs = ceramic.Platform.nodeRequire('fs');
            var stat = fs.statSync(path);
            if (stat == null) return -1;
            return stat.mtime.getTime();
        }
        else {
            return -1;
        }
        #else
        return -1;
        #end

    }

    /**
     * Reads the content of a file as a string.
     * 
     * @param path The file path
     * @return The file content, or null if unavailable
     */
    function getContent(path:String):String {

        #if (sys || hxnodejs || nodejs || node)
        return File.getContent(path);
        #elseif web
        if (electron != null) {
            var fs = ceramic.Platform.nodeRequire('fs');
            return fs.readFileSync(path, 'utf8');
        }
        else {
            return null;
        }
        #else
        return null;
        #end

    }

}

/**
 * Internal data structure for tracking watched file state.
 */
@:allow(ceramic.FileWatcher)
private class WatchedFile {

    /**
     * List of callbacks to notify when the file changes.
     */
    public var updateCallbacks:Array<String->Void> = [];

    /**
     * Last known modification time of the file.
     * -1 indicates the file hasn't been checked yet.
     */
    public var mtime:Float = -1;

    /**
     * Cached content of the file for comparison.
     */
    public var content:String = null;

    public function new() {}

}

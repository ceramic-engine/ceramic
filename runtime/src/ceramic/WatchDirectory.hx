package ceramic;

import ceramic.Assert.assert;
import ceramic.Path;

/**
 * A directory watcher that monitors file changes in specified directories.
 * 
 * This class provides cross-platform file system monitoring, detecting when files
 * are added, modified, or removed within watched directories. On Node.js platforms,
 * it can use the 'chokidar' library for efficient file watching if available,
 * otherwise it falls back to periodic polling.
 * 
 * Features:
 * - Monitor multiple directories simultaneously
 * - Detect file additions, modifications, and deletions
 * - Configurable update interval for polling mode
 * - Automatic cleanup when directories are unwatched
 * 
 * Example usage:
 * ```haxe
 * var watcher = new WatchDirectory(1.0); // Check every second
 * 
 * watcher.onDirectoryChange(this, (path, newFiles, previousFiles) -> {
 *     trace("Directory changed: " + path);
 *     
 *     // Check for new files
 *     for (file => mtime in newFiles) {
 *         if (!previousFiles.exists(file)) {
 *             trace("New file: " + file);
 *         }
 *     }
 * });
 * 
 * watcher.watchDirectory("/path/to/assets");
 * ```
 * 
 * Note: File watching may have platform-specific limitations and performance
 * characteristics. The chokidar integration provides better performance on
 * Node.js platforms when available.
 */
class WatchDirectory extends Entity {

    /**
     * Emitted when files in a watched directory have changed.
     * 
     * @param path The directory path that changed
     * @param newFiles Map of current files to their modification times (Unix timestamp)
     * @param previousFiles Map of files to modification times before the change
     */
    @event function directoryChange(path:String, newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>);

    /**
     * The interval in seconds between directory checks when using polling mode.
     * This is ignored when using chokidar on Node.js platforms.
     */
    public var updateInterval(default, null):Float;

    /**
     * Map of watched directory paths to their current file modification times.
     * The outer map key is the directory path, the inner map contains filenames
     * mapped to their last modification timestamps.
     */
    public var watchedDirectories(default, null):ReadOnlyMap<String, ReadOnlyMap<String, Float>> = null;

    var startingToWatchDirectories:Map<String, Bool> = null;

    #if js
    static var didTryRequireChokidar:Bool = false;
    static var chokidar:Dynamic = null;
    static var fs:Dynamic = null;

    var chokidarUpdatedFilesByWatchedDirectory:Map<String, Array<{
        status:ChokidarWatchedFileStatus,
        lastModified:Float,
        name:String
    }>> = null;

    var chokidarWatchers:Map<String, Dynamic> = null;
    #end

    /**
     * Create a new directory watcher.
     * 
     * @param updateInterval The interval in seconds between directory checks (default: 1.0).
     *                       Only used in polling mode; chokidar provides real-time updates.
     */
    public function new(updateInterval:Float = 1.0) {

        super();

        #if js
        if (!didTryRequireChokidar) {
            didTryRequireChokidar = true;
            fs = ceramic.Platform.nodeRequire('fs');
            if (fs != null)
                chokidar = ceramic.Platform.nodeRequire('chokidar');
        }
        #end

        this.updateInterval = updateInterval;

        Timer.interval(this, updateInterval, tick);

    }

    /**
     * Start watching a directory for file changes.
     * 
     * The initial file list is computed asynchronously. Once ready, any subsequent
     * changes will trigger the directoryChange event.
     * 
     * @param path The absolute path to the directory to watch
     * @throws String if the directory is already being watched
     */
    public function watchDirectory(path:String):Void {

        if (watchedDirectories == null)
            watchedDirectories = new Map();

        if (startingToWatchDirectories == null)
            startingToWatchDirectories = new Map();

        assert(!watchedDirectories.exists(path) && !startingToWatchDirectories.exists(path), 'Directory is already being watched at path $path');

        startingToWatchDirectories.set(path, true);

        Runner.runInBackground(() -> {
            var newFilesModificationTime = computeFilesModificationTime(path);
            Runner.runInMain(() -> {
                if (!startingToWatchDirectories.exists(path))
                    return;
                startingToWatchDirectories.remove(path);
                watchedDirectories.original.set(path, newFilesModificationTime);

                #if js
                if (chokidar != null) {
                    if (chokidarUpdatedFilesByWatchedDirectory == null) {
                        chokidarUpdatedFilesByWatchedDirectory = new Map();
                    }
                    chokidarUpdatedFilesByWatchedDirectory.set(path, []);
                    watchWithChokidar(path);
                }
                #end
            });
        });

    }

    #if js
    function watchWithChokidar(path:String):Void {

        var watcher = chokidar.watch('.', {
            ignoreInitial: true,
            disableGlobbing: true,
            cwd: path
        });

        if (chokidarWatchers == null) {
            chokidarWatchers = new Map();
        }

        if (chokidarWatchers.exists(path)) {
            chokidarWatchers.get(path).close();
        }

        chokidarWatchers.set(path, watcher);

        watcher.on('add', name -> {
            var stats = fs.statSync(Path.join([path, name]));
            if (!stats.isDirectory()) {
                chokidarUpdatedFilesByWatchedDirectory.get(path).push({
                    status: ADD,
                    lastModified: stats.mtime.getTime() / 1000,
                    name: name
                });
            }
        });

        watcher.on('change', name -> {
            var stats = fs.statSync(Path.join([path, name]));
            if (!stats.isDirectory()) {
                chokidarUpdatedFilesByWatchedDirectory.get(path).push({
                    status: CHANGE,
                    lastModified: stats.mtime.getTime() / 1000,
                    name: name
                });
            }
        });

        watcher.on('unlink', name -> {
            chokidarUpdatedFilesByWatchedDirectory.get(path).push({
                status: UNLINK,
                lastModified: -1,
                name: name
            });
        });

    }
    #end

    /**
     * Stop watching a directory.
     * 
     * @param path The directory path to stop watching
     * @return true if the directory was being watched and is now stopped, false otherwise
     */
    public function stopWatchingDirectory(path:String):Bool {

        #if js
        if (chokidarWatchers != null) {
            if (chokidarWatchers.exists(path)) {
                chokidarWatchers.get(path).close();
                chokidarWatchers.remove(path);
            }
        }
        #end

        if (watchedDirectories == null && watchedDirectories.exists(path)) {
            watchedDirectories.original.remove(path);
            if (startingToWatchDirectories != null && startingToWatchDirectories.exists(path)) {
                startingToWatchDirectories.remove(path);
            }
            return true;
        }

        if (startingToWatchDirectories != null && startingToWatchDirectories.exists(path)) {
            startingToWatchDirectories.remove(path);
            return true;
        }

        return false;

    }

    /**
     * Internal method called periodically to check for file changes.
     * Only used in polling mode when chokidar is not available.
     */
    function tick() {

        if (watchedDirectories != null) {
            var paths = [];
            for (path in watchedDirectories.keys()) {
                paths.push(path);
            }
            for (path in paths) {
                checkWatchedDirectory(path);
            }
        }

    }

    /**
     * Check a specific watched directory for changes.
     * In chokidar mode, processes queued change events.
     * In polling mode, compares current files with cached state.
     * 
     * @param path The directory path to check
     */
    function checkWatchedDirectory(path:String):Void {

        #if js

        if (chokidar != null) {
            if (chokidarUpdatedFilesByWatchedDirectory.exists(path)) {
                var list = chokidarUpdatedFilesByWatchedDirectory.get(path);
                if (list.length > 0) {
                    var previousFilesModificationTime = watchedDirectories.get(path);
                    var newFilesModificationTime = new Map<String,Float>();
                    for (key => value in previousFilesModificationTime) {
                        newFilesModificationTime.set(key, value);
                    }
                    for (info in list) {
                        switch info.status {
                            case ADD | CHANGE:
                                newFilesModificationTime.set(info.name, info.lastModified);
                            case UNLINK:
                                newFilesModificationTime.remove(info.name);
                        }
                    }
                    if (watchedDirectories.exists(path)) {
                        watchedDirectories.original.set(path, cast newFilesModificationTime);
                        emitDirectoryChange(path, newFilesModificationTime, previousFilesModificationTime);
                    }
                    list.splice(0, list.length);
                }
            }
        }
        else {

        #end

        var previousFilesModificationTime = watchedDirectories.get(path);
        Runner.runInBackground(() -> {
            var newFilesModificationTime = computeFilesModificationTime(path);

            // Will be set to true if any file has changed or if any file was added/removed
            var didChange = false;

            // Compare new files with previous ones
            for (path => mtime in newFilesModificationTime) {
                if (!previousFilesModificationTime.exists(path)) {
                    // This is a new file
                    didChange = true;
                    break;
                }
                else if (mtime != previousFilesModificationTime.get(path)) {
                    // Modification time has changed
                    didChange = true;
                    break;
                }
            }

            if (!didChange) {
                // Check if some files were removed
                for (path => mtime in previousFilesModificationTime) {
                    if (!newFilesModificationTime.exists(path)) {
                        // This file was removed
                        didChange = true;
                        break;
                    }
                }
            }

            if (didChange) {
                Runner.runInMain(() -> {
                    if (watchedDirectories.exists(path)) {
                        watchedDirectories.original.set(path, newFilesModificationTime);
                        emitDirectoryChange(path, newFilesModificationTime, previousFilesModificationTime);
                    }
                });
            }
        });

        #if js
        }
        #end

    }

    /**
     * Compute a map of all files in a directory with their modification times.
     * 
     * @param path The directory path to scan
     * @return Map of relative file paths to modification timestamps
     */
    function computeFilesModificationTime(path:String):ReadOnlyMap<String, Float> {

        var result = new Map<String, Float>();

        for (file in Files.getFlatDirectory(path)) {
            result.set(file, Files.getLastModified(Path.join([path, file])));
        }

        return cast result;

    }

}

#if js
/**
 * File change status types used by the chokidar file watcher.
 */
enum abstract ChokidarWatchedFileStatus(Int) from Int to Int {
    /**
     * A new file was added to the directory.
     */
    var ADD;
    
    /**
     * An existing file was modified.
     */
    var CHANGE;
    
    /**
     * A file was removed from the directory.
     */
    var UNLINK;
}
#end

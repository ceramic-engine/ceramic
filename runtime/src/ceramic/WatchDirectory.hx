package ceramic;

import ceramic.Path;
import ceramic.Assert.assert;

class WatchDirectory extends Entity {

    @event function directoryChange(path:String, newFiles:ImmutableMap<String, Float>, previousFiles:ImmutableMap<String, Float>);

    public var updateInterval(default, null):Float;

    public var watchedDirectories(default, null):ImmutableMap<String, ImmutableMap<String, Float>> = null;

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

    public function new(updateInterval:Float = 1.0) {

        super();

        #if js
        if (!didTryRequireChokidar) {
            didTryRequireChokidar = true;
            fs = ceramic.internal.PlatformSpecific.nodeRequire('fs');
            if (fs != null)
                chokidar = ceramic.internal.PlatformSpecific.nodeRequire('chokidar');
        }
        #end

        this.updateInterval = updateInterval;

        Timer.interval(this, updateInterval, tick);

    }

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
                watchedDirectories.mutable.set(path, newFilesModificationTime);
                
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
            var stats = fs.statSync(Path.join([path, name]));
            if (!stats.isDirectory()) {
                chokidarUpdatedFilesByWatchedDirectory.get(path).push({
                    status: UNLINK,
                    lastModified: stats.mtime.getTime() / 1000,
                    name: name
                });
            }
        });

    }
    #end

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
            watchedDirectories.mutable.remove(path);
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

    function checkWatchedDirectory(path:String):Void {

        #if js

        if (chokidar != null) {
            if (chokidarUpdatedFilesByWatchedDirectory.exists(path)) {
                var list = chokidarUpdatedFilesByWatchedDirectory.get(path);
                if (list.length > 0) {
                    var previousFilesModificationTime = watchedDirectories.get(path);
                    var newFilesModificationTime = new Map<String,Float>();
                    for (key => value in previousFilesModificationTime.mutable) {
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
                        watchedDirectories.mutable.set(path, cast newFilesModificationTime);
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
            for (path => mtime in newFilesModificationTime.mutable) {
                if (!previousFilesModificationTime.exists(path)) {
                    // This is a new file
                    didChange = true;
                    break;
                }
                else if (mtime > previousFilesModificationTime.get(path)) {
                    // Modification time has changed
                    didChange = true;
                    break;
                }
            }

            if (!didChange) {
                // Check if some files were removed
                for (path => mtime in previousFilesModificationTime.mutable) {
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
                        watchedDirectories.mutable.set(path, newFilesModificationTime);
                        emitDirectoryChange(path, newFilesModificationTime, previousFilesModificationTime);
                    }
                });
            }
        });

        #if js
        }
        #end
        
    }

    function computeFilesModificationTime(path:String):ImmutableMap<String, Float> {

        var result = new Map<String, Float>();

        for (file in Files.getFlatDirectory(path)) {
            result.set(file, Files.getLastModified(Path.join([path, file])));
        }

        return cast result;

    }

}

#if js
enum abstract ChokidarWatchedFileStatus(Int) from Int to Int {
    var ADD;
    var CHANGE;
    var UNLINK;
}
#end

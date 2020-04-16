package ceramic;

import ceramic.Path;
import ceramic.Assert.assert;

class WatchDirectory extends Entity {

    @event function directoryChange(path:String, newFiles:ImmutableMap<String, Float>, previousFiles:ImmutableMap<String, Float>);

    public var updateInterval(default, null):Float;

    public var watchedDirectories(default, null):ImmutableMap<String, ImmutableMap<String, Float>> = null;

    var startingToWatchDirectories:Map<String, Bool> = null;

    public function new(updateInterval:Float = 1.0) {

        super();

        this.updateInterval = updateInterval;

        Timer.interval(this, updateInterval, tick);

    }

    public function watchDirectory(path:String, ?onUpdate:ImmutableMap<String,Float>):Void {

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
            });
        });

    }

    public function stopWatchingDirectory(path:String):Bool {

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
        
    }

    function computeFilesModificationTime(path:String):ImmutableMap<String, Float> {

        var result = new Map<String, Float>();

        for (file in Files.getFlatDirectory(path)) {
            result.set(file, Files.getLastModified(Path.join([path, file])));
        }

        return cast result;

    }

}

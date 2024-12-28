package tools;

import haxe.crypto.Md5;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Mutex;
import sys.thread.Thread;
import tools.Helpers.*;

/**
 * Manages single instance enforcement for any identified resource
 */
class InstanceManager {

    private static var lockFile:String = null;
    private static var onQuitCallback:()->Void;
    private static var checkInterval:Float;

    public static function makeUnique(identifier:String):Void {

        if (InstanceManager.lockFile != null) return;

        InstanceManager.init(
            identifier,
            () -> {
                context.shouldExit = true;
            }
        );

    }

    /**
     * Creates a new instance manager
     * @param identifier Any string that uniquely identifies what you want single-instanced
     * @param onQuit Callback that will be called when this instance should quit
     * @param checkIntervalMs How often to check for changes (in milliseconds)
     */
    static function init(identifier:String, onQuit:()->Void, checkInterval:Float = 0.01) {
        quitExisting(identifier);

        InstanceManager.onQuitCallback = onQuit;
        InstanceManager.checkInterval = checkInterval;

        // Create the lock file path
        var hash = Md5.encode(identifier);
        var homeDir = homedir();

        var ceramicDir = Path.join([homeDir, ".ceramic"]);
        InstanceManager.lockFile = Path.join([ceramicDir, 'instance-${hash}.lock']);

        // Ensure .ceramic directory exists
        if (!FileSystem.exists(ceramicDir)) {
            FileSystem.createDirectory(ceramicDir);
        }

        // Start the file watcher thread
        initializeWatcher();
    }

    /**
     * Initializes the file watching thread and writes initial lock file
     */
    private static function initializeWatcher():Void {
        // Write initial lock file with current timestamp
        updateLockFile();

        // Start watcher
        var lastMod = FileSystem.stat(lockFile).mtime;
        var clearInterval = null;
        clearInterval = timer.interval(InstanceManager.checkInterval, () -> {
            try {
                if (!FileSystem.exists(lockFile)) {
                    // Lock file was deleted, recreate it
                    updateLockFile();
                    lastMod = FileSystem.stat(lockFile).mtime;
                    return;
                }

                var currentMod = FileSystem.stat(lockFile).mtime;
                if (currentMod.getTime() > lastMod.getTime()) {
                    // File was modified by another instance
                    if (onQuitCallback != null) {
                        onQuitCallback();
                    }
                    clearInterval();
                }

                lastMod = currentMod;
            }
            catch (e:Dynamic) {
                print('Error in watcher: $e');
            }
        });
    }

    /**
     * Updates the lock file to signal presence to other instances
     */
    private static function updateLockFile():Void {
        try {
            File.saveContent(lockFile, Std.string(Sys.time()));
        }
        catch (e:Dynamic) {
            print('Error updating lock file: $e');
        }
    }

    /**
     * Call this when your application is shutting down
     */
    public function dispose():Void {
        try {
            if (FileSystem.exists(lockFile)) {
                FileSystem.deleteFile(lockFile);
            }
        }
        catch (e:Dynamic) {
            print('Error cleaning up lock file: $e');
        }
    }

    /**
     * Forces any existing instance to quit
     */
    static function quitExisting(identifier:String):Void {
        var hash = Md5.encode(identifier);
        var homeDir = "";

        #if windows
        homeDir = Sys.getEnv("USERPROFILE");
        #else
        homeDir = Sys.getEnv("HOME");
        #end

        var ceramicDir = Path.join([homeDir, ".ceramic"]);
        var lockFile = Path.join([ceramicDir, 'instance-${hash}.lock']);

        if (FileSystem.exists(lockFile)) {
            // Touch the file to trigger the other instance to quit
            File.saveContent(lockFile, Std.string(Sys.time()));
            // Give the other instance a moment to quit
            Sys.sleep(0.1);
        }
    }

}
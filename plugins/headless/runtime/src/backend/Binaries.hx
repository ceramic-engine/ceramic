package backend;

import haxe.io.Bytes;
import ceramic.Path;

#if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

#if !no_backend_docs
/**
 * Binary file loading implementation for the headless backend.
 * 
 * This class handles loading binary files from the filesystem.
 * On platforms with filesystem access, it can actually load
 * files. On other platforms, it provides placeholder functionality.
 * 
 * Binary files are loaded as Haxe Bytes objects, which can be
 * used for any type of binary data like images, sounds, or
 * custom file formats.
 */
#end
class Binaries implements spec.Binaries {

    #if !no_backend_docs
    /**
     * Creates a new binary file loading system.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Loads a binary file from the specified path.
     * 
     * On platforms with filesystem access, this will actually load
     * the file content. On other platforms, it returns null or empty data.
     * 
     * @param path Path to the binary file (absolute or relative to assets)
     * @param options Optional loading parameters (currently unused)
     * @param _done Callback function called with the loaded bytes (or null on failure)
     */
    #end
    public function load(path:String, ?options:LoadBinaryOptions, _done:Bytes->Void):Void {

        var done = function(binary:Bytes) {
            ceramic.App.app.onceImmediate(function() {
                _done(binary);
                _done = null;
            });
        };

        #if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))

        // Convert relative paths to absolute paths based on assets directory
        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        if (path.startsWith('http://') || path.startsWith('https://')) {
            // HTTP loading not implemented in headless mode
            done(null);
            return;
        }

        if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) {
            try {
                done(File.getBytes(path));
            } catch (e:Dynamic) {
                ceramic.App.app.logger.error('Failed to load file at path: $path, $e');
                done(null);
            }
        }
        else {
            ceramic.App.app.logger.error('File doesn\'t exist at path: $path');
            done(null);
        }

        #else

        // On platforms without filesystem access, return empty data
        ceramic.App.app.logger.warning('Backend cannot read file at path: $path ; returning empty string');
        done('');

        #end

    }

    #if !no_backend_docs
    /**
     * Indicates whether this backend supports hot reloading of binary assets.
     * 
     * @return Always false for the headless backend
     */
    #end
    inline public function supportsHotReloadPath():Bool {
        
        return false;

    }

}
package backend;

import ceramic.Path;

#if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

#if !no_backend_docs
/**
 * Text file loading implementation for the headless backend.
 * 
 * This class handles loading text files from the filesystem.
 * On platforms with filesystem access, it can actually load
 * files. On other platforms, it provides placeholder functionality.
 * 
 * Text files are commonly used for configuration, data files,
 * JSON, XML, and other text-based assets.
 */
#end
class Texts implements spec.Texts {

    #if !no_backend_docs
    /**
     * Creates a new text file loading system.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Loads a text file from the specified path.
     * 
     * On platforms with filesystem access, this will actually load
     * the file content. On other platforms, it returns an empty string.
     * 
     * @param path Path to the text file (absolute or relative to assets)
     * @param options Optional loading parameters (currently unused)
     * @param _done Callback function called with the loaded text (or null on failure)
     */
    #end
    public function load(path:String, ?options:LoadTextOptions, _done:String->Void):Void {

        var done = function(text:String) {
            ceramic.App.app.onceImmediate(function() {
                _done(text);
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
                done(File.getContent(path));
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

        // On platforms without filesystem access, return empty string
        ceramic.App.app.logger.warning('Backend cannot read file at path: $path ; returning empty string');
        done('');

        #end

    }

    #if !no_backend_docs
    /**
     * Indicates whether this backend supports hot reloading of text assets.
     * 
     * @return Always false for the headless backend
     */
    #end
    inline public function supportsHotReloadPath():Bool {
        
        return false;

    }

}
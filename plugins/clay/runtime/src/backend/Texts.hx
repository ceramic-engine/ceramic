package backend;

import ceramic.Path;
import clay.Clay;
import clay.Immediate;
import clay.buffers.Uint8Array;

using StringTools;
#if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
import sys.FileSystem;
import sys.io.File;
#end


/**
 * Clay backend implementation for loading text files.
 * 
 * This class handles loading of text-based resources from various sources:
 * - Local filesystem (when available)
 * - HTTP/HTTPS URLs
 * - Application bundle resources
 * 
 * Features:
 * - Asynchronous and synchronous loading modes
 * - Request deduplication to prevent redundant loads
 * - Hot reload support for development
 * - Automatic UTF-8 text decoding
 * - URL query parameter stripping for cache busting
 * 
 * Common text file types include JSON, XML, configuration files,
 * shader source code, and other text-based assets.
 * 
 * @see spec.Texts The interface this class implements
 * @see TextAsset For the high-level text asset interface
 */
class Texts implements spec.Texts {

    public function new() {}

    /**
     * Loads text content from the specified path.
     * 
     * The path can be:
     * - Relative to the assets directory (e.g., "data/config.json")
     * - Absolute filesystem path (e.g., "/usr/local/data/config.txt")
     * - HTTP/HTTPS URL (e.g., "https://example.com/data.json")
     * 
     * Multiple requests for the same path are automatically deduplicated,
     * with all callbacks being notified when the load completes.
     * 
     * @param path Path to the text file to load
     * @param options Optional loading configuration (sync/async, immediate queue)
     * @param _done Callback invoked with the loaded text (null on error)
     */
    public function load(path:String, ?options:LoadTextOptions, _done:String->Void):Void {

        var synchronous = options != null && options.loadMethod == SYNC;
        var immediate = options != null ? options.immediate : null;
        var done = function(text:String) {
            final fn = function() {
                _done(text);
                _done = null;
            };
            if (immediate != null)
                immediate.push(fn);
            else
                ceramic.App.app.onceImmediate(fn);
        };

        var isUrl:Bool = path.startsWith('http://') || path.startsWith('https://');
        path = Path.isAbsolute(path) || isUrl ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        // Is text currently loading?
        if (loadingTextCallbacks.exists(path)) {
            // Yes, just bind it
            loadingTextCallbacks.get(path).push(function(text:String) {
                done(text);
            });
            return;
        }
        else {
            // Add loading callbacks array
            loadingTextCallbacks.set(path, []);
        }

        // Remove ?something in path
        var cleanedPath = path;
        if (!isUrl) {
            var questionMarkIndex = cleanedPath.indexOf('?');
            if (questionMarkIndex != -1) {
                cleanedPath = cleanedPath.substr(0, questionMarkIndex);
            }
        }

        var fullPath = isUrl ? cleanedPath : Clay.app.assets.fullPath(cleanedPath);

        Clay.app.io.loadData(fullPath, true, !synchronous, function(res:Uint8Array) {

            if (res == null) {

                var callbacks = loadingTextCallbacks.get(path);
                if (callbacks != null) {
                    loadingTextCallbacks.remove(path);
                    done(null);
                    for (callback in callbacks) {
                        callback(null);
                    }
                }
                else {
                    done(null);
                }

                return;
            }

            var text = res.toBytes().toString();

            var callbacks = loadingTextCallbacks.get(path);
            if (callbacks != null) {
                loadingTextCallbacks.remove(path);
                done(text);
                for (callback in callbacks) {
                    callback(text);
                }
            }
            else {
                done(text);
            }
        });

        // Needed to ensure a synchronous load will be done before the end of the frame
        if (immediate != null) {
            immediate.push(Immediate.flush);
        }
        else {
            ceramic.App.app.onceImmediate(Immediate.flush);
        }

    }

    /**
     * Indicates whether this backend supports hot reloading of text files.
     * Clay backend always supports hot reload for development efficiency.
     * 
     * @return true, indicating hot reload is supported
     */
    inline public function supportsHotReloadPath():Bool {

        return true;

    }

/// Internal

    /**
     * Tracks pending load operations to prevent duplicate requests.
     * Maps file paths to arrays of callbacks waiting for that file.
     */
    var loadingTextCallbacks:Map<String,Array<String->Void>> = new Map();

}
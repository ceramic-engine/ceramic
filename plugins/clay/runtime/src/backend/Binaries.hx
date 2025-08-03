package backend;

import ceramic.Path;
import clay.Clay;
import clay.Immediate;
import clay.buffers.Uint8Array;
import haxe.io.Bytes;

using StringTools;
#if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
import sys.FileSystem;
import sys.io.File;
#end


/**
 * Clay backend implementation for loading binary data files.
 * 
 * This class handles loading of raw binary data from various sources including:
 * - Local filesystem (when available)
 * - HTTP/HTTPS URLs
 * - Application bundle resources
 * 
 * The implementation includes:
 * - Asynchronous loading with callback support
 * - Request deduplication (multiple requests for the same file share one load operation)
 * - Hot reload support for development
 * - Automatic path resolution relative to assets directory
 * 
 * @see spec.Binaries The interface this class implements
 * @see BinaryAsset For the high-level binary asset interface
 */
class Binaries implements spec.Binaries {

    public function new() {}

    /**
     * Loads binary data from the specified path.
     * 
     * The path can be:
     * - Relative to the assets directory (e.g., "data/config.bin")
     * - Absolute filesystem path (e.g., "/usr/local/data/config.bin")
     * - HTTP/HTTPS URL (e.g., "https://example.com/data.bin")
     * 
     * @param path Path to the binary file to load
     * @param options Optional loading configuration (immediate callback execution)
     * @param _done Callback invoked with the loaded bytes data (null on error)
     */
    public function load(path:String, ?options:LoadBinaryOptions, _done:Bytes->Void):Void {

        var immediate = options != null ? options.immediate : null;
        var done = function(binary:Bytes) {
            final fn = function() {
                _done(binary);
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

        // Is binary currently loading?
        if (loadingBinaryCallbacks.exists(path)) {
            // Yes, just bind it
            loadingBinaryCallbacks.get(path).push(function(binary:Bytes) {
                done(binary);
            });
            return;
        }
        else {
            // Add loading callbacks array
            loadingBinaryCallbacks.set(path, []);
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

        Clay.app.io.loadData(fullPath, true, function(res:Uint8Array) {

            if (res == null) {

                var callbacks = loadingBinaryCallbacks.get(path);
                if (callbacks != null) {
                    loadingBinaryCallbacks.remove(path);
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

            var binary = res.toBytes();

            var callbacks = loadingBinaryCallbacks.get(path);
            if (callbacks != null) {
                loadingBinaryCallbacks.remove(path);
                done(binary);
                for (callback in callbacks) {
                    callback(binary);
                }
            }
            else {
                done(binary);
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
     * Indicates whether this backend supports hot reloading of binary files.
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
    var loadingBinaryCallbacks:Map<String,Array<Bytes->Void>> = new Map();

}
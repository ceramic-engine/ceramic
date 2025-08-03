package backend;

import ceramic.Path;
import sys.FileSystem;
import sys.io.File;

import unityengine.TextAsset;

using StringTools;

#if !no_backend_docs
/**
 * Unity backend implementation for text file loading.
 * Loads text files from Unity Resources or filesystem paths.
 * Handles concurrent load requests for the same file.
 */
#end
class Texts implements spec.Texts {

    #if !no_backend_docs
    /**
     * Creates a new Texts loader instance.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Loads a text file from the specified path.
     * Supports loading from Unity Resources (relative paths) or filesystem (absolute paths).
     * HTTP/HTTPS URLs are not currently supported.
     * @param path File path (relative to assets or absolute)
     * @param options Loading options (currently unused)
     * @param _done Callback with loaded text content (null on failure)
     */
    #end
    public function load(path:String, ?options:LoadTextOptions, _done:String->Void):Void {

        var done = function(text:String) {
            ceramic.App.app.onceImmediate(function() {
                _done(text);
                _done = null;
            });
        };

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        if (path.startsWith('http://') || path.startsWith('https://')) {
            // Not implemented (yet?)
            done(null);
            return;
        }

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
        
        var textFile:TextAsset = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.TextAsset>({0})', path);

        if (textFile == null) {
            ceramic.App.app.logger.error('Failed to load text file at path: $path');
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

        var text = '' + textFile.text;
        untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', textFile);
        textFile = null;

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

    }

    #if !no_backend_docs
    /**
     * Checks if hot reload is supported for text files.
     * Unity backend doesn't support text hot reload.
     * @return Always false for Unity
     */
    #end
    inline public function supportsHotReloadPath():Bool {
        
        return false;

    }

/// Internal

    #if !no_backend_docs
    /**
     * Tracks callbacks for files currently being loaded.
     * Prevents duplicate loads and allows multiple callbacks for the same file.
     */
    #end
    var loadingTextCallbacks:Map<String,Array<String->Void>> = new Map();

} //Texts
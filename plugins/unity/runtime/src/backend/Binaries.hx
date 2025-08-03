package backend;

import ceramic.Path;
import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;
import unityengine.TextAsset;

using StringTools;

#if !no_backend_docs
/**
 * Unity implementation for loading binary files.
 * 
 * This class handles loading of binary data from Unity's Resources system.
 * It supports loading from the Resources folder and implements a callback
 * system to handle multiple simultaneous requests for the same file.
 * 
 * Key features:
 * - Loads binary files as Unity TextAsset objects
 * - Automatically converts Unity byte arrays to Haxe Bytes
 * - Prevents duplicate loading with callback queuing
 * - Proper resource unloading after conversion
 * - Deferred callback execution via onceImmediate
 * 
 * Limitations:
 * - HTTP/HTTPS URLs are not currently supported
 * - Hot reload is not available in Unity builds
 * - Files must be in the Resources folder
 * 
 * @see spec.Binaries The interface this class implements
 * @see backend.Texts Similar implementation for text files
 */
#end
class Binaries implements spec.Binaries {

    #if !no_backend_docs
    /**
     * Creates a new Binaries instance.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Loads a binary file from Unity's Resources folder.
     * 
     * The loading process:
     * 1. Normalizes the path (relative to assets or absolute)
     * 2. Checks if file is already loading (queues callback if so)
     * 3. Loads as TextAsset from Resources
     * 4. Converts Unity bytes to Haxe Bytes
     * 5. Unloads the TextAsset to free memory
     * 6. Executes all queued callbacks
     * 
     * @param path The file path relative to Resources folder or absolute path
     * @param options Loading options (currently unused in Unity)
     * @param _done Callback with loaded bytes or null on failure
     */
    #end
    public function load(path:String, ?options:LoadBinaryOptions, _done:Bytes->Void):Void {

        var done = function(binary:Bytes) {
            ceramic.App.app.onceImmediate(function() {
                _done(binary);
                _done = null;
            });
        };

        // Normalize path - convert relative paths to absolute
        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        // HTTP loading not supported in Unity backend
        if (path.startsWith('http://') || path.startsWith('https://')) {
            // Not implemented (yet?)
            done(null);
            return;
        }

        // Check if this file is already being loaded
        // This prevents duplicate Resource.Load calls
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

        // Load binary file as TextAsset from Resources
        // TextAsset can hold any binary data, not just text
        var binaryFile:TextAsset = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.TextAsset>({0})', path);

        if (binaryFile == null) {
            ceramic.App.app.logger.error('Failed to load binary file at path: $path');
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

        // Convert Unity byte array to Haxe Bytes
        var binary = Bytes.ofData(binaryFile.bytes);
        
        // Unload the TextAsset to free memory
        untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', binaryFile);
        binaryFile = null;

        // Execute all callbacks waiting for this file
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

    }

    #if !no_backend_docs
    /**
     * Checks if hot reload is supported for file paths.
     * Unity Resources system doesn't support hot reload in builds.
     * 
     * @return Always returns false
     */
    #end
    inline public function supportsHotReloadPath():Bool {

        return false;

    }

/// Internal

    #if !no_backend_docs
    /**
     * Tracks callbacks for files currently being loaded.
     * Key: file path, Value: array of callbacks waiting for that file.
     * This prevents duplicate Resource.Load calls for the same file.
     */
    #end
    var loadingBinaryCallbacks:Map<String,Array<Bytes->Void>> = new Map();

} //Binaries
package backend;

import haxe.io.Bytes;
import ceramic.Path;
import sys.FileSystem;
import sys.io.File;

import unityengine.TextAsset;

using StringTools;

class Binaries implements spec.Binaries {

    public function new() {}

    public function load(path:String, ?options:LoadBinaryOptions, _done:Bytes->Void):Void {

        var done = function(binary:Bytes) {
            ceramic.App.app.onceImmediate(function() {
                _done(binary);
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

        var binary = Bytes.ofData(binaryFile.bytes);
        untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', binaryFile);
        binaryFile = null;

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

    inline public function supportsHotReloadPath():Bool {
        
        return false;

    }

/// Internal

    var loadingBinaryCallbacks:Map<String,Array<Bytes->Void>> = new Map();

} //Binaryures
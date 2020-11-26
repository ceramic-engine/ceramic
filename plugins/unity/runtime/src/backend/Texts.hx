package backend;

import ceramic.Path;
import sys.FileSystem;
import sys.io.File;

import unityengine.TextAsset;

using StringTools;

class Texts implements spec.Texts {

    public function new() {}

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

    inline public function supportsHotReloadPath():Bool {
        
        return false;

    }

/// Internal

    var loadingTextCallbacks:Map<String,Array<String->Void>> = new Map();

} //Textures
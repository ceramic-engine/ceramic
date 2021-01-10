package backend;

import clay.Immediate;
import clay.buffers.Uint8Array;
import clay.Clay;
import ceramic.Path;

#if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
import sys.FileSystem;
import sys.io.File;
#end

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
        var questionMarkIndex = cleanedPath.indexOf('?');
        if (questionMarkIndex != -1) {
            cleanedPath = cleanedPath.substr(0, questionMarkIndex);
        }

        var fullPath = cleanedPath;
        if (!Path.isAbsolute(fullPath)) {
            fullPath = Path.join([Clay.app.io.appPath(), fullPath]);
        }
        Clay.app.io.loadData(fullPath, null, function(res:Uint8Array) {
            
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
        ceramic.App.app.onceImmediate(function() {
            Immediate.flush();
        });

    }

    inline public function supportsHotReloadPath():Bool {
        
        return true;

    }

/// Internal

    var loadingTextCallbacks:Map<String,Array<String->Void>> = new Map();

} //Textures
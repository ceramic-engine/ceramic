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


class Texts implements spec.Texts {

    public function new() {}

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

        var fullPath = Clay.app.assets.fullPath(cleanedPath);

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

    inline public function supportsHotReloadPath():Bool {

        return true;

    }

/// Internal

    var loadingTextCallbacks:Map<String,Array<String->Void>> = new Map();

}
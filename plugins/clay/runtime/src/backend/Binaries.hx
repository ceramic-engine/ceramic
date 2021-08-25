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


class Binaries implements spec.Binaries {

    public function new() {}

    public function load(path:String, ?options:LoadBinaryOptions, _done:Bytes->Void):Void {

        var synchronous:Bool = options != null && options.synchronous;

        var done = synchronous ? _done : function(binary:Bytes) {
            ceramic.App.app.onceImmediate(function() {
                _done(binary);
                _done = null;
            });
        };

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
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
        var questionMarkIndex = cleanedPath.indexOf('?');
        if (questionMarkIndex != -1) {
            cleanedPath = cleanedPath.substr(0, questionMarkIndex);
        }

        var fullPath = Clay.app.assets.fullPath(cleanedPath);

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
        if (synchronous) {
            Immediate.flush();
        }
        else {
            ceramic.App.app.onceImmediate(function() {
                Immediate.flush();
            });
        }

    }

    inline public function supportsHotReloadPath():Bool {

        return true;

    }

/// Internal

    var loadingBinaryCallbacks:Map<String,Array<Bytes->Void>> = new Map();

}
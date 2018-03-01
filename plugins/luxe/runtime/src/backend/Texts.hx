package backend;

import haxe.io.Path;

using StringTools;

class Texts implements spec.Texts {

    public function new() {}

    public function load(path:String, ?options:LoadTextOptions, done:String->Void):Void {

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        // Is text currently loading?B
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

        Luxe.resources.load_text(path)
        .then(function(res:luxe.resource.Resource.TextResource) {
            
            if (res.asset == null) {
                res.destroy(true);

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

            var text = res.asset.text;
            try {
                // May fail if text failed to load first
                res.destroy(true);
            } catch (e:Dynamic) {}

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
        },
        function(_) {
            done(null);
        });

    } //load

/// Internal

    var loadingTextCallbacks:Map<String,Array<String->Void>> = new Map();

} //Textures
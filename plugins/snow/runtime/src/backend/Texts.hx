package backend;

import snow.types.Types;

import haxe.io.Path;

using StringTools;

typedef LoadTextOptions = {
    
}

class Texts #if !completion implements spec.Texts #end {

    public function new() {}

    public function load(path:String, ?options:LoadTextOptions, done:String->Void):Void {

        var snowApp = ceramic.App.app.backend.snow;

        path = ceramic.Utils.realPath(path);

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

        function allDone(result:String) {

            var callbacks = loadingTextCallbacks.get(path);
            if (callbacks != null) {
                loadingTextCallbacks.remove(path);
                done(result);
                for (callback in callbacks) {
                    callback(result);
                }
            }
            else {
                done(result);
            }
        }

        var list = [
            snowApp.assets.text(path)
        ];

        snow.api.Promise.all(list)
        .then(function(assets:Array<AssetText>) {

            for (asset in assets) {
                var text = asset.text;
                asset.destroy();
                allDone(text);
                return;
            }

            allDone(null);

        }).error(function(error) {
            
            allDone(null);

        });

    } //load

/// Internal

    var loadingTextCallbacks:Map<String,Array<String->Void>> = new Map();

} //Textures

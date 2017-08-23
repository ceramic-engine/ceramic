package backend;

import haxe.io.Path;

using StringTools;

typedef LoadTextOptions = {
    
}

class Texts implements spec.Texts {

    public function new() {}

    inline public function load(path:String, ?options:LoadTextOptions, done:String->Void):Void {

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        Luxe.resources.load_text(path)
        .then(function(res:luxe.resource.Resource.TextResource) {
            done(res.asset.text);
        },
        function(_) {
            done(null);
        });

    } //load

} //Textures
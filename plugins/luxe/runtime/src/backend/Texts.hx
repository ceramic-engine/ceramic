package backend;

import haxe.io.Path;

using StringTools;

typedef LoadTextOptions = {
    
}

class Texts implements spec.Texts {

    public function new() {}

    public function load(path:String, ?options:LoadTextOptions, done:String->Void):Void {

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        Luxe.resources.load_text(path)
        .then(function(res:luxe.resource.Resource.TextResource) {
            
            if (res.asset == null) {
                res.destroy(true);
                done(null);
                return;
            }

            var text = res.asset.text;
            try {
                // May fail if text failed to load first
                res.destroy(true);
            } catch (e:Dynamic) {}
            done(text);
        },
        function(_) {
            done(null);
        });

    } //load

} //Textures
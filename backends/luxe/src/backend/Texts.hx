package backend;

typedef LoadTextOptions = {
    
}

class Texts implements spec.Texts {

    public function new() {}

    inline public function load(name:String, ?options:LoadTextOptions, done:String->Void):Void {

        Luxe.resources.load_text(name)
        .then(function(res:luxe.resource.Resource.TextResource) {
            done(res.asset.text);
        },
        function(_) {
            done(null);
        });

    } //load

} //Textures
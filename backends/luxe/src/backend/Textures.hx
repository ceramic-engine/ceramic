package backend;

typedef LoadTextureOptions = {
    
}

abstract Texture(phoenix.Texture) from phoenix.Texture to phoenix.Texture {}

class Textures implements spec.Textures {

    public function new() {}

    inline public function load(name:String, ?options:LoadTextureOptions, done:Texture->Void):Void {

        Luxe.resources.load_texture(name, {
            load_premultiply_alpha: true
        })
        .then(function(texture:Texture) {
            done(texture);
        },
        function(_) {
            done(null);
        });

    } //load

    inline public function destroy(texture:Texture):Void {
        
        (texture:phoenix.Texture).destroy(true);

    } //destroy

    inline public function getWidth(texture:Texture):Int {

        return (texture:phoenix.Texture).width_actual;

    } //getWidth

    inline public function getHeight(texture:Texture):Int {

        return (texture:phoenix.Texture).height_actual;

    } //getHeight

} //Textures
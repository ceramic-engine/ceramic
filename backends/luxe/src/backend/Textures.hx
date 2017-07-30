package backend;

import snow.systems.assets.Asset;
import luxe.Resources;

typedef LoadTextureOptions = {
    ?premultiplyAlpha:Bool
}

abstract Texture(phoenix.Texture) from phoenix.Texture to phoenix.Texture {}

class Textures implements spec.Textures {

    public function new() {}

    inline public function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void {

        // Create empty texture
        var id = 'assets/' + path;
        var texture:phoenix.Texture = new phoenix.Texture({
            id: id,
            system: Luxe.resources,
            filter_min: null,
            filter_mag: null,
            clamp_s: null,
            clamp_t: null,
            load_premultiply_alpha: options != null && options.premultiplyAlpha ? true : false
        });

        // Keep it in luxe cache
        Luxe.resources.add(texture);

        function doLoad() {
            // Load from asset using Luxe's internal API
            texture.state = ResourceState.loading;
            var get = Luxe.snow.assets.image(id);
            get.then(function(asset:AssetImage) {
                texture.state = ResourceState.loaded;

                function doCreate() {
                    @:privateAccess texture.texture = texture.create_texture_id();
                    @:privateAccess texture.from_asset(asset);
                    done(texture);
                }
/*#if cpp
                ceramic.internal.Worker.execInPrimary(doCreate);
#else*/
                doCreate();
//#end
            });
            get.error(function(_) {

                function doFail() {
                    texture.state = ResourceState.failed;
                    texture.destroy(true);
                    done(null);
                }
/*#if cpp
                ceramic.internal.Worker.execInPrimary(doFail);
#else*/
                doFail();
//#end
            });
        }

/*#if cpp
        ceramic.App.app.backend.worker.enqueue(doLoad);
#else*/
        doLoad();
//#end

    } //load

    inline public function destroy(texture:Texture):Void {
        
        (texture:phoenix.Texture).destroy(true);

    } //destroy

    inline public function getWidth(texture:Texture):Int {

        return (texture:phoenix.Texture).width;

    } //getWidth

    inline public function getHeight(texture:Texture):Int {

        return (texture:phoenix.Texture).height;

    } //getHeight

} //Textures
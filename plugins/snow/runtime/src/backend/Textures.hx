package backend;

import snow.types.Types;

using StringTools;

typedef LoadTextureOptions = {
}

class TextureImpl {
    public var width:Int = 0;
    public var height:Int = 0;
    public function new(width:Int = 0, height:Int = 0) {
        this.width = width;
        this.height = height;
    }
}

abstract Texture(TextureImpl) from TextureImpl to TextureImpl {}


class Textures #if !completion implements spec.Textures #end {

    public function new() {}

    public function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void {

        var snowApp = ceramic.App.app.backend.snow;

        path = ceramic.Utils.realPath(path);
        
        var list = [
            snowApp.assets.image(path)
        ];
        
        snow.api.Promise.all(list)
        .then(function(assets:Array<AssetImage>) {

            for (asset in assets) {
                var image = asset.image;
                
                // TODO asset/image/texture API

                return;
            }

            done(null);

        }).error(function(error) {

            done(null);
        });

        done(null);//new TextureImpl(0, 0));

    } //load

    inline public function createRenderTexture(width:Int, height:Int):Texture {

        return new TextureImpl(width, height);

    } //createRenderTexture

    public function destroy(texture:Texture):Void {

        //

    } //destroy

    inline public function getWidth(texture:Texture):Int {

        return (texture:TextureImpl).width;

    } //getWidth

    inline public function getHeight(texture:Texture):Int {

        return (texture:TextureImpl).height;

    } //getHeight

/// Internal

    var loadingTextureCallbacks:Map<String,Array<Texture->Void>> = new Map();

    var loadedTextures:Map<String,TextureImpl> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures

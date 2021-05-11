package backend;

class Textures implements spec.Textures {

    public function new() {}

    public function load(path:String, ?options:LoadTextureOptions, _done:Texture->Void):Void {

        var done = function(texture:Texture) {
            ceramic.App.app.onceImmediate(function() {
                _done(texture);
                _done = null;
            });
        };

        done(new TextureImpl(0, 0));

    }

    inline public function supportsHotReloadPath():Bool {
        
        return false;

    }

    public function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture {

        return null;

    }

    public function destroyTexture(texture:Texture):Void {

    }

    inline public function createRenderTarget(width:Int, height:Int):Texture {

        return new TextureImpl(width, height);

    }

    public function destroy(texture:Texture):Void {

        //

    }

    inline public function getTextureId(texture:Texture):backend.TextureId {

        return (texture:TextureImpl).textureId;

    }

    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function getTextureWidthActual(texture:Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeightActual(texture:Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array {

        return null;

    }

    inline public function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void {

    }

    inline public function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void {

        //

    }

    public function maxTexturesByBatch():Int {

        return 1;

    }

    inline public function getTextureIndex(texture:Texture):Int {

        return -1;

    }

} //Textures
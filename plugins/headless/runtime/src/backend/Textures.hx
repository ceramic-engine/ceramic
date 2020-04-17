package backend;

class Textures implements spec.Textures {

    public function new() {}

    public function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void {

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

    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function getTexturePixels(texture:Texture):Null<UInt8Array> {

        return null;

    }

    inline public function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void {

        //

    }

} //Textures
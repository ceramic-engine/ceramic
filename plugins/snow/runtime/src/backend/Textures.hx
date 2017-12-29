package backend;

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


class Textures implements spec.Textures {

    public function new() {}

    public function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void {

        done(new TextureImpl(0, 0));

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

} //Textures

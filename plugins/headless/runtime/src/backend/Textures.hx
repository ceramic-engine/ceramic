package backend;

class Textures #if !completion implements spec.Textures #end {

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
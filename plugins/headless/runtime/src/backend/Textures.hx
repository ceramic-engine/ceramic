package backend;

class Textures implements spec.Textures {

    public function new() {}

    public function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void {

        done(new TextureImpl(0, 0));

    } //load

    public function createTexture(width:Int, height:Int):Texture {

        return null;

    } //createTexture

    public function destroyTexture(texture:Texture):Void {

    } //destroyTexture

    inline public function createRenderTarget(width:Int, height:Int):Texture {

        return new TextureImpl(width, height);

    } //createRenderTarget

    public function destroy(texture:Texture):Void {

        //

    } //destroy

    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:TextureImpl).width;

    } //getWidth

    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:TextureImpl).height;

    } //getHeight

    inline public function getTexturePixels(texture:Texture):Null<UInt8Array> {

        return null;

    } //getTexturePixels

    inline public function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void {

        //

    } //setTextureFilter

} //Textures
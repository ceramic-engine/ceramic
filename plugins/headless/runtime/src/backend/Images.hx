package backend;

class Images implements spec.Images {

    public function new() {}

    public function load(path:String, ?options:LoadImageOptions, done:Image->Void):Void {

        done(new ImageImpl(0, 0));

    } //load

    public function createImage(width:Int, height:Int):Image {

        return null;

    } //createImage

    public function destroyImage(texture:Image):Void {

    } //destroyImage

    inline public function createRenderTarget(width:Int, height:Int):Image {

        return new ImageImpl(width, height);

    } //createRenderTarget

    public function destroy(texture:Image):Void {

        //

    } //destroy

    inline public function getImageWidth(texture:Image):Int {

        return (texture:ImageImpl).width;

    } //getWidth

    inline public function getImageHeight(texture:Image):Int {

        return (texture:ImageImpl).height;

    } //getHeight

    inline public function getImagePixels(texture:Image):Null<UInt8Array> {

        return null;

    } //getImagePixels

} //Images
package backend;

import snow.types.Types;

class ImageImpl {

    public var pixels:Null<UInt8Array> = null;

    public var width:Int = 0;

    public var height:Int = 0;

    public var widthActual:Int = 0;

    public var heightActual:Int = 0;

    public var asset:AssetImage = null;

    public var texture:TextureImpl = null;

    public function new(width:Int = 0, height:Int = 0) {

        this.width = width;
        this.height = height;

    } //new

    function set_asset(asset:AssetImage):AssetImage {
        if (this.asset == asset) return asset;
        this.asset = asset;

        this.width = asset.image.width;
        this.height = asset.image.height;
        this.widthActual = asset.image.width_actual;
        this.heightActual = asset.image.height_actual;
        this.pixels = asset.image.pixels;

        return asset;

    } //set_asset

    public function loadTexture(clearPixels:Bool = true):Void {

        texture = new TextureImpl(width, height);
        if (asset != null) {
            texture.fromAsset(asset, clearPixels);
            if (clearPixels) {
                pixels = null;
                asset.image.pixels = null;
            }
        }

    } //loadTexture

} //ImageImpl

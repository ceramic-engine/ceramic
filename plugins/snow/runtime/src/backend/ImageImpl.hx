package backend;

import snow.types.Types;

class ImageImpl {

    public var pixels:Null<UInt8Array> = null;

    public var texture:TextureImpl = null;

    public var width:Int = 0;

    public var height:Int = 0;

    public var asset:AssetImage = null;

    public function new(width:Int = 0, height:Int = 0) {
        this.width = width;
        this.height = height;
    }

} //ImageImpl

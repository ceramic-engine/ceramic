package backend;

class TextureImpl {
    static var _nextTextureId:Int = 1;
    public var width:Int = 0;
    public var height:Int = 0;
    public var textureId:TextureId = 0;
    public function new(width:Int = 0, height:Int = 0) {
        this.width = width;
        this.height = height;
        this.textureId = _nextTextureId++;
    }
}

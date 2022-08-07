package backend;

class TextureImpl {
    static var _nextTextureId:Int = 1;
    public var width:Int = 0;
    public var height:Int = 0;
    public var depth:Bool = true;
    public var stencil:Bool = true;
    public var antialiasing:Int = 0;
    public var textureId:TextureId = 0;
    public function new(width:Int = 0, height:Int = 0, depth:Bool = true, stencil:Bool = true, antialiasing:Int = 0) {
        this.width = width;
        this.height = height;
        this.depth = depth;
        this.stencil = stencil;
        this.antialiasing = antialiasing;
        this.textureId = _nextTextureId++;
    }
}

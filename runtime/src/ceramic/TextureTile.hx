package ceramic;

@:structInit
class TextureTile {

    public var texture:Texture;

    public var frameX:Float;

    public var frameY:Float;

    public var frameWidth:Float;

    public var frameHeight:Float;

    public function new(texture:Texture, frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float) {

        this.texture = texture;
        this.frameX = frameX;
        this.frameY = frameY;
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;

    } //new

} //TextureTile

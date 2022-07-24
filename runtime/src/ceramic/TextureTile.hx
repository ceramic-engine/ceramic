package ceramic;

@:structInit
class TextureTile {

    public var texture:Texture;

    public var frameX:Float;

    public var frameY:Float;

    public var frameWidth:Float;

    public var frameHeight:Float;

    public var rotateFrame:Bool;

    /**
     * When assigning the file to a quad, edge uvs will be adjusted by this inset.
     * Can be useful to set it to values like `0.5` in some situations like
     * preventing atlas regions from displaying bleed from siblings.
     */
    public var edgeInset:Float;

    public function new(texture:Texture, frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float, rotateFrame:Bool = false, edgeInset:Float = 0) {

        this.texture = texture;
        this.frameX = frameX;
        this.frameY = frameY;
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;
        this.rotateFrame = rotateFrame;
        this.edgeInset = edgeInset;

    }

    function toString() {

        return '' + {
            texture: texture,
            frameX: frameX,
            frameY: frameY,
            frameWidth: frameWidth,
            frameHeight: frameHeight
        };

    }

}

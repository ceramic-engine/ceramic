package ceramic;

class Quad extends Visual {

    public var color:Color = Color.WHITE;

    public var texture(default,set):Texture = null;
    inline function set_texture(texture:Texture):Texture {
        if (this.texture == texture) return texture;
        this.texture = texture;

        // Update frame
        if (texture == null) {
            frameX = -1;
            frameY = -1;
            frameWidth = -1;
            frameHeight = -1;
        }
        else {
            frameX = 0;
            frameY = 0;
            frameWidth = texture.width;
            frameHeight = texture.height;
        }

        return texture;
    }

    public var frameX:Float = -1;

    public var frameY:Float = -1;

    public var frameWidth(default,set):Float = -1;
    inline function set_frameWidth(frameWidth:Float):Float {
        if (this.frameWidth == frameWidth) return frameWidth;
        this.frameWidth = frameWidth;

        // Update width
        realWidth = frameWidth;

        return frameWidth;
    }

    public var frameHeight(default,set):Float = -1;
    inline function set_frameHeight(frameHeight:Float):Float {
        if (this.frameHeight == frameHeight) return frameHeight;
        this.frameHeight = frameHeight;

        // Update height
        realHeight = frameHeight;

        return frameHeight;
    }

/// Helpers

    inline public function frame(frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float):Void {

        this.frameX = frameX;
        this.frameY = frameY;
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;

    } //frame

} //Quad

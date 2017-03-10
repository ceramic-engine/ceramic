package ceramic;

class Sprite extends Visual {

/// Properties

    public var frame(default,set):Frame;
    function set_frame(frame:Frame):Frame {
        if (this.frame == frame) return frame;
        this.frame = frame;
        if (frame != null) {
            realWidth = frame.width;
            realHeight = frame.height;
        } else {
            realWidth = 0;
            realHeight = 0;
        }
        dirty = true;
        return frame;
    }

    override function set_width(width:Float):Float {
        if (frame == null) {
            super.set_width(width);
        } else {
            scaleX = width / frame.width;
        }
        return width;
    }

    override function set_height(height:Float):Float {
        if (frame == null) {
            super.set_height(height);
        } else {
            scaleY = height / frame.height;
        }
        return height;
    }

/// Lifecycle

    private function new() {

        super();

    } //new

/// Factories

    public static function fromFrame(frame:Frame):Sprite {

        var sprite = new Sprite();

        sprite.frame = frame;

        return sprite;

    } //fromFrame

    public static function fromTexture(texture:Texture):Sprite {

        return fromFrame(new Frame(texture));

    } //fromTexture

}

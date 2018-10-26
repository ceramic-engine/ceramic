package ceramic;

import ceramic.Assert.*;

@editable({ implicitSizeUnlessNull: 'texture' })
class Quad extends Visual {

    static var _matrix = Visual._matrix;

    static var _degToRad = Visual._degToRad;

    @editable public var color:Color = Color.WHITE;

    /** If set to `true`, this quad will be considered
        transparent thus won't be draw on screen. 
        Children still behave and get drawn as before:
        they don't inherit this property. */
    @editable public var transparent:Bool = false;

    public var tile(default,set):TextureTile = null;
    function set_tile(tile:TextureTile):TextureTile {
        if (this.tile == tile) return tile;

        this.tile = tile;

        if (tile == null) {
            texture = null;
        }
        else {
            if (texture != tile.texture) {
                texture = tile.texture;
            } else {
                frameX = tile.frameX;
                frameY = tile.frameY;
                frameWidth = tile.frameWidth;
                frameHeight = tile.frameHeight;
            }
        }

        return tile;
    }

    @editable
    public var texture(default,set):Texture = null;
    inline function set_texture(texture:Texture):Texture {

        if (this.texture == texture) return texture;

        assert(texture == null || !texture.destroyed, 'Cannot assign destroyed texture: ' + texture);

        // Unbind previous texture destroy event
        if (this.texture != null) {
            this.texture.offDestroy(textureDestroyed);
            if (this.texture.asset != null) this.texture.asset.release();
        }

        this.texture = texture;

        // Update frame
        if (texture == null) {
            frameX = -1;
            frameY = -1;
            frameWidth = -1;
            frameHeight = -1;
        }
        else if (tile != null) {
            frameX = tile.frameX;
            frameY = tile.frameY;
            frameWidth = tile.frameWidth;
            frameHeight = tile.frameHeight;
        }
        else {
            frameX = 0;
            frameY = 0;
            frameWidth = texture.width;
            frameHeight = texture.height;

            // Ensure we remove the texture if it gets destroyed
            texture.onDestroy(this, textureDestroyed);
            if (texture.asset != null) texture.asset.retain();
        }

        return texture;
    }

    public var rotateFrame(default,set):RotateFrame = RotateFrame.NONE;
    inline function set_rotateFrame(rotateFrame:RotateFrame):RotateFrame {
        if (this.rotateFrame == rotateFrame) return rotateFrame;
        
        this.rotateFrame = rotateFrame;
        matrixDirty = true;
        return rotateFrame;
    }

    public var frameX:Float = -1;

    public var frameY:Float = -1;

    public var frameWidth(default,set):Float = -1;
    inline function set_frameWidth(frameWidth:Float):Float {
        if (this.frameWidth == frameWidth) return frameWidth;
        this.frameWidth = frameWidth;

        // Update width
        if (frameWidth != -1) width = frameWidth;

        return frameWidth;
    }

    public var frameHeight(default,set):Float = -1;
    inline function set_frameHeight(frameHeight:Float):Float {
        if (this.frameHeight == frameHeight) return frameHeight;
        this.frameHeight = frameHeight;

        // Update height
        if (frameHeight != -1) height = frameHeight;

        return frameHeight;
    }

/// Lifecycle

    public function new() {

        super();

        quad = this;

    } //new

/// Helpers

    inline public function frame(frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float):Void {

        this.frameX = frameX;
        this.frameY = frameY;
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;

    } //frame

/// Overrides

    override function computeMatrix() {

        if (parent != null && parent.matrixDirty) {
            parent.computeMatrix();
        }

        _matrix.identity();

        if (texture != null) {
            if (rotateFrame == RotateFrame.ROTATE_90) {
                _matrix.rotate(90 * _degToRad);
                _matrix.tx += frameWidth;
            }
        }

        doComputeMatrix();

    } //computeMatrix

/// Texture destroyed

    function textureDestroyed() {

        // Remove texture (and/or tile) because it has been destroyed
        this.texture = null;
        this.tile = null;

    } //textureDestroyed

} //Quad

package ceramic;

import ceramic.Assert.*;
import ceramic.Visual;

@editable({
    implicitSizeUnlessNull: 'texture'
})
class Quad extends Visual {

    private inline static final FLAG_TRANSPARENT:Int = 16; // 1 << 4
    private inline static final FLAG_ROTATE_FRAME:Int = 32; // 1 << 5

    static var _matrix = Visual._matrix;

    static var _degToRad = Visual._degToRad;

    @editable
    public var color:Color = Color.WHITE;

    /**
     * If set to `true`, this quad will be considered
     * transparent thus won't be draw on screen.
     * Children still behave and get drawn as before:
     * they don't inherit this property.
     */
    @editable
    public var transparent(get,set):Bool;
    inline function get_transparent():Bool {
        return flags & FLAG_TRANSPARENT == FLAG_TRANSPARENT;
    }
    inline function set_transparent(transparent:Bool):Bool {
        flags = transparent ? flags | FLAG_TRANSPARENT : flags & ~FLAG_TRANSPARENT;
        return transparent;
    }

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
            }

            frameX = tile.frameX + tile.edgeInset;
            frameY = tile.frameY + tile.edgeInset;
            frameWidth = tile.frameWidth - tile.edgeInset * 2;
            frameHeight = tile.frameHeight - tile.edgeInset * 2;
            width = tile.frameWidth;
            height = tile.frameHeight;

            rotateFrame = tile.rotateFrame;
        }

        return tile;
    }

    @editable
    public var texture(get,set):Texture;
    inline function get_texture():Texture {
        return _texture;
    }
    inline function set_texture(texture:Texture):Texture {

        if (_texture != texture) {
            _set_texture(texture);
        }

        return texture;
    }
    var _texture:Texture = null;
    function _set_texture(texture:Texture):Void {

        assert(texture == null || !texture.destroyed, 'Cannot assign destroyed texture: ' + texture);

        if (_texture != null) {
            // Unbind previous texture destroy event
            _texture.offDestroy(textureDestroyed);
            if (_texture.asset != null) _texture.asset.release();
        }

        _texture = texture;

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

            // Ensure we remove the texture if it gets destroyed
            texture.onDestroy(this, textureDestroyed);
            if (texture.asset != null) texture.asset.retain();
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

    public var rotateFrame(get,set):Bool;
    inline function get_rotateFrame():Bool {
        return flags & FLAG_ROTATE_FRAME == FLAG_ROTATE_FRAME;
    }
    inline function set_rotateFrame(rotateFrame:Bool):Bool {
        flags = rotateFrame ? flags | FLAG_ROTATE_FRAME : flags & ~FLAG_ROTATE_FRAME;
        return rotateFrame;
    }

/// Lifecycle

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        asQuad = this;

    }

    override function destroy() {

        // Will update texture asset retain count and render target dependencies accordingly
        texture = null;

        super.destroy();

    }

/// Helpers

    inline public function frame(frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float):Void {

        this.frameX = frameX;
        this.frameY = frameY;
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;

    }

/// Overrides

    override function computeMatrix() {

        if (parent != null && parent.matrixDirty) {
            parent.computeMatrix();
        }

        _matrix.identity();

        doComputeMatrix();

    }

/// Texture destroyed

    function textureDestroyed(_) {

        // Remove texture (and/or tile) because it has been destroyed
        this.texture = null;
        this.tile = null;

    }

#if editor

/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('width', 100);
        entityData.props.set('height', 100);

    }

#end

}

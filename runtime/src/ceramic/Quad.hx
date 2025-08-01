package ceramic;

import ceramic.Assert.*;
import ceramic.Visual;

using ceramic.Extensions;

/**
 * The most basic and commonly used visual for displaying rectangles and images.
 * 
 * Quad is a specialized Visual that renders a rectangular shape which can be:
 * - A solid colored rectangle
 * - A textured rectangle (displaying an image)
 * - A portion of a texture (using frame coordinates)
 * 
 * Features:
 * - Color tinting
 * - Texture/image display
 * - Frame-based texture regions (for sprite sheets)
 * - Transparency control
 * - Texture tile support
 * - Automatic size from texture
 * 
 * Quads are the building blocks for most 2D visuals in Ceramic.
 * They're optimized for performance and batched together when possible.
 * 
 * @example
 * ```haxe
 * // Create a colored rectangle
 * var rect = new Quad();
 * rect.size(100, 50);
 * rect.color = Color.RED;
 * rect.pos(10, 10);
 * 
 * // Create a textured quad
 * var image = new Quad();
 * image.texture = assets.texture('hero');
 * image.anchor(0.5, 0.5);
 * image.pos(screen.width * 0.5, screen.height * 0.5);
 * 
 * // Use a portion of a texture
 * var sprite = new Quad();
 * sprite.texture = assets.texture('spritesheet');
 * sprite.frame(32, 64, 16, 16); // x, y, width, height
 * ```
 * 
 * @see Visual
 * @see Mesh
 * @see Texture
 */
class Quad extends Visual {

    private inline static final FLAG_TRANSPARENT:Int = 16; // 1 << 4
    private inline static final FLAG_ROTATE_FRAME:Int = 32; // 1 << 5

    static var _matrix = Visual._matrix;

    static var _degToRad = Visual._degToRad;

    /**
     * The color to tint this quad.
     * Default is WHITE (no tinting).
     * The color is multiplied with the texture colors if a texture is set.
     * Use this to tint images or create colored rectangles.
     */
    public var color:Color = Color.WHITE;

    /**
     * If set to `true`, this quad will be considered
     * transparent and won't be drawn on screen.
     * This only affects this quad's rendering - children
     * are still drawn normally (transparency is not inherited).
     * Useful for invisible containers or temporarily hiding quads.
     */
    public var transparent(get,set):Bool;
    inline function get_transparent():Bool {
        return flags & FLAG_TRANSPARENT == FLAG_TRANSPARENT;
    }
    inline function set_transparent(transparent:Bool):Bool {
        flags = transparent ? flags | FLAG_TRANSPARENT : flags & ~FLAG_TRANSPARENT;
        return transparent;
    }

    /**
     * A texture tile defining a region of a texture to display.
     * When set, automatically configures the texture and frame properties.
     * Useful for working with texture atlases and sprite sheets.
     * Setting this to null clears the texture.
     */
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

    /**
     * The texture (image) to display on this quad.
     * When set, the quad's size is automatically updated to match the texture size
     * unless a tile or frame is specified.
     * Setting to null makes the quad display as a solid color.
     * The texture's asset reference count is automatically managed.
     */
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

    /**
     * The X coordinate of the texture region to display.
     * Used with frameWidth/frameHeight to display a portion of the texture.
     * -1 means no frame is set (display entire texture).
     */
    public var frameX:Float = -1;

    /**
     * The Y coordinate of the texture region to display.
     * Used with frameWidth/frameHeight to display a portion of the texture.
     * -1 means no frame is set (display entire texture).
     */
    public var frameY:Float = -1;

    /**
     * The width of the texture region to display.
     * When set, also updates the quad's display width.
     * -1 means no frame is set (use full texture width).
     */
    public var frameWidth(default,set):Float = -1;
    inline function set_frameWidth(frameWidth:Float):Float {
        if (this.frameWidth == frameWidth) return frameWidth;
        this.frameWidth = frameWidth;

        // Update width
        if (frameWidth != -1) width = frameWidth;

        return frameWidth;
    }

    /**
     * The height of the texture region to display.
     * When set, also updates the quad's display height.
     * -1 means no frame is set (use full texture height).
     */
    public var frameHeight(default,set):Float = -1;
    inline function set_frameHeight(frameHeight:Float):Float {
        if (this.frameHeight == frameHeight) return frameHeight;
        this.frameHeight = frameHeight;

        // Update height
        if (frameHeight != -1) height = frameHeight;

        return frameHeight;
    }

    /**
     * Whether the texture frame should be rotated 90 degrees.
     * Used internally by texture packing systems to optimize atlas space.
     * Most users won't need to set this directly.
     */
    public var rotateFrame(get,set):Bool;
    inline function get_rotateFrame():Bool {
        return flags & FLAG_ROTATE_FRAME == FLAG_ROTATE_FRAME;
    }
    inline function set_rotateFrame(rotateFrame:Bool):Bool {
        flags = rotateFrame ? flags | FLAG_ROTATE_FRAME : flags & ~FLAG_ROTATE_FRAME;
        return rotateFrame;
    }

#if ceramic_quad_float_attributes

    public var floatAttributes:Array<Float> = null;

    #if ceramic_quad_dark_color

    /**
     * Set a dark color to the quad for special tinting effects.
     * Only works when using a shader that supports dark color (like TINT_BLACK).
     * This allows for more complex color effects than simple multiplication.
     * Requires ceramic_quad_dark_color and ceramic_quad_float_attributes defines.
     */
    public var darkColor(get,set):Color;
    function get_darkColor():Color {
        if (floatAttributes == null || floatAttributes.length < 3) {
            return Color.BLACK;
        }
        else {
            return Color.fromRGBFloat(
                floatAttributes.unsafeGet(0),
                floatAttributes.unsafeGet(1),
                floatAttributes.unsafeGet(2)
            );
        }
    }
    function set_darkColor(darkColor:Color):Color {
        if (floatAttributes == null) {
            floatAttributes = [
                darkColor.redFloat,
                darkColor.greenFloat,
                darkColor.blueFloat,
                1.0
            ];
        }
        else {
            floatAttributes[0] = darkColor.redFloat;
            floatAttributes[1] = darkColor.greenFloat;
            floatAttributes[2] = darkColor.blueFloat;
        }
        return darkColor;
    }

    #end

#end

/// Lifecycle

    /**
     * Create a new Quad.
     * The quad starts with no texture (solid color) and must be
     * sized and positioned after creation.
     */
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

    /**
     * Set the texture frame coordinates and size in one call.
     * Useful for displaying a specific region of a texture (sprite sheets).
     * @param frameX X coordinate in the texture
     * @param frameY Y coordinate in the texture
     * @param frameWidth Width of the region to display
     * @param frameHeight Height of the region to display
     */
    inline public function frame(frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float):Void {

        this.frameX = frameX;
        this.frameY = frameY;
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;

    }

    /**
     * Returns `true` if this quad is a regular rectangle.
     * A quad is regular if it has no rotation or skew transformations.
     * Regular quads can be rendered more efficiently in some cases.
     * @return True if the quad is axis-aligned without skew
     */
    public function isRegular():Bool {

        if (matrixDirty)
            computeMatrix();

        var w = width;
        var h = height;

        return (matC * h == 0 && matB * w == 0 && matC * h == 0 && matB * w == 0);

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

}

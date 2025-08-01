package ceramic;

/**
 * Defines a rectangular sub-region within a texture for rendering.
 * 
 * TextureTile represents a portion of a texture that can be rendered
 * independently, similar to a sprite frame. It's commonly used for:
 * - Texture atlas regions
 * - Sprite sheet frames
 * - Tiled textures
 * - UI element slicing
 * 
 * The tile can be assigned to visual objects like Quad.tile to render
 * only the specified portion of the texture. Supports rotation for
 * optimally packed texture atlases and edge insets to prevent bleeding.
 * 
 * @example
 * ```haxe
 * // Create a tile from a sprite sheet
 * var spriteSheet = assets.texture('characters.png');
 * var playerTile = new TextureTile(
 *     spriteSheet,
 *     0, 0,      // Top-left corner
 *     32, 48,    // 32x48 sprite
 *     false, 0.5 // No rotation, 0.5 pixel inset
 * );
 * 
 * // Apply to a quad
 * var player = new Quad();
 * player.tile = playerTile;
 * player.size(32, 48);
 * ```
 * 
 * @see Quad.tile Property that accepts TextureTile
 * @see TextureAtlasRegion Extends this class for atlas support
 * @see Texture The source texture containing the tile
 */
@:structInit
class TextureTile {

    /**
     * The source texture containing this tile.
     * 
     * References the full texture from which this tile
     * extracts its rectangular region. Must be a valid
     * loaded texture for the tile to render.
     */
    public var texture:Texture;

    /**
     * X coordinate of the tile's top-left corner in the texture.
     * 
     * Measured in texture pixels from the texture's origin.
     * Combined with frameWidth defines the horizontal bounds.
     */
    public var frameX:Float;

    /**
     * Y coordinate of the tile's top-left corner in the texture.
     * 
     * Measured in texture pixels from the texture's origin.
     * Combined with frameHeight defines the vertical bounds.
     */
    public var frameY:Float;

    /**
     * Width of the tile region in texture pixels.
     * 
     * Defines how many pixels wide to sample from the texture
     * starting at frameX. Should not exceed texture bounds.
     */
    public var frameWidth:Float;

    /**
     * Height of the tile region in texture pixels.
     * 
     * Defines how many pixels tall to sample from the texture
     * starting at frameY. Should not exceed texture bounds.
     */
    public var frameHeight:Float;

    /**
     * Whether this tile is rotated 90 degrees in the texture.
     * 
     * Used by texture packers to fit more images by rotating them.
     * When true, the tile's width and height are swapped during
     * rendering to display correctly. Common in optimized atlases.
     */
    public var rotateFrame:Bool;

    /**
     * Pixel inset applied to tile edges during rendering.
     * 
     * Shrinks the UV coordinates by this amount to prevent texture
     * bleeding between adjacent tiles in an atlas. Useful values:
     * - 0: No inset (default)
     * - 0.5: Half-pixel inset (common for atlases)
     * - 1.0: Full pixel inset (for problematic cases)
     * 
     * The inset is applied in texture space, not screen space.
     */
    public var edgeInset:Float;

    /**
     * Creates a new texture tile.
     * 
     * @param texture Source texture containing the tile
     * @param frameX X coordinate in texture pixels
     * @param frameY Y coordinate in texture pixels
     * @param frameWidth Width in texture pixels
     * @param frameHeight Height in texture pixels
     * @param rotateFrame Whether tile is rotated 90 degrees (default: false)
     * @param edgeInset Pixel inset for edge bleeding prevention (default: 0)
     */
    public function new(texture:Texture, frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float, rotateFrame:Bool = false, edgeInset:Float = 0) {

        this.texture = texture;
        this.frameX = frameX;
        this.frameY = frameY;
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;
        this.rotateFrame = rotateFrame;
        this.edgeInset = edgeInset;

    }

    /**
     * Updates the tile's frame coordinates.
     * 
     * Convenience method to update all frame properties at once.
     * Does not affect texture, rotation, or inset settings.
     * 
     * @param frameX New X coordinate in texture pixels
     * @param frameY New Y coordinate in texture pixels
     * @param frameWidth New width in texture pixels
     * @param frameHeight New height in texture pixels
     */
    inline public function frame(frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float):Void {

        this.frameX = frameX;
        this.frameY = frameY;
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;

    }

    /**
     * Returns a string representation of this tile.
     * 
     * Includes texture reference and frame coordinates for debugging.
     * Rotation and inset values are not included in the output.
     * 
     * @return String with tile properties
     */
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

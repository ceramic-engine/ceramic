package ceramic;

import ceramic.Shortcuts.*;

/**
 * Represents a single image region within a texture atlas.
 *
 * TextureAtlasRegion defines a rectangular area within a texture atlas page
 * that contains a specific image. It extends TextureTile, allowing it to be
 * directly assigned to visual objects like Quad.tile for rendering.
 *
 * Key features:
 * - Supports trimmed sprites with offset data
 * - Handles rotated regions for optimal packing
 * - Automatic UV coordinate calculation
 * - Direct integration with the rendering system
 *
 * The region stores both the packed dimensions (actual space used in atlas)
 * and original dimensions (including trimmed transparent areas), enabling
 * proper sprite alignment and collision detection.
 *
 * ```haxe
 * // Get a region from atlas
 * var region = atlas.region("player_idle");
 *
 * // Apply to a quad (basic support)
 * var quad = new Quad();
 * quad.tile = region;
 *
 * // Position accounting for trim offset
 * quad.pos(100 + region.offsetX, 200 + region.offsetY);
 *
 * // Apply to a sprite (extended support of trimmed regions with offsets, needs sprite plugin)
 * var sprite = new Sprite();
 * sprite.region = region;
 * ```
 *
 * @see TextureAtlas The container for regions
 * @see TextureTile Base class for texture sub-regions
 * @see Quad.tile Property that accepts TextureAtlasRegion
 */
class TextureAtlasRegion extends TextureTile {

    /**
     * Unique identifier for this region within the atlas.
     *
     * Used to retrieve specific images from the atlas.
     * Often matches the original image filename without extension.
     */
    public var name:String = null;

    /**
     * Reference to the containing texture atlas.
     *
     * Provides access to the atlas pages and other regions.
     * Set automatically during region creation.
     */
    public var atlas:TextureAtlas = null;

    /**
     * Index of the texture page containing this region.
     *
     * Large atlases may span multiple texture pages.
     * Used to retrieve the correct texture for rendering.
     */
    public var page:Int = 0;

    /**
     * Actual width of packed pixels in the atlas.
     *
     * This is the width after any rotation applied during packing.
     * May be different from display width if the region was rotated.
     * Used for texture coordinate calculations.
     */
    public var packedWidth:Int = 0;

    /**
     * Actual height of packed pixels in the atlas.
     *
     * This is the height after any rotation applied during packing.
     * May be different from display height if the region was rotated.
     * Used for texture coordinate calculations.
     */
    public var packedHeight:Int = 0;

    /**
     * X position of the region within its texture page.
     *
     * Pixel coordinate from the left edge of the texture.
     * Used to calculate texture coordinates for rendering.
     */
    public var x:Int = 0;

    /**
     * Y position of the region within its texture page.
     *
     * Pixel coordinate from the top edge of the texture.
     * Used to calculate texture coordinates for rendering.
     */
    public var y:Int = 0;

    /**
     * Display width of the region (before any rotation).
     *
     * This is the width of the visible pixels, excluding
     * any transparent areas that were trimmed during packing.
     */
    public var width:Int = 0;

    /**
     * Display height of the region (before any rotation).
     *
     * This is the height of the visible pixels, excluding
     * any transparent areas that were trimmed during packing.
     */
    public var height:Int = 0;

    /**
     * Horizontal offset from original sprite origin.
     *
     * When sprites are trimmed, this offset maintains proper
     * alignment. Positive values shift the sprite right.
     * Add to sprite X position for correct placement.
     */
    public var offsetX:Float = 0;

    /**
     * Vertical offset from original sprite origin.
     *
     * When sprites are trimmed, this offset maintains proper
     * alignment. Positive values shift the sprite down.
     * Add to sprite Y position for correct placement.
     */
    public var offsetY:Float = 0;

    /**
     * Original sprite width before trimming.
     *
     * Includes any transparent margins that were removed during
     * atlas packing. Use this for maintaining consistent sprite
     * sizes and proper collision bounds.
     */
    public var originalWidth:Int = 0;

    /**
     * Original sprite height before trimming.
     *
     * Includes any transparent margins that were removed during
     * atlas packing. Use this for maintaining consistent sprite
     * sizes and proper collision bounds.
     */
    public var originalHeight:Int = 0;

    /**
     * Creates a new texture atlas region.
     *
     * Typically called internally by atlas parsers and packers.
     * Automatically registers this region with the atlas.
     *
     * @param name Unique identifier for this region
     * @param atlas The containing texture atlas
     * @param page Index of the texture page containing this region
     */
    public function new(name:String, atlas:TextureAtlas, page:Int) {

        this.name = name;
        this.atlas = atlas;
        this.page = page;

        var pageInfo = atlas.pages[page];
        super(
            pageInfo != null ? pageInfo.texture : null,
            0, 0, 0, 0, false, 0
        );

        atlas.regions.push(this);

    }

/// Helpers

    /**
     * Calculates texture coordinates from pixel positions.
     *
     * Converts the pixel-based region coordinates (x, y, width, height)
     * into normalized UV coordinates for GPU rendering. This method must
     * be called after the atlas page textures are loaded to ensure proper
     * coordinate calculation.
     *
     * The method handles:
     * - Texture density scaling
     * - Coordinate normalization (0-1 range)
     * - Frame property updates for rendering
     *
     * Typically called automatically by TextureAtlas.computeFrames()
     * after all pages are loaded.
     */
    public function computeFrame():Void {

        var pageInfo = atlas.pages[page];
        if (pageInfo != null) {
            texture = pageInfo.texture;
            if (texture != null) {
                var pageWidth = pageInfo.width;
                var pageHeight = pageInfo.height;
                var ratioX = texture.width / pageWidth;
                var ratioY = texture.height / pageHeight;

                this.frameX = x * ratioX;
                this.frameY = y * ratioY;
                this.frameWidth = width * ratioX;
                this.frameHeight = height * ratioY;
            }
            else {
                log.warning('Failed to compute region frame because there is no texture at page $page');
            }
        }
        else {
            log.warning('Failed to compute region frame because there is no page $page');
        }

    }

    /**
     * Returns a detailed string representation of this region.
     *
     * Includes all region properties for debugging purposes:
     * name, page index, dimensions, offsets, and texture coordinates.
     *
     * @return String representation with all region data
     */
    override function toString() {

        return '' + {
            name: name,
            page: page,
            texture: texture,
            packedWidth: packedWidth,
            packedHeight: packedHeight,
            originalWidth: originalWidth,
            originalHeight: originalHeight,
            width: width,
            height: height,
            offsetX: offsetX,
            offsetY: offsetY,
            frameX: frameX,
            frameY: frameY,
            frameWidth: frameWidth,
            frameHeight: frameHeight
        };

    }

}

package ceramic;

using ceramic.Extensions;

/**
 * A texture atlas that combines multiple images into larger textures for efficient rendering.
 *
 * TextureAtlas is a fundamental optimization technique in game development that packs
 * multiple smaller images (sprites, UI elements, etc.) into larger texture pages.
 * This reduces texture switches during rendering, improving performance significantly.
 *
 * Benefits of texture atlases:
 * - Reduced draw calls by batching sprites from the same atlas
 * - Better texture memory usage and cache efficiency
 * - Simplified asset management for related images
 * - Support for texture bleeding prevention with padding
 *
 * The atlas consists of:
 * - Pages: One or more large textures containing packed images
 * - Regions: Individual images within the pages with position data
 * - Metadata: Names, coordinates, and optional rotation info
 *
 * @example
 * ```haxe
 * // Load a texture atlas
 * var atlas = app.assets.atlas('characters');
 *
 * // Get a specific region
 * var heroRegion = atlas.region('hero_idle');
 *
 * // Apply to a quad
 * var quad = new Quad();
 * quad.tile = heroRegion;
 *
 * // Apply to a sprite: needs sprite plugin,
 * // but supports region offsets which are not
 * // supported on plain quad tiles
 * var sprite = new Sprite();
 * sprite.region = heroRegion;
 * ```
 *
 * @see TextureAtlasPage Individual texture pages in the atlas
 * @see TextureAtlasRegion Individual image regions within pages
 * @see AtlasAsset For loading atlas files
 * @see TextureAtlasPacker For creating atlases at runtime
 */
class TextureAtlas extends Entity {

    /**
     * The texture pages of this atlas.
     *
     * Large atlases may span multiple texture pages to accommodate
     * all images while respecting maximum texture size limits.
     * Each page is a separate GPU texture containing packed images.
     */
    public var pages:Array<TextureAtlasPage> = [];

    /**
     * All texture regions contained in this atlas.
     *
     * Each region represents a single image within the atlas,
     * with its location, size, and optional metadata. Regions
     * reference their containing page by index.
     */
    public var regions:Array<TextureAtlasRegion> = [];

    /**
     * The asset that loaded this atlas.
     *
     * Reference to the AtlasAsset for resource management.
     * Will be destroyed when the atlas is destroyed to ensure
     * proper cleanup of loaded resources.
     */
    public var asset:AtlasAsset = null;

    /**
     * Creates a new empty texture atlas.
     *
     * Typically, atlases are loaded via Assets.atlas() rather than
     * created directly, but this can be used for runtime atlas generation.
     */
    public function new() {

        super();

    }

    /**
     * Finds a texture region by name.
     *
     * Searches through all regions in the atlas for one matching
     * the specified name. Names should be unique within an atlas.
     *
     * @param name The name of the region to find
     * @return The matching TextureAtlasRegion, or null if not found
     *
     * @example
     * ```haxe
     * // Get specific sprite from atlas
     * var enemyRegion = atlas.region('enemy_walk_01');
     * if (enemyRegion != null) {
     *     enemySprite.region = enemyRegion;
     * }
     *
     * // Check if region exists
     * if (atlas.region('powerup_star') != null) {
     *     showPowerup();
     * }
     * ```
     */
    public function region(name:String):TextureAtlasRegion {

        for (i in 0...regions.length) {
            var region = regions.unsafeGet(i);
            if (region.name == name)
                return region;
        }

        return null;

    }

    /**
     * Computes texture coordinates for all regions after pages are loaded.
     *
     * This method must be called after all page textures are loaded to
     * calculate the actual UV coordinates for each region. It converts
     * pixel positions to normalized texture coordinates based on the
     * actual texture dimensions.
     *
     * This is typically called automatically by the asset loader,
     * but may need manual invocation when building atlases at runtime.
     *
     * @example
     * ```haxe
     * // Manual atlas creation
     * var atlas = new TextureAtlas();
     * // ... add pages and regions ...
     * atlas.computeFrames(); // Calculate UVs
     * ```
     */
    public function computeFrames() {

        for (i in 0...regions.length) {
            var region = regions.unsafeGet(i);
            region.computeFrame();
        }

    }

    /**
     * Destroys the atlas and all associated resources.
     *
     * Cleans up:
     * - All page textures (GPU memory)
     * - The associated asset (if any)
     * - Region data and metadata
     *
     * After destruction, this atlas should not be used.
     */
    override function destroy() {

        while (pages.length > 0) {
            var page = pages.pop();
            var texture = page.texture;
            if (texture != null) {
                texture.destroy();
            }
        }

        if (asset != null) asset.destroy();

        super.destroy();

    }

}

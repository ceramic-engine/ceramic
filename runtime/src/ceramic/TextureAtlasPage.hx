package ceramic;

import tracker.Observable;

/**
 * Represents a single texture page within a texture atlas.
 *
 * TextureAtlasPage holds the actual GPU texture containing packed images
 * and metadata about the page dimensions and filtering. Large atlases may
 * consist of multiple pages when images don't fit within texture size limits.
 *
 * Pages are observable, allowing UI or debugging tools to react to changes
 * in texture assignment or filtering modes. Each page is referenced by
 * regions via their page index.
 *
 * Features:
 * - Observable properties for reactive updates
 * - Automatic dimension detection from texture
 * - Filter mode propagation to texture
 * - Named identification for debugging
 *
 * @example
 * ```haxe
 * // Access a page from an atlas
 * var page = atlas.pages[0];
 * trace('Page ${page.name}: ${page.width}x${page.height}');
 *
 * // Change filtering for all regions on this page
 * page.filter = NEAREST; // For pixel art
 * ```
 *
 * @see TextureAtlas Container that manages pages
 * @see TextureAtlasRegion References pages by index
 * @see Texture The GPU texture resource
 */
class TextureAtlasPage implements Observable {

    /**
     * Unique identifier for this page.
     *
     * Typically in format like "page0", "atlas_0", or custom names.
     * Used for debugging and in some atlas formats for page references.
     */
    @observe public var name:String;

    /**
     * Width of this page in pixels.
     *
     * Set explicitly or auto-detected from the texture.
     * Observable to allow reactive updates when page size changes.
     */
    @observe public var width:Float = 0;

    /**
     * Height of this page in pixels.
     *
     * Set explicitly or auto-detected from the texture.
     * Observable to allow reactive updates when page size changes.
     */
    @observe public var height:Float = 0;

    /**
     * Texture filtering mode for this page.
     *
     * Controls how the texture is sampled:
     * - LINEAR: Smooth interpolation (default)
     * - NEAREST: Pixel-perfect sampling
     *
     * When changed, automatically updates the associated texture.
     * All regions on this page share the same filter setting.
     */
    @observe public var filter(default, set):TextureFilter = LINEAR;
    function set_filter(filter:TextureFilter):TextureFilter {
        if (this.filter != filter) {
            this.filter = filter;
            if (texture != null) {
                texture.filter = filter;
            }
        }
        return filter;
    }

    /**
     * The GPU texture containing the packed images.
     *
     * This texture holds all regions assigned to this page.
     * When set, automatically updates width/height if not already specified.
     * Observable to allow monitoring texture changes or hot-reloading.
     */
    @observe public var texture(default, set):Texture = null;

    function set_texture(texture:Texture):Texture {
        if (this.texture != texture) {
            this.texture = texture;
            if (texture != null) {
                if (width <= 0)
                    width = texture.nativeWidth;
                if (height <= 0)
                    height = texture.nativeHeight;
            }
        }
        return texture;
    }

    /**
     * Creates a new texture atlas page.
     *
     * @param name Identifier for this page
     * @param width Page width in pixels (0 to auto-detect from texture)
     * @param height Page height in pixels (0 to auto-detect from texture)
     * @param filter Texture filtering mode (default: LINEAR)
     * @param texture Optional texture to assign immediately
     */
    public function new(name:String, width:Float = 0, height:Float = 0, filter:TextureFilter = LINEAR, texture:Texture = null) {

        this.name = name;
        this.width = width;
        this.height = height;
        this.filter = filter;
        this.texture = texture;

    }

}

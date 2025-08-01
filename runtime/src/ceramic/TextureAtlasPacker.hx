package ceramic;

import binpacking.MaxRectsPacker;
import ceramic.UInt8Array;

using StringTools;

/**
 * Dynamic texture atlas builder that packs multiple images into optimized texture pages at runtime.
 * 
 * TextureAtlasPacker uses bin packing algorithms to efficiently arrange images into
 * larger textures, minimizing wasted space and texture switches. This is useful for:
 * - Dynamically generated content (procedural graphics, text rendering)
 * - User-generated content that needs atlasing
 * - Optimizing texture usage for varying screen resolutions
 * - Creating atlases from individual loaded images
 * 
 * The packer features:
 * - Automatic page size growth (32x32 to 2048x2048)
 * - Multi-page support when content exceeds maximum size
 * - Configurable spacing between packed images
 * - Support for trimmed sprites with offset data
 * - Variant regions that share texture data
 * 
 * @example
 * ```haxe
 * // Create a packer
 * var packer = new TextureAtlasPacker();
 * packer.spacing = 2; // 2 pixel margin
 * packer.filter = LINEAR;
 * 
 * // Add regions from pixel data
 * packer.add("player_idle", idlePixels, 64, 64, 60, 60, 2, 2);
 * packer.add("player_walk", walkPixels, 64, 64, 62, 62, 1, 1);
 * 
 * // Pack and get resulting atlas
 * packer.pack((atlas) -> {
 *     var playerRegion = atlas.region("player_idle");
 *     playerSprite.region = playerRegion;
 * });
 * ```
 * 
 * @see TextureAtlas The resulting atlas after packing
 * @see TextureAtlasRegion Individual regions in the atlas
 * @see binpacking.MaxRectsPacker The underlying bin packing algorithm
 */
class TextureAtlasPacker extends Entity {

    /**
     * Event emitted when packing is complete.
     * 
     * Fired after all regions have been successfully packed
     * and textures have been created. The atlas is ready for use.
     */
    @event function finishPack();

    /**
     * Minimum texture page size in pixels.
     * Pages start at this size and grow as needed.
     */
    static final MIN_TEXTURE_SIZE:Int = 32;

    /**
     * Maximum texture page size in pixels.
     * When exceeded, additional pages are created.
     * This limit ensures compatibility with most GPUs.
     */
    static final MAX_TEXTURE_SIZE:Int = 2048;

    /**
     * The resulting texture atlas after packing.
     * 
     * Created on first pack() call and reused for subsequent packing.
     * Contains all pages and regions that have been packed.
     */
    public var atlas(default, null):TextureAtlas = null;

    /**
     * Spacing between packed regions in pixels.
     * 
     * Adds a margin around each packed image to prevent texture bleeding
     * during filtering. Recommended values: 1-2 pixels for linear filtering,
     * 0 for nearest neighbor filtering.
     * 
     * Default: 1
     */
    public var spacing:Int = 1;

    /**
     * Texture filtering mode for atlas pages.
     * 
     * Applied to all texture pages created by this packer.
     * - LINEAR: Smooth filtering (best for scaled graphics)
     * - NEAREST: Pixel-perfect filtering (best for pixel art)
     * 
     * Default: LINEAR
     */
    public var filter:TextureFilter = LINEAR;

    /**
     * Regions waiting to be packed.
     * Populated by add() calls, cleared after pack().
     */
    private var pendingRegions:Array<TextureAtlasPackerRegion> = [];

    /**
     * Internal page data for bin packing.
     * Each page tracks its packer, regions, and texture state.
     */
    private var pages:Array<TextureAtlasPackerPage> = [];

    /**
     * Creates a new texture atlas packer.
     * 
     * The packer starts empty - use add() to queue regions
     * and pack() to build the atlas.
     */
    public function new() {

        super();

    }

    /**
     * Checks if there are regions waiting to be packed.
     * 
     * @return True if add() has been called but pack() hasn't processed the regions yet
     */
    public function hasPendingRegions():Bool {

        return pendingRegions != null && pendingRegions.length > 0;

    }

    /**
     * Finds a region by name in pending or packed regions.
     * 
     * Searches both regions waiting to be packed and regions
     * already packed into pages. Useful for creating variant regions
     * or checking if a region exists.
     * 
     * @param name The region name to search for
     * @return The packer region data, or null if not found
     */
    public function region(name:String):TextureAtlasPackerRegion {

        if (pendingRegions != null) {
            for (i in 0...pendingRegions.length) {
                var region = pendingRegions[i];
                if (region.name == name) {
                    return region;
                }
            }
        }

        if (pages != null) {
            for (p in 0...pages.length) {
                var page = pages[p];
                for (i in 0...page.regions.length) {
                    var region = page.regions[i];
                    if (region.name == name) {
                        return region;
                    }
                }
            }
        }

        return null;

    }

    /**
     * Removes regions from the packer using a custom matching function.
     * 
     * This method allows selective removal of regions based on any criteria.
     * It handles cleanup of both pending regions and already-packed regions,
     * reorganizing the atlas as needed.
     * 
     * @param removeAtlasRegions If true, also removes matching regions from the final atlas
     * @param matcher Function that returns true for regions to remove
     * 
     * @example
     * ```haxe
     * // Remove all enemy sprites
     * packer.removeRegionsWithMatcher(true, name -> name.indexOf("enemy_") == 0);
     * 
     * // Remove temporary regions
     * packer.removeRegionsWithMatcher(true, name -> tempRegions.exists(name));
     * ```
     */
    public function removeRegionsWithMatcher(removeAtlasRegions:Bool = true, matcher:(regionName:String)->Bool):Void {

        if (pendingRegions != null) {
            var pendingToRemove:Array<TextureAtlasPackerRegion> = null;
            for (i in 0...pendingRegions.length) {
                var region = pendingRegions[i];
                if (matcher(region.name)) {
                    if (pendingToRemove == null)
                        pendingToRemove = [];
                    pendingToRemove.push(region);
                }
            }
            if (pendingToRemove != null) {
                for (i in 0...pendingToRemove.length) {
                    var region = pendingToRemove[i];
                    pendingRegions.remove(region);
                }
            }
        }

        if (pages != null) {
            var pagesToRemove:Array<TextureAtlasPackerPage> = null;
            for (p in 0...pages.length) {
                var pendingToRemove:Array<TextureAtlasPackerRegion> = null;
                var page = pages[p];
                for (i in 0...page.regions.length) {
                    var region = page.regions[i];
                    if (matcher(region.name)) {
                        if (pendingToRemove == null)
                            pendingToRemove = [];
                        pendingToRemove.push(region);
                    }
                }
                if (pendingToRemove != null) {
                    if (pagesToRemove == null)
                        pagesToRemove = [];
                    pagesToRemove.push(page);
                    for (i in 0...pendingToRemove.length) {
                        var region = pendingToRemove[i];
                        page.regions.remove(region);
                        page.shouldResetTexture = true;
                    }
                    if (pendingRegions != null)
                        pendingRegions = [];
                    for (i in 0...page.regions.length) {
                        var region = page.regions[i];
                        region.rect = null;
                        region.rendered = false;
                        pendingRegions.unshift(region);
                    }
                }
            }
            if (pagesToRemove != null) {
                for (p in 0...pagesToRemove.length) {
                    pages.remove(pagesToRemove[p]);
                }
            }
        }

        if (removeAtlasRegions && atlas != null) {
            var toRemoveInAtlas:Array<TextureAtlasRegion> = null;
            for (i in 0...atlas.regions.length) {
                var atlasRegion = atlas.regions[i];
                if (matcher(atlasRegion.name)) {
                    if (toRemoveInAtlas == null)
                        toRemoveInAtlas = [];
                    toRemoveInAtlas.push(atlasRegion);
                }
            }
            if (toRemoveInAtlas != null) {
                for (i in 0...toRemoveInAtlas.length) {
                    atlas.regions.remove(toRemoveInAtlas[i]);
                }
            }
        }

    }

    /**
     * Removes all regions whose names start with the specified prefix.
     * 
     * Convenience method for removing groups of related regions.
     * Commonly used for cleaning up temporary or category-specific regions.
     * 
     * @param removeAtlasRegions If true, also removes matching regions from the final atlas
     * @param prefix The string prefix to match region names against
     * 
     * @example
     * ```haxe
     * // Remove all UI elements
     * packer.removeRegionsWithPrefix(true, "ui_");
     * 
     * // Remove temporary regions
     * packer.removeRegionsWithPrefix(true, "temp_");
     * ```
     */
    public function removeRegionsWithPrefix(removeAtlasRegions:Bool = true, prefix:String):Void {

        removeRegionsWithMatcher(removeAtlasRegions, regionName -> regionName.startsWith(prefix));

    }

    /**
     * Destroys the packer and all associated resources.
     * 
     * Cleans up:
     * - The generated atlas and all its textures
     * - Pending region data
     * - Internal packing structures
     */
    override function destroy() {

        if (atlas != null) {
            if (atlas.pages != null) {
                for (p in 0...atlas.pages.length) {
                    var page = atlas.pages[p];
                    var texture = page.texture;
                    if (texture != null) {
                        page.texture = null;
                        texture.destroy();
                    }
                }
            }

            atlas.destroy();
            atlas = null;
        }

        pendingRegions = null;
        pages = null;

        super.destroy();

    }

    /**
     * Add a region to this atlas packer from the given pixels.
     * Example usage:
     *
     * ```haxe
     * atlas.add(region1, pixels1);
     * atlas.add(region2, pixels2);
     * atlas.pack(() -> {
     *     // Done packing new regions
     * });
     * ```
     */
    public extern inline overload function add(
        name:String, pixels:UInt8Array,
        originalWidth:Int, originalHeight:Int,
        packedWidth:Int, packedHeight:Int = -1,
        offsetX:Int = 0, offsetY:Int = 0
    ):Void {
        _addRegionFromPixels(
            name, pixels,
            originalWidth, originalHeight,
            packedWidth, packedHeight,
            offsetX, offsetY
        );
    }

    private function _addRegionFromPixels(
        name:String, pixels:UInt8Array,
        originalWidth:Int, originalHeight:Int,
        packedWidth:Int, packedHeight:Int,
        offsetX:Int, offsetY:Int
    ):Void {

        if (packedHeight == -1) {
            packedHeight = Math.round(pixels.length / packedWidth);
        }

        pendingRegions.push({
            name: name,
            originalWidth: originalWidth,
            originalHeight: originalHeight,
            packedWidth: packedWidth,
            packedHeight: packedHeight,
            pixels: pixels,
            offsetX: offsetX,
            offsetY: offsetY
        });

    }

    /**
     * Add a region to this atlas packer that is a variant of
     * another existing region: it has the same packed size in pixels
     * but can have different offsets and original size.
     */
    public extern inline overload function add(
        variantName:String, sourceName:String,
        originalWidth:Int, originalHeight:Int,
        offsetX:Int = 0, offsetY:Int = 0
    ):Void {
        _addVariantRegion(
            variantName, sourceName,
            originalWidth, originalHeight,
            offsetX, offsetY
        );
    }

    private function _addVariantRegion(
        variantName:String, sourceName:String,
        originalWidth:Int, originalHeight:Int,
        offsetX:Int, offsetY:Int
    ):Void {

        var sourceRegion = this.region(sourceName);
        if (sourceRegion == null)
            throw 'Cannot add variant region: source region "$sourceName" not found!';

        pendingRegions.push({
            name: variantName,
            originalWidth: originalWidth,
            originalHeight: originalHeight,
            packedWidth: sourceRegion.packedWidth,
            packedHeight: sourceRegion.packedHeight,
            sourceRegion: sourceRegion,
            offsetX: offsetX,
            offsetY: offsetY
        });

    }

    /**
     * Packs all pending regions into texture atlas pages.
     * 
     * This method executes the bin packing algorithm to arrange all regions
     * added via add() into optimal texture layouts. It handles:
     * - Automatic page size growth when regions don't fit
     * - Creation of new pages when maximum size is exceeded
     * - Texture generation from pixel data
     * - Variant region resolution
     * 
     * The packing process:
     * 1. Attempts to fit regions into existing pages
     * 2. Grows page size (up to MAX_TEXTURE_SIZE) if needed
     * 3. Creates new pages when current pages are full
     * 4. Generates GPU textures from packed pixel data
     * 5. Creates TextureAtlasRegion instances for use
     * 
     * @param done Callback invoked when packing is complete, receives the atlas
     * 
     * @example
     * ```haxe
     * // Add multiple regions
     * packer.add("sprite1", pixels1, 32, 32, 32, 32);
     * packer.add("sprite2", pixels2, 64, 64, 64, 64);
     * 
     * // Pack and use atlas
     * packer.pack((atlas) -> {
     *     var region1 = atlas.region("sprite1");
     *     quad.region = region1;
     * });
     * ```
     * 
     * @throws String if region dimensions exceed MAX_TEXTURE_SIZE
     * @throws String if variant regions reference invalid sources
     */
    public function pack(done:(atlas:TextureAtlas)->Void) {

        var pageSize:Int = MIN_TEXTURE_SIZE;

        if (pages.length == 0) {
            pages.push({
                spacing: spacing,
                name: 'page' + pages.length,
                width: pageSize, height: pageSize,
                binPacker: new MaxRectsPacker(pageSize + spacing, pageSize + spacing, false),
                regions: [],
                shouldResetTexture: true
            });
        }

        var page = pages[pages.length - 1];
        pageSize = page.width;

        var variantRegions:Array<TextureAtlasPackerRegion> = [];

        while (pendingRegions.length > 0) {
            var region = pendingRegions.shift();
            if (region.pixels == null) {
                variantRegions.push(region);
                continue;
            }

            if (region.packedWidth > MAX_TEXTURE_SIZE || region.packedHeight > MAX_TEXTURE_SIZE) {
                throw "Cannot insert region " + region.name + " with used size: " + region.packedWidth + " x " + region.packedHeight;
            }

            // TODO try on previous pages if any

            var rect:binpacking.Rect = null;

            rect = page.binPacker.insert(
                region.packedWidth + page.spacing,
                region.packedHeight + page.spacing,
                FreeRectChoiceHeuristic.BestAreaFit
            );

            if (rect == null) {
                // Not enough space, if the page is lower than MAX_TEXTURE_SIZE,
                // Increase page size and try again
                if (pageSize < MAX_TEXTURE_SIZE) {
                    pageSize *= 2;
                    page.width = pageSize;
                    page.height = pageSize;
                    page.binPacker = new MaxRectsPacker(pageSize + page.spacing, pageSize + page.spacing, false);

                    for (i in 0...page.regions.length) {
                        page.regions[i].rect = null;
                        page.regions[i].rendered = false;
                    }
                    pendingRegions = [region].concat(page.regions.concat(pendingRegions));

                    page.regions = [];
                    page.shouldResetTexture = true;
                }
                else {
                    // Page size is maximum, then add a new page
                    pageSize = MIN_TEXTURE_SIZE;
                    pages.push({
                        spacing: spacing,
                        name: 'page' + pages.length,
                        width: pageSize, height: pageSize,
                        binPacker: new MaxRectsPacker(pageSize + spacing, pageSize + spacing, false),
                        regions: [],
                        shouldResetTexture: true
                    });

                    pendingRegions.unshift(region);
                }
            }
            else {
                // Rect is valid
                region.rect = rect;
                page.regions.push(region);
            }
        }

        // Handle variant regions
        for (r in 0...variantRegions.length) {
            var region = variantRegions[r];
            var sourceRegion = region.sourceRegion;
            while (sourceRegion != null && sourceRegion.sourceRegion != null) {
                sourceRegion = sourceRegion.sourceRegion;
            }
            if (sourceRegion != null) {
                var resolvedPage:TextureAtlasPackerPage = null;
                for (p in 0...pages.length) {
                    var page = pages[p];
                    for (pr in 0...page.regions.length) {
                        var pageRegion = page.regions[pr];
                        if (pageRegion.name == sourceRegion.name) {
                            resolvedPage = page;
                            break;
                        }
                    }
                    if (resolvedPage != null)
                        break;
                }
                if (resolvedPage != null) {
                    resolvedPage.regions.push(region);
                }
                else {
                    throw "Invalid variant region: " + region.name + " (source region not found in any page).";
                }
            }
            else {
                throw "Invalid variant region: " + region.name + " (source region not found).";
            }
        }

        if (atlas == null) {
            atlas = new TextureAtlas();
            atlas.onDestroy(this, _ -> destroy());
        }

        for (p in 0...pages.length) {
            var page = pages[p];
            if (page.regions.length > 0) {
                var atlasPage:TextureAtlasPage = null;
                if (atlas.pages.length > p) {
                    atlasPage = atlas.pages[p];
                }
                if (atlasPage == null) {
                    atlasPage = new TextureAtlasPage(
                        page.name,
                        page.width,
                        page.height,
                        filter
                    );
                    atlas.pages.push(atlasPage);
                }

                // Create pixels
                var pagePixels:UInt8Array = null;
                if (page.shouldResetTexture || atlasPage.texture == null) {
                    pagePixels = Pixels.create(page.width, page.height, AlphaColor.TRANSPARENT);
                    atlasPage.width = page.width;
                    atlasPage.height = page.height;
                }
                else {
                    pagePixels = atlasPage.texture.fetchPixels();
                }

                var renderedRegionsWithPixels = [];
                var renderedVariantRegions = [];
                for (r in 0...page.regions.length) {
                    var region = page.regions[r];
                    if (!region.rendered) {
                        if (region.pixels != null) {
                            Pixels.copy(
                                region.pixels, region.packedWidth,
                                pagePixels, page.width,
                                0, 0, region.packedWidth, region.packedHeight,
                                Std.int(region.rect.x),
                                Std.int(region.rect.y)
                            );
                            region.rendered = true;
                            renderedRegionsWithPixels.push(region);
                        }
                        else if (region.sourceRegion != null) {
                            // Variant region, no need to add pixels
                            region.rendered = true;
                            renderedVariantRegions.push(region);
                        }
                        else {
                            // TODO support regions based on existing texture/tile
                            throw 'Cannot render region ${region.name} because it doesn\'t have pixels';
                        }
                    }
                }

                if (renderedRegionsWithPixels.length > 0) {
                    if (atlasPage.texture != null) {
                        if (atlasPage.texture.nativeWidth == page.width && atlasPage.texture.nativeHeight == page.height) {
                            atlasPage.texture.submitPixels(pagePixels);
                        }
                        else {
                            atlasPage.texture.destroy();
                            atlasPage.texture = Texture.fromPixels(page.width, page.height, pagePixels, 1);
                        }
                    }
                    else {
                        atlasPage.texture = Texture.fromPixels(page.width, page.height, pagePixels, 1);
                    }

                    atlasPage.texture.filter = filter;

                    for (r in 0...renderedRegionsWithPixels.length) {
                        var region = renderedRegionsWithPixels[r];
                        var atlasRegion = atlas.region(region.name);
                        if (atlasRegion == null) {
                            atlasRegion = new TextureAtlasRegion(region.name, atlas, p);
                        }
                        atlasRegion.texture = atlasPage.texture;
                        atlasRegion.originalWidth = region.originalWidth;
                        atlasRegion.originalHeight = region.originalHeight;
                        atlasRegion.packedWidth = region.packedWidth;
                        atlasRegion.packedHeight = region.packedHeight;
                        atlasRegion.offsetX = region.offsetX;
                        atlasRegion.offsetY = region.offsetY;
                        atlasRegion.x = Math.round(region.rect.x + page.spacing);
                        atlasRegion.y = Math.round(region.rect.y + page.spacing);
                        atlasRegion.width = region.packedWidth;
                        atlasRegion.height = region.packedHeight;
                        atlasRegion.computeFrame();
                    }
                }

                if (renderedVariantRegions.length > 0) {

                    for (r in 0...renderedVariantRegions.length) {
                        var region = renderedVariantRegions[r];
                        var sourceRegion = region.sourceRegion;
                        while (sourceRegion != null && sourceRegion.sourceRegion != null) {
                            sourceRegion = sourceRegion.sourceRegion;
                        }
                        var sourceAtlasRegion = atlas.region(sourceRegion.name);
                        if (sourceAtlasRegion == null) {
                            throw "Invalid variant region: " + region.name + " (source atlas region not found).";
                        }
                        var atlasRegion = atlas.region(region.name);
                        if (atlasRegion == null) {
                            atlasRegion = new TextureAtlasRegion(region.name, atlas, p);
                        }
                        atlasRegion.texture = sourceAtlasRegion.texture;
                        atlasRegion.originalWidth = region.originalWidth;
                        atlasRegion.originalHeight = region.originalHeight;
                        atlasRegion.packedWidth = sourceRegion.packedWidth;
                        atlasRegion.packedHeight = sourceRegion.packedHeight;
                        atlasRegion.offsetX = region.offsetX;
                        atlasRegion.offsetY = region.offsetY;
                        atlasRegion.x = Math.round(sourceRegion.rect.x + page.spacing);
                        atlasRegion.y = Math.round(sourceRegion.rect.y + page.spacing);
                        atlasRegion.width = region.packedWidth;
                        atlasRegion.height = region.packedHeight;
                        atlasRegion.computeFrame();
                    }
                }
            }
        }

        emitFinishPack();
        done(atlas);

    }

}

/**
 * Internal data structure for regions during the packing process.
 * 
 * TextureAtlasPackerRegion holds temporary information about images
 * to be packed, including pixel data, dimensions, and packing results.
 * This is distinct from TextureAtlasRegion which represents the final
 * packed regions in the atlas.
 * 
 * Features:
 * - Support for trimmed sprites (packed vs original dimensions)
 * - Offset data for proper sprite alignment
 * - Variant regions that share texture data with a source
 * - Bin packing rectangle assignment
 * 
 * @see TextureAtlasRegion The final region type after packing
 */
@:structInit
@:allow(ceramic.TextureAtlasPacker)
@:allow(ceramic.TextureAtlasPackerPage)
private class TextureAtlasPackerRegion {

    /**
     * Unique identifier for this region.
     * Used to reference the region in the final atlas.
     */
    public var name:String;

    /**
     * Original sprite width including transparent margins.
     * This is the full size before any trimming optimization.
     */
    public var originalWidth:Int = 0;

    /**
     * Original sprite height including transparent margins.
     * This is the full size before any trimming optimization.
     */
    public var originalHeight:Int = 0;

    /**
     * Actual width of non-transparent pixels to be packed.
     * Usually smaller than originalWidth due to trimming.
     */
    public var packedWidth:Int;

    /**
     * Actual height of non-transparent pixels to be packed.
     * Usually smaller than originalHeight due to trimming.
     */
    public var packedHeight:Int;

    /**
     * Horizontal offset from original sprite origin to packed pixels.
     * Used to maintain proper sprite alignment after trimming.
     */
    public var offsetX:Int = 0;

    /**
     * Vertical offset from original sprite origin to packed pixels.
     * Used to maintain proper sprite alignment after trimming.
     */
    public var offsetY:Int = 0;

    /**
     * Raw pixel data for this region in RGBA format.
     * Null for variant regions that reference another region.
     */
    public var pixels:UInt8Array = null;

    /**
     * Reference to source region for variants.
     * Variant regions share the same texture coordinates as their source
     * but can have different original dimensions and offsets.
     */
    public var sourceRegion:TextureAtlasPackerRegion = null;

    /**
     * Assigned position in the texture page after bin packing.
     * Null until the region has been successfully packed.
     */
    public var rect:binpacking.Rect = null;

    /**
     * Tracks whether pixels have been copied to the page texture.
     * Prevents duplicate rendering during repacking operations.
     */
    public var rendered:Bool = false;

}

/**
 * Internal representation of a texture page during packing.
 * 
 * Each page manages its own bin packer instance and tracks
 * which regions have been assigned to it. Pages grow dynamically
 * and can be reset when repacking is needed.
 */
@:structInit
@:allow(ceramic.TextureAtlasPacker)
@:allow(ceramic.TextureAtlasPackerRegion)
private class TextureAtlasPackerPage {

    /**
     * Pixel spacing between regions on this page.
     * Matches the packer's spacing setting.
     */
    public var spacing:Int;

    /**
     * Identifier for this page (e.g., "page0", "page1").
     * Used for debugging and texture naming.
     */
    public var name:String;

    /**
     * Current width of this page in pixels.
     * Grows from MIN_TEXTURE_SIZE to MAX_TEXTURE_SIZE as needed.
     */
    public var width:Int;

    /**
     * Current height of this page in pixels.
     * Grows from MIN_TEXTURE_SIZE to MAX_TEXTURE_SIZE as needed.
     */
    public var height:Int;

    /**
     * All regions assigned to this page.
     * Includes both regular regions and variants.
     */
    public var regions:Array<TextureAtlasPackerRegion>;

    /**
     * Bin packing algorithm instance for this page.
     * Handles optimal placement of regions within the page bounds.
     */
    public var binPacker:MaxRectsPacker;

    /**
     * Flag indicating the page texture needs regeneration.
     * Set when page size changes or regions are modified.
     */
    public var shouldResetTexture:Bool;

}

package ceramic;

import binpacking.MaxRectsPacker;
import ceramic.UInt8Array;

using StringTools;

class TextureAtlasPacker extends Entity {

    static final MIN_TEXTURE_SIZE:Int = 32;

    static final MAX_TEXTURE_SIZE:Int = 2048;

    public var atlas(default, null):TextureAtlas = null;

    public var spacing:Int = 1;

    public var filter:TextureFilter = LINEAR;

    private var pendingRegions:Array<TextureAtlasPackerRegion> = [];

    private var pages:Array<TextureAtlasPackerPage> = [];

    public function new() {

        super();

    }

    public function hasPendingRegions():Bool {

        return pendingRegions != null && pendingRegions.length > 0;

    }

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

    public function removeRegionsWithMatcher(matcher:(region:TextureAtlasPackerRegion)->Bool):Void {

        if (pendingRegions != null) {
            var pendingToRemove:Array<TextureAtlasPackerRegion> = null;
            for (i in 0...pendingRegions.length) {
                var region = pendingRegions[i];
                if (matcher(region)) {
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
            for (p in 0...pages.length) {
                var pendingToRemove:Array<TextureAtlasPackerRegion> = null;
                var page = pages[p];
                for (i in 0...page.regions.length) {
                    var region = page.regions[i];
                    if (matcher(region)) {
                        if (pendingToRemove == null)
                            pendingToRemove = [];
                        pendingToRemove.push(region);
                    }
                }
                if (pendingToRemove != null) {
                    for (i in 0...pendingToRemove.length) {
                        var region = pendingToRemove[i];
                        page.regions.remove(region);
                        page.shouldResetTexture = true;

                        if (atlas != null) {
                            var atlasRegion = atlas.region(region.name);
                            if (atlasRegion != null) {
                                atlas.regions.remove(atlasRegion);
                            }
                        }
                    }
                    if (pendingRegions != null)
                        pendingRegions = [];
                    for (i in 0...page.regions.length) {
                        var region = page.regions[i];
                        pendingRegions.unshift(region);
                    }
                }
            }
        }

    }

    public function removeRegionsWithPrefix(prefix:String):Void {

        removeRegionsWithMatcher(region -> region.name.startsWith(prefix));

    }

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
     * Pack new regions added with `add()` to the texture atlas.
     * If no texture atlas exists yet, it will be created.
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
                    atlasPage = {
                        name: page.name,
                        width: page.width,
                        height: page.height,
                        filter: filter
                    };
                    atlas.pages.push(atlasPage);
                }

                // Create pixels
                var pagePixels:UInt8Array = null;
                if (page.shouldResetTexture || atlasPage.texture == null) {
                    pagePixels = Pixels.create(page.width, page.height, AlphaColor.TRANSPARENT);
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
                            atlas.regions.push(atlasRegion);
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
                        atlasRegion.width = region.originalWidth;
                        atlasRegion.height = region.originalHeight;
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
                            atlas.regions.push(atlasRegion);
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
                        atlasRegion.width = region.originalWidth;
                        atlasRegion.height = region.originalHeight;
                        atlasRegion.computeFrame();
                    }
                }
            }
        }

        done(atlas);

    }

}

/**
 * A region for a texture atlas packer. Not to be confused
 * with `TextureAtlasRegion` which is to be used with `TextureAtlas`,
 * while `TextureAtlasPackerRegion` is holding information to
 * pack a region with `TextureAtlasPacker` and is not a region
 * usable with an atlas yet.
 */
@:structInit
@:allow(ceramic.TextureAtlasPacker)
@:allow(ceramic.TextureAtlasPackerPage)
private class TextureAtlasPackerRegion {

    /**
     * Region name
     */
    public var name:String;

    /**
     * Original region width (including margins / transparent pixels)
     */
    public var originalWidth:Int = 0;

    /**
     * Original region height (including margins / transparent pixels)
     */
    public var originalHeight:Int = 0;

    /**
     * Packed region width (without margins / transparent pixels)
     */
    public var packedWidth:Int;

    /**
     * Packed region height (without margins / transparent pixels)
     */
    public var packedHeight:Int;

    /**
     * X offset to position the region to its original size
     */
    public var offsetX:Int = 0;

    /**
     * Y offset to position the region to its original size
     */
    public var offsetY:Int = 0;

    /**
     * If the region comes from a pixels buffer, this is the buffer
     */
    public var pixels:UInt8Array = null;

    /**
     * If the region is a variant of another region,
     * this is the other region used as source
     */
    public var sourceRegion:TextureAtlasPackerRegion = null;

    /**
     * The rect describing how this region should be packed
     */
    public var rect:binpacking.Rect = null;

    /**
     * Whether this region has been rendered to a page texture or not
     */
    public var rendered:Bool = false;

}

@:structInit
@:allow(ceramic.TextureAtlasPacker)
@:allow(ceramic.TextureAtlasPackerRegion)
private class TextureAtlasPackerPage {

    public var spacing:Int;

    public var name:String;

    public var width:Int;

    public var height:Int;

    public var regions:Array<TextureAtlasPackerRegion>;

    public var binPacker:MaxRectsPacker;

    public var shouldResetTexture:Bool;

}

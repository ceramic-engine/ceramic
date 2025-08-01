package ceramic;

import ceramic.Shortcuts.*;

/**
 * Dynamic texture tile allocator with automatic packing and reuse capabilities.
 * 
 * TextureTilePacker provides a grid-based allocation system for dynamically
 * creating and managing texture tiles within render textures. Unlike static
 * texture atlases, this packer allows runtime allocation and deallocation
 * of texture regions, making it ideal for:
 * - Dynamic text rendering
 * - Procedural graphics generation
 * - Temporary visual effects
 * - Runtime sprite composition
 * 
 * Features:
 * - Grid-based allocation with configurable padding
 * - Automatic texture chaining when space runs out
 * - Tile reuse after deallocation
 * - Visual stamping into allocated tiles
 * - Margin support to prevent bleeding
 * 
 * The packer divides textures into a grid of fixed-size cells (pads) and
 * allocates contiguous blocks for tiles that need more space.
 * 
 * @example
 * ```haxe
 * // Create a packer for dynamic text
 * var packer = new TextureTilePacker(
 *     true,    // Auto-render
 *     2048,    // Max width
 *     2048,    // Max height
 *     64, 64,  // Pad size
 *     2        // Margin
 * );
 * 
 * // Allocate a tile
 * var tile = packer.allocTile(128, 32);
 * 
 * // Render content into the tile
 * var text = new Text();
 * text.content = "Dynamic Text";
 * packer.stamp(tile, text, () -> {
 *     // Use the tile
 *     quad.tile = tile;
 * });
 * 
 * // Release when done
 * packer.releaseTile(tile);
 * ```
 * 
 * @see TextureTile The tiles allocated by this packer
 * @see RenderTexture The target texture for packing
 */
class TextureTilePacker extends Entity {

    /**
     * The render texture containing all allocated tiles.
     * 
     * This texture is rendered to when stamping visuals into tiles.
     * Size is determined by constructor parameters and screen density.
     */
    public var texture(default,null):RenderTexture;

    /**
     * Width of each grid cell in pixels.
     * 
     * Tiles smaller than this will still occupy a full cell.
     * Larger tiles will span multiple cells horizontally.
     */
    public var padWidth(default,null):Int;

    /**
     * Height of each grid cell in pixels.
     * 
     * Tiles smaller than this will still occupy a full cell.
     * Larger tiles will span multiple cells vertically.
     */
    public var padHeight(default,null):Int;

    /**
     * Margin around each tile in pixels.
     * 
     * Prevents texture bleeding between adjacent tiles.
     * Applied on all sides of allocated regions.
     */
    public var margin(default,null):Int;

    /**
     * Next packer in the chain for overflow handling.
     * 
     * When this packer runs out of space, tiles are allocated
     * from the next packer, creating a linked list of textures.
     */
    public var nextPacker:TextureTilePacker = null;

    /**
     * Grid storage for allocated tiles.
     * Indexed as [row * numCols + col].
     */
    var areas:Array<TextureTile>;

    /**
     * Number of columns in the allocation grid.
     */
    var numCols:Int = 0;

    /**
     * Number of rows in the allocation grid.
     */
    var numRows:Int = 0;

    /**
     * Maximum texture width constraint in pixels.
     */
    var maxPixelTextureWidth:Int = 0;

    /**
     * Maximum texture height constraint in pixels.
     */
    var maxPixelTextureHeight:Int = 0;

    /**
     * Creates a new texture tile packer.
     * 
     * @param autoRender Whether to automatically render changes to the texture
     * @param maxPixelTextureWidth Maximum texture width (-1 for auto based on density)
     * @param maxPixelTextureHeight Maximum texture height (-1 for auto based on density)
     * @param padWidth Width of each grid cell (default: 16)
     * @param padHeight Height of each grid cell (default: 16)
     * @param margin Pixel margin around tiles (default: 1)
     */
    public function new(autoRender:Bool, maxPixelTextureWidth:Int = -1, maxPixelTextureHeight:Int = -1, padWidth:Int = 16, padHeight:Int = 16, margin:Int = 1) {

        super();

        this.padWidth = padWidth;
        this.padHeight = padHeight;
        this.margin = margin;

        this.maxPixelTextureWidth = maxPixelTextureWidth;
        this.maxPixelTextureHeight = maxPixelTextureHeight;

        if (maxPixelTextureWidth == -1) {
            maxPixelTextureWidth = Std.int(2048 / screen.texturesDensity);
        }
        if (maxPixelTextureHeight == -1) {
            maxPixelTextureHeight = Std.int(2048 / screen.texturesDensity);
        }

        var textureWidth = Std.int(Math.min(maxPixelTextureWidth, 2048 / screen.texturesDensity));
        var textureHeight = Std.int(Math.min(maxPixelTextureHeight, 2048 / screen.texturesDensity));
        texture = new RenderTexture(textureWidth, textureHeight);

        if (autoRender) {
            texture.autoRender = true;
            texture.clearOnRender = true;
        }
        else {
            texture.autoRender = false;
            texture.clearOnRender = false;
        }

        areas = [];
        var texWidth = texture.width;
        var texHeight = texture.height;

        var x = margin;
        var y = margin;
        while (y + padHeight < texHeight) {
            while (x + padWidth < texWidth) {
                areas.push(null);
                x += padWidth + margin * 2;
                if (numRows == 0) numCols++;
            }
            x = 0;
            y += padHeight + margin * 2;
            numRows++;

        }

    }

    override function destroy() {

        super.destroy();

        if (nextPacker != null) {
            nextPacker.destroy();
            nextPacker = null;
        }

        texture.destroy();
        texture = null;

        areas = null;

    }

    inline function getTileAtPosition(col:Int, row:Int):TextureTile {

        return areas[row * numCols + col];

    }

    inline function setTileAtPosition(col:Int, row:Int, tile:TextureTile):Void {

        areas[row * numCols + col] = tile;

    }

/// Public API

    /**
     * Allocates a new tile of the specified size.
     * 
     * Searches for available space in the grid that can accommodate
     * the requested dimensions. If the tile is larger than a single
     * pad, multiple adjacent pads are allocated. When no space is
     * available, automatically creates a chained packer.
     * 
     * @param width Required tile width in pixels
     * @param height Required tile height in pixels
     * @return The allocated TextureTile, or null if dimensions exceed maximum
     * 
     * @example
     * ```haxe
     * // Allocate a 100x50 tile
     * var tile = packer.allocTile(100, 50);
     * if (tile != null) {
     *     // Tile successfully allocated
     *     myQuad.tile = tile;
     * }
     * ```
     */
    public function allocTile(width:Int, height:Int):TextureTile {

        var texWidth = texture.width;
        var texHeight = texture.height;

        var padWidthWithMargin = padWidth + margin * 2;
        var padHeightWithMargin = padHeight + margin * 2;

        var maxWidth = padWidthWithMargin * numCols - margin * 2;
        var maxHeight = padHeightWithMargin * numRows - margin * 2;

        if (width > maxWidth || height > maxHeight) {
            log.warning('Cannot alloc tile of $width x $height because this is bigger than $maxWidth x $maxHeight');
            return null;
        }

        // TODO proper texture filling

        var widthInCols = padWidth;
        var requiredCols = 1;
        while (widthInCols < width) {
            requiredCols++;
            widthInCols += padWidth + margin * 2; // Margin between areas of a same tile can be used
        }

        var heightInRows = padHeight;
        var requiredRows = 1;
        while (heightInRows < height) {
            requiredRows++;
            heightInRows += padHeight + margin * 2; // Margin between areas of a same tile can be used
        }

        // Find an area available
        for (row in 0...(numRows - requiredRows + 1)) {
            for (col in 0...(numCols - requiredCols + 1)) {

                var areaAvailable = true;
                for (r in row...row+requiredRows) {
                    for (c in col...col+requiredCols) {
                        if (getTileAtPosition(c, r) != null) {
                            areaAvailable = false;
                            break;
                        }
                    }
                    if (!areaAvailable) break;
                }

                if (areaAvailable) {

                    // Yay! found an available area, alloc tile!

                    var tile = new PackedTextureTile(
                        texture,
                        col * padWidthWithMargin,
                        row * padHeightWithMargin,
                        width,
                        height
                    );

                    tile.col = col;
                    tile.row = row;
                    tile.usedCols = requiredCols;
                    tile.usedRows = requiredRows;

                    // Mark every used area as used by this tile
                    for (r in row...row+requiredRows) {
                        for (c in col...col+requiredCols) {
                            setTileAtPosition(c, r, tile);
                        }
                    }

                    return tile;
                }

            }
        }

        // No space available, use another packer (with another texture)
        if (nextPacker == null) {
            nextPacker = new TextureTilePacker(texture.autoRender, maxPixelTextureWidth, maxPixelTextureHeight, padWidth, padHeight, margin);
        }
        return nextPacker.allocTile(width, height);

    }

    /**
     * Releases a previously allocated tile for reuse.
     * 
     * Marks the tile's grid cells as available for future allocations.
     * The release is deferred by two frames to ensure any pending
     * rendering operations complete first.
     * 
     * @param tile The tile to release (must be from this packer)
     * @throws String if tile is not a PackedTextureTile
     * 
     * @example
     * ```haxe
     * // Release a tile when no longer needed
     * packer.releaseTile(myTile);
     * myTile = null; // Clear reference
     * ```
     */
    public function releaseTile(tile:TextureTile):Void {

        log.info('release tile $tile');

        if (!(Std.isOfType(tile, PackedTextureTile))) {
            throw 'Cannot release tile: $tile.';
        }

        var packedTile:PackedTextureTile = cast tile;

        // Find related packer (could be a chained packer)
        var packer = this;
        while (packer != null && packer.texture != packedTile.texture) {
            packer = packer.nextPacker;
        }

        if (packer == null) {
            log.warning('Failed to release tile: ' + packedTile + ' (it doesn\'t belong to this packer)');
            return;
        }

        app.onceUpdate(this, function(_) {
            app.onceUpdate(this, function(_) {
                var didRelease = false;

                // Free up packer areas
                for (r in packedTile.row...packedTile.row+packedTile.usedRows) {
                    for (c in packedTile.col...packedTile.col+packedTile.usedCols) {
                        if (packer.getTileAtPosition(c, r) == packedTile) {
                            didRelease = true;
                            packer.setTileAtPosition(c, r, null);
                        }
                    }
                }

                packedTile.texture = null;

                if (!didRelease) {
                    log.warning('Failed to release tile: ' + packedTile + ' (did not find it)');
                }
            });
        });

    }

    /**
     * Renders a visual into an allocated tile.
     * 
     * Stamps the visual's content into the tile's region of the render
     * texture. The visual is temporarily reparented and transformed to
     * fit within the tile bounds, including margins.
     * 
     * @param tile The target tile to render into
     * @param visual The visual content to render
     * @param done Callback invoked when rendering completes
     * 
     * @example
     * ```haxe
     * // Render text into a tile
     * var tile = packer.allocTile(200, 50);
     * var text = new Text();
     * text.content = "Hello World";
     * 
     * packer.stamp(tile, text, () -> {
     *     // Text is now rendered in the tile
     *     sprite.tile = tile;
     * });
     * ```
     */
    public function stamp(tile:TextureTile, visual:Visual, done:Void->Void):Void {

        var stampVisual = new Quad();
        stampVisual.anchor(0, 0);
        stampVisual.size(tile.frameWidth + margin * 2, tile.frameHeight + margin * 2);
        stampVisual.pos(tile.frameX - margin, tile.frameY - margin);
        stampVisual.blending = Blending.SET;
        stampVisual.inheritAlpha = false;
        stampVisual.alpha = 0;
        stampVisual.color = Color.WHITE;

        var prevTransform = visual.transform;

        var prevParent = visual.parent;
        if (prevParent != null) {
            prevParent.remove(visual);
        }
        stampVisual.add(visual);
        visual.transform = new Transform();
        visual.transform.translate(margin, margin);

        var dynTexture:RenderTexture = cast tile.texture;

        dynTexture.stamp(stampVisual, function() {

            stampVisual.remove(visual);
            if (prevParent != null) {
                prevParent.add(visual);
            }
            stampVisual.destroy();
            stampVisual = null;

            visual.transform = prevTransform;
            visual = null;

            done();
            done = null;

        });

    }

    /**
     * Checks if a texture is managed by this packer or its chain.
     * 
     * Recursively searches through this packer and any chained
     * packers to determine if the given texture belongs to the
     * allocation system.
     * 
     * @param texture The texture to check
     * @return True if this packer chain manages the texture
     */
    public function managesTexture(texture:Texture):Bool {

        return this.texture == texture || (nextPacker != null && nextPacker.managesTexture(texture));

    }

}

/**
 * Internal texture tile implementation with grid allocation metadata.
 * 
 * PackedTextureTile extends TextureTile with additional information
 * about its position and size within the packer's grid system. This
 * allows the packer to track which grid cells are occupied and
 * properly release them when the tile is no longer needed.
 * 
 * @see TextureTilePacker The main packer that manages these tiles
 */
@:allow(ceramic.TextureTilePacker)
private class PackedTextureTile extends TextureTile {

    /**
     * The starting column index in the packer's grid.
     * 
     * Zero-based index indicating the leftmost column
     * occupied by this tile. Set to -1 before allocation.
     */
    public var col:Int = -1;

    /**
     * The starting row index in the packer's grid.
     * 
     * Zero-based index indicating the topmost row
     * occupied by this tile. Set to -1 before allocation.
     */
    public var row:Int = -1;

    /**
     * Number of grid columns occupied by this tile.
     * 
     * Tiles larger than padWidth span multiple columns.
     * Always at least 1 for allocated tiles.
     */
    public var usedCols:Int = 1;

    /**
     * Number of grid rows occupied by this tile.
     * 
     * Tiles larger than padHeight span multiple rows.
     * Always at least 1 for allocated tiles.
     */
    public var usedRows:Int = 1;

    /**
     * Creates a new packed texture tile.
     * 
     * @param texture The render texture containing this tile
     * @param frameX X position in the texture
     * @param frameY Y position in the texture
     * @param frameWidth Width of the tile
     * @param frameHeight Height of the tile
     */
    public function new(texture:Texture, frameX:Float, frameY:Float, frameWidth:Float, frameHeight:Float) {

        super(texture, frameX, frameY, frameWidth, frameHeight);

    }

}

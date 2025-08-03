package ceramic;

using ceramic.Extensions;

/**
 * Component that automatically processes tilemap tiles to apply auto-tiling rules.
 * Auto-tiling analyzes neighboring tiles and replaces them with appropriate variants
 * to create seamless connections and transitions.
 * 
 * The AutoTiler supports multiple auto-tiling algorithms (EDGE_16, EDGE_CORNER_32,
 * EXPANDED_47, etc.) and can handle complex tile arrangements including:
 * - Edge connections (straight borders)
 * - Corner pieces (diagonal connections)
 * - Overlapping tiles for detailed transitions
 * - Custom tile mappings for different tileset standards
 * 
 * ## Usage Example:
 * ```haxe
 * // Define auto-tiles for grass terrain
 * var grassAutoTile = {
 *     kind: EXPANDED_47,
 *     gid: 10,  // Base grass tile GID
 *     bounds: true  // Connect with map edges
 * };
 * 
 * // Create auto-tiler
 * var autoTiler = new AutoTiler([grassAutoTile]);
 * 
 * // Add to tilemap layer
 * tilemapLayer.component(autoTiler);
 * ```
 * 
 * The component automatically updates when the layer's tiles change,
 * recomputing auto-tiling for affected areas.
 * 
 * @see AutoTile For auto-tile configuration
 * @see AutoTileKind For supported algorithms
 * @see TilemapLayerData For the tilemap data structure
 */
class AutoTiler extends Entity implements Component {

    /**
     * The tilemap layer data this auto-tiler processes.
     * Automatically bound when added as a component to a TilemapLayerData entity.
     */
    @entity var layerData:TilemapLayerData;

    /**
     * Event fired when a single tile is computed during auto-tiling.
     * Useful for custom post-processing or debugging tile placement.
     * 
     * @param autoTiler This AutoTiler instance
     * @param autoTile The auto-tile rule that was applied
     * @param computedTiles The array of computed tiles being built
     * @param index The index of the tile that was just computed
     */
    @event function computeTile(autoTiler:AutoTiler, autoTile:AutoTile, computedTiles:Array<TilemapTile>, index:Int);

    /**
     * Event fired after all tiles have been computed but before they are
     * applied to the layer. Allows for final adjustments to the tile array.
     * 
     * @param autoTiler This AutoTiler instance
     * @param computedTiles The complete array of computed tiles
     */
    @event function computeTiles(autoTiler:AutoTiler, computedTiles:Array<TilemapTile>);

    /**
     * Read-only array of auto-tile configurations.
     * Each auto-tile defines a GID and algorithm for processing tiles.
     */
    public var autoTiles(default, null):ReadOnlyArray<AutoTile>;

    /**
     * Internal map for fast lookup of auto-tiles by their GID.
     * Built during construction from the autoTiles array.
     */
    var gidMap:IntMap<AutoTile>;

    /**
     * Creates a new AutoTiler with the specified auto-tile configurations.
     * 
     * @param autoTiles Array of auto-tile rules to apply
     * @param handleComputeTile Optional callback for each computed tile
     * @param handleComputeTiles Optional callback after all tiles are computed
     */
    public function new(autoTiles:Array<AutoTile>, ?handleComputeTile:(autoTiler:AutoTiler, autoTile:AutoTile, computedTiles:Array<TilemapTile>, index:Int)->Void, ?handleComputeTiles:(autoTiler:AutoTiler, computedTiles:Array<TilemapTile>)->Void) {

        super();

        this.autoTiles = [].concat(autoTiles);

        this.gidMap = new IntMap<AutoTile>();
        for (i in 0...autoTiles.length) {
            var autoTile = autoTiles.unsafeGet(i);
            autoTile.computeValues();
            this.gidMap.set(autoTile.gid, autoTile);
        }

        if (handleComputeTile != null) {
            onComputeTile(this, handleComputeTile);
        }

        if (handleComputeTiles != null) {
            onComputeTiles(this, handleComputeTiles);
        }

    }

    /**
     * Called when this auto-tiler is bound as a component to a TilemapLayerData.
     * Sets up event listeners and performs initial auto-tiling computation.
     */
    function bindAsComponent() {

        layerData.onTilesChange(this, handleTilesChange);
        computeAutoTiles(layerData.tiles);

    }

    /**
     * Handles changes to the layer's tile data.
     * Automatically recomputes auto-tiling when tiles are modified.
     * 
     * @param tiles The new tile array
     * @param prevTiles The previous tile array (before the change)
     */
    function handleTilesChange(tiles:ReadOnlyArray<TilemapTile>, prevTiles:ReadOnlyArray<TilemapTile>):Void {

        computeAutoTiles(tiles);

    }

    /**
     * Core auto-tiling computation method. Analyzes each tile in the layer
     * and applies appropriate auto-tiling transformations based on neighboring tiles.
     * 
     * The algorithm:
     * 1. Iterates through each tile position
     * 2. Checks if the tile matches any auto-tile rule
     * 3. Examines neighboring tiles (4 cardinal + 4 diagonal)
     * 4. Computes edge and corner masks based on matches
     * 5. Selects appropriate tile variant from the tileset
     * 6. Handles overlapping tiles for detailed transitions
     * 
     * @param tiles The source tile array to process
     */
    function computeAutoTiles(tiles:ReadOnlyArray<TilemapTile>):Void {

        var computedTiles:Array<TilemapTile> = [];
        if (layerData.computedTiles != null) {
            computedTiles = computedTiles.concat(layerData.computedTiles.original);
        }
        computedTiles.setArrayLength(tiles.length);

        var edgeCorner32Map:ReadOnlyArray<Int> = null;
        var expandedBottomCorner26Map:ReadOnlyArray<Int> = null;
        var tilesetterBlob47Map:ReadOnlyArray<Int> = null;

        var listensComputeTileEvent = this.listensComputeTile();

        var row = 0;
        var col = 0;
        var columns = layerData.columns;
        var rows = layerData.rows;
        var numTiles = columns * rows;
        var hasExtraTiles = false;
        var extraI = numTiles;
        if (tiles.length >= numTiles * 2) {
            hasExtraTiles = true;
        }
        for (i in 0...numTiles) {
            var tile = tiles.unsafeGet(i);
            var extraTile = hasExtraTiles ? tiles.unsafeGet(extraI) : 0;
            var gid = tile.gid;
            var autoTile = gidMap.get(gid);
            if (autoTile != null) {
                // Matching autotile rule
                var kind = autoTile.kind;
                var boundsSameTile = autoTile.bounds;
                switch kind {
                    case EDGE_16 | EDGE_CORNER_32 | EXPANDED_47 | EXPANDED_BOTTOM_CORNER_26 | TILESETTER_BLOB_47:

                        // Create mask from surrounding tiles
                        // bits: 0 = any other tile / 1 = same tile
                        var edgeMask:Flags = 0;
                        var cornerMask:Flags = 15;
                        var otherTile:TilemapTile = 0;
                        var otherExtraTile:TilemapTile = 0;
                        var n:Int = 0;

                        if (col > 0) {
                            // Left
                            n = i - 1;
                            otherTile = tiles.unsafeGet(n);
                            n += numTiles;
                            otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                            if (otherTile.gid == gid && otherExtraTile.gid == extraTile.gid)
                                edgeMask.setBool(0, true);
                        }
                        else if (boundsSameTile) {
                            edgeMask.setBool(0, true);
                        }
                        if (row > 0) {
                            // Top
                            n = i - columns;
                            otherTile = tiles.unsafeGet(n);
                            n += numTiles;
                            otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                            if (otherTile.gid == gid && otherExtraTile.gid == extraTile.gid)
                                edgeMask.setBool(1, true);
                        }
                        else if (boundsSameTile) {
                            edgeMask.setBool(1, true);
                        }
                        if (col < columns - 1) {
                            // Right
                            n = i  +1;
                            otherTile = tiles.unsafeGet(n);
                            n += numTiles;
                            otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                            if (otherTile.gid == gid && otherExtraTile.gid == extraTile.gid)
                                edgeMask.setBool(2, true);
                        }
                        else if (boundsSameTile) {
                            edgeMask.setBool(2, true);
                        }
                        if (row < rows - 1) {
                            // Bottom
                            n = i + columns;
                            otherTile = tiles.unsafeGet(n);
                            n += numTiles;
                            otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                            if (otherTile.gid == gid && otherExtraTile.gid == extraTile.gid)
                                edgeMask.setBool(3, true);
                        }
                        else if (boundsSameTile) {
                            edgeMask.setBool(3, true);
                        }

                        // Corners
                        if (kind != EDGE_16) {
                            if (edgeMask.bool(0)) {
                                if (edgeMask.bool(1)) {
                                    if (col > 0 && row > 0) {
                                        // Top-left corner
                                        n = i - columns - 1;
                                        otherTile = tiles.unsafeGet(n);
                                        n += numTiles;
                                        otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                                        if (otherTile.gid != gid || otherExtraTile.gid != extraTile.gid) {
                                            cornerMask.setBool(0, false);
                                        }
                                    }
                                }
                                if (edgeMask.bool(3)) {
                                    if (col > 0 && row < rows - 1) {
                                        // Bottom-left corner
                                        n = i + columns - 1;
                                        otherTile = tiles.unsafeGet(n);
                                        n += numTiles;
                                        otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                                        if (otherTile.gid != gid || otherExtraTile.gid != extraTile.gid) {
                                            cornerMask.setBool(3, false);
                                        }
                                    }
                                }
                            }
                            if (edgeMask.bool(2)) {
                                if (edgeMask.bool(1)) {
                                    if (col < columns - 1 && row > 0) {
                                        // Top-right corner
                                        n = i - columns + 1;
                                        otherTile = tiles.unsafeGet(n);
                                        n += numTiles;
                                        otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                                        if (otherTile.gid != gid || otherExtraTile.gid != extraTile.gid) {
                                            cornerMask.setBool(1, false);
                                        }
                                    }
                                }
                                if (edgeMask.bool(3)) {
                                    if (col < columns - 1 && row < rows - 1) {
                                        // Bottom-right corner
                                        n = i + columns + 1;
                                        otherTile = tiles.unsafeGet(n);
                                        n += numTiles;
                                        otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                                        if (otherTile.gid != gid || otherExtraTile.gid != extraTile.gid) {
                                            cornerMask.setBool(2, false);
                                        }
                                    }
                                }
                            }
                        }

                        if (kind == EDGE_CORNER_32) {

                            // Update tile gid
                            tile.gid = gid + edgeMask;

                            // Add extra tile on top if needed to display corners
                            if (cornerMask != 15) {
                                var cornerTile = tile;
                                cornerTile.gid = gid + 16 + cornerMask;
                                computedTiles[i + numTiles] = cornerTile;
                                if (listensComputeTileEvent)
                                    emitComputeTile(this, autoTile, computedTiles, i + numTiles);
                            }

                            // Add extra tile on top if it already existed
                            // but offset it with gid
                            if (extraTile != 0) {
                                computedTiles[i + numTiles * 2] = extraTile;
                                if (listensComputeTileEvent)
                                    emitComputeTile(this, autoTile, computedTiles, i + numTiles * 2);
                            }
                        }
                        else {

                            // Some corner specifics
                            if (cornerMask == 15) {
                                if (edgeMask != 15 || kind == EDGE_16) {
                                    cornerMask = 0;
                                }
                            }

                            // Compute full mask
                            var fullMask:Flags = 0;
                            fullMask.setBool(0, edgeMask.bool(0));
                            fullMask.setBool(1, edgeMask.bool(1));
                            fullMask.setBool(2, edgeMask.bool(2));
                            fullMask.setBool(3, edgeMask.bool(3));
                            fullMask.setBool(4, cornerMask.bool(0));
                            fullMask.setBool(5, cornerMask.bool(1));
                            fullMask.setBool(6, cornerMask.bool(2));
                            fullMask.setBool(7, cornerMask.bool(3));

                            // Retrieve index from mapping
                            var finalIndex:Int = fullMask;

                            if (finalIndex == -1) {
                                tile.gid = 0;
                            }
                            else {
                                if (edgeCorner32Map == null)
                                    edgeCorner32Map = AutoTiler.edgeCorner32Map;
                                finalIndex = edgeCorner32Map[finalIndex];

                                switch kind {

                                    case EDGE_16:
                                        tile.gid = gid + finalIndex;

                                    case EDGE_CORNER_32:
                                        tile.gid = gid + finalIndex;

                                    case EXPANDED_47:
                                        tile.gid = gid + finalIndex;

                                    case EXPANDED_BOTTOM_CORNER_26:
                                        if (expandedBottomCorner26Map == null)
                                            expandedBottomCorner26Map = AutoTiler.expandedBottomCorner26Map;
                                        finalIndex = expandedBottomCorner26Map[finalIndex];

                                        tile.gid = gid + finalIndex;

                                    case TILESETTER_BLOB_47:
                                        if (tilesetterBlob47Map == null)
                                            tilesetterBlob47Map = AutoTiler.tilesetterBlob47Map;

                                        var tileset = autoTile.tileset;
                                        if (tileset != null) {
                                            var x = autoTile.column;
                                            var y = autoTile.row;
                                            x += tilesetterBlob47Map[finalIndex * 2];
                                            y += tilesetterBlob47Map[finalIndex * 2 + 1];
                                            finalIndex = tileset.gidAtPosition(x, y);

                                            tile.gid = finalIndex;
                                        }
                                        else {
                                            throw "The 'tileset' option is required when using TILESETTER_BLOB_47 auto tile kind!";
                                        }
                                }
                            }

                            // Add extra tile on top if it already existed
                            // but offset it with gid
                            if (extraTile != 0) {
                                computedTiles[i + numTiles] = extraTile;
                                if (listensComputeTileEvent)
                                    emitComputeTile(this, autoTile, computedTiles, i + numTiles);
                            }
                        }
                }
            }

            // Assign computed tile
            computedTiles.unsafeSet(i, tile);
            if (listensComputeTileEvent && autoTile != null)
                emitComputeTile(this, autoTile, computedTiles, i);

            // Update row and columns
            col++;
            if (col == columns) {
                col = 0;
                row++;
            }

            // Increment extra i
            extraI++;
        }

        // Emit event before updating computed tiles
        emitComputeTiles(this, computedTiles);

        // Update computed tiles
        layerData.computedTiles = computedTiles;

    }

    /**
     * Static lookup table mapping 8-bit masks to tile indices for EDGE_CORNER_32 auto-tiling.
     * The mask encodes which edges and corners connect to matching tiles.
     * Built lazily on first access.
     */
    public static var edgeCorner32Map(get,null):ReadOnlyArray<Int> = null;
    /**
     * Builds the edge-corner mapping table for 32-tile auto-tiling.
     * Maps each possible combination of edge and corner connections to a tile index.
     * 
     * @return Read-only array where index is the 8-bit mask and value is tile offset
     */
    static function get_edgeCorner32Map():ReadOnlyArray<Int> {
        if (edgeCorner32Map == null) {
            var map:Array<Int> = [];
            var validIndex = 0;

            for (i in 0...16) {
                for (j in 0...16) {
                    var edges:Flags = j;
                    var corners:Flags = i;
                    var result:Flags = 0;

                    result.setBool(0, edges.bool(0));
                    result.setBool(1, edges.bool(1));
                    result.setBool(2, edges.bool(2));
                    result.setBool(3, edges.bool(3));
                    result.setBool(4, corners.bool(0));
                    result.setBool(5, corners.bool(1));
                    result.setBool(6, corners.bool(2));
                    result.setBool(7, corners.bool(3));

                    var fullIndex:Int = result;

                    if (isValidEdgeCorner32Combination(result)) {
                        map[fullIndex] = validIndex;
                        validIndex++;
                    }
                    else {
                        map[fullIndex] = -1;
                    }

                }
            }

            edgeCorner32Map = map;
        }
        return edgeCorner32Map;
    }

    /**
     * Static lookup table for EXPANDED_BOTTOM_CORNER_26 auto-tiling.
     * Maps 47-tile indices to their 26-tile equivalents, removing top corners.
     * Built lazily on first access.
     */
    public static var expandedBottomCorner26Map(get,null):ReadOnlyArray<Int> = null;
    /**
     * Builds the mapping table for 26-tile bottom-corner-only auto-tiling.
     * Reduces the 47-tile set by mapping tiles with top corners to simpler variants.
     * 
     * @return Read-only array mapping 47-tile indices to 26-tile indices
     */
    static function get_expandedBottomCorner26Map():ReadOnlyArray<Int> {
        if (expandedBottomCorner26Map == null) {
            var map:Array<Int> = [];

            for (i in 0...16) {
                map[i] = i;
            }

            map[16] = 15;
            map[17] = 15;
            map[18] = 16;
            map[19] = 15;
            map[20] = 17;
            map[21] = 17;
            map[22] = 18;
            map[23] = 17;
            map[24] = 19;
            map[25] = 18;
            map[26] = 20;
            map[27] = 17;
            map[28] = 21;
            map[29] = 22;
            map[30] = 21;
            map[31] = 21;
            map[32] = 23;
            map[33] = 24;
            map[34] = 22;
            map[35] = 21;
            map[36] = 7;
            map[37] = 25;
            map[38] = 6;
            map[39] = 7;
            map[40] = 14;
            map[41] = 25;
            map[42] = 3;
            map[43] = 7;
            map[44] = 11;
            map[45] = 25;
            map[46] = 25;

            expandedBottomCorner26Map = map;
        }
        return expandedBottomCorner26Map;
    }

    /**
     * Static lookup table for TILESETTER_BLOB_47 tile positions.
     * Maps tile indices to X,Y offsets in the Tilesetter blob layout.
     * Built lazily on first access.
     */
    public static var tilesetterBlob47Map(get,null):ReadOnlyArray<Int> = null;
    /**
     * Builds the position mapping for Tilesetter's 47-tile blob layout.
     * Each tile index maps to X,Y offsets from the base tile position.
     * 
     * The array stores pairs of values: [x0,y0, x1,y1, x2,y2, ...]
     * where index i maps to offset (map[i*2], map[i*2+1]).
     * 
     * @return Read-only array of X,Y offset pairs
     */
    static function get_tilesetterBlob47Map():ReadOnlyArray<Int> {
        if (tilesetterBlob47Map == null) {
            var map:Array<Int> = [];

            var i = 0;
            map[i*2] = 2;
            map[i*2+1] = 2;

            i = 1;
            map[i*2] = 1;
            map[i*2+1] = 2;

            i = 2;
            map[i*2] = 2;
            map[i*2+1] = 1;

            i = 3;
            map[i*2] = 1;
            map[i*2+1] = 1;

            i = 4;
            map[i*2] = -1;
            map[i*2+1] = 2;

            i = 5;
            map[i*2] = 0;
            map[i*2+1] = 2;

            i = 6;
            map[i*2] = -1;
            map[i*2+1] = 1;

            i = 7;
            map[i*2] = 0;
            map[i*2+1] = 1;

            i = 8;
            map[i*2] = 2;
            map[i*2+1] = -1;

            i = 9;
            map[i*2] = 1;
            map[i*2+1] = -1;

            i = 10;
            map[i*2] = 2;
            map[i*2+1] = 0;

            i = 11;
            map[i*2] = 1;
            map[i*2+1] = 0;

            i = 12;
            map[i*2] = -1;
            map[i*2+1] = -1;

            i = 13;
            map[i*2] = 0;
            map[i*2+1] = -1;

            i = 14;
            map[i*2] = -1;
            map[i*2+1] = 0;

            i = 15;
            map[i*2] = 7;
            map[i*2+1] = 3;

            i = 16;
            map[i*2] = 9;
            map[i*2+1] = 2;

            i = 17;
            map[i*2] = 8;
            map[i*2+1] = 2;

            i = 18;
            map[i*2] = 7;
            map[i*2+1] = -1;

            i = 19;
            map[i*2] = 7;
            map[i*2+1] = 0;

            i = 20;
            map[i*2] = 8;
            map[i*2+1] = 1;

            i = 21;
            map[i*2] = 8;
            map[i*2+1] = -1;

            i = 22;
            map[i*2] = 6;
            map[i*2+1] = 3;

            i = 23;
            map[i*2] = 5;
            map[i*2+1] = 3;

            i = 24;
            map[i*2] = 6;
            map[i*2+1] = -1;

            i = 25;
            map[i*2] = 6;
            map[i*2+1] = 0;

            i = 26;
            map[i*2] = 5;
            map[i*2+1] = -1;

            i = 27;
            map[i*2] = 5;
            map[i*2+1] = 0;

            i = 28;
            map[i*2] = 9;
            map[i*2+1] = 1;

            i = 29;
            map[i*2] = 3;
            map[i*2+1] = 3;

            i = 30;
            map[i*2] = 4;
            map[i*2+1] = 3;

            i = 31;
            map[i*2] = 8;
            map[i*2+1] = 0;

            i = 32;
            map[i*2] = 3;
            map[i*2+1] = -1;

            i = 33;
            map[i*2] = 4;
            map[i*2+1] = -1;

            i = 34;
            map[i*2] = 3;
            map[i*2+1] = 0;

            i = 35;
            map[i*2] = 4;
            map[i*2+1] = 0;

            i = 36;
            map[i*2] = 7;
            map[i*2+1] = 2;

            i = 37;
            map[i*2] = 7;
            map[i*2+1] = 1;

            i = 38;
            map[i*2] = 3;
            map[i*2+1] = 2;

            i = 39;
            map[i*2] = 4;
            map[i*2+1] = 2;

            i = 40;
            map[i*2] = 3;
            map[i*2+1] = 1;

            i = 41;
            map[i*2] = 4;
            map[i*2+1] = 1;

            i = 42;
            map[i*2] = 6;
            map[i*2+1] = 2;

            i = 43;
            map[i*2] = 5;
            map[i*2+1] = 2;

            i = 44;
            map[i*2] = 6;
            map[i*2+1] = 1;

            i = 45;
            map[i*2] = 5;
            map[i*2+1] = 1;

            i = 46;
            map[i*2] = 0;
            map[i*2+1] = 0;

            tilesetterBlob47Map = map;
        }
        return tilesetterBlob47Map;
    }

    /**
     * Inverted lookup table for EDGE_CORNER_32 mapping.
     * Maps tile indices back to their 8-bit mask values.
     * Built lazily on first access.
     */
    public static var edgeCorner32InvertedMap(get,null):ReadOnlyArray<Int> = null;
    /**
     * Builds the inverted edge-corner mapping table.
     * Useful for analyzing which connections a specific tile index represents.
     * 
     * @return Read-only array where index is tile offset and value is 8-bit mask
     */
    static function get_edgeCorner32InvertedMap():ReadOnlyArray<Int> {
        if (edgeCorner32InvertedMap == null) {
            var edgeCorner32Map = AutoTiler.edgeCorner32Map;
            var map:Array<Int> = [];
            for (i in 0...edgeCorner32Map.length) {
                var val = edgeCorner32Map.unsafeGet(i);
                if (val != -1) {
                    map[val] = i;
                }
            }
            edgeCorner32InvertedMap = map;
        }
        return edgeCorner32InvertedMap;
    }

    /**
     * Validates whether a given edge/corner combination is valid for EDGE_CORNER_32 tiling.
     * 
     * Rules enforced:
     * - If all corners are present, all edges must also be present
     * - A corner can only exist if both adjacent edges are present
     *   (e.g., top-left corner requires both left and top edges)
     * 
     * This validation ensures visually correct tile connections without
     * impossible configurations like floating corners.
     * 
     * @param value 8-bit value encoding edges (bits 0-3) and corners (bits 4-7)
     * @return true if the combination is valid, false otherwise
     */
    public static function isValidEdgeCorner32Combination(value:Int):Bool {

        var flags:Flags = value;

        var corners:Flags = 0;
        corners.setBool(0, flags.bool(4));  // Top-left
        corners.setBool(1, flags.bool(5));  // Top-right
        corners.setBool(2, flags.bool(6));  // Bottom-right
        corners.setBool(3, flags.bool(7));  // Bottom-left

        if (corners == 15) {
            // All corners present - all edges must be present too
            if (!flags.bool(0) || !flags.bool(1) || !flags.bool(2) || !flags.bool(3)) {
                return false;
            }
        }
        else if (corners != 0) {
            // Top-left corner requires left and top edges
            if (!flags.bool(4)) {
                if (!flags.bool(0) || !flags.bool(1)) {
                    return false;
                }
            }
            // Top-right corner requires top and right edges
            if (!flags.bool(5)) {
                if (!flags.bool(1) || !flags.bool(2)) {
                    return false;
                }
            }
            // Bottom-right corner requires right and bottom edges
            if (!flags.bool(6)) {
                if (!flags.bool(2) || !flags.bool(3)) {
                    return false;
                }
            }
            // Bottom-left corner requires bottom and left edges
            if (!flags.bool(7)) {
                if (!flags.bool(3) || !flags.bool(0)) {
                    return false;
                }
            }
        }

        return true;

    }

}
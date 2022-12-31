package ceramic;

using ceramic.Extensions;

class AutoTiler extends Entity implements Component {

    @entity var layerData:TilemapLayerData;

    public var autoTiles(default, null):ReadOnlyArray<AutoTile>;

    var gidMap:IntMap<AutoTile>;

    public function new(autoTiles:Array<AutoTile>) {

        super();

        this.autoTiles = [].concat(autoTiles);

        this.gidMap = new IntMap<AutoTile>();
        for (i in 0...autoTiles.length) {
            var autoTile = autoTiles.unsafeGet(i);
            this.gidMap.set(autoTile.gid, autoTile);
        }

    }

    function bindAsComponent() {

        layerData.onTilesChange(this, handleTilesChange);
        computeAutoTiles(layerData.tiles);

    }

    function handleTilesChange(tiles:ReadOnlyArray<TilemapTile>, prevTiles:ReadOnlyArray<TilemapTile>):Void {

        computeAutoTiles(tiles);

    }

    function computeAutoTiles(tiles:ReadOnlyArray<TilemapTile>):Void {

        var computedTiles:Array<TilemapTile> = [];
        if (layerData.computedTiles != null) {
            computedTiles = computedTiles.concat(layerData.computedTiles.original);
        }
        computedTiles.setArrayLength(tiles.length);

        var edgeCorner32Map = AutoTiler.edgeCorner32Map;
        var expandedBottomCorner26Map = AutoTiler.expandedBottomCorner26Map;

        var row = 0;
        var col = 0;
        var width = layerData.width;
        var height = layerData.height;
        var numTiles = width * height;
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
                    case EDGE_16 | EDGE_CORNER_32 | EXPANDED_47 | EXPANDED_BOTTOM_CORNER_26:

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
                            n = i - width;
                            otherTile = tiles.unsafeGet(n);
                            n += numTiles;
                            otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                            if (otherTile.gid == gid && otherExtraTile.gid == extraTile.gid)
                                edgeMask.setBool(1, true);
                        }
                        else if (boundsSameTile) {
                            edgeMask.setBool(1, true);
                        }
                        if (col < width - 1) {
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
                        if (row < height - 1) {
                            // Bottom
                            n = i + width;
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
                                        n = i - width - 1;
                                        otherTile = tiles.unsafeGet(n);
                                        n += numTiles;
                                        otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                                        if (otherTile.gid != gid || otherExtraTile.gid != extraTile.gid) {
                                            cornerMask.setBool(0, false);
                                        }
                                    }
                                }
                                if (edgeMask.bool(3)) {
                                    if (col > 0 && row < height - 1) {
                                        // Bottom-left corner
                                        n = i + width - 1;
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
                                    if (col < width - 1 && row > 0) {
                                        // Top-right corner
                                        n = i - width + 1;
                                        otherTile = tiles.unsafeGet(n);
                                        n += numTiles;
                                        otherExtraTile = hasExtraTiles ? tiles.unsafeGet(n) : 0;
                                        if (otherTile.gid != gid || otherExtraTile.gid != extraTile.gid) {
                                            cornerMask.setBool(1, false);
                                        }
                                    }
                                }
                                if (edgeMask.bool(3)) {
                                    if (col < width - 1 && row < height - 1) {
                                        // Bottom-right corner
                                        n = i + width + 1;
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
                            }

                            // Add extra tile on top if it already existed
                            // but offset it with gid
                            if (extraTile != 0) {
                                computedTiles[i + numTiles * 2] = extraTile;
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
                                finalIndex = edgeCorner32Map[finalIndex];
                                if (kind == EXPANDED_BOTTOM_CORNER_26) {
                                    finalIndex = expandedBottomCorner26Map[finalIndex];
                                }

                                tile.gid = gid + finalIndex;
                            }

                            // Add extra tile on top if it already existed
                            // but offset it with gid
                            if (extraTile != 0) {
                                computedTiles[i + numTiles] = extraTile;
                            }
                        }
                }
            }

            // Assign computed tile
            computedTiles.unsafeSet(i, tile);

            // Update row and columns
            col++;
            if (col == width) {
                col = 0;
                row++;
            }

            // Increment extra i
            extraI++;
        }

        // Update computed tiles
        layerData.computedTiles = computedTiles;

    }

    public static var edgeCorner32Map(get,null):ReadOnlyArray<Int> = null;
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

    public static var expandedBottomCorner26Map(get,null):ReadOnlyArray<Int> = null;
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

    public static var edgeCorner32InvertedMap(get,null):ReadOnlyArray<Int> = null;
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

    public static function isValidEdgeCorner32Combination(value:Int):Bool {

        var flags:Flags = value;

        var corners:Flags = 0;
        corners.setBool(0, flags.bool(4));
        corners.setBool(1, flags.bool(5));
        corners.setBool(2, flags.bool(6));
        corners.setBool(3, flags.bool(7));

        if (corners == 15) {
            if (!flags.bool(0) || !flags.bool(1) || !flags.bool(2) || !flags.bool(3)) {
                return false;
            }
        }
        else if (corners != 0) {
            // Top-left corner
            if (!flags.bool(4)) {
                if (!flags.bool(0) || !flags.bool(1)) {
                    return false;
                }
            }
            // Top-right corner
            if (!flags.bool(5)) {
                if (!flags.bool(1) || !flags.bool(2)) {
                    return false;
                }
            }
            // Bottom-right corner
            if (!flags.bool(6)) {
                if (!flags.bool(2) || !flags.bool(3)) {
                    return false;
                }
            }
            // Bottom-left corner
            if (!flags.bool(7)) {
                if (!flags.bool(3) || !flags.bool(0)) {
                    return false;
                }
            }
        }

        return true;

    }

}
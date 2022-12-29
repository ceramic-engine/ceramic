package ceramic;

/**
 * Specifies which kind of auto tiling to use with `AutoTiler` component
 */
enum abstract AutoTileKind(Int) from Int to Int {

    /**
     * Auto tiling using 16 tiles for edges.
     * There are no corners.
     */
    var EDGE_16 = 1;

    /**
     * Auto tiling using 32 tiles. 16 for edges and 16 for corners.
     * Corner tiles are overlapping edge tiles.
     */
    var EDGE_CORNER_32 = 2;

    /**
     * Auto tiling using 47 tiles.
     * In contrary of `EDGE_CORNER_32` auto-tiling, there is no need to overlap
     * multiple tiles as the 47 pre-rendered tiles should cover every case.
     */
    var EXPANDED_47 = 3;

    /**
     * More specific auto tiling using 26 tiles.
     * Similar to `EXPANDED_47` except that tiles
     * can only have corners at the bottom so tiles
     * with top corners are replaced with their
     * equivalent that doesn't have those corners.
     * Useful to use a smaller number of tiles for auto tiling
     * when you don't need the top corners but need the bottom ones.
     */
    var EXPANDED_BOTTOM_CORNER_26 = 4;

}
package ceramic;

/**
 * Specifies which kind of auto tiling to use with `AutoTiler` component
 */
enum abstract AutoTileKind(Int) from Int to Int {

    /**
     * Auto tiling using 32 tiles. 16 for edges and 16 for corners.
     * Corner tiles are overlapping edge tiles.
     */
    var EDGE_CORNER_32 = 1;

    /**
     * Auto tiling using expanded EDGE_CORNER_32 tiles.
     * All valid pre-rendered combinations of 16 edges tiles and 16 edges corners.
     */
    var EDGE_CORNER_32_EXPANDED = 2;

}
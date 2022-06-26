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
     * Auto tiling using 48 tiles.
     * In contrary of `EDGE_CORNER_32` auto-tiling, there is no need to overlap
     * multiple tiles as the 48 pre-rendered tiles should cover every case.
     */
    var EXPANDED_48 = 2;

}
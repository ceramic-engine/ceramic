package ceramic;

/**
 * Defines the type of auto-tiling algorithm used by the `AutoTiler` component.
 * Each algorithm requires a specific arrangement of tiles in the source tileset
 * and produces different visual results for tile connections.
 * 
 * Auto-tiling algorithms analyze neighboring tiles to automatically select the
 * appropriate tile variant that creates seamless connections. The choice of
 * algorithm depends on:
 * - The visual style desired (sharp corners vs rounded)
 * - The number of tile variants available
 * - Whether overlapping tiles are supported
 * - The tileset layout standard being followed
 * 
 * ## Common Use Cases:
 * - EDGE_16: Simple platforms without corner variations
 * - EDGE_CORNER_32: Detailed terrain with separate corner overlays
 * - EXPANDED_47: Complete terrain with all edge/corner combinations
 * - TILESETTER_BLOB_47: When using Tilesetter-generated tilesets
 * 
 * @see AutoTiler The component that processes auto-tiling
 * @see AutoTile Configuration for individual auto-tiles
 */
enum abstract AutoTileKind(Int) from Int to Int {

    /**
     * Basic auto-tiling using 16 tiles for edge connections only.
     * This pattern handles straight edges but not corners, creating
     * angular connections at diagonal boundaries.
     * 
     * Tile arrangement in tileset:
     * - 16 tiles total for all edge combinations
     * - No dedicated corner tiles
     * - Suitable for simple platformer tiles or angular terrain
     * 
     * Visual result: Sharp, 90-degree corners where edges meet
     */
    var EDGE_16 = 1;

    /**
     * Auto-tiling using 32 tiles: 16 for edges and 16 for corners.
     * Corner tiles are rendered as separate overlapping layers on top
     * of edge tiles, allowing for smooth corner transitions.
     * 
     * Tile arrangement in tileset:
     * - First 16 tiles: Edge variations
     * - Next 16 tiles: Corner overlays
     * - Requires rendering multiple tiles per cell for corners
     * 
     * Visual result: Smooth, rounded corners with better transitions
     * Performance note: May render up to 2 tiles per cell (edge + corner)
     */
    var EDGE_CORNER_32 = 2;

    /**
     * Comprehensive auto-tiling using 47 pre-rendered tile combinations.
     * Unlike `EDGE_CORNER_32`, each tile is complete and doesn't require
     * overlapping, as all 47 possible edge/corner combinations are included.
     * 
     * Tile arrangement in tileset:
     * - 47 unique tiles covering all connection patterns
     * - Single tile per cell (no overlapping needed)
     * - Standard "blob" tileset layout
     * 
     * Visual result: Smooth, organic connections with all variations
     * Performance: Optimal (one tile per cell)
     * Memory: Higher tileset size but better runtime performance
     */
    var EXPANDED_47 = 3;

    /**
     * Specialized auto-tiling using 26 tiles, optimized for top-down views.
     * Similar to `EXPANDED_47` but only includes bottom corner variations,
     * making tiles with top corners fall back to their cornerless equivalents.
     * 
     * Use cases:
     * - Top-down games where top corners aren't visible
     * - Reducing tileset size while maintaining bottom detail
     * - Platform tiles that only need bottom corner variations
     * 
     * Tile arrangement:
     * - 26 tiles (subset of the 47-tile pattern)
     * - Bottom corners preserved, top corners simplified
     * - More compact tileset with acceptable visual quality
     */
    var EXPANDED_BOTTOM_CORNER_26 = 4;

    /**
     * Blob tileset pattern following the Tilesetter standard layout.
     * Functionally identical to `EXPANDED_47` but with tiles arranged
     * according to Tilesetter's blob set specification.
     * 
     * This format is ideal when:
     * - Using Tilesetter-generated tilesets
     * - Following standardized tileset layouts
     * - Sharing tilesets with other engines that support this format
     * 
     * Reference: https://www.tilesetter.org/docs/generating_tilesets#blob-sets
     * 
     * The blob pattern includes all 47 tile variations but in a specific
     * grid arrangement that Tilesetter and compatible tools expect.
     */
    var TILESETTER_BLOB_47 = 5;

}
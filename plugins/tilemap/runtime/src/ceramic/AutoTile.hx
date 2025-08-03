package ceramic;

/**
 * Configuration for an auto-tiling tile that automatically adjusts its appearance
 * based on neighboring tiles. Auto-tiles adapt their visual representation to create
 * seamless connections with adjacent tiles of the same type.
 * 
 * Auto-tiling is commonly used for:
 * - Terrain (grass, dirt, water)
 * - Walls and platforms
 * - Pipes and roads
 * - Any tileable surface that needs edge transitions
 * 
 * @see AutoTileKind For different auto-tiling algorithms
 * @see AutoTiler For the auto-tiling processor
 * @see Tileset For tileset management
 */
@:structInit
class AutoTile {

    /**
     * The kind of autotile algorithm to use. Different algorithms require
     * different tile arrangements in the source tileset and produce different
     * visual results.
     * 
     * Common kinds include:
     * - BLOB_47: 47-tile blob pattern for organic shapes
     * - TILESETTER_BLOB_47: Tilesetter-specific 47-tile variant
     * - Custom patterns for specific use cases
     */
    public var kind:AutoTileKind;

    /**
     * The main global tile ID (GID) of this autotile. This is typically the
     * "standalone" or "center" tile that appears when no auto-tiling 
     * transformation is needed (i.e., when surrounded by tiles of the same type).
     * 
     * The GID corresponds to a specific tile in the tileset and serves as the
     * base reference for finding related auto-tile variations.
     */
    public var gid:Int;

    /**
     * Controls whether tilemap boundaries affect auto-tiling calculations.
     * 
     * When `true` (default):
     * - Tiles at the edge of the tilemap connect with the boundary
     * - Creates a "filled" appearance at map edges
     * - Useful for solid terrain that extends beyond the visible area
     * 
     * When `false`:
     * - Tiles at the edge don't connect with boundaries
     * - Creates an "island" appearance
     * - Useful for floating platforms or isolated structures
     */
    public var bounds:Bool = true;

    /**
     * The tileset containing this autotile's graphics. Required when using
     * certain auto-tile kinds like `TILESETTER_BLOB_47` that need tileset
     * information to locate tile variations.
     * 
     * The tileset defines the tile dimensions and layout necessary for
     * computing row/column positions from GIDs.
     */
    public var tileset:Tileset = null;

    /**
     * The column position in the tileset grid for the main GID tile.
     * Automatically computed when `computeValues()` is called.
     * 
     * This value is -1 if no tileset is assigned or values haven't been computed.
     * Column indices start at 0 for the leftmost column.
     */
    public var column(default, null):Int = -1;

    /**
     * The row position in the tileset grid for the main GID tile.
     * Automatically computed when `computeValues()` is called.
     * 
     * This value is -1 if no tileset is assigned or values haven't been computed.
     * Row indices start at 0 for the topmost row.
     */
    public var row(default, null):Int = -1;

    /**
     * Computes derived values like `row` and `column` from the current
     * configuration. This method is automatically called by `AutoTiler`
     * during processing.
     * 
     * The computation requires a valid `tileset` to be assigned. If no
     * tileset is available, row and column remain at their default -1 values.
     * 
     * This method should be called whenever the `gid` or `tileset` changes
     * to keep the computed values in sync.
     */
    public function computeValues() {

        if (tileset != null) {
            column = tileset.columnForGid(gid);
            row = tileset.rowForGid(gid);
        }

    }

}

package ceramic;

/**
 * Specialized Quad visual used to render individual tiles in a tilemap layer.
 *
 * TilemapQuad extends the basic Quad to add tilemap-specific properties and implements
 * object pooling for efficient memory management. Each quad represents a single visible
 * tile within a TilemapLayer and is automatically managed by the layer's rendering system.
 *
 * ## Features
 *
 * - **Object Pooling**: Reuses instances to minimize garbage collection
 * - **Tile Properties**: Stores tile index, position, and tile data
 * - **Arcade Physics**: When arcade plugin is enabled, can have physics bodies attached
 * - **Automatic Management**: Created and recycled automatically by TilemapLayer
 *
 * ## Internal Usage
 *
 * This class is primarily used internally by TilemapLayer. Direct instantiation
 * is not recommended - use the static `get()` method to obtain pooled instances.
 *
 * ```haxe
 * // Internal usage by TilemapLayer
 * var quad = TilemapQuad.get();
 * quad.index = tileIndex;
 * quad.column = col;
 * quad.row = row;
 * quad.tilemapTile = tileData;
 * // ... configure visual properties
 *
 * // When done, recycle back to pool:
 * quad.recycle();
 * ```
 *
 * @see TilemapLayer
 * @see TilemapTile
 * @see Quad
 */
class TilemapQuad extends Quad {

    /**
     * Static object pool for recycling TilemapQuad instances.
     * Initialized on first use to reduce memory allocation.
     */
    static var pool(default, null):Pool<TilemapQuad> = null;

    /**
     * The tile index in the layer's flat tile array.
     * Set to -1 when the quad is not in use.
     */
    public var index:Int = -1;

    /**
     * The column position of this tile in the tilemap grid (0-based).
     * Set to -1 when the quad is not in use.
     */
    public var column:Int = -1;

    /**
     * The row position of this tile in the tilemap grid (0-based).
     * Set to -1 when the quad is not in use.
     */
    public var row:Int = -1;

    /**
     * The tile data including GID and flip flags.
     * Contains the global tile ID and transformation information.
     */
    public var tilemapTile:TilemapTile = 0;

    /**
     * Gets a TilemapQuad instance from the object pool.
     * If the pool is empty, creates a new instance.
     * The returned quad will be active and ready for use.
     * @return A TilemapQuad instance ready for configuration
     */
    public static function get():TilemapQuad {

        var result:TilemapQuad = null;
        if (pool != null) {
            result = pool.get();
        }
        if (result == null) {
            result = new TilemapQuad();
        }
        else {
            result.active = true;
        }
        return result;

    }

    /**
     * Returns this TilemapQuad to the object pool for reuse.
     * Automatically removes the quad from its parent, resets all properties,
     * and marks it as inactive. This method should be called when the tile
     * is no longer needed to free memory and reduce garbage collection.
     */
    public function recycle():Void {

        if (this.parent != null) {
            this.parent.remove(this);
        }

        this.active = false;
        this.index = -1;
        this.column = -1;
        this.row = -1;
        this.tilemapTile = 0;

        if (pool == null) {
            pool = new Pool<TilemapQuad>();
        }

        pool.recycle(this);

    }

}

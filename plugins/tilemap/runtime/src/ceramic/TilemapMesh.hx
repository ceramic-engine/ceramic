package ceramic;

/**
 * Specialized Mesh visual used to render multiple tiles in a tilemap layer.
 *
 * TilemapMesh extends the basic Mesh to add tilemap-specific properties and implements
 * object pooling for efficient memory management. Each quad represents a single visible
 * tile within a TilemapLayer and is automatically managed by the layer's rendering system.
 *
 * ## Features
 *
 * - **Object Pooling**: Reuses instances to minimize garbage collection
 * - **Tile Mesh Properties**: Stores tile index, position, and tile data
 * - **Automatic Management**: Created and recycled automatically by TilemapLayer
 *
 * ## Internal Usage
 *
 * This class is primarily used internally by TilemapLayer. Direct instantiation
 * is not recommended - use the static `get()` method to obtain pooled instances.
 *
 * ```haxe
 * // Internal usage by TilemapLayer
 * var mesh = TilemapMesh.get();
 * mesh.layerIndex = layerIndex;
 * mesh.textureIndex = textureIndex;
 * // ... configure visual properties
 *
 * // When done, recycle back to pool:
 * mesh.recycle();
 * ```
 *
 * @see TilemapLayer
 * @see TilemapTile
 * @see Quad
 */
class TilemapMesh extends Mesh {

    /**
     * Static object pool for recycling TilemapMesh instances.
     * Initialized on first use to reduce memory allocation.
     */
    static var pool(default, null):Pool<TilemapMesh> = null;

    /**
     * The sub-layer index in the rendered layer.
     * Set to -1 when the mesh is not in use.
     */
    public var layerIndex:Int = -1;

    /**
     * The index of texture being used.
     */
    public var textureIndex:Int = -1;

    // Used to keep track during iteration within computeTileMeshes() (TilemapLayer)
    public var nextVertexIndice:Int = 0;
    public var nextIndexIndice:Int = 0;
    public var nextColorIndice:Int = 0;
    public var nextQuadIndice:Int = 0;

    /**
     * Gets a TilemapMesh instance from the object pool.
     * If the pool is empty, creates a new instance.
     * The returned quad will be active and ready for use.
     * @return A TilemapQuad instance ready for configuration
     */
    public static function get():TilemapMesh {

        var result:TilemapMesh = null;
        if (pool != null) {
            result = pool.get();
        }
        if (result == null) {
            result = new TilemapMesh();
        }
        else {
            result.active = true;
        }
        return result;

    }

    /**
     * Returns this TilemapMesh to the object pool for reuse.
     * Automatically removes the quad from its parent, resets all properties,
     * and marks it as inactive. This method should be called when the mesh
     * is no longer needed to free memory and reduce garbage collection.
     */
    public function recycle():Void {

        if (this.parent != null) {
            this.parent.remove(this);
        }

        this.active = false;
        this.layerIndex = -1;
        this.textureIndex = -1;
        this.nextVertexIndice = 0;
        this.nextIndexIndice = 0;
        this.nextColorIndice = 0;
        this.nextQuadIndice = 0;

        if (pool == null) {
            pool = new Pool<TilemapMesh>();
        }

        pool.recycle(this);

    }

}

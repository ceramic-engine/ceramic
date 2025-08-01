package ceramic;

using ceramic.Extensions;

/**
 * A global object pool for efficiently reusing Mesh instances and their arrays.
 * 
 * MeshPool provides a memory-efficient way to manage Mesh objects by recycling
 * them instead of creating new instances. This reduces garbage collection pressure
 * and improves performance in scenarios with frequent mesh creation/destruction.
 * 
 * The pool also manages arrays used by meshes (vertices, indices, colors, uvs)
 * to further optimize memory usage.
 * 
 * Key features:
 * - Mesh instance recycling with automatic cleanup
 * - Array buffer recycling for vertices, indices, colors, and UVs
 * - Thread-safe array clearing on native platforms
 * - Debug tracking for allocation and recycling
 * 
 * @example
 * ```haxe
 * // Get a mesh from pool (creates new if pool is empty)
 * var mesh = MeshPool.get();
 * mesh.createQuad(100, 100);
 * mesh.texture = myTexture;
 * parent.add(mesh);
 * 
 * // When done, recycle the mesh back to pool
 * MeshPool.recycle(mesh);
 * // The mesh is automatically cleaned up and ready for reuse
 * ```
 * 
 * @see Mesh The mesh class being pooled
 */
class MeshPool {

    /**
     * Pool of available mesh instances ready for reuse.
     */
    static var availableMeshes:Array<Mesh> = [];

    /**
     * Pool of available float arrays for vertices and UVs.
     */
    static var availableFloatArrays:Array<Array<Float>> = [];
    
    /**
     * Pool of available integer arrays for indices and colors.
     */
    static var availableIntArrays:Array<Array<Int>> = [];

    /**
     * Gets an integer array from the pool or creates a new one if pool is empty.
     * Used internally for indices and color arrays.
     * 
     * @return An empty integer array
     */
    @:noCompletion inline static public function getIntArray():Array<Int> {

        return availableIntArrays.length > 0 ? availableIntArrays.pop() : [];

    }

    /**
     * Gets a float array from the pool or creates a new one if pool is empty.
     * Used internally for vertices and UV arrays.
     * 
     * @return An empty float array
     */
    @:noCompletion inline static public function getFloatArray():Array<Float> {

        return availableFloatArrays.length > 0 ? availableFloatArrays.pop() : [];

    }

    /**
     * Returns an integer array to the pool for reuse.
     * The array is cleared before being added to the pool.
     * 
     * Uses platform-specific optimizations:
     * - Native (cpp): Direct size manipulation for performance
     * - Other platforms: Standard splice operation
     * 
     * @param array The integer array to recycle. Can be null.
     */
    @:noCompletion inline static public function recycleIntArray(array:Array<Int>):Void {

        if (array != null) {
            if (array.length > 0) {
                #if cpp
                untyped array.__SetSize(0);
                #else
                array.splice(0, array.length);
                #end
            }
            availableIntArrays.push(array);
        }

    }

    /**
     * Returns a float array to the pool for reuse.
     * The array is cleared before being added to the pool.
     * 
     * Uses platform-specific optimizations:
     * - Native (cpp): Direct size manipulation for performance
     * - Other platforms: Standard splice operation
     * 
     * @param array The float array to recycle. Can be null.
     */
    @:noCompletion inline static public function recycleFloatArray(array:Array<Float>):Void {

        if (array != null) {
            if (array.length > 0) {
                #if cpp
                untyped array.__SetSize(0);
                #else
                array.splice(0, array.length);
                #end
            }
            availableFloatArrays.push(array);
        }

    }

    /**
     * Gets a mesh from the pool or creates a new one if the pool is empty.
     * 
     * The returned mesh is:
     * - Active and ready to be displayed
     * - Reset to default values (visible, touchable)
     * - Provided with empty arrays for indices, vertices, colors, and UVs
     * 
     * Debug mode tracks allocation positions for memory leak detection.
     * 
     * @param pos (Debug only) Source position for allocation tracking
     * @return A ready-to-use Mesh instance
     * 
     * @example
     * ```haxe
     * var mesh = MeshPool.get();
     * mesh.createQuad(100, 100);
     * parent.add(mesh);
     * ```
     */
    public static function get(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end):Mesh {

        if (availableMeshes.length > 0) {
            var mesh = availableMeshes.pop();
            mesh.active = true;
            mesh.visible = true;
            mesh.touchable = true;
            mesh.indices = getIntArray();
            mesh.vertices = getFloatArray();
            mesh.colors = getIntArray();
            mesh.uvs = getFloatArray();
            #if ceramic_debug_entity_allocs
            @:privateAccess mesh.recycledPosInfos = null;
            @:privateAccess mesh.reusedPosInfos = pos;
            #end
            return mesh;
        }
        else {
            var mesh = new Mesh();
            #if ceramic_debug_entity_allocs
            @:privateAccess mesh.posInfos = pos;
            #end
            return mesh;
        }

    }

    /**
     * Returns a mesh to the pool for reuse.
     * 
     * The mesh is automatically:
     * - Cleared of all visual data
     * - Removed from its parent (if any)
     * - Reset to default property values
     * - Made inactive (not displayed)
     * - Arrays recycled to their respective pools
     * 
     * Debug mode checks for double-recycling and tracks recycling positions.
     * 
     * @param mesh The mesh to recycle
     * @param pos (Debug only) Source position for recycling tracking
     * 
     * @throws String If the mesh is already in the pool (debug mode only)
     * 
     * @example
     * ```haxe
     * // When done with a mesh
     * MeshPool.recycle(myMesh);
     * // myMesh is now cleaned and in the pool
     * ```
     */
    public static function recycle(mesh:Mesh #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        mesh.clear();

        #if ceramic_debug_mesh_pool
        if (availableMeshes.indexOf(mesh) != -1) {
            throw 'Mesh is already recycled: $mesh';
        }
        #end

        if (mesh.parent != null) {
            mesh.parent.remove(mesh);
        }

        #if ceramic_debug_entity_allocs
        @:privateAccess mesh.recycledPosInfos = pos;
        #end

        mesh.pos(0, 0);
        mesh.scale(1, 1);
        mesh.anchor(0, 0);
        mesh.skew(0, 0);
        mesh._width = 0;
        mesh._height = 0;
        mesh.transform = null;
        mesh.rotation = 0;
        mesh.active = true;
        mesh.visible = true;
        mesh.touchable = true;
        mesh.active = false;
        mesh.renderTarget = null;
        mesh.texture = null;
        mesh.multiTouch = false;
        mesh._numPointerDown = 0;
        mesh._numPointerOver = 0;
        mesh.clip = null;
        mesh.inheritAlpha = false;
        mesh.alpha = 1;
        mesh.blending = Blending.AUTO;
        mesh.shader = null;
        mesh.customFloatAttributesSize = 0;

        #if ceramic_no_depth_range
        mesh.depthRange = -1;
        #else
        mesh.depthRange = 1;
        #end

#if ceramic_wireframe
        mesh.wireframe = false;
#end

        recycleIntArray(mesh.indices);
        recycleFloatArray(mesh.vertices);
        recycleIntArray(mesh.colors);
        recycleFloatArray(mesh.uvs);

        mesh.indices = null;
        mesh.vertices = null;
        mesh.colors = null;
        mesh.uvs = null;

        #if ceramic_wireframe
        mesh.wireframeIndices = null;
        #end

        mesh.offPointerDown();
        mesh.offPointerUp();
        mesh.offPointerOver();
        mesh.offPointerOut();
        mesh.offFocus();
        mesh.offBlur();

        availableMeshes.push(mesh);

    }

    /**
     * Clears the entire mesh pool and destroys all pooled meshes.
     * 
     * This permanently destroys all meshes in the pool, freeing their resources.
     * Use this when:
     * - Switching between major application states
     * - Freeing memory before loading new content
     * - Shutting down the application
     * 
     * Note: Array pools are not cleared by this method.
     * 
     * @example
     * ```haxe
     * // Before loading a new level
     * MeshPool.clear();
     * // All pooled meshes are now destroyed
     * ```
     */
    public static function clear():Void {

        if (availableMeshes.length > 0) {
            var prevAvailable = availableMeshes;
            availableMeshes = [];
            for (i in 0...prevAvailable.length) {
                prevAvailable.unsafeGet(i).destroy();
            }
        }

    }

}
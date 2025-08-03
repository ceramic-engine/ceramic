package ceramic.scriptable;

/**
 * Scriptable wrapper for MeshColorMapping to expose mesh coloring modes to scripts.
 * 
 * This class provides constants that define how colors are applied to mesh geometry.
 * In scripts, this type is exposed as `MeshColorMapping` (without the Scriptable prefix).
 * 
 * Color mapping determines how color values are distributed across a mesh's geometry,
 * allowing for uniform coloring, per-triangle coloring, or per-vertex coloring.
 * 
 * ## Usage in Scripts
 * 
 * ```hscript
 * // Create a mesh with uniform color
 * var mesh = new Mesh();
 * mesh.colorMapping = MeshColorMapping.MESH;
 * mesh.color = Color.RED; // Entire mesh is red
 * 
 * // Use per-triangle coloring
 * mesh.colorMapping = MeshColorMapping.INDICES;
 * mesh.colors = [
 *     Color.RED,    // First triangle
 *     Color.GREEN,  // Second triangle
 *     Color.BLUE    // Third triangle
 * ];
 * 
 * // Use per-vertex coloring for gradients
 * mesh.colorMapping = MeshColorMapping.VERTICES;
 * mesh.colors = [
 *     Color.RED,    // First vertex
 *     Color.GREEN,  // Second vertex
 *     Color.BLUE,   // Third vertex
 *     Color.YELLOW  // Fourth vertex
 * ];
 * ```
 * 
 * ## Mapping Modes
 * 
 * - **MESH**: Single color for the entire mesh (most efficient)
 * - **INDICES**: One color per triangle (3 vertices)
 * - **VERTICES**: One color per vertex (allows smooth gradients)
 * 
 * @see ceramic.MeshColorMapping The actual implementation
 * @see ceramic.Mesh For using color mapping with meshes
 */
class ScriptableMeshColorMapping {
    /**
     * Map a single color to the whole mesh.
     */
    public static var MESH:Int = 0;
    /**
     * Map a color to each indice.
     */
    public static var INDICES:Int = 1;
    /**
     * Map a color to each vertex.
     */
    public static var VERTICES:Int = 2;
}

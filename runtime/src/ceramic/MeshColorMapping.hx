package ceramic;

/**
 * Defines how colors are mapped to a mesh's geometry.
 *
 * This enum controls the color mapping strategy for Mesh objects, determining
 * whether colors are applied uniformly, per-triangle, or per-vertex.
 * The choice affects both visual appearance and performance.
 *
 * Performance considerations:
 * - MESH: Fastest, uses least memory (single color)
 * - INDICES: Moderate, one color per triangle
 * - VERTICES: Slowest, most flexible (smooth gradients possible)
 *
 * ```haxe
 * var mesh = new Mesh();
 *
 * // Single color for entire mesh
 * mesh.colorMapping = MESH;
 * mesh.color = Color.RED;
 *
 * // Different color per triangle
 * mesh.colorMapping = INDICES;
 * mesh.colors = [Color.RED, Color.GREEN, Color.BLUE];
 *
 * // Color per vertex (for gradients)
 * mesh.colorMapping = VERTICES;
 * mesh.colors = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW];
 * ```
 *
 * @see Mesh The mesh class that uses this color mapping
 */
enum abstract MeshColorMapping(Int) {
    /**
     * Maps a single color to the entire mesh.
     *
     * This is the most efficient color mapping mode, using only the mesh's
     * main color property. All vertices and triangles share the same color.
     *
     * Use cases:
     * - Solid colored meshes
     * - Simple geometric shapes
     *
     * @see Mesh.color
     */
    var MESH = 0;
    /**
     * Maps a color to each triangle (set of 3 indices).
     *
     * Each triangle in the mesh can have its own color. The colors array
     * should have one color per triangle (indices.length / 3 colors).
     * Within each triangle, all three vertices share the same color.
     *
     * Use cases:
     * - Low-poly art style with flat-shaded triangles
     * - Visualizing mesh topology
     * - Face-based coloring effects
     *
     * @see Mesh.colors
     * @see Mesh.indices
     */
    var INDICES = 1;
    /**
     * Maps a color to each vertex in the mesh.
     *
     * Each vertex can have its own color, enabling smooth color gradients
     * across triangles through hardware color interpolation. The colors array
     * should have one color per vertex (vertices.length / 2 colors).
     *
     * Use cases:
     * - Smooth color gradients
     * - Vertex-based lighting effects
     * - Heat maps and data visualization
     * - Advanced shading techniques
     *
     * Note: This mode uses the most memory and GPU bandwidth.
     *
     * @see Mesh.colors
     * @see Mesh.vertices
     */
    var VERTICES = 2;
}

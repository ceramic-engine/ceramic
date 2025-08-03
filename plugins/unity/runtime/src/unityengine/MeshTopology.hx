package unityengine;

/**
 * Defines how vertex indices are interpreted to form primitives.
 * Determines the basic shape type created from vertices.
 * 
 * In Ceramic's Unity backend, Triangles is primarily used for
 * rendering filled shapes and sprites, while Lines may be used
 * for debugging or wireframe rendering.
 * 
 * @see Mesh
 * @see SubMeshDescriptor
 */
@:native('UnityEngine.MeshTopology')
extern class MeshTopology {

    /**
     * Interprets indices in groups of 3 to form triangles.
     * Most common topology for 3D and filled 2D rendering.
     * 
     * Index pattern: [0,1,2, 3,4,5, ...]
     * Forms triangles: (0,1,2), (3,4,5), ...
     * 
     * Used by Ceramic for all filled visuals.
     */
    static var Triangles:MeshTopology;

    /**
     * Interprets indices in groups of 4 to form quadrilaterals.
     * 
     * Index pattern: [0,1,2,3, 4,5,6,7, ...]
     * Forms quads: (0,1,2,3), (4,5,6,7), ...
     * 
     * Note: Deprecated in modern Unity, converted to triangles internally.
     */
    static var Quads:MeshTopology;

    /**
     * Interprets indices in pairs to form individual line segments.
     * 
     * Index pattern: [0,1, 2,3, 4,5, ...]
     * Forms lines: (0→1), (2→3), (4→5), ...
     * 
     * Used for wireframes, debugging visualizations, or stroked paths.
     */
    static var Lines:MeshTopology;

    /**
     * Forms a continuous line through all vertices in order.
     * 
     * Index pattern: [0,1,2,3,4, ...]
     * Forms connected line: 0→1→2→3→4→...
     * 
     * Efficient for drawing paths or outlines with fewer indices.
     */
    static var LineStrip:MeshTopology;

    /**
     * Renders each vertex as an individual point.
     * 
     * Index pattern: [0,1,2,3, ...]
     * Renders points at each vertex position.
     * 
     * Point size controlled by shader. Useful for particle
     * systems or debug visualization of vertex positions.
     */
    static var Points:MeshTopology;

}
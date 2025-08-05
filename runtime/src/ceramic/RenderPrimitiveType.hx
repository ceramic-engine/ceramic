package ceramic;

/**
 * Defines the primitive types used for rendering geometry.
 * 
 * This enum specifies how vertices should be interpreted when drawing:
 * - TRIANGLE: Groups vertices into triangles (3 vertices per primitive)
 * - LINE: Groups vertices into lines (2 vertices per primitive)
 * 
 * The primitive type affects how the GPU interprets the vertex and index buffers
 * during rendering. It determines the basic shape that will be drawn from the
 * provided vertex data.
 * 
 * ```haxe
 * // Set primitive type for triangle-based rendering (default)
 * renderer.setPrimitiveType(TRIANGLE);
 * 
 * // Switch to line rendering for wireframes or outlines
 * renderer.setPrimitiveType(LINE);
 * ```
 * 
 * @see Renderer For usage in the rendering pipeline
 * @see Mesh For geometry that uses these primitive types
 */
enum abstract RenderPrimitiveType(Int) from Int to Int {

    /**
     * Triangle primitive type.
     * 
     * Vertices are grouped into triangles with 3 vertices each.
     * This is the most common primitive type used for:
     * - Filled shapes and surfaces
     * - Textured quads and meshes
     * - UI elements
     * - Most 2D graphics
     * 
     * When using indexed rendering, every 3 indices define one triangle.
     * Triangles use the winding order to determine front/back faces.
     */
    var TRIANGLE = 1;

    /**
     * Line primitive type.
     * 
     * Vertices are grouped into lines with 2 vertices each.
     * Used for:
     * - Wireframe rendering
     * - Debug visualization
     * - Outlines and strokes
     * - Vector graphics
     * 
     * When using indexed rendering, every 2 indices define one line segment.
     * Lines have a fixed 1-pixel width in most renderers.
     */
    var LINE = 2;

}
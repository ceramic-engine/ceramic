package backend;

/**
 * Enumeration of visual element types used by the Clay backend renderer.
 * 
 * This enum identifies the type of visual being rendered, which determines
 * how the renderer processes and batches draw calls. Different visual types
 * have different performance characteristics and rendering requirements.
 */
enum VisualItem {

    /**
     * No visual item.
     * Used as a default or placeholder value when no specific visual type applies.
     */
    NONE;

    /**
     * Quad visual - a four-vertex rectangle.
     * 
     * The most common and optimized visual type, used for:
     * - Sprites and images
     * - Solid color rectangles
     * - UI elements
     * 
     * Quads are highly optimized in the renderer with specialized batching
     * for maximum performance.
     */
    QUAD;

    /**
     * Mesh visual - arbitrary triangle-based geometry.
     * 
     * Used for complex shapes including:
     * - Polygons and custom shapes
     * - Particle systems
     * - 3D-like effects
     * - Distortion effects
     * 
     * Meshes have more overhead than quads but provide complete geometric flexibility.
     */
    MESH;

}

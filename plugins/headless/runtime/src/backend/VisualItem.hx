package backend;

/**
 * Visual item type enumeration for the headless backend.
 * 
 * This enum categorizes different types of visual objects for
 * optimized rendering. The backend uses these categories to
 * determine the appropriate rendering path for each visual
 * without performing expensive type checks during drawing.
 * 
 * In headless mode, these categories are maintained for API
 * compatibility and logic flow, even though no actual rendering occurs.
 */
enum VisualItem {

    /**
     * No specific visual type or unsupported visual.
     * Used for visual objects that don't have specialized rendering paths.
     */
    NONE;

    /**
     * Quad/rectangle visual type.
     * Used for simple rectangular geometry like sprites, images, and UI elements.
     */
    QUAD;

    /**
     * Mesh visual type.
     * Used for complex geometry with custom vertex data and arbitrary topology.
     */
    MESH;

}

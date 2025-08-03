package backend;

#if !no_backend_docs
/**
 * Visual element types for Unity rendering backend.
 * Used to categorize different types of drawable objects.
 */
#end
enum VisualItem {

    #if !no_backend_docs
    /**
     * No visual element.
     * Used as a default or placeholder value.
     */
    #end
    NONE;

    #if !no_backend_docs
    /**
     * Quad visual element.
     * Represents a rectangular sprite or image.
     */
    #end
    QUAD;

    #if !no_backend_docs
    /**
     * Mesh visual element.
     * Represents complex geometry with arbitrary vertices and triangles.
     */
    #end
    MESH;

}

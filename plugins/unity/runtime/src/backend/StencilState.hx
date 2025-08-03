package backend;

#if !no_backend_docs
/**
 * Stencil buffer operation states for Unity rendering.
 * Controls how the stencil buffer is used during draw operations.
 */
#end
enum abstract StencilState(Int) from Int to Int {

    #if !no_backend_docs
    /**
     * No stencil operations.
     * Stencil buffer is not used.
     */
    #end
    var NONE = 0;

    #if !no_backend_docs
    /**
     * Test against stencil buffer.
     * Only pixels that pass the stencil test are rendered.
     */
    #end
    var TEST = 1;

    #if !no_backend_docs
    /**
     * Write to stencil buffer.
     * Updates stencil values for rendered pixels.
     */
    #end
    var WRITE = 2;
    
    #if !no_backend_docs
    /**
     * Clear stencil buffer.
     * Resets stencil values to zero.
     */
    #end
    var CLEAR = 3;

}
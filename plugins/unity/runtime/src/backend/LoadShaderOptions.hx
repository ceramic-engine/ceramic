package backend;

#if !no_backend_docs
/**
 * Options for loading shader files in the Unity backend.
 * 
 * These options control how custom shader programs are loaded
 * for use with Ceramic's rendering system. Shaders are loaded
 * as text files and compiled into GPU programs.
 * 
 * @see backend.Shaders.load() Uses these options when loading shaders
 */
#end
typedef LoadShaderOptions = {

    #if !no_backend_docs
    /**
     * Optional callback queue for deferred execution.
     * If provided, the load completion callback will be queued
     * on this Immediate instance rather than called directly.
     * Useful for batching shader compilation operations.
     */
    #end
    @:optional var immediate:ceramic.Immediate;

    #if !no_backend_docs
    /**
     * The loading method to use (SYNC or ASYNC).
     * - SYNC: Blocks until the shader is loaded and compiled
     * - ASYNC: Loads in the background and calls callback when ready
     * 
     * Note: Shader compilation in Unity is typically synchronous,
     * so this mainly affects the callback timing mechanism.
     */
    #end
    @:optional var loadMethod:ceramic.AssetsLoadMethod;

}

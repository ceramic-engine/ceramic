package backend;

#if !no_backend_docs
/**
 * Options for loading text files in the Unity backend.
 * 
 * These options control how text files are loaded from Unity's
 * Resources folder. Text files include JSON data, configuration files,
 * bitmap font definitions, texture atlases, and other text-based assets.
 * 
 * @see backend.Texts.load() Uses these options when loading text files
 */
#end
typedef LoadTextOptions = {

    #if !no_backend_docs
    /**
     * Optional callback queue for deferred execution.
     * If provided, the load completion callback will be queued
     * on this Immediate instance rather than called directly.
     * This helps manage callback ordering and performance.
     */
    #end
    @:optional var immediate:ceramic.Immediate;

    #if !no_backend_docs
    /**
     * The loading method to use (SYNC or ASYNC).
     * - SYNC: Blocks until the text file is fully loaded
     * - ASYNC: Loads in the background and calls callback when ready
     * 
     * Note: Unity Resources.Load is synchronous by nature, so this
     * option primarily controls when the callback is invoked.
     */
    #end
    @:optional var loadMethod:ceramic.AssetsLoadMethod;

}

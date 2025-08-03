package backend;

#if !no_backend_docs
/**
 * Options for loading binary files in the Unity backend.
 * 
 * These options control how binary data is loaded from Unity's
 * Resources folder. Binary files are loaded as Unity TextAssets
 * and converted to Haxe Bytes for use by the application.
 * 
 * @see backend.Binaries.load() Uses these options when loading binary data
 */
#end
typedef LoadBinaryOptions = {

    #if !no_backend_docs
    /**
     * Optional callback queue for deferred execution.
     * If provided, the load completion callback will be queued
     * on this Immediate instance rather than called directly.
     * This allows batching of callbacks for performance.
     */
    #end
    @:optional var immediate:ceramic.Immediate;

    #if !no_backend_docs
    /**
     * The loading method to use (SYNC or ASYNC).
     * - SYNC: Blocks until the binary data is fully loaded
     * - ASYNC: Loads in the background and calls callback when ready
     * 
     * Note: Unity Resources.Load is inherently synchronous, so this
     * mainly affects callback timing rather than actual loading behavior.
     */
    #end
    @:optional var loadMethod:ceramic.AssetsLoadMethod;

}

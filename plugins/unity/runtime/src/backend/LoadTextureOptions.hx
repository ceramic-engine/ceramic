package backend;

#if !no_backend_docs
/**
 * Options for loading texture files in the Unity backend.
 * 
 * These options control how image files are loaded and converted
 * to Unity Texture2D objects for GPU rendering. The backend supports
 * various image formats including PNG, JPEG, and other Unity-supported
 * formats.
 * 
 * @see backend.Textures.load() Uses these options when loading textures
 * @see backend.Info.imageExtensions() Lists supported image formats
 */
#end
typedef LoadTextureOptions = {

    #if !no_backend_docs
    /**
     * Optional callback queue for deferred execution.
     * If provided, the load completion callback will be queued
     * on this Immediate instance rather than called directly.
     * This is useful for batching texture loads and managing memory.
     */
    #end
    @:optional var immediate:ceramic.Immediate;

    #if !no_backend_docs
    /**
     * The loading method to use (SYNC or ASYNC).
     * - SYNC: Blocks until the texture is loaded and uploaded to GPU
     * - ASYNC: Loads in the background and calls callback when ready
     * 
     * Note: Unity's Resources.Load is synchronous, but texture
     * GPU upload can be deferred in some cases.
     */
    #end
    @:optional var loadMethod:ceramic.AssetsLoadMethod;

}

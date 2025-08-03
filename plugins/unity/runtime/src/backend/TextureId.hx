package backend;

#if !no_backend_docs
/**
 * Type alias for texture identifiers in the Unity backend.
 */
#end
typedef TextureId = TextureIdImpl;

#if !no_backend_docs
/**
 * Unique texture identifier implementation.
 * Represents a texture handle as an integer for efficient storage and comparison.
 * Used internally by the rendering system to reference textures.
 */
#end
abstract TextureIdImpl(Int) from Int to Int {

    #if !no_backend_docs
    /**
     * Default texture ID constant.
     * Represents an invalid or uninitialized texture.
     */
    #end
    #if !debug inline #end public static var DEFAULT:TextureId = 0;

}

package backend;

/**
 * Texture identifier type for the headless backend.
 * 
 * This provides a unique identifier for each texture instance.
 * Texture IDs are used to track and compare textures efficiently
 * without storing full texture references.
 * 
 * In headless mode, these IDs maintain the same uniqueness
 * guarantees as other backends for API compatibility.
 */
typedef TextureId = TextureIdImpl;

abstract TextureIdImpl(Int) from Int to Int {

    /**
     * Default texture ID used for uninitialized or invalid textures.
     */
    #if !debug inline #end public static var DEFAULT:TextureId = 0;

}

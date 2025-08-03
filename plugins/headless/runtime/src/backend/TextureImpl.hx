package backend;

#if !no_backend_docs
/**
 * Texture implementation for the headless backend.
 * 
 * This class represents a texture object in the headless environment.
 * Unlike other backends, this doesn't contain actual pixel data or
 * GPU texture handles. Instead, it maintains texture metadata like
 * dimensions and properties for API compatibility.
 * 
 * Each texture gets a unique ID that can be used for comparison
 * and tracking, just like in other backends.
 */
#end
class TextureImpl {
    #if !no_backend_docs
    /**
     * Static counter for generating unique texture IDs.
     */
    #end
    static var _nextTextureId:Int = 1;
    
    #if !no_backend_docs
    /**
     * Width of the texture in pixels.
     */
    #end
    public var width:Int = 0;
    
    #if !no_backend_docs
    /**
     * Height of the texture in pixels.
     */
    #end
    public var height:Int = 0;
    
    #if !no_backend_docs
    /**
     * Whether the texture has a depth buffer (for render targets).
     */
    #end
    public var depth:Bool = true;
    
    #if !no_backend_docs
    /**
     * Whether the texture has a stencil buffer (for render targets).
     */
    #end
    public var stencil:Bool = true;
    
    #if !no_backend_docs
    /**
     * Antialiasing level for the texture (for render targets).
     */
    #end
    public var antialiasing:Int = 0;
    
    #if !no_backend_docs
    /**
     * Unique identifier for this texture instance.
     */
    #end
    public var textureId:TextureId = 0;
    
    #if !no_backend_docs
    /**
     * Creates a new texture implementation with the specified properties.
     * 
     * @param width Texture width in pixels
     * @param height Texture height in pixels
     * @param depth Whether to include a depth buffer
     * @param stencil Whether to include a stencil buffer
     * @param antialiasing Antialiasing level (0 = none)
     */
    #end
    public function new(width:Int = 0, height:Int = 0, depth:Bool = true, stencil:Bool = true, antialiasing:Int = 0) {
        this.width = width;
        this.height = height;
        this.depth = depth;
        this.stencil = stencil;
        this.antialiasing = antialiasing;
        this.textureId = _nextTextureId++;
    }
}

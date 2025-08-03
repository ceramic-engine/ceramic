package backend;

import unityengine.RenderTexture;
import unityengine.Texture2D;

#if unity_6000
import unityengine.RTHandle;
#end

#if !no_backend_docs
/**
 * Concrete implementation of a Unity texture.
 * Wraps Unity's Texture2D or RenderTexture with additional metadata.
 * Supports both regular textures and render targets with optional depth buffers.
 */
#end
class TextureImpl {

    #if !no_backend_docs
    /**
     * Global counter for generating unique texture indices.
     */
    #end
    static var _nextIndex:Int = 1;

    #if !no_backend_docs
    /**
     * Unique index for this texture instance.
     * Used for internal tracking and debugging.
     */
    #end
    @:noCompletion
    public var index:Int = _nextIndex++;

    #if !no_backend_docs
    /**
     * Whether this texture is being used as a render target.
     * Affects how the texture is managed during rendering.
     */
    #end
    @:noCompletion
    public var usedAsRenderTarget:Bool = false;

    #if !no_backend_docs
    /**
     * Unity Texture2D reference for regular textures.
     * Null if this is a render texture.
     */
    #end
    public var unityTexture:Texture2D;

    #if !no_backend_docs
    /**
     * Unity RenderTexture reference for render targets.
     * Null if this is a regular texture.
     */
    #end
    public var unityRenderTexture:RenderTexture;

    #if !no_backend_docs
    /**
     * Unity 6 RTHandle for render texture management.
     * Provides better render texture lifecycle handling in Unity 6+.
     */
    #end
    #if unity_6000
    public var unityRtHandle:RTHandle;
    #end

    #if !no_backend_docs
    /**
     * Depth buffer components for render graph compatibility.
     * Required for advanced rendering features like shadows.
     */
    #end
    #if unity_rendergraph
    public var unityRenderTextureDepth:RenderTexture;
    public var unityRtHandleDepth:RTHandle;
    #end

    #if !no_backend_docs
    /**
     * Path to the texture resource.
     * Used for debugging and resource tracking.
     */
    #end
    public var path:String;

    #if !no_backend_docs
    /**
     * Unique texture identifier from Unity's instance ID.
     * Used for texture comparison and batching.
     */
    #end
    public var textureId:TextureId;

    #if !no_backend_docs
    /**
     * Texture width in pixels.
     */
    #end
    public var width(default,null):Int;

    #if !no_backend_docs
    /**
     * Texture height in pixels.
     */
    #end
    public var height(default,null):Int;

    #if !no_backend_docs
    /**
     * Creates a new texture implementation.
     * @param path Resource path for debugging
     * @param unityTexture Unity Texture2D (for regular textures)
     * @param unityRenderTexture Unity RenderTexture (for render targets)
     * @param unityRtHandle Unity 6 RTHandle (if available)
     * @param unityRenderTextureDepth Optional depth buffer for render graph
     * @param unityRtHandleDepth Optional depth RTHandle for render graph
     */
    #end
    public function new(path:String, unityTexture:Texture2D, unityRenderTexture:RenderTexture #if unity_6000 , unityRtHandle:RTHandle #end #if unity_rendergraph , ?unityRenderTextureDepth:RenderTexture, ?unityRtHandleDepth:RTHandle #end) {

        this.path = path;
        this.unityTexture = unityTexture;
        this.unityRenderTexture = unityRenderTexture;

        #if unity_6000
        this.unityRtHandle = unityRtHandle;
        #end

        #if unity_rendergraph
        this.unityRenderTextureDepth = unityRenderTextureDepth;
        this.unityRtHandleDepth = unityRtHandleDepth;
        #end

        if (unityTexture != null) {
            this.width = unityTexture.width;
            this.height = unityTexture.height;
            this.textureId = unityTexture.GetInstanceID();
        }
        else if (unityRenderTexture != null) {
            this.width = unityRenderTexture.width;
            this.height = unityRenderTexture.height;
            this.textureId = unityRenderTexture.GetInstanceID();
        }

    }

}

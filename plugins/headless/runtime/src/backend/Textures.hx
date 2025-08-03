package backend;

import ceramic.ImageType;
import haxe.io.Bytes;

/**
 * Texture management system for the headless backend.
 * 
 * This class implements the Ceramic texture specification but provides
 * mock functionality since no actual image data is loaded or processed
 * in headless mode. It creates texture objects with proper dimensions
 * and metadata for API compatibility.
 * 
 * All texture operations return valid objects and maintain state but
 * don't perform actual image loading, GPU uploading, or pixel processing.
 */
class Textures implements spec.Textures {

    /**
     * Creates a new headless texture management system.
     */
    public function new() {}

    /**
     * Loads a texture from the specified path.
     * 
     * In headless mode, this creates a mock texture without
     * loading any actual image data.
     * 
     * @param path Path to the image file (ignored in headless mode)
     * @param options Optional loading parameters (ignored in headless mode)
     * @param _done Callback function called with the loaded texture
     */
    public function load(path:String, ?options:LoadTextureOptions, _done:Texture->Void):Void {

        var done = function(texture:Texture) {
            ceramic.App.app.onceImmediate(function() {
                _done(texture);
                _done = null;
            });
        };

        done(new TextureImpl(0, 0));

    }

    /**
     * Loads a texture from raw image bytes.
     * 
     * In headless mode, this creates a mock texture without
     * processing the provided image data.
     * 
     * @param bytes Raw image data (ignored in headless mode)
     * @param type Image format type (ignored in headless mode)
     * @param options Optional loading parameters (ignored in headless mode)
     * @param _done Callback function called with the loaded texture
     */
    public function loadFromBytes(bytes:Bytes, type:ImageType, ?options:LoadTextureOptions, _done:Texture->Void):Void {

        var done = function(texture:Texture) {
            ceramic.App.app.onceImmediate(function() {
                _done(texture);
                _done = null;
            });
        };

        done(new TextureImpl(0, 0));

    }

    /**
     * Indicates whether this backend supports hot reloading of texture assets.
     * 
     * @return Always false for the headless backend
     */
    inline public function supportsHotReloadPath():Bool {

        return false;

    }

    /**
     * Creates a texture from raw pixel data.
     * 
     * @param width Texture width in pixels
     * @param height Texture height in pixels
     * @param pixels Raw pixel data (ignored in headless mode)
     * @return Always null in headless mode
     */
    public function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture {

        return null;

    }

    /**
     * Destroys a texture and frees its resources.
     * 
     * In headless mode, this is a no-op since no actual resources are allocated.
     * 
     * @param texture The texture to destroy
     */
    public function destroyTexture(texture:Texture):Void {

    }

    /**
     * Creates a render target texture with the specified properties.
     * 
     * In headless mode, this creates a texture object with the proper
     * dimensions and settings but no actual rendering surface.
     * 
     * @param width Render target width in pixels
     * @param height Render target height in pixels
     * @param depth Whether to include a depth buffer
     * @param stencil Whether to include a stencil buffer
     * @param antialiasing Antialiasing level (0 = none)
     * @return A mock render target texture
     */
    inline public function createRenderTarget(width:Int, height:Int, depth:Bool, stencil:Bool, antialiasing:Int):Texture {

        return new TextureImpl(width, height, depth, stencil, antialiasing);

    }

    /**
     * Destroys a texture and frees its resources.
     * 
     * In headless mode, this is a no-op since no actual resources are allocated.
     * 
     * @param texture The texture to destroy
     */
    public function destroy(texture:Texture):Void {

        //

    }

    inline public function getTextureId(texture:Texture):backend.TextureId {

        return (texture:TextureImpl).textureId;

    }

    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function getTextureWidthActual(texture:Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeightActual(texture:Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array {

        return null;

    }

    inline public function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void {

    }

    inline public function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void {

        //

    }

    inline public function setTextureWrapS(texture:Texture, wrap:ceramic.TextureWrap): Void {

        //

    }

    inline public function setTextureWrapT(texture:Texture, wrap:ceramic.TextureWrap): Void {

        //

    }

    /**
     * Gets the maximum number of textures that can be used in a single batch.
     * 
     * @return Always 1 in headless mode since no actual batching occurs
     */
    public function maxTexturesByBatch():Int {

        return 1;

    }

    /**
     * Gets the texture index for batched rendering.
     * 
     * @param texture The texture to get the index for
     * @return Always -1 in headless mode since no batching occurs
     */
    inline public function getTextureIndex(texture:Texture):Int {

        return -1;

    }

    /**
     * Exports a texture to PNG format.
     * 
     * @param texture The texture to export
     * @param reversePremultiplyAlpha Whether to reverse premultiplied alpha
     * @param path Optional file path to save to
     * @param done Callback called with the PNG data (always null in headless mode)
     */
    public function textureToPng(texture:Texture, reversePremultiplyAlpha:Bool = true, ?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    /**
     * Exports raw pixel data to PNG format.
     * 
     * @param width Image width in pixels
     * @param height Image height in pixels
     * @param pixels Raw pixel data
     * @param path Optional file path to save to
     * @param done Callback called with the PNG data (always null in headless mode)
     */
    public function pixelsToPng(width:Int, height:Int, pixels:ceramic.UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

}
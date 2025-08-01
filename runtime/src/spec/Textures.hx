package spec;

import backend.LoadTextureOptions;
import backend.Texture;
import ceramic.ImageType;
import haxe.io.Bytes;

/**
 * Backend interface for texture (image) management and GPU operations.
 * 
 * This interface handles loading images, creating textures, managing GPU texture
 * memory, and configuring texture properties. Textures are the primary way to
 * display images and render targets in Ceramic.
 * 
 * Textures can be created from:
 * - Image files (PNG, JPEG, etc.)
 * - Raw pixel data
 * - Render targets for off-screen rendering
 * 
 * The interface supports various texture operations including filtering modes,
 * wrapping modes, pixel access, and PNG export.
 */
interface Textures {

    /**
     * Loads a texture from an image file.
     * 
     * Supported formats depend on the backend but typically include PNG, JPEG,
     * and sometimes GIF or WebP. The image is uploaded to GPU memory as a texture.
     * 
     * @param path The path to the image file (relative to assets)
     * @param options Optional loading configuration (filtering, density, etc.)
     * @param done Callback invoked with the loaded texture or null on failure
     */
    function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void;

    /**
     * Creates a texture from image data in memory.
     * 
     * This allows creating textures from downloaded or generated image data
     * without writing to disk first.
     * 
     * @param bytes The raw image file data
     * @param type The image format (PNG, JPEG, etc.)
     * @param options Optional loading configuration
     * @param done Callback invoked with the created texture or null on failure
     */
    function loadFromBytes(bytes:Bytes, type:ImageType, ?options:LoadTextureOptions, done:Texture->Void):Void;

/// Textures

    /**
     * Checks if the backend supports hot-reloading of texture files.
     * 
     * When true, textures can include a `?hot=timestamp` query parameter to
     * bypass caching and force reloading when the image changes during development.
     * 
     * @return True if hot-reload paths are supported, false otherwise
     */
    function supportsHotReloadPath():Bool;

    /**
     * Creates a texture from raw pixel data.
     * 
     * Pixels should be provided as RGBA bytes (4 bytes per pixel) in row-major order.
     * The texture is immediately uploaded to GPU memory.
     * 
     * @param width The texture width in pixels
     * @param height The texture height in pixels
     * @param pixels The raw RGBA pixel data (width * height * 4 bytes)
     * @return The created texture
     */
    function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture;

    /**
     * Destroys a texture and frees its GPU memory.
     * 
     * After calling this, the texture should not be used for rendering.
     * This is automatically called when a Texture object is destroyed.
     * 
     * @param texture The texture to destroy
     */
    function destroyTexture(texture:Texture):Void;

    /**
     * Gets the unique identifier for a texture.
     * 
     * This ID is used internally for texture state tracking and batching.
     * 
     * @param texture The texture to query
     * @return The texture's unique identifier
     */
    function getTextureId(texture:Texture):backend.TextureId;

    /**
     * Gets the logical width of a texture.
     * 
     * This is the usable width, which may be smaller than the actual GPU texture
     * if the backend uses power-of-two padding.
     * 
     * @param texture The texture to query
     * @return The logical width in pixels
     */
    function getTextureWidth(texture:Texture):Int;

    /**
     * Gets the logical height of a texture.
     * 
     * This is the usable height, which may be smaller than the actual GPU texture
     * if the backend uses power-of-two padding.
     * 
     * @param texture The texture to query
     * @return The logical height in pixels
     */
    function getTextureHeight(texture:Texture):Int;

    /**
     * Gets the actual GPU texture width.
     * 
     * This may be larger than the logical width if the backend pads textures
     * to power-of-two dimensions for older GPU compatibility.
     * 
     * @param texture The texture to query
     * @return The actual GPU texture width in pixels
     */
    function getTextureWidthActual(texture:Texture):Int;

    /**
     * Gets the actual GPU texture height.
     * 
     * This may be larger than the logical height if the backend pads textures
     * to power-of-two dimensions for older GPU compatibility.
     * 
     * @param texture The texture to query
     * @return The actual GPU texture height in pixels
     */
    function getTextureHeightActual(texture:Texture):Int;

    /**
     * Fetches pixel data from a texture.
     * 
     * This downloads the texture from GPU memory to CPU memory. The operation
     * may be slow and should be used sparingly. Pixels are returned as RGBA bytes.
     * 
     * @param texture The texture to read from
     * @param result Optional array to store results (must be width*height*4 bytes)
     * @return Array containing RGBA pixel data
     */
    function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array;

    /**
     * Updates a texture with new pixel data.
     * 
     * This uploads new pixel data to an existing texture on the GPU.
     * The pixel array must match the texture's dimensions (width*height*4 bytes).
     * 
     * @param texture The texture to update
     * @param pixels The new RGBA pixel data
     */
    function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void;

    /**
     * Sets the filtering mode for a texture.
     * 
     * Filtering determines how pixels are sampled when the texture is scaled:
     * - LINEAR: Smooth interpolation (good for photos)
     * - NEAREST: No interpolation (good for pixel art)
     * 
     * @param texture The texture to configure
     * @param filter The filtering mode to apply
     */
    function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void;

    /**
     * Sets the horizontal (S/U axis) wrapping mode for a texture.
     * 
     * Wrapping determines what happens when texture coordinates exceed 0-1:
     * - CLAMP: Clamps to edge pixels
     * - REPEAT: Tiles the texture
     * - MIRROR: Tiles with alternating mirrored copies
     * 
     * @param texture The texture to configure
     * @param wrap The wrapping mode for the S (horizontal) axis
     */
    function setTextureWrapS(texture: Texture, wrap: ceramic.TextureWrap):Void;

    /**
     * Sets the vertical (T/V axis) wrapping mode for a texture.
     * 
     * Wrapping determines what happens when texture coordinates exceed 0-1:
     * - CLAMP: Clamps to edge pixels
     * - REPEAT: Tiles the texture
     * - MIRROR: Tiles with alternating mirrored copies
     * 
     * @param texture The texture to configure
     * @param wrap The wrapping mode for the T (vertical) axis
     */
    function setTextureWrapT(texture: Texture, wrap: ceramic.TextureWrap):Void;

    /**
     * Creates a render target texture for off-screen rendering.
     * 
     * Render targets allow rendering to a texture instead of the screen.
     * This is used for post-processing effects, render-to-texture, and more.
     * 
     * @param width The render target width in pixels
     * @param height The render target height in pixels
     * @param depth Whether to include a depth buffer
     * @param stencil Whether to include a stencil buffer
     * @param antialiasing MSAA sample count (0 or 1 for no antialiasing)
     * @return The created render target texture
     */
    function createRenderTarget(width:Int, height:Int, depth:Bool, stencil:Bool, antialiasing:Int):Texture;

    /**
     * Gets the maximum number of textures that can be used in a single draw call.
     * 
     * If this returns a value above 1, the backend supports multi-texture batching,
     * which can significantly improve performance by reducing draw calls.
     * 
     * @return Maximum textures per batch (1 if multi-texturing is not supported)
     */
    function maxTexturesByBatch():Int;

    /**
     * Gets the texture slot index for multi-texture batching.
     * 
     * When using multi-texture batching, each texture is assigned to a slot
     * (0 to maxTexturesByBatch-1). This index is used in shader texture arrays.
     * 
     * @param texture The texture to query
     * @return The texture's slot index for the current batch
     */
    function getTextureIndex(texture:Texture):Int;

    /**
     * Exports a texture to PNG format.
     * 
     * This is useful for debugging, screenshots, or saving generated textures.
     * 
     * @param texture The texture to export
     * @param reversePremultiplyAlpha Whether to reverse premultiplied alpha (usually true)
     * @param path Optional file path to save the PNG
     * @param done Callback with PNG data bytes (null on error)
     */
    function textureToPng(texture:Texture, reversePremultiplyAlpha:Bool = true, ?path:String, done:(?data:Bytes)->Void):Void;

    /**
     * Converts raw pixel data to PNG format.
     * 
     * @param width Image width in pixels
     * @param height Image height in pixels
     * @param pixels RGBA pixel data (width * height * 4 bytes)
     * @param path Optional file path to save the PNG
     * @param done Callback with PNG data bytes (null on error)
     */
    function pixelsToPng(width:Int, height:Int, pixels:ceramic.UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void;

}

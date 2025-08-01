package ceramic;

import backend.LoadTextureOptions;
import ceramic.Assets;
import ceramic.Shortcuts.*;
import haxe.io.Bytes;

using StringTools;
using ceramic.Extensions;

/**
 * A texture represents an image loaded in GPU memory ready for rendering.
 * 
 * Textures are the foundation for displaying images in Ceramic. They can be:
 * - Loaded from image files (PNG, JPG, etc.)
 * - Created from pixel data
 * - Generated as render targets
 * - Extracted from texture atlases
 * 
 * Features:
 * - Automatic density handling for different screen resolutions
 * - Filtering modes (NEAREST for pixel art, LINEAR for smooth scaling)
 * - Wrap modes for texture coordinates outside 0-1 range
 * - Reference counting through asset management
 * - Automatic cleanup when destroyed
 * 
 * Textures are typically obtained through asset loading rather than
 * created directly:
 * 
 * @example
 * ```haxe
 * // Load texture through assets
 * var texture = assets.texture('hero');
 * 
 * // Apply to a quad
 * var quad = new Quad();
 * quad.texture = texture;
 * 
 * // Configure for pixel art
 * texture.filter = NEAREST;
 * 
 * // Create texture from pixels
 * var pixels = Pixels.create(100, 100, Color.RED);
 * var texture = Texture.fromPixels(pixels);
 * ```
 * 
 * @see ImageAsset
 * @see Quad
 * @see TextureAtlas
 */
class Texture extends Entity {

/// Internal

    static var _nextIndex:Int = 1;

    @:noCompletion
    public var index:Int = _nextIndex++;

    /**
     * Whether this texture is a render target.
     * Render textures can be drawn to using RenderTexture class.
     */
    public var isRenderTexture(default,null):Bool = false;

    /**
     * If this is a render texture, returns the RenderTexture instance.
     * Otherwise null.
     */
    public var asRenderTexture(default,null):RenderTexture = null;

/// Properties

    /**
     * The texture ID used by the underlying graphics API (OpenGL, etc.).
     * This is backend-specific and mainly used for debugging or advanced usage.
     */
    public var textureId(get,never):backend.TextureId;
    inline function get_textureId():backend.TextureId {
        return app.backend.textures.getTextureId(backendItem);
    }

    /**
     * The native pixel width of the texture in GPU memory.
     * This is the actual texture size, not affected by density scaling.
     */
    public var nativeWidth(get,never):Int;
    inline function get_nativeWidth():Int {
        return app.backend.textures.getTextureWidth(backendItem);
    }

    /**
     * The native pixel height of the texture in GPU memory.
     * This is the actual texture size, not affected by density scaling.
     */
    public var nativeHeight(get,never):Int;
    inline function get_nativeHeight():Int {
        return app.backend.textures.getTextureHeight(backendItem);
    }

    /**
     * The actual allocated width of the texture in GPU memory.
     * May be larger than nativeWidth if the backend requires power-of-two dimensions.
     * Use this for advanced texture coordinate calculations.
     */
    public var nativeWidthActual(get,never):Int;
    inline function get_nativeWidthActual():Int {
        return app.backend.textures.getTextureWidthActual(backendItem);
    }

    /**
     * The actual allocated height of the texture in GPU memory.
     * May be larger than nativeHeight if the backend requires power-of-two dimensions.
     * Use this for advanced texture coordinate calculations.
     */
    public var nativeHeightActual(get,never):Int;
    inline function get_nativeHeightActual():Int {
        return app.backend.textures.getTextureHeightActual(backendItem);
    }

    /**
     * The logical width of the texture after density scaling.
     * This is what you use for positioning and sizing visuals.
     * Calculated as: nativeWidth / density
     */
    public var width(default,null):Float;

    /**
     * The logical height of the texture after density scaling.
     * This is what you use for positioning and sizing visuals.
     * Calculated as: nativeHeight / density
     */
    public var height(default,null):Float;

    /**
     * The texture density (scale factor).
     * Used for supporting different screen resolutions:
     * - 1.0 = standard resolution
     * - 2.0 = retina/high-dpi (@2x assets)
     * - 3.0 = extra high density (@3x assets)
     * Changing this updates width/height accordingly.
     */
    public var density(default,set):Float;
    function set_density(density:Float):Float {
        if (this.density == density) return density;
        this.density = density;
        width = app.backend.textures.getTextureWidth(backendItem) / density;
        height = app.backend.textures.getTextureHeight(backendItem) / density;
        return density;
    }

    /**
     * The texture filtering mode.
     * - LINEAR: Smooth interpolation (default, good for photos)
     * - NEAREST: No interpolation (good for pixel art)
     * Change this based on your art style and scaling needs.
     */
    public var filter(default,set):TextureFilter = LINEAR;
    function set_filter(filter:TextureFilter):TextureFilter {
        if (this.filter == filter) return filter;
        this.filter = filter;
        app.backend.textures.setTextureFilter(backendItem, filter);
        return filter;
    }

    /**
     * Horizontal texture wrap mode for UV coordinates outside 0-1 range.
     * - CLAMP: Clamp to edge pixels (default)
     * - REPEAT: Tile the texture
     * - MIRROR: Tile with alternating mirrors
     */
    public var wrapS(default,set):TextureWrap = CLAMP;
    function set_wrapS(wrapS:TextureWrap):TextureWrap {
        if (this.wrapS == wrapS) return wrapS;
        this.wrapS = wrapS;
        app.backend.textures.setTextureWrapS(backendItem, wrapS);
        return wrapS;
    }

    /**
     * Vertical texture wrap mode for UV coordinates outside 0-1 range.
     * - CLAMP: Clamp to edge pixels (default)
     * - REPEAT: Tile the texture
     * - MIRROR: Tile with alternating mirrors
     */
    public var wrapT(default,set):TextureWrap = CLAMP;
    function set_wrapT(wrapT:TextureWrap):TextureWrap {
        if (this.wrapT == wrapT) return wrapT;
        this.wrapT = wrapT;
        app.backend.textures.setTextureWrapT(backendItem, wrapT);
        return wrapT;
    }

    /**
     * Shorthand for setting both wrapS and wrapT at the same time.
     * Possible values: `CLAMP`, `REPEAT`, `MIRROR`
     * @param wrapS horizontal wrap mode
     * @param wrapT vertical wrap mode
     */
    public function setWrap(wrapS:TextureWrap, ?wrapT:TextureWrap):Void {
        set_wrapS(wrapS);
        if(wrapT != null)
            set_wrapT(wrapT);
    }

    /**
     * The backend-specific texture resource.
     * This is managed internally by Ceramic.
     */
    public var backendItem:backend.Texture;

    /**
     * The image asset this texture was loaded from, if any.
     * Automatically destroyed when the texture is destroyed.
     */
    public var asset:ImageAsset = null;

/// Lifecycle

    /**
     * Create a new texture from raw pixel data.
     * Useful for procedural texture generation or image manipulation.
     * @param width Width of the texture in logical units
     * @param height Height of the texture in logical units
     * @param pixels Pixel buffer in RGBA format (4 bytes per pixel)
     * @param density Texture density/scale (default: 1.0)
     * @return A new Texture instance
     * @example
     * ```haxe
     * var pixels = new UInt8Array(100 * 100 * 4);
     * // Fill with red color
     * for (i in 0...100*100) {
     *     pixels[i*4] = 255;     // R
     *     pixels[i*4+1] = 0;     // G
     *     pixels[i*4+2] = 0;     // B
     *     pixels[i*4+3] = 255;   // A
     * }
     * var texture = Texture.fromPixels(100, 100, pixels);
     * ```
     */
    public static function fromPixels(width:Float, height:Float, pixels:ceramic.UInt8Array, density:Float = 1):Texture {

        var backendItem = app.backend.textures.createTexture(Math.round(width * density), Math.round(height * density), pixels);
        return new Texture(backendItem, density);

    }

    /**
     * Create a new texture from PNG or JPEG data.
     * Asynchronously decodes the image data and creates a texture.
     * @param bytes The PNG or JPEG data as bytes
     * @param density Texture density/scale (default: 1.0)
     * @param options Additional loading options (backend-specific)
     * @param done Callback receiving the loaded texture, or null if it failed
     * @example
     * ```haxe
     * var imageBytes = Files.getBytes('custom.png');
     * Texture.fromBytes(imageBytes, 1.0, null, texture -> {
     *     if (texture != null) {
     *         quad.texture = texture;
     *     }
     * });
     * ```
     */
    public static function fromBytes(bytes:Bytes, density:Float = 1, ?options:LoadTextureOptions, done:(texture:Texture)->Void):Void {

        app.backend.textures.loadFromBytes(bytes, Utils.imageTypeFromBytes(bytes), options, backendItem -> {
            done(new Texture(backendItem, density));
        });

    }

    /**
     * Create a new Texture from a backend texture resource.
     * Usually you don't call this directly - use asset loading or fromPixels/fromBytes.
     * @param backendItem The backend texture resource
     * @param density Texture density (-1 uses screen density)
     */
    public function new(backendItem:backend.Texture, density:Float = -1 #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        if (density == -1) density = screen.texturesDensity;

        this.backendItem = backendItem;
        this.density = density; // sets widht/height as well

    }

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        app.backend.textures.destroyTexture(backendItem);
        backendItem = null;

    }

/// Pixels

    /**
     * Fetch the current pixel data from this texture.
     * Reads pixels from GPU memory (can be slow).
     * @param result Optional array to store results (will be allocated if null)
     * @return Array containing RGBA pixel data
     */
    public function fetchPixels(?result:ceramic.UInt8Array):ceramic.UInt8Array {

        return app.backend.textures.fetchTexturePixels(backendItem, result);

    }

    /**
     * Update this texture with new pixel data.
     * Uploads pixels to GPU memory.
     * The pixel array must match the texture's dimensions.
     * @param pixels RGBA pixel data to upload
     */
    public function submitPixels(pixels:ceramic.UInt8Array):Void {

        app.backend.textures.submitTexturePixels(backendItem, pixels);

    }

/// PNG

    /**
     * Export texture as PNG data and save it to the given file path.
     * Useful for screenshots or texture debugging.
     * @param path The png file path where to save the image (`'/path/to/image.png'`)
     * @param done Called when the png has been exported
     */
    inline extern overload public function toPng(path:String, reversePremultiplyAlpha:Bool = true, done:()->Void):Void {
        _toPng(path, reversePremultiplyAlpha, (?data) -> {
            done();
        });
    }

    /**
     * Export texture to PNG data/bytes
     * @param done Called when the png has been exported, with `data` containing PNG bytes
     */
    inline extern overload public function toPng(reversePremultiplyAlpha:Bool = true, done:(data:Bytes)->Void):Void {
        _toPng(null, reversePremultiplyAlpha, (?data) -> {
            done(data);
        });
    }

    function _toPng(?path:String, reversePremultiplyAlpha:Bool = true, done:(?data:Bytes)->Void):Void {

        app.backend.textures.textureToPng(backendItem, reversePremultiplyAlpha, path, done);

    }

/// Print

    override function toString():String {

        if (id != null) {
            var name = id;
            if (name.startsWith('texture:')) name = name.substr(8);
            return 'Texture($name $width $height $density #$index)';
        } else {
            return 'Texture($width $height $density #$index)';
        }

    }

}

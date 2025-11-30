package backend;

import ceramic.Files;
import ceramic.ImageType;
import ceramic.Path;
import ceramic.Utils;
import clay.Clay;
import clay.Immediate;
import haxe.io.Bytes;

using StringTools;

/**
 * Clay backend implementation of texture management.
 * Handles loading, creating, and managing GPU textures with reference counting.
 * 
 * Features:
 * - Automatic texture caching and reference counting
 * - Support for loading from files, URLs, or raw bytes
 * - Render texture creation for off-screen rendering
 * - Texture filtering and wrapping configuration
 * - PNG export functionality
 * - Multi-texture batching support
 * 
 * The class maintains a cache of loaded textures to avoid duplicate loads
 * and uses reference counting to manage texture lifetime.
 * 
 * @see ceramic.Texture
 * @see clay.graphics.Texture
 */
class Textures implements spec.Textures {

    public function new() {}

    /**
     * Loads a texture from a file path or URL.
     * Implements automatic caching and reference counting to avoid duplicate loads.
     * 
     * Features:
     * - Supports both local files and HTTP(S) URLs
     * - Automatic texture caching with reference counting
     * - Synchronous or asynchronous loading
     * - Optional alpha premultiplication
     * - Queues callbacks if texture is already loading
     * 
     * @param path File path (relative to assets) or URL to load
     * @param options Loading options (sync/async, premultiply alpha, etc.)
     * @param _done Callback when texture is loaded or failed (null on failure)
     */
    public function load(path:String, ?options:backend.LoadTextureOptions, _done:Texture->Void):Void {

        var synchronous = options != null && options.loadMethod == SYNC;
        var immediate = options != null ? options.immediate : null;
        var done = function(texture:Texture) {
            final fn = function() {
                _done(texture);
                _done = null;
            };
            if (immediate != null)
                immediate.push(fn);
            else
                ceramic.App.app.onceImmediate(fn);
        };

        var isUrl:Bool = path.startsWith('http://') || path.startsWith('https://');
        path = Path.isAbsolute(path) || isUrl ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        // Is texture already loaded?
        if (loadedTextures.exists(path)) {
            loadedTexturesRetainCount.set(path, loadedTexturesRetainCount.get(path) + 1);
            var existing = loadedTextures.get(path);
            done(existing);
            return;
        }

        // Is texture currently loading?
        if (loadingTextureCallbacks.exists(path)) {
            // Yes, just bind it
            loadingTextureCallbacks.get(path).push(function(texture:Texture) {
                if (texture != null) {
                    var retain = loadedTexturesRetainCount.exists(path) ? loadedTexturesRetainCount.get(path) : 0;
                    loadedTexturesRetainCount.set(path, retain + 1);
                }
                done(texture);
            });
            return;
        }

        // Remove ?something in path
        var cleanedPath = path;
        if (!isUrl) {
            var questionMarkIndex = cleanedPath.indexOf('?');
            if (questionMarkIndex != -1) {
                cleanedPath = cleanedPath.substr(0, questionMarkIndex);
            }
        }

        // Create callbacks list with first entry
        loadingTextureCallbacks.set(path, [function(texture:Texture) {
            if (texture != null) {
                var retain = loadedTexturesRetainCount.exists(path) ? loadedTexturesRetainCount.get(path) : 0;
                loadedTexturesRetainCount.set(path, retain + 1);
            }
            done(texture);
        }]);

        var fullPath = isUrl ? cleanedPath : Clay.app.assets.fullPath(cleanedPath);
        var premultiplyAlpha:Bool = #if web true #else false #end;
        if (options != null && options.premultiplyAlpha != null) {
            premultiplyAlpha = options.premultiplyAlpha;
        }

        function doFail() {

            var callbacks = loadingTextureCallbacks.get(path);
            loadingTextureCallbacks.remove(path);
            for (callback in callbacks) {
                try {
                    callback(null);
                }
                catch (e:Dynamic) {
                    ceramic.App.app.onceImmediate(() -> {
                        throw e;
                    });
                }
            }

        }

        // Load image
        Clay.app.assets.loadImage(fullPath, !synchronous, function(image:clay.Image) {

            if (image == null) {
                doFail();
                return;
            }

            // Transform image into texture
            var texture:clay.graphics.Texture = null;
            try {
                texture = clay.graphics.Texture.fromImage(image, premultiplyAlpha);
                if (texture == null) {
                    doFail();
                    return;
                }
                texture.id = path;
                texture.init();
            }
            catch (e:Dynamic) {
                ceramic.Shortcuts.log.error('Failed to create texture: ' + e);
                doFail();
                return;
            }

            // Load seems successful, keep texture
            loadedTextures.set(path, texture);
            var callbacks = loadingTextureCallbacks.get(path);
            loadingTextureCallbacks.remove(path);
            for (callback in callbacks) {
                try {
                    callback(texture);
                }
                catch (e:Dynamic) {
                    ceramic.App.app.onceImmediate(() -> {
                        throw e;
                    });
                }
            }

        });

        // Needed to ensure a synchronous load will be done before the end of the frame
        if (immediate != null) {
            immediate.push(Immediate.flush);
        }
        else {
            ceramic.App.app.onceImmediate(Immediate.flush);
        }

    }

    /**
     * Creates a texture from raw image bytes.
     * Useful for dynamically generated images or data loaded from custom sources.
     * 
     * @param bytes Raw image data
     * @param type Image format (PNG, JPEG, GIF)
     * @param options Loading options (sync/async, premultiply alpha)
     * @param _done Callback when texture is created or failed (null on failure)
     */
    public function loadFromBytes(bytes:Bytes, type:ImageType, ?options:LoadTextureOptions, _done:Texture->Void):Void {

        var id = 'bytes:' + (nextBytesIndex++);

        var synchronous = options != null && options.loadMethod == SYNC;
        var immediate = options != null ? options.immediate : null;
        var done = function(texture:Texture) {
            final fn = function() {
                _done(texture);
                _done = null;
            };
            if (immediate != null)
                immediate.push(fn);
            else
                ceramic.App.app.onceImmediate(fn);
        };

        var premultiplyAlpha:Bool = #if web true #else false #end;
        if (options != null && options.premultiplyAlpha != null) {
            premultiplyAlpha = options.premultiplyAlpha;
        }

        inline function doFail() {
            done(null);
        }

        // Load image
        Clay.app.assets.imageFromBytes(clay.buffers.Uint8Array.fromBytes(bytes) #if web , type #else , !synchronous #end , function(image:clay.Image) {

            if (image == null) {
                doFail();
                return;
            }

            // Transform image into texture
            var texture:clay.graphics.Texture = null;
            try {
                texture = clay.graphics.Texture.fromImage(image, premultiplyAlpha);
                if (texture == null) {
                    doFail();
                    return;
                }
                texture.id = id;
                texture.init();
            }
            catch (e:Dynamic) {
                ceramic.Shortcuts.log.error('Failed to create texture: ' + e);
                doFail();
                return;
            }

            // Load seems successful, keep texture
            loadedTexturesRetainCount.set(id, 1);
            done(texture);

        });

        // Needed to ensure a synchronous load will be done before the end of the frame
        if (immediate != null) {
            immediate.push(Immediate.flush);
        }
        else {
            ceramic.App.app.onceImmediate(Immediate.flush);
        }

    }

    /**
     * Indicates whether hot-reloading of texture files is supported.
     * Clay backend supports watching texture files for changes.
     * 
     * @return Always returns true for Clay backend
     */
    inline public function supportsHotReloadPath():Bool {

        return true;

    }

    /** Counter for unique render texture IDs */
    var nextRenderIndex:Int = 0;

    /** Counter for unique pixel texture IDs */
    var nextPixelsIndex:Int = 0;

    /** Counter for unique byte-loaded texture IDs */
    var nextBytesIndex:Int = 0;

    /**
     * Creates a texture from raw pixel data.
     * The pixels should be in RGBA format with 8 bits per channel.
     * 
     * @param width Texture width in pixels
     * @param height Texture height in pixels
     * @param pixels Raw RGBA pixel data (width * height * 4 bytes)
     * @return Created texture with reference count of 1
     */
    public function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture {

        var id = 'pixels:' + (nextPixelsIndex++);

        var texture = new clay.graphics.Texture();
        texture.id = id;
        texture.width = width;
        texture.height = height;
        texture.pixels = pixels;
        texture.init();

        loadedTexturesRetainCount.set(id, 1);

        return texture;

    }

    /**
     * Creates a render texture for off-screen rendering.
     * Render textures can be used as drawing targets for post-processing effects.
     * 
     * @param width Texture width in pixels
     * @param height Texture height in pixels
     * @param depth Whether to create a depth buffer
     * @param stencil Whether to create a stencil buffer
     * @param antialiasing Antialiasing samples (0 = disabled, WebGL2+ required on web)
     * @return Created render texture with reference count of 1
     */
    inline public function createRenderTarget(width:Int, height:Int, depth:Bool, stencil:Bool, antialiasing:Int):Texture {

        var id = 'render:' + (nextRenderIndex++);

        #if web
        var webglVersion = clay.Clay.app.runtime.webglVersion;
        #end

        var renderTexture = new clay.graphics.RenderTexture();
        renderTexture.id = id;
        renderTexture.width = width;
        renderTexture.height = height;
        renderTexture.depth = depth;
        renderTexture.stencil = stencil;
        #if web
        // On web, render texture antialiasing is only supported on WebGL 2.0+
        renderTexture.antialiasing = webglVersion >= 2 ? antialiasing : 0;
        #else
        renderTexture.antialiasing = antialiasing;
        #end
        renderTexture.init();

        loadedTexturesRetainCount.set(id, 1);

        return renderTexture;

    }

    /**
     * Reads pixel data from a texture.
     * Retrieves the current pixel contents from GPU memory.
     * 
     * @param texture The texture to read from
     * @param result Optional array to store results (created if null)
     * @return Array containing RGBA pixel data
     */
    public function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array {

        var w = (texture:clay.graphics.Texture).width;
        var h = (texture:clay.graphics.Texture).height;

        if (result == null) {
            result = new ceramic.UInt8Array(w * h * 4);
        }

        (texture:clay.graphics.Texture).fetch(result);

        return result;

    }

    /**
     * Updates texture pixels on the GPU.
     * Uploads new pixel data to an existing texture.
     * 
     * @param texture The texture to update
     * @param pixels New RGBA pixel data (must match texture dimensions)
     */
    public function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void {

        (texture:clay.graphics.Texture).submit(pixels);

    }

    /**
     * Destroys a texture and releases GPU resources.
     * Decrements reference count and only destroys when count reaches zero.
     * 
     * @param texture The texture to destroy
     */
    public function destroyTexture(texture:Texture):Void {

        var id = (texture:clay.graphics.Texture).id;

        if (loadedTexturesRetainCount.get(id) > 1) {
            loadedTexturesRetainCount.set(id, loadedTexturesRetainCount.get(id) - 1);
        }
        else {
            loadedTextures.remove(id);
            loadedTexturesRetainCount.remove(id);
            (texture:clay.graphics.Texture).destroy();
        }

    }

    /**
     * Gets the GPU texture ID.
     * @param texture The texture
     * @return OpenGL texture ID
     */
    inline public function getTextureId(texture:Texture):backend.TextureId {

        return (texture:clay.graphics.Texture).textureId;

    }

    /**
     * Gets the texture width in pixels.
     * @param texture The texture
     * @return Width in pixels
     */
    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:clay.graphics.Texture).width;

    }

    /**
     * Gets the texture height in pixels.
     * @param texture The texture
     * @return Height in pixels
     */
    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:clay.graphics.Texture).height;

    }

    /**
     * Gets the actual texture width on GPU (may be power of 2).
     * @param texture The texture
     * @return Actual width in GPU memory
     */
    inline public function getTextureWidthActual(texture:Texture):Int {

        return (texture:clay.graphics.Texture).widthActual;

    }

    /**
     * Gets the actual texture height on GPU (may be power of 2).
     * @param texture The texture
     * @return Actual height in GPU memory
     */
    inline public function getTextureHeightActual(texture:Texture):Int {

        return (texture:clay.graphics.Texture).heightActual;

    }

    /**
     * Gets the texture index for multi-texture batching.
     * @param texture The texture
     * @return Texture slot index
     */
    inline public function getTextureIndex(texture:Texture):Int {

        return (texture:clay.graphics.Texture).index;

    }

    /**
     * Sets the texture filtering mode.
     * LINEAR provides smooth interpolation, NEAREST provides pixelated look.
     * 
     * @param texture The texture to configure
     * @param filter Filter mode (LINEAR or NEAREST)
     */
    inline public function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void {

        switch (filter) {
            case LINEAR:
                (texture:clay.graphics.Texture).filterMin = LINEAR;
                (texture:clay.graphics.Texture).filterMag = LINEAR;
            case NEAREST:
                (texture:clay.graphics.Texture).filterMin = NEAREST;
                (texture:clay.graphics.Texture).filterMag = NEAREST;
        }

    }

    /**
     * Sets the horizontal texture wrapping mode.
     * Controls how the texture repeats or clamps at U coordinates outside 0-1.
     * 
     * @param texture The texture to configure
     * @param wrap Wrap mode (CLAMP, REPEAT, or MIRROR)
     */
    inline public function setTextureWrapS(texture:Texture, wrap:ceramic.TextureWrap): Void {

            switch (wrap) {
                case CLAMP:
                    (texture: clay.graphics.Texture).wrapS = CLAMP_TO_EDGE;
                case REPEAT:
                    (texture: clay.graphics.Texture).wrapS = REPEAT;
                case MIRROR:
                    (texture: clay.graphics.Texture).wrapS = MIRRORED_REPEAT;
            }

    }

    /**
     * Sets the vertical texture wrapping mode.
     * Controls how the texture repeats or clamps at V coordinates outside 0-1.
     * 
     * @param texture The texture to configure
     * @param wrap Wrap mode (CLAMP, REPEAT, or MIRROR)
     */
    inline public function setTextureWrapT(texture:Texture, wrap:ceramic.TextureWrap): Void {

            switch (wrap) {
                case CLAMP:
                    (texture: clay.graphics.Texture).wrapT = CLAMP_TO_EDGE;
                case REPEAT:
                    (texture: clay.graphics.Texture).wrapT = REPEAT;
                case MIRROR:
                    (texture: clay.graphics.Texture).wrapT = MIRRORED_REPEAT;
            }

    }

    /** Cached maximum texture size */
    static var _maxTextureSize:Int = -1;

    /** Cached maximum textures per batch */
    static var _maxTexturesByBatch:Int = -1;

    /**
     * Queries GPU for maximum texture size if not already cached.
     * @private
     */
    inline static function computeMaxTextureSizeIfNeeded() {
        if (_maxTextureSize == -1) {
            _maxTextureSize = Clay.app.graphics.getMaxTextureSize();
        }
    }

    /**
     * Returns the maximum texture width supported by the GPU.
     * @return Maximum width in pixels
     */
    public function maxTextureWidth():Int {
        computeMaxTextureSizeIfNeeded();
        return _maxTextureSize;
    }

    /**
     * Returns the maximum texture height supported by the GPU.
     * @return Maximum height in pixels
     */
    public function maxTextureHeight():Int {
        computeMaxTextureSizeIfNeeded();
        return _maxTextureSize;
    }

    /**
     * Queries GPU for maximum texture units if not already cached.
     * @private
     */
    inline static function computeMaxTexturesByBatchIfNeeded() {
        if (_maxTexturesByBatch == -1) {
            _maxTexturesByBatch = Clay.app.graphics.getMaxTextureUnits();
        }
    }

    /**
     * Returns the maximum number of textures that can be used in a single batch.
     * Values above 1 indicate multi-texture batching support for improved performance.
     *
     * @return Maximum texture units (capped at 32)
     */
    public function maxTexturesByBatch():Int {
        computeMaxTexturesByBatchIfNeeded();
        return _maxTexturesByBatch;
    }

    #if cpp

    /**
     * Exports a texture to PNG format.
     * Native implementation using STB image write.
     * 
     * @param texture The texture to export
     * @param reversePremultiplyAlpha Whether to reverse premultiplied alpha
     * @param path Optional file path to save to (returns bytes if null)
     * @param done Callback with PNG data bytes (null if path provided)
     */
    public function textureToPng(texture:Texture, reversePremultiplyAlpha:Bool = true, ?path:String, done:(?data:Bytes)->Void):Void {

        var pixels = fetchTexturePixels(texture);
        var id = (texture:clay.graphics.Texture).id;

        if (reversePremultiplyAlpha)
            ceramic.PremultiplyAlpha.reversePremultiplyAlpha(pixels);

        var bytes = pixels.toBytes();

        if (path != null) {
            stb.ImageWrite.write_png(path, (texture:clay.graphics.Texture).width, (texture:clay.graphics.Texture).height, 4, bytes.getData(), 0, bytes.length, Std.int((texture:clay.graphics.Texture).width * 4));
            done();
        }
        else {
            // This part could be improved if we exposed stbi_write_png_to_func
            // and skipped the write to disk part, but that will do for now.
            var tmpFile = Utils.uniqueId() + '_texture.png';
            var storageDir = ceramic.App.app.backend.info.storageDirectory();
            var tmpPath = ceramic.Path.join([storageDir, tmpFile]);
            stb.ImageWrite.write_png(tmpPath, (texture:clay.graphics.Texture).width, (texture:clay.graphics.Texture).height, 4, bytes.getData(), 0, bytes.length, Std.int((texture:clay.graphics.Texture).width * 4));
            var data = Files.getBytes(tmpPath);
            Files.deleteFile(tmpPath);
            done(data);
        }

    }

    /**
     * Exports raw pixel data to PNG format.
     * Native implementation using STB image write.
     * 
     * @param width Image width in pixels
     * @param height Image height in pixels
     * @param pixels Raw RGBA pixel data
     * @param path Optional file path to save to (returns bytes if null)
     * @param done Callback with PNG data bytes (null if path provided)
     */
    public function pixelsToPng(width:Int, height:Int, pixels:ceramic.UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void {

        var bytes = pixels.toBytes();

        if (path != null) {
            stb.ImageWrite.write_png(path, width, height, 4, bytes.getData(), 0, bytes.length, Std.int(width * 4));
            done();
        }
        else {
            // This part could be improved if we exposed stbi_write_png_to_func
            // and skipped the write to disk part, but that will do for now.
            var tmpFile = Utils.uniqueId() + '_texture.png';
            var storageDir = ceramic.App.app.backend.info.storageDirectory();
            var tmpPath = ceramic.Path.join([storageDir, tmpFile]);
            stb.ImageWrite.write_png(tmpPath, width, height, 4, bytes.getData(), 0, bytes.length, Std.int(width * 4));
            var data = Files.getBytes(tmpPath);
            Files.deleteFile(tmpPath);
            done(data);
        }

    }

    #elseif web

    /**
     * Exports a texture to PNG format.
     * Web implementation using canvas API.
     * 
     * @param texture The texture to export
     * @param reversePremultiplyAlpha Whether to reverse premultiplied alpha
     * @param path Optional file path to save to (returns bytes if null)
     * @param done Callback with PNG data bytes (null if path provided)
     */
    public function textureToPng(texture:Texture, reversePremultiplyAlpha:Bool = true, ?path:String, done:(?data:Bytes)->Void):Void {

        var pixels = fetchTexturePixels(texture);
        var id = (texture:clay.graphics.Texture).id;

        if (reversePremultiplyAlpha)
            ceramic.PremultiplyAlpha.reversePremultiplyAlpha(pixels);

        clay.Clay.app.assets.pixelsToPngData((texture:clay.graphics.Texture).width, (texture:clay.graphics.Texture).height, pixels, function(data) {
            if (data != null) {
                if (path != null) {
                    Files.saveBytes(path, data.toBytes());
                    done();
                }
                else {
                    done(data.toBytes());
                }
            }
            else {
                ceramic.Shortcuts.log.warning('Failed to get PNG data from texture');
                done(null);
            }
        });

    }

    /**
     * Exports raw pixel data to PNG format.
     * Web implementation using canvas API.
     * 
     * @param width Image width in pixels
     * @param height Image height in pixels
     * @param pixels Raw RGBA pixel data
     * @param path Optional file path to save to (returns bytes if null)
     * @param done Callback with PNG data bytes (null if path provided)
     */
    public function pixelsToPng(width:Int, height:Int, pixels:ceramic.UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void {

        clay.Clay.app.assets.pixelsToPngData(width, height, pixels, function(data) {
            if (data != null) {
                if (path != null) {
                    Files.saveBytes(path, data.toBytes());
                    done();
                }
                else {
                    done(data.toBytes());
                }
            }
            else {
                ceramic.Shortcuts.log.warning('Failed to get PNG data from pixels');
                done(null);
            }
        });

    }

    #else

    /**
     * Exports a texture to PNG format.
     * Stub implementation for unsupported platforms.
     * 
     * @param texture The texture to export
     * @param reversePremultiplyAlpha Whether to reverse premultiplied alpha
     * @param path Optional file path to save to
     * @param done Callback with null (not supported)
     */
    public function textureToPng(texture:Texture, reversePremultiplyAlpha:Bool = true, ?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    /**
     * Exports raw pixel data to PNG format.
     * Stub implementation for unsupported platforms.
     * 
     * @param width Image width in pixels
     * @param height Image height in pixels
     * @param pixels Raw RGBA pixel data
     * @param path Optional file path to save to
     * @param done Callback with null (not supported)
     */
    public function pixelsToPng(width:Int, height:Int, pixels:ceramic.UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    #end

/// Internal

    /** Map of loading textures to their callbacks */
    var loadingTextureCallbacks:Map<String,Array<Texture->Void>> = new Map();

    /** Cache of loaded textures by path/ID */
    var loadedTextures:Map<String,Texture> = new Map();

    /** Reference count for each loaded texture */
    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures
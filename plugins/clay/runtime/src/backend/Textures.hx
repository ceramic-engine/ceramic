package backend;

import ceramic.Files;
import ceramic.ImageType;
import ceramic.Path;
import ceramic.Utils;
import clay.Clay;
import clay.Immediate;
import haxe.io.Bytes;

using StringTools;

#if cpp
import opengl.GL;
#else
import clay.opengl.GL;
#end


class Textures implements spec.Textures {

    public function new() {}

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

    inline public function supportsHotReloadPath():Bool {

        return true;

    }

    var nextRenderIndex:Int = 0;

    var nextPixelsIndex:Int = 0;

    var nextBytesIndex:Int = 0;

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

    public function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array {

        var w = (texture:clay.graphics.Texture).width;
        var h = (texture:clay.graphics.Texture).height;

        if (result == null) {
            result = new ceramic.UInt8Array(w * h * 4);
        }

        (texture:clay.graphics.Texture).fetch(result);

        return result;

    }

    public function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void {

        (texture:clay.graphics.Texture).submit(pixels);

    }

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

    inline public function getTextureId(texture:Texture):backend.TextureId {

        return (texture:clay.graphics.Texture).textureId;

    }

    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:clay.graphics.Texture).width;

    }

    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:clay.graphics.Texture).height;

    }

    inline public function getTextureWidthActual(texture:Texture):Int {

        return (texture:clay.graphics.Texture).widthActual;

    }

    inline public function getTextureHeightActual(texture:Texture):Int {

        return (texture:clay.graphics.Texture).heightActual;

    }

    inline public function getTextureIndex(texture:Texture):Int {

        return (texture:clay.graphics.Texture).index;

    }

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

    inline public function setTextureWrapS(texture: Texture, wrap: ceramic.TextureWrap): Void {
            
            switch (wrap) {
                case CLAMP_TO_EDGE:
                    (texture: clay.graphics.Texture).wrapS = CLAMP_TO_EDGE;
                case REPEAT:
                    (texture: clay.graphics.Texture).wrapS = REPEAT;
                case MIRRORED_REPEAT:
                    (texture: clay.graphics.Texture).wrapS = MIRRORED_REPEAT;
            }
    
    }

    inline public function setTextureWrapT(texture: Texture, wrap: ceramic.TextureWrap): Void {
            
            switch (wrap) {
                case CLAMP_TO_EDGE:
                    (texture: clay.graphics.Texture).wrapT = CLAMP_TO_EDGE;
                case REPEAT:
                    (texture: clay.graphics.Texture).wrapT = REPEAT;
                case MIRRORED_REPEAT:
                    (texture: clay.graphics.Texture).wrapT = MIRRORED_REPEAT;
            }
    
    }

    static var _maxTexturesByBatch:Int = -1;

    #if cpp

    static var _maxTextureWidth:Int = -1;
    static var _maxTextureHeight:Int = -1;

    // Just a dummy method to force opengl headers to be imported
    // in our generated c++ file
    @:noCompletion @:keep function importGlHeaders():Void {
        GL.glClear(0);
    }

    inline static function computeMaxTextureSizeIfNeeded() {

        if (_maxTextureWidth == -1) {
            var maxSize:Array<Int> = [0];
            GL.glGetIntegerv(GL.GL_MAX_TEXTURE_SIZE, maxSize);
            _maxTextureWidth = maxSize[0];
            _maxTextureHeight = maxSize[0];
        }

    }

    #end

    public function maxTextureWidth():Int {

        #if cpp
        computeMaxTextureSizeIfNeeded();
        return _maxTextureWidth;
        #else
        return 2048;
        #end

    }

    public function maxTextureHeight():Int {

        #if cpp
        computeMaxTextureSizeIfNeeded();
        return _maxTextureHeight;
        #else
        return 2048;
        #end

    }

    inline static function computeMaxTexturesByBatchIfNeeded() {

        if (_maxTexturesByBatch == -1) {
            #if cpp
            var maxUnits:Array<Int> = [0];
            GL.glGetIntegerv(GL.GL_MAX_TEXTURE_IMAGE_UNITS, maxUnits);
            _maxTexturesByBatch = Std.int(Math.min(32, maxUnits[0]));

            #else
            _maxTexturesByBatch = Std.int(Math.min(32, GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS)));
            #end
        }

    }

    /**
     * If this returns a value above 1, that means this backend supports multi-texture batching.
     */
    public function maxTexturesByBatch():Int {

        computeMaxTexturesByBatchIfNeeded();
        return _maxTexturesByBatch;

    }

    #if cpp

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

    public function textureToPng(texture:Texture, reversePremultiplyAlpha:Bool = true, ?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    public function pixelsToPng(width:Int, height:Int, pixels:ceramic.UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    #end

/// Internal

    var loadingTextureCallbacks:Map<String,Array<Texture->Void>> = new Map();

    var loadedTextures:Map<String,Texture> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures
package backend;

import backend.impl.CeramicTexture;
import snow.systems.assets.Asset;
import luxe.Resources;
import luxe.options.ResourceOptions;
import ceramic.Path;

#if cpp
import opengl.GL;
#else
import snow.modules.opengl.GL;
#end

using StringTools;

class Textures implements spec.Textures {

    public function new() {}

    public function load(path:String, ?options:backend.LoadTextureOptions, done:Texture->Void):Void {

        // Create empty texture
        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);
        
        // Is texture already loaded?
        if (loadedTextures.exists(path)) {
            loadedTexturesRetainCount.set(path, loadedTexturesRetainCount.get(path) + 1);
            var existing = Luxe.resources.texture(path);
            if (existing.state == ResourceState.loaded) {
                done(existing);
            } else {
                done(null);
            }
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
        var questionMarkIndex = cleanedPath.indexOf('?');
        if (questionMarkIndex != -1) {
            cleanedPath = cleanedPath.substr(0, questionMarkIndex);
        }

        // No texture yet, load one
        var texture:phoenix.Texture = new CeramicTexture(path, {
            id: cleanedPath,
            system: Luxe.resources,
            filter_min: null,
            filter_mag: null,
            clamp_s: null,
            clamp_t: null,
            load_premultiply_alpha: options != null && options.premultiplyAlpha ? true : false
        });

        // Keep it in luxe cache
        if (Luxe.resources.cache.exists(texture.id)) {
            Luxe.resources.remove(texture);
        }
        Luxe.resources.add(texture);

        // Create callbacks list with first entry
        loadingTextureCallbacks.set(path, [function(texture:Texture) {
            if (texture != null) {
                var retain = loadedTexturesRetainCount.exists(path) ? loadedTexturesRetainCount.get(path) : 0;
                loadedTexturesRetainCount.set(path, retain + 1);
            }
            done(texture);
        }]);

        // Load
        function doLoad() {
            // Load from asset using Luxe's internal API
            texture.state = ResourceState.loading;
            var get = Luxe.snow.assets.image(texture.id);
            get.then(function(asset:AssetImage) {
                texture.state = ResourceState.loaded;

                function doCreate() {
                    @:privateAccess texture.texture = texture.create_texture_id();
                    @:privateAccess texture.from_asset(asset);

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
                }
/*#if cpp
                ceramic.internal.Worker.execInPrimary(doCreate);
#else*/
                doCreate();
//#end
            });
            get.error(function(_) {

                function doFail() {
                    texture.state = ResourceState.failed;
                    texture.destroy(true);
                    
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
/*#if cpp
                ceramic.internal.Worker.execInPrimary(doFail);
#else*/
                doFail();
//#end
            });
        }

/*#if cpp
        ceramic.App.app.backend.worker.enqueue(doLoad);
#else*/
        doLoad();
//#end

        // Needed to ensure a synchronous load will be done before the end of the frame
        ceramic.App.app.onceImmediate(function() {
            snow.api.Promise.Promises.step();
        });

    }

    inline public function supportsHotReloadPath():Bool {
        
        return true;

    }

    var nextRenderIndex:Int = 0;

    var nextPixelsIndex:Int = 0;

    public function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture {

        var texture = new phoenix.Texture({
            id: 'pixels:' + (nextPixelsIndex++),
            width: width,
            height: height,
            pixels: pixels
        });

        return texture;

    }

    inline public function createRenderTarget(width:Int, height:Int):Texture {

        var id = 'render:' + (nextRenderIndex++);

        var renderTexture = new backend.impl.CeramicRenderTexture({
            id: id,
            width: width,
            height: height,
            render_stencil: true // TODO optionize
        });

        loadedTexturesRetainCount.set(id, 1);

        return renderTexture;

    }

    public function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array {

        var w = (texture:phoenix.Texture).width;
        var h = (texture:phoenix.Texture).height;

        if (result == null) {
            result = new ceramic.UInt8Array(w * h * 4);
        }

        (texture:phoenix.Texture).fetch(result);

        return result;

    }

    public function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void {

        (texture:phoenix.Texture).submit(pixels);

    }

    public function destroyTexture(texture:Texture):Void {

        var id = (texture:phoenix.Texture).id;
        if (Std.isOfType(texture, CeramicTexture)) {
            var ceramicTexture:CeramicTexture = cast texture;
            id = ceramicTexture.ceramicId;
        }
        if (loadedTexturesRetainCount.get(id) > 1) {
            loadedTexturesRetainCount.set(id, loadedTexturesRetainCount.get(id) - 1);
        }
        else {
            loadedTextures.remove(id);
            loadedTexturesRetainCount.remove(id);
            (texture:phoenix.Texture).destroy(true);
        }

    }

    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:phoenix.Texture).width;

    }

    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:phoenix.Texture).height;

    }

    inline public function getTextureIndex(texture:Texture):Int {

        return (texture:phoenix.Texture).index;

    }

    inline public function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void {

        switch (filter) {
            case LINEAR:
                (texture:phoenix.Texture).filter_min = linear;
                (texture:phoenix.Texture).filter_mag = linear;
            case NEAREST:
                (texture:phoenix.Texture).filter_min = nearest;
                (texture:phoenix.Texture).filter_mag = nearest;
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

/// Internal

    var loadingTextureCallbacks:Map<String,Array<Texture->Void>> = new Map();

    var loadedTextures:Map<String,phoenix.Texture> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures
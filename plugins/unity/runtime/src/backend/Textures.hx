package backend;

import ceramic.Path;

import unityengine.Texture2D;

using StringTools;

class Textures implements spec.Textures {

    var imageExtensions:Array<String> = null;

    public function new() {}

    public function load(path:String, ?options:backend.LoadTextureOptions, _done:Texture->Void):Void {

        var done = function(texture:Texture) {
            ceramic.App.app.onceImmediate(function() {
                _done(texture);
                _done = null;
            });
        };

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        if (path.startsWith('http://') || path.startsWith('https://')) {
            // Not implemented (yet?)
            done(null);
            return;
        }
        
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

            // Load texture from Unity API
            var extension = Path.extension(path);
            if (imageExtensions == null)
                imageExtensions = ceramic.App.app.backend.info.imageExtensions();
            var unityPath = path;
            if (extension != null && imageExtensions.indexOf(extension.toLowerCase()) != -1) {
                unityPath = unityPath.substr(0, unityPath.length - extension.length - 1);
            }
            var unityTexture:Texture2D = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.Texture2D>({0})', unityPath);

            if (unityTexture != null) {

                function doCreate() {
                    var texture = new TextureImpl(path, unityTexture, null);

                    loadedTextures.set(path, texture);
                    var callbacks = loadingTextureCallbacks.get(path);
                    loadingTextureCallbacks.remove(path);
                    for (callback in callbacks) {
                        callback(texture);
                    }
                }

                doCreate();
            }
            else {

                function doFail() {
                    var callbacks = loadingTextureCallbacks.get(path);
                    loadingTextureCallbacks.remove(path);
                    for (callback in callbacks) {
                        callback(null);
                    }
                }

                doFail();
            }
        }

        doLoad();

    }

    var nextRenderIndex:Int = 0;

    var nextPixelsIndex:Int = 0;

    public function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture {

        var unityTexture:Texture2D = untyped __cs__('new UnityEngine.Texture2D({0}, {1}, UnityEngine.TextureFormat.RGBA32, false)', width, height);

        unityTexture.SetPixelData(pixels, 0, 0);
        unityTexture.Apply(false, false);

        var texture = new TextureImpl('pixels:' + (nextPixelsIndex++), unityTexture, null);

        return texture;

    }

    inline public function createRenderTarget(width:Int, height:Int):Texture {

        untyped __cs__('var renderTexture = new UnityEngine.RenderTexture({0}, {1}, 24, UnityEngine.RenderTextureFormat.Default)', width, height);
        untyped __cs__('renderTexture.Create()');

        var texture = new TextureImpl('render:' + (nextRenderIndex++), null, untyped __cs__('renderTexture'));

        return texture;

    }

    public function destroyTexture(texture:Texture):Void {

        var id = (texture:TextureImpl).path;
        if (loadedTexturesRetainCount.get(id) > 1) {
            loadedTexturesRetainCount.set(id, loadedTexturesRetainCount.get(id) - 1);
        }
        else {
            loadedTextures.remove(id);
            loadedTexturesRetainCount.remove(id);
            if (id.startsWith('pixels:')) {
                untyped __cs__('UnityEngine.Object.Destroy({0})', (texture:TextureImpl).unityTexture);
            }
            else if (id.startsWith('render:')) {
                untyped __cs__('((UnityEngine.RenderTexture){0}).Release()', (texture:TextureImpl).unityRenderTexture);
            }
            else {
                untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', (texture:TextureImpl).unityTexture);
            }
        }

    }

    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:TextureImpl).height;

    }

    public function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array {

        var unityTexture = (texture:TextureImpl).unityTexture;

        untyped __cs__('var rawData = {0}.GetRawTextureData<UnityEngine.Color32>()', unityTexture);
        var width = (texture:TextureImpl).width;
        var height = (texture:TextureImpl).height;

        if (result == null) {
            result = new backend.UInt8Array(width * height);
        }

        var i = 0;
        var n = 0;
        untyped __cs__('var color32 = new UnityEngine.Color32(0, 0, 0, 0)');
        for (y in 0...height) {
            for (x in 0...width) {
                untyped __cs__('color32 = rawData[{0}]', i);
                untyped __cs__('{0}[{1}] = color32.r', result, n);
                n++;
                untyped __cs__('{0}[{1}] = color32.g', result, n);
                n++;
                untyped __cs__('{0}[{1}] = color32.b', result, n);
                n++;
                untyped __cs__('{0}[{1}] = color32.a', result, n);
                n++;
                i++;
            }
        }

        return result;

    }

    public function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void {

        var unityTexture = (texture:TextureImpl).unityTexture;

        unityTexture.SetPixelData(pixels, 0, 0);
        unityTexture.Apply(false, false);

    }

    inline public function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void {

        switch (filter) {
            case LINEAR:
                (texture:TextureImpl).unityTexture.filterMode = untyped __cs__('UnityEngine.FilterMode.Bilinear');
            case NEAREST:
                (texture:TextureImpl).unityTexture.filterMode = untyped __cs__('UnityEngine.FilterMode.Point');
        }

    }

    inline public function supportsHotReloadPath():Bool {
        
        return false;

    }

    /** If this returns a value above 1, that means this backend supports multi-texture batching. */
    public function maxTexturesByBatch():Int {

        // Might do some more checks later
        return 8;

    }

    inline public function getTextureIndex(texture:Texture):Int {

        return (texture:TextureImpl).index;

    }

/// Internal

    var loadingTextureCallbacks:Map<String,Array<Texture->Void>> = new Map();

    var loadedTextures:Map<String,TextureImpl> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures
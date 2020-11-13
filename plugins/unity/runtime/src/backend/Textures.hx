package backend;

import ceramic.Path;

import unityengine.Texture2D;

using StringTools;

class Textures implements spec.Textures {

    var imageExtensions:Array<String> = null;

    public function new() {}

    public function load(path:String, ?options:backend.LoadTextureOptions, done:Texture->Void):Void {

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
            trace('TEXTURE PATH $unityPath (extension=$extension)');
            var unityTexture:Texture2D = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.Texture2D>({0})', unityPath);

            if (unityTexture != null) {

                function doCreate() {
                    var texture = new TextureImpl(path, unityTexture);

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

    public function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture {

        return null;

    }

    inline public function createRenderTarget(width:Int, height:Int):Texture {

        // TODO

        return null;

    }

    public function destroyTexture(texture:Texture):Void {

        var id = (texture:TextureImpl).path;
        if (loadedTexturesRetainCount.get(id) > 1) {
            loadedTexturesRetainCount.set(id, loadedTexturesRetainCount.get(id) - 1);
        }
        else {
            loadedTextures.remove(id);
            loadedTexturesRetainCount.remove(id);
            untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', (texture:TextureImpl).unityTexture);
        }

    }

    inline public function getTextureWidth(texture:Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeight(texture:Texture):Int {

        return (texture:TextureImpl).height;

    }

    public function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array {

        // TODO

        return result;

    }

    public function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void {

        // TODO

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

        // Multi-texture not supported for now
        return 1;

    }

    inline public function getTextureIndex(texture:Texture):Int {

        return (texture:TextureImpl).index;

    }

/// Internal

    var loadingTextureCallbacks:Map<String,Array<Texture->Void>> = new Map();

    var loadedTextures:Map<String,TextureImpl> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures
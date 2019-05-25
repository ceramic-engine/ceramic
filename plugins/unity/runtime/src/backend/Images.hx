package backend;

import ceramic.Path;

import unityengine.Texture2D;

using StringTools;

class Images implements spec.Images {

    public function new() {}

    public function load(path:String, ?options:backend.LoadImageOptions, done:Image->Void):Void {

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
            loadingTextureCallbacks.get(path).push(function(texture:Image) {
                if (texture != null) {
                    var retain = loadedTexturesRetainCount.exists(path) ? loadedTexturesRetainCount.get(path) : 0;
                    loadedTexturesRetainCount.set(path, retain + 1);
                }
                done(texture);
            });
            return;
        }

        // Create callbacks list with first entry
        loadingTextureCallbacks.set(path, [function(texture:Image) {
            if (texture != null) {
                var retain = loadedTexturesRetainCount.exists(path) ? loadedTexturesRetainCount.get(path) : 0;
                loadedTexturesRetainCount.set(path, retain + 1);
            }
            done(texture);
        }]);

        // Load
        function doLoad() {

            // Load texture from Unity API
            var unityPath = path;
            if (unityPath.toLowerCase().endsWith('.png')) {
                unityPath = unityPath.substr(0, unityPath.length - '.png'.length);
            }
            var unityTexture:Texture2D = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.Texture2D>({0})', unityPath);

            if (unityTexture != null) {

                function doCreate() {
                    var texture = new ImageImpl(path, unityTexture);

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

    } //load

    var nextRenderIndex:Int = 0;

    public function createImage(width:Int, height:Int):Image {

        return null;

    } //createImage

    inline public function createRenderTarget(width:Int, height:Int):Image {

        // TODO

        return null;

    } //createRenderTarget

    public function destroyImage(texture:Image):Void {

        var id = (texture:ImageImpl).path;
        if (loadedTexturesRetainCount.get(id) > 1) {
            loadedTexturesRetainCount.set(id, loadedTexturesRetainCount.get(id) - 1);
        }
        else {
            loadedTextures.remove(id);
            loadedTexturesRetainCount.remove(id);
            untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', (texture:ImageImpl).unityTexture);
        }

    } //destroy

    inline public function getImageWidth(texture:Image):Int {

        return (texture:ImageImpl).width;

    } //getWidth

    inline public function getImageHeight(texture:Image):Int {

        return (texture:ImageImpl).height;

    } //getHeight

    inline public function getImagePixels(texture:Image):Null<UInt8Array> {

        return null;

    } //getImagePixels

    inline public function setTextureFilter(texture:Image, filter:ceramic.TextureFilter):Void {

        switch (filter) {
            case LINEAR:
                (texture:ImageImpl).unityTexture.filterMode = untyped __cs__('UnityEngine.FilterMode.Bilinear');
            case NEAREST:
                (texture:ImageImpl).unityTexture.filterMode = untyped __cs__('UnityEngine.FilterMode.Point');
        }

    } //setTextureFilter

/// Internal

    var loadingTextureCallbacks:Map<String,Array<Image->Void>> = new Map();

    var loadedTextures:Map<String,ImageImpl> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Images
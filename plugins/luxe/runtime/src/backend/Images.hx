package backend;

import snow.systems.assets.Asset;
import luxe.Resources;
import luxe.options.ResourceOptions;
import haxe.io.Path;

using StringTools;

class Images implements spec.Images {

    public function new() {}

    public function load(path:String, ?options:backend.LoadImageOptions, done:Image->Void):Void {

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
            loadingTextureCallbacks.get(path).push(function(texture:Image) {
                if (texture != null) {
                    var retain = loadedTexturesRetainCount.exists(path) ? loadedTexturesRetainCount.get(path) : 0;
                    loadedTexturesRetainCount.set(path, retain + 1);
                }
                done(texture);
            });
            return;
        }

        // No texture yet, load one
        var texture:phoenix.Texture = new phoenix.Texture({
            id: path,
            system: Luxe.resources,
            filter_min: null,
            filter_mag: null,
            clamp_s: null,
            clamp_t: null,
            load_premultiply_alpha: options != null && options.premultiplyAlpha ? true : false
        });

        // Keep it in luxe cache
        Luxe.resources.add(texture);

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
            // Load from asset using Luxe's internal API
            texture.state = ResourceState.loading;
            var get = Luxe.snow.assets.image(path);
            get.then(function(asset:AssetImage) {
                texture.state = ResourceState.loaded;

                function doCreate() {
                    @:privateAccess texture.texture = texture.create_texture_id();
                    @:privateAccess texture.from_asset(asset);

                    loadedTextures.set(path, texture);
                    var callbacks = loadingTextureCallbacks.get(path);
                    loadingTextureCallbacks.remove(path);
                    for (callback in callbacks) {
                        callback(texture);
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
                        callback(null);
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

    } //load

    var nextRenderIndex:Int = 0;

    public function createImage(width:Int, height:Int):Image {

        return null;

    } //createImage

    inline public function createRenderTarget(width:Int, height:Int):Image {

        var id = 'render:' + (nextRenderIndex++);

        var renderTexture = new backend.impl.CeramicRenderTexture({
            id: id,
            width: width,
            height: height
        });

        loadedTexturesRetainCount.set(id, 1);

        return renderTexture;

    } //createRenderTarget

    public function destroyImage(texture:Image):Void {

        var id = (texture:phoenix.Texture).id;
        if (loadedTexturesRetainCount.get(id) > 1) {
            loadedTexturesRetainCount.set(id, loadedTexturesRetainCount.get(id) - 1);
        }
        else {
            loadedTextures.remove(id);
            loadedTexturesRetainCount.remove(id);
            (texture:phoenix.Texture).destroy(true);
        }

    } //destroy

    inline public function getImageWidth(texture:Image):Int {

        return (texture:phoenix.Texture).width;

    } //getWidth

    inline public function getImageHeight(texture:Image):Int {

        return (texture:phoenix.Texture).height;

    } //getHeight

    inline public function getImagePixels(texture:Image):Null<UInt8Array> {

        return null;

    } //getImagePixels

    inline public function setTextureFilter(texture:Image, filter:ceramic.TextureFilter):Void {

        switch (filter) {
            case LINEAR:
                (texture:phoenix.Texture).filter_min = linear;
                (texture:phoenix.Texture).filter_mag = linear;
            case NEAREST:
                (texture:phoenix.Texture).filter_min = nearest;
                (texture:phoenix.Texture).filter_mag = nearest;
        }

    } //setTextureFilter

/// Internal

    var loadingTextureCallbacks:Map<String,Array<Image->Void>> = new Map();

    var loadedTextures:Map<String,phoenix.Texture> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures
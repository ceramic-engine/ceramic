package backend;

import ceramic.Files;
import ceramic.ImageType;
import ceramic.Path;
import ceramic.Pixels;
import cs.system.Byte;
import haxe.io.Bytes;
import unityengine.ImageConversion;
import unityengine.ResourceRequest;
import unityengine.Texture2D;
import unityengine.TextureWrapMode;

using StringTools;

class Textures implements spec.Textures {

    public function new() {}

    public function load(path:String, ?options:backend.LoadTextureOptions, _done:Texture->Void):Void {

        var synchronous = options != null && options.loadMethod == SYNC;

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

            var unityTexture:Texture2D = null;

            inline function handleUnityTexture() {
                if (unityTexture != null) {

                    inline function doCreate() {
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

                    inline function doFail() {
                        var callbacks = loadingTextureCallbacks.get(path);
                        loadingTextureCallbacks.remove(path);
                        for (callback in callbacks) {
                            callback(null);
                        }
                    }

                    doFail();
                }
            }

            var isEditor:Bool = untyped __cs__('UnityEngine.Application.isEditor');
            var loadAsync:Bool = isEditor || !synchronous; // We force async loading in editor to prevent editor using textures that are not ready
            if (loadAsync) {
                var request:ResourceRequest = untyped __cs__('UnityEngine.Resources.LoadAsync<UnityEngine.Texture2D>({0})', unityPath);
                var checkRequest:Void->Void = null;
                checkRequest = function() {
                    if (request.isDone) {
                        unityTexture = cast request.asset;
                        handleUnityTexture();
                    }
                    else {
                        ceramic.App.app.backend.onceNextUpdate(checkRequest);
                    }
                };
                checkRequest();
            }
            else {
                unityTexture = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.Texture2D>({0})', unityPath);
                handleUnityTexture();
            }

        }

        doLoad();

    }

    var nextRenderIndex:Int = 0;

    var nextPixelsIndex:Int = 0;

    var nextBytesIndex:Int = 0;

    public function loadFromBytes(bytes:Bytes, type:ImageType, ?options:LoadTextureOptions, _done:Texture->Void):Void {

        var done = function(texture:Texture) {
            ceramic.App.app.onceImmediate(function() {
                _done(texture);
                _done = null;
            });
        };

        var unityTexture:Texture2D = untyped __cs__('new UnityEngine.Texture2D(2, 2, UnityEngine.TextureFormat.RGBA32, false)');
        ImageConversion.LoadImage(unityTexture, bytes.getData(), false);

        var texture = new TextureImpl('bytes:' + (nextBytesIndex++), unityTexture, null);

        loadedTexturesRetainCount.set(texture.path, 1);

        done(texture);

    }

    public function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture {

        var unityTexture:Texture2D = untyped __cs__('new UnityEngine.Texture2D({0}, {1}, UnityEngine.TextureFormat.RGBA32, false)', width, height);

        Pixels.flipY(pixels, width);
        unityTexture.SetPixelData(pixels, 0, 0);
        unityTexture.Apply(false, false);
        Pixels.flipY(pixels, width);

        var texture = new TextureImpl('pixels:' + (nextPixelsIndex++), unityTexture, null);

        loadedTexturesRetainCount.set(texture.path, 1);

        return texture;

    }

    inline public function createRenderTarget(width:Int, height:Int, depth:Bool, stencil:Bool, antialiasing:Int):Texture {

        if (antialiasing < 1)
            antialiasing = 1;

        untyped __cs__('var renderTexture = new UnityEngine.RenderTexture({0}, {1}, 24, UnityEngine.RenderTextureFormat.Default)', width, height);
        untyped __cs__('renderTexture.antiAliasing = {0}', antialiasing);

        if (stencil) {
            untyped __cs__('renderTexture.depthStencilFormat = UnityEngine.Experimental.Rendering.GraphicsFormat.D24_UNorm_S8_UInt');
        }
        else if (depth)
            untyped __cs__('renderTexture.depth = 16');

        untyped __cs__('renderTexture.Create()');

        var texture = new TextureImpl('render:' + (nextRenderIndex++), null, untyped __cs__('renderTexture'));

        loadedTexturesRetainCount.set(texture.path, 1);

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
            if (id.startsWith('pixels:') || id.startsWith('screenshot:') || id.startsWith('bytes:')) {
                untyped __cs__('UnityEngine.Object.Destroy({0})', (texture:TextureImpl).unityTexture);
            }
            else if (id.startsWith('render:')) {
                untyped __cs__('((UnityEngine.RenderTexture){0}).Release()', (texture:TextureImpl).unityRenderTexture);
                untyped __cs__('UnityEngine.Object.Destroy({0})', (texture:TextureImpl).unityRenderTexture);
            }
            else {
                untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', (texture:TextureImpl).unityTexture);
            }
        }

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

    public function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array {

        // TODO read pixel directly from CPU if unityTexture.isReadable is true

        var unityTexture = (texture:TextureImpl).unityTexture;
        var didCreateTemporaryTexture = false;

        if (unityTexture == null) {
            if ((texture:TextureImpl).unityRenderTexture != null) {
                didCreateTemporaryTexture = true;

                var unityRenderTexture = (texture:TextureImpl).unityRenderTexture;
                unityTexture = untyped __cs__('new UnityEngine.Texture2D({0}, {1}, UnityEngine.TextureFormat.RGBA32, false)', unityRenderTexture.width, unityRenderTexture.height);

                var previousActiveRenderTexture = unityengine.RenderTexture.active;
                unityengine.RenderTexture.active = unityRenderTexture;

                unityTexture.ReadPixels(new unityengine.Rect(0, 0, unityRenderTexture.width, unityRenderTexture.height), 0, 0, false);
                unityTexture.Apply(false, false);

                unityengine.RenderTexture.active = previousActiveRenderTexture;
            }
        }

        untyped __cs__('var rawData = {0}.GetRawTextureData<UnityEngine.Color32>()', unityTexture);
        var width = (texture:TextureImpl).width;
        var height = (texture:TextureImpl).height;

        if (result == null) {
            result = new backend.UInt8Array(width * height * 4);
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

        Pixels.flipY(result, width);

        if (didCreateTemporaryTexture) {
            untyped __cs__('UnityEngine.Object.Destroy({0})', unityTexture);
        }

        return result;

    }

    public function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void {

        var unityTexture = (texture:TextureImpl).unityTexture;
        var width = (texture:TextureImpl).width;

        Pixels.flipY(pixels, width);
        unityTexture.SetPixelData(pixels, 0, 0);
        unityTexture.Apply(false, false);
        Pixels.flipY(pixels, width);

    }

    inline public function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void {

        switch (filter) {
            case LINEAR:
                if ((texture:TextureImpl).unityTexture != null)
                    (texture:TextureImpl).unityTexture.filterMode = untyped __cs__('UnityEngine.FilterMode.Bilinear');
                else if ((texture:TextureImpl).unityRenderTexture != null)
                    (texture:TextureImpl).unityRenderTexture.filterMode = untyped __cs__('UnityEngine.FilterMode.Bilinear');
            case NEAREST:
                if ((texture:TextureImpl).unityTexture != null)
                    (texture:TextureImpl).unityTexture.filterMode = untyped __cs__('UnityEngine.FilterMode.Point');
                else if ((texture:TextureImpl).unityRenderTexture != null)
                    (texture:TextureImpl).unityRenderTexture.filterMode = untyped __cs__('UnityEngine.FilterMode.Point');
        }

    }

    inline public function setTextureWrapS(texture:Texture, wrap:ceramic.TextureWrap): Void {

        switch (wrap) {
            case CLAMP:
                if ((texture:TextureImpl).unityTexture != null)
                    (texture:TextureImpl).unityTexture.wrapModeU = TextureWrapMode.Clamp;
                else if ((texture:TextureImpl).unityRenderTexture != null)
                    (texture:TextureImpl).unityRenderTexture.wrapModeU = TextureWrapMode.Clamp;
            case REPEAT:
                if ((texture:TextureImpl).unityTexture != null)
                    (texture:TextureImpl).unityTexture.wrapModeU = TextureWrapMode.Repeat;
                else if ((texture:TextureImpl).unityRenderTexture != null)
                    (texture:TextureImpl).unityRenderTexture.wrapModeU = TextureWrapMode.Repeat;
            case MIRROR:
                if ((texture:TextureImpl).unityTexture != null)
                    (texture:TextureImpl).unityTexture.wrapModeU = TextureWrapMode.Mirror;
                else if ((texture:TextureImpl).unityRenderTexture != null)
                    (texture:TextureImpl).unityRenderTexture.wrapModeU = TextureWrapMode.Mirror;
        }

    }

    inline public function setTextureWrapT(texture:Texture, wrap:ceramic.TextureWrap): Void {

        switch (wrap) {
            case CLAMP:
                if ((texture:TextureImpl).unityTexture != null)
                    (texture:TextureImpl).unityTexture.wrapModeV = TextureWrapMode.Clamp;
                else if ((texture:TextureImpl).unityRenderTexture != null)
                    (texture:TextureImpl).unityRenderTexture.wrapModeV = TextureWrapMode.Clamp;
            case REPEAT:
                if ((texture:TextureImpl).unityTexture != null)
                    (texture:TextureImpl).unityTexture.wrapModeV = TextureWrapMode.Repeat;
                else if ((texture:TextureImpl).unityRenderTexture != null)
                    (texture:TextureImpl).unityRenderTexture.wrapModeV = TextureWrapMode.Repeat;
            case MIRROR:
                if ((texture:TextureImpl).unityTexture != null)
                    (texture:TextureImpl).unityTexture.wrapModeV = TextureWrapMode.Mirror;
                else if ((texture:TextureImpl).unityRenderTexture != null)
                    (texture:TextureImpl).unityRenderTexture.wrapModeV = TextureWrapMode.Mirror;
        }

    }

    inline public function supportsHotReloadPath():Bool {

        return false;

    }

    /**
     * If this returns a value above 1, that means this backend supports multi-texture batching.
     */
    public function maxTexturesByBatch():Int {

        // Might do some more checks later
        return 8;

    }

    inline public function getTextureIndex(texture:Texture):Int {

        return (texture:TextureImpl).index;

    }

    public function textureToPng(texture:Texture, reversePremultiplyAlpha:Bool = true, ?path:String, done:(?data:Bytes)->Void):Void {

        var unityTexture:Texture2D = (texture:TextureImpl).unityTexture;
        var id = (texture:TextureImpl).path;
        var shouldDestroyTexture = false;

        // If exporting a texture loaded from assets, reverse premultiplied alpha
        if (reversePremultiplyAlpha) {
            var pixels = fetchTexturePixels(texture);
            ceramic.PremultiplyAlpha.reversePremultiplyAlpha(pixels);
            texture = createTexture((texture:TextureImpl).width, (texture:TextureImpl).height, pixels);
            unityTexture = (texture:TextureImpl).unityTexture;
            shouldDestroyTexture = true;
        }

        if (unityTexture != null) {
            var pngBytesData = ImageConversion.EncodeToPNG(unityTexture);
            if (path != null) {
                Files.saveBytes(path, Bytes.ofData(pngBytesData));
                done();
            }
            else {
                done(Bytes.ofData(pngBytesData));
            }
        }
        else {
            ceramic.Shortcuts.log.warning('Failed to read unity texture data');
            done(null);
        }
        if (shouldDestroyTexture) {
            destroyTexture(texture);
        }

    }

    public function pixelsToPng(width:Int, height:Int, pixels:ceramic.UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void {

        var texture = createTexture(width, height, pixels);
        var unityTexture:Texture2D = texture != null ? (texture:TextureImpl).unityTexture : null;
        if (unityTexture != null) {
            var pngBytesData = ImageConversion.EncodeToPNG(unityTexture);
            if (path != null) {
                Files.saveBytes(path, Bytes.ofData(pngBytesData));
                done();
            }
            else {
                done(Bytes.ofData(pngBytesData));
            }
        }
        else {
            ceramic.Shortcuts.log.warning('Failed to read unity texture data');
            done(null);
        }
        if (texture != null) {
            destroyTexture(texture);
        }

    }

/// Internal

    var imageExtensions:Array<String> = null;

    var loadingTextureCallbacks:Map<String,Array<Texture->Void>> = new Map();

    var loadedTextures:Map<String,TextureImpl> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures
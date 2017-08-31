package backend;

import snow.systems.assets.Asset;
import luxe.Resources;
import luxe.options.ResourceOptions;
import haxe.io.Path;

using StringTools;

typedef LoadTextureOptions = {
    ?premultiplyAlpha:Bool
}

abstract Texture(phoenix.Texture) from phoenix.Texture to phoenix.Texture {}

class BatchedRenderTexture extends phoenix.RenderTexture {

    public var targetBatcher:phoenix.Batcher = null;

    public var batcherClearColor = new phoenix.Color(1.0, 1.0, 1.0, 1.0);

    public function new(_options:RenderTextureOptions) {

        super(_options);

        targetBatcher = Luxe.renderer.create_batcher({
            name: 'batcher:' + _options.id
        });
        targetBatcher.on(prerender, targetBatcherBefore);
        targetBatcher.on(postrender, targetBatcherAfter);
        targetBatcher.view.transform.scale.y = -1;
        targetBatcher.view.viewport = new luxe.Rectangle(0, 0, _options.width, _options.height);

    } //new

    override function destroy(?_force:Bool=false) {

        targetBatcher.destroy();
        targetBatcher = null;

        super.destroy(_force);

    } //destroy

/// Batcher stuff

    function targetBatcherBefore(_) {

        Luxe.renderer.target = this;
        Luxe.renderer.clear(new phoenix.Color().rgb(0xff4b03));

    } //targetBatcherBefore

    function targetBatcherAfter(_) {

        Luxe.renderer.target = null;

    } //targetBatcherAfter

} //BatchedRenderTexture

class Textures implements spec.Textures {

    public function new() {}

    inline public function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void {

        // Create empty texture
        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);
        
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

        function doLoad() {
            // Load from asset using Luxe's internal API
            texture.state = ResourceState.loading;
            var get = Luxe.snow.assets.image(path);
            get.then(function(asset:AssetImage) {
                texture.state = ResourceState.loaded;

                function doCreate() {
                    @:privateAccess texture.texture = texture.create_texture_id();
                    @:privateAccess texture.from_asset(asset);
                    done(texture);
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
                    done(null);
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

    inline public function createRenderTexture(width:Int, height:Int):Texture {

        var id = 'render:' + (nextRenderIndex++);

        var renderTexture = new BatchedRenderTexture({
            id: id,
            width: width,
            height: height
        });

        loadedTexturesRetainCount.set(id, 1);

        return renderTexture;

    } //createRenderTexture

    public function destroy(texture:Texture):Void {

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

    inline public function getWidth(texture:Texture):Int {

        return (texture:phoenix.Texture).width;

    } //getWidth

    inline public function getHeight(texture:Texture):Int {

        return (texture:phoenix.Texture).height;

    } //getHeight

/// Internal

    var loadedTextures:Map<String,phoenix.Texture> = new Map();

    var loadedTexturesRetainCount:Map<String,Int> = new Map();

} //Textures
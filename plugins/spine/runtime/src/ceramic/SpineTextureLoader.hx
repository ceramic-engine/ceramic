package ceramic;

import spine.support.graphics.TextureAtlas;
import spine.support.graphics.TextureLoader;

@:access(ceramic.SpineAsset)
class SpineTextureLoader implements TextureLoader
{
    private var asset:SpineAsset;

    private var basePath:Null<String>;

    public function new(asset:SpineAsset, ?basePath:String) {

        this.asset = asset;
        this.basePath = basePath;

    }

    public function loadPage(page:AtlasPage, path:String):Void {

        asset.loadPage(page, path, basePath);

    }

    public function loadRegion(region:AtlasRegion):Void {

        // Nothing to do here

    }

    public function unloadPage(page:AtlasPage):Void {

        asset.unloadPage(page);

    }
}

package plugin.spine;

import spine.support.graphics.TextureAtlas;
import spine.support.graphics.TextureLoader;

@:access(plugin.spine.SpineAsset)
class SpineTextureLoader implements TextureLoader
{
    private var asset:SpineAsset;

    public function new(asset:SpineAsset) {

        this.asset = asset;

    } //new

    public function loadPage(page:AtlasPage, path:String):Void {

        asset.loadPage(page, path);

    } //loadPage

    public function loadRegion(region:AtlasRegion):Void {

        // Nothing to do here

    } //loadRegion

    public function unloadPage(page:AtlasPage):Void {

        asset.unloadPage(page);

    } //unloadPage
}

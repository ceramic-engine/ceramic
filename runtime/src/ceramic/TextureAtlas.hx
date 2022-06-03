package ceramic;

using ceramic.Extensions;

class TextureAtlas extends Entity {

    /**
     * The pages of this atlas.
     */
    public var pages:Array<TextureAtlasPage> = [];

    /**
     * The texture regions of this atlas
     */
    public var regions:Array<TextureAtlasRegion> = [];

    /**
     * The asset related to this atlas (if any)
     */
    public var asset:AtlasAsset = null;

    public function new() {

        super();

    }

    public function region(name:String):TextureAtlasRegion {

        for (i in 0...regions.length) {
            var region = regions.unsafeGet(i);
            if (region.name == name)
                return region;
        }

        return null;

    }

    /**
     * Expected to be called when every page got their texture loaded,
     * in order to compute the actual frames of each region
     */
    public function computeFrames() {

        for (i in 0...regions.length) {
            var region = regions.unsafeGet(i);
            region.computeFrame();
        }

    }

    override function destroy() {

        while (pages.length > 0) {
            var page = pages.pop();
            var texture = page.texture;
            if (texture != null) {
                texture.destroy();
            }
        }

        if (asset != null) asset.destroy();

        super.destroy();

    }

}

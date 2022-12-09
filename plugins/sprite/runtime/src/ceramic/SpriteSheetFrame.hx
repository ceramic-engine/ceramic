package ceramic;

import tracker.Model;

class SpriteSheetFrame extends Model {

    @serialize public var duration:Float = 0;

    @serialize public var region:TextureAtlasRegion;

    public function new(atlas:TextureAtlas, name:String, page:Int = 0, ?region:TextureAtlasRegion) {
        super();

        if (region != null)
            this.region = region;
        else
            this.region = new TextureAtlasRegion(name, atlas, page);
    }

}

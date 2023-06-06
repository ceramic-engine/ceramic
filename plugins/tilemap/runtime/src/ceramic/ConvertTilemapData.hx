package ceramic;

import ceramic.Assets;
import ceramic.ConvertField;
import ceramic.TilemapPlugin;

using ceramic.TilemapPlugin;

class ConvertTilemapData implements ConvertField<String,TilemapData> {

    public function new() {}

    public function basicToField(instance:Entity, field:String, assets:Assets, basic:String, done:TilemapData->Void):Void {

        if (basic != null) {
            assets.ensureTilemap(basic, null, null, function(asset:TilemapAsset) {
                done(asset != null ? asset.tilemapData : null);
            });
        }
        else {
            done(null);
        }

    }

    public function fieldToBasic(instance:Entity, field:String, value:TilemapData):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

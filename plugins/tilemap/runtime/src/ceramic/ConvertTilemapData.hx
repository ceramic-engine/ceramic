package plugin.spine;

import ceramic.Assets;
import ceramic.ConvertField;

import ceramic.TilemapPlugin;
using ceramic.TilemapPlugin;

class ConvertTilemapData implements ConvertField<String,TilemapData> {

    public function new() {}

    public function basicToField(assets:Assets, basic:String, done:TilemapData->Void):Void {

        if (basic != null) {
            assets.ensureTilemap(basic, null, function(asset:TilemapAsset) {
                done(asset != null ? asset.tilemapData : null);
            });
        }
        else {
            done(null);
        }

    } //basicToField

    public function fieldToBasic(value:TilemapData):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    } //fieldToBasic

} //ConvertTilemapData

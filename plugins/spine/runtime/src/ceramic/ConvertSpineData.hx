package ceramic;

import ceramic.Assets;
import ceramic.ConvertField;
import ceramic.SpinePlugin;

using ceramic.SpinePlugin;

class ConvertSpineData implements ConvertField<String,SpineData> {

    public function new() {}

    public function basicToField(instance:Entity, field:String, assets:Assets, basic:String, done:SpineData->Void):Void {

        if (basic != null) {
            assets.ensureSpine(basic, null, null, function(asset:SpineAsset) {
                done(asset != null ? asset.spineData : null);
            });
        }
        else {
            done(null);
        }

    }

    public function fieldToBasic(instance:Entity, field:String, value:SpineData):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

package ceramic;

import ceramic.Assets;
import ceramic.ConvertField;

import ceramic.SpritePlugin;
using ceramic.SpritePlugin;

class ConvertSpriteSheet implements ConvertField<String,SpriteSheet> {

    public function new() {}

    public function basicToField(instance:Entity, field:String, assets:Assets, basic:String, done:SpriteSheet->Void):Void {

        if (basic != null) {
            assets.ensureSprite(basic, null, function(asset:SpriteAsset) {
                done(asset != null ? asset.sheet : null);
            });
        }
        else {
            done(null);
        }

    }

    public function fieldToBasic(instance:Entity, field:String, value:SpriteSheet):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

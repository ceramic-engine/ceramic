package ceramic;

class ConvertTexture implements ConvertField<String,Texture> {

    public function new() {}

    public function basicToField(instance:Entity, assets:Assets, basic:String, done:Texture->Void):Void {

        if (basic != null) {
            assets.ensureImage(basic, null, function(asset:ImageAsset) {
                done(asset != null ? asset.texture : null);
            });
        }
        else {
            done(null);
        }

    }

    public function fieldToBasic(instance:Entity, value:Texture):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

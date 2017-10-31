package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

/** Interface to convert from/to basic type and field values with complex types. */
interface ConvertField<BasicType,FieldType> {

    /** Get field value from basic type. As this may require loading assets,
        A usable `Assets` instance must be provided and the result will only be
        provided asynchronously by calling `done` callback. */
    function basicToField(assets:Assets, basic:BasicType, done:FieldType->Void):Void;

    /** Get a basic type from the field value. */
    function fieldToBasic(value:FieldType):BasicType;

} //ConvertField


/// Built-in converters

class ConvertTexture implements ConvertField<String,Texture> {

    public function new() {}

    public function basicToField(assets:Assets, basic:String, done:Texture->Void):Void {

        if (basic != null) {
            assets.ensureImage(basic, null, function(asset:ImageAsset) {
                done(asset != null ? asset.texture : null);
            });
        }
        else {
            done(null);
        }

    } //basicToField

    public function fieldToBasic(value:Texture):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    } //fieldToBasic

} //ConvertTexture

class ConvertFont implements ConvertField<String,BitmapFont> {

    public function new() {}

    public function basicToField(assets:Assets, basic:String, done:BitmapFont->Void):Void {

        if (basic != null) {
            if (basic == app.defaultFont.asset.name) {
                done(app.defaultFont);
            }
            else {
                assets.ensureFont(basic, null, function(asset:FontAsset) {
                    done(asset != null ? asset.font : null);
                });
            }
        }
        else {
            done(null);
        }

    } //basicToField

    public function fieldToBasic(value:BitmapFont):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    } //fieldToBasic

} //ConvertFont

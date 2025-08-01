package ceramic;

import ceramic.Shortcuts.*;

/**
 * Converter for BitmapFont fields in fragments and data serialization.
 * 
 * This converter handles BitmapFont instances by storing and loading them
 * using asset names. During deserialization, fonts are loaded from the
 * asset system asynchronously. The default font is handled as a special
 * case to avoid unnecessary loading.
 * 
 * @see ConvertField
 * @see BitmapFont
 * @see FontAsset
 * @see Fragment
 */
class ConvertFont implements ConvertField<String,BitmapFont> {

    /**
     * Create a new font converter instance.
     */
    public function new() {}

    /**
     * Convert a font asset name to a BitmapFont instance.
     * 
     * Special handling:
     * - If the name matches the default font, returns it immediately
     * - Otherwise loads the font asset asynchronously
     * - Returns null if the asset name is null or loading fails
     * 
     * @param instance The entity that will use this font
     * @param field The name of the field being converted
     * @param assets Assets instance used to load the font
     * @param basic The font asset name to load
     * @param done Callback invoked with the loaded BitmapFont instance
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:String, done:BitmapFont->Void):Void {

        if (basic != null) {
            if (basic == app.defaultFont.asset.name) {
                done(app.defaultFont);
            }
            else {
                assets.ensureFont(basic, null, null, function(asset:FontAsset) {
                    done(asset != null ? asset.font : null);
                });
            }
        }
        else {
            done(null);
        }

    }

    /**
     * Convert a BitmapFont instance to its asset name for serialization.
     * 
     * @param instance The entity that owns this font
     * @param field The name of the field being converted
     * @param value The BitmapFont instance to convert
     * @return The font's asset name, or null if the font or its asset is null
     */
    public function fieldToBasic(instance:Entity, field:String, value:BitmapFont):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

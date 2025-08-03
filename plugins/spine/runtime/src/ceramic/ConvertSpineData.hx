package ceramic;

import ceramic.Assets;
import ceramic.ConvertField;
import ceramic.SpinePlugin;

using ceramic.SpinePlugin;

/**
 * Converter for Spine animation data fields in entity components.
 *
 * This converter handles the serialization and deserialization of SpineData
 * fields when saving/loading entity data. It automatically loads the corresponding
 * Spine asset when converting from a string asset name to SpineData.
 *
 * @see SpineData
 * @see SpineAsset
 * @see ConvertField
 */
class ConvertSpineData implements ConvertField<String,SpineData> {

    public function new() {}

    /**
     * Converts a string (asset name) to SpineData by loading the corresponding Spine asset.
     *
     * This method is called during deserialization when converting saved data back
     * to runtime SpineData objects. It ensures the Spine asset is loaded before
     * providing the SpineData to the entity.
     *
     * @param instance The entity instance that owns the field
     * @param field The name of the field being converted
     * @param assets The asset manager used to load the Spine asset
     * @param basic The string value (asset name) to convert from
     * @param done Callback invoked with the loaded SpineData (or null if loading fails)
     */
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

    /**
     * Converts SpineData to a string (asset name) for serialization.
     *
     * This method extracts the asset name from the SpineData object,
     * allowing it to be saved as a simple string reference rather than
     * the full animation data.
     *
     * @param instance The entity instance that owns the field
     * @param field The name of the field being converted
     * @param value The SpineData value to convert
     * @return The asset name string, or null if the SpineData has no associated asset
     */
    public function fieldToBasic(instance:Entity, field:String, value:SpineData):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

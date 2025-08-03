package ceramic;

import ceramic.Assets;
import ceramic.ConvertField;

using ceramic.SpritePlugin;

/**
 * Field converter for SpriteSheet instances.
 * Handles conversion between asset names (strings) and loaded SpriteSheet objects.
 * This enables automatic sprite sheet loading when deserializing entities.
 * 
 * Used by the entity serialization system to convert sprite sheet references
 * in saved data into actual SpriteSheet instances.
 */
class ConvertSpriteSheet implements ConvertField<String,SpriteSheet> {

    public function new() {}

    /**
     * Convert a sprite sheet asset name to a loaded SpriteSheet instance.
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param assets The assets instance to load from
     * @param basic The sprite sheet asset name
     * @param done Callback with the loaded SpriteSheet (or null if loading fails)
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:String, done:SpriteSheet->Void):Void {

        if (basic != null) {
            assets.ensureSprite(basic, null, null, function(asset:SpriteAsset) {
                done(asset != null ? asset.sheet : null);
            });
        }
        else {
            done(null);
        }

    }

    /**
     * Convert a SpriteSheet instance back to its asset name for serialization.
     * @param instance The entity that owns this field
     * @param field The name of the field being converted
     * @param value The SpriteSheet instance
     * @return The asset name, or null if the sheet has no associated asset
     */
    public function fieldToBasic(instance:Entity, field:String, value:SpriteSheet):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

package ceramic;

/**
 * Converter for Texture fields in fragments and data serialization.
 * 
 * This converter handles Texture instances by storing and loading them
 * using asset names. During deserialization, textures are loaded from
 * the asset system asynchronously. This allows fragments to reference
 * textures by name without embedding the actual image data.
 * 
 * @see ConvertField
 * @see Texture
 * @see ImageAsset
 * @see Fragment
 */
class ConvertTexture implements ConvertField<String,Texture> {

    /**
     * Create a new texture converter instance.
     */
    public function new() {}

    /**
     * Convert an image asset name to a Texture instance.
     * 
     * The image is loaded asynchronously from the asset system.
     * If loading fails or the asset name is null, returns null.
     * 
     * @param instance The entity that will use this texture
     * @param field The name of the field being converted
     * @param assets Assets instance used to load the image
     * @param basic The image asset name to load
     * @param done Callback invoked with the loaded Texture instance
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:String, done:Texture->Void):Void {

        if (basic != null) {
            assets.ensureImage(basic, null, null, function(asset:ImageAsset) {
                done(asset != null ? asset.texture : null);
            });
        }
        else {
            done(null);
        }

    }

    /**
     * Convert a Texture instance to its asset name for serialization.
     * 
     * @param instance The entity that owns this texture
     * @param field The name of the field being converted
     * @param value The Texture instance to convert
     * @return The texture's asset name, or null if the texture or its asset is null
     */
    public function fieldToBasic(instance:Entity, field:String, value:Texture):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

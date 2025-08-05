package ceramic;

/**
 * Type-safe wrapper for asset identifiers.
 * 
 * AssetId provides compile-time type safety for asset references,
 * helping prevent runtime errors from incorrect asset types.
 * 
 * The generic type parameter T typically represents the return type
 * of the asset (e.g., Texture, Sound, String).
 * 
 * ```haxe
 * // Define typed asset IDs
 * var heroTexture:AssetId<Texture> = 'image:hero';
 * var bgMusic:AssetId<Sound> = 'sound:background';
 * 
 * // Use with Assets instance
 * assets.add(heroTexture);
 * assets.add(bgMusic);
 * 
 * // Type-safe retrieval
 * var texture = assets.texture(heroTexture);
 * var sound = assets.sound(bgMusic);
 * ```
 * 
 * @param T The type of asset this ID represents
 */
@:forward
abstract AssetId<T>(T) from T to T {

    /**
     * Create a new AssetId.
     * @param value The asset identifier value
     */
    inline public function new(value:T) {
        this = value;
    }

}

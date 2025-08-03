package ceramic;

import ceramic.Assets;
import ceramic.ConvertField;
import ceramic.TilemapPlugin;

using ceramic.TilemapPlugin;

/**
 * Field converter that handles conversion between tilemap asset names (strings)
 * and TilemapData instances. This converter enables automatic loading of tilemap
 * data when deserializing entities from fragments or other data sources.
 * 
 * When a string tilemap name is provided, the converter:
 * 1. Uses the Assets system to load the tilemap asset
 * 2. Extracts the TilemapData from the loaded asset
 * 3. Provides the data to the entity field
 * 
 * This converter is automatically registered by the TilemapPlugin and used
 * whenever a TilemapData field needs to be populated from serialized data.
 * 
 * ## Usage Example:
 * ```haxe
 * // In a fragment or serialized data:
 * {
 *     "tilemap": "levels/level1"  // String asset name
 * }
 * 
 * // Gets converted to:
 * entity.tilemap = <TilemapData instance>
 * ```
 * 
 * @see ConvertField The base interface for field converters
 * @see TilemapData The tilemap data structure
 * @see TilemapAsset The asset type that contains tilemap data
 */
class ConvertTilemapData implements ConvertField<String,TilemapData> {

    /**
     * Creates a new tilemap data converter instance.
     */
    public function new() {}

    /**
     * Converts a tilemap asset name (string) to a TilemapData instance.
     * Loads the tilemap asset asynchronously and extracts its data.
     * 
     * @param instance The entity that owns the field being converted
     * @param field The name of the field being converted
     * @param assets The Assets instance to use for loading
     * @param basic The tilemap asset name to load
     * @param done Callback that receives the loaded TilemapData (or null if loading fails)
     */
    public function basicToField(instance:Entity, field:String, assets:Assets, basic:String, done:TilemapData->Void):Void {

        if (basic != null) {
            assets.ensureTilemap(basic, null, null, function(asset:TilemapAsset) {
                done(asset != null ? asset.tilemapData : null);
            });
        }
        else {
            done(null);
        }

    }

    /**
     * Converts a TilemapData instance back to its asset name string.
     * Used when serializing entities that contain tilemap data.
     * 
     * @param instance The entity that owns the field being converted
     * @param field The name of the field being converted
     * @param value The TilemapData instance to convert
     * @return The asset name string, or null if the data has no associated asset
     */
    public function fieldToBasic(instance:Entity, field:String, value:TilemapData):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    }

}

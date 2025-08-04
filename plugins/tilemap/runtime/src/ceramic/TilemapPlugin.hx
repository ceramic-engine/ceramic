package ceramic;

import ceramic.App;
import ceramic.Asset;
import ceramic.AssetId;
import ceramic.AssetOptions;
import ceramic.Assets;
import ceramic.Either;
import ceramic.Entity;
import ceramic.Shortcuts.*;

using StringTools;

#if plugin_ldtk
import ceramic.LdtkData;
#end

/**
 * Main plugin class that integrates tilemap support into Ceramic.
 * 
 * The TilemapPlugin extends the asset system to support loading and managing tilemap files,
 * including TMX (Tiled Map Editor) and optionally LDtk formats. It provides convenience
 * methods for working with tilemap assets and manages parser instances and caching.
 * 
 * ## Features
 * 
 * - **Asset Integration**: Adds 'tilemap' asset kind to the asset system
 * - **Format Support**: TMX files, with optional LDtk support
 * - **Parser Management**: Maintains parser instances per Assets object
 * - **TSX Caching**: Caches external tileset data for performance
 * - **Type Conversion**: Registers TilemapData converter for serialization
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Add a tilemap asset
 * assets.addTilemap('level1');
 * 
 * // Load and use tilemap data
 * assets.onceComplete(this, function(success) {
 *     var tilemapData = assets.tilemap('level1');
 *     var tilemap = new Tilemap();
 *     tilemap.tilemapData = tilemapData;
 * });
 * 
 * // Access LDtk data (if available)
 * var ldtkData = assets.ldtk('myLevel');
 * ```
 * 
 * @see TilemapAsset
 * @see TilemapData
 * @see TilemapParser
 */
@:access(ceramic.App)
class TilemapPlugin {

/// Init plugin

    /**
     * Initializes the tilemap plugin during application startup.
     * This method is called automatically by the plugin system.
     * Registers the 'tilemap' asset kind and sets up converters.
     */
    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init tilemap plugin');

            // Extend assets with `tilemap` kind
            Assets.addAssetKind('tilemap', _addTilemap, ['tmx' #if plugin_ldtk , 'ldtk' #end], false, ['ceramic.TilemapData']);

            // Extend converters
            var convertTilemapData = new ConvertTilemapData();
            ceramic.App.app.converters.set('ceramic.TilemapData', convertTilemapData);

        });

    }

/// Asset extensions

    /**
     * Internal wrapper for addTilemap that matches the asset system callback signature.
     */
    private static function _addTilemap(assets:Assets, name:String, variant:String, options:AssetOptions):Void {
        addTilemap(assets, name, variant, options);
    }

    /**
     * Adds a tilemap asset to the asset manager.
     * The tilemap will be loaded from a file with the given name and appropriate extension (.tmx or .ldtk).
     * @param assets The assets manager to add the tilemap to
     * @param name The name of the tilemap file (without extension)
     * @param variant Optional variant suffix for the file
     * @param options Optional asset loading options
     */
    public static function addTilemap(assets:Assets, name:String, ?variant:String, ?options:AssetOptions):Void {

        if (name.startsWith('tilemap:')) name = name.substr(8);

        assets.addAsset(new TilemapAsset(name, variant, options));

    }

    /**
     * Ensures a tilemap asset is loaded, loading it if necessary.
     * This method is useful when you need to guarantee an asset is available before using it.
     * @param assets The assets manager
     * @param name The tilemap name or asset ID
     * @param variant Optional variant suffix
     * @param options Optional loading options
     * @param done Callback that receives the loaded TilemapAsset (or null if loading failed)
     */
    public static function ensureTilemap(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:TilemapAsset->Void):Void {

        if (!name.startsWith('tilemap:')) name = 'tilemap:' + name;

        assets.ensure(cast name, variant, options, function(asset) {
            done(Std.isOfType(asset, TilemapAsset) ? cast asset : null);
        });

    }

    /**
     * Gets the TilemapData from a loaded tilemap asset.
     * Returns null if the asset is not found or not loaded.
     * @param assets The assets manager
     * @param name The tilemap name or asset ID
     * @param variant Optional variant suffix
     * @return The TilemapData instance, or null if not found
     */
    public static function tilemap(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String):TilemapData {

        var asset = tilemapAsset(assets, name, variant);
        if (asset == null) return null;
        return asset.tilemapData;

    }

    /**
     * Gets the TilemapAsset instance for the given name.
     * Searches in the current assets manager and its parents.
     * @param assets The assets manager
     * @param name The tilemap name or asset ID
     * @param variant Optional variant suffix
     * @return The TilemapAsset instance, or null if not found
     */
    @:access(ceramic.Assets)
    public static function tilemapAsset(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String):TilemapAsset {

        var nameStr:String = cast name;
        if (nameStr.startsWith('tilemap:')) nameStr = nameStr.substr(8);
        if (variant != null) nameStr += ':' + variant;

        if (!assets.assetsByKindAndName.exists('tilemap')) return assets.parent != null ? tilemapAsset(assets.parent, name, variant) : null;
        var asset:TilemapAsset = cast assets.assetsByKindAndName.get('tilemap').get(nameStr);
        if (asset == null) return assets.parent != null ? tilemapAsset(assets.parent, name, variant) : null;
        return asset;

    }

    #if plugin_ldtk

    /**
     * Gets the LdtkData from a loaded LDtk tilemap asset.
     * Only available when the ldtk plugin is enabled.
     * @param assets The assets manager
     * @param name The LDtk file name or asset ID
     * @return The LdtkData instance, or null if not found or not an LDtk file
     */
    @:plugin('ldtk')
    public static function ldtk(assets:Assets, name:Either<String,AssetId<String>>):LdtkData {

        var asset = tilemapAsset(assets, name);
        if (asset == null) return null;
        return asset.ldtkData;

    }

    #end

    /**
     * Return the tilemap parser instance associated with this `Assets` object.
     * The first time, creates an instance, then reuses it.
     * @param assets
     * @return TilemapParser
     */
    public static function getTilemapParser(assets:Assets):TilemapParser {

        final data = EntityData.data(assets);

        var tilemapParser:TilemapParser = data.tilemapParser;
        if (tilemapParser == null) {
            tilemapParser = new TilemapParser();
            data.tilemapParser = tilemapParser;
        }
        return tilemapParser;

    }

    /**
     * Return a string map to read and store raw TSX cached data
     * @param assets
     * @return Map<String,String>
     */
    public static function getRawTsxCache(assets:Assets):Map<String,String> {

        final data = EntityData.data(assets);

        var rawTsxCache:Map<String,String> = data.rawTsxCache;
        if (rawTsxCache == null) {
            rawTsxCache = new Map<String,String>();
            data.rawTsxCache = rawTsxCache;
        }
        return rawTsxCache;

    }

}

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

@:access(ceramic.App)
class TilemapPlugin {

/// Init plugin

    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init tilemap plugin');

            // Extend assets with `tilemap` kind
            Assets.addAssetKind('tilemap', addTilemap, ['tmx' #if plugin_ldtk , 'ldtk' #end], false, ['ceramic.TilemapData']);

            // Extend converters
            var convertTilemapData = new ConvertTilemapData();
            ceramic.App.app.converters.set('ceramic.TilemapData', convertTilemapData);

        });

    }

/// Asset extensions

    public static function addTilemap(assets:Assets, name:String, ?options:AssetOptions):Void {

        if (name.startsWith('tilemap:')) name = name.substr(8);

        assets.addAsset(new TilemapAsset(name, options));

    }

    public static function ensureTilemap(assets:Assets, name:Either<String,AssetId<String>>, ?options:AssetOptions, done:TilemapAsset->Void):Void {

        if (!name.startsWith('tilemap:')) name = 'tilemap:' + name;

        assets.ensure(cast name, options, function(asset) {
            done(Std.isOfType(asset, TilemapAsset) ? cast asset : null);
        });

    }

    public static function tilemap(assets:Assets, name:Either<String,AssetId<String>>):TilemapData {

        var asset = tilemapAsset(assets, name);
        if (asset == null) return null;
        return asset.tilemapData;

    }

    @:access(ceramic.Assets)
    public static function tilemapAsset(assets:Assets, name:Either<String,AssetId<String>>):TilemapAsset {

        var nameStr:String = cast name;
        if (nameStr.startsWith('tilemap:')) nameStr = nameStr.substr(8);

        if (!assets.assetsByKindAndName.exists('tilemap')) return assets.parent != null ? tilemapAsset(assets.parent, name) : null;
        var asset:TilemapAsset = cast assets.assetsByKindAndName.get('tilemap').get(nameStr);
        if (asset == null) return assets.parent != null ? tilemapAsset(assets.parent, name) : null;
        return asset;

    }

    #if plugin_ldtk

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

        var tilemapParser:TilemapParser = assets.data.tilemapParser;
        if (tilemapParser == null) {
            tilemapParser = new TilemapParser();
            assets.data.tilemapParser = tilemapParser;
        }
        return tilemapParser;

    }

    /**
     * Return a string map to read and store raw TSX cached data
     * @param assets
     * @return Map<String,String>
     */
    public static function getRawTsxCache(assets:Assets):Map<String,String> {

        var rawTsxCache:Map<String,String> = assets.data.rawTsxCache;
        if (rawTsxCache == null) {
            rawTsxCache = new Map<String,String>();
            assets.data.rawTsxCache = rawTsxCache;
        }
        return rawTsxCache;

    }

}

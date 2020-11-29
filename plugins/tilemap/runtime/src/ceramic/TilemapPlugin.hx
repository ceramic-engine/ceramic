package ceramic;

import ceramic.App;
import ceramic.Entity;
import ceramic.Assets;
import ceramic.AssetOptions;
import ceramic.AssetId;
import ceramic.Asset;
import ceramic.Either;

import ceramic.Shortcuts.*;

using StringTools;

@:access(ceramic.App)
class TilemapPlugin {

/// Init plugin
    
    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init tilemap plugin');

            // Extend assets with `tilemap` kind
            Assets.addAssetKind('tilemap', addTilemap, ['tmx'], false, ['ceramic.TilemapData']);

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
            done(Std.is(asset, TilemapAsset) ? cast asset : null);
        });

    }

    @:access(ceramic.Assets)
    public static function tilemap(assets:Assets, name:Either<String,AssetId<String>>):TilemapData {

        var nameStr:String = cast name;
        if (nameStr.startsWith('tilemap:')) nameStr = nameStr.substr(8);
        
        if (!assets.assetsByKindAndName.exists('tilemap')) return null;
        var asset:TilemapAsset = cast assets.assetsByKindAndName.get('tilemap').get(nameStr);
        if (asset == null) return null;

        return asset.tilemapData;

    }

}

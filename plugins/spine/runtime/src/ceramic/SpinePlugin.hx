package ceramic;

import ceramic.App;
import ceramic.Asset;
import ceramic.AssetId;
import ceramic.AssetOptions;
import ceramic.Assets;
import ceramic.ConvertSpineData;
import ceramic.Either;
import ceramic.Entity;
import ceramic.Shortcuts.*;
import ceramic.SpineAsset;
import ceramic.SpineData;
import spine.Bone;

using StringTools;

@:access(ceramic.App)
class SpinePlugin {

/// Init plugin

    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init spine plugin');

            /*
            // Generate spine asset ids
            var clazz = Type.resolveClass('assets.Spines');
            var spineIds:Map<String,String> = Reflect.field(clazz, '_ids');
            for (key in spineIds.keys()) {
                var id = spineIds.get(key);
                var info:Dynamic = Reflect.field(clazz, key);
                Reflect.setField(info, '_id', id);
            }
            */

            // Extend assets with `spine` kind
            Assets.addAssetKind('spine', addSpine, ['spine'], true, ['ceramic.SpineData']);

            // Extend converters
            var convertSpineData = new ConvertSpineData();
            ceramic.App.app.converters.set('ceramic.SpineData', convertSpineData);

            // Load additional shaders required by spine
            ceramic.App.app.onceDefaultAssetsLoad(null, function(assets) {
                assets.add('shader:tintBlack', {
                    customAttributes: [
                        { size: 4, name: 'vertexDarkColor' }
                    ]
                });
            });

        });

    }

/// Asset extensions

    public static function addSpine(assets:Assets, name:String, ?options:AssetOptions):Void {

        if (name.startsWith('spine:')) name = name.substr(6);

        assets.addAsset(new SpineAsset(name, options));

    }

    public static function ensureSpine(assets:Assets, name:Either<String,Dynamic>, ?options:AssetOptions, done:SpineAsset->Void):Void {

        var realName:String = Std.isOfType(name, String) ? cast name : cast Reflect.field(name, '_id');
        if (!realName.startsWith('spine:')) realName = 'spine:' + realName;

        assets.ensure(cast realName, options, function(asset) {
            done(Std.isOfType(asset, SpineAsset) ? cast asset : null);
        });

    }

    @:access(ceramic.Assets)
    public static function spine(assets:Assets, name:Either<String,Dynamic>):SpineData {

        var asset = spineAsset(assets, name);
        if (asset == null) return null;

        return asset.spineData;

    }

    @:access(ceramic.Assets)
    public static function spineAsset(assets:Assets, name:Either<String,Dynamic>):SpineAsset {

        var realName:String = Std.isOfType(name, String) ? cast name : cast Reflect.field(name, '_id');
        if (realName.startsWith('spine:')) realName = realName.substr(6);

        if (!assets.assetsByKindAndName.exists('spine')) return assets.parent != null ? spineAsset(assets.parent, name) : null;
        var asset:SpineAsset = cast assets.assetsByKindAndName.get('spine').get(realName);
        if (asset == null) return assets.parent != null ? spineAsset(assets.parent, name) : null;
        return asset;

    }

    inline public static function toSkeletonName(name:Dynamic):String {

        return Reflect.field(name, '_id');

    }

}

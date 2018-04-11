package plugin;

import ceramic.App;
import ceramic.Entity;
import ceramic.Assets;
import ceramic.AssetOptions;
import ceramic.AssetId;
import ceramic.Asset;
import ceramic.Either;

import plugin.spine.SpineAsset;
import plugin.spine.SpineData;
import plugin.spine.Spines;
import plugin.spine.ConvertSpineData;

import spine.Bone;

import ceramic.Shortcuts.*;

using StringTools;

@:access(ceramic.App)
class SpinePlugin {

/// Init plugin

    static function __init__():Void {

        App.oncePreInit(function() {

            log('Init spine plugin');

            // Generate spine asset ids
            var clazz = Type.resolveClass('plugin.spine.Spines');
            for (key in @:privateAccess Spines._ids.keys()) {
                var id = @:privateAccess Spines._ids.get(key);
                var info:Dynamic = Reflect.field(clazz, key);
                Reflect.setField(info, '_id', id);
            }

            // Extend assets with `spine` kind
            Assets.addAssetKind('spine', addSpine, ['spine'], true, ['plugin.spine.SpineData']);

            // Extend converters
            var convertSpineData = new ConvertSpineData();
            ceramic.App.app.converters.set('plugin.spine.SpineData', convertSpineData);

            // Load additional shaders required by spine
            ceramic.App.app.onceDefaultAssetsLoad(null, function(assets) {
                assets.add(ceramic.Shaders.TWO_COLORS);
            });

        });
    }

/// Asset extensions

    public static function addSpine(assets:Assets, name:String, ?options:AssetOptions):Void {

        if (name.startsWith('spine:')) name = name.substr(6);

        assets.addAsset(new SpineAsset(name, options));

    } //addSpine

    public static function ensureSpine(assets:Assets, name:Either<String,AssetId<Dynamic>>, ?options:AssetOptions, done:SpineAsset->Void):Void {

        var realName:String = Std.is(name, String) ? cast name : cast Reflect.field(name, '_id');
        if (!realName.startsWith('spine:')) realName = 'spine:' + realName;

        assets.ensure(cast realName, options, function(asset) {
            done(Std.is(asset, SpineAsset) ? cast asset : null);
        });

    } //ensureSpine

    @:access(ceramic.Assets)
    public static function spine(assets:Assets, name:Either<String,AssetId<Dynamic>>):SpineData {

        var realName:String = Std.is(name, String) ? cast name : cast Reflect.field(name, '_id');
        if (realName.startsWith('spine:')) realName = realName.substr(6);
        
        if (!assets.assetsByKindAndName.exists('spine')) return null;
        var asset:SpineAsset = cast assets.assetsByKindAndName.get('spine').get(realName);
        if (asset == null) return null;

        return asset.spineData;

    } //spine

} //SpinePlugin

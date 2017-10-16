package plugin;

import ceramic.App;
import ceramic.Entity;
import ceramic.Assets;
import ceramic.Either;
import ceramic.Shortcuts.*;

import spine.Bone;

using StringTools;

// Expose API
typedef Spine = plugin.spine.Spine;
typedef SpineData = plugin.spine.SpineData;
typedef SpineAsset = plugin.spine.SpineAsset;
typedef SpineTextureLoader = plugin.spine.SpineTextureLoader;

#if !macro
@:build(plugin.spine.macros.SpineMacros.buildNames())
#end
class Spines {}

@:access(ceramic.App)
class SpinePlugin {

/// Init plugin

    static function __init__():Void {
        App.oncePreInit(function() {

            App.app.logger.log('Init spine plugin');

            // Extend assets with `spine` kind
            Assets.addAssetKind('spine', addSpine, ['spine'], true);

        });
    }

/// Asset extensions

    public static function addSpine(assets:Assets, name:String, ?options:AssetOptions):Void {

        if (name.startsWith('spine:')) name = name.substr(6);

        assets.addAsset(new SpineAsset(name, options));

    } //addSpine

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

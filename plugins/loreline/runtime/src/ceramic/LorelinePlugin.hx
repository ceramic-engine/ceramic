package ceramic;

import ceramic.App;
import ceramic.Asset;
import ceramic.AssetId;
import ceramic.AssetOptions;
import ceramic.Assets;
import ceramic.Either;
import ceramic.Entity;
import ceramic.LorelineAsset;
import ceramic.Shortcuts.*;

using StringTools;

@:access(ceramic.App)
class LorelinePlugin {

/// Init plugin

    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init loreline plugin');

            // Extend assets with `loreline` kind
            Assets.addAssetKind('loreline', addLoreline, ['lor', 'loreline'], false, ['loreline.Script']);

            // Extend converters
            // TODO?

        });

    }

/// Asset extensions

    private static function _addLoreline(assets:Assets, name:String, variant:String, options:AssetOptions):Void {
        addLoreline(assets, name, variant, options);
    }

    public static function addLoreline(assets:Assets, name:String, ?variant:String, ?options:AssetOptions):Void {

        if (name.startsWith('loreline:')) name = name.substr(9);

        assets.addAsset(new LorelineAsset(name, variant, options));

    }

    public static function ensureLoreline(assets:Assets, name:Either<String,Dynamic>, ?variant:String, ?options:AssetOptions, done:LorelineAsset->Void):Void {

        if (!name.startsWith('loreline:')) name = 'loreline:' + name;

        assets.ensure(cast name, variant, options, function(asset) {
            done(Std.isOfType(asset, LorelineAsset) ? cast asset : null);
        });

    }

    @:access(ceramic.Assets)
    public static function loreline(assets:Assets, name:Either<String,Dynamic>, ?variant:String):loreline.Script {

        var asset = lorelineAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.lorelineScript;

    }

    @:access(ceramic.Assets)
    public static function lorelineAsset(assets:Assets, name:Either<String,Dynamic>, ?variant:String):LorelineAsset {

        var nameStr:String = cast name;
        if (nameStr.startsWith('loreline:')) nameStr = nameStr.substr(9);
        if (variant != null) nameStr += ':' + variant;

        if (!assets.assetsByKindAndName.exists('loreline')) return assets.parent != null ? lorelineAsset(assets.parent, nameStr, variant) : null;
        var asset:LorelineAsset = cast assets.assetsByKindAndName.get('loreline').get(nameStr);
        if (asset == null) return assets.parent != null ? lorelineAsset(assets.parent, name, variant) : null;
        return asset;

    }

}

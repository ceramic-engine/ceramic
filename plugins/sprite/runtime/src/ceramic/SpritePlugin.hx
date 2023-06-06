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

@:access(ceramic.App)
class SpritePlugin {

/// Init plugin

    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init sprite plugin');

            // Extend assets with `sprite` kind
            Assets.addAssetKind('sprite', addSprite, ['sprite', 'ase', 'aseprite'], false, ['ceramic.SpriteSheet']);

            // Extend converters
            var convertSpriteSheet = new ConvertSpriteSheet();
            ceramic.App.app.converters.set('ceramic.SpriteSheet', convertSpriteSheet);

        });

    }

/// Asset extensions

    private static function _addSprite(assets:Assets, name:String, variant:String, options:AssetOptions):Void {
        addSprite(assets, name, variant, options);
    }

    public static function addSprite(assets:Assets, name:String, ?variant:String, ?options:AssetOptions):Void {

        if (name.startsWith('sprite:')) name = name.substr(7);

        assets.addAsset(new SpriteAsset(name, variant, options));

    }

    public static function ensureSprite(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:SpriteAsset->Void):Void {

        if (!name.startsWith('sprite:')) name = 'sprite:' + name;

        assets.ensure(cast name, variant, options, function(asset) {
            done(Std.isOfType(asset, SpriteAsset) ? cast asset : null);
        });

    }

    public static function sheet(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String):SpriteSheet {

        var asset = spriteAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.sheet;

    }

    @:access(ceramic.Assets)
    public static function spriteAsset(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String):SpriteAsset {

        var nameStr:String = cast name;
        if (nameStr.startsWith('sprite:')) nameStr = nameStr.substr(7);
        if (variant != null) nameStr += ':' + variant;

        if (!assets.assetsByKindAndName.exists('sprite')) return assets.parent != null ? spriteAsset(assets.parent, name, variant) : null;
        var asset:SpriteAsset = cast assets.assetsByKindAndName.get('sprite').get(nameStr);
        if (asset == null) return assets.parent != null ? spriteAsset(assets.parent, name, variant) : null;
        return asset;

    }

}
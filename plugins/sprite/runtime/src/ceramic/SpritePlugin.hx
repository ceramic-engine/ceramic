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

/**
 * Plugin that adds sprite sheet and animation support to Ceramic.
 * 
 * Provides:
 * - SpriteAsset loading for various sprite sheet formats
 * - Sprite visual for animated sprites
 * - SpriteSystem for automatic sprite updates
 * - Asset extensions for easy sprite access
 * 
 * Supported formats:
 * - Aseprite JSON exports (.sprite files)
 * - Native Aseprite files (.ase, .aseprite) when ase plugin is enabled
 * 
 * This plugin is automatically initialized when included in the project.
 */
@:access(ceramic.App)
class SpritePlugin {

/// Init plugin

    /**
     * Initialize the sprite plugin.
     * Called automatically by Ceramic during app initialization.
     * Registers asset kinds and converters for sprite support.
     */
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

    /**
     * Internal helper for asset kind registration.
     */
    private static function _addSprite(assets:Assets, name:String, variant:String, options:AssetOptions):Void {
        addSprite(assets, name, variant, options);
    }

    /**
     * Add a sprite asset to the assets list for loading.
     * @param assets The assets instance to add to
     * @param name The sprite asset name (without 'sprite:' prefix)
     * @param variant Optional variant name
     * @param options Loading options
     */
    public static function addSprite(assets:Assets, name:String, ?variant:String, ?options:AssetOptions):Void {

        if (name.startsWith('sprite:')) name = name.substr(7);

        assets.addAsset(new SpriteAsset(name, variant, options));

    }

    /**
     * Ensure a sprite asset is loaded, loading it if necessary.
     * @param assets The assets instance
     * @param name The sprite asset name or AssetId
     * @param variant Optional variant name
     * @param options Loading options
     * @param done Callback with the loaded SpriteAsset
     */
    public static function ensureSprite(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:SpriteAsset->Void):Void {

        if (!name.startsWith('sprite:')) name = 'sprite:' + name;

        assets.ensure(cast name, variant, options, function(asset) {
            done(Std.isOfType(asset, SpriteAsset) ? cast asset : null);
        });

    }

    /**
     * Get a loaded sprite sheet by name.
     * @param assets The assets instance
     * @param name The sprite asset name or AssetId
     * @param variant Optional variant name
     * @return The SpriteSheet if loaded, null otherwise
     */
    public static function sheet(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String):SpriteSheet {

        var asset = spriteAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.sheet;

    }

    /**
     * Get a loaded sprite asset by name.
     * Searches in the current assets and parent assets if not found.
     * @param assets The assets instance
     * @param name The sprite asset name or AssetId
     * @param variant Optional variant name
     * @return The SpriteAsset if loaded, null otherwise
     */
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
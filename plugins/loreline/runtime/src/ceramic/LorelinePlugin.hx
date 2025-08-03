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

/**
 * Plugin that integrates Loreline scripting language into Ceramic.
 * 
 * Loreline is a narrative scripting language designed for:
 * - Dialogue trees and branching conversations
 * - Interactive storytelling
 * - Game narrative and quest systems
 * - Conditional story flow
 * 
 * This plugin provides:
 * - Asset loading for .lor and .loreline files
 * - Script parsing with import resolution
 * - Easy access to parsed scripts through the Assets API
 * - Hot-reload support for iterative development
 * 
 * Usage:
 * ```haxe
 * // In ceramic.yml:
 * plugins:
 *   - loreline
 * 
 * // In your code:
 * assets.add('loreline:story/chapter1');
 * var script = assets.loreline('story/chapter1');
 * ```
 * 
 * @see LorelineAsset
 * @see https://github.com/loreline/loreline for the Loreline language
 */
@:access(ceramic.App)
class LorelinePlugin {

/// Init plugin

    /**
     * Plugin initialization entry point.
     * Registers the 'loreline' asset kind with supported file extensions.
     */
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

    /**
     * Adds a Loreline asset to the assets collection.
     * @param assets The assets collection to add to
     * @param name The asset name (with or without 'loreline:' prefix)
     * @param variant Optional variant identifier
     * @param options Optional asset loading options
     */
    public static function addLoreline(assets:Assets, name:String, ?variant:String, ?options:AssetOptions):Void {

        if (name.startsWith('loreline:')) name = name.substr(9);

        assets.addAsset(new LorelineAsset(name, variant, options));

    }

    /**
     * Ensures a Loreline asset is loaded before proceeding.
     * Loads the asset if not already loaded, or returns the existing one.
     * @param assets The assets collection
     * @param name The asset name or identifier
     * @param variant Optional variant identifier
     * @param options Optional asset loading options
     * @param done Callback with the loaded LorelineAsset
     */
    public static function ensureLoreline(assets:Assets, name:Either<String,Dynamic>, ?variant:String, ?options:AssetOptions, done:LorelineAsset->Void):Void {

        if (!name.startsWith('loreline:')) name = 'loreline:' + name;

        assets.ensure(cast name, variant, options, function(asset) {
            done(Std.isOfType(asset, LorelineAsset) ? cast asset : null);
        });

    }

    /**
     * Gets a parsed Loreline script from the assets collection.
     * @param assets The assets collection
     * @param name The asset name or identifier
     * @param variant Optional variant identifier
     * @return The parsed Loreline script, or null if not found
     */
    @:access(ceramic.Assets)
    public static function loreline(assets:Assets, name:Either<String,Dynamic>, ?variant:String):loreline.Script {

        var asset = lorelineAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.lorelineScript;

    }

    /**
     * Gets a LorelineAsset from the assets collection.
     * @param assets The assets collection
     * @param name The asset name or identifier
     * @param variant Optional variant identifier
     * @return The LorelineAsset, or null if not found
     */
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

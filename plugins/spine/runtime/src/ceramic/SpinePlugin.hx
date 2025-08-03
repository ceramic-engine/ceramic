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
import haxe.Constraints.NotVoid;
import spine.Bone;

using StringTools;

/**
 * Plugin that integrates the Spine 2D skeletal animation runtime into Ceramic.
 * 
 * This plugin extends Ceramic's asset system to support loading and managing
 * Spine animations, including skeleton data, texture atlases, and animation
 * configurations. It provides convenient methods for loading Spine assets
 * and accessing them throughout your application.
 * 
 * The plugin automatically:
 * - Registers the 'spine' asset kind with the asset system
 * - Sets up SpineData converters for serialization
 * - Loads required shaders for two-color tinting support
 * - Provides helper methods for accessing Spine assets
 * 
 * @example Loading Spine assets
 * ```haxe
 * // Add a spine asset to load
 * assets.add(Spines.HERO);
 * 
 * // Load and use
 * assets.load(function(success) {
 *     if (success) {
 *         var heroData = assets.spine(Spines.HERO);
 *         var spine = new Spine();
 *         spine.spineData = heroData;
 *         spine.animate("idle", true);
 *     }
 * });
 * ```
 */
@:access(ceramic.App)
class SpinePlugin {

/// Init plugin

    /**
     * Initializes the Spine plugin during Ceramic's pre-initialization phase.
     * 
     * This method is called automatically by Ceramic's plugin system and:
     * - Registers the 'spine' asset kind for .spine file support
     * - Sets up the SpineData converter for serialization/deserialization
     * - Loads the tintBlack shader required for two-color tinting in Spine
     * 
     * The plugin initialization happens before the main app initialization,
     * ensuring Spine assets can be loaded during the app's startup phase.
     */
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

    /**
     * Internal wrapper for addSpine to match the expected asset loader signature.
     * This method is registered with the asset system during plugin initialization.
     */
    private static function _addSpine(assets:Assets, name:String, variant:String, options:AssetOptions):Void {
        addSpine(assets, name, variant, options);
    }

    /**
     * Adds a Spine asset to the asset loading queue.
     * 
     * This method creates a new SpineAsset instance and registers it with
     * the asset system for loading. The asset will be loaded when assets.load()
     * is called.
     * 
     * @param assets The Assets instance to add the spine asset to
     * @param name The asset name/path (with or without 'spine:' prefix)
     * @param variant Optional variant name for different versions of the same asset
     * @param options Optional loading options (density, filter, etc.)
     * 
     * @example
     * ```haxe
     * assets.addSpine("characters/hero");
     * assets.addSpine("spine:characters/hero");  // Same as above
     * assets.addSpine("characters/hero", "hd");  // HD variant
     * ```
     */
    public static function addSpine(assets:Assets, name:String, ?variant:String, ?options:AssetOptions):Void {

        if (name.startsWith('spine:')) name = name.substr(6);

        assets.addAsset(new SpineAsset(name, variant, options));

    }

    /**
     * Ensures a Spine asset is loaded before executing a callback.
     * 
     * This method checks if the specified Spine asset is already loaded.
     * If not, it loads the asset first. Once the asset is available,
     * the callback is executed with the loaded SpineAsset.
     * 
     * @param assets The Assets instance to check/load from
     * @param name Asset identifier - either a string name or an object with _id field
     * @param variant Optional variant name
     * @param options Optional loading options
     * @param done Callback executed with the loaded SpineAsset (or null if loading failed)
     * 
     * @example
     * ```haxe
     * assets.ensureSpine(Spines.HERO, function(asset) {
     *     if (asset != null) {
     *         var spine = new Spine();
     *         spine.spineData = asset.spineData;
     *     }
     * });
     * ```
     */
    public static function ensureSpine(assets:Assets, name:Either<String,Dynamic>, ?variant:String, ?options:AssetOptions, done:SpineAsset->Void):Void {

        var realName:String = Std.isOfType(name, String) ? cast name : cast Reflect.field(name, '_id');
        if (!realName.startsWith('spine:')) realName = 'spine:' + realName;

        assets.ensure(cast realName, variant, options, function(asset) {
            done(Std.isOfType(asset, SpineAsset) ? cast asset : null);
        });

    }

    /**
     * Retrieves the SpineData for a loaded Spine asset.
     * 
     * This is a convenience method that gets the SpineAsset and returns
     * its spineData property. Returns null if the asset is not found or
     * not yet loaded.
     * 
     * @param assets The Assets instance to retrieve from
     * @param name Asset identifier - either a string name or an object with _id field
     * @param variant Optional variant name
     * @return The SpineData instance, or null if not found/loaded
     * 
     * @example
     * ```haxe
     * var heroData = assets.spine(Spines.HERO);
     * if (heroData != null) {
     *     var spine = new Spine();
     *     spine.spineData = heroData;
     * }
     * ```
     */
    @:access(ceramic.Assets)
    public static function spine(assets:Assets, name:Either<String,Dynamic>, ?variant:String):SpineData {

        var asset = spineAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.spineData;

    }

    /**
     * Retrieves a SpineAsset from the asset system.
     * 
     * This method looks up a Spine asset by name and variant, checking both
     * the current Assets instance and its parent hierarchy if not found.
     * The 'spine:' prefix is handled automatically.
     * 
     * @param assets The Assets instance to search in
     * @param name Asset identifier - either a string name or an object with _id field
     * @param variant Optional variant name
     * @return The SpineAsset if found, null otherwise
     * 
     * @example
     * ```haxe
     * var asset = assets.spineAsset("characters/hero");
     * if (asset != null && asset.status == READY) {
     *     // Asset is loaded and ready to use
     * }
     * ```
     */
    @:access(ceramic.Assets)
    public static function spineAsset(assets:Assets, name:Either<String,Dynamic>, ?variant:String):SpineAsset {

        var realName:String = Std.isOfType(name, String) ? cast name : cast Reflect.field(name, '_id');
        if (realName.startsWith('spine:')) realName = realName.substr(6);
        if (variant != null) realName += ':' + variant;

        if (!assets.assetsByKindAndName.exists('spine')) return assets.parent != null ? spineAsset(assets.parent, name, variant) : null;
        var asset:SpineAsset = cast assets.assetsByKindAndName.get('spine').get(realName);
        if (asset == null) return assets.parent != null ? spineAsset(assets.parent, name, variant) : null;
        return asset;

    }

    /**
     * Converts a dynamic asset reference to its skeleton name string.
     * 
     * This utility method extracts the '_id' field from asset constant objects
     * generated by the build system (e.g., from the Spines class).
     * 
     * @param name An asset constant object with an _id field
     * @return The string identifier for the skeleton
     * 
     * @example
     * ```haxe
     * var skeletonName = SpinePlugin.toSkeletonName(Spines.HERO);
     * // Returns something like "characters/hero"
     * ```
     */
    inline public static function toSkeletonName(name:Dynamic):String {

        return Reflect.field(name, '_id');

    }

}

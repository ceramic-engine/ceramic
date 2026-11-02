// Original code (not a port), written for the Ceramic vector plugin.
// The asset kind registration follows the other Ceramic plugins (ase, spine, ttf).
// MIT License, see Ceramic's LICENSE file.
package ceramic;

import ceramic.App;
import ceramic.Asset;
import ceramic.AssetId;
import ceramic.AssetOptions;
import ceramic.Assets;
import ceramic.Either;
import ceramic.Shortcuts.*;

using StringTools;

/**
 * Plugin adding 2D vector graphics and SVG support to Ceramic, built on the
 * pure Haxe ports of plutovg (rasterizer) and lunasvg (SVG documents).
 *
 * Provides:
 * - an `svg` asset kind for `.svg` files (`SvgAsset`: source, lunasvg `Document`,
 *   cached textures following the texture density);
 * - `SvgQuad`: a quad displaying an SVG document rasterized at its own size;
 * - `VectorCanvas`: plutovg drawing from code into a texture;
 * - `VectorTextures`: conversions from plutovg surfaces and lunasvg documents to textures.
 *
 * ```haxe
 * assets.add('svg:icons/heart');
 * assets.onceComplete(this, success -> {
 *     var icon = new SvgQuad();
 *     icon.asset = assets.svgAsset('icons/heart');
 *     icon.size(48, 48);
 *     icon.setCurrentColor(Color.RED);
 *     add(icon);
 * });
 * ```
 *
 * The methods below are static extensions of `Assets` (`assets.svgAsset(...)`).
 */
@:access(ceramic.App)
class VectorPlugin {

/// Init plugin

    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init vector plugin');

            // Extend assets with `svg` kind
            Assets.addAssetKind('svg', _addSvg, ['svg'], false, ['lunasvg.Document']);

        });

    }

/// Asset extensions

    private static function _addSvg(assets:Assets, name:String, variant:String, options:AssetOptions):Void {
        addSvg(assets, name, variant, options);
    }

    /**
     * Add an SVG asset to the assets list for loading.
     * @param assets The assets instance to add to
     * @param name The asset name (with or without `svg:` prefix)
     * @param variant Optional variant name
     * @param options Loading options
     */
    public static function addSvg(assets:Assets, name:String, ?variant:String, ?options:AssetOptions):Void {

        if (name.startsWith('svg:')) name = name.substr(4);

        assets.addAsset(new SvgAsset(name, variant, options));

    }

    /**
     * Ensure an SVG asset is loaded, loading it if necessary.
     */
    public static function ensureSvg(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:SvgAsset->Void):Void {

        if (!name.startsWith('svg:')) name = 'svg:' + name;

        assets.ensure(cast name, variant, options, function(asset) {
            done(Std.isOfType(asset, SvgAsset) ? cast asset : null);
        });

    }

    /**
     * Get a loaded SVG asset by name (searching parent assets too).
     */
    @:access(ceramic.Assets)
    public static function svgAsset(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String):SvgAsset {

        var nameStr:String = cast name;
        if (nameStr.startsWith('svg:')) nameStr = nameStr.substr(4);
        if (variant != null) nameStr += ':' + variant;

        if (!assets.assetsByKindAndName.exists('svg')) return assets.parent != null ? svgAsset(assets.parent, name, variant) : null;
        var asset:SvgAsset = cast assets.assetsByKindAndName.get('svg').get(nameStr);
        if (asset == null) return assets.parent != null ? svgAsset(assets.parent, name, variant) : null;
        return asset;

    }

    /**
     * Get the document of a loaded SVG asset (shared by every user of the asset).
     */
    public static function svg(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String):lunasvg.Document {

        var asset = svgAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.document;

    }

    /**
     * Get a texture of a loaded SVG asset rasterized at `width` x `height`
     * (cached by the asset, see `SvgAsset.texture()`).
     */
    public static function svgTexture(assets:Assets, name:Either<String,AssetId<String>>, width:Float = -1, height:Float = -1, ?variant:String):Texture {

        var asset = svgAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.texture(width, height);

    }

}

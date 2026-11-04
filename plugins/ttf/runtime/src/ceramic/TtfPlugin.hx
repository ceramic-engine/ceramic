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
 * Plugin that adds runtime TrueType / OpenType font support to Ceramic,
 * built on the pure Haxe `ttf` library (parsing, shaping, rasterization)
 * and `plutovg` (anti-aliased scan converter).
 *
 * Provides:
 * - a `ttf` asset kind for `.ttf`, `.otf`, `.ttc` and `.otc` files (`TtfFontAsset`)
 * - `DynamicBitmapFont`: a `BitmapFont` whose glyphs are rasterized on demand,
 *   so that `ceramic.Text` can display any TrueType / OpenType font directly
 * - `TtfText`: a visual that renders shaped text (kerning, ligatures, font fallback,
 *   subpixel positioning) from a shared glyph atlas
 * - `TtfGlyphAtlas`: dynamic glyph atlas pages uploaded with partial texture updates
 *
 * ```haxe
 * assets.add('ttf:fonts/Inter-Regular');
 * assets.onceComplete(this, success -> {
 *     var text = new Text();
 *     text.font = assets.ttfBitmapFont('fonts/Inter-Regular', 24);
 *     text.pointSize = 24;
 *     text.content = 'Hello from a TrueType font';
 *     add(text);
 * });
 * ```
 *
 * Note: the built-in `font` tools plugin converts `.ttf` / `.otf` assets into
 * MSDF bitmap fonts at build time and does not ship the original files.
 * Until that conversion can be disabled for runtime fonts, ship runtime fonts
 * as collections (`.ttc` / `.otc`, never converted) or load them from bytes
 * with `TtfFontAsset.fromBytes()` / `ttf.Font.fromBytes()`.
 */
@:access(ceramic.App)
class TtfPlugin {

/// Init plugin

    static function pluginInit() {

        App.oncePreInit(function() {

            log.info('Init ttf plugin');

            // Extend assets with `ttf` kind
            Assets.addAssetKind('ttf', _addTtf, ['ttf', 'otf', 'ttc', 'otc'], false, ['ttf.Font']);

        });

    }

/// Asset extensions

    private static function _addTtf(assets:Assets, name:String, variant:String, options:AssetOptions):Void {
        addTtf(assets, name, variant, options);
    }

    /**
     * Add a TrueType / OpenType font asset to the assets list for loading.
     * @param assets The assets instance to add to
     * @param name The font asset name (without `ttf:` prefix)
     * @param variant Optional variant name
     * @param options Loading options
     */
    public static function addTtf(assets:Assets, name:String, ?variant:String, ?options:AssetOptions):Void {

        if (name.startsWith('ttf:')) name = name.substr(4);

        assets.addAsset(new TtfFontAsset(name, variant, options));

    }

    /**
     * Ensure a font asset is loaded, loading it if necessary.
     */
    public static function ensureTtf(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:(TtfFontAsset) -> Void):Void {

        if (!name.startsWith('ttf:')) name = 'ttf:' + name;

        assets.ensure(cast name, variant, options, function(asset) {
            done(Std.isOfType(asset, TtfFontAsset) ? cast asset : null);
        });

    }

    /**
     * Get a loaded font asset by name (searching parent assets too).
     */
    @:access(ceramic.Assets)
    public static function ttfAsset(assets:Assets, name:Either<String,AssetId<String>>, ?variant:String):TtfFontAsset {

        var nameStr:String = cast name;
        if (nameStr.startsWith('ttf:')) nameStr = nameStr.substr(4);
        if (variant != null) nameStr += ':' + variant;

        if (!assets.assetsByKindAndName.exists('ttf')) return assets.parent != null ? ttfAsset(assets.parent, name, variant) : null;
        var asset:TtfFontAsset = cast assets.assetsByKindAndName.get('ttf').get(nameStr);
        if (asset == null) return assets.parent != null ? ttfAsset(assets.parent, name, variant) : null;
        return asset;

    }

    /**
     * Get a loaded font face (`faceIndex` selects a face of a collection).
     */
    public static function ttfFont(assets:Assets, name:Either<String,AssetId<String>>, faceIndex:Int = 0, ?variant:String):ttf.Font {

        var asset = ttfAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.face(faceIndex);

    }

    /**
     * Get a `BitmapFont` rasterizing the font on demand at `pixelSize`
     * (cached by the asset, see `TtfFontAsset.bitmapFont()`).
     */
    public static function ttfBitmapFont(assets:Assets, name:Either<String,AssetId<String>>, pixelSize:Float, faceIndex:Int = 0, ?variant:String):DynamicBitmapFont {

        var asset = ttfAsset(assets, name, variant);
        if (asset == null) return null;

        return asset.bitmapFont(pixelSize, faceIndex);

    }

}

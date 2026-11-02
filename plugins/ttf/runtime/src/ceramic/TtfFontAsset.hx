package ceramic;

import ceramic.Shortcuts.*;
import haxe.io.Bytes;

using StringTools;

/**
 * Asset loader for TrueType / OpenType fonts (`.ttf`, `.otf`) and font
 * collections (`.ttc`, `.otc`).
 *
 * The font file is loaded as binary data and parsed with the `ttf` library.
 * Every face of a collection is available with `face(index)`.
 *
 * ```haxe
 * assets.add('ttf:fonts/Inter');
 * assets.onceComplete(this, success -> {
 *     var asset = assets.ttfAsset('fonts/Inter');
 *     var font = asset.bitmapFont(16); // BitmapFont for ceramic.Text
 * });
 * ```
 */
class TtfFontAsset extends Asset {

/// Properties

    /**
     * Raw font file data.
     */
    public var bytes(default, null):Bytes = null;

    /**
     * Faces of the font file (a single face unless the file is a collection).
     */
    @observe public var faces:Array<ttf.Font> = null;

    /**
     * The first face of the font file.
     */
    public var font(get, never):ttf.Font;
    function get_font():ttf.Font {
        return faces != null && faces.length > 0 ? faces[0] : null;
    }

    /**
     * Bitmap fonts created by `bitmapFont()`, by face and size.
     */
    var bitmapFonts:Map<String, DynamicBitmapFont> = null;

/// Lifecycle

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('ttf', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    /**
     * Load the font file.
     */
    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load ttf asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log.info('Load ttf $path');

        var realPath = Assets.realAssetPath(path, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.binaries.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
        }

        app.backend.binaries.load(realPath, options, function(bytes) {

            if (bytes == null) {
                status = BROKEN;
                log.error('Failed to load ttf at path: $path');
                emitComplete(false);
                return;
            }

            try {
                setBytes(bytes);
                status = READY;
                emitComplete(true);
            }
            catch (e:Dynamic) {
                status = BROKEN;
                log.error('Failed to parse ttf at path: $path ($e)');
                emitComplete(false);
            }

        });

    }

    /**
     * Parses the given font data (every face of a collection).
     */
    function setBytes(bytes:Bytes):Void {

        var count = ttf.Font.faceCount(bytes);
        if (count <= 0)
            throw 'Unsupported font data';

        var newFaces:Array<ttf.Font> = [];
        for (i in 0...count) {
            newFaces.push(ttf.Font.fromBytes(bytes, i));
        }

        this.bytes = bytes;
        this.faces = newFaces;

    }

    /**
     * Creates an asset from font data already in memory (not managed by `Assets`).
     */
    public static function fromBytes(name:String, bytes:Bytes):TtfFontAsset {

        var asset = new TtfFontAsset(name);
        asset.setBytes(bytes);
        asset.status = READY;
        return asset;

    }

    override function destroy():Void {

        super.destroy();

        if (bitmapFonts != null) {
            var fonts = bitmapFonts;
            bitmapFonts = null;
            for (font in fonts) {
                font.asset = null;
                font.destroy();
            }
        }

        faces = null;
        bytes = null;

    }

/// Public API

    /**
     * Returns the face at `index` (0 for single fonts), or null.
     */
    public function face(index:Int = 0):ttf.Font {

        if (faces == null || index < 0 || index >= faces.length)
            return null;
        return faces[index];

    }

    /**
     * Returns a `BitmapFont` that rasterizes this font on demand at
     * `pixelSize` (logical pixels, multiplied by `screen.texturesDensity`
     * for the actual rendering). Fonts are cached by face, size and density.
     */
    public function bitmapFont(pixelSize:Float, faceIndex:Int = 0, ?fallbacks:Array<ttf.Font>):DynamicBitmapFont {

        var font = face(faceIndex);
        if (font == null)
            return null;

        var density = screen.texturesDensity;
        var key = faceIndex + ':' + pixelSize + ':' + density;
        if (fallbacks == null) {
            if (bitmapFonts == null)
                bitmapFonts = new Map();
            var existing = bitmapFonts.get(key);
            if (existing != null && !existing.destroyed)
                return existing;
        }

        var bitmapFont = new DynamicBitmapFont(font, pixelSize, density, fallbacks);
        if (fallbacks == null)
            bitmapFonts.set(key, bitmapFont);
        return bitmapFont;

    }

}

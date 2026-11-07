// Original code (not a port), written for Glaze.
// MIT License, see Ceramic's LICENSE file.
package glaze.platform;

import haxe.io.Bytes;

/**
 * The emoji font bundled with the glaze plugin: Noto Color Emoji (`CBDT` /
 * `CBLC` bitmaps, `GSUB` sequences), shipped only when the define
 * `glaze_bundled_emoji` is set (the plugin's `emoji-font/assets` folder, see
 * `emoji-font/README.md` for its origin and licenses).
 *
 * With the define, the plugin adds it to `glaze.App.defaultTextSystem()` once
 * the default assets are loaded (see `ceramic.GlazePlugin`), after the
 * bundled text fonts:
 *
 * - on native targets (and Node.js), the file is read piece by piece
 *   (`ttf.Font.fromSource()` over `ceramic.Files.getBytesRange()`), like the
 *   system emoji font of `SystemFontFallback`: about 95 KB of tables at
 *   startup, then the images of the emoji drawn;
 * - in browsers, it is a binary asset loaded with the default assets (the
 *   whole file).
 *
 * The face is then a face of the font database (`CeramicTextSystem.addBundledEmojiFace()`),
 * so emoji graphemes it covers use it before the system emoji font and
 * before the browser canvas, which still supply what it lacks. Its
 * PostScript name makes it GPUI's known emoji font (polychrome glyphs, the
 * glyph 3 hack of `cosmic_text_system.rs`).
 */
class BundledEmojiFont {

    /** Asset path of the font file (in the plugin's `emoji-font/assets`) */
    public static final ASSET_PATH:String = 'glaze/emoji/NotoColorEmoji.ttf.bin';

    /** PostScript name of the bundled face */
    public static final POSTSCRIPT_NAME:String = 'NotoColorEmoji';

    /** Whether this build ships the font (define `glaze_bundled_emoji`) */
    public static inline function enabled():Bool {
        #if glaze_bundled_emoji
        return true;
        #else
        return false;
        #end
    }

    /** Time spent opening the font, in seconds (the last `open*()` call) */
    public static var loadTime(default, null):Float = 0;

    /** Bytes read to open the font (the last `open*()` call) */
    public static var loadedBytes(default, null):Float = 0;

    /**
     * File path of the shipped font on targets with a file system: the
     * assets folder of the app joined with the asset path.
     */
    public static function filePath():String {
        var assetsPath = 'assets';
        try {
            if (ceramic.App.app != null && ceramic.App.app.settings != null)
                assetsPath = ceramic.App.app.settings.assetsPath;
        }
        catch (e:Dynamic) {}
        final path = ceramic.Assets.realAssetPath(ASSET_PATH);
        return ceramic.Path.isAbsolute(path) ? path : ceramic.Path.join([assetsPath, path]);
    }

    /**
     * Opens the font file at `path` with its bitmap tables left in the file
     * (read on demand through `ceramic.Files.getBytesRange()`), or returns
     * null if it cannot be read.
     */
    public static function openFile(path:String):Null<ttf.Font> {
        final start = haxe.Timer.stamp();
        loadedBytes = 0;
        try {
            if (!ceramic.Files.exists(path))
                return null;
            final size = ceramic.Files.getSize(path);
            if (size <= 0 || size > 0x7FFFFFFF)
                return null;
            var read = 0.0;
            final source = new ttf.FontSource.FunctionFontSource(Std.int(size), (offset, length) -> {
                read += length;
                return ceramic.Files.getBytesRange(path, offset, length);
            });
            final face = ttf.Font.fromSource(source, 0);
            loadedBytes = read;
            loadTime = haxe.Timer.stamp() - start;
            return isBundledFace(face) ? face : null;
        }
        catch (e:Dynamic) {
            loadTime = haxe.Timer.stamp() - start;
            return null;
        }
    }

    /** Parses the font from its whole file content (browsers), or returns null */
    public static function openBytes(bytes:Null<Bytes>):Null<ttf.Font> {
        final start = haxe.Timer.stamp();
        loadedBytes = 0;
        if (bytes == null)
            return null;
        try {
            final face = ttf.Font.fromBytes(bytes, 0);
            loadedBytes = bytes.length;
            loadTime = haxe.Timer.stamp() - start;
            return isBundledFace(face) ? face : null;
        }
        catch (e:Dynamic) {
            loadTime = haxe.Timer.stamp() - start;
            return null;
        }
    }

    static function isBundledFace(face:Null<ttf.Font>):Bool {
        return face != null && face.numGlyphs > 1 && face.hasColorGlyphs && face.postScriptName == POSTSCRIPT_NAME;
    }

    /**
     * Adds the face to a text system as its bundled emoji font (see
     * `CeramicTextSystem.addBundledEmojiFace()`). Returns false when the
     * text system is not a `CeramicTextSystem` or already has it.
     */
    public static function addTo(platform:glaze.PlatformTextSystem, face:ttf.Font):Bool {
        if (!(platform is CeramicTextSystem))
            return false;
        final ceramicTextSystem:CeramicTextSystem = cast platform;
        if (ceramicTextSystem.bundledEmojiFace != null)
            return false;
        ceramicTextSystem.addBundledEmojiFace(face);
        return true;
    }
}

// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Utf8;
import haxe.ds.IntMap;
import haxe.io.Bytes;

/**
 * The GPUI text rendering sub system.
 *
 * Differences with GPUI: single threaded (no locks), errors are thrown,
 * missing glyph reporting (an async channel used by Zed to download fonts)
 * is not ported, and line wrappers are kept per font and size instead of
 * being lent through a `LineWrapperHandle`.
 */
class TextSystem {

    /** Number of subpixel glyph variants along the X axis. */
    public static inline final SUBPIXEL_VARIANTS_X:Int = 4;

    /** Number of subpixel glyph variants along the Y axis. */
    public static inline final SUBPIXEL_VARIANTS_Y:Int = 1;

    // Leave enough room below the underline for its stroke while keeping it below the baseline.
    static inline final UNDERLINE_DESCENT_OFFSET_FACTOR:Float = 0.618;

    /**
     * Returns the vertical offset used to paint an underline within a line.
     */
    public static inline function underlineYOffset(lineHeight:Pixels, ascent:Pixels, descent:Pixels):Pixels {
        final paddingTop = (lineHeight - ascent - descent) / 2.0;
        return paddingTop + ascent + descent * UNDERLINE_DESCENT_OFFSET_FACTOR;
    }

    public var platformTextSystem(default, null):PlatformTextSystem;

    final fontIdsByFont:Map<String, CachedFont> = new Map();

    /** Fonts of `fontIdsByFont`, by key (to answer `getFontForId()`) */
    final fontsByKey:Map<String, Font> = new Map();

    final fontMetrics:IntMap<FontMetrics> = new IntMap();

    final rasterBoundsCache:GlyphCache<Bounds> = new GlyphCache();

    /** Line wrappers by font id, then by exact font size (few sizes per font) */
    final wrapperPool:haxe.ds.IntMap<Array<LineWrapper>> = new haxe.ds.IntMap();

    /**
     * Families tried, in order, when a font cannot be resolved.
     */
    public var fallbackFontStack:Array<Font>;

    /** Incremented when fonts are added (invalidates line layout caches) */
    public var fontGeneration(default, null):Int = 0;

    final charBuffer:Array<FontRun> = [new FontRun(0, 0)];

    /**
     * Create a new TextSystem with the given platform text system.
     */
    public function new(platformTextSystem:PlatformTextSystem) {
        this.platformTextSystem = platformTextSystem;
        fallbackFontStack = [
            // TODO: Remove this when Linux have implemented setting fallbacks.
            Font.of('.ZedMono'),
            Font.of('.ZedSans'),
            Font.of('Helvetica'),
            Font.of('Segoe UI'), // Windows
            Font.of('Ubuntu'), // Gnome (Ubuntu)
            Font.of('Adwaita Sans'), // Gnome 47
            Font.of('Cantarell'), // Gnome
            Font.of('Noto Sans'), // KDE
            Font.of('DejaVu Sans'),
            Font.of('Arial'), // macOS, Windows
        ];
    }

    /**
     * Get sorted, unique font family names available to the platform text system.
     */
    public function allFontNames():Array<String> {
        final names = platformTextSystem.allFontNames().copy();
        names.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        final result:Array<String> = [];
        for (name in names) {
            if (result.length == 0 || result[result.length - 1] != name)
                result.push(name);
        }
        return result;
    }

    /**
     * Add a font's data to the text system.
     *
     * Cached font resolution and line layouts are invalidated after installation.
     */
    public function addFonts(fonts:Array<Bytes>):Void {
        platformTextSystem.addFonts(fonts);
        fontIdsByFont.clear();
        fontsByKey.clear();
        fontGeneration++;
    }

    /**
     * Get the Font for the Font Id.
     */
    public function getFontForId(id:FontId):Null<Font> {
        for (key => cached in fontIdsByFont) {
            switch cached {
                case Direct(fontId) if ((fontId:Int) == (id:Int)):
                    return fontsByKey.get(key);
                case _:
            }
        }
        return null;
    }

    /**
     * Resolves the specified font, falling back to the default font stack if
     * the font fails to load.
     *
     * Throws if the font and none of the fallbacks can be resolved.
     */
    public function resolveFont(font:Font):FontId {
        final cached = fontIdsByFont.get(font.key());
        if (cached != null) {
            switch cached {
                case Direct(fontId) | Fallback(fontId):
                    return fontId;
                case Missing(_):
            }
        }
        return resolveFontUncached(font);
    }

    /** Sets the cached resolution of a font (used by tests). */
    public function setCachedFont(font:Font, cached:CachedFont):Void {
        final key = font.key();
        fontIdsByFont.set(key, cached);
        fontsByKey.set(key, font);
    }

    function resolveFontUncached(font:Font):FontId {
        var fontError:Null<String> = null;
        final fontKey = font.key();

        function lookupFont(candidate:Font):Null<FontId> {
            final key = candidate.key();
            var cached = fontIdsByFont.get(key);
            if (cached == null) {
                cached = try {
                    Direct(platformTextSystem.fontId(candidate));
                }
                catch (e:Dynamic) {
                    Missing(Std.string(e));
                }
                fontIdsByFont.set(key, cached);
                fontsByKey.set(key, candidate);
            }
            return switch cached {
                case Direct(fontId): fontId;
                case Fallback(_): null;
                case Missing(error):
                    if (key == fontKey) {
                        fontError = error;
                    }
                    null;
            }
        }

        var fontId:Null<FontId> = lookupFont(font);
        if (fontId == null) {
            for (fallback in fallbackFontStack) {
                fontId = lookupFont(fallback);
                if (fontId != null)
                    break;
            }
            if (fontId != null) {
                fontIdsByFont.set(fontKey, Fallback(fontId));
                fontsByKey.set(fontKey, font);
            }
        }
        if (fontError != null) {
            ceramic.Shortcuts.log.warning('failed to load font $font: $fontError');
        }
        if (fontId == null) {
            throw 'failed to resolve font \'${font.family}\' or any of the fallbacks: ' + [for (f in fallbackFontStack) f.family].join(', ');
        }
        return fontId;
    }

    /**
     * Get the bounding box for the given font and font size.
     * A font's bounding box is the smallest rectangle that could enclose all glyphs
     * in the font. superimposed over one another.
     */
    public function boundingBox(fontId:FontId, fontSize:Pixels):Bounds {
        return readMetrics(fontId).boundingBoxAt(fontSize);
    }

    /**
     * Get the typographic bounds for the given character, in the given font and size.
     * Throws if the font has no glyph for the character.
     */
    public function typographicBounds(fontId:FontId, fontSize:Pixels, character:Int):Bounds {
        final glyphId = platformTextSystem.glyphForChar(fontId, character);
        if (glyphId == null)
            throw 'glyph not found for character \'${Utf8.fromCodePoint(character)}\'';
        final bounds = platformTextSystem.typographicBounds(fontId, glyphId);
        final metrics = readMetrics(fontId);
        return FontMetrics.scaleBounds(bounds, metrics.unitsPerEm, fontSize);
    }

    /**
     * Get the advance width for the given character, in the given font and size.
     * Throws if the font has no glyph for the character.
     */
    public function advance(fontId:FontId, fontSize:Pixels, ch:Int):Size {
        final glyphId = platformTextSystem.glyphForChar(fontId, ch);
        if (glyphId == null)
            throw 'glyph not found for character \'${Utf8.fromCodePoint(ch)}\'';
        // In f32, like GPUI
        final advance = platformTextSystem.advance(fontId, glyphId);
        final unitsPerEm = unitsPerEm(fontId);
        final size = SpringMath.f32(fontSize);
        return new Size(SpringMath.f32(SpringMath.f32(advance.width / unitsPerEm) * size), SpringMath.f32(SpringMath.f32(advance.height / unitsPerEm) * size));
    }

    /**
     * Returns the shaped layout width of for the given character, in the given font and size.
     */
    public function layoutWidth(fontId:FontId, fontSize:Pixels, ch:Int):Pixels {
        final run = charBuffer[0];
        run.len = Utf8.codePointLength(ch);
        run.fontId = fontId;
        return platformTextSystem.layoutLine(Utf8.fromCodePoint(ch), fontSize, charBuffer).width;
    }

    /**
     * Returns the width of an `em` (the width of the `m` character).
     */
    public function emWidth(fontId:FontId, fontSize:Pixels):Pixels {
        return typographicBounds(fontId, fontSize, 'm'.code).size.width;
    }

    /**
     * Returns the advance width of an `em` (the advance of the `m` character).
     */
    public function emAdvance(fontId:FontId, fontSize:Pixels):Pixels {
        return advance(fontId, fontSize, 'm'.code).width;
    }

    /**
     * Returns the width of an `ch` (the width of the `0` character).
     */
    public function chWidth(fontId:FontId, fontSize:Pixels):Pixels {
        return typographicBounds(fontId, fontSize, '0'.code).size.width;
    }

    /**
     * Returns the advance width of an `ch` (the advance of the `0` character).
     */
    public function chAdvance(fontId:FontId, fontSize:Pixels):Pixels {
        return advance(fontId, fontSize, '0'.code).width;
    }

    /**
     * Get the number of font size units per 'em square'.
     */
    public function unitsPerEm(fontId:FontId):Int {
        return readMetrics(fontId).unitsPerEm;
    }

    /**
     * Get the height of a capital letter in the given font and size.
     */
    public function capHeight(fontId:FontId, fontSize:Pixels):Pixels {
        return readMetrics(fontId).capHeightAt(fontSize);
    }

    /**
     * Get the height of the x character in the given font and size.
     */
    public function xHeight(fontId:FontId, fontSize:Pixels):Pixels {
        return readMetrics(fontId).xHeightAt(fontSize);
    }

    /**
     * Get the recommended distance from the baseline for the given font
     */
    public function ascent(fontId:FontId, fontSize:Pixels):Pixels {
        return readMetrics(fontId).ascentAt(fontSize);
    }

    /**
     * Get the recommended distance below the baseline for the given font,
     * in single spaced text.
     */
    public function descent(fontId:FontId, fontSize:Pixels):Pixels {
        return readMetrics(fontId).descentAt(fontSize);
    }

    /**
     * Get the recommended baseline offset for the given font and line height.
     */
    public function baselineOffset(fontId:FontId, fontSize:Pixels, lineHeight:Pixels):Pixels {
        final ascent:Float = ascent(fontId, fontSize);
        final descent:Float = descent(fontId, fontSize);
        // In f32, like GPUI
        final paddingTop = SpringMath.f32(SpringMath.f32(SpringMath.f32((lineHeight:Float) - ascent) - descent) / 2.0);
        return SpringMath.f32(paddingTop + ascent);
    }

    /**
     * Metrics of a font (cached).
     */
    public function readMetrics(fontId:FontId):FontMetrics {
        var metrics = fontMetrics.get(fontId);
        if (metrics == null) {
            metrics = platformTextSystem.fontMetrics(fontId);
            fontMetrics.set(fontId, metrics);
        }
        return metrics;
    }

    /**
     * Returns a line wrapper for the given font and font size. Wrappers
     * cache character widths and are reused (one per font id and size).
     */
    public function lineWrapper(font:Font, fontSize:Pixels):LineWrapper {
        final fontId = resolveFont(font);
        var wrappers = wrapperPool.get(fontId);
        if (wrappers == null) {
            wrappers = [];
            wrapperPool.set(fontId, wrappers);
        }
        final size:Float = fontSize;
        for (i in 0...wrappers.length) {
            final wrapper = wrappers[i];
            if ((wrapper.fontSize:Float) == size) {
                return wrapper;
            }
        }
        final wrapper = new LineWrapper(fontId, fontSize, this);
        wrappers.push(wrapper);
        return wrapper;
    }

    /**
     * Get the rasterized size and location of a specific, rendered glyph
     * (cached). The returned bounds must not be modified.
     */
    public function rasterBounds(params:RenderGlyphParams):Bounds {
        var bounds = rasterBoundsCache.get(params);
        if (bounds == null) {
            bounds = platformTextSystem.glyphRasterBounds(params);
            rasterBoundsCache.set(params.clone(), bounds);
        }
        return bounds;
    }

    /**
     * Rasterizes a glyph (8-bit coverage, the size of its raster bounds).
     */
    public function rasterizeGlyph(params:RenderGlyphParams):Bytes {
        final rasterBounds = rasterBounds(params);
        return platformTextSystem.rasterizeGlyph(params, rasterBounds);
    }

    /**
     * Returns the dilation level to use for a glyph painted in the given color.
     */
    public inline function glyphDilationForColor(color:Hsla):Int {
        return platformTextSystem.glyphDilationForColor(color);
    }

    /**
     * Returns the text rendering mode recommended by the platform for the given font and size.
     * The return value will never be `PlatformDefault`.
     */
    public inline function recommendedRenderingMode(fontId:FontId, fontSize:Pixels):TextRenderingMode {
        return platformTextSystem.recommendedRenderingMode(fontId, fontSize);
    }

}

/**
 * Cached result of a font resolution.
 */
enum CachedFont {
    Direct(fontId:FontId);
    Fallback(fontId:FontId);
    Missing(error:String);
}

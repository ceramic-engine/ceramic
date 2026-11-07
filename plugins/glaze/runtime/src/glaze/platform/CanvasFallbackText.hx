// Ported from gpui-pre-web 0.3.10: src/text_system.rs (`WebTextSystem`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic, as the web part of
// `CeramicTextSystem` (which plays `CosmicTextSystem`); the browser calls go
// through `CanvasTextBackend`. See NOTICE.md.
package gpui.platform;

import gpui.platform.CanvasText.CanvasTextBackend;
import gpui.platform.CanvasText.CanvasTextMetrics;
import gpui.platform.CanvasGlyphCache.CanvasGlyph;
import gpui.platform.RunReplacements.Replacement;
import gpui.util.Utf8;
import haxe.io.Bytes;
import ttf.shape.Shaper;

/**
 * The Canvas2D font fallback of GPUI's web text system: graphemes that the
 * loaded fonts lack (or lack in color, for emoji presentation) are measured
 * and drawn by the browser with its own fonts.
 *
 * Canvas fonts have their own font ids (`CANVAS_FONT_BIT` set, one per
 * native font id, in creation order) and their glyph ids index a
 * `CanvasGlyphCache` (one per grapheme and presentation). Emoji with emoji
 * presentation are color glyphs (`ShapedGlyph.isEmoji`, polychrome sprites
 * of straight alpha BGRA pixels); the other graphemes are alpha masks.
 *
 * Owned by `CeramicTextSystem`, which routes canvas font ids here.
 */
class CanvasFallbackText {

    /**
     * Cosmic's font IDs index its loaded-font vector. Keep browser IDs in a
     * disjoint namespace: the top bit of a 32-bit `usize`, as on wasm32.
     */
    public static inline final CANVAS_FONT_BIT:Int = 1 << 31;

    public static inline final MAX_MEASUREMENTS:Int = 4096;

    final native:CeramicTextSystem;

    /** The browser canvas (null: no Canvas fallback) */
    public var backend:Null<CanvasTextBackend>;

    public var policy:CanvasFontFallback;

    /** Requested font of each native font id, with the weight and style of its face */
    final descriptors:Map<Int, Font> = new Map();

    final canvasFonts:Array<CanvasFont> = [];

    final canvasFontIds:Map<Int, Int> = new Map();

    public final glyphs:CanvasGlyphCache = new CanvasGlyphCache();

    final measurements:Map<String, CanvasTextMetrics> = new Map();

    var measurementCount:Int = 0;

    public function new(native:CeramicTextSystem, backend:Null<CanvasTextBackend>, policy:CanvasFontFallback) {
        this.native = native;
        this.backend = backend;
        this.policy = policy;
    }

    public static inline function isCanvasFontId(fontId:FontId):Bool {
        return ((fontId:Int) & CANVAS_FONT_BIT) != 0;
    }

    /** The canvas font of a font id, or null for a native font id */
    public function canvasFont(fontId:FontId):Null<CanvasFont> {
        if (!isCanvasFontId(fontId))
            return null;
        final index = (fontId:Int) & ~CANVAS_FONT_BIT;
        return index < canvasFonts.length ? canvasFonts[index] : null;
    }

    /** The native font of a font id (itself for a native font id) */
    public function nativeFontId(fontId:FontId):FontId {
        final font = canvasFont(fontId);
        return font != null ? font.nativeId : fontId;
    }

    /** Called when fonts are added */
    public function clearMeasurements():Void {
        measurements.clear();
        measurementCount = 0;
    }

    /** Records the descriptor of a resolved native font (Rust `font_id`) */
    public function recordDescriptor(fontId:FontId, font:Font, weight:FontWeight, style:FontStyle):Void {
        if (descriptors.exists(fontId))
            return;
        final descriptor = font.clone();
        descriptor.weight = weight;
        descriptor.style = style;
        descriptors.set(fontId, descriptor);
    }

    /** The canvas font id for a native font id, created on first use */
    public function canvasFontId(nativeId:FontId):FontId {
        final existing = canvasFontIds.get(nativeId);
        if (existing != null)
            return existing;
        final descriptor = descriptors.get(nativeId);
        if (descriptor == null)
            throw 'missing source font descriptor for Canvas fallback';
        final narrow = native.glyphForChar(nativeId, 'i'.code);
        final wide = native.glyphForChar(nativeId, 'm'.code);
        final monospace = narrow != null && wide != null
            && (native.advance(nativeId, narrow).width:Float) == (native.advance(nativeId, wide).width:Float);
        if (canvasFonts.length >= 0x7FFFFFFF)
            throw 'Canvas font ID space exhausted';
        final fontId = CANVAS_FONT_BIT | canvasFonts.length;
        canvasFonts.push(new CanvasFont(nativeId, descriptor, monospace));
        canvasFontIds.set(nativeId, fontId);
        return fontId;
    }

    public inline function registerGlyph(fontId:FontId, text:String, color:Bool):GlyphId {
        return glyphs.getOrInsert(fontId, text, color);
    }

    public function canvasGlyph(fontId:FontId, glyphId:GlyphId):CanvasGlyph {
        final glyph = glyphs.glyph(fontId, glyphId);
        if (glyph == null)
            throw 'invalid Canvas glyph ID';
        return glyph;
    }

    static inline function measurementKey(fontId:FontId, glyphId:GlyphId, fontSize:Float):String {
        return (fontId:Int) + ':' + (glyphId:Int) + ':' + fontSize;
    }

    /** Browser metrics of a canvas glyph at a font size (f32), cached */
    public function measure(fontId:FontId, glyphId:GlyphId, fontSize:Float):CanvasTextMetrics {
        final key = measurementKey(fontId, glyphId, fontSize);
        final cached = measurements.get(key);
        if (cached != null)
            return cached;
        final font = canvasFont(fontId);
        if (font == null)
            throw 'invalid Canvas font ID';
        final glyph = canvasGlyph(fontId, glyphId);
        if (backend == null)
            throw 'Canvas text rendering is unavailable';
        final metrics = CanvasText.measure(backend, glyph.text, font.cssFont(fontSize, glyph.color));
        if (!(metrics.advance >= 0.0))
            throw 'Canvas returned a negative advance';
        if (measurementCount >= MAX_MEASUREMENTS) {
            measurements.clear();
            measurementCount = 0;
        }
        measurements.set(key, metrics);
        measurementCount++;
        return metrics;
    }

    /** Rust `fallback_glyph` */
    function fallbackGlyph(nativeId:FontId, text:String, color:Bool, fontSize:Float):{fontId:FontId, glyphId:GlyphId, metrics:CanvasTextMetrics} {
        final fontId = canvasFontId(nativeId);
        final glyphId = registerGlyph(fontId, text, color);
        final metrics = measure(fontId, glyphId, fontSize);
        return {fontId: fontId, glyphId: glyphId, metrics: metrics};
    }

    /**
     * Replaces the missing or uncolored eligible graphemes of a native line
     * layout with canvas glyphs (Rust `apply_fallback`). The primary font's
     * baseline and line spacing stay: browser ink extents affect raster
     * bounds, not the surrounding line metrics.
     */
    public function applyFallback(text:String, fontRuns:Array<FontRun>, layout:LineLayout):Void {
        final fontSize:Float = layout.fontSize;
        if (backend == null || policy == Disabled || Utf8.isAscii(text) || !Math.isFinite(fontSize) || fontSize <= 0)
            return;
        final replacements:Array<Replacement> = [];
        for (candidate in RunReplacements.collectCandidates(text, fontRuns, layout)) {
            if (!policy.allows(candidate.isEmoji))
                continue;
            final glyphs = candidate.glyphs;
            if (glyphs == null)
                continue;
            if (!glyphs.contiguous || !(glyphs.missing || (candidate.color && !glyphs.nativeColor)))
                continue;
            final oldWidth = f32(glyphs.endX - glyphs.position.x);
            if (oldWidth < 0)
                continue;
            try {
                final fallback = fallbackGlyph(candidate.fontId, candidate.text, candidate.color, f32(fontSize));
                replacements.push(new Replacement(
                    glyphs.rangeStart,
                    glyphs.rangeEnd,
                    fallback.fontId,
                    new ShapedGlyph(fallback.glyphId, glyphs.position, candidate.sourceStart, candidate.color),
                    f32(fallback.metrics.advance - oldWidth)
                ));
            }
            catch (e:Dynamic) {
                ceramic.Shortcuts.log.warning('Canvas font fallback failed: $e');
            }
        }
        if (replacements.length == 0)
            return;
        replacements.sort((a, b) -> a.glyphRangeStart - b.glyphRangeStart);
        RunReplacements.applyReplacements(layout, replacements);
    }

    /** Font size at which glyphs are measured in font units: the units per em of the native font */
    inline function unitsPerEmSize(font:CanvasFont):Float {
        return f32(native.fontMetrics(font.nativeId).unitsPerEm);
    }

    public function typographicBounds(font:CanvasFont, fontId:FontId, glyphId:GlyphId):Bounds {
        final metrics = measure(fontId, glyphId, unitsPerEmSize(font));
        return new Bounds(
            new Point(metrics.left, -metrics.ascent),
            new Size(f32(metrics.right - metrics.left), f32(metrics.ascent + metrics.descent))
        );
    }

    public function advance(font:CanvasFont, fontId:FontId, glyphId:GlyphId):Size {
        return new Size(measure(fontId, glyphId, unitsPerEmSize(font)).advance, 0.0);
    }

    public function glyphForChar(fontId:FontId, ch:Int):Null<GlyphId> {
        final text = Utf8.fromCodePoint(ch);
        final fallback = CanvasFallback.classify(text);
        final color = fallback != null && fallback.emojiPresentation;
        try {
            return registerGlyph(fontId, text, color);
        }
        catch (e:Dynamic) {
            ceramic.Shortcuts.log.warning('registering Canvas glyph failed: $e');
            return null;
        }
    }

    /** Subpixel offset of a glyph in device pixels (Rust `subpixel_offset`) */
    public static inline function subpixelOffsetX(params:RenderGlyphParams):Float {
        return f32(params.subpixelVariantX / TextSystem.SUBPIXEL_VARIANTS_X);
    }

    public static inline function subpixelOffsetY(params:RenderGlyphParams):Float {
        return f32(params.subpixelVariantY / TextSystem.SUBPIXEL_VARIANTS_Y);
    }

    static inline function deviceFontSize(params:RenderGlyphParams):Float {
        return f32(f32(params.fontSize) * f32(params.scaleFactor));
    }

    public function glyphRasterBounds(params:RenderGlyphParams):Bounds {
        final metrics = measure(params.fontId, params.glyphId, deviceFontSize(params));
        return rasterBoundsOf(metrics, subpixelOffsetX(params), subpixelOffsetY(params));
    }

    /** Raster bounds of browser metrics at a subpixel offset (Rust `glyph_raster_bounds`) */
    public static function rasterBoundsOf(metrics:CanvasTextMetrics, offsetX:Float, offsetY:Float):Bounds {
        if (metrics.right <= metrics.left || f32(metrics.ascent + metrics.descent) <= 0)
            return new Bounds(new Point(0, 0), new Size(0, 0));
        final left = Math.ffloor(metrics.left + offsetX) - 1;
        final top = Math.ffloor(-metrics.ascent + offsetY) - 1;
        final right = Math.fceil(metrics.right + offsetX) + 1;
        final bottom = Math.fceil(metrics.descent + offsetY) + 1;
        for (value in [left, top, right, bottom]) {
            if (!(value >= -2147483648.0 && value <= 2147483647.0))
                throw 'Canvas text bounds exceed device coordinates';
        }
        final width = right - left;
        final height = bottom - top;
        if (width > 2147483647.0)
            throw 'Canvas text width overflow';
        if (height > 2147483647.0)
            throw 'Canvas text height overflow';
        return new Bounds(new Point(left, top), new Size(width, height));
    }

    public function rasterizeGlyph(font:CanvasFont, params:RenderGlyphParams, bounds:Bounds):Bytes {
        final glyph = canvasGlyph(params.fontId, params.glyphId);
        final cssFont = font.cssFont(deviceFontSize(params), glyph.color);
        if (backend == null)
            throw 'Canvas text rendering is unavailable';
        var pixels = CanvasText.rasterize(backend, glyph.text, cssFont, bounds, subpixelOffsetX(params), subpixelOffsetY(params), glyph.color);
        if (params.subpixelRendering && !glyph.color) {
            final expanded = Bytes.alloc(pixels.length * 4);
            for (i in 0...pixels.length) {
                final alpha = pixels.get(i);
                expanded.set(i * 4, alpha);
                expanded.set(i * 4 + 1, alpha);
                expanded.set(i * 4 + 2, alpha);
                expanded.set(i * 4 + 3, alpha);
            }
            pixels = expanded;
        }
        return pixels;
    }

    static inline function f32(value:Float):Float {
        return Shaper.f32(value);
    }

}

/**
 * A font drawn by the browser (Rust `CanvasFont`): the requested font of a
 * native font id, with the weight and style of its face.
 */
class CanvasFont {

    public final nativeId:FontId;

    public final descriptor:Font;

    /** Whether the native font is monospace (same advance for `i` and `m`) */
    public final monospace:Bool;

    public function new(nativeId:FontId, descriptor:Font, monospace:Bool) {
        this.nativeId = nativeId;
        this.descriptor = descriptor;
        this.monospace = monospace;
    }

    /**
     * The CSS font of a canvas glyph (Rust `CanvasFont::css_font`): style,
     * weight, size, then the family (not for color glyphs, nor for a
     * family starting with `.` like `.SystemUIFont`), the user fallbacks,
     * and `emoji`, `monospace` or `sans-serif`.
     */
    public function cssFont(fontSize:Float, color:Bool):String {
        final size = f32(fontSize);
        if (!Math.isFinite(size) || !(size > 0))
            throw 'invalid Canvas font size';
        final style = switch descriptor.style {
            case Normal: 'normal';
            case Italic: 'italic';
            case Oblique: 'oblique';
        }
        final families:Array<String> = [];
        if (!color && !StringTools.startsWith(descriptor.family, '.')) {
            families.push(quoteFamily(descriptor.family));
        }
        if (descriptor.fallbacks != null) {
            for (family in descriptor.fallbacks.fallbackList())
                families.push(quoteFamily(family));
        }
        families.push(color ? 'emoji' : (monospace ? 'monospace' : 'sans-serif'));
        return style + ' ' + f32Display(descriptor.weight) + ' ' + f32Display(size) + 'px ' + families.join(', ');
    }

    /** A CSS string for a family name (Rust `quote_family`) */
    public static function quoteFamily(family:String):String {
        final quoted = new StringBuf();
        quoted.add('"');
        for (c in new haxe.iterators.StringIteratorUnicode(family)) {
            if (c == '\\'.code || c == '"'.code) {
                quoted.add('\\');
                quoted.addChar(c);
            }
            else if (c < 0x20 || (c >= 0x7F && c <= 0x9F)) {
                // `char::is_control`
                quoted.add(' ');
            }
            else {
                quoted.add(Utf8.fromCodePoint(c));
            }
        }
        quoted.add('"');
        return quoted.toString();
    }

    /**
     * Rust `format!("{}", value)` of an `f32`: the shortest digits that read
     * back as the same `f32`, without exponent.
     */
    public static function f32Display(value:Float):String {
        final v = f32(value);
        if (Math.isNaN(v))
            return 'NaN';
        if (!Math.isFinite(v))
            return v > 0 ? 'inf' : '-inf';
        final negative = v < 0 || (v == 0 && 1 / v < 0);
        final sign = negative ? '-' : '';
        final abs = Math.abs(v);
        if (abs == 0)
            return sign + '0';
        // Shortest decimal digits that round trip through f32
        final exp = Math.floor(Math.log(abs) / Math.log(10));
        var digits = '';
        var digitsExp = exp;
        for (precision in 1...10) {
            for (e in [exp - 1, exp, exp + 1]) {
                final scale = e - precision + 1;
                final mantissa = Math.fround(abs / pow10(scale));
                if (mantissa < Math.pow(10, precision - 1) || mantissa >= Math.pow(10, precision))
                    continue;
                if (f32(mantissa * pow10(scale)) == abs || f32(mantissa / pow10(-scale)) == abs) {
                    digits = Std.string(Std.int(mantissa));
                    digitsExp = e;
                    break;
                }
            }
            if (digits != '')
                break;
        }
        if (digits == '')
            return sign + Std.string(abs);
        // Trim trailing zeros
        while (digits.length > 1 && digits.charAt(digits.length - 1) == '0')
            digits = digits.substr(0, digits.length - 1);
        final length = digits.length;
        if (length - 1 <= digitsExp) {
            return sign + digits + StringTools.lpad('', '0', digitsExp - (length - 1));
        }
        else if (digitsExp >= 0) {
            return sign + digits.substr(0, digitsExp + 1) + '.' + digits.substr(digitsExp + 1);
        }
        else {
            return sign + '0.' + StringTools.lpad('', '0', -digitsExp - 1) + digits;
        }
    }

    static function pow10(e:Int):Float {
        return e >= 0 ? Math.pow(10, e) : 1 / Math.pow(10, -e);
    }

    static inline function f32(value:Float):Float {
        return Shaper.f32(value);
    }

}

// Ported from gpui-pre-wgpu 0.3.10: src/cosmic_text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic, on top of the ttf library
// instead of cosmic-text and swash. See NOTICE.md.
package gpui.platform;

import gpui.*;
import gpui.util.Utf8;
import haxe.io.Bytes;
import ttf.GlyphRasterizer;
import ttf.shape.Features;
import ttf.shape.Shaper;

/**
 * GPUI's `PlatformTextSystem` for Ceramic, in pure Haxe over the `ttf`
 * library (font parsing, OpenType shaping, glyph rasterization).
 *
 * It follows GPUI's font file based text system (`CosmicTextSystem` of
 * gpui-pre-wgpu, used on Linux and the web), and is validated against it
 * (`test/unit/data/gpui-text-reference.json`):
 *
 * - fonts are only the ones added with `addFonts()` (no system fonts);
 *   `.SystemUIFont` maps to `systemFontFallback` (Inter by default);
 * - one font id per face and descriptor (family, features, fallbacks),
 *   faces without an `m` glyph cannot be primary fonts, the face closest
 *   to the requested weight and style is picked;
 * - metrics, advances and typographic bounds use the same definitions as
 *   swash (typographic bounds and advance heights span ascent to descent,
 *   the bounding box is `advanceWidthMax` by ascent + descent);
 * - lines are split into words at whitespace and each word is shaped on
 *   its own (like cosmic-text), user fallbacks (`Font.fallbacks`) are
 *   applied per grapheme, then every other loaded face can supply missing
 *   characters; tabs advance to the next multiple of 4 spaces;
 * - glyphs are rasterized without hinting, with the horizontal subpixel
 *   offset `variant / 4 / scaleFactor` used by GPUI's swash rasterizer.
 *   GPUI's swash path hints glyphs (`.hint(true)`), but GPUI's primary
 *   platform (macOS, CoreText through font-kit) does not, so the port
 *   renders unhinted glyphs: `ttf.GlyphRasterizer` scales TrueType outlines
 *   in 26.6 fixed point like skrifa and scans them with a port of zeno (the
 *   rasterizer of swash), so its masks and raster bounds are bit exact with
 *   swash's unhinted rendering (the reference harness renders text that way,
 *   see `reference/src/unhinted_text.rs`).
 *
 * Not supported: color glyphs (emoji), subpixel (LCD) masks, glyph dilation,
 * complex scripts and bidirectional text (see the `ttf` library).
 */
class CeramicTextSystem implements PlatformTextSystem {

    /** Font family used for `.SystemUIFont` */
    public var systemFontFallback(default, null):String;

    /** Faces of every added font file (the font database) */
    final faces:Array<ttf.Font> = [];

    /** Loaded fonts, indexed by `FontId` */
    final loadedFonts:Array<LoadedFont> = [];

    final loadedFontIdsByKey:Map<String, Int> = new Map();

    final fontIdsByFamilyCache:Map<String, Array<Int>> = new Map();

    final featuresCache:Map<String, Features> = new Map();

    final shaper:Shaper = {
        final shaper = new Shaper();
        // Advances and metrics in f32, like cosmic-text
        shaper.singlePrecision = true;
        shaper;
    };

    final rasterizer:GlyphRasterizer = new GlyphRasterizer();

    final bitmap:GlyphBitmap = new GlyphBitmap();

    final decoded:Utf8Text = new Utf8Text();

    public function new(systemFontFallback:String = 'Inter') {
        this.systemFontFallback = systemFontFallback;
    }

/// Fonts

    public function addFonts(fonts:Array<Bytes>):Void {
        fontIdsByFamilyCache.clear();
        for (bytes in fonts) {
            final count = ttf.Font.faceCount(bytes);
            if (count == 0)
                throw 'unsupported font data';
            for (i in 0...count) {
                faces.push(ttf.Font.fromBytes(bytes, i));
            }
        }
    }

    /**
     * The face of the given family closest to the given weight and style,
     * or null (used to render SVG text, see `SvgFontProvider`). Generic CSS
     * families map to the system font (`monospace` to the first monospace face).
     */
    public function faceForFamily(family:String, bold:Bool, italic:Bool):Null<ttf.Font> {
        var name = Font.fontNameWithFallbacks(family, systemFontFallback);
        switch name {
            case '' | 'sans-serif' | 'serif' | 'cursive' | 'fantasy' | 'system-ui':
                name = systemFontFallback;
            case 'monospace':
                for (face in faces)
                    if (face.isMonospace)
                        return face;
                name = systemFontFallback;
            case _:
        }
        var best:Null<ttf.Font> = null;
        var bestScore = 0x7FFFFFFF;
        final weight = bold ? 700 : 400;
        for (face in faces) {
            if (face.familyName != name)
                continue;
            final score = Std.int(Math.abs(face.weight - weight)) + (face.italic != italic ? 1000 : 0);
            if (score < bestScore) {
                best = face;
                bestScore = score;
            }
        }
        return best;
    }

    public function allFontNames():Array<String> {
        final result:Array<String> = [];
        for (face in faces) {
            if (result.indexOf(face.familyName) == -1)
                result.push(face.familyName);
        }
        result.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return result;
    }

    static function fontKey(family:String, features:FontFeatures, fallbacks:Null<FontFallbacks>):String {
        return family + '\x00' + features.key() + '\x00' + (fallbacks != null ? fallbacks.key() : '-');
    }

    public function fontId(font:Font):FontId {
        final key = fontKey(font.family, font.features, font.fallbacks);
        var candidates = fontIdsByFamilyCache.get(key);
        if (candidates == null) {
            candidates = loadFamily(font.family, font.features, font.fallbacks);
            fontIdsByFamilyCache.set(key, candidates);
        }

        final ix = findBestMatch(font, candidates);
        return candidates[ix];
    }

    function loadFamily(name:String, features:FontFeatures, fallbacks:Null<FontFallbacks>):Array<Int> {
        final loadedFontKey = fontKey(name, features, fallbacks);

        // Recurse with `fallbacks = null` so a fallback family cannot pull in
        // another chain. Missing fallback families are dropped so a typo in
        // settings still lets the primary family load.
        final userFallbackChain:Array<Int> = [];
        if (fallbacks != null && fallbacks.fallbackList().length > 0) {
            for (fallbackName in fallbacks.fallbackList()) {
                final fbKey = fontKey(fallbackName, features, null);
                var fbIds = fontIdsByFamilyCache.get(fbKey);
                if (fbIds == null) {
                    fbIds = loadFamily(fallbackName, features, null);
                    fontIdsByFamilyCache.set(fbKey, fbIds);
                }
                if (fbIds.length == 0)
                    continue;
                userFallbackChain.push(fbIds[0]);
            }
        }

        final resolvedName = Font.fontNameWithFallbacks(name, systemFontFallback);

        final ttfFeatures = featuresFor(features);

        final loadedFontIds:Array<Int> = [];
        for (faceIndex in 0...faces.length) {
            final face = faces[faceIndex];
            if (face.familyName != resolvedName)
                continue;

            final key = faceIndex + '\x00' + loadedFontKey;
            final existing = loadedFontIdsByKey.get(key);
            if (existing != null) {
                loadedFonts[existing].userFallbackChain = userFallbackChain;
                loadedFontIds.push(existing);
                continue;
            }

            // This only decides whether a face can be a primary font. The
            // editor measures layout with the width of 'm' and would panic
            // without it.
            if (face.glyphForChar('m'.code) == 0)
                continue;

            final fontId = loadedFonts.length;
            loadedFontIds.push(fontId);
            loadedFonts.push(new LoadedFont(face, ttfFeatures, isKnownEmojiFont(face.postScriptName), userFallbackChain));
            loadedFontIdsByKey.set(key, fontId);
        }

        return loadedFontIds;
    }

    /** ttf shaper features for GPUI font features (applied over the defaults) */
    function featuresFor(features:FontFeatures):Features {
        final key = features.key();
        var result = featuresCache.get(key);
        if (result == null) {
            result = Features.DEFAULT;
            for (i in 0...features.length()) {
                final tag = features.tags[i];
                if (tag.length != 4)
                    throw 'Incorrect feature flag format';
                result = result.with(tag, features.values[i] != 0);
            }
            featuresCache.set(key, result);
        }
        return result;
    }

    static function isKnownEmojiFont(postScriptName:String):Bool {
        // TODO: Include other common emoji fonts
        return postScriptName == 'NotoColorEmoji';
    }

    function findBestMatch(font:Font, candidates:Array<Int>):Int {
        if (candidates.length == 0) {
            throw 'requested font family contains no font matching the other parameters';
        }
        if (candidates.length == 1) {
            return 0;
        }

        final targetWeight:Float = font.weight;
        final targetItalic = font.style == Italic || font.style == Oblique;

        var bestIndex = 0;
        var bestScore = 0x7FFFFFFF;

        for (index in 0...candidates.length) {
            final face = loadedFonts[candidates[index]].face;
            final stylePenalty = face.italic == targetItalic ? 0 : 1000;
            final weightDiff = Std.int(Math.abs(face.weight - Std.int(targetWeight)));
            final score = stylePenalty + weightDiff;

            if (score < bestScore) {
                bestScore = score;
                bestIndex = index;
            }
        }

        return bestIndex;
    }

    /**
     * Font id of a face used as a fallback by the shaper (Rust
     * `font_id_for_cosmic_id`): the first loaded font of that face, or a new
     * one without features.
     */
    function fontIdForFace(face:ttf.Font):Int {
        for (i in 0...loadedFonts.length) {
            if (loadedFonts[i].face == face)
                return i;
        }
        final fontId = loadedFonts.length;
        loadedFonts.push(new LoadedFont(face, Features.DEFAULT, isKnownEmojiFont(face.postScriptName), []));
        return fontId;
    }

    /** The `ttf.Font` of a font id */
    public inline function ttfFont(fontId:FontId):ttf.Font {
        return loadedFonts[fontId].face;
    }

/// Metrics

    public function fontMetrics(fontId:FontId):FontMetrics {
        final face = loadedFonts[fontId].face;
        final m = face.metrics;
        final ascent = m.ascent;
        final descent = -m.descent;
        return new FontMetrics(
            m.unitsPerEm,
            ascent,
            -descent,
            m.lineGap,
            m.underlinePosition,
            m.underlineThickness,
            m.capHeight,
            m.xHeight,
            new Bounds(new Point(0.0, 0.0), new Size(advanceWidthMax(face), ascent + descent))
        );
    }

    /** `hhea.advanceWidthMax` (swash `Metrics::max_width`) */
    static function advanceWidthMax(face:ttf.Font):Float {
        final hhea = face.table('hhea');
        if (hhea < 0)
            return 0;
        final data = face.data;
        return (data.get(hhea + 10) << 8) | data.get(hhea + 11);
    }

    /** Ascent + descent in font units (swash advance height without `vmtx`) */
    static inline function advanceHeight(face:ttf.Font):Float {
        return face.metrics.ascent - face.metrics.descent;
    }

    public function typographicBounds(fontId:FontId, glyphId:GlyphId):Bounds {
        final face = loadedFonts[fontId].face;
        return new Bounds(new Point(0.0, 0.0), new Size(face.advance(glyphId), advanceHeight(face)));
    }

    public function advance(fontId:FontId, glyphId:GlyphId):Size {
        final face = loadedFonts[fontId].face;
        return new Size(face.advance(glyphId), advanceHeight(face));
    }

    public function glyphForChar(fontId:FontId, ch:Int):Null<GlyphId> {
        final glyphId = loadedFonts[fontId].face.glyphForChar(ch);
        return glyphId == 0 ? null : glyphId;
    }

/// Rasterization

    public function glyphRasterBounds(params:RenderGlyphParams):Bounds {
        final face = loadedFonts[params.fontId].face;
        final b = rasterizer.rasterBounds(face, params.glyphId, params.fontSize * params.scaleFactor, subpixelOffsetX(params), subpixelOffsetY(params), bitmap);
        if (b.width <= 0 || b.height <= 0)
            return new Bounds(new Point(0, 0), new Size(0, 0));
        return new Bounds(new Point(b.left, -b.top), new Size(b.width, b.height));
    }

    static inline function subpixelOffsetX(params:RenderGlyphParams):Float {
        return params.subpixelVariantX / TextSystem.SUBPIXEL_VARIANTS_X / params.scaleFactor;
    }

    static inline function subpixelOffsetY(params:RenderGlyphParams):Float {
        return params.subpixelVariantY / TextSystem.SUBPIXEL_VARIANTS_Y / params.scaleFactor;
    }

    public function rasterizeGlyph(params:RenderGlyphParams, rasterBounds:Bounds):Bytes {
        if (rasterBounds.size.width == 0 || rasterBounds.size.height == 0)
            throw 'glyph bounds are empty';
        if (params.subpixelRendering)
            throw 'subpixel rendering is not supported';
        final face = loadedFonts[params.fontId].face;
        final b = rasterizer.rasterize(face, params.glyphId, params.fontSize * params.scaleFactor, subpixelOffsetX(params), subpixelOffsetY(params), bitmap);
        final width = Std.int(rasterBounds.size.width);
        final height = Std.int(rasterBounds.size.height);
        final result = Bytes.alloc(width * height);
        result.fill(0, result.length, 0);
        if (b.data != null) {
            final w = Std.int(Math.min(width, b.width));
            for (row in 0...Std.int(Math.min(height, b.height))) {
                result.blit(row * width, b.data, row * b.width, w);
            }
        }
        return result;
    }

    public function recommendedRenderingMode(fontId:FontId, fontSize:Pixels):TextRenderingMode {
        return Grayscale;
    }

    public function glyphDilationForColor(color:Hsla):Int {
        return 0;
    }

/// Layout

    public function layoutLine(text:String, fontSize:Pixels, runs:Array<FontRun>):LineLayout {
        if (containsParagraphSeparator(text)) {
            return layoutLineWithSeparators(text, fontSize, runs);
        }
        else {
            return layoutLineNoSeparators(text, fontSize, runs);
        }
    }

    static inline function isParagraphSeparator(c:Int):Bool {
        // Unicode bidi class B
        return c == 0x0A || c == 0x0D || (c >= 0x1C && c <= 0x1E) || c == 0x85 || c == 0x2029;
    }

    static function containsParagraphSeparator(text:String):Bool {
        for (i in 0...text.length) {
            if (isParagraphSeparator(StringTools.fastCodeAt(text, i)))
                return true;
        }
        return false;
    }

    function layoutLineWithSeparators(text:String, fontSize:Pixels, runs:Array<FontRun>):LineLayout {
        final layout = new LineLayout(fontSize, 0, 0, 0, [], Utf8.byteLength(text));
        final d = new Utf8Text(text);
        var paragraphStart = 0;
        for (k in 0...d.count) {
            final c = d.codePoints[k];
            if (!isParagraphSeparator(c))
                continue;
            final separatorStart = d.byteOffsets[k];
            final separatorEnd = separatorStart + Utf8.codePointLength(c);
            shapeSegment(text, paragraphStart, separatorStart, fontSize, runs, layout);
            shapeSegment(text, separatorStart, separatorEnd, fontSize, runs, layout);
            paragraphStart = separatorEnd;
        }
        shapeSegment(text, paragraphStart, d.byteLength, fontSize, runs, layout);
        return layout;
    }

    function shapeSegment(text:String, start:Int, end:Int, fontSize:Pixels, fontRuns:Array<FontRun>, layout:LineLayout):Void {
        if (end <= start)
            return;

        final segmentFontRuns = clipFontRuns(fontRuns, start, end);
        final segment = layoutLineNoSeparators(Utf8.substring(text, start, end), fontSize, segmentFontRuns);

        for (run in segment.runs) {
            for (glyph in run.glyphs) {
                glyph.index += start;
                glyph.position = new Point(glyph.position.x + layout.width, glyph.position.y);
            }
            final last = layout.runs.length > 0 ? layout.runs[layout.runs.length - 1] : null;
            if (last != null && (last.fontId:Int) == (run.fontId:Int)) {
                for (glyph in run.glyphs)
                    last.glyphs.push(glyph);
            }
            else {
                layout.runs.push(run);
            }
        }

        layout.width += segment.width;
        layout.ascent = Math.max(layout.ascent, segment.ascent);
        layout.descent = Math.max(layout.descent, segment.descent);
    }

    static function clipFontRuns(fontRuns:Array<FontRun>, start:Int, end:Int):Array<FontRun> {
        final clipped:Array<FontRun> = [];
        var offs = 0;
        for (run in fontRuns) {
            final runStart = offs;
            offs += run.len;
            if (offs <= start) {
                continue;
            }
            if (runStart >= end) {
                break;
            }
            final s = Std.int(Math.max(runStart, start));
            final e = Std.int(Math.min(offs, end));
            if (s < e) {
                clipped.push(new FontRun(e - s, run.fontId));
            }
        }
        return clipped;
    }

    // Spans of the line being laid out: [start, end) byte ranges and their font id
    final spanStarts:Array<Int> = [];
    final spanEnds:Array<Int> = [];
    final spanFontIds:Array<Int> = [];
    final shapeRuns:Array<ttf.shape.FontRun> = [];
    final fallbackLists:Map<Int, Array<ttf.Font>> = new Map();

    /**
     * Faces tried for characters missing from `face`: every other face, in
     * the order fonts were added (cosmic-text falls back on its database).
     */
    function databaseFallbacks(face:ttf.Font):Array<ttf.Font> {
        final faceIndex = faces.indexOf(face);
        var list = fallbackLists.get(faceIndex);
        if (list == null || list.length != faces.length - 1) {
            list = [for (f in faces) if (f != face) f];
            fallbackLists.set(faceIndex, list);
        }
        return list;
    }

    function layoutLineNoSeparators(text:String, fontSize:Pixels, fontRuns:Array<FontRun>):LineLayout {
        final d = decoded.reset(text);
        spanStarts.resize(0);
        spanEnds.resize(0);
        spanFontIds.resize(0);

        // Spans: primary font, or the user fallback covering each grapheme
        var offs = 0;
        for (run in fontRuns) {
            final runEnd = offs + run.len;
            if ((run.fontId:Int) < 0 || (run.fontId:Int) >= loadedFonts.length) {
                offs = runEnd;
                continue;
            }
            final loaded = loadedFonts[run.fontId];
            if (loaded.userFallbackChain.length == 0) {
                if (runEnd > offs)
                    pushSpan(offs, runEnd, run.fontId);
            }
            else {
                computeRunSpans(d, offs, runEnd, run.fontId, loaded.userFallbackChain);
            }
            offs = runEnd;
        }

        // Shape each word on its own, like cosmic-text
        shapeRuns.resize(0);
        wordStarts.resize(0);
        if (spanStarts.length > 0)
            addWordRuns(d);

        if (shapeRuns.length == 0 || d.count == 0) {
            return new LineLayout(fontSize, 0, 0, 0, [], d.byteLength);
        }

        final hasTab = text.indexOf('\t') != -1;
        final shapedText = hasTab ? StringTools.replace(text, '\t', ' ') : text;
        final shaped = shaper.layoutLine(shapedText, fontSize, shapeRuns);

        // Layout of the glyphs in f32, like cosmic-text 0.19 (src/shape.rs:
        // `shape_fallback`, the tab stops of `ShapeLine::build`, then
        // `layout_to_buffer` without wrapping, alignment or hinting): advances
        // in ems (`x_advance as f32 / units_per_em`), tabs moved to the next
        // stop in ems, pixel advances `font_size.mul_add(advance, 0.0)` (the
        // exact product rounded once) accumulated glyph by glyph for the pen
        // position, and the line width summed word by word. GPUI places each
        // glyph at the pen position (`LayoutGlyph::x` and `y`): the glyph
        // offsets of the shaper are not applied.
        final size = f32(fontSize);
        final runs:Array<ShapedRun> = [];
        var tabX = 0.0;
        var x = 0.0;
        var width = 0.0;
        var wordWidth = 0.0;
        var wordIndex = 0;
        var spanIndex = 0;
        for (ttfRun in shaped.runs) {
            final face = ttfRun.font;
            final unitsPerEm = face.unitsPerEm;
            for (g in ttfRun.glyphs) {
                while (spanIndex < spanStarts.length - 1 && g.index >= spanEnds[spanIndex])
                    spanIndex++;
                while (spanIndex > 0 && g.index < spanStarts[spanIndex])
                    spanIndex--;
                final spanFontId = spanFontIds[spanIndex];
                final fontId = loadedFonts[spanFontId].face == face ? spanFontId : fontIdForFace(face);
                final loaded = loadedFonts[fontId];

                var advance = f32(g.advanceUnits / unitsPerEm);
                if (hasTab && d.codePointAtByte(g.index) == '\t'.code) {
                    // Tabs are shaped as spaces, then advance to the next tab stop
                    final tabXAdvance = f32(TAB_WIDTH * advance);
                    if (tabXAdvance > 0) {
                        final tabStop = f32(f32(Math.ffloor(f32(tabX / tabXAdvance)) + 1.0) * tabXAdvance);
                        advance = f32(tabStop - tabX);
                    }
                }
                tabX = f32(tabX + advance);
                final xAdvance = f32(size * advance);

                while (wordIndex < wordStarts.length - 1 && g.index >= wordStarts[wordIndex + 1]) {
                    width = f32(width + wordWidth);
                    wordWidth = 0.0;
                    wordIndex++;
                }
                wordWidth = f32(wordWidth + xAdvance);

                final isEmoji = loaded.isKnownEmojiFont;
                final glyph = new ShapedGlyph(g.id, new Point(x, 0.0), g.index, isEmoji);
                x = f32(x + xAdvance);
                final last = runs.length > 0 ? runs[runs.length - 1] : null;
                if (last != null && (last.fontId:Int) == fontId) {
                    last.glyphs.push(glyph);
                }
                else {
                    runs.push(new ShapedRun(fontId, [glyph]));
                }
            }
        }

        width = f32(width + wordWidth);

        return new LineLayout(fontSize, width, shaped.ascent, shaped.descent, runs, d.byteLength);
    }

    static inline function f32(value:Float):Float {
        return Shaper.f32(value);
    }

    static inline final TAB_WIDTH:Int = 4;

    inline function pushSpan(start:Int, end:Int, fontId:Int):Void {
        // cosmic-text keeps spans in a `RangeMap`, which coalesces adjacent
        // spans with the same attributes: runs of the same font that only
        // differ by their decorations are shaped together (kerning and
        // ligatures across the boundary)
        final last = spanStarts.length - 1;
        if (last >= 0 && spanEnds[last] == start && spanFontIds[last] == fontId) {
            spanEnds[last] = end;
            return;
        }
        spanStarts.push(start);
        spanEnds.push(end);
        spanFontIds.push(fontId);
    }

    /**
     * Groups the graphemes of a run into spans, by the font (primary or user
     * fallback) that covers them (Rust `compute_run_spans`). Graphemes are
     * approximated by code points followed by their continuation characters.
     */
    function computeRunSpans(d:Utf8Text, runOffset:Int, runEnd:Int, primary:Int, fallbackChain:Array<Int>):Void {
        if (runEnd <= runOffset)
            return;
        var spanStart = runOffset;
        var spanSlot = -1;
        var spanFontId = primary;
        var k = d.indexAtByte(runOffset);
        while (k < d.count && d.byteOffsets[k] < runEnd) {
            final abs = d.byteOffsets[k];
            final ch = d.codePoints[k];
            k++;
            // Skip the rest of the grapheme
            while (k < d.count && d.byteOffsets[k] < runEnd && ttf.Utf8.isContinuation(d.codePoints[k]))
                k++;
            final nextSlot = pickCoveringSlot(ch, spanSlot, primary, fallbackChain);
            if (nextSlot == spanSlot) {
                continue;
            }
            if (abs > spanStart) {
                pushSpan(spanStart, abs, spanFontId);
            }
            spanStart = abs;
            spanSlot = nextSlot;
            spanFontId = nextSlot < 0 ? primary : fallbackChain[nextSlot];
        }
        if (spanStart < runEnd) {
            pushSpan(spanStart, runEnd, spanFontId);
        }
    }

    inline function covers(fontId:Int, ch:Int):Bool {
        return fontId >= 0 && fontId < loadedFonts.length && loadedFonts[fontId].face.glyphForChar(ch) != 0;
    }

    /** Slot of the font covering a character: -1 for the primary font, else an index in the chain */
    function pickCoveringSlot(ch:Int, current:Int, primary:Int, fallbackChain:Array<Int>):Int {
        if (ch <= 0x7F) {
            return -1;
        }
        if (covers(primary, ch)) {
            return -1;
        }
        final currentId = current < 0 ? primary : fallbackChain[current];
        if (covers(currentId, ch)) {
            return current;
        }
        for (i in 0...fallbackChain.length) {
            if (covers(fallbackChain[i], ch))
                return i;
        }
        return -1;
    }

    /** Byte offsets where the words of the line being laid out start */
    final wordStarts:Array<Int> = [];

    /**
     * Adds ttf runs for the words of the line, like cosmic-text's
     * `ShapeSpan::build` and `ShapeWord::build` (cosmic-text 0.19,
     * src/shape.rs, the line being one left to right span): words end at the
     * UAX#14 line break opportunities, except between two ASCII punctuation
     * characters that the font joins (a ligature or a contextual alternate,
     * found by shaping the pair alone); the whitespace at the end of a word
     * is split off, one word per whitespace character. Each word is shaped on
     * its own, so contextual rules do not see across a break opportunity
     * (in Inter, the hyphen of "234-" is `hyphen.case`), and a word that
     * spans several fonts is shaped in one run per font.
     */
    function addWordRuns(d:Utf8Text):Void {
        final end = d.byteLength;
        if (end <= 0)
            return;
        if (spanBytesText != d.text) {
            spanBytesText = d.text;
            spanBytes = Bytes.ofString(d.text, UTF8);
        }
        final breaks = unicode_linebreak.UnicodeLinebreak.linebreaksBytes(spanBytes, 0, end);
        var startWord = 0;
        while (breaks.nextBreak()) {
            final endLb = breaks.index;
            if (endLb > 0 && endLb < end) {
                final c1 = d.codePointAtByte(endLb - 1);
                final c2 = d.codePointAtByte(endLb);
                if (isAsciiPunctuation(c1) && isAsciiPunctuation(c2)) {
                    // The probe uses the font of the text after the break
                    final s = spanAt(endLb);
                    if (s >= 0 && joinsPair(loadedFonts[spanFontIds[s]], c1, c2))
                        continue;
                }
            }
            // Split off the whitespace at the end of the word
            var startLb = endLb;
            var k = d.indexAtByte(endLb) - 1;
            while (k >= 0 && d.byteOffsets[k] >= startWord && Utf8.isWhitespace(d.codePoints[k])) {
                startLb = d.byteOffsets[k];
                k--;
            }
            if (startWord < startLb)
                addWord(startWord, startLb);
            var offset = startLb;
            while (offset < endLb) {
                final len = Utf8.codePointLength(d.codePointAtByte(offset));
                addWord(offset, offset + len);
                offset += len;
            }
            startWord = endLb;
        }
    }

    /** Adds the runs of a word: one per span (font) it overlaps */
    function addWord(start:Int, end:Int):Void {
        wordStarts.push(start);
        for (s in 0...spanStarts.length) {
            final runStart = spanStarts[s] > start ? spanStarts[s] : start;
            final runEnd = spanEnds[s] < end ? spanEnds[s] : end;
            if (runStart >= runEnd)
                continue;
            final loaded = loadedFonts[spanFontIds[s]];
            shapeRuns.push(new ttf.shape.FontRun(runEnd - runStart, loaded.face, databaseFallbacks(loaded.face), loaded.features));
        }
    }

    /** Index of the span containing a byte offset, or -1 */
    function spanAt(offset:Int):Int {
        for (s in 0...spanStarts.length) {
            if (offset >= spanStarts[s] && offset < spanEnds[s])
                return s;
        }
        return -1;
    }

    var spanBytesText:Null<String> = null;

    var spanBytes:Null<Bytes> = null;

    static inline function isAsciiPunctuation(c:Int):Bool {
        return (c >= 0x21 && c <= 0x2F) || (c >= 0x3A && c <= 0x40) || (c >= 0x5B && c <= 0x60) || (c >= 0x7B && c <= 0x7E);
    }

    final probeShaper = new Shaper();

    final joinedPairs:Map<String, Bool> = new Map();

    /**
     * cosmic-text's ligature probe: the pair shaped alone gives fewer glyphs
     * than characters, or glyphs other than the cmap's.
     */
    function joinsPair(loaded:LoadedFont, c1:Int, c2:Int):Bool {
        final key = loadedFonts.indexOf(loaded) + ':' + c1 + ':' + c2;
        final cached = joinedPairs.get(key);
        if (cached != null)
            return cached;
        final probe = String.fromCharCode(c1) + String.fromCharCode(c2);
        final shaped = probeShaper.layoutLine(probe, 16, [new ttf.shape.FontRun(2, loaded.face, [], loaded.features)]);
        final ids:Array<Int> = [];
        for (run in shaped.runs)
            for (glyph in run.glyphs)
                ids.push(glyph.id);
        final joined = ids.length < 2 || ids[0] != loaded.face.glyphForChar(c1) || ids[1] != loaded.face.glyphForChar(c2);
        joinedPairs.set(key, joined);
        return joined;
    }
}

private class LoadedFont {

    public final face:ttf.Font;

    public final features:Features;

    public final isKnownEmojiFont:Bool;

    /** Font ids of the user fallbacks, resolved at load time */
    public var userFallbackChain:Array<Int>;

    public function new(face:ttf.Font, features:Features, isKnownEmojiFont:Bool, userFallbackChain:Array<Int>) {
        this.face = face;
        this.features = features;
        this.isKnownEmojiFont = isKnownEmojiFont;
        this.userFallbackChain = userFallbackChain;
    }

}

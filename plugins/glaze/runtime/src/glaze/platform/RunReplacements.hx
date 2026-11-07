// Ported from gpui-pre-web 0.3.10: src/run_replacements.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.platform;

import glaze.util.Utf8;
import ttf.shape.Shaper;
import unicode_segmentation.UnicodeSegmentation;

/**
 * A grapheme of a line eligible for the Canvas fallback (Rust `Candidate`),
 * with the glyphs the loaded fonts gave it.
 */
class Candidate {

    /** UTF-8 byte range of the grapheme in the line */
    public final sourceStart:Int;

    public final sourceEnd:Int;

    /** Font of the run the grapheme belongs to */
    public final fontId:FontId;

    public final isEmoji:Bool;

    /** Whether emoji presentation is requested */
    public final color:Bool;

    /** Glyphs shaped for the grapheme, or null when it has none */
    public var glyphs:Null<GlyphSpan> = null;

    /** The grapheme (`text[sourceStart..sourceEnd]`) */
    public final text:String;

    public function new(sourceStart:Int, sourceEnd:Int, fontId:FontId, isEmoji:Bool, color:Bool, text:String) {
        this.text = text;
        this.sourceStart = sourceStart;
        this.sourceEnd = sourceEnd;
        this.fontId = fontId;
        this.isEmoji = isEmoji;
        this.color = color;
    }

    public inline function containsIndex(index:Int):Bool {
        return index >= sourceStart && index < sourceEnd;
    }

}

/**
 * The glyphs of a candidate (Rust `GlyphSpan`), in the flattened glyph stream
 * of the line.
 */
class GlyphSpan {

    /** Flattened glyph range */
    public var rangeStart:Int;

    public var rangeEnd:Int;

    /** Position of the first glyph */
    public var position:Point;

    /** x of the glyph after the last one (or the line width) */
    public var endX:Float;

    /** Whether the glyphs are consecutive in the stream */
    public var contiguous:Bool = true;

    /** Whether one of the glyphs is missing (glyph id 0) */
    public var missing:Bool = false;

    /** Whether every glyph is a color glyph */
    public var nativeColor:Bool = true;

    public function new(rangeStart:Int, rangeEnd:Int, position:Point, endX:Float) {
        this.rangeStart = rangeStart;
        this.rangeEnd = rangeEnd;
        this.position = position;
        this.endX = endX;
    }

}

/**
 * A glyph range replaced by one Canvas glyph (Rust `Replacement`).
 */
class Replacement {

    public final glyphRangeStart:Int;

    public final glyphRangeEnd:Int;

    public final fontId:FontId;

    public final glyph:ShapedGlyph;

    /** Change of the line width (f32) */
    public final widthDelta:Float;

    public function new(glyphRangeStart:Int, glyphRangeEnd:Int, fontId:FontId, glyph:ShapedGlyph, widthDelta:Float) {
        this.glyphRangeStart = glyphRangeStart;
        this.glyphRangeEnd = glyphRangeEnd;
        this.fontId = fontId;
        this.glyph = glyph;
        this.widthDelta = widthDelta;
    }

}

/**
 * Finds the graphemes of a line that the Canvas fallback may replace and
 * splices the replacements into the line layout.
 */
class RunReplacements {

    /**
     * The eligible graphemes of `text` (Rust `collect_candidates`), each with
     * the span of glyphs `layout` gave it. Graphemes that cross a font change
     * are skipped; runs of the same font are joined first, since paint-only
     * run boundaries must not split a fallback grapheme.
     */
    public static function collectCandidates(text:String, fontRuns:Array<FontRun>, layout:LineLayout):Array<Candidate> {
        final candidates:Array<Candidate> = [];
        var runIndex = 0;
        var run:Null<FontRun> = fontRuns.length > 0 ? fontRuns[runIndex++] : null;
        var runEnd = run != null ? run.len : 0;
        final graphemes = UnicodeSegmentation.graphemeIndices(text, true);
        var grapheme = graphemes.next();
        while (grapheme != null) {
            final g:String = grapheme;
            grapheme = null;
            final start = graphemes.rangeStart;
            final end = graphemes.rangeEnd;
            while (start >= runEnd) {
                run = runIndex < fontRuns.length ? fontRuns[runIndex++] : null;
                if (run == null)
                    break;
                runEnd += run.len;
            }
            if (run == null)
                break;
            while (runIndex < fontRuns.length && (fontRuns[runIndex].fontId:Int) == (run.fontId:Int)) {
                runEnd += fontRuns[runIndex].len;
                runIndex++;
            }
            grapheme = graphemes.next();
            if (end > runEnd)
                continue;
            final fallback = CanvasFallback.classify(g);
            if (fallback == null)
                continue;
            candidates.push(new Candidate(start, end, run.fontId, fallback.isEmoji, fallback.emojiPresentation, g));
        }
        if (candidates.length == 0)
            return candidates;

        // The flattened glyph stream
        final flat:Array<ShapedGlyph> = [];
        for (r in layout.runs)
            for (g in r.glyphs)
                flat.push(g);
        for (index in 0...flat.length) {
            final glyph = flat[index];
            final candidateIndex = partitionPoint(candidates, glyph.index);
            if (candidateIndex >= candidates.length)
                continue;
            final candidate = candidates[candidateIndex];
            if (!candidate.containsIndex(glyph.index))
                continue;
            var span = candidate.glyphs;
            if (span == null) {
                span = new GlyphSpan(index, index, glyph.position, glyph.position.x);
                candidate.glyphs = span;
            }
            span.contiguous = span.contiguous && span.rangeEnd == index;
            span.rangeEnd = index + 1;
            span.endX = index + 1 < flat.length ? flat[index + 1].position.x : layout.width;
            span.missing = span.missing || (glyph.id:Int) == 0;
            span.nativeColor = span.nativeColor && glyph.isEmoji;
        }
        return candidates;
    }

    /** First candidate whose source does not end at or before `index` */
    static function partitionPoint(candidates:Array<Candidate>, index:Int):Int {
        var lo = 0;
        var hi = candidates.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (candidates[mid].sourceEnd <= index)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo;
    }

    /**
     * Replaces glyph ranges of `layout` (Rust `apply_replacements`). Ranges
     * refer to the original flattened glyph stream and must be sorted,
     * non-overlapping, nonempty, and in bounds. The glyphs after a
     * replacement move by its width delta (f32), runs are split where the
     * font changes and runs left without glyphs are removed.
     */
    public static function applyReplacements(layout:LineLayout, replacements:Array<Replacement>):Void {
        if (replacements.length == 0)
            return;

        var next = 0;
        var originalIndex = 0;
        var consumedEnd = 0;
        var shift = 0.0;
        final runs:Array<ShapedRun> = [];

        for (run in layout.runs) {
            // Segments of consecutive glyphs of the same font, within this run
            var segment:Null<ShapedRun> = null;
            for (sourceGlyph in run.glyphs) {
                final index = originalIndex;
                originalIndex++;
                if (index < consumedEnd)
                    continue;

                var glyph:ShapedGlyph;
                var fontId:FontId;
                if (next < replacements.length && replacements[next].glyphRangeStart == index) {
                    final replacement = replacements[next++];
                    consumedEnd = replacement.glyphRangeEnd;
                    final r = replacement.glyph;
                    glyph = new ShapedGlyph(r.id, new Point(f32(r.position.x + shift), r.position.y), r.index, r.isEmoji);
                    shift = f32(shift + replacement.widthDelta);
                    fontId = replacement.fontId;
                }
                else {
                    glyph = sourceGlyph;
                    glyph.position = new Point(f32(sourceGlyph.position.x + shift), sourceGlyph.position.y);
                    fontId = run.fontId;
                }

                if (segment != null && (segment.fontId:Int) == (fontId:Int)) {
                    segment.glyphs.push(glyph);
                }
                else {
                    segment = new ShapedRun(fontId, [glyph]);
                    runs.push(segment);
                }
            }
        }

        layout.runs = runs;
        layout.width = f32(layout.width + shift);
    }

    static inline function f32(value:Float):Float {
        return Shaper.f32(value);
    }

}

// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs, src/text_system/line.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.util.Utf8;

/**
 * A laid out and styled line of text
 */
class LineLayout {

    /** The font size for this line */
    public var fontSize:Pixels;

    /** The width of the line */
    public var width:Pixels;

    /** The ascent of the line */
    public var ascent:Pixels;

    /** The descent of the line */
    public var descent:Pixels;

    /** The shaped runs that make up this line */
    public var runs:Array<ShapedRun>;

    /** The length of the line in utf-8 bytes */
    public var len:Int;

    public function new(fontSize:Pixels = 0, width:Pixels = 0, ascent:Pixels = 0, descent:Pixels = 0, ?runs:Array<ShapedRun>, len:Int = 0) {
        this.fontSize = fontSize;
        this.width = width;
        this.ascent = ascent;
        this.descent = descent;
        this.runs = runs != null ? runs : [];
        this.len = len;
    }

    /**
     * The index for the character at the given x coordinate
     */
    public function indexForX(x:Pixels):Null<Int> {
        if (x >= width) {
            return null;
        }
        else {
            var r = runs.length - 1;
            while (r >= 0) {
                final glyphs = runs[r].glyphs;
                var g = glyphs.length - 1;
                while (g >= 0) {
                    final glyph = glyphs[g];
                    if (glyph.position.x <= x) {
                        return glyph.index;
                    }
                    g--;
                }
                r--;
            }
            return 0;
        }
    }

    /**
     * closestIndexForX returns the character boundary closest to the given x coordinate
     * (e.g. to handle aligning up/down arrow keys)
     */
    public function closestIndexForX(x:Pixels):Int {
        var prevIndex = 0;
        var prevX:Float = 0.0;

        for (run in runs) {
            for (glyph in run.glyphs) {
                if (glyph.position.x >= x) {
                    if (glyph.position.x - (x:Float) < (x:Float) - prevX) {
                        return glyph.index;
                    }
                    else {
                        return prevIndex;
                    }
                }
                prevIndex = glyph.index;
                prevX = glyph.position.x;
            }
        }

        if (len == 1) {
            if (x > width / 2.0) {
                return 1;
            }
            else {
                return 0;
            }
        }

        return len;
    }

    /**
     * The x position of the character at the given index
     */
    public function xForIndex(index:Int):Pixels {
        for (run in runs) {
            for (glyph in run.glyphs) {
                if (glyph.index >= index) {
                    return glyph.position.x;
                }
            }
        }
        return width;
    }

    /**
     * The corresponding Font at the given index
     */
    public function fontIdForIndex(index:Int):Null<FontId> {
        for (run in runs) {
            for (glyph in run.glyphs) {
                if (glyph.index >= index) {
                    return run.fontId;
                }
            }
        }
        return null;
    }

    /**
     * Split this layout at a byte index, returning `[prefix, suffix]`.
     *
     * - `prefix` contains glyphs for bytes `[0, byteIndex)` with original positions.
     *   Its width equals the x-advance up to the split point.
     * - `suffix` contains glyphs for bytes `[byteIndex, len)` with positions
     *   shifted left so the first glyph starts at x=0, and byte indices rebased to 0.
     * - `fontSize`, `ascent`, and `descent` are copied to both halves.
     */
    public function splitAt(byteIndex:Int):Array<LineLayout> {
        final xOffset = xForIndex(byteIndex);

        // Partition glyph runs. A single run may contribute glyphs to both halves.
        final leftRuns:Array<ShapedRun> = [];
        final rightRuns:Array<ShapedRun> = [];

        for (run in runs) {
            // partition_point: glyphs are expected sorted by index
            var splitPos = 0;
            {
                var lo = 0;
                var hi = run.glyphs.length;
                while (lo < hi) {
                    final mid = (lo + hi) >> 1;
                    if (run.glyphs[mid].index < byteIndex)
                        lo = mid + 1;
                    else
                        hi = mid;
                }
                splitPos = lo;
            }

            if (splitPos > 0) {
                leftRuns.push(new ShapedRun(run.fontId, run.glyphs.slice(0, splitPos)));
            }

            if (splitPos < run.glyphs.length) {
                final rightGlyphs:Array<ShapedGlyph> = [];
                for (i in splitPos...run.glyphs.length) {
                    final g = run.glyphs[i];
                    rightGlyphs.push(new ShapedGlyph(g.id, new Point(g.position.x - (xOffset:Float), g.position.y), g.index - byteIndex, g.isEmoji));
                }
                rightRuns.push(new ShapedRun(run.fontId, rightGlyphs));
            }
        }

        final left = new LineLayout(fontSize, xOffset, ascent, descent, leftRuns, byteIndex);
        final right = new LineLayout(fontSize, width - xOffset, ascent, descent, rightRuns, len - byteIndex);

        return [left, right];
    }

    /**
     * Computes where the line wraps for the given width (and line clamp).
     * Very similar to `LineWrapper.wrapLine()`, with some differences.
     * `maxLines` is -1 when there is no line clamp.
     */
    public function computeWrapBoundaries(text:String, wrapWidth:Pixels, maxLines:Int = -1):Array<WrapBoundary> {
        final boundaries:Array<WrapBoundary> = [];
        var firstNonWhitespaceIx:WrapBoundary = null;
        var lastCandidateIx:WrapBoundary = null;
        var lastCandidateX:Float = 0.0;
        var lastBoundary = new WrapBoundary(0, 0);
        var lastBoundaryX:Float = 0.0;
        var prevCh = 0;

        final decoded = new Utf8Text(text);

        // Flatten (run_ix, glyph_ix) pairs to iterate with a peek
        var runIx = 0;
        var glyphIx = 0;
        inline function advance() {
            glyphIx++;
            while (runIx < runs.length && glyphIx >= runs[runIx].glyphs.length) {
                runIx++;
                glyphIx = 0;
            }
        }
        while (runIx < runs.length && runs[runIx].glyphs.length == 0)
            runIx++;

        while (runIx < runs.length) {
            final glyph = runs[runIx].glyphs[glyphIx];
            final ch = decoded.codePointAtByte(glyph.index);
            final x:Float = glyph.position.x;
            final curRunIx = runIx;
            final curGlyphIx = glyphIx;
            advance();

            if (ch == '\n'.code) {
                continue;
            }

            final boundary = new WrapBoundary(curRunIx, curGlyphIx);

            // Here is very similar to `LineWrapper.wrapLine()` to determine text wrapping,
            // but there are some differences, so we have to duplicate the code here.
            if (LineWrapper.isWordChar(ch)) {
                if (prevCh == ' '.code && ch != ' '.code && firstNonWhitespaceIx != null) {
                    lastCandidateIx = boundary;
                    lastCandidateX = x;
                }
            }
            else {
                if (ch != ' '.code && firstNonWhitespaceIx != null) {
                    lastCandidateIx = boundary;
                    lastCandidateX = x;
                }
            }

            if (ch != ' '.code && firstNonWhitespaceIx == null) {
                firstNonWhitespaceIx = boundary;
            }

            final nextX:Float = runIx < runs.length ? runs[runIx].glyphs[glyphIx].position.x : width;
            final lineWidth = nextX - lastBoundaryX;

            if (lineWidth > wrapWidth && boundary.compare(lastBoundary) > 0) {
                // When used line_clamp, we should limit the number of lines.
                if (maxLines >= 0 && boundaries.length >= (maxLines > 0 ? maxLines - 1 : 0)) {
                    break;
                }

                if (lastCandidateIx != null) {
                    lastBoundary = lastCandidateIx;
                    lastBoundaryX = lastCandidateX;
                    lastCandidateIx = null;
                }
                else {
                    lastBoundary = boundary;
                    lastBoundaryX = x;
                }
                boundaries.push(lastBoundary);
            }
            prevCh = ch;
        }

        return boundaries;
    }

    /**
     * Paint this layout, using the given decoration runs to color glyphs
     * and draw underlines and strikethroughs.
     *
     * This is a lower-level alternative to `ShapedLine.paint()` for callers that
     * hold a bare layout and track decorations themselves.
     */
    public function paint(origin:Point, lineHeight:Pixels, align:TextAlign, alignWidth:Null<Float>, decorationRuns:Array<DecorationRun>, painter:TextPainter):Void {
        LinePaint.paintLine(origin, this, lineHeight, align, alignWidth, decorationRuns, null, painter, null);
    }

    /**
     * Paint the background of this layout, using the given decoration runs
     * to determine background colors.
     */
    public function paintBackground(origin:Point, lineHeight:Pixels, align:TextAlign, alignWidth:Null<Float>, decorationRuns:Array<DecorationRun>, painter:TextPainter):Void {
        LinePaint.paintLineBackground(origin, this, lineHeight, align, alignWidth, decorationRuns, null, painter);
    }

    public function toString():String {
        return 'LineLayout(fontSize=$fontSize, width=$width, ascent=$ascent, descent=$descent, len=$len, runs=$runs)';
    }

}

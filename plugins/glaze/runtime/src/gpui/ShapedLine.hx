// Ported from gpui-pre 0.3.10: src/text_system/line.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Utf8;

/**
 * A line of text that has been shaped and decorated.
 *
 * Rust derefs `ShapedLine` to its `LineLayout`: use the `layout` field
 * (or the forwarding methods) here. Painting goes through a `TextPainter`
 * (see `TextPainter` for how a `Window` provides one).
 */
class ShapedLine {

    public var layout:LineLayout;

    /** The text that was shaped for this line. */
    public var text:String;

    public var decorationRuns:Array<DecorationRun>;

    public function new(layout:LineLayout, text:String, ?decorationRuns:Array<DecorationRun>) {
        this.layout = layout;
        this.text = text;
        this.decorationRuns = decorationRuns != null ? decorationRuns : [];
    }

    public function clone():ShapedLine {
        return new ShapedLine(layout, text, decorationRuns.copy());
    }

    /**
     * Returns a forward-only cursor for this shaped line.
     */
    public function cursor():ShapedLineCursor {
        if (len() != Utf8.byteLength(text))
            throw 'cannot split a shaped line with an adjusted length';
        var byteOrdered = true;
        var previous = -1;
        for (run in layout.runs) {
            for (glyph in run.glyphs) {
                if (glyph.index < previous)
                    byteOrdered = false;
                previous = glyph.index;
            }
        }
        return new ShapedLineCursor(this, byteOrdered ? null : clone());
    }

    /** The length of the line in utf-8 bytes. */
    public inline function len():Int {
        return layout.len;
    }

    /**
     * The width of the shaped line in pixels.
     *
     * This is the glyph advance width computed by the text shaping system and is useful for
     * incrementally advancing a "pen" when painting multiple fragments on the same row.
     */
    public inline function width():Pixels {
        return layout.width;
    }

    public inline function fontSize():Pixels {
        return layout.fontSize;
    }

    public inline function ascent():Pixels {
        return layout.ascent;
    }

    public inline function descent():Pixels {
        return layout.descent;
    }

    public inline function runs():Array<ShapedRun> {
        return layout.runs;
    }

    public inline function xForIndex(index:Int):Pixels {
        return layout.xForIndex(index);
    }

    public inline function indexForX(x:Pixels):Null<Int> {
        return layout.indexForX(x);
    }

    public inline function closestIndexForX(x:Pixels):Int {
        return layout.closestIndexForX(x);
    }

    /**
     * Override the len, useful if you're rendering text a
     * as text b (e.g. rendering invisibles).
     */
    public function withLen(len:Int):ShapedLine {
        final l = layout;
        return new ShapedLine(new LineLayout(l.fontSize, l.width, l.ascent, l.descent, [for (run in l.runs) run.clone()], len), text, decorationRuns);
    }

    /**
     * Paint the line of text. `alignWidth` is null to use the width of the line.
     */
    public function paint(origin:Point, lineHeight:Pixels, align:TextAlign, alignWidth:Null<Float>, painter:TextPainter):Void {
        LinePaint.paintLine(origin, layout, lineHeight, align, alignWidth, decorationRuns, null, painter, null);
    }

    /**
     * Paint the line with a handler for each underline (called with the
     * byte range start and end, the origin, the width and the style).
     */
    public function paintWithUnderlineHandler(origin:Point, lineHeight:Pixels, align:TextAlign, alignWidth:Null<Float>, painter:TextPainter, paintUnderline:UnderlineHandler):Void {
        LinePaint.paintLine(origin, layout, lineHeight, align, alignWidth, decorationRuns, null, painter, paintUnderline);
    }

    /**
     * Paint the background of the line.
     */
    public function paintBackground(origin:Point, lineHeight:Pixels, align:TextAlign, alignWidth:Null<Float>, painter:TextPainter):Void {
        LinePaint.paintLineBackground(origin, layout, lineHeight, align, alignWidth, decorationRuns, null, painter);
    }

    /** `paint` with an alignment width that is known (a `Null<Float>` argument is boxed on hxcpp) */
    public function paintAligned(origin:Point, lineHeight:Pixels, align:TextAlign, alignWidth:Float, painter:TextPainter):Void {
        LinePaint.paintLineAligned(origin, layout, lineHeight, align, alignWidth, decorationRuns, null, painter, null);
    }

    /** `paintBackground` with an alignment width that is known */
    public function paintBackgroundAligned(origin:Point, lineHeight:Pixels, align:TextAlign, alignWidth:Float, painter:TextPainter):Void {
        LinePaint.paintLineBackgroundAligned(origin, layout, lineHeight, align, alignWidth, decorationRuns, null, painter);
    }

    /**
     * Split this shaped line at a byte index, returning `[prefix, suffix]`.
     *
     * - `prefix` contains glyphs for bytes `[0, byteIndex)` with original positions.
     *   Its width equals the x-advance up to the split point.
     * - `suffix` contains glyphs for bytes `[byteIndex, len)` with positions
     *   shifted left so the first glyph starts at x=0, and byte indices rebased to 0.
     * - Decoration runs are partitioned at the boundary; a run that straddles it is
     *   split into two with adjusted lengths.
     * - `fontSize`, `ascent`, and `descent` are copied to both halves.
     */
    public function splitAt(byteIndex:Int):Array<ShapedLine> {
        final layouts = layout.splitAt(byteIndex);

        // Partition decoration runs. A run straddling the boundary is split into two.
        final leftDecorations:Array<DecorationRun> = [];
        final rightDecorations:Array<DecorationRun> = [];
        var decorationOffset = 0;
        final splitPoint = byteIndex;

        for (decoration in decorationRuns) {
            final runEnd = decorationOffset + decoration.len;

            if (runEnd <= splitPoint) {
                leftDecorations.push(decoration.clone());
            }
            else if (decorationOffset >= splitPoint) {
                rightDecorations.push(decoration.clone());
            }
            else {
                leftDecorations.push(decoration.withLen(splitPoint - decorationOffset));
                rightDecorations.push(decoration.withLen(runEnd - splitPoint));
            }

            decorationOffset = runEnd;
        }

        // Split text
        final textLen = Utf8.byteLength(text);
        final leftText = byteIndex == textLen ? text : Utf8.substring(text, 0, byteIndex);
        final rightText = byteIndex == 0 ? text : Utf8.substringFrom(text, byteIndex);

        return [
            new ShapedLine(layouts[0], leftText, leftDecorations),
            new ShapedLine(layouts[1], rightText, rightDecorations)
        ];
    }

    public function toString():String {
        return 'ShapedLine($text, $layout)';
    }

}

/**
 * Called for each underline of a line: byte range (start, end), origin,
 * width and style.
 */
typedef UnderlineHandler = (rangeStart:Int, rangeEnd:Int, origin:Point, width:Pixels, style:UnderlineStyle, painter:TextPainter) -> Void;

/**
 * Incrementally splits a `ShapedLine` at increasing UTF-8 byte boundaries.
 *
 * Each piece preserves the original glyphs and decorations, rebased as in
 * `ShapedLine.splitAt()`. Byte-ordered glyphs are advanced in linear time,
 * copying each glyph and byte at most once; visually reordered glyphs fall
 * back to the existing split operation.
 */
class ShapedLineCursor {

    final line:ShapedLine;

    /** Bidirectional shaping can put glyphs out of byte order. */
    var unorderedRemainder:Null<ShapedLine>;

    var byteIndex:Int = 0;
    var runIndex:Int = 0;
    var glyphIndex:Int = 0;
    var decorationIndex:Int = 0;
    var decorationOffset:Int = 0;
    var _xOffset:Float = 0;

    public function new(line:ShapedLine, unorderedRemainder:Null<ShapedLine>) {
        this.line = line;
        this.unorderedRemainder = unorderedRemainder;
    }

    /**
     * Takes the bytes since the previous boundary.
     *
     * Throws if the boundary precedes the previous one, exceeds the line's
     * length, or falls inside a UTF-8 character.
     */
    public function takeUntil(byteIndex:Int):ShapedLine {
        if (byteIndex < this.byteIndex)
            throw 'split boundary moved backwards';
        if (byteIndex > line.len())
            throw 'split boundary exceeds line length';
        if (!Utf8.isCharBoundary(line.text, byteIndex))
            throw 'split boundary is not a UTF-8 character boundary';

        final previousIndex = this.byteIndex;
        final previousX = _xOffset;
        if (unorderedRemainder != null) {
            final parts = unorderedRemainder.splitAt(byteIndex - previousIndex);
            unorderedRemainder = parts[1];
            this.byteIndex = byteIndex;
            _xOffset = line.layout.xForIndex(byteIndex);
            return parts[0];
        }
        final runs:Array<ShapedRun> = [];
        var nextX:Float = line.layout.width;
        final layoutRuns = line.layout.runs;
        while (runIndex < layoutRuns.length) {
            final run = layoutRuns[runIndex];
            final start = glyphIndex;
            while (glyphIndex < run.glyphs.length) {
                if (run.glyphs[glyphIndex].index >= byteIndex) {
                    break;
                }
                glyphIndex += 1;
            }
            final end = glyphIndex;
            if (start < end) {
                final glyphs:Array<ShapedGlyph> = [];
                for (i in start...end) {
                    final glyph = run.glyphs[i];
                    glyphs.push(new ShapedGlyph(glyph.id, new Point(glyph.position.x - previousX, glyph.position.y), glyph.index - previousIndex, glyph.isEmoji));
                }
                runs.push(new ShapedRun(run.fontId, glyphs));
            }
            if (glyphIndex < run.glyphs.length) {
                nextX = run.glyphs[glyphIndex].position.x;
                break;
            }
            runIndex += 1;
            glyphIndex = 0;
        }
        final decorations:Array<DecorationRun> = [];
        while (decorationIndex < line.decorationRuns.length) {
            final decoration = line.decorationRuns[decorationIndex];
            if (!(decorationOffset < byteIndex || (decoration.len == 0 && decorationOffset == byteIndex)))
                break;
            final end = decorationOffset + decoration.len;
            final start = Std.int(Math.max(decorationOffset, previousIndex));
            final len = Std.int(Math.min(end, byteIndex)) - start;
            if (len > 0 || decoration.len == 0) {
                decorations.push(decoration.withLen(len));
            }
            if (end <= byteIndex) {
                decorationIndex += 1;
                decorationOffset = end;
            }
            else {
                break;
            }
        }
        this.byteIndex = byteIndex;
        _xOffset = nextX;
        final l = line.layout;
        return new ShapedLine(
            new LineLayout(l.fontSize, nextX - previousX, l.ascent, l.descent, runs, byteIndex - previousIndex),
            Utf8.substring(line.text, previousIndex, byteIndex),
            decorations
        );
    }

    /** Returns the original line's x position at the current boundary. */
    public inline function xOffset():Pixels {
        return _xOffset;
    }

}

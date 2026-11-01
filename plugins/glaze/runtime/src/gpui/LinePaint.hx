// Ported from gpui-pre 0.3.10: src/text_system/line.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The painting functions of `line.rs` (`paint_line`, `paint_line_background`,
 * `line_paint_bounds`, `aligned_origin_x`), shared by `ShapedLine`,
 * `WrappedLine` and `LineLayout`.
 *
 * Positions are kept in local Float variables (Rust mutates `Point`s), so
 * painting a line only allocates when it emits decorations.
 */
class LinePaint {

    /**
     * Paints the glyphs, underlines and strikethroughs of a line.
     * `wrapBoundaries` is null for an unwrapped line, `paintUnderline` null
     * to paint underlines with `painter.paintUnderline()`.
     */
    public static function paintLine(origin:Point, layout:LineLayout, lineHeight:Pixels, align:TextAlign, alignWidth:Null<Float>, decorationRuns:Array<DecorationRun>, wrapBoundaries:Null<Array<WrapBoundary>>, painter:TextPainter, paintUnderline:Null<ShapedLine.UnderlineHandler>):Void {
        final wraps:Array<WrapBoundary> = wrapBoundaries != null ? wrapBoundaries : NO_WRAPS;
        final lineBounds = linePaintBounds(origin, layout, lineHeight, align, alignWidth, wraps);
        final pushed = painter.pushLayer(lineBounds);

        final paddingTop = (lineHeight - layout.ascent - layout.descent) / 2.0;
        final baselineOffsetY = paddingTop + layout.ascent;
        final underlineYOffset = TextSystem.underlineYOffset(lineHeight, layout.ascent, layout.descent);
        var decorationIndex = 0;
        var wrapIndex = 0;
        var runEnd = 0;
        var color = Hsla.black();

        // current_underline: (origin, style, range)
        var hasUnderline = false;
        var underlineX:Float = 0;
        var underlineY:Float = 0;
        var underlineStyle:UnderlineStyle = null;
        var underlineRangeStart = 0;
        var underlineRangeEnd = 0;

        // current_strikethrough: (origin, style)
        var hasStrikethrough = false;
        var strikethroughX:Float = 0;
        var strikethroughY:Float = 0;
        var strikethroughStyle:StrikethroughStyle = null;

        final textSystem = painter.textSystem;
        final effectiveAlignWidth:Float = alignWidth != null ? alignWidth : layout.width;
        var glyphOriginX = alignedOriginX(origin, effectiveAlignWidth, 0.0, align, layout, wrapIndex < wraps.length ? wraps[wrapIndex] : null);
        var glyphOriginY:Float = origin.y;
        var prevGlyphX:Float = 0;
        var maxGlyphWidth:Float = 0;
        var maxGlyphHeight:Float = 0;
        var firstGlyphX:Float = origin.x;

        inline function emitUnderline(rangeStart:Int, rangeEnd:Int, x:Float, y:Float, width:Float, style:UnderlineStyle) {
            if (paintUnderline != null)
                paintUnderline(rangeStart, rangeEnd, new Point(x, y), width, style, painter);
            else
                painter.paintUnderlineAt(x, y, width, style);
        }

        final runs = layout.runs;
        for (runIx in 0...runs.length) {
            final run = runs[runIx];
            final maxGlyphSize = textSystem.boundingBox(run.fontId, layout.fontSize).size;
            maxGlyphWidth = maxGlyphSize.width;
            maxGlyphHeight = maxGlyphSize.height;

            final glyphs = run.glyphs;
            for (glyphIx in 0...glyphs.length) {
                final glyph = glyphs[glyphIx];
                glyphOriginX += glyph.position.x - prevGlyphX;
                if (glyphIx == 0 && runIx == 0) {
                    firstGlyphX = glyphOriginX;
                }

                if (wrapIndex < wraps.length && wraps[wrapIndex].runIx == runIx && wraps[wrapIndex].glyphIx == glyphIx) {
                    wrapIndex++;
                    if (hasUnderline) {
                        if (glyphOriginX == underlineX) {
                            underlineX -= maxGlyphWidth / 2.0;
                        }
                        emitUnderline(underlineRangeStart, underlineRangeEnd, underlineX, underlineY, glyphOriginX - underlineX, underlineStyle);
                        if (glyph.index < runEnd) {
                            underlineX = origin.x;
                            underlineY += lineHeight;
                        }
                        else {
                            hasUnderline = false;
                        }
                    }
                    if (hasStrikethrough) {
                        if (glyphOriginX == strikethroughX) {
                            strikethroughX -= maxGlyphWidth / 2.0;
                        }
                        painter.paintStrikethroughAt(strikethroughX, strikethroughY, glyphOriginX - strikethroughX, strikethroughStyle);
                        if (glyph.index < runEnd) {
                            strikethroughX = origin.x;
                            strikethroughY += lineHeight;
                        }
                        else {
                            hasStrikethrough = false;
                        }
                    }

                    glyphOriginX = alignedOriginX(origin, effectiveAlignWidth, glyph.position.x, align, layout, wrapIndex < wraps.length ? wraps[wrapIndex] : null);
                    glyphOriginY += lineHeight;
                }
                prevGlyphX = glyph.position.x;

                var finishedUnderline = false;
                var finishedUnderlineX:Float = 0;
                var finishedUnderlineY:Float = 0;
                var finishedUnderlineStyle:UnderlineStyle = null;
                var finishedUnderlineStart = 0;
                var finishedUnderlineEnd = 0;
                var finishedStrikethrough = false;
                var finishedStrikethroughX:Float = 0;
                var finishedStrikethroughY:Float = 0;
                var finishedStrikethroughStyle:StrikethroughStyle = null;

                inline function takeUnderline() {
                    finishedUnderline = true;
                    finishedUnderlineX = underlineX;
                    finishedUnderlineY = underlineY;
                    finishedUnderlineStyle = underlineStyle;
                    finishedUnderlineStart = underlineRangeStart;
                    finishedUnderlineEnd = underlineRangeEnd;
                    hasUnderline = false;
                }

                inline function takeStrikethrough() {
                    finishedStrikethrough = true;
                    finishedStrikethroughX = strikethroughX;
                    finishedStrikethroughY = strikethroughY;
                    finishedStrikethroughStyle = strikethroughStyle;
                    hasStrikethrough = false;
                }

                if (glyph.index >= runEnd) {
                    var styleRun:DecorationRun = decorationIndex < decorationRuns.length ? decorationRuns[decorationIndex++] : null;

                    // ignore style runs that apply to a partial glyph
                    while (styleRun != null) {
                        if (glyph.index < runEnd + styleRun.len) {
                            break;
                        }
                        runEnd += styleRun.len;
                        styleRun = decorationIndex < decorationRuns.length ? decorationRuns[decorationIndex++] : null;
                    }

                    if (styleRun != null) {
                        final styleRunStart = runEnd;
                        if (hasUnderline) {
                            if (styleRun.underline == null || !styleRun.underline.equals(underlineStyle)) {
                                takeUnderline();
                            }
                            else {
                                underlineRangeEnd = styleRunStart + styleRun.len;
                            }
                        }
                        final runUnderline = styleRun.underline;
                        if (runUnderline != null && !hasUnderline) {
                            hasUnderline = true;
                            underlineX = glyphOriginX;
                            underlineY = glyphOriginY + underlineYOffset;
                            underlineStyle = new UnderlineStyle(runUnderline.thickness, runUnderline.color != null ? runUnderline.color : styleRun.color, runUnderline.wavy);
                            underlineRangeStart = styleRunStart;
                            underlineRangeEnd = styleRunStart + styleRun.len;
                        }
                        if (hasStrikethrough && (styleRun.strikethrough == null || !styleRun.strikethrough.equals(strikethroughStyle))) {
                            takeStrikethrough();
                        }
                        final runStrikethrough = styleRun.strikethrough;
                        if (runStrikethrough != null && !hasStrikethrough) {
                            hasStrikethrough = true;
                            strikethroughX = glyphOriginX;
                            strikethroughY = glyphOriginY + (((layout.ascent * 0.5) + baselineOffsetY) * 0.5);
                            strikethroughStyle = new StrikethroughStyle(runStrikethrough.thickness, runStrikethrough.color != null ? runStrikethrough.color : styleRun.color);
                        }

                        runEnd += styleRun.len;
                        color = styleRun.color;
                    }
                    else {
                        runEnd = layout.len;
                        if (hasUnderline)
                            takeUnderline();
                        if (hasStrikethrough)
                            takeStrikethrough();
                    }
                }

                if (finishedUnderline) {
                    if (finishedUnderlineX == glyphOriginX) {
                        finishedUnderlineX -= maxGlyphWidth / 2.0;
                    }
                    emitUnderline(finishedUnderlineStart, finishedUnderlineEnd, finishedUnderlineX, finishedUnderlineY, glyphOriginX - finishedUnderlineX, finishedUnderlineStyle);
                }

                if (finishedStrikethrough) {
                    if (finishedStrikethroughX == glyphOriginX) {
                        finishedStrikethroughX -= maxGlyphWidth / 2.0;
                    }
                    painter.paintStrikethroughAt(finishedStrikethroughX, finishedStrikethroughY, glyphOriginX - finishedStrikethroughX, finishedStrikethroughStyle);
                }

                // max_glyph_bounds.intersects(content_mask.bounds)
                final mask = painter.contentMaskBounds;
                if (glyphOriginX < mask.origin.x + mask.size.width
                    && glyphOriginX + maxGlyphWidth > mask.origin.x
                    && glyphOriginY < mask.origin.y + mask.size.height
                    && glyphOriginY + maxGlyphHeight > mask.origin.y) {
                    final paintX = glyphOriginX;
                    final paintY = glyphOriginY + baselineOffsetY + glyph.position.y;
                    if (glyph.isEmoji) {
                        painter.paintEmojiAt(paintX, paintY, run.fontId, glyph.id, layout.fontSize);
                    }
                    else {
                        painter.paintGlyphAt(paintX, paintY, run.fontId, glyph.id, layout.fontSize, color);
                    }
                }
            }
        }

        var lastLineEndX = firstGlyphX + layout.width;
        if (wraps.length > 0) {
            final boundary = wraps[wraps.length - 1];
            final glyph = layout.runs[boundary.runIx].glyphs[boundary.glyphIx];
            lastLineEndX -= glyph.position.x;
        }

        if (hasUnderline) {
            if (lastLineEndX == underlineX) {
                underlineX -= maxGlyphWidth / 2.0;
            }
            emitUnderline(underlineRangeStart, underlineRangeEnd, underlineX, underlineY, lastLineEndX - underlineX, underlineStyle);
            hasUnderline = false;
        }

        if (hasStrikethrough) {
            if (lastLineEndX == strikethroughX) {
                strikethroughX -= maxGlyphWidth / 2.0;
            }
            painter.paintStrikethroughAt(strikethroughX, strikethroughY, lastLineEndX - strikethroughX, strikethroughStyle);
            hasStrikethrough = false;
        }

        if (pushed)
            painter.popLayer();
    }

    static final NO_WRAPS:Array<WrapBoundary> = [];

    /**
     * Paints the background colors of the decoration runs of a line.
     */
    public static function paintLineBackground(origin:Point, layout:LineLayout, lineHeight:Pixels, align:TextAlign, alignWidth:Null<Float>, decorationRuns:Array<DecorationRun>, wrapBoundaries:Null<Array<WrapBoundary>>, painter:TextPainter):Void {
        final wraps:Array<WrapBoundary> = wrapBoundaries != null ? wrapBoundaries : NO_WRAPS;
        final lineBounds = linePaintBounds(origin, layout, lineHeight, align, alignWidth, wraps);
        final pushed = painter.pushLayer(lineBounds);

        var decorationIndex = 0;
        var wrapIndex = 0;
        var runEnd = 0;
        var hasBackground = false;
        var backgroundX:Float = 0;
        var backgroundY:Float = 0;
        var backgroundColor:Hsla = null;
        final textSystem = painter.textSystem;
        final effectiveAlignWidth:Float = alignWidth != null ? alignWidth : layout.width;
        var glyphOriginX = alignedOriginX(origin, effectiveAlignWidth, 0.0, align, layout, wrapIndex < wraps.length ? wraps[wrapIndex] : null);
        var glyphOriginY:Float = origin.y;
        var prevGlyphX:Float = 0;
        var maxGlyphWidth:Float = 0;

        final runs = layout.runs;
        for (runIx in 0...runs.length) {
            final run = runs[runIx];
            maxGlyphWidth = textSystem.boundingBox(run.fontId, layout.fontSize).size.width;

            final glyphs = run.glyphs;
            for (glyphIx in 0...glyphs.length) {
                final glyph = glyphs[glyphIx];
                glyphOriginX += glyph.position.x - prevGlyphX;

                if (wrapIndex < wraps.length && wraps[wrapIndex].runIx == runIx && wraps[wrapIndex].glyphIx == glyphIx) {
                    wrapIndex++;
                    if (hasBackground) {
                        if (glyphOriginX == backgroundX) {
                            backgroundX -= maxGlyphWidth / 2.0;
                        }
                        painter.paintFill(backgroundX, backgroundY, glyphOriginX - backgroundX, lineHeight, backgroundColor);
                        if (glyph.index < runEnd) {
                            backgroundX = origin.x;
                            backgroundY += lineHeight;
                        }
                        else {
                            hasBackground = false;
                        }
                    }

                    glyphOriginX = alignedOriginX(origin, effectiveAlignWidth, glyph.position.x, align, layout, wrapIndex < wraps.length ? wraps[wrapIndex] : null);
                    glyphOriginY += lineHeight;
                }
                prevGlyphX = glyph.position.x;

                var finished = false;
                var finishedX:Float = 0;
                var finishedY:Float = 0;
                var finishedColor:Hsla = null;
                if (glyph.index >= runEnd) {
                    var styleRun:DecorationRun = decorationIndex < decorationRuns.length ? decorationRuns[decorationIndex++] : null;

                    // ignore style runs that apply to a partial glyph
                    while (styleRun != null) {
                        if (glyph.index < runEnd + styleRun.len) {
                            break;
                        }
                        runEnd += styleRun.len;
                        styleRun = decorationIndex < decorationRuns.length ? decorationRuns[decorationIndex++] : null;
                    }

                    if (styleRun != null) {
                        if (hasBackground && (styleRun.backgroundColor == null || !styleRun.backgroundColor.equals(backgroundColor))) {
                            finished = true;
                            finishedX = backgroundX;
                            finishedY = backgroundY;
                            finishedColor = backgroundColor;
                            hasBackground = false;
                        }
                        if (styleRun.backgroundColor != null && !hasBackground) {
                            hasBackground = true;
                            backgroundX = glyphOriginX;
                            backgroundY = glyphOriginY;
                            backgroundColor = styleRun.backgroundColor;
                        }
                        runEnd += styleRun.len;
                    }
                    else {
                        runEnd = layout.len;
                        if (hasBackground) {
                            finished = true;
                            finishedX = backgroundX;
                            finishedY = backgroundY;
                            finishedColor = backgroundColor;
                            hasBackground = false;
                        }
                    }
                }

                if (finished) {
                    final width = glyphOriginX - finishedX;
                    if (finishedX == glyphOriginX) {
                        finishedX -= maxGlyphWidth / 2.0;
                    }
                    painter.paintFill(finishedX, finishedY, width, lineHeight, finishedColor);
                }
            }
        }

        var lastLineEndX = origin.x + layout.width;
        if (wraps.length > 0) {
            final boundary = wraps[wraps.length - 1];
            final glyph = layout.runs[boundary.runIx].glyphs[boundary.glyphIx];
            lastLineEndX -= glyph.position.x;
        }

        if (hasBackground) {
            if (lastLineEndX == backgroundX) {
                backgroundX -= maxGlyphWidth / 2.0;
            }
            painter.paintFill(backgroundX, backgroundY, lastLineEndX - backgroundX, lineHeight, backgroundColor);
        }

        if (pushed)
            painter.popLayer();
    }

    /**
     * Bounds covered by a painted line (all its rows, aligned).
     */
    public static function linePaintBounds(origin:Point, layout:LineLayout, lineHeight:Pixels, align:TextAlign, alignWidth:Null<Float>, wrapBoundaries:Array<WrapBoundary>):Bounds {
        var bounds = new Bounds(origin, new Size(layout.width, lineHeight * (wrapBoundaries.length + 1.0)));
        if (align == Left || layout.len == 0) {
            return bounds;
        }

        final effectiveAlignWidth:Float = alignWidth != null ? alignWidth : layout.width;
        var rowStart:Float = 0;
        final count = wrapBoundaries.length + 1;
        for (row in 0...count) {
            final rowEnd:Float = if (row < wrapBoundaries.length) {
                final boundary = wrapBoundaries[row];
                layout.runs[boundary.runIx].glyphs[boundary.glyphIx].position.x;
            }
            else {
                layout.width;
            }
            final width = rowEnd - rowStart;
            final offset:Float = switch align {
                case Left: 0.0;
                case Center: (effectiveAlignWidth - width) / 2.0;
                case Right: effectiveAlignWidth - width;
            }
            bounds = bounds.union(new Bounds(new Point(origin.x + offset, origin.y + lineHeight * row), new Size(width, lineHeight)));
            rowStart = rowEnd;
        }
        return bounds;
    }

    /**
     * X of the first glyph of a row, for the given alignment.
     */
    public static function alignedOriginX(origin:Point, alignWidth:Pixels, lastGlyphX:Pixels, align:TextAlign, layout:LineLayout, wrapBoundary:Null<WrapBoundary>):Pixels {
        final endOfLine:Float = if (wrapBoundary != null) {
            layout.runs[wrapBoundary.runIx].glyphs[wrapBoundary.glyphIx].position.x;
        }
        else {
            layout.width;
        }

        final lineWidth = endOfLine - (lastGlyphX:Float);

        return switch align {
            case Left: origin.x;
            case Center: (origin.x * 2.0 + alignWidth - lineWidth) / 2.0;
            case Right: origin.x + alignWidth - lineWidth;
        }
    }

}

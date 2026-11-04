// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A line of text that has been wrapped to fit a given width
 */
class WrappedLineLayout {

    /** The line layout, pre-wrapping. */
    public var unwrappedLayout:LineLayout;

    /** The boundaries at which the line was wrapped */
    public var wrapBoundaries:Array<WrapBoundary>;

    /** The width of the line, if it was wrapped */
    public var wrapWidth:Null<Float>;

    public function new(unwrappedLayout:LineLayout, ?wrapBoundaries:Array<WrapBoundary>, ?wrapWidth:Float) {
        this.unwrappedLayout = unwrappedLayout;
        this.wrapBoundaries = wrapBoundaries != null ? wrapBoundaries : [];
        this.wrapWidth = wrapWidth;
    }

    /** The length of the underlying text, in utf8 bytes. */
    public inline function len():Int {
        return unwrappedLayout.len;
    }

    /** The width of this line, in pixels, whether or not it was wrapped. */
    public function width():Pixels {
        final w:Float = wrapWidth != null ? wrapWidth : gpui.util.MathUtil.F32_MAX;
        return Math.min(w, unwrappedLayout.width);
    }

    /**
     * The size of the whole wrapped text, for the given line_height.
     * can span multiple lines if there are multiple wrap boundaries.
     */
    public function size(lineHeight:Pixels):Size {
        return new Size(width(), lineHeight * (wrapBoundaries.length + 1));
    }

    /** `size(lineHeight).height` without the `Size` */
    public inline function sizeHeight(lineHeight:Pixels):Pixels {
        return lineHeight * (wrapBoundaries.length + 1);
    }

    /** The ascent of a line in this layout */
    public inline function ascent():Pixels {
        return unwrappedLayout.ascent;
    }

    /** The descent of a line in this layout */
    public inline function descent():Pixels {
        return unwrappedLayout.descent;
    }

    /** The font size of this layout */
    public inline function fontSize():Pixels {
        return unwrappedLayout.fontSize;
    }

    /** The runs in this layout, sans wrapping */
    public inline function runs():Array<ShapedRun> {
        return unwrappedLayout.runs;
    }

    /**
     * The index corresponding to a given position in this layout for the given line height.
     *
     * See also `closestIndexForPosition()`.
     */
    public inline function indexForPosition(position:Point, lineHeight:Pixels):IndexResult {
        return _indexForPosition(position, lineHeight, false);
    }

    /**
     * The closest index to a given position in this layout for the given line height.
     *
     * Closest means the character boundary closest to the given position.
     *
     * See also `LineLayout.closestIndexForX()`.
     */
    public inline function closestIndexForPosition(position:Point, lineHeight:Pixels):IndexResult {
        return _indexForPosition(position, lineHeight, true);
    }

    function _indexForPosition(position:Point, lineHeight:Pixels, closest:Bool):IndexResult {
        // Rust: `(position.y / line_height) as usize` (saturating cast)
        final wrappedLineIx:Int = gpui.util.MathUtil.toI32(Math.max(0, position.y / (lineHeight:Float)));

        var wrappedLineStartIndex:Int;
        var wrappedLineStartX:Float;
        if (wrappedLineIx > 0) {
            if (wrappedLineIx - 1 >= wrapBoundaries.length) {
                return Err(0);
            }
            final lineStartBoundary = wrapBoundaries[wrappedLineIx - 1];
            final run = unwrappedLayout.runs[lineStartBoundary.runIx];
            final glyph = run.glyphs[lineStartBoundary.glyphIx];
            wrappedLineStartIndex = glyph.index;
            wrappedLineStartX = glyph.position.x;
        }
        else {
            wrappedLineStartIndex = 0;
            wrappedLineStartX = 0;
        }

        var wrappedLineEndIndex:Int;
        var wrappedLineEndX:Float;
        if (wrappedLineIx < wrapBoundaries.length) {
            final nextWrapBoundary = wrapBoundaries[wrappedLineIx];
            final run = unwrappedLayout.runs[nextWrapBoundary.runIx];
            final glyph = run.glyphs[nextWrapBoundary.glyphIx];
            wrappedLineEndIndex = glyph.index;
            wrappedLineEndX = glyph.position.x;
        }
        else {
            wrappedLineEndIndex = unwrappedLayout.len;
            wrappedLineEndX = unwrappedLayout.width;
        }

        final x = position.x + wrappedLineStartX;
        if (x < wrappedLineStartX) {
            return Err(wrappedLineStartIndex);
        }
        else if (x >= wrappedLineEndX) {
            return Err(wrappedLineEndIndex);
        }
        else {
            if (closest) {
                return Ok(unwrappedLayout.closestIndexForX(x));
            }
            else {
                // The shaper can place a trailing zero-width wrap boundary glyph slightly past
                // the line's width, so the row can extend past where `indexForX` has glyphs.
                final index = unwrappedLayout.indexForX(x);
                return index != null ? Ok(index) : Err(wrappedLineEndIndex);
            }
        }
    }

    /**
     * Returns the pixel position for the given byte index.
     */
    public function positionForIndex(index:Int, lineHeight:Pixels):Null<Point> {
        var lineStartIx = 0;
        final count = wrapBoundaries.length + 1;
        for (ix in 0...count) {
            final lineEndIx = if (ix < wrapBoundaries.length) {
                final wrapBoundary = wrapBoundaries[ix];
                unwrappedLayout.runs[wrapBoundary.runIx].glyphs[wrapBoundary.glyphIx].index;
            }
            else {
                len();
            }
            final lineY = ix * (lineHeight:Float);
            if (index < lineStartIx) {
                break;
            }
            else if (index > lineEndIx) {
                lineStartIx = lineEndIx;
                continue;
            }
            else {
                final lineStartX = unwrappedLayout.xForIndex(lineStartIx);
                final x = unwrappedLayout.xForIndex(index) - lineStartX;
                return new Point(x, lineY);
            }
        }

        return null;
    }

}

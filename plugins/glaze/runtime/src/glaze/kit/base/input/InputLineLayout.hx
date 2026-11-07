// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs (`LineLayout`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Point;
import glaze.ShapedLine;
import glaze.Size;
import glaze.TextAlign;
import glaze.Window;
import glaze.util.MathUtil;
import glaze.util.Utf8;

/**
 * A soft wrapped visual line position: the result of
 * `InputLineLayout.closestIndexForPosition` (Rust returns a tuple).
 */
class LineIndex {

    /** Local byte index in the line layout */
    public final index:Int;

    /** True when the index landed on the wrap boundary of a non-final sub-line */
    public final lineEndAffinity:Bool;

    public inline function new(index:Int, lineEndAffinity:Bool) {
        this.index = index;
        this.lineEndAffinity = lineEndAffinity;
    }

}

/**
 * A whitespace indicator of a line: its visual line, x and kind (Rust tuple
 * `(usize, Pixels, bool)`).
 */
class WhitespaceChar {

    public final lineIndex:Int;

    public final x:Float;

    public final isTab:Bool;

    public inline function new(lineIndex:Int, x:Float, isTab:Bool) {
        this.lineIndex = lineIndex;
        this.x = x;
        this.isTab = isTab;
    }

}

/**
 * The layout info of a line with soft wrapped lines.
 *
 * Rust names it `LineLayout`: renamed because `glaze.LineLayout` (the shaped
 * line of the text system) has the same name.
 */
class InputLineLayout {

    /** Total bytes length of this line. */
    var _len:Int;

    /** The soft wrapped lines of this line (Include the first line). */
    public var wrappedLines:Array<InputLine>;

    /**
     * Extra left offset applied to continuation wrapped lines, used to reserve the first line's
     * indentation when `WrappingIndent.Same` is used.
     */
    public var wrapIndent:Float;

    public var longestWidth:Float;

    public var whitespaceIndicators:Null<WhitespaceIndicators>;

    /** Whitespace indicators: (line_index, x_position, is_tab) */
    public var whitespaceChars:Array<WhitespaceChar>;

    /**
     * Whether any run of this line carries a background color, so `paintBackground`
     * can skip the glyph walk for the common case of a line without highlights.
     */
    var hasBackground:Bool;

    public function new() {
        _len = 0;
        longestWidth = 0.0;
        wrappedLines = [];
        wrapIndent = 0.0;
        whitespaceChars = [];
        whitespaceIndicators = null;
        hasBackground = false;
    }

    /** Record whether any run of this line carries a background color. */
    public function withBackground(hasBackground:Bool):InputLineLayout {
        this.hasBackground = hasBackground;
        return this;
    }

    /**
     * Set the left offset reserved for continuation wrapped lines (Rust
     * builder `wrap_indent`, renamed: the field has that name).
     */
    public function withWrapIndent(wrapIndent:Float):InputLineLayout {
        this.wrapIndent = wrapIndent;
        return this;
    }

    /**
     * The pixel indent applied to the given visual line, relative to the line's
     * leading text. Only continuation lines (index > 0) are indented.
     */
    inline function lineIndent(lineIndex:Int):Float {
        return lineIndex == 0 ? 0.0 : wrapIndent;
    }

    /** Rust builder `lines` */
    public function lines(wrappedLines:Array<ShapedLine>):InputLineLayout {
        setWrappedLines(wrappedLines);
        return this;
    }

    public function setWrappedLines(wrappedLines:Array<ShapedLine>):Void {
        var len = 0;
        var width = 0.0;
        for (l in wrappedLines) {
            len += l.len();
            if (l.width() > width)
                width = l.width();
        }
        this._len = len;
        this.longestWidth = width;
        this.wrappedLines = [for (l in wrappedLines) InputLine.fromShapedLine(l)];
    }

    public function inlineLines(lines:Array<InputLine>):InputLineLayout {
        var len = 0;
        var width = 0.0;
        for (line in lines) {
            len += line.len;
            if (line.width > width)
                width = line.width;
        }
        this._len = len;
        this.longestWidth = width;
        this.wrappedLines = lines;
        return this;
    }

    public function withWhitespaces(indicators:Null<WhitespaceIndicators>):InputLineLayout {
        this.whitespaceIndicators = indicators;
        if (indicators == null)
            return this;

        final spaceWidth:Float = indicators.space.width();
        final spaceIndicatorOffset = spaceWidth / 2.0;

        final decoded = new Utf8Text();
        for (lineIndex in 0...wrappedLines.length) {
            final wrappedLine = wrappedLines[lineIndex];
            decoded.reset(wrappedLine.text);
            for (k in 0...decoded.count) {
                final c = decoded.codePoints[k];
                if (c == ' '.code || c == '\t'.code) {
                    final relativeOffset = decoded.byteOffsets[k];
                    final isTab = c == '\t'.code;
                    final startX = wrappedLine.xForIndex(relativeOffset);
                    final endX = wrappedLine.xForIndex(relativeOffset + 1);
                    // Center the indicator in the actual character's space
                    final xPosition = c == ' '.code ? (startX + endX) / 2.0 - spaceIndicatorOffset : startX;

                    whitespaceChars.push(new WhitespaceChar(lineIndex, xPosition, isTab));
                }
            }
        }
        return this;
    }

    public inline function len():Int {
        return _len;
    }

    /**
     * Get the position (x, y) for the given index in this line layout.
     *
     * - The `offset` is a local byte index in this line layout.
     * - When `lineEndAffinity` is true, an offset at a soft wrap boundary is placed at
     *   the end of the current visual line rather than the start of the next one.
     * - The return value is relative to the top-left corner of this line layout, start from (0, 0)
     */
    public function positionForIndex(offset:Int, lastLayout:LastLayout, lineEndAffinity:Bool):Null<Point> {
        var accLen = 0;
        var offsetY = 0.0;

        final xOffset:Float = lastLayout.alignmentOffset(longestWidth);

        for (i in 0...wrappedLines.length) {
            final line = wrappedLines[i];
            final isLast = i + 1 == wrappedLines.length;

            final matches = if (line.len == 0) {
                // Empty visual lines still own their boundary offset.
                offset == accLen;
            }
            else if (isLast || lineEndAffinity) {
                // Inclusive: cursor can sit at end of this visual line.
                offset >= accLen && offset <= accLen + line.len;
            }
            else {
                // Exclusive: boundary offset belongs to the next visual line.
                offset >= accLen && offset < accLen + line.len;
            }

            if (matches) {
                final x = line.xForIndex(offset > accLen ? offset - accLen : 0) + xOffset + lineIndent(i);
                return new Point(x, offsetY);
            }

            // Always advance by actual line length. The last line gets +1 so the
            // cursor can be placed after the final character.
            accLen += isLast ? line.len + 1 : line.len;
            offsetY += (lastLayout.lineHeight:Float);
        }

        return null;
    }

    /**
     * Get the closest index for the given x in this line layout.
     *
     * This ignores y, so it only makes sense for a layout that is known to occupy a single
     * visual line. Wrapped layouts must use `closestIndexForPosition`, which also
     * reports the caret affinity that a wrap boundary needs.
     */
    public function closestIndexForX(x:Float, lastLayout:LastLayout):Int {
        var accLen = 0;
        final xOffset:Float = lastLayout.alignmentOffset(longestWidth);
        final x = x - xOffset;

        for (i in 0...wrappedLines.length) {
            final line = wrappedLines[i];
            final indent = lineIndent(i);
            if (x <= indent + line.width)
                return accLen + line.closestIndexForX(x - indent);
            accLen += line.len;
        }

        return accLen;
    }

    // Outputs of `wrappedLineAt()` (Rust returns a tuple)
    var hitLine:Int = 0;
    var hitOffset:Int = 0;
    var hitX:Float = 0;

    /**
     * Resolve `pos` to the wrapped sub-line under it.
     *
     * Sets the sub-line index, the byte offset that sub-line starts at within this line
     * layout, and `pos.x` translated into that sub-line's own coordinate space
     * (`hitLine`, `hitOffset`, `hitX`), or returns false (Rust `None`).
     */
    function wrappedLineAt(pos:Point, lastLayout:LastLayout):Bool {
        var offset = 0;
        var lineTop = 0.0;
        final xOffset:Float = lastLayout.alignmentOffset(longestWidth);

        for (i in 0...wrappedLines.length) {
            final line = wrappedLines[i];
            final lineBottom = lineTop + (lastLayout.lineHeight:Float);
            if (pos.y >= lineTop && pos.y < lineBottom) {
                hitLine = i;
                hitOffset = offset;
                hitX = pos.x - xOffset - lineIndent(i);
                return true;
            }

            offset += line.len;
            lineTop = lineBottom;
        }

        return false;
    }

    /**
     * Get the index for the given position (x, y) in this line layout.
     *
     * The `pos` is relative to the top-left corner of this line layout, start from (0, 0).
     *
     * Returns a local byte index in this line layout (start from 0) together with the caret
     * affinity to use for it: `true` when the index landed on the wrap boundary of a non-final
     * sub-line. That boundary offset is shared by the end of one visual line and the start of
     * the next, so the affinity is what tells `positionForIndex` which of the two the
     * caret belongs to. Without it a click past the last glyph of a wrapped line would put a
     * visible caret on the following line.
     */
    public function closestIndexForPosition(pos:Point, lastLayout:LastLayout):Null<LineIndex> {
        if (!wrappedLineAt(pos, lastLayout))
            return null;
        final i = hitLine;
        final line = wrappedLines[i];
        final ix = line.closestIndexForX(hitX);
        final lineEndAffinity = i + 1 < wrappedLines.length && ix == line.len;

        return new LineIndex(hitOffset + ix, lineEndAffinity);
    }

    /**
     * How many columns the given position sits past the end of the line under it.
     *
     * Past the end of a line there is no glyph to hit-test against, so a position out
     * there resolves to the line end and loses how far right it really was. The extra
     * distance is reported here in whole spaces, letting a columnar selection keep its
     * width over a short row. Only the final visual line of a wrapped layout has that
     * trailing space; a continuation line ends at a wrap boundary, where the next glyph
     * merely lives on the following row.
     *
     * The `pos` is relative to the top-left corner of this line layout, start from (0, 0).
     */
    public function columnsPastLineEnd(pos:Point, lastLayout:LastLayout):Int {
        if (!wrappedLineAt(pos, lastLayout))
            return 0;
        final i = hitLine;

        final spaceWidth:Float = lastLayout.spaceWidth;
        if (i + 1 < wrappedLines.length || spaceWidth <= 0.0)
            return 0;

        final pastEnd = hitX - wrappedLines[i].width;
        if (pastEnd <= 0.0)
            return 0;

        return Std.int(MathUtil.round(pastEnd / spaceWidth));
    }

    public function indexForPosition(pos:Point, lastLayout:LastLayout):Null<Int> {
        if (!wrappedLineAt(pos, lastLayout))
            return null;
        final index = wrappedLines[hitLine].indexForX(hitX);
        return index == null ? null : hitOffset + index;
    }

    public function size(lineHeight:Float):Size {
        var width = longestWidth;
        if (wrappedLines.length > 0) {
            width = wrappedLines[0].width + lineIndent(0);
            for (ix in 1...wrappedLines.length) {
                final w = wrappedLines[ix].width + lineIndent(ix);
                if (w > width)
                    width = w;
            }
        }
        return new Size(width, wrappedLines.length * lineHeight);
    }

    /**
     * Paint only the glyph background quads of this line.
     *
     * gpui's `ShapedLine.paint` does not draw backgrounds, so every line painted with
     * `paint` needs this called first, with the same origin and align width.
     */
    public function paintBackground(pos:Point, lineHeight:Float, textAlign:TextAlign, alignWidth:Null<Float>, window:Window, cx:App):Void {
        // Painting a background walks every glyph and pushes a scene layer, so skip the
        // whole pass for lines that have no background color to paint.
        if (!hasBackground)
            return;

        for (ix in 0...wrappedLines.length) {
            wrappedLines[ix].paintBackground(new Point(pos.x + lineIndent(ix), pos.y + ix * lineHeight), lineHeight, textAlign, alignWidth, window, cx);
        }
    }

    /** `paintBackground` with an align width that is known (a `Null<Float>` argument is boxed on hxcpp) */
    public function paintBackgroundAligned(pos:Point, lineHeight:Float, textAlign:TextAlign, alignWidth:Float, window:Window, cx:App):Void {
        if (!hasBackground)
            return;

        for (ix in 0...wrappedLines.length) {
            wrappedLines[ix].paintBackgroundAligned(new Point(pos.x + lineIndent(ix), pos.y + ix * lineHeight), lineHeight, textAlign, alignWidth, window, cx);
        }
    }

    /** `paint` with an align width that is known */
    public function paintAligned(pos:Point, lineHeight:Float, textAlign:TextAlign, alignWidth:Float, window:Window, cx:App):Void {
        for (ix in 0...wrappedLines.length) {
            wrappedLines[ix].paintAligned(new Point(pos.x + lineIndent(ix), pos.y + ix * lineHeight), lineHeight, textAlign, alignWidth, window, cx);
        }

        // Paint whitespace indicators
        final indicators = whitespaceIndicators;
        if (indicators != null) {
            final painter = window.textPainter();
            for (ws in whitespaceChars) {
                final invisible = ws.isTab ? indicators.tab.clone() : indicators.space.clone();

                final origin = new Point(pos.x + ws.x + lineIndent(ws.lineIndex), pos.y + ws.lineIndex * lineHeight);

                invisible.paintAligned(origin, lineHeight, textAlign, alignWidth, painter);
            }
        }
    }

    public function paint(pos:Point, lineHeight:Float, textAlign:TextAlign, alignWidth:Null<Float>, window:Window, cx:App):Void {
        for (ix in 0...wrappedLines.length) {
            wrappedLines[ix].paint(new Point(pos.x + lineIndent(ix), pos.y + ix * lineHeight), lineHeight, textAlign, alignWidth, window, cx);
        }

        // Paint whitespace indicators
        final indicators = whitespaceIndicators;
        if (indicators != null) {
            final painter = window.textPainter();
            for (ws in whitespaceChars) {
                final invisible = ws.isTab ? indicators.tab.clone() : indicators.space.clone();

                final origin = new Point(pos.x + ws.x + lineIndent(ws.lineIndex), pos.y + ws.lineIndex * lineHeight);

                invisible.paint(origin, lineHeight, textAlign, alignWidth, painter);
            }
        }
    }

}

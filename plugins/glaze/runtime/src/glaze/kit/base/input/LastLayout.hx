// Ported from gpui-kit 0.8.1: crates/base/src/input/base/layout.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.Pixels;
import glaze.Range;
import glaze.TextAlign;

/**
 * The layout of the visible part of an input, as of its last prepaint.
 */
class LastLayout {

    public var visibleRange:Range;

    public var visibleBufferLines:Array<Int>;

    public var visibleLineByteOffsets:Array<Int>;

    public var visibleTop:Pixels;

    public var visibleRangeOffset:Range;

    public var lines:Array<InputLineLayout>;

    public var lineHeight:Pixels;

    public var wrapWidth:Null<Pixels>;

    public var wrappingIndent:WrappingIndent;

    /**
     * Width of one space in the editor font.
     *
     * Past the end of a line there are no glyphs to hit-test against, so this
     * is the step used to measure how far past the end a pointer sits.
     */
    public var spaceWidth:Pixels;

    public var cursorBounds:Null<Bounds>;

    public var textAlign:TextAlign;

    public var contentWidth:Pixels;

    public function new(visibleRange:Range, visibleBufferLines:Array<Int>, visibleLineByteOffsets:Array<Int>, visibleTop:Pixels,
            visibleRangeOffset:Range, lines:Array<InputLineLayout>, lineHeight:Pixels, wrapWidth:Null<Pixels>, wrappingIndent:WrappingIndent,
            spaceWidth:Pixels, cursorBounds:Null<Bounds>, textAlign:TextAlign, contentWidth:Pixels) {
        this.visibleRange = visibleRange;
        this.visibleBufferLines = visibleBufferLines;
        this.visibleLineByteOffsets = visibleLineByteOffsets;
        this.visibleTop = visibleTop;
        this.visibleRangeOffset = visibleRangeOffset;
        this.lines = lines;
        this.lineHeight = lineHeight;
        this.wrapWidth = wrapWidth;
        this.wrappingIndent = wrappingIndent;
        this.spaceWidth = spaceWidth;
        this.cursorBounds = cursorBounds;
        this.textAlign = textAlign;
        this.contentWidth = contentWidth;
    }

    /** A shallow copy (Rust `Clone`: the lines are shared, like their `Rc`). */
    public function clone():LastLayout {
        return new LastLayout(visibleRange, visibleBufferLines.copy(), visibleLineByteOffsets.copy(), visibleTop, visibleRangeOffset, lines, lineHeight,
            wrapWidth, wrappingIndent, spaceWidth, cursorBounds, textAlign, contentWidth);
    }

    /** The layout of the buffer line `row`, when it is visible. */
    public function line(row:Int):Null<InputLineLayout> {
        // Rust `binary_search` on the sorted visible rows.
        var lo = 0;
        var hi = visibleBufferLines.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            final value = visibleBufferLines[mid];
            if (value == row) {
                return mid < lines.length ? lines[mid] : null;
            }
            else if (value < row) {
                lo = mid + 1;
            }
            else {
                hi = mid;
            }
        }
        return null;
    }

    /** The x offset of a line of `lineWidth` for the text alignment. */
    public function alignmentOffset(lineWidth:Pixels):Pixels {
        return switch textAlign {
            case Left: 0.;
            case Center: (contentWidth - lineWidth).half().max(0.);
            case Right: (contentWidth - lineWidth).max(0.);
        }
    }

}

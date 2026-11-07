// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;

/**
 * A line with soft wrapped lines info.
 */
class LineItem {

    /** The byte length of the line, without the end `\n`. */
    var _len:Int;

    /**
     * Number of leading characters of the line reserved as indentation for
     * continuation wrapped lines, when `WrappingIndent.Same` is used.
     *
     * Zero when `WrappingIndent.None` is used or the line is not wrapped.
     */
    public var indent:Int;

    /**
     * The soft wrapped lines relative byte range (0..len) of this line (Include first line).
     *
     * Not contains the line end `\n`.
     */
    public var wrappedLines:Array<Range>;

    /** Width-only reuse is valid only while every measured fit decision stays unchanged. */
    public var validWidths:WidthRange;

    public function new(len:Int, indent:Int, wrappedLines:Array<Range>, validWidths:WidthRange) {
        this._len = len;
        this.indent = indent;
        this.wrappedLines = wrappedLines;
        this.validWidths = validWidths;
    }

    /** Get the bytes length of this line. */
    public inline function len():Int {
        return _len;
    }

    /** Get number of soft wrapped lines of this line (include the first line). */
    public inline function linesLen():Int {
        return wrappedLines.length;
    }

    /** Rust `Clone` */
    public function clone():LineItem {
        return new LineItem(_len, indent, wrappedLines.copy(), validWidths.copy());
    }

}

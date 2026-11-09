// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/wrap_map.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Font;
import glaze.Range;
import ropey.Rope;

using glaze.kit.base.input.RopeExt;

/**
 * WrapMap: Soft-wrapping layer (Buffer to Wrap rows).
 *
 * This module wraps the existing TextWrapper and provides:
 * - BufferPoint to WrapPoint mapping
 * - Efficient buffer_line to wrap_row queries
 * - Incremental updates when text or layout changes
 *
 * Buffer line to wrap row mapping is backed by the `TextWrapper`'s lines.
 */
class WrapMap {

    /** The underlying text wrapper (reuses existing implementation) */
    final _wrapper:TextWrapper;

    public function new(font:Font, fontSize:Float, wrapWidth:Null<Float>) {
        _wrapper = new TextWrapper(font, fontSize, wrapWidth);
    }

    /** Get total number of wrap rows (visual rows after soft-wrapping) */
    public inline function wrapRowCount():Int {
        return _wrapper.len();
    }

    /** Get total number of buffer lines (logical lines) */
    public inline function bufferLineCount():Int {
        return _wrapper.linesCount();
    }

    /** Convert buffer position to wrap position */
    public function bufferPosToWrapPos(pos:BufferPoint):WrapPoint {
        // Clamp to valid range
        final lastLine = bufferLineCount() > 0 ? bufferLineCount() - 1 : 0;
        final line = pos.line < lastLine ? pos.line : lastLine;
        final lineItem = _wrapper.line(line);

        final col = lineItem != null ? (pos.col < lineItem.len() ? pos.col : lineItem.len()) : 0;

        // Calculate offset in rope
        final lineStartOffset = _wrapper.text.lineStartOffset(line);
        final offset = lineStartOffset + col;

        // Use TextWrapper's existing conversion
        final displayPoint = _wrapper.offsetToDisplayPoint(offset);

        return new WrapPoint(displayPoint.row, displayPoint.column);
    }

    /** Convert wrap position to buffer position */
    public function wrapPosToBufferPos(pos:WrapPoint):BufferPoint {
        // Clamp wrap_row to valid range
        final lastRow = wrapRowCount() > 0 ? wrapRowCount() - 1 : 0;
        final row = pos.row < lastRow ? pos.row : lastRow;

        // Use TextWrapper's existing conversion
        final displayPoint = new WrapDisplayPoint(row, 0, pos.col);
        final offset = _wrapper.displayPointToOffset(displayPoint);

        // Convert offset to buffer position
        final point = _wrapper.text.offsetToPoint(offset);
        final lineStart = _wrapper.text.lineStartOffset(point.row);
        final col = offset > lineStart ? offset - lineStart : 0;

        return new BufferPoint(point.row, col);
    }

    /** Get the buffer line for a given wrap row */
    public inline function wrapRowToBufferLine(wrapRow:Int):Int {
        return _wrapper.wrapRowToBufferLine(wrapRow);
    }

    /** Get the first wrap row for a given buffer line */
    public inline function bufferLineToFirstWrapRow(line:Int):Int {
        return _wrapper.bufferLineToFirstWrapRow(line);
    }

    /** Get the wrap row range for a buffer line: [start, end) */
    public inline function bufferLineToWrapRowRange(line:Int):Range {
        return _wrapper.bufferLineToWrapRowRange(line);
    }

    /** Update text (incremental or full) */
    public function onTextChanged(changedText:Rope, range:Range, newText:Rope, cx:App):Void {
        _wrapper.adjustInlineMetrics(range, newText.len());
        _wrapper.update(changedText, range, newText, cx);
    }

    /** Update layout parameters (wrap width or font) */
    public function setInlineMetrics(metrics:Array<InlineMetric>, cx:App):Void {
        _wrapper.setInlineMetrics(metrics, cx);
    }

    public function onLayoutChanged(wrapWidth:Null<Float>, cx:App):Void {
        _wrapper.setWrapWidth(wrapWidth, cx);
    }

    /** Set the wrapping indent mode for continuation lines. */
    public function setWrappingIndent(wrappingIndent:WrappingIndent, cx:App):Void {
        _wrapper.setWrappingIndent(wrappingIndent, cx);
    }

    /** Set the number of spaces per tab stop. Returns whether it changed. */
    public function setTabSize(tabSize:Int, cx:App):Bool {
        return _wrapper.setTabSize(tabSize, cx);
    }

    /** Set font parameters */
    public function setFont(font:Font, fontSize:Float, cx:App):Void {
        _wrapper.setFont(font, fontSize, cx);
    }

    /** Ensure text is prepared (initializes wrapper if needed) */
    public function ensureTextPrepared(text:Rope, cx:App):Bool {
        return _wrapper.prepareIfNeed(text, cx);
    }

    /** Initialize with text */
    public function setText(text:Rope, cx:App):Void {
        _wrapper.setDefaultText(text);
        _wrapper.prepareIfNeed(text, cx);
    }

    /** Get access to the underlying wrapper (for rendering/hit-testing) */
    public inline function wrapper():TextWrapper {
        return _wrapper;
    }

    /** Get the line item by buffer row index. */
    public inline function line(row:Int):Null<LineItem> {
        return _wrapper.line(row);
    }

    /** Get the rope text */
    public inline function text():Rope {
        return _wrapper.text;
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/display_map.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Font;
import glaze.Range;
import ropey.Rope;

using glaze.kit.base.input.RopeExt;

/**
 * DisplayMap is the main interface for Input/Textarea coordinate mapping.
 *
 * gpui-kit projects buffer to wrap (soft-wrapping), then wrap to display
 * (folding). Folding is a feature of gpui-kit's code editor, which Glaze does
 * not have (its code editor is Cityscape): the display rows here are the wrap
 * rows.
 *
 * Input only needs to work with BufferPoint and DisplayPoint.
 */
class DisplayMap {

    final wrapMap:WrapMap;

    public function new(font:Font, fontSize:Float, wrapWidth:Null<Float>) {
        wrapMap = new WrapMap(font, fontSize, wrapWidth);
    }

/// Core Coordinate Mapping

    /** Convert buffer position to display position */
    public function bufferPosToDisplayPos(pos:BufferPoint):DisplayPoint {
        // Buffer to Wrap
        final wrapPos = wrapMap.bufferPosToWrapPos(pos);

        // Wrap to Display
        final displayRow = wrapRowToDisplayRow(wrapPos.row);
        if (displayRow != null)
            return new DisplayPoint(displayRow, wrapPos.col);

        // Past the last row: the nearest visible row
        return new DisplayPoint(nearestVisibleDisplayRow(wrapPos.row), 0);
    }

    /** Convert display position to buffer position */
    public function displayPosToBufferPos(pos:DisplayPoint):BufferPoint {
        // Display to Wrap
        final wrapRow = displayRowToWrapRow(pos.row);

        // Wrap to Buffer
        return wrapMap.wrapPosToBufferPos(new WrapPoint(wrapRow != null ? wrapRow : 0, pos.col));
    }

    /** Get total number of visible display rows */
    public inline function displayRowCount():Int {
        return wrapMap.wrapRowCount();
    }

    /** Get the buffer line for a given display row */
    public function displayRowToBufferLine(displayRow:Int):Int {
        // Display to Wrap
        final wrapRow = displayRowToWrapRow(displayRow);

        // Wrap to Buffer line
        return wrapMap.wrapRowToBufferLine(wrapRow != null ? wrapRow : 0);
    }

    /**
     * Get the display row range for a buffer line: [start, end)
     * Returns null if the buffer line has no row
     */
    public function bufferLineToDisplayRowRange(line:Int):Null<Range> {
        // Buffer line to Wrap row range
        final wrapRowRange = wrapMap.bufferLineToWrapRowRange(line);

        // Find first and last display rows in this range
        var firstDisplayRow:Null<Int> = null;
        var lastDisplayRow:Null<Int> = null;

        for (wrapRow in wrapRowRange.start...wrapRowRange.end) {
            final displayRow = wrapRowToDisplayRow(wrapRow);
            if (displayRow != null) {
                if (firstDisplayRow == null)
                    firstDisplayRow = displayRow;
                lastDisplayRow = displayRow;
            }
        }

        if (firstDisplayRow != null && lastDisplayRow != null)
            return new Range(firstDisplayRow, lastDisplayRow + 1);
        return null;
    }

    /**
     * First display row of a buffer line, or the nearest visible display row.
     */
    public function bufferLineToDisplayRow(line:Int):Int {
        final range = bufferLineToDisplayRowRange(line);
        if (range != null)
            return range.start;
        final wrapRow = wrapMap.bufferLineToFirstWrapRow(line);
        return nearestVisibleDisplayRow(wrapRow);
    }

/// Text and Layout Updates

    /** Update text (incremental or full) */
    public function onTextChanged(changedText:Rope, range:Range, newText:Rope, cx:App):Void {
        wrapMap.onTextChanged(changedText, range, newText, cx);
    }

    /** Update layout parameters (wrap width or font) */
    public function setInlineMetrics(metrics:Array<InlineMetric>, cx:App):Void {
        wrapMap.setInlineMetrics(metrics, cx);
    }

    public function onLayoutChanged(wrapWidth:Null<Float>, cx:App):Void {
        wrapMap.onLayoutChanged(wrapWidth, cx);
    }

    /** Set the wrapping indent for continuation lines. */
    public function setWrappingIndent(wrappingIndent:WrappingIndent, cx:App):Void {
        wrapMap.setWrappingIndent(wrappingIndent, cx);
    }

    /** Set the number of spaces per tab stop. */
    public function setTabSize(tabSize:Int, cx:App):Void {
        wrapMap.setTabSize(tabSize, cx);
    }

    /** Set font parameters */
    public function setFont(font:Font, fontSize:Float, cx:App):Void {
        wrapMap.setFont(font, fontSize, cx);
    }

    /** Ensure text is prepared (initializes wrapper if needed) */
    public function ensureTextPrepared(text:Rope, cx:App):Void {
        wrapMap.ensureTextPrepared(text, cx);
    }

    /** Initialize with text */
    public function setText(text:Rope, cx:App):Void {
        wrapMap.setText(text, cx);
    }

/// Wrap Display Point Operations

    /** Convert byte offset to wrap display point (with soft wrap info). */
    public inline function offsetToWrapDisplayPoint(offset:Int):WrapDisplayPoint {
        return wrapMap.wrapper().offsetToDisplayPoint(offset);
    }

    /**
     * Like `offsetToWrapDisplayPoint`, but honours the caret's line-end affinity so
     * an offset on a soft wrap boundary resolves to the row the caret is drawn on.
     */
    public inline function offsetToWrapDisplayPointWithAffinity(offset:Int, lineEndAffinity:Bool):WrapDisplayPoint {
        return wrapMap.wrapper().offsetToDisplayPointWithAffinity(offset, lineEndAffinity);
    }

    /** Resolve the caret's visual row through wrapping. */
    public function offsetToDisplayRow(offset:Int, lineEndAffinity:Bool):Int {
        final point = offsetToWrapDisplayPointWithAffinity(offset, lineEndAffinity);
        final row = wrapRowToDisplayRow(point.row);
        return row != null ? row : nearestVisibleDisplayRow(point.row);
    }

    /** Convert wrap display point to byte offset. */
    public inline function wrapDisplayPointToOffset(point:WrapDisplayPoint):Int {
        return wrapMap.wrapper().displayPointToOffset(point);
    }

    /** Convert wrap display point to a `RopePoint` (buffer line/col). */
    public inline function wrapDisplayPointToPoint(point:WrapDisplayPoint):RopePoint {
        return wrapMap.wrapper().displayPointToPoint(point);
    }

    /**
     * Convert a wrap row to a display row (the same row). Returns null past
     * the last row.
     */
    public inline function wrapRowToDisplayRow(wrapRow:Int):Null<Int> {
        return wrapRow < wrapMap.wrapRowCount() ? wrapRow : null;
    }

    /** Find the nearest visible display row for a given wrap row. */
    public function nearestVisibleDisplayRow(wrapRow:Int):Int {
        final count = wrapMap.wrapRowCount();
        final last = count > 0 ? count - 1 : 0;
        return wrapRow < last ? wrapRow : last;
    }

    /** Convert a display row to a wrap row (the same row), or null past the last row. */
    public inline function displayRowToWrapRow(displayRow:Int):Null<Int> {
        return displayRow < wrapMap.wrapRowCount() ? displayRow : null;
    }

    public function displayRowColumnToOffset(displayRow:Int, column:Int):Int {
        final wrapRow = displayRowToWrapRow(displayRow);
        return wrapMap.wrapper().displayPointToOffset(new WrapDisplayPoint(wrapRow != null ? wrapRow : 0, 0, column));
    }

    /** Get the longest row index (by byte length). */
    public inline function longestRow():Int {
        return wrapMap.wrapper().longestRow();
    }

/// Access Methods

    /** Get the line item by buffer row index. */
    public inline function line(row:Int):Null<LineItem> {
        return wrapMap.line(row);
    }

    /** Get the rope text */
    public inline function text():Rope {
        return wrapMap.text();
    }

    /** How many wrap rows a buffer line has */
    public inline function visibleWrapRowCountForBufferLine(line:Int):Int {
        final range = wrapMap.bufferLineToWrapRowRange(line);
        return range.end - range.start;
    }

    /** Get the wrap row count */
    public inline function wrapRowCount():Int {
        return wrapMap.wrapRowCount();
    }

    /** Get the buffer line count (logical lines) */
    public inline function bufferLineCount():Int {
        return wrapMap.bufferLineCount();
    }

}

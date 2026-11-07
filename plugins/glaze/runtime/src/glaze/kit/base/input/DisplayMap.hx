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
 * DisplayMap is the main interface for Editor/Input coordinate mapping.
 *
 * It manages the two-layer projection:
 * 1. Buffer to Wrap (soft-wrapping)
 * 2. Wrap to Display (folding)
 *
 * Editor/Input only needs to work with BufferPoint and DisplayPoint.
 */
class DisplayMap {

    final wrapMap:WrapMap;

    final foldMap:FoldMap;

    public function new(font:Font, fontSize:Float, wrapWidth:Null<Float>) {
        wrapMap = new WrapMap(font, fontSize, wrapWidth);
        foldMap = new FoldMap();
    }

/// Core Coordinate Mapping

    /** Convert buffer position to display position */
    public function bufferPosToDisplayPos(pos:BufferPoint):DisplayPoint {
        // Buffer to Wrap
        final wrapPos = wrapMap.bufferPosToWrapPos(pos);

        // Wrap to Display
        final displayRow = foldMap.wrapRowToDisplayRow(wrapPos.row);
        if (displayRow != null)
            return new DisplayPoint(displayRow, wrapPos.col);

        // Cursor is in a folded region, find nearest visible row
        return new DisplayPoint(foldMap.nearestVisibleDisplayRow(wrapPos.row), 0); // Column 0 at fold boundary
    }

    /** Convert display position to buffer position */
    public function displayPosToBufferPos(pos:DisplayPoint):BufferPoint {
        // Display to Wrap
        final wrapRow = foldMap.displayRowToWrapRow(pos.row);

        // Wrap to Buffer
        return wrapMap.wrapPosToBufferPos(new WrapPoint(wrapRow != null ? wrapRow : 0, pos.col));
    }

    /** Get total number of visible display rows */
    public inline function displayRowCount():Int {
        return foldMap.displayRowCount();
    }

    /** Get the buffer line for a given display row */
    public function displayRowToBufferLine(displayRow:Int):Int {
        // Display to Wrap
        final wrapRow = foldMap.displayRowToWrapRow(displayRow);

        // Wrap to Buffer line
        return wrapMap.wrapRowToBufferLine(wrapRow != null ? wrapRow : 0);
    }

    /**
     * Get the display row range for a buffer line: [start, end)
     * Returns null if the buffer line is completely hidden
     */
    public function bufferLineToDisplayRowRange(line:Int):Null<Range> {
        // Buffer line to Wrap row range
        final wrapRowRange = wrapMap.bufferLineToWrapRowRange(line);

        // Find first and last visible display rows in this range
        var firstDisplayRow:Null<Int> = null;
        var lastDisplayRow:Null<Int> = null;

        for (wrapRow in wrapRowRange.start...wrapRowRange.end) {
            final displayRow = foldMap.wrapRowToDisplayRow(wrapRow);
            if (displayRow != null) {
                if (firstDisplayRow == null)
                    firstDisplayRow = displayRow;
                lastDisplayRow = displayRow;
            }
        }

        if (firstDisplayRow != null && lastDisplayRow != null)
            return new Range(firstDisplayRow, lastDisplayRow + 1);
        return null; // Completely folded
    }

    /** Check if a buffer line is completely hidden */
    public inline function isBufferLineHidden(line:Int):Bool {
        return bufferLineToDisplayRowRange(line) == null;
    }

    /**
     * First display row of a buffer line. If the line is fully folded, returns the
     * nearest visible display row.
     */
    public function bufferLineToDisplayRow(line:Int):Int {
        final range = bufferLineToDisplayRowRange(line);
        if (range != null)
            return range.start;
        final wrapRow = wrapMap.bufferLineToFirstWrapRow(line);
        return foldMap.nearestVisibleDisplayRow(wrapRow);
    }

    /** Set fold candidates (from tree-sitter/LSP) */
    public function setFoldCandidates(candidates:Array<FoldRange>):Void {
        foldMap.setCandidates(candidates);
        rebuildFoldProjection();
    }

    /** Set a fold at the given start_line (must be in candidates) */
    public function setFolded(startLine:Int, folded:Bool):Void {
        foldMap.setFolded(startLine, folded);
        rebuildFoldProjection();
    }

    /** Toggle fold at the given start_line */
    public function toggleFold(startLine:Int):Void {
        foldMap.toggleFold(startLine);
        rebuildFoldProjection();
    }

    /** Check if a line is currently folded */
    public inline function isFoldedAt(startLine:Int):Bool {
        return foldMap.isFoldedAt(startLine);
    }

    /** Check if a line is a fold candidate */
    public inline function isFoldCandidate(startLine:Int):Bool {
        return foldMap.isFoldCandidate(startLine);
    }

    /** Get all currently folded ranges */
    public inline function foldedRanges():Array<FoldRange> {
        return foldMap.foldedRanges();
    }

    /** Clear all folds */
    public function clearFolds():Void {
        foldMap.clearFolds();
        rebuildFoldProjection();
    }

/// Text and Layout Updates

    /**
     * Adjust folds and candidates for a text edit before updating the wrap map.
     *
     * Must be called with the OLD text (before replacement) and the edit range/new_text
     * so we can compute which old lines were affected.
     */
    public function adjustFoldsForEdit(oldText:Rope, range:Range, newText:String):Void {
        if (foldMap.foldedRanges().length == 0 && foldMap.foldCandidates().length == 0)
            return;

        final editStartLine = oldText.offsetToPoint(range.start).row;
        final editEndLine = oldText.offsetToPoint(range.end < oldText.len() ? range.end : oldText.len()).row;

        final oldLinesInRange = editEndLine > editStartLine ? editEndLine - editStartLine : 0;
        var newLinesInRange = 0;
        for (i in 0...newText.length) {
            if (StringTools.fastCodeAt(newText, i) == '\n'.code)
                newLinesInRange++;
        }
        final lineDelta = newLinesInRange - oldLinesInRange;

        foldMap.adjustFoldsForEdit(editStartLine, editEndLine, lineDelta);
    }

    /**
     * Incrementally update fold candidates after a text edit.
     *
     * Extracts new fold candidates only within the edited byte range
     * and merges them with existing (already adjusted) candidates.
     */
    public function updateFoldCandidatesForEdit(extractFoldRanges:(Range, Rope) -> Array<FoldRange>, editByteRange:Range, newText:Rope):Void {
        final newStartLine = newText.offsetToPoint(editByteRange.start).row;
        final newEndLine = newText.offsetToPoint(editByteRange.end < newText.len() ? editByteRange.end : newText.len()).row;

        final newCandidates = extractFoldRanges(editByteRange, newText);
        foldMap.mergeCandidatesForEdit(newStartLine, newEndLine, newCandidates);
    }

    /** Update text (incremental or full) */
    public function onTextChanged(changedText:Rope, range:Range, newText:Rope, cx:App):Void {
        wrapMap.onTextChanged(changedText, range, newText, cx);
        rebuildFoldProjection();
    }

    /** Update layout parameters (wrap width or font) */
    public function setInlineMetrics(metrics:Array<InlineMetric>, cx:App):Void {
        wrapMap.setInlineMetrics(metrics, cx);
        rebuildFoldProjection();
    }

    public function onLayoutChanged(wrapWidth:Null<Float>, cx:App):Void {
        wrapMap.onLayoutChanged(wrapWidth, cx);
        rebuildFoldProjection();
    }

    /** Set the wrapping indent for continuation lines. */
    public function setWrappingIndent(wrappingIndent:WrappingIndent, cx:App):Void {
        wrapMap.setWrappingIndent(wrappingIndent, cx);
        rebuildFoldProjection();
    }

    /** Set the number of spaces per tab stop. */
    public function setTabSize(tabSize:Int, cx:App):Void {
        if (wrapMap.setTabSize(tabSize, cx))
            rebuildFoldProjection();
    }

    /** Set font parameters */
    public function setFont(font:Font, fontSize:Float, cx:App):Void {
        wrapMap.setFont(font, fontSize, cx);
        rebuildFoldProjection();
    }

    /** Ensure text is prepared (initializes wrapper if needed) */
    public function ensureTextPrepared(text:Rope, cx:App):Void {
        final didInitialize = wrapMap.ensureTextPrepared(text, cx);
        if (didInitialize)
            rebuildFoldProjection();
    }

    /** Initialize with text */
    public function setText(text:Rope, cx:App):Void {
        wrapMap.setText(text, cx);
        rebuildFoldProjection();
    }

/// Internal Helpers

    /**
     * Rebuild fold projection after wrap_map or fold state changes
     * Only rebuilds if there are actually folded ranges
     */
    function rebuildFoldProjection():Void {
        if (foldMap.foldedRanges().length > 0) {
            foldMap.rebuild(wrapMap);
        }
        else {
            // No active folds: identity mapping (wrap_row == display_row).
            // Just update cached count so query methods work without Vec allocation.
            foldMap.markDirtyWithWrapCount(wrapMap.wrapRowCount());
        }
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

    /** Resolve the caret's visual row through both wrapping and folded regions. */
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
     * Convert a wrap row to a display row (skipping folded rows).
     * Returns null if the wrap row is folded.
     */
    public inline function wrapRowToDisplayRow(wrapRow:Int):Null<Int> {
        return foldMap.wrapRowToDisplayRow(wrapRow);
    }

    /** Find the nearest visible display row for a given wrap row. */
    public inline function nearestVisibleDisplayRow(wrapRow:Int):Int {
        return foldMap.nearestVisibleDisplayRow(wrapRow);
    }

    /** Convert a display row to a wrap row. */
    public inline function displayRowToWrapRow(displayRow:Int):Null<Int> {
        return foldMap.displayRowToWrapRow(displayRow);
    }

    public function displayRowColumnToOffset(displayRow:Int, column:Int):Int {
        final wrapRow = foldMap.displayRowToWrapRow(displayRow);
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

    /** Calculate how many wrap rows of a buffer line are visible (not folded) */
    public inline function visibleWrapRowCountForBufferLine(line:Int):Int {
        return wrapMap.visibleWrapRowCountForLine(line, foldMap);
    }

    /** Get the wrap row count (before folding) */
    public inline function wrapRowCount():Int {
        return wrapMap.wrapRowCount();
    }

    /** Get the buffer line count (logical lines) */
    public inline function bufferLineCount():Int {
        return wrapMap.bufferLineCount();
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/fold_map.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;

/**
 * A run of wrap rows hidden by folding.
 */
class HiddenRows {

    public var wrapRows:Range;

    /** How many wrap rows the runs before this one hide. */
    public final hiddenBefore:Int;

    public inline function new(wrapRows:Range, hiddenBefore:Int) {
        this.wrapRows = wrapRows;
        this.hiddenBefore = hiddenBefore;
    }

    /** The display row of the first visible wrap row after this run. */
    public inline function displayStart():Int {
        return wrapRows.start - hiddenBefore;
    }

}

/**
 * FoldMap: Folding projection layer (Wrap rows to Display rows).
 *
 * This module manages code folding by:
 * - Filtering out wrap rows that belong to folded regions
 * - Maintaining bidirectional mapping: wrap_row to display_row
 * - Handling fold state changes and rebuilding the projection
 */
class FoldMap {

    /**
     * The wrap rows hidden by folding: sorted, disjoint and non-adjacent.
     *
     * The projection is kept as these runs rather than a table per wrap row,
     * so rebuilding it after an edit costs the number of folds, not the
     * length of the document, and both directions are a binary search.
     */
    final hidden:Array<HiddenRows> = [];

    /** How many wrap rows `hidden` hides in total. */
    var totalHidden:Int = 0;

    /** The wrap row count the projection was last built for. */
    var projectedWrapRowCount:Int = 0;

    /**
     * Candidate fold ranges (from tree-sitter/LSP)
     * Sorted by start_line, unique start_line
     */
    var candidates:Array<FoldRange> = [];

    /**
     * Currently folded ranges
     * Subset of candidates, sorted by start_line
     */
    @:allow(tests) var folded:Array<FoldRange> = [];

    /**
     * Flag indicating if the fold projection needs rebuilding
     * Used for lazy evaluation to avoid expensive rebuilds on every text change
     */
    var needsRebuild:Bool = true;

    /**
     * Cached wrap_row_count from last rebuild
     * Used to detect if WrapMap changed and rebuild is needed
     */
    var cachedWrapRowCount:Int = 0;

    public function new() {}

    /**
     * Update cached wrap_row_count without full rebuild.
     * Used when no folds are active (identity mapping assumed).
     */
    public function markDirtyWithWrapCount(wrapRowCount:Int):Void {
        needsRebuild = true;
        cachedWrapRowCount = wrapRowCount;
    }

    /** Get total number of visible display rows */
    public function displayRowCount():Int {
        if (folded.length == 0)
            return cachedWrapRowCount;
        return projectedWrapRowCount - totalHidden;
    }

    /** How many wrap rows the runs before `index` hide. */
    function hiddenBefore(index:Int):Int {
        return index < hidden.length ? hidden[index].hiddenBefore : totalHidden;
    }

    /** hidden.partition_point(|run| run.wrap_rows.end <= wrap_row) */
    function runIndexForWrapRow(wrapRow:Int):Int {
        var lo = 0;
        var hi = hidden.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (hidden[mid].wrapRows.end <= wrapRow)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo;
    }

    /**
     * Convert wrap_row to display_row
     * Returns null if the wrap_row is hidden by folding
     */
    public function wrapRowToDisplayRow(wrapRow:Int):Null<Int> {
        if (folded.length == 0)
            return wrapRow < cachedWrapRowCount ? wrapRow : null;
        if (wrapRow >= projectedWrapRowCount)
            return null;
        final index = runIndexForWrapRow(wrapRow);
        if (index < hidden.length && hidden[index].wrapRows.start <= wrapRow)
            return null;
        return wrapRow - hiddenBefore(index);
    }

    /** Convert display_row to wrap_row */
    public function displayRowToWrapRow(displayRow:Int):Null<Int> {
        if (folded.length == 0)
            return displayRow < cachedWrapRowCount ? displayRow : null;
        if (displayRow >= displayRowCount())
            return null;
        var lo = 0;
        var hi = hidden.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (hidden[mid].displayStart() <= displayRow)
                lo = mid + 1;
            else
                hi = mid;
        }
        return displayRow + hiddenBefore(lo);
    }

    /** Find the nearest visible display_row for a given wrap_row */
    public function nearestVisibleDisplayRow(wrapRow:Int):Int {
        if (folded.length == 0) {
            final last = cachedWrapRowCount > 0 ? cachedWrapRowCount - 1 : 0;
            return wrapRow < last ? wrapRow : last;
        }

        final dr = wrapRowToDisplayRow(wrapRow);
        if (dr != null)
            return dr;

        // A hidden row maps to the last visible row before it.
        final visibleBefore = if (wrapRow >= projectedWrapRowCount) {
            displayRowCount();
        }
        else {
            final index = runIndexForWrapRow(wrapRow);
            index < hidden.length ? hidden[index].displayStart() : displayRowCount();
        }
        return visibleBefore > 0 ? visibleBefore - 1 : 0;
    }

    static function sortAndDedupByStartLine(ranges:Array<FoldRange>):Array<FoldRange> {
        // Rust `sort_by_key` is stable, `dedup_by_key` keeps the first of each run
        haxe.ds.ArraySort.sort(ranges, (a, b) -> a.startLine - b.startLine);
        final result:Array<FoldRange> = [];
        for (r in ranges) {
            if (result.length == 0 || result[result.length - 1].startLine != r.startLine)
                result.push(r);
        }
        return result;
    }

    /** Set fold candidates (from tree-sitter/LSP), full replacement. */
    public function setCandidates(candidates:Array<FoldRange>):Void {
        // Sort and deduplicate by start_line
        this.candidates = sortAndDedupByStartLine([for (c in candidates) c.copy()]);

        // Remove any folded ranges that are no longer in candidates
        folded = [for (fold in folded) if (isFoldCandidate(fold.startLine)) fold];
    }

    /**
     * Merge new candidates extracted from an edited region into existing candidates.
     *
     * Replaces candidates within [edit_start_line, edit_end_line] with `new_candidates`,
     * keeping candidates outside the edit range intact.
     */
    public function mergeCandidatesForEdit(editStartLine:Int, editEndLine:Int, newCandidates:Array<FoldRange>):Void {
        // Remove old candidates within the edit range (already done by adjust_folds_for_edit)
        // But do it again in case adjust wasn't called or range differs
        final kept = [for (c in candidates) if (c.startLine < editStartLine || c.startLine > editEndLine) c];

        // Add new candidates
        for (c in newCandidates)
            kept.push(c.copy());
        candidates = sortAndDedupByStartLine(kept);
    }

    /** Set a fold at the given start_line (must be in candidates) */
    public function setFolded(startLine:Int, isFolded:Bool):Void {
        if (isFolded) {
            // Find the candidate range for this start_line
            for (candidate in candidates) {
                if (candidate.startLine == startLine) {
                    // Add to folded if not already present
                    if (!isFoldedAt(startLine)) {
                        folded.push(candidate.copy());
                        haxe.ds.ArraySort.sort(folded, (a, b) -> a.startLine - b.startLine);
                        needsRebuild = true;
                    }
                    break;
                }
            }
        }
        else {
            // Remove from folded
            folded = [for (f in folded) if (f.startLine != startLine) f];
            needsRebuild = true;
        }
    }

    /** Toggle fold at the given start_line */
    public function toggleFold(startLine:Int):Void {
        final isFolded = isFoldedAt(startLine);
        setFolded(startLine, !isFolded);
    }

    /** Check if a line is currently folded */
    public function isFoldedAt(startLine:Int):Bool {
        for (f in folded) {
            if (f.startLine == startLine)
                return true;
        }
        return false;
    }

    /** Check if a line is a fold candidate */
    public function isFoldCandidate(startLine:Int):Bool {
        for (c in candidates) {
            if (c.startLine == startLine)
                return true;
        }
        return false;
    }

    /** Get all fold candidates */
    public inline function foldCandidates():Array<FoldRange> {
        return candidates;
    }

    /** Get all currently folded ranges */
    public inline function foldedRanges():Array<FoldRange> {
        return folded;
    }

    /** Clear all folds */
    public inline function clearFolds():Void {
        folded = [];
    }

    /**
     * Adjust folds and candidates after a text edit.
     *
     * - Folds/candidates overlapping the edited line range are removed
     * - Folds/candidates after the edit are shifted by line_delta
     *
     * This avoids expensive full tree traversal on every keystroke.
     */
    public function adjustFoldsForEdit(editStartLine:Int, editEndLine:Int, lineDelta:Int):Void {
        inline function shift(line:Int):Int {
            final value = line + lineDelta;
            return value > 0 ? value : 0;
        }

        // Adjust folded ranges
        if (folded.length > 0) {
            folded = [for (fold in folded) if (!(fold.startLine <= editEndLine && fold.endLine >= editStartLine)) fold];

            if (lineDelta != 0) {
                for (fold in folded) {
                    if (fold.startLine > editEndLine) {
                        fold.startLine = shift(fold.startLine);
                        fold.endLine = shift(fold.endLine);
                    }
                }
            }
        }

        // Adjust candidates the same way
        if (candidates.length > 0) {
            candidates = [for (c in candidates) if (!(c.startLine <= editEndLine && c.endLine >= editStartLine)) c];

            if (lineDelta != 0) {
                for (c in candidates) {
                    if (c.startLine > editEndLine) {
                        c.startLine = shift(c.startLine);
                        c.endLine = shift(c.endLine);
                    }
                }
            }
        }

        needsRebuild = true;
    }

    /**
     * Rebuild the fold mapping after wrap_map or fold state changes
     *
     * This is the core algorithm that projects wrap rows to display rows.
     */
    public function rebuild(wrapMap:WrapMap):Void {
        final wrapRowCount = wrapMap.wrapRowCount();

        // Performance optimization: skip rebuild if nothing changed
        if (!needsRebuild && wrapRowCount == cachedWrapRowCount)
            return;

        cachedWrapRowCount = wrapRowCount;

        if (folded.length == 0) {
            // Fast path: no folds, all wrap rows are visible
            setHiddenRows(wrapRowCount, []);
            needsRebuild = false;
            return;
        }

        // Build set of hidden wrap_row ranges from folded buffer lines
        final hiddenRanges:Array<Range> = [];
        for (fold in folded) {
            // Hide wrap rows from (start_line + 1) to (end_line - 1) (inclusive)
            // Both the first line and last line of the fold remain visible
            final hideStartLine = fold.startLine + 1;
            final hideEndLine = fold.endLine > 0 ? fold.endLine - 1 : 0;

            if (hideStartLine > hideEndLine)
                continue; // No middle lines to hide (0 or 1 lines between start and end)

            // Get wrap_row ranges for the hidden buffer lines
            final startWrapRow = wrapMap.bufferLineToFirstWrapRow(hideStartLine);
            final endWrapRow = hideEndLine + 1 < wrapMap.bufferLineCount() ? wrapMap.bufferLineToFirstWrapRow(hideEndLine + 1) : wrapRowCount;

            if (startWrapRow < endWrapRow)
                hiddenRanges.push(new Range(startWrapRow, endWrapRow));
        }

        setHiddenRows(wrapRowCount, hiddenRanges);
        needsRebuild = false;
    }

    /**
     * Install the projection for `wrapRowCount` wrap rows with
     * `hiddenRanges` hidden, merging overlapping and adjacent ranges.
     */
    @:allow(tests) function setHiddenRows(wrapRowCount:Int, hiddenRanges:Array<Range>):Void {
        hiddenRanges = hiddenRanges.copy();
        haxe.ds.ArraySort.sort(hiddenRanges, (a, b) -> a.start - b.start);

        hidden.resize(0);
        totalHidden = 0;
        projectedWrapRowCount = wrapRowCount;
        for (r in hiddenRanges) {
            final range = new Range(r.start, r.end < wrapRowCount ? r.end : wrapRowCount);
            if (range.isEmpty())
                continue;
            if (hidden.length > 0 && range.start <= hidden[hidden.length - 1].wrapRows.end) {
                final last = hidden[hidden.length - 1];
                // Overlapping or adjacent, merge
                if (range.end > last.wrapRows.end) {
                    totalHidden += range.end - last.wrapRows.end;
                    last.wrapRows = new Range(last.wrapRows.start, range.end);
                }
                continue;
            }
            totalHidden += range.len();
            hidden.push(new HiddenRows(range, totalHidden - range.len()));
        }
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs
// (the `SumTree<LineItem>` with its `BufferRows` and `WrapRows` dimensions)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The lines of a `TextWrapper`, standing for Rust's `SumTree<LineItem>`.
 *
 * The port keeps the items in an array, with the summary and the prefix sums
 * of the wrap rows computed lazily after a change. A seek by buffer row or by
 * wrap row gives the same item and the same start position as the sum tree
 * cursor (`Bias.Right`), so every query returns what the original returns.
 * Splicing rows costs O(lines) instead of O(log lines).
 */
class LineItems {

    final items:Array<LineItem>;

    /** wrapStarts[i]: wrap rows before item i (length + 1 entries), null when dirty */
    var wrapStarts:Null<Array<Int>> = null;

    var cachedSummary:Null<LineSummary> = null;

    public function new(?items:Array<LineItem>) {
        this.items = items != null ? items : [];
    }

    /** Rust `SumTree::from_iter` */
    public static inline function fromArray(items:Array<LineItem>):LineItems {
        return new LineItems(items);
    }

    public inline function isEmpty():Bool {
        return items.length == 0;
    }

    public inline function length():Int {
        return items.length;
    }

    /** Item at buffer row `row`, or null. */
    public inline function get(row:Int):Null<LineItem> {
        return row >= 0 && row < items.length ? items[row] : null;
    }

    /** Iterate buffer lines in order. */
    public inline function iterator():Iterator<LineItem> {
        return items.iterator();
    }

    public function summary():LineSummary {
        if (cachedSummary == null) {
            final summary = new LineSummary();
            for (item in items)
                summary.addItem(item);
            cachedSummary = summary;
        }
        return cachedSummary;
    }

    function starts():Array<Int> {
        if (wrapStarts == null) {
            final result = [0];
            var total = 0;
            for (item in items) {
                total += item.linesLen();
                result.push(total);
            }
            wrapStarts = result;
        }
        return wrapStarts;
    }

    /**
     * Wrap rows before buffer row `row` (the `WrapRows` start of a cursor
     * seeked to `BufferRows(row)`): the total when `row` is out of range.
     */
    public function wrapRowsBefore(row:Int):Int {
        final starts = starts();
        return starts[row < 0 ? 0 : (row > items.length ? items.length : row)];
    }

    /**
     * Index of the item a cursor seeked to `WrapRows(wrapRow)` with
     * `Bias.Right` stops on: the first item whose wrap rows end after
     * `wrapRow`, or `length()` when there is none.
     */
    public function itemIndexForWrapRow(wrapRow:Int):Int {
        final starts = starts();
        var lo = 0;
        var hi = items.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (starts[mid + 1] <= wrapRow)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo;
    }

    /**
     * Replaces the items of buffer rows `startRow...endRow` (exclusive end)
     * with `newItems` (Rust: `slice`, `seek_forward`, `extend`, `append`).
     */
    public function splice(startRow:Int, endRow:Int, newItems:Array<LineItem>):Void {
        if (startRow > items.length)
            startRow = items.length;
        if (endRow > items.length)
            endRow = items.length;
        if (endRow < startRow)
            endRow = startRow;
        final tail = items.splice(endRow, items.length - endRow);
        items.resize(startRow);
        for (item in newItems)
            items.push(item);
        for (item in tail)
            items.push(item);
        wrapStarts = null;
        cachedSummary = null;
    }

}

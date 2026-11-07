// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Summary of a run of `LineItem`s (Rust: of a `SumTree` subtree), see `LineItems`.
 */
class LineSummary {

    /** Number of buffer lines. */
    public var bufferRows:Int = 0;

    /** Number of wrap rows (sum of each line's `linesLen()`). */
    public var wrapRows:Int = 0;

    /** Sum of byte lengths of the buffer lines (without the trailing `\n`). */
    public var bytes:Int = 0;

    /** Byte length of the longest line. */
    public var maxLineLen:Int = 0;

    /** Buffer row of the first line achieving `maxLineLen`. */
    public var longestRow:Int = 0;

    /** Intersection permits a constant-time no-op when every line retains its current breaks. */
    public var validWidths:WidthRange = WidthRange.all();

    public function new() {}

    /** Rust `Summary::add_summary` with the summary of a single item. */
    public function addItem(item:LineItem):Void {
        // Keep the leftmost row that achieves a strictly greater length
        if (item.len() > maxLineLen) {
            longestRow = bufferRows;
            maxLineLen = item.len();
        }
        bufferRows += 1;
        wrapRows += item.linesLen();
        bytes += item.len();
        validWidths.intersect(item.validWidths);
    }

}

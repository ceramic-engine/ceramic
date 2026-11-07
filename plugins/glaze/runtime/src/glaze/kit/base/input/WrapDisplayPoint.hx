// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * A display point within the soft-wrapped text.
 *
 * This represents a position in the text after soft-wrapping, with an
 * additional `localRow` field tracking the wrap line within the original
 * buffer line.
 */
class WrapDisplayPoint {

    /** The 0-based soft wrapped row index in the text. */
    public final row:Int;

    /**
     * The 0-based row index in local line (include first line).
     *
     * Only valid when returned by `TextWrapper.offsetToDisplayPoint`, ignored otherwise.
     */
    public final localRow:Int;

    /** The 0-based column byte index in the display line (with soft wrap). */
    public final column:Int;

    public inline function new(row:Int, localRow:Int, column:Int) {
        this.row = row;
        this.localRow = localRow;
        this.column = column;
    }

    public inline function equals(other:WrapDisplayPoint):Bool {
        return other != null && row == other.row && localRow == other.localRow && column == other.column;
    }

    public function toString():String {
        return 'WrapDisplayPoint { row: $row, local_row: $localRow, column: $column }';
    }

}

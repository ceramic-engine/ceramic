// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A location in a grid layout. Rust's `row` and `column` ranges are
 * stored as start / end fields.
 */
class GridLocation {

    /** Start of the rows this item uses within the grid. */
    public var rowStart:GridPlacement = Auto;

    /** End of the rows this item uses within the grid. */
    public var rowEnd:GridPlacement = Auto;

    /** Start of the columns this item uses within the grid. */
    public var columnStart:GridPlacement = Auto;

    /** End of the columns this item uses within the grid. */
    public var columnEnd:GridPlacement = Auto;

    public function new() {}

    public function clone():GridLocation {
        final result = new GridLocation();
        result.rowStart = rowStart;
        result.rowEnd = rowEnd;
        result.columnStart = columnStart;
        result.columnEnd = columnEnd;
        return result;
    }

    public function equals(other:GridLocation):Bool {
        return other != null
            && Type.enumEq(rowStart, other.rowStart)
            && Type.enumEq(rowEnd, other.rowEnd)
            && Type.enumEq(columnStart, other.columnStart)
            && Type.enumEq(columnEnd, other.columnEnd);
    }

}

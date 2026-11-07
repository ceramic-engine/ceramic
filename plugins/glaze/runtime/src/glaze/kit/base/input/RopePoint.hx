// Ported from gpui-kit 0.8.1: crates/base/src/input/base/rope_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Parser-independent byte/row/column position used for incremental edits
 * (Rust `rope_ext::Point`, renamed: it clashes with `glaze.Point`).
 * The column is in bytes.
 */
class RopePoint {

    public final row:Int;

    public final column:Int;

    public inline function new(row:Int, column:Int) {
        this.row = row;
        this.column = column;
    }

    public function equals(other:Null<RopePoint>):Bool {
        return other != null && other.row == row && other.column == column;
    }

    public function toString():String {
        return 'Point { row: ' + row + ', column: ' + column + ' }';
    }

}

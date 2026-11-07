// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Position after soft-wrapping but before folding (internal).
 */
class WrapPoint {

    public final row:Int;

    public final col:Int;

    public inline function new(row:Int, col:Int) {
        this.row = row;
        this.col = col;
    }

    public inline function equals(other:WrapPoint):Bool {
        return other != null && row == other.row && col == other.col;
    }

    public function toString():String {
        return 'WrapPoint { row: $row, col: $col }';
    }

}

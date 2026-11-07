// Ported from gpui-kit 0.8.1: crates/base/src/input/base/cursor.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Pixels;

/**
 * The remembered column of a cursor moving vertically: Rust
 * `Option<(Pixels, usize)>`, the x position and the column in bytes.
 */
class ColumnAnchor {

    public final x:Pixels;

    public final column:Int;

    public inline function new(x:Pixels, column:Int) {
        this.x = x;
        this.column = column;
    }

    public function equals(other:Null<ColumnAnchor>):Bool {
        return other != null && (other.x:Float) == (x:Float) && other.column == column;
    }

    public static function same(a:Null<ColumnAnchor>, b:Null<ColumnAnchor>):Bool {
        return a == null ? b == null : a.equals(b);
    }

}

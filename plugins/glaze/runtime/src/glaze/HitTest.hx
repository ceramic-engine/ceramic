// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The hitboxes under a position, front to back, and how many of them count as hovered.
 */
class HitTest {

    public final ids:Array<Int> = [];

    public var hoverHitboxCount:Int = 0;

    public function new() {}

    public function equals(other:HitTest):Bool {
        if (hoverHitboxCount != other.hoverHitboxCount || ids.length != other.ids.length)
            return false;
        for (i in 0...ids.length) {
            if (ids[i] != other.ids[i])
                return false;
        }
        return true;
    }

}

// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The positioning strategy for this item (copy of taffy's `Position`).
 */
enum abstract Position(Int) {

    /** The offset is computed relative to the final position given by the layout algorithm. */
    var Relative = 0;

    /** The node is taken out of the normal flow and positioned relative to its parent. */
    var Absolute = 1;

}

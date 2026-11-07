// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * How children overflowing their container should affect layout (copy of taffy's `Overflow`).
 */
enum abstract Overflow(Int) {

    /** The automatic minimum size of this node as a flexbox/grid item should be based on the size of its content. */
    var Visible = 0;

    /** The automatic minimum size of this node as a flexbox/grid item should be based on the size of its content, and content is clipped. */
    var Clip = 1;

    /** The automatic minimum size of this node as a flexbox/grid item should be `0`. */
    var Hidden = 2;

    /** The automatic minimum size of this node as a flexbox/grid item should be `0`. Additionally, space should be reserved for a scrollbar. */
    var Scroll = 3;

}

// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Sets the layout used for the children of this node (copy of taffy's `Display`).
 * `Style` defaults to `Block`, the enum itself defaults to `Flex` like in GPUI.
 */
enum abstract Display(Int) {

    /** The children will follow the block layout algorithm */
    var Block = 0;

    /** The children will follow the flexbox layout algorithm */
    var Flex = 1;

    /** The children will follow the CSS Grid layout algorithm */
    var Grid = 2;

    /** The children will not be laid out, and will follow absolute positioning */
    var None = 3;

}

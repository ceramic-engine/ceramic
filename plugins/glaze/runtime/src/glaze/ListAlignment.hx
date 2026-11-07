// Ported from gpui-pre 0.3.10: src/elements/list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Whether the list is scrolling from top to bottom or bottom to top.
 */
enum abstract ListAlignment(Int) {

    /** The list is scrolling from top to bottom, like most lists. */
    var Top = 0;

    /** The list is scrolling from bottom to top, like a chat log. */
    var Bottom = 1;

}

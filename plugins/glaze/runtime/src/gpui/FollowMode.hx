// Ported from gpui-pre 0.3.10: src/elements/list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Controls whether the list automatically follows new content at the end.
 */
enum abstract FollowMode(Int) {

    /** Normal scrolling, no automatic following (default). */
    var Normal = 0;

    /** The list should auto-scroll along with the tail, when scrolled to bottom. */
    var Tail = 1;

}

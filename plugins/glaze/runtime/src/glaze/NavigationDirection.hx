// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A navigation direction, such as back or forward.
 */
enum abstract NavigationDirection(Int) {

    /** The back button. */
    var Back = 0;

    /** The forward button. */
    var Forward = 1;

}

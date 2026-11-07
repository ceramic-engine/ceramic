// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The phase of a touch motion event.
 */
enum abstract TouchPhase(Int) {

    /** The touch started. */
    var Started = 0;

    /** The touch event is moving. */
    var Moved = 1;

    /** The touch phase has ended */
    var Ended = 2;

    /** The touch was cancelled. */
    var Cancelled = 3;

}

// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The kind of input that produced a `ScrollEvent`.
 */
enum abstract ScrollSource(Int) {

    /**
     * A scroll the platform reported from a pointing device, such as a mouse
     * wheel or a trackpad.
     */
    var Pointer = 0;

    /**
     * A pan of a finger on a touchscreen, recognized by GPUI, including the
     * momentum GPUI synthesizes after the finger lifts.
     */
    var Touch = 1;

}

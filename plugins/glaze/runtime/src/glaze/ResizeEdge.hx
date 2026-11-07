// Ported from gpui-pre 0.3.10: src/platform.rs (ResizeEdge)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Which part of the window to resize.
 */
enum abstract ResizeEdge(Int) {

    /** The top edge */
    var Top = 0;

    /** The top right corner */
    var TopRight = 1;

    /** The right edge */
    var Right = 2;

    /** The bottom right corner */
    var BottomRight = 3;

    /** The bottom edge */
    var Bottom = 4;

    /** The bottom left corner */
    var BottomLeft = 5;

    /** The left edge */
    var Left = 6;

    /** The top left corner */
    var TopLeft = 7;

}

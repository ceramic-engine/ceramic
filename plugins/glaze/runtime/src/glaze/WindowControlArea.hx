// Ported from gpui-pre 0.3.10: src/window.rs (WindowControlArea)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * An area of the window that the platform treats as one of its own window
 * controls (Windows hit testing of the non client area).
 *
 * The port has no platform window: elements record their area
 * (`Div.windowControlArea`) and the window keeps the hitboxes of the last
 * frame (`Window.windowControlHitboxes`), but nothing consumes them yet.
 */
enum abstract WindowControlArea(Int) {

    /** An area that allows dragging of the platform window. */
    var Drag = 0;

    /** An area that allows closing of the platform window. */
    var Close = 1;

    /** An area that allows maximizing of the platform window. */
    var Max = 2;

    /** An area that allows minimizing of the platform window. */
    var Min = 3;

}

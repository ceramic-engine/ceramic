// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The kind of a `PlatformInput` (the variants of Rust's `PlatformInput`
 * enum that the port supports). Mouse listeners are registered for one kind.
 */
enum abstract PlatformInputKind(Int) to Int {

    var KeyDown = 0;

    var KeyUp = 1;

    var ModifiersChanged = 2;

    var MouseDown = 3;

    var MouseUp = 4;

    var MouseMove = 5;

    var MouseExited = 6;

    var Scroll = 7;

    /**
     * Whether events of this kind are dispatched to mouse listeners.
     */
    public inline function isMouseEvent():Bool {
        return this >= 3;
    }

    /**
     * Whether events of this kind are dispatched along the focus path.
     */
    public inline function isKeyboardEvent():Bool {
        return this <= 2;
    }

}

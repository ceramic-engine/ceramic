// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A mouse wheel or trackpad scroll event (Rust `ScrollEvent`, formerly
 * `ScrollWheelEvent`).
 */
class ScrollEvent extends PlatformInput {

    /** The position of the mouse on the window. */
    public var position:Point;

    /** The change in scroll. */
    public var delta:ScrollDelta;

    /** The modifiers that were held down when the mouse was moved. */
    public var modifiers:Modifiers;

    /** The phase of the touch event. */
    public var touchPhase:TouchPhase;

    public function new(position:Point, delta:ScrollDelta, ?modifiers:Modifiers, touchPhase:TouchPhase = Moved) {
        super(Scroll);
        this.position = position;
        this.delta = delta;
        this.modifiers = modifiers != null ? modifiers : Modifiers.none();
        this.touchPhase = touchPhase;
    }

}

// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * One step of scrolling from a mouse wheel, trackpad, or touch pan (Rust
 * `ScrollEvent`, formerly `ScrollWheelEvent`).
 */
class ScrollEvent extends PlatformInput {

    /**
     * The position the scroll targets. For touch pans this is where the pan
     * started, so the whole gesture stays with the container it began on.
     */
    public var position:Point;

    /** The change in scroll. */
    public var delta:ScrollDelta;

    /** The modifiers that were held down when the mouse was moved. */
    public var modifiers:Modifiers;

    /** The phase of the scroll gesture. */
    public var touchPhase:TouchPhase;

    /** The kind of input that produced this scroll. */
    public var source:ScrollSource;

    public function new(position:Point, delta:ScrollDelta, ?modifiers:Modifiers, touchPhase:TouchPhase = Moved, source:ScrollSource = Pointer) {
        super(Scroll);
        this.position = position;
        this.delta = delta;
        this.modifiers = modifiers != null ? modifiers : Modifiers.none();
        this.touchPhase = touchPhase;
        this.source = source;
    }

}

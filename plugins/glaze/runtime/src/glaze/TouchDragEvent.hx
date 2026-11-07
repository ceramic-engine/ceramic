// Ported from gpui-pre 0.3.10: src/gestures.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A direct touch drag claimed by an element before touch input becomes a
 * tap, long press, or scrolling gesture.
 */
class TouchDragEvent extends PlatformInput {

    /** The phase of the touch drag. */
    public var phase:TouchPhase;

    /** The position where the touch started. */
    public var startPosition:Point;

    /** The touch's current position. */
    public var position:Point;

    public function new(phase:TouchPhase, startPosition:Point, position:Point) {
        super(TouchDrag);
        this.phase = phase;
        this.startPosition = startPosition;
        this.position = position;
    }

}

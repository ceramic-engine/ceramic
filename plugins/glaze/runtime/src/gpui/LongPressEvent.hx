// Ported from gpui-pre 0.3.10: src/gestures.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A phased long-press gesture recognized from a touch.
 */
class LongPressEvent extends PlatformInput {

    /** The phase of the long press. */
    public var phase:TouchPhase;

    /** The position where the touch started. */
    public var startPosition:Point;

    /** The touch's current position. */
    public var position:Point;

    public function new(phase:TouchPhase = Started, ?startPosition:Point, ?position:Point) {
        super(LongPress);
        this.phase = phase;
        this.startPosition = startPosition != null ? startPosition : new Point(0, 0);
        this.position = position != null ? position : new Point(0, 0);
    }

}

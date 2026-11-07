// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A raw touch event from the platform.
 *
 * Dispatch contract (core implementation pending in GPUI too): a touch is
 * hit-tested once, at `TouchPhase.Started`, occlusion-aware; all subsequent
 * events for the same `TouchId` are delivered to the elements under the
 * starting position, even after the touch moves outside them.
 */
class TouchEvent extends PlatformInput {

    /** Which touch this event belongs to. */
    public var id:TouchId;

    /** The phase of the touch. */
    public var phase:TouchPhase;

    /** The position of the touch in window coordinates. */
    public var position:Point;

    /**
     * Where the platform predicts the touch will be roughly one frame from
     * now, in the same coordinate space as `position`, when the platform
     * offers a prediction for a `TouchPhase.Moved` event. Best-effort
     * latency compensation only: it may influence how far a recognized pan
     * scrolls within a frame, but never hit testing, gesture classification,
     * or velocity estimation.
     */
    public var predictedPosition:Null<Point>;

    /** Normalized touch force in `0.0..=1.0`, if the hardware reports it. */
    public var force:Null<Float>;

    public function new(id:TouchId, phase:TouchPhase, position:Point, ?predictedPosition:Point, ?force:Float) {
        super(Touch);
        this.id = id;
        this.phase = phase;
        this.position = position;
        this.predictedPosition = predictedPosition;
        this.force = force;
    }

    /** A copy of this event (Rust `clone`). */
    public function copy():TouchEvent {
        return new TouchEvent(id, phase, position, predictedPosition, force);
    }

}

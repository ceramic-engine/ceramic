// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (MotionStatus)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

/**
 * Where a keyed motion is in its course.
 */
enum abstract MotionStatus(Int) {

    /** Resting on its target, with nothing to animate. */
    var Idle = 0;

    /** Waiting for a positive delay to elapse. */
    var Delayed = 1;

    /** Moving toward its target. */
    var Running = 2;

    /** Arrived at its target. */
    var Finished = 3;

    /**
     * Whether the motion still needs animation frames (`Delayed` or `Running`).
     */
    public inline function isActive():Bool {
        final status:MotionStatus = cast this;
        return status == Delayed || status == Running;
    }

    public function toString():String {
        return switch (cast this : MotionStatus) {
            case Idle: 'Idle';
            case Delayed: 'Delayed';
            case Running: 'Running';
            case Finished: 'Finished';
        }
    }

}

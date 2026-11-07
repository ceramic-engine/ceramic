// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (MotionValue)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

/**
 * A sampled motion value and the status of its motion.
 */
class MotionValue<T> {

    public final value:T;

    public final status:MotionStatus;

    public inline function new(value:T, status:MotionStatus) {
        this.value = value;
        this.status = status;
    }

    public function toString():String {
        return 'MotionValue(value: $value, status: ${status.toString()})';
    }

}

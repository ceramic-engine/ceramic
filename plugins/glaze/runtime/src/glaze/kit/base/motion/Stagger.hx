// Ported from gpui-kit 0.8.1: crates/base/src/motion/stagger.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

/**
 * The item a stagger starts from: its delay is zero, and each item further
 * away waits one more interval.
 */
enum StaggerOrigin {
    First;
    Last;
    Center;
    Index(index:Int);
}

/**
 * Per-item delays for a list of motions, computed on demand without
 * allocating a schedule. The interval and delays are in seconds.
 */
class Stagger {

    final intervalNanos:Float;

    final origin:StaggerOrigin;

    public function new(interval:Float, origin:StaggerOrigin) {
        this.intervalNanos = MotionTime.nanos(interval);
        this.origin = origin;
    }

    /**
     * The delay, in seconds, of item `index` among `count` items.
     */
    public function delay(index:Int, count:Int):Float {
        if (count <= 0) {
            return 0.0;
        }
        final index = index < count - 1 ? index : count - 1;
        final origin = switch this.origin {
            case First: 0;
            case Last: count - 1;
            case Center: Std.int((count - 1) / 2);
            case Index(origin): origin < count - 1 ? origin : count - 1;
        }
        final distance = index > origin ? index - origin : origin - index;
        return MotionTime.seconds(intervalNanos * distance);
    }

}

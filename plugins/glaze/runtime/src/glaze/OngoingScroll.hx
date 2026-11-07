// Ported from gpui-pre 0.3.10: src/gestures.rs (OngoingScroll)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Tracks the dominant axis across the events in a scroll gesture.
 *
 * Differences with GPUI: Rust reads `Instant::now()` (the wall clock); the
 * port reads `cx.backgroundExecutor().now()` (seconds), so tests can drive
 * the gesture separation with a fake clock. `filter` returns the filtered
 * delta instead of mutating it in place (points are immutable).
 */
class OngoingScroll {

    static inline final SCROLL_EVENT_SEPARATION:Float = 0.028;

    static inline final UNLOCK_PERCENT:Float = 1.9;

    static inline final UNLOCK_LOWER_BOUND:Float = 6.;

    /** Time of the last event of the gesture, in seconds, or `null`. */
    var lastEvent:Null<Float> = null;

    /** The locked axis, or `null`. */
    var axis:Null<Axis> = null;

    public function new() {}

    static function dominantAxis(delta:Point):Axis {
        return Math.abs(delta.x) <= Math.abs(delta.y) ? Vertical : Horizontal;
    }

    static function lockDeltaToAxis(delta:Point, axis:Axis):Point {
        return switch axis {
            case Vertical: new Point(0, delta.y);
            case Horizontal: new Point(delta.x, 0);
        }
    }

    /**
     * Filters the given delta to the dominant axis of the current scroll gesture.
     *
     * Gestures are delimited by their touch phase when available, with a timeout
     * fallback for platforms that only emit `TouchPhase.Moved`.
     */
    public function filter(delta:Point, touchPhase:TouchPhase, now:Float):Point {
        if (touchPhase == Ended || touchPhase == Cancelled) {
            lastEvent = null;
            axis = null;
            return delta;
        }

        final x = Math.abs(delta.x);
        final y = Math.abs(delta.y);
        if (x == 0 && y == 0) {
            if (touchPhase == Started) {
                lastEvent = null;
                axis = null;
            }
            return delta;
        }

        final startsNewGesture = touchPhase == Started
            || lastEvent == null
            || now - lastEvent >= SCROLL_EVENT_SEPARATION;
        var axis = this.axis;
        if (startsNewGesture) {
            axis = dominantAxis(delta);
        }
        else if (Math.max(x, y) >= UNLOCK_LOWER_BOUND) {
            if (axis == Vertical && x > y && x >= y * UNLOCK_PERCENT) {
                axis = null;
            }
            else if (axis == Horizontal && y > x && y >= x * UNLOCK_PERCENT) {
                axis = null;
            }
        }

        lastEvent = now;
        this.axis = axis;
        if (axis != null) {
            return lockDeltaToAxis(delta, axis);
        }
        return delta;
    }

}

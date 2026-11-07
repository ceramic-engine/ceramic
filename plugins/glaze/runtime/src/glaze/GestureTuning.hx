// Ported from gpui-pre 0.3.10: src/gestures.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Feel constants consumed by gesture recognizers. Provided on a best-effort
 * basis, depending on each platform's support, defaulting to GPUI's own
 * (iOS flavored) values.
 *
 * Differences with GPUI: durations are in seconds.
 */
class GestureTuning {

    /**
     * Distance a touch may travel before it stops being a potential tap and
     * becomes a pan/drag.
     */
    public var touchSlop:Float;

    /** Maximum interval between taps for them to accumulate a tap count (seconds). */
    public var multiTapInterval:Float;

    /** Maximum distance between taps for them to accumulate a tap count. */
    public var multiTapSlop:Float;

    /**
     * How long a touch must remain within `touchSlop` to be recognized as a
     * long press (seconds).
     */
    public var longPressDuration:Float;

    /** How scroll momentum decelerates after a fling. */
    public var scrollPhysics:ScrollPhysics;

    /**
     * Minimum release velocity, in pixels per second, required to start
     * scroll momentum.
     */
    public var minFlingVelocity:Float;

    public function new(touchSlop:Float = 8., multiTapInterval:Float = 0.4, multiTapSlop:Float = 16., longPressDuration:Float = 0.5, ?scrollPhysics:ScrollPhysics, minFlingVelocity:Float = 50.) {
        this.touchSlop = touchSlop;
        this.multiTapInterval = multiTapInterval;
        this.multiTapSlop = multiTapSlop;
        this.longPressDuration = longPressDuration;
        this.scrollPhysics = scrollPhysics != null ? scrollPhysics : glaze.ScrollPhysics.ScrollPhysicsTools.ios();
        this.minFlingVelocity = minFlingVelocity;
    }

    /** Rust `GestureTuning::default()`. */
    public static function defaults():GestureTuning {
        return new GestureTuning();
    }

}

// Ported from gpui-pre 0.3.10: src/elements/animation.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * An animation that can be applied to an element.
 *
 * Durations are in seconds (`Float`) instead of `std::time::Duration`.
 * The builder methods modify this instance and return it (GPUI consumes
 * and returns `self`); use `clone()` to derive a variant from a shared one.
 */
class Animation {

    /**
     * The amount of time for which this animation should run, in seconds.
     */
    public var duration:Float;

    /**
     * Whether to repeat this animation when it finishes.
     */
    public var oneshot:Bool;

    /**
     * Whether to derive the phase from a shared clock. See `repeatSynced()`.
     */
    public var synced:Bool;

    /**
     * A function that maps normalized time to an animated value.
     * The result may exceed 0..1 for easing functions that overshoot.
     */
    public var easing:Float->Float;

    /**
     * The maximum number of times per second this animation re-renders.
     * When `null`, the animation re-renders on every frame.
     */
    public var maxFps:Null<Float>;

    /**
     * Create a new animation with the given duration (in seconds).
     * By default the animation will only run once and will use a linear easing function.
     */
    public function new(duration:Float) {

        this.duration = duration;
        this.oneshot = true;
        this.synced = false;
        this.easing = Easing.linear;
        this.maxFps = null;

    }

    /**
     * Set the animation to loop when it finishes.
     */
    public function repeat():Animation {

        oneshot = false;
        return this;

    }

    /**
     * Set the animation to loop when it finishes, phase-locked to a clock shared by the whole `App`.
     */
    public function repeatSynced():Animation {

        oneshot = false;
        synced = true;
        return this;

    }

    /**
     * Sets the easing function used to map normalized time to an animated value.
     *
     * The output is not clamped, allowing physical easing functions such as
     * springs to overshoot.
     */
    public function withEasing(easing:Float->Float):Animation {

        this.easing = easing;
        return this;

    }

    /**
     * Limit how often this animation re-renders. Instead of re-rendering on
     * every frame, the animation schedules its next render `1 / maxFps`
     * seconds after the current one. Values that are not finite and positive
     * are ignored.
     */
    public function withMaxFps(maxFps:Float):Animation {

        this.maxFps = maxFps;
        return this;

    }

    /**
     * The delay between two throttled re-renders, in seconds, or `null` when the
     * animation re-renders on every frame (no `maxFps`, or one that is not
     * finite and positive). Extracted from `AnimationElement::request_layout`.
     */
    public function frameInterval():Null<Float> {

        final maxFps = this.maxFps;
        if (maxFps != null && Math.isFinite(maxFps) && maxFps > 0.0) {
            // Rust: Duration::from_secs_f32(1.0 / max_fps)
            return Spring.durationFromSecs(SpringMath.f32(1.0 / SpringMath.f32(maxFps)));
        }
        return null;

    }

    public function clone():Animation {

        final result = new Animation(duration);
        result.oneshot = oneshot;
        result.synced = synced;
        result.easing = easing;
        result.maxFps = maxFps;
        return result;

    }

}

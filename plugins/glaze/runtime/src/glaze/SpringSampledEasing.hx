// Ported from gpui-pre 0.3.10: src/spring.rs (return value of sampled_easing)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * The `(Duration, impl Fn(f32) -> f32)` tuple returned by `Spring.sampledEasing`.
 * Use it as `new Animation(sampled.duration).withEasing(sampled.easing)`.
 */
class SpringSampledEasing {

    /**
     * The settle time of the spring, in seconds (`Spring.DURATION_MAX` if it never settles).
     */
    public final duration:Float;

    /**
     * The easing, exactly 0 at 0 and 1 at 1, possibly overshooting in between.
     */
    public final easing:(Float) -> Float;

    public inline function new(duration:Float, easing:(Float) -> Float) {

        this.duration = duration;
        this.easing = easing;

    }

}

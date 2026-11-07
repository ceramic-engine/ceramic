// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (Spring, SpringError)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.motion;

import glaze.SpringConfig;
import glaze.SpringMath.f32;

/**
 * Invalid physical or settling parameters for a `Spring`.
 */
@:using(glaze.kit.base.motion.Spring.SpringErrorTools)
enum SpringError {
    InvalidDamping;
    InvalidEpsilon;
}

class SpringErrorTools {

    /**
     * The error message (Rust `Display`).
     */
    public static function message(error:SpringError):String {
        return switch error {
            case InvalidDamping: 'spring damping must be finite and non-negative';
            case InvalidEpsilon: 'spring epsilon must be finite and greater than zero';
        }
    }

}

/**
 * A physical spring policy for `Motion.spring`.
 *
 * A spring is the counterpart to `Transition` for values that can be
 * retargeted while they are still moving. A duration-based transition restarts
 * its easing from the value sampled at that instant, which is continuous in
 * position but not in velocity. A spring carries velocity across the retarget,
 * so a value reversed mid-flight decelerates and turns around instead of
 * snapping to a new curve's initial speed.
 *
 * Not to be confused with `glaze.Spring` (GPUI's spring helpers): this is
 * gpui-kit's `motion::Spring`. Immutable: the builders return a modified copy.
 */
class Spring {

    /**
     * Matches GPUI's own default spring settling tolerance.
     */
    public static final DEFAULT_SPRING_EPSILON:Float = f32(0.001);

    static final TAU_F32:Float = f32(Math.PI * 2.0);

    /** The response, in whole nanoseconds. */
    @:allow(glaze.kit.base.motion)
    var responseNanos(default, null):Float;

    var damping:Float;

    var epsilonValue:Float;

    @:allow(glaze.kit.base.motion)
    var travel(default, null):Bool;

    /**
     * Builds a spring that reaches its target in about `response` seconds
     * without overshooting it.
     *
     * `response` is not a duration in the sense `Transition` means one. A
     * spring has no end to schedule: this is the period one full oscillation
     * would take without damping, which is the scale the motion is felt at
     * rather than the moment it stops. The remaining fraction of a percent
     * keeps settling past it, until it is within the tolerance `withEpsilon`
     * sets.
     *
     * A zero response adopts the target on the spot, as a zero duration does
     * for a transition. Say that with `withTravel` where it is what you mean;
     * a zero here is the degenerate case, defined so an infinitely stiff
     * spring resolves rather than dividing by its own period.
     */
    public function new(response:Float) {
        this.responseNanos = MotionTime.nanos(response);
        this.damping = 1.0;
        this.epsilonValue = DEFAULT_SPRING_EPSILON;
        this.travel = true;
    }

    function copy():Spring {
        final spring = new Spring(0);
        spring.responseNanos = responseNanos;
        spring.damping = damping;
        spring.epsilonValue = epsilonValue;
        spring.travel = travel;
        return spring;
    }

    /**
     * Sets the damping ratio, which is `1.0` (no overshoot) by default.
     *
     * Below `1.0` the spring passes its target and comes back; above `1.0` it
     * approaches slowly. Overshoot suits a value with room to pass its target
     * and nothing to collide with. A height, an opacity, or anything bounded by
     * the geometry around it should stay at the default.
     *
     * This is the ratio zeta, not GPUI's `SpringConfig.damping`, which is the
     * coefficient `c = 2 * zeta * omega0`.
     *
     * Throws (Rust panics) when `ratio` is negative or non-finite. Use
     * `tryWithDamping` when the value is not a trusted constant.
     */
    public function withDamping(ratio:Float):Spring {
        try {
            return tryWithDamping(ratio);
        }
        catch (error:SpringError) {
            throw new haxe.Exception(error.message());
        }
    }

    /**
     * Checked form of `withDamping`: throws a `SpringError` (Rust `Err`).
     */
    public function tryWithDamping(ratio:Float):Spring {
        if (!Math.isFinite(ratio) || ratio < 0.0) {
            throw SpringError.InvalidDamping;
        }
        final spring = copy();
        spring.damping = f32(ratio);
        return spring;
    }

    /**
     * Sets whether the spring travels to its target or adopts it on the spot.
     *
     * A value the pointer is already moving (a panel being dragged by its
     * resize handle) must not lag behind the pointer, so the spring stops
     * travelling for as long as the drag lasts. Retained state stays pinned to
     * the target meanwhile, so travel resumes from the value the drag released
     * rather than from wherever the spring was when it began.
     */
    public function withTravel(travel:Bool):Spring {
        final spring = copy();
        spring.travel = travel;
        return spring;
    }

    /**
     * Sets the settling tolerance, expressed in the target's own units.
     *
     * The default suits targets that move within a normalized `0..1` range. A
     * spring over pixels settles perceptibly sooner with a coarser tolerance,
     * which also ends the animation frames that the remaining sub-pixel motion
     * would otherwise request.
     *
     * Throws (Rust panics) when `epsilon` is zero, negative, or non-finite.
     * Use `tryWithEpsilon` when the value is not a trusted constant.
     */
    public function withEpsilon(epsilon:Float):Spring {
        try {
            return tryWithEpsilon(epsilon);
        }
        catch (error:SpringError) {
            throw new haxe.Exception(error.message());
        }
    }

    /**
     * Checked form of `withEpsilon`: throws a `SpringError` (Rust `Err`).
     */
    public function tryWithEpsilon(epsilon:Float):Spring {
        if (!Math.isFinite(epsilon) || epsilon <= 0.0) {
            throw SpringError.InvalidEpsilon;
        }
        final spring = copy();
        spring.epsilonValue = f32(epsilon);
        return spring;
    }

    /**
     * Returns the settling tolerance in the target's own units.
     */
    public inline function epsilon():Float {
        return epsilonValue;
    }

    /**
     * The physical parameters GPUI integrates. The response must be non-zero;
     * `Motion.spring` adopts the target before reaching here when it is not.
     */
    @:allow(glaze.kit.base.motion)
    function config():SpringConfig {
        final frequency = f32(TAU_F32 / MotionTime.asSecsF32(responseNanos));
        return new SpringConfig(f32(frequency * frequency), f32(f32(2.0 * damping) * frequency), 1.0);
    }

}

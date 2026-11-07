// Ported from gpui-pre 0.3.10: src/spring.rs (SpringConfig)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.SpringMath.*;
import gpui.util.MathUtil;

/**
 * The physical parameters of a damped harmonic oscillator.
 *
 * `stiffness` and `mass` must be finite and positive. `damping` must be finite
 * and non-negative.
 *
 * Like GPUI, every computation is done in `f32` (emulated with `SpringMath`,
 * in the same operation order as the Rust code), so the results match GPUI's.
 * Durations are in seconds, with `Spring.DURATION_MAX` standing for `Duration::MAX`.
 */
class SpringConfig {

    /**
     * The spring stiffness, conventionally written as k.
     */
    public final stiffness:Float;

    /**
     * The viscous damping coefficient, conventionally written as c.
     */
    public final damping:Float;

    /**
     * The moving mass, conventionally written as m.
     */
    public final mass:Float;

    /**
     * Creates a spring from its physical parameters (rounded to `f32`).
     */
    public inline function new(stiffness:Float, damping:Float, mass:Float) {

        this.stiffness = f32(stiffness);
        this.damping = f32(damping);
        this.mass = f32(mass);

    }

    /**
     * The natural angular frequency (omega0), first value of Rust's `canonical()`.
     */
    public inline function naturalFrequency():Float {

        return sqrtF32(f32(stiffness / mass));

    }

    /**
     * The damping ratio (zeta), second value of Rust's `canonical()`.
     */
    public inline function dampingRatio():Float {

        return f32(damping / f32(2.0 * sqrtF32(f32(stiffness * mass))));

    }

    /**
     * Returns the natural angular frequency and damping ratio `[omega0, zeta]`.
     */
    public function canonical():Array<Float> {

        return [naturalFrequency(), dampingRatio()];

    }

    /**
     * Advances a spring toward a target that remains fixed for `deltaTime` (seconds).
     *
     * This analytic step is independent of frame rate and preserves velocity,
     * allowing an interrupted spring to be retargeted without restarting it.
     */
    public function step(state:SpringState, target:Float, deltaTime:Float):SpringState {

        final target = f32(target);
        final position = f32(state.position);
        final velocity = f32(state.velocity);
        final propagator = this.propagator(deltaTime);
        final displacement = f32(position - target);

        return new SpringState(
            f32(f32(target + f32(propagator.m00 * displacement)) + f32(propagator.m01 * velocity)),
            f32(f32(propagator.m10 * displacement) + f32(propagator.m11 * velocity))
        );

    }

    /**
     * Advances a spring toward a target moving at a constant velocity.
     *
     * A first-order hold avoids the frame-rate-dependent lag introduced by
     * treating a dragged target as stationary between frames.
     */
    public function stepRamp(state:SpringState, target:Float, targetVelocity:Float, deltaTime:Float):SpringState {

        final target = f32(target);
        final targetVelocity = f32(targetVelocity);
        final deltaTime = f32(deltaTime);
        final naturalFrequency = this.naturalFrequency();
        final dampingRatio = this.dampingRatio();
        final steadyStateLag = f32(f32(f32(-2.0 * dampingRatio) * targetVelocity) / naturalFrequency);
        final displacement = f32(f32(f32(state.position) - target) - steadyStateLag);
        final velocity = f32(f32(state.velocity) - targetVelocity);
        final propagator = this.propagator(deltaTime);
        final target = f32(target + f32(targetVelocity * deltaTime));

        return new SpringState(
            f32(f32(f32(target + steadyStateLag) + f32(propagator.m00 * displacement)) + f32(propagator.m01 * velocity)),
            f32(f32(targetVelocity + f32(propagator.m10 * displacement)) + f32(propagator.m11 * velocity))
        );

    }

    /**
     * Returns the exact state-transition matrix for a constant target.
     *
     * Materializing this matrix is useful when many springs share the same
     * configuration and frame delta. A matrix must not be reused when the
     * frame delta changes.
     */
    public function propagator(deltaTime:Float):SpringPropagator {

        final deltaTime = f32(deltaTime);
        final naturalFrequency = this.naturalFrequency();
        final dampingRatio = this.dampingRatio();

        if (dampingRatio < Spring.UNDERDAMPED_LIMIT) {
            final decay = f32(dampingRatio * naturalFrequency);
            final dampedFrequency = f32(naturalFrequency * sqrtF32(f32(1.0 - f32(dampingRatio * dampingRatio))));
            final exponential = expF32(f32(-decay * deltaTime));
            final angle = f32(dampedFrequency * deltaTime);
            final sine = sinF32(angle);
            final cosine = cosF32(angle);
            final sineOverFrequency = f32(sine / dampedFrequency);

            return new SpringPropagator(
                f32(exponential * f32(cosine + f32(decay * sineOverFrequency))),
                f32(exponential * sineOverFrequency),
                f32(f32(f32(-exponential * naturalFrequency) * naturalFrequency) * sineOverFrequency),
                f32(exponential * f32(cosine - f32(decay * sineOverFrequency)))
            );
        }
        else if (dampingRatio > Spring.OVERDAMPED_LIMIT) {
            final root = sqrtF32(f32(f32(dampingRatio * dampingRatio) - 1.0));
            final rootSum = f32(dampingRatio + root);
            final slowRoot = f32(-naturalFrequency / rootSum);
            final fastRoot = f32(-naturalFrequency * rootSum);
            final denominator = f32(slowRoot - fastRoot);
            final slowExponential = expF32(f32(slowRoot * deltaTime));
            final fastExponential = expF32(f32(fastRoot * deltaTime));

            return new SpringPropagator(
                f32(f32(f32(-fastRoot * slowExponential) + f32(slowRoot * fastExponential)) / denominator),
                f32(f32(slowExponential - fastExponential) / denominator),
                f32(f32(f32(slowRoot * fastRoot) * f32(fastExponential - slowExponential)) / denominator),
                f32(f32(f32(slowRoot * slowExponential) - f32(fastRoot * fastExponential)) / denominator)
            );
        }
        else {
            final exponential = expF32(f32(-naturalFrequency * deltaTime));

            return new SpringPropagator(
                f32(exponential * f32(1.0 + f32(naturalFrequency * deltaTime))),
                f32(exponential * deltaTime),
                f32(f32(f32(-exponential * naturalFrequency) * naturalFrequency) * deltaTime),
                f32(exponential * f32(1.0 - f32(naturalFrequency * deltaTime)))
            );
        }

    }

    /**
     * Tests both displacement and velocity against a positional tolerance.
     *
     * Velocity is compared with `epsilon * naturalFrequency`, giving it the
     * corresponding animated-units-per-second scale.
     */
    public function isSettled(state:SpringState, target:Float, epsilon:Float):Bool {

        final epsilon = f32(epsilon);
        final naturalFrequency = this.naturalFrequency();
        return Math.isFinite(epsilon)
            && epsilon >= 0.0
            && Math.abs(f32(f32(state.position) - f32(target))) <= epsilon
            && Math.abs(f32(state.velocity)) <= f32(epsilon * naturalFrequency);

    }

    /**
     * Returns a conservative time (in seconds) after which the spring remains settled.
     *
     * An undamped spring has no finite settling time and returns
     * `Spring.DURATION_MAX`.
     */
    public function settleTime(state:SpringState, target:Float, epsilon:Float):Float {

        final epsilon = f32(epsilon);
        final velocity = f32(state.velocity);
        final displacement = f32(f32(state.position) - f32(target));
        if (displacement == 0.0 && velocity == 0.0) {
            return 0.0;
        }

        final naturalFrequency = this.naturalFrequency();
        final dampingRatio = this.dampingRatio();
        if (!Math.isFinite(naturalFrequency)
            || naturalFrequency <= 0.0
            || !Math.isFinite(dampingRatio)
            || dampingRatio <= 0.0
            || !Math.isFinite(epsilon)
            || epsilon <= 0.0
        ) {
            return Spring.DURATION_MAX;
        }

        final velocityThreshold = f32(epsilon * naturalFrequency);

        if (dampingRatio < Spring.UNDERDAMPED_LIMIT) {
            final decay = f32(dampingRatio * naturalFrequency);
            final dampedFrequency = f32(naturalFrequency * sqrtF32(f32(1.0 - f32(dampingRatio * dampingRatio))));
            final sineCoefficient = f32(f32(velocity + f32(decay * displacement)) / dampedFrequency);
            final positionEnvelope = hypotF32(displacement, sineCoefficient);
            final velocityCosine = f32(f32(dampedFrequency * sineCoefficient) - f32(decay * displacement));
            final velocitySine = f32(f32(-dampedFrequency * displacement) - f32(decay * sineCoefficient));
            final velocityEnvelope = hypotF32(velocityCosine, velocitySine);

            return Spring.findSettleTime(
                0.0,
                naturalFrequency,
                time -> {
                    final exponential = expF32(f32(-decay * time));
                    Spring.envelopeBelow(
                        f32(positionEnvelope * exponential),
                        f32(velocityEnvelope * exponential),
                        epsilon,
                        velocityThreshold
                    );
                }
            );
        }
        else if (dampingRatio > Spring.OVERDAMPED_LIMIT) {
            final root = sqrtF32(f32(f32(dampingRatio * dampingRatio) - 1.0));
            final rootSum = f32(dampingRatio + root);
            final slowRoot = f32(-naturalFrequency / rootSum);
            final fastRoot = f32(-naturalFrequency * rootSum);
            final denominator = f32(slowRoot - fastRoot);
            final slowCoefficient = f32(f32(velocity - f32(fastRoot * displacement)) / denominator);
            final fastCoefficient = f32(f32(f32(slowRoot * displacement) - velocity) / denominator);

            return Spring.findSettleTime(
                0.0,
                naturalFrequency,
                time -> {
                    final slowTerm = f32(Math.abs(slowCoefficient) * expF32(f32(slowRoot * time)));
                    final fastTerm = f32(Math.abs(fastCoefficient) * expF32(f32(fastRoot * time)));
                    Spring.envelopeBelow(
                        f32(slowTerm + fastTerm),
                        f32(f32(Math.abs(slowRoot) * slowTerm) + f32(Math.abs(fastRoot) * fastTerm)),
                        epsilon,
                        velocityThreshold
                    );
                }
            );
        }
        else {
            final linearCoefficient = f32(velocity + f32(naturalFrequency * displacement));
            final positionConstant = Math.abs(displacement);
            final positionLinear = Math.abs(linearCoefficient);
            final velocityConstant = Math.abs(f32(linearCoefficient - f32(naturalFrequency * displacement)));
            final velocityLinear = f32(naturalFrequency * Math.abs(linearCoefficient));
            final positionDecayStart = Spring.envelopeDecayStart(positionConstant, positionLinear, naturalFrequency);
            final velocityDecayStart = Spring.envelopeDecayStart(velocityConstant, velocityLinear, naturalFrequency);

            return Spring.findSettleTime(
                MathUtil.max(positionDecayStart, velocityDecayStart),
                naturalFrequency,
                time -> {
                    final exponential = expF32(f32(-naturalFrequency * time));
                    Spring.envelopeBelow(
                        f32(f32(positionConstant + f32(positionLinear * time)) * exponential),
                        f32(f32(velocityConstant + f32(velocityLinear * time)) * exponential),
                        epsilon,
                        velocityThreshold
                    );
                }
            );
        }

    }

    public function equals(other:SpringConfig):Bool {

        return stiffness == other.stiffness && damping == other.damping && mass == other.mass;

    }

    public function toString():String {

        return 'SpringConfig(stiffness: $stiffness, damping: $damping, mass: $mass)';

    }

}

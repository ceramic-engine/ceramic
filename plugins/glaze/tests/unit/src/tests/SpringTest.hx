package tests;

import gpui.AnimationPhase;
import gpui.Hsla;
import gpui.Pixels;
import gpui.Rgba;
import gpui.Spring;
import gpui.SpringConfig;
import gpui.SpringPhaseTarget;
import gpui.SpringMath.f32;
import gpui.SpringPropagator;
import gpui.SpringState;
import gpui.SpringValueTarget;
import testing.TestCase;

/**
 * Tests of the spring port (gpui-pre 0.3.10: src/spring.rs): the Rust unit
 * tests, then a comparison of every public computation with the values dumped
 * from the original GPUI by `reference/examples/animation_dump.rs`.
 *
 * The port emulates GPUI's f32 arithmetic (see `gpui.SpringMath`), so most
 * values are bit for bit identical. The exceptions come from the platform
 * `libm`: macOS `expf` is not always correctly rounded (`expf(-0.05)` is 1 ulp
 * below the exact rounding), and formulas that cancel large terms (`target +
 * m00 * displacement + ...`) turn that ulp into an error of one ulp of the
 * target. So differences are divided by the magnitude of the values involved
 * (`max(1, |expected|, |target|, |position|, |velocity|, |target velocity|)`) before the 1e-6 comparison.
 * `maxErrors` keeps the unscaled maximum absolute error per computation.
 */
class SpringTest extends TestCase {

    static inline final EPSILON = 1e-4;

    static inline final TOLERANCE = 1e-6;

    /**
     * Largest absolute difference with GPUI per computation, filled by the
     * comparison tests (printed when the define `gpui_animation_errors` is set).
     */
    public static final maxErrors:Map<String, Float> = new Map();

/// Ported #[cfg(test)] tests of spring.rs

    function testSpringTargetsResolveTypedOutputs() {

        assertEquals(12.0, new SpringValueTarget(12.0).target());
        assertEquals(14.0, new SpringValueTarget(12.0).resolve(14.0));
        final pixels:Pixels = new SpringValueTarget((12.0:Pixels)).resolve(14.0);
        assertEquals((14.0:Pixels), pixels);
        assertEquals(0.0, SpringPhaseTarget.ofBool(false).target());
        assertEquals(1.0, SpringPhaseTarget.ofBool(true).target());
        assertEquals(new AnimationPhase(1.25), SpringPhaseTarget.ofBool(true).resolve(1.25));

    }

    function testAnimationPhasesInterpolateOverArbitraryRanges() {

        final phase = new AnimationPhase(1.5);
        assertEquals(15.0, phase.interpolateBetween(1.0, 2.0, 10.0, 20.0));
        assertEquals(10.0, phase.interpolateBetweenClamped(2.0, 3.0, 10.0, 20.0));
        assertEquals(25.0, new AnimationPhase(3.5).interpolateBetween(2.0, 3.0, 10.0, 20.0));

    }

    function testHslaInterpolationTakesTheShortestHuePath() {

        final from = new Hsla(0.9, 0.5, 0.5, 1.0);
        final to = new Hsla(0.1, 1.0, 0.75, 0.5);
        final result = new AnimationPhase(0.5).interpolate(from, to);

        assertTrue(result.h < EPSILON || (1.0 - result.h) < EPSILON);
        assertTrue(Math.abs(result.s - 0.75) < EPSILON);
        assertTrue(Math.abs(result.l - 0.625) < EPSILON);
        assertTrue(Math.abs(result.a - 0.75) < EPSILON);

    }

    function testPropagatorsComposeAndHaveExpectedDeterminant() {

        for (dampingRatio in [0.4, 1.0, 1.5]) {
            final naturalFrequency = 12.0;
            final config = new SpringConfig(
                naturalFrequency * naturalFrequency,
                2.0 * dampingRatio * naturalFrequency,
                1.0
            );
            final first = config.propagator(0.013);
            final second = config.propagator(0.021);
            final combined = multiply(second, first);
            final direct = config.propagator(0.034);

            for (row in 0...2) {
                for (column in 0...2) {
                    assertTrue(
                        Math.abs(combined.get(row, column) - direct.get(row, column)) < 2e-4,
                        '$dampingRatio: $combined != $direct'
                    );
                }
            }

            final determinant = direct.m00 * direct.m11 - direct.m01 * direct.m10;
            final expected = Math.exp(-2.0 * dampingRatio * naturalFrequency * 0.034);
            assertTrue(Math.abs(determinant - expected) < 2e-4);
        }

    }

    function testStepPreservesSemigroupForEveryDampingRegime() {

        final state = new SpringState(-3.0, 5.0);
        for (damping in [4.0, 20.0, 40.0]) {
            final config = new SpringConfig(100.0, damping, 1.0);
            final stepped = config.step(config.step(state, 7.0, 0.013), 7.0, 0.021);
            final direct = config.step(state, 7.0, 0.034);

            assertTrue(Math.abs(stepped.position - direct.position) < 2e-4);
            assertTrue(Math.abs(stepped.velocity - direct.velocity) < 2e-4);
        }

    }

    function testRampTracksSteadyStateLag() {

        final naturalFrequency = 10.0;
        final dampingRatio = 0.8;
        final targetVelocity = 3.0;
        final config = new SpringConfig(
            naturalFrequency * naturalFrequency,
            2.0 * dampingRatio * naturalFrequency,
            1.0
        );
        final lag = -2.0 * dampingRatio * targetVelocity / naturalFrequency;
        final state = new SpringState(lag, targetVelocity);
        final next = config.stepRamp(state, 0.0, targetVelocity, 0.25);

        assertTrue(Math.abs(next.position - (targetVelocity * 0.25 + lag)) < EPSILON);
        assertTrue(Math.abs(next.velocity - targetVelocity) < EPSILON);

    }

    function testSettlingRequiresLowVelocity() {

        final config = new SpringConfig(100.0, 10.0, 1.0);
        assertFalse(config.isSettled(new SpringState(1.0, 1.0), 1.0, 0.01));
        assertTrue(config.isSettled(new SpringState(1.005, 0.05), 1.0, 0.01));

    }

    function testSettleTimeIsConservativeForEveryDampingRegime() {

        final initialState = new SpringState(-2.0, 4.0);
        for (damping in [4.0, 20.0, 40.0]) {
            final config = new SpringConfig(100.0, damping, 1.0);
            final duration = config.settleTime(initialState, 3.0, 0.001);
            assertTrue(duration != Spring.DURATION_MAX);

            for (additionalTime in [0.0, 0.1, 1.0]) {
                // Rust: duration.as_secs_f32() + additional_time, an f32 sum
                final state = config.step(initialState, 3.0, f32(Spring.durationAsSecsF32(duration) + f32(additionalTime)));
                assertTrue(config.isSettled(state, 3.0, 0.001), '$damping: $duration produced $state');
            }
        }

    }

    function testSettleTimeAccountsForMotionOutsideAnInstantaneousTolerance() {

        final config = new SpringConfig(100.0, 2.0, 1.0);
        final state = new SpringState(1.125, 1.25);
        assertTrue(config.isSettled(state, 1.0, 0.125));

        final duration = config.settleTime(state, 1.0, 0.125);
        assertTrue(duration > 0.0);
        assertTrue(config.isSettled(config.step(state, 1.0, Spring.durationAsSecsF32(duration)), 1.0, 0.125));

    }

    function testUndampedSpringNeverSettles() {

        final config = new SpringConfig(100.0, 0.0, 1.0);
        assertEquals(Spring.DURATION_MAX, config.settleTime(new SpringState(0.0, 0.0), 1.0, 0.001));

    }

    function testSampledEasingHasExactEndpointsAndCanOvershoot() {

        final config = new SpringConfig(100.0, 6.0, 1.0);
        final sampled = Spring.sampledEasing(config, 0.001);

        assertTrue(sampled.duration != Spring.DURATION_MAX);
        assertEquals(0.0, sampled.easing(0.0));
        assertEquals(1.0, sampled.easing(1.0));
        var overshoots = false;
        for (step in 1...100) {
            if (sampled.easing(step / 100.0) > 1.0) overshoots = true;
        }
        assertTrue(overshoots);

    }

/// Extra checks

    function testAnimationPhaseHelpers() {

        assertEquals(1.0, AnimationPhase.fromBool(true).value);
        assertEquals(0.0, AnimationPhase.fromBool(false).value);
        assertEquals(2.0, new AnimationPhase(2.5).clamp(2.0, 1.0).value);
        assertEquals(1.0, new AnimationPhase(-2.5).clamp(2.0, 1.0).value);
        assertEquals(20.0, new AnimationPhase(1.5).interpolateClamped(10.0, 20.0));
        final color = new AnimationPhase(0.5).interpolate(new Rgba(0, 0.5, 1, 1), new Rgba(1, 1, 0, 0));
        assertTrue(color.equals(new Rgba(0.5, 0.75, 0.5, 0.5)));
        final clampedColor = new AnimationPhase(2.0).interpolateBetweenClamped(0.0, 1.0, new Rgba(0, 0, 0, 0), new Rgba(1, 1, 1, 1));
        assertTrue(clampedColor.equals(new Rgba(1, 1, 1, 1)));

    }

    function testSettleTimeOfSettledState() {

        final config = new SpringConfig(100.0, 10.0, 1.0);
        assertEquals(0.0, config.settleTime(new SpringState(1.0, 0.0), 1.0, 0.001));
        assertEquals(Spring.DURATION_MAX, config.settleTime(new SpringState(0.0, 0.0), 1.0, 0.0));
        assertEquals(Spring.DURATION_MAX, config.settleTime(new SpringState(0.0, 0.0), 1.0, Math.NaN));
        assertFalse(config.isSettled(new SpringState(1.0, 0.0), 1.0, Math.NaN));
        assertFalse(config.isSettled(new SpringState(1.0, 0.0), 1.0, -1.0));

    }

/// Comparison with GPUI

    function testCanonicalMatchesGpui() {

        for (spring in springs()) {
            final config = configOf(spring);
            final canonical:Array<Float> = spring.canonical;
            final actual = config.canonical();
            check('canonical', canonical[0], actual[0]);
            check('canonical', canonical[1], actual[1]);
        }

    }

    function testPropagatorsMatchGpui() {

        for (spring in springs()) {
            final config = configOf(spring);
            final propagators:Array<Dynamic> = spring.propagators;
            for (entry in propagators) {
                final m:Array<Array<Float>> = entry.m;
                final actual = config.propagator(entry.dt);
                for (row in 0...2) {
                    for (column in 0...2) {
                        check('propagator', m[row][column], actual.get(row, column), '${config} dt ${entry.dt}');
                    }
                }
            }
        }

    }

    function testStepsMatchGpui() {

        for (spring in springs()) {
            final config = configOf(spring);
            final steps:Array<Dynamic> = spring.steps;
            for (entry in steps) {
                final actual = config.step(stateOf(entry.state), entry.target, entry.dt);
                final expected = stateOf(entry.result);
                final scale = magnitude([entry.target, entry.state[0], entry.state[1]]);
                check('step', expected.position, actual.position, '${config} ${entry.state} dt ${entry.dt}', scale);
                check('step', expected.velocity, actual.velocity, '${config} ${entry.state} dt ${entry.dt}', scale);
            }
        }


        // Last comparison test in alphabetical order
        printErrors();

    }

    function testStepRampsMatchGpui() {

        for (spring in springs()) {
            final config = configOf(spring);
            final ramps:Array<Dynamic> = spring.step_ramps;
            for (entry in ramps) {
                final actual = config.stepRamp(stateOf(entry.state), entry.target, entry.target_velocity, entry.dt);
                final expected = stateOf(entry.result);
                final scale = magnitude([entry.target, entry.state[0], entry.state[1], entry.target_velocity]);
                check('step_ramp', expected.position, actual.position, '${config} ${entry.state} dt ${entry.dt}', scale);
                check('step_ramp', expected.velocity, actual.velocity, '${config} ${entry.state} dt ${entry.dt}', scale);
            }
        }

    }

    function testIsSettledMatchesGpui() {

        for (spring in springs()) {
            final config = configOf(spring);
            final entries:Array<Dynamic> = spring.is_settled;
            for (entry in entries) {
                final actual = config.isSettled(stateOf(entry.state), entry.target, entry.epsilon);
                assertEquals((entry.result:Bool), actual, '${config} ${entry.state} epsilon ${entry.epsilon}');
            }
        }

    }

    function testSettleTimesMatchGpui() {

        for (spring in springs()) {
            final config = configOf(spring);
            final entries:Array<Dynamic> = spring.settle_times;
            for (entry in entries) {
                final actual = config.settleTime(stateOf(entry.state), entry.target, entry.epsilon);
                final context = '${config} ${entry.state} target ${entry.target} epsilon ${entry.epsilon}';
                if (entry.result.is_max) {
                    assertEquals(Spring.DURATION_MAX, actual, context);
                }
                else {
                    check('settle_time', entry.result.secs, actual, context);
                }
            }
        }

    }

    function testSampledEasingsMatchGpui() {

        final inputs:Array<Float> = AnimationReference.data().inputs;
        for (spring in springs()) {
            final config = configOf(spring);
            final entries:Array<Dynamic> = spring.sampled_easing;
            for (entry in entries) {
                final sampled = Spring.sampledEasing(config, entry.epsilon);
                if (entry.duration.is_max) {
                    assertEquals(Spring.DURATION_MAX, sampled.duration);
                    continue;
                }
                check('sampled_easing duration', entry.duration.secs, sampled.duration, '$config');
                final values:Array<Float> = entry.values;
                for (i in 0...inputs.length) {
                    check('sampled_easing', values[i], sampled.easing(inputs[i]), '$config epsilon ${entry.epsilon} t ${inputs[i]}');
                }
            }
        }

    }

    function testInterpolationMatchesGpui() {

        final data = AnimationReference.data();
        final hsla:Array<Dynamic> = data.hsla_interpolation;
        for (entry in hsla) {
            final from:Array<Float> = entry.from;
            final to:Array<Float> = entry.to;
            final expected:Array<Float> = entry.result;
            final actual = new AnimationPhase(entry.phase).interpolate(
                new Hsla(from[0], from[1], from[2], from[3]),
                new Hsla(to[0], to[1], to[2], to[3])
            );
            final context = '$from -> $to at ${entry.phase}';
            check('hsla_interpolation', expected[0], actual.h, context);
            check('hsla_interpolation', expected[1], actual.s, context);
            check('hsla_interpolation', expected[2], actual.l, context);
            check('hsla_interpolation', expected[3], actual.a, context);
        }

        final phases:Array<Dynamic> = data.phase_interpolation;
        for (entry in phases) {
            final phase = new AnimationPhase(entry.phase);
            final range:Array<Float> = entry.range;
            final context = 'phase ${entry.phase} range $range';
            check('interpolate_between', entry.between, phase.interpolateBetween(range[0], range[1], 10.0, 20.0), context);
            check('interpolate_between_clamped', entry.between_clamped, phase.interpolateBetweenClamped(range[0], range[1], 10.0, 20.0), context);
            check('clamp', entry.clamp, phase.clamp(range[0], range[1]).value, context);
        }


    }

/// Helpers

    function check(name:String, expected:Null<Float>, actual:Float, ?context:String, scale:Float = 1.0, ?pos:haxe.PosInfos):Void {

        if (expected == null) {
            // Not finite in GPUI
            assertFalse(Math.isFinite(actual), '$name $context: expected a non finite value, got $actual', pos);
            return;
        }
        final error = Math.abs(actual - expected);
        final previous = maxErrors.get(name);
        if (previous == null || error > previous) maxErrors.set(name, error);
        final scaledError = error / Math.max(scale, Math.abs(expected));
        assertTrue(scaledError <= TOLERANCE, '$name $context: expected $expected, got $actual (error $error, scaled $scaledError)', pos);

    }

    static function magnitude(values:Array<Float>):Float {

        var result = 1.0;
        for (value in values) result = Math.max(result, Math.abs(value));
        return result;

    }

    function printErrors():Void {

        #if gpui_animation_errors
        final names = [for (name in maxErrors.keys()) name];
        names.sort((a, b) -> a < b ? -1 : 1);
        for (name in names) trace('spring $name: max abs error ${maxErrors.get(name)}');
        #end

    }

    static function springs():Array<Dynamic> {

        return AnimationReference.data().springs;

    }

    static function configOf(spring:Dynamic):SpringConfig {

        return new SpringConfig(spring.stiffness, spring.damping, spring.mass);

    }

    static function stateOf(values:Array<Float>):SpringState {

        return new SpringState(values[0], values[1]);

    }

    static function multiply(left:SpringPropagator, right:SpringPropagator):SpringPropagator {

        return new SpringPropagator(
            left.m00 * right.m00 + left.m01 * right.m10,
            left.m00 * right.m01 + left.m01 * right.m11,
            left.m10 * right.m00 + left.m11 * right.m10,
            left.m10 * right.m01 + left.m11 * right.m11
        );

    }

}

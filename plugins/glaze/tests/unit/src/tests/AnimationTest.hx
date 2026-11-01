package tests;

import gpui.Animation;
import gpui.AnimationState;
import gpui.Easing;
import gpui.Spring;
import gpui.SpringAnimation;
import gpui.SpringAnimationState;
import gpui.SpringConfig;
import gpui.SpringPlayback;
import gpui.TestDispatcher;
import testing.TestCase;

/**
 * Tests of the animation port (gpui-pre 0.3.10: src/elements/animation.rs).
 *
 * - Easing functions are compared with the values dumped from the original GPUI
 *   by `reference/examples/animation_dump.rs`. They emulate f32 like GPUI, so
 *   the only differences are 1 ulp of macOS `sinf` in `pulsatingBetween`.
 * - The `#[cfg(test)]` element tests are ported on the pure state machines
 *   (`AnimationState`, `SpringAnimationState`) driven by the `TestDispatcher`
 *   clock: `AnimationHarness` and `SpringHarness` reproduce what the element does on each render
 *   (advance the state, record the value, request an animation frame when not
 *   done) and what `simulate_next_frame` does (run pending animation frames).
 *   `test_animation_parent` and `test_spring_animation_parent` only check that
 *   the Rust code builds and wait for the element wrapper.
 */
class AnimationTest extends TestCase {

    static inline final TOLERANCE = 1e-6;

    /**
     * Largest absolute difference with GPUI for each easing, filled by
     * `testEasingsMatchGpui` (printed when the define `gpui_animation_errors` is set).
     */
    public static final maxErrors:Map<String, Float> = new Map();

/// Easing functions against GPUI

    function testEasingsMatchGpui() {

        final data = AnimationReference.data();
        final inputs:Array<Float> = data.inputs;
        final easings:Dynamic = data.easings;

        final functions:Array<{name:String, easing:Float->Float}> = [
            {name: 'linear', easing: Easing.linear},
            {name: 'quadratic', easing: Easing.quadratic},
            {name: 'ease_in_out', easing: Easing.easeInOut},
            {name: 'ease_out_quint', easing: Easing.easeOutQuint()},
            {name: 'bounce_linear', easing: Easing.bounce(Easing.linear)},
            {name: 'bounce_ease_in_out', easing: Easing.bounce(Easing.easeInOut)},
            {name: 'bounce_ease_out_quint', easing: Easing.bounce(Easing.easeOutQuint())},
            {name: 'pulsating_between_0.4_0.8', easing: Easing.pulsatingBetween(0.4, 0.8)},
            {name: 'pulsating_between_0.1_1', easing: Easing.pulsatingBetween(0.1, 1.0)},
            {name: 'pulsating_between_1_0', easing: Easing.pulsatingBetween(1.0, 0.0)}
        ];

        for (fn in functions) {
            final expected:Array<Float> = Reflect.field(easings, fn.name);
            assertEquals(inputs.length, expected.length, fn.name);
            var maxError = 0.0;
            for (i in 0...inputs.length) {
                final actual = fn.easing(inputs[i]);
                final error = Math.abs(actual - expected[i]);
                if (error > maxError) maxError = error;
                assertFloatEquals(expected[i], actual, TOLERANCE, '${fn.name}(${inputs[i]})');
            }
            maxErrors.set(fn.name, maxError);
        }

        #if gpui_animation_errors
        for (name => error in maxErrors) trace('easing $name: max error $error');
        #end

    }

    function testEasingEndpoints() {

        assertEquals(0.0, Easing.easeInOut(0.0));
        assertEquals(0.5, Easing.easeInOut(0.5));
        assertEquals(1.0, Easing.easeInOut(1.0));
        assertEquals(1.0, Easing.easeOutQuint()(1.0));
        assertEquals(0.0, Easing.bounce(Easing.linear)(1.0));
        assertEquals(1.0, Easing.bounce(Easing.linear)(0.5));
        // f32 result, like GPUI
        assertFloatEquals(0.6, Easing.pulsatingBetween(0.4, 0.8)(0.0), 1e-7);

    }

/// Animation builder

    function testAnimationDefaults() {

        final animation = new Animation(1.5);
        assertEquals(1.5, animation.duration);
        assertTrue(animation.oneshot);
        assertFalse(animation.synced);
        assertEquals(0.25, animation.easing(0.25));
        assertNull(animation.maxFps);
        assertNull(animation.frameInterval());

        final repeating = animation.clone().repeat();
        assertFalse(repeating.oneshot);
        assertFalse(repeating.synced);
        assertTrue(animation.oneshot);

        final synced = new Animation(1).repeatSynced();
        assertFalse(synced.oneshot);
        assertTrue(synced.synced);

        assertEquals(0.0625, new Animation(1).withEasing(Easing.quadratic).easing(0.25));

        // Duration::from_secs_f32(1.0 / 10.0) is 100_000_001 ns (0.1 in f32)
        assertFloatEquals(0.100000001, new Animation(1).withMaxFps(10).frameInterval(), 1e-15);
        assertNull(new Animation(1).withMaxFps(0).frameInterval());
        assertNull(new Animation(1).withMaxFps(-5).frameInterval());
        assertNull(new Animation(1).withMaxFps(Math.POSITIVE_INFINITY).frameInterval());
        assertNull(new Animation(1).withMaxFps(Math.NaN).frameInterval());

    }

    function testSpringSampledEasingAsAnimation() {

        final sampled = Spring.sampledEasing(new SpringConfig(100.0, 10.0, 1.0), 0.001);
        final animation = new Animation(sampled.duration).withEasing(sampled.easing);
        assertEquals(sampled.duration, animation.duration);
        assertEquals(1.0, animation.easing(1.0));

    }

/// Progress computation (AnimationElement::request_layout)

    function testOneshotAnimationClampsAndFinishes() {

        final animations = [new Animation(2.0).withEasing(Easing.quadratic)];
        final state = new AnimationState(10.0);

        state.advance(animations, 10.0, 0.0, false);
        assertEquals(0, state.frameAnimationIx);
        assertEquals(0.0, state.frameDelta);
        assertFalse(state.frameDone);

        state.advance(animations, 11.0, 0.0, false);
        assertEquals(0.5, state.frameProgress);
        assertEquals(0.25, state.frameDelta);
        assertFalse(state.frameDone);

        // Exactly at the end, delta is 1 but the animation is not done yet (GPUI checks delta > 1)
        state.advance(animations, 12.0, 0.0, false);
        assertEquals(1.0, state.frameDelta);
        assertFalse(state.frameDone);

        state.advance(animations, 15.0, 0.0, false);
        assertEquals(1.0, state.frameProgress);
        assertEquals(1.0, state.frameDelta);
        assertTrue(state.frameDone);

    }

    function testRepeatingAnimationWraps() {

        final animations = [new Animation(2.0).repeat()];
        final state = new AnimationState(0.0);

        state.advance(animations, 5.0, 0.0, false);
        assertEquals(0.5, state.frameDelta);
        assertFalse(state.frameDone);

        // Exactly one cycle: GPUI only wraps when delta > 1
        state.advance(animations, 2.0, 0.0, false);
        assertEquals(1.0, state.frameDelta);

        state.advance(animations, 7.0, 0.0, false);
        assertEquals(0.5, state.frameDelta);
        assertFalse(state.frameDone);

    }

    function testAnimationChain() {

        final animations = [new Animation(1.0), new Animation(2.0).withEasing(Easing.quadratic)];
        final state = new AnimationState(0.0);

        state.advance(animations, 0.5, 0.0, false);
        assertEquals(0, state.frameAnimationIx);
        assertEquals(0.5, state.frameDelta);

        // Past the first animation: renders its end state, then the chain moves on
        state.advance(animations, 1.5, 0.0, false);
        assertEquals(0, state.frameAnimationIx);
        assertEquals(1.0, state.frameDelta);
        assertFalse(state.frameDone);
        assertEquals(1, state.animationIx);
        assertEquals(1.5, state.start);

        state.advance(animations, 2.5, 0.0, false);
        assertEquals(1, state.frameAnimationIx);
        assertEquals(0.25, state.frameDelta);

        state.advance(animations, 4.0, 0.0, false);
        assertEquals(1, state.frameAnimationIx);
        assertEquals(1.0, state.frameDelta);
        assertTrue(state.frameDone);

    }

    function testReduceMotionStaticStates() {

        final oneshot = [new Animation(1.0), new Animation(1.0).withEasing(Easing.quadratic)];
        final state = new AnimationState(0.0);
        state.advance(oneshot, 0.0, 0.0, true);
        assertEquals(1, state.frameAnimationIx);
        assertEquals(1.0, state.frameDelta);
        assertTrue(state.frameDone);

        final repeating = [new Animation(1.0).repeat().withEasing(x -> x + 0.5)];
        state.advance(repeating, 0.3, 0.0, true);
        assertEquals(0, state.frameAnimationIx);
        assertEquals(0.5, state.frameDelta);
        assertTrue(state.frameDone);

    }

    function testZeroDurationSyncedAnimationIsNotReduced() {

        // GPUI skips the modulo when the duration is zero: the delta is then elapsed / 0
        final animations = [new Animation(0.0).repeatSynced()];
        final state = new AnimationState(0.0);
        state.advance(animations, 1.0, 0.0, false);
        assertTrue(Math.isNaN(state.frameDelta));

    }

/// Ported #[cfg(test)] tests of animation.rs

    function testRepeatingAnimationSchedulesAnimationFrames() {

        final harness = new AnimationHarness([new Animation(1.0).repeat()]);
        harness.render();
        assertEquals(1, harness.deltas.length);

        for (expectedFrames in 2...4) {
            assertEquals(1, harness.simulateNextFrame());
            assertEquals(expectedFrames, harness.deltas.length);
        }

    }

    function testMaxFpsSchedulesTimerDrivenFrames() {

        final animation = new Animation(1.0).repeatSynced().withMaxFps(10.0);
        final harness = new AnimationHarness([animation]);
        harness.render();

        final assertDeltasApproxEq = (expected:Array<Float>) -> {
            assertEquals(expected.length, harness.deltas.length);
            for (i in 0...expected.length) {
                assertFloatEquals(expected[i], harness.deltas[i], 1e-2);
            }
        };

        assertDeltasApproxEq([0.0]);

        // No per-frame callback is scheduled; re-renders are timer-driven.
        assertEquals(0, harness.simulateNextFrame());
        assertDeltasApproxEq([0.0]);

        harness.advanceClock(0.105);
        assertDeltasApproxEq([0.0, 0.105]);

        harness.advanceClock(0.105);
        assertDeltasApproxEq([0.0, 0.105, 0.21]);

    }

    function testSyncedAnimationsSharePhaseAcrossElements() {

        final dispatcher = new TestDispatcher();
        final epoch = dispatcher.now();
        final first = new AnimationHarness([new Animation(1.0).repeatSynced()], dispatcher, epoch);
        final second = new AnimationHarness([new Animation(1.0).repeatSynced()], dispatcher, epoch);

        first.render();
        assertEquals('[0]', '' + first.deltas);

        dispatcher.advanceClock(0.25);
        first.simulateNextFrame();
        assertEquals('[0,0.25]', '' + first.deltas);

        // The second element mounts a quarter through the cycle, yet renders
        // the shared phase rather than starting at zero.
        first.render();
        second.render();
        dispatcher.advanceClock(0.25);
        first.simulateNextFrame();
        second.simulateNextFrame();

        assertEquals(0.5, second.deltas[second.deltas.length - 1]);
        assertEquals(first.deltas[first.deltas.length - 1], second.deltas[second.deltas.length - 1]);
        for (delta in second.deltas) assertTrue(delta > 0.0);

        // The phase wraps around each full cycle.
        dispatcher.advanceClock(2.25);
        first.simulateNextFrame();
        assertEquals(0.75, first.deltas[first.deltas.length - 1]);

        // Sub-second precision survives months of uptime.
        dispatcher.advanceClock(300 * 24 * 60 * 60 + 0.5);
        first.simulateNextFrame();
        assertEquals(0.25, first.deltas[first.deltas.length - 1]);

    }

    function testReduceMotionRendersSingleStaticFrame() {

        final harness = new AnimationHarness([new Animation(1.0).repeat()]);
        harness.reduceMotion = true;
        harness.render();
        assertEquals('[0]', '' + harness.deltas);

        assertEquals(0, harness.simulateNextFrame());
        assertEquals('[0]', '' + harness.deltas);

    }

    function testSpringAnimationPreservesVelocityWhenRetargeted() {

        final harness = new SpringHarness(0.0);
        harness.render();
        assertEquals('[0]', '' + harness.values);

        harness.target = 100.0;
        harness.render();

        harness.dispatcher.advanceClock(0.05);
        assertTrue(harness.simulateNextFrame() > 0);
        final valueBeforeRetargeting = harness.last();
        assertTrue(valueBeforeRetargeting > 0.0);
        assertTrue(valueBeforeRetargeting < 100.0);

        harness.target = 0.0;
        harness.render();

        harness.dispatcher.advanceClock(0.005);
        assertTrue(harness.simulateNextFrame() > 0);
        final valueAfterRetargeting = harness.last();
        assertTrue(valueAfterRetargeting > valueBeforeRetargeting);

    }

    function testPausedSpringResumesWithItsVelocity() {

        final harness = new SpringHarness(0.0);
        harness.render();

        harness.target = 100.0;
        harness.render();
        harness.dispatcher.advanceClock(0.05);
        assertTrue(harness.simulateNextFrame() > 0);

        harness.target = 0.0;
        harness.playback = Paused;
        harness.render();
        final pausedValue = harness.last();

        harness.dispatcher.advanceClock(0.5);
        assertTrue(harness.simulateNextFrame() > 0);
        assertEquals(pausedValue, harness.last());
        assertEquals(0, harness.simulateNextFrame());

        harness.playback = Running;
        harness.render();
        harness.dispatcher.advanceClock(0.005);
        assertTrue(harness.simulateNextFrame() > 0);
        assertTrue(harness.last() > pausedValue);

    }

    function testStoppedSpringResumesWithoutVelocity() {

        final harness = new SpringHarness(0.0);
        harness.render();

        harness.target = 1000000.0;
        harness.render();
        harness.dispatcher.advanceClock(0.05);
        assertTrue(harness.simulateNextFrame() > 0);

        harness.target = 0.0;
        harness.playback = Stopped;
        harness.render();
        final stoppedValue = harness.last();

        harness.dispatcher.advanceClock(0.5);
        assertTrue(harness.simulateNextFrame() > 0);
        assertEquals(stoppedValue, harness.last());
        assertEquals(0, harness.simulateNextFrame());

        harness.target = stoppedValue;
        harness.playback = Running;
        harness.render();
        assertEquals(stoppedValue, harness.last());
        assertEquals(0, harness.simulateNextFrame());

    }

    function testCancelledAndCompletedSpringsResolveTheirEndpoints() {

        final harness = new SpringHarness(100.0, 20.0);
        harness.render();
        assertEquals('[20]', '' + harness.values);

        harness.dispatcher.advanceClock(0.05);
        assertTrue(harness.simulateNextFrame() > 0);
        assertTrue(harness.last() > 20.0);

        harness.playback = Cancelled;
        harness.render();
        assertEquals(20.0, harness.last());
        assertTrue(harness.simulateNextFrame() > 0);
        assertEquals(0, harness.simulateNextFrame());

        harness.playback = Completed;
        harness.render();
        assertEquals(100.0, harness.last());
        assertEquals(0, harness.simulateNextFrame());

    }

    function testSpringAnimationRespectsReducedMotion() {

        final harness = new SpringHarness(100.0);
        harness.reduceMotion = true;
        harness.render();

        assertEquals('[100]', '' + harness.values);
        assertEquals(0, harness.simulateNextFrame());

    }

    function testSpringAnimationBuilder() {

        final config = new SpringConfig(100.0, 10.0, 1.0);
        final base = new SpringAnimation<Any>(config);
        assertEquals(Spring.DEFAULT_SPRING_EPSILON, base.epsilon);
        assertEquals(SpringPlayback.Running, base.playback);
        assertNull(base.initial);

        final animation = base.withEpsilon(0.01).withPlayback(Paused).toValue(10.0).fromValue(0.0);
        assertEquals(10.0, animation.target.target());
        assertEquals(14.0, animation.target.resolve(14.0));
        assertEquals(0.01, animation.epsilon);
        assertEquals(SpringPlayback.Paused, animation.playback);
        assertEquals(0.0, animation.initial);
        assertTrue(animation.config.equals(config));

        final phase = new SpringAnimation<Any>(config).toBool(true).from(gpui.SpringPhaseTarget.ofBool(false));
        assertEquals(1.0, phase.target.target());
        assertEquals(0.0, phase.initial);
        assertEquals(1.25, phase.target.resolve(1.25).value);

    }

}

/**
 * Reproduces the frame logic of `AnimationElement` for one element: each
 * `render()` advances its `AnimationState`, records the eased value, then
 * requests an animation frame or, with `maxFps`, schedules a timer that
 * re-renders (a notify of the view).
 */
private class AnimationHarness {

    public final dispatcher:TestDispatcher;

    public final animations:Array<Animation>;

    public final syncedEpoch:Float;

    public final deltas:Array<Float> = [];

    public var reduceMotion:Bool = false;

    var state:AnimationState = null;

    var framePending:Bool = false;

    public function new(animations:Array<Animation>, ?dispatcher:TestDispatcher, ?syncedEpoch:Float) {
        this.animations = animations;
        this.dispatcher = dispatcher != null ? dispatcher : new TestDispatcher();
        this.syncedEpoch = syncedEpoch != null ? syncedEpoch : this.dispatcher.now();
    }

    public function render():Void {
        final now = dispatcher.now();
        if (state == null) {
            state = new AnimationState(now);
        }
        state.advance(animations, now, syncedEpoch, reduceMotion);
        deltas.push(state.frameDelta);

        if (!state.frameDone) {
            final interval = animations[state.frameAnimationIx].frameInterval();
            if (interval != null) {
                if (!state.delayedFramePending) {
                    state.delayedFramePending = true;
                    final pendingState = state;
                    dispatcher.dispatchAfter(interval, () -> {
                        pendingState.delayedFramePending = false;
                        render();
                    });
                }
            }
            else {
                framePending = true;
            }
        }
    }

    public function simulateNextFrame():Int {
        if (!framePending) return 0;
        framePending = false;
        render();
        dispatcher.runUntilParked();
        return 1;
    }

    public function advanceClock(seconds:Float):Void {
        dispatcher.advanceClock(seconds);
        dispatcher.runUntilParked();
    }

}

/**
 * Reproduces `SpringAnimationTestView` of animation.rs: a spring
 * `SpringConfig::new(100.0, 2.0, 1.0)` with epsilon 0.01, rendered through
 * the frame logic of `SpringAnimationElement`.
 */
private class SpringHarness {

    public final dispatcher:TestDispatcher = new TestDispatcher();

    public final values:Array<Float> = [];

    public var target:Float;

    public var initial:Null<Float>;

    public var playback:SpringPlayback = Running;

    public var reduceMotion:Bool = false;

    var state:SpringAnimationState = null;

    var framePending:Bool = false;

    public function new(target:Float, ?initial:Float) {
        this.target = target;
        this.initial = initial;
    }

    public function render():Void {
        var animation = new SpringAnimation<Any>(new SpringConfig(100.0, 2.0, 1.0))
            .toValue(target)
            .withEpsilon(0.01)
            .withPlayback(playback);
        if (initial != null) {
            animation = animation.fromValue(initial);
        }

        final now = dispatcher.now();
        if (state == null) {
            state = SpringAnimationState.create(animation.config, animation.target.target(), animation.initial, animation.playback, now);
        }
        final done = state.advance(animation.config, animation.target.target(), animation.epsilon, animation.playback, now, reduceMotion);
        values.push(animation.target.resolve(state.spring.position));
        if (!done) {
            framePending = true;
        }
    }

    public function simulateNextFrame():Int {
        if (!framePending) return 0;
        framePending = false;
        render();
        return 1;
    }

    public function last():Float {
        return values[values.length - 1];
    }

}

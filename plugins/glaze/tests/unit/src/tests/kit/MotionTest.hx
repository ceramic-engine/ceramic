// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.Bounds;
import gpui.Context;
import gpui.ElementId;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.SpringMath.f32;
import gpui.Window;
import gpui.base.motion.Discrete;
import gpui.base.motion.Easing;
import gpui.base.motion.Interpolators;
import gpui.base.motion.Keyframes;
import gpui.base.motion.Motion;
import gpui.base.motion.MotionStatus;
import gpui.base.motion.MotionTransform;
import gpui.base.motion.MotionValue;
import gpui.base.motion.Presence;
import gpui.base.motion.Sequence;
import gpui.base.motion.SignedDuration;
import gpui.base.motion.Spring;
import gpui.base.motion.Stagger;
import gpui.base.motion.Timing;
import gpui.base.motion.Transition;
import gpui.base.motion.TransitionId;

import gpui.Prelude.*;

using gpui.base.motion.SignedDuration.SignedDurationTools;

class MotionStatusView extends Model implements Render {

    public var target:Float = 0.0;

    public final policy:Transition;

    public final samples:Array<MotionValue<Float>> = [];

    public function new(policy:Transition) {
        super();
        this.policy = policy;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        samples.push(Motion.transitionWithStatus(TransitionId.named('status-test', 'value'), target, policy, window, cx));
        return div();
    }

}

class MotionKeyframeView extends Model implements Render {

    final track:Keyframes<Float>;

    final timing:Timing;

    public final samples:Array<MotionValue<Float>> = [];

    public function new(track:Keyframes<Float>, timing:Timing) {
        super();
        this.track = track;
        this.timing = timing;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        samples.push(Motion.animateKeyframes('keyframe-test', track, timing, window, cx));
        return div();
    }

}

class MotionPresenceView extends Model implements Render {

    public var present:Bool;

    public final samples:Array<PresenceSample> = [];

    public function new(present:Bool) {
        super();
        this.present = present;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        samples.push(new Presence('presence-test', present).transition(new Transition(0.1).ease(t -> t)).sample(window, cx));
        return div();
    }

}

class MotionSequenceView extends Model implements Render {

    public var steps:Array<SequenceStep<Float>>;

    public final samples:Array<SequenceSample<Float>> = [];

    public function new(steps:Array<SequenceStep<Float>>) {
        super();
        this.steps = steps;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        samples.push(new Sequence('sequence-test', 0.0, Interpolators.FLOAT).withSteps(steps).sample(window, cx));
        return div();
    }

}

class MotionSingleStepView extends Model implements Render {

    public var armed:Bool = false;

    public final sequenceSamples:Array<SequenceSample<Float>> = [];

    public final plainSamples:Array<MotionValue<Float>> = [];

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final policy = new Transition(0.1).delay(0.02).easing(Easing.EaseInOut);
        // A plain transition adopts its first target where a sequence plays
        // from `from` at once, so the transition is primed at 0.0 and both
        // leave for 10.0 on the frame that arms the view.
        if (!armed) {
            Motion.transitionWithStatus('plain', 0.0, policy, window, cx);
            return div();
        }
        final sequence = new Sequence('single-step', 0.0, Interpolators.FLOAT).withStep(10.0, policy).sample(window, cx);
        final plain = Motion.transitionWithStatus('plain', 10.0, policy, window, cx);
        sequenceSamples.push(sequence);
        plainSamples.push(plain);
        return div();
    }

}

class MotionTestView extends Model implements Render {

    public var target:Float = 0.0;

    final duration:Float;

    public final samples:Array<Float> = [];

    public function new(duration:Float) {
        super();
        this.duration = duration;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        samples.push(Motion.transition(TransitionId.named('test', 'value'), target, new Transition(duration).ease(t -> t), window, cx));
        return div();
    }

}

class MotionDelayedView extends Model implements Render {

    public var target:Float = 0.0;

    public final samples:Array<Float> = [];

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        samples.push(Motion.transition(TransitionId.named('delayed-test', 'value'), target, new Transition(0.1).delay(0.05).ease(t -> t), window, cx));
        return div();
    }

}

class MotionSpringView extends Model implements Render {

    public var target:Float = 0.0;

    public var policy:Spring;

    public final samples:Array<Float> = [];

    public function new(policy:Spring) {
        super();
        this.policy = policy;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        samples.push(Motion.spring(TransitionId.named('spring-test', 'value'), target, policy, window, cx));
        return div();
    }

}

/**
 * Tests of `gpui.base.motion` (Rust `motion.rs`: `css_timing_tests`,
 * `motion_track_tests` and `tests`).
 *
 * Durations are seconds. Motion computes in `f32` like Rust, so the values
 * Rust compares exactly are compared exactly here, against the `f32` of the
 * Rust literal where it is not exact in binary (`f32(0.6)`).
 */
class MotionTest extends KitTestCase {

    // css_timing_tests

    function testCssKeywordEasingMatchesPublishedReferenceSamples() {
        final cases:Array<{easing:Easing, samples:Array<Array<Float>>}> = [
            {easing: Easing.Ease, samples: [[0.2, 0.295], [0.5, 0.802], [0.8, 0.976]]},
            {easing: Easing.EaseIn, samples: [[0.2, 0.062], [0.5, 0.315], [0.8, 0.692]]},
            {easing: Easing.EaseOut, samples: [[0.2, 0.308], [0.5, 0.685], [0.8, 0.938]]},
            {easing: Easing.EaseInOut, samples: [[0.2, 0.082], [0.5, 0.5], [0.8, 0.918]]},
        ];
        for (c in cases) {
            for (sample in c.samples) {
                final actual = c.easing.sample(sample[0]);
                assertTrue(Math.abs(actual - sample[1]) < 0.002, '${c.easing}(${sample[0]}) = $actual, expected ${sample[1]}');
            }
        }
    }

    function testCubicBezierEasingKeepsAnticipationAndOvershoot() {
        final anticipate = Easing.cubicBezier(1.0, -0.4, 0.35, 0.95);
        final overshoot = Easing.cubicBezier(0.175, 0.885, 0.32, 1.275);

        assertTrue(anticipate.sample(0.2) < 0.0);
        assertTrue(overshoot.sample(0.8) > 1.0);
        for (easing in [anticipate, overshoot]) {
            assertEquals(0.0, easing.sample(-1.0));
            assertEquals(1.0, easing.sample(2.0));
        }
    }

    function testStepEasingObservesCssJumpPositions() {
        final start = Easing.steps(4, JumpStart);
        final end = Easing.steps(4, JumpEnd);

        assertEquals(0.25, start.sample(0.0));
        assertEquals(0.25, start.sample(0.24));
        assertEquals(0.5, start.sample(0.25));
        assertEquals(0.0, end.sample(0.0));
        assertEquals(0.0, end.sample(0.24));
        assertEquals(0.25, end.sample(0.25));
        assertEquals(InvalidStepCount, easingError(() -> Easing.steps(0, JumpEnd)));

        final none = Easing.steps(4, JumpNone);
        final both = Easing.steps(4, JumpBoth);
        assertEquals(0.0, none.sample(0.0));
        assertTrue(Math.abs(none.sample(0.5) - f32(2.0 / 3.0)) < F32_EPSILON);
        assertEquals(1.0, none.sample(1.0));
        assertEquals(f32(0.2), both.sample(0.0));
        assertEquals(1.0, both.sample(1.0));
        assertEquals(InvalidStepCount, easingError(() -> Easing.steps(1, JumpNone)));
    }

    function testLinearStopsFillOmittedPositionsBeforeSampling() {
        final easing = Easing.linearStops([
            LinearStop.at(0.0, 0.0),
            new LinearStop(0.2),
            new LinearStop(0.8),
            LinearStop.at(1.0, 1.0),
        ]);

        assertTrue(Math.abs(easing.sample(1.0 / 3.0) - f32(0.2)) < 1e-6);
        assertTrue(Math.abs(easing.sample(0.5) - 0.5) < 1e-6);
        assertEquals(InvalidLinearStops, easingError(() -> Easing.linearStops([LinearStop.at(0.0, 0.8), LinearStop.at(1.0, 0.2)])));
    }

    function testNegativeDelayStartsInsideTheActiveInterval() {
        final timing = new Timing(0.1).delay(SignedDurationTools.negative(0.025));
        final sample = timing.sample(0.0);

        assertEquals(Active, sample.phase);
        assertTrue(Math.abs(sample.directedProgress - 0.25) < F32_EPSILON);
        assertTrue(sample.active);
        assertFalse(sample.finished);
    }

    function testAlternateDirectionReversesOddIterations() {
        final timing = new Timing(0.1).iterations(Finite(2)).direction(Alternate).ease(Easing.Linear);

        final first = timing.sample(0.025);
        final second = timing.sample(0.125);
        final finished = timing.sample(0.2);

        assertEquals(0, first.iteration);
        assertEquals(0.25, first.directedProgress);
        assertEquals(1, second.iteration);
        assertEquals(0.75, second.directedProgress);
        assertEquals(After, finished.phase);
        assertEquals(0.0, finished.directedProgress);
        assertTrue(finished.finished);
    }

    // motion_track_tests

    function testKeyframesValidateOffsetsAndSampleEachSegmentsEasing() {
        assertEquals(MissingEndpoint, keyframeError(() -> Keyframes.tryNewFloat([new Keyframe(0.2, 0.0), new Keyframe(1.0, 1.0)])));
        assertEquals(OffsetsNotMonotonic, keyframeError(() -> Keyframes.tryNewFloat([
            new Keyframe(0.0, 0.0),
            new Keyframe(0.8, 1.0),
            new Keyframe(0.7, 2.0),
            new Keyframe(1.0, 3.0),
        ])));

        final track = Keyframes.tryNewFloat([
            new Keyframe(0.0, 0.0).ease(Easing.steps(2, JumpEnd)),
            new Keyframe(0.5, 10.0).ease(Easing.Linear),
            new Keyframe(1.0, 20.0),
        ]);

        assertEquals(0.0, track.sample(0.2));
        assertEquals(5.0, track.sample(0.3));
        assertEquals(15.0, track.sample(0.75));
        assertEquals(20.0, track.sample(1.0));
    }

    function testDiscreteValuesSwitchOnlyAtTheRequestedProgress() {
        final value = new Discrete('old', 'new').switchAt(0.75);
        assertEquals('old', value.sample(0.749));
        assertEquals('new', value.sample(0.75));
        var error:Null<DiscreteError> = null;
        try {
            new Discrete(0, 1).switchAt(Math.NaN);
        }
        catch (e:DiscreteError) {
            error = e;
        }
        assertEquals(InvalidSwitchPoint, error);
    }

    function testStaggerOriginsProduceStableDelaysWithoutAllocatingASchedule() {
        final interval = 0.02;
        final first = new Stagger(interval, First);
        final last = new Stagger(interval, Last);
        final center = new Stagger(interval, Center);

        assertEquals(0.06, first.delay(3, 5));
        assertEquals(0.02, last.delay(3, 5));
        assertEquals(0.0, center.delay(2, 5));
        assertEquals(0.04, center.delay(0, 5));
        assertEquals(0.0, first.delay(7, 0));
    }

    function testCommonGpuiGeometryInterpolatesChannelByChannel() {
        final fromSize = size(px(10.0), px(20.0));
        final toSize = size(px(30.0), px(60.0));
        assertTrue(Interpolators.SIZE.interpolate(fromSize, toSize, 0.25).equals(size(px(15.0), px(30.0))));

        final from = new Bounds(point(px(0.0), px(10.0)), fromSize);
        final to = new Bounds(point(px(40.0), px(50.0)), toSize);
        assertTrue(Interpolators.BOUNDS.interpolate(from, to, 0.5).equals(new Bounds(point(px(20.0), px(30.0)), size(px(20.0), px(40.0)))));

        final transform = MotionTransform.identity().interpolate(
            new MotionTransform(point(px(20.0), px(40.0)), point(2.0, 0.5), f32(Math.PI), 0.0),
            0.5
        );
        assertTrue(transform.translation.equals(point(px(10.0), px(20.0))));
        assertTrue(transform.scale.equals(point(1.5, 0.75)));
        assertEquals(f32(Math.PI / 2), transform.rotationRadians);
        assertEquals(0.5, transform.opacity);
    }

    // tests: status

    function openStatus(policy:Transition) {
        return openWindow(_ -> new MotionStatusView(policy));
    }

    function renderStatus(opened:{window:Window, view:gpui.Entity<MotionStatusView>}, target:Float):MotionValue<Float> {
        (opened.view : MotionStatusView).target = target;
        refresh(opened.window);
        final samples = (opened.view : MotionStatusView).samples;
        return samples[samples.length - 1];
    }

    function testStatusTransitionReportsDelayRunningAndFinished() {
        final fixture = openStatus(new Transition(0.1).delay(0.02));
        assertEquals(Delayed, renderStatus(fixture, 1.0).status);

        advanceClock(20);
        assertEquals(Running, renderStatus(fixture, 1.0).status);
        advanceClock(100);
        assertEquals(Finished, renderStatus(fixture, 1.0).status);
    }

    function testNegativeDelaySamplesATargetChangeInsideItsInterval() {
        final fixture = openStatus(new Transition(0.1).delay(SignedDurationTools.negative(0.025)).ease(t -> t));
        final sample = renderStatus(fixture, 1.0);
        assertEquals(Running, sample.status);
        assertEquals(0.25, sample.value);
    }

    function testADirectReversalShortensTheReturnTransition() {
        final fixture = openStatus(new Transition(0.1).ease(t -> t));
        assertEquals(0.0, renderStatus(fixture, 1.0).value);
        advanceClock(50);
        assertEquals(0.5, renderStatus(fixture, 0.0).value);
        advanceClock(25);
        assertEquals(0.25, renderStatus(fixture, 0.0).value);
    }

    // tests: keyframes

    function testKeyedKeyframesFollowTimingAndStopAfterCompletion() {
        final opened = openWindow(_ -> new MotionKeyframeView(Keyframes.tryNewFloat([new Keyframe(0.0, 0.0), new Keyframe(1.0, 10.0)]), new Timing(0.1)));
        final view:MotionKeyframeView = opened.view;
        function last() return view.samples[view.samples.length - 1];
        assertEquals(0.0, last().value);
        assertEquals(Running, last().status);

        advanceClock(50);
        assertEquals(1, simulateNextFrame(opened.window));
        runUntilParked();
        assertEquals(5.0, last().value);

        advanceClock(50);
        refresh(opened.window);
        assertEquals(Finished, last().status);
        simulateNextFrame(opened.window);
        runUntilParked();
        assertEquals(0, simulateNextFrame(opened.window));
    }

    // tests: presence

    function openPresence(initiallyPresent:Bool) {
        return openWindow(_ -> new MotionPresenceView(initiallyPresent));
    }

    function renderPresence(opened:{window:Window, view:gpui.Entity<MotionPresenceView>}, present:Bool):PresenceSample {
        (opened.view : MotionPresenceView).present = present;
        refresh(opened.window);
        return lastPresence(opened);
    }

    function lastPresence(opened:{window:Window, view:gpui.Entity<MotionPresenceView>}):PresenceSample {
        final samples = (opened.view : MotionPresenceView).samples;
        return samples[samples.length - 1];
    }

    function testPresenceEntersExitsAndOnlyUnmountsAfterExit() {
        final fixture = openPresence(true);
        final entering = lastPresence(fixture);
        assertEquals(Entering, entering.phase);
        assertEquals(0.0, entering.progress);
        assertTrue(entering.shouldRender());

        advanceClock(100);
        final present = renderPresence(fixture, true);
        assertEquals(Present, present.phase);
        assertEquals(1.0, present.progress);

        final exiting = renderPresence(fixture, false);
        assertEquals(Exiting, exiting.phase);
        assertEquals(1.0, exiting.progress);
        assertTrue(exiting.shouldRender());

        advanceClock(100);
        final absent = renderPresence(fixture, false);
        assertEquals(Absent, absent.phase);
        assertEquals(0.0, absent.progress);
        assertFalse(absent.shouldRender());
    }

    function testPresenceReentryReversesFromTheExitSample() {
        final fixture = openPresence(true);
        advanceClock(100);
        renderPresence(fixture, true);
        renderPresence(fixture, false);
        advanceClock(40);
        final reentering = renderPresence(fixture, true);

        assertEquals(Entering, reentering.phase);
        assertEquals(f32(0.6), reentering.progress);
    }

    function testReducedMotionResolvesPresenceWithoutAPendingFrame() {
        app.setReduceMotion(true);
        final fixture = openPresence(true);
        assertEquals(Present, lastPresence(fixture).phase);
        assertEquals(0, simulateNextFrame(fixture.window));
        assertEquals(Absent, renderPresence(fixture, false).phase);
    }

    // tests: sequence

    static function linear(millis:Float):Transition {
        return new Transition(millis / 1000.0).ease(t -> t);
    }

    function openSequence(steps:Array<SequenceStep<Float>>) {
        return openWindow(_ -> new MotionSequenceView(steps));
    }

    function lastSequence(opened:{window:Window, view:gpui.Entity<MotionSequenceView>}):SequenceSample<Float> {
        final samples = (opened.view : MotionSequenceView).samples;
        return samples[samples.length - 1];
    }

    function renderSequence(opened:{window:Window, view:gpui.Entity<MotionSequenceView>}):SequenceSample<Float> {
        refresh(opened.window);
        return lastSequence(opened);
    }

    function advanceSequence(opened:{window:Window, view:gpui.Entity<MotionSequenceView>}, millis:Float):SequenceSample<Float> {
        advanceClock(millis);
        return renderSequence(opened);
    }

    function assertSample(sample:SequenceSample<Float>, value:Float, step:Int, status:MotionStatus, ?pos:haxe.PosInfos) {
        assertEquals('$value $step ${status.toString()}', '${sample.value()} ${sample.step()} ${sample.status().toString()}', null, pos);
    }

    function testSequenceStepsAdvanceInOrderAtTheirBoundaries() {
        final fixture = openSequence([
            new SequenceStep(10.0, linear(100)),
            new SequenceStep(20.0, linear(100).delay(0.05)),
        ]);
        assertSample(lastSequence(fixture), 0.0, 0, Running);
        assertSample(advanceSequence(fixture, 50), 5.0, 0, Running);

        // The first step ends and the second begins within one frame; nothing
        // reports the first step as finished in between.
        assertSample(advanceSequence(fixture, 50), 10.0, 1, Delayed);
        assertSample(advanceSequence(fixture, 50), 10.0, 1, Running);
        assertSample(advanceSequence(fixture, 50), 15.0, 1, Running);
        assertSample(advanceSequence(fixture, 50), 20.0, 1, Finished);
    }

    function testASequenceStartsItsNextStepWhereThePreviousEndedNotAtTheFrame() {
        final fixture = openSequence([
            new SequenceStep(10.0, linear(100)),
            new SequenceStep(20.0, linear(100)),
        ]);
        // One frame at 50 ms, the next at 175 ms: the boundary at 100 ms fell
        // between them, and the second step is sampled as if it started there.
        advanceSequence(fixture, 50);
        assertSample(advanceSequence(fixture, 125), 17.5, 1, Running);
    }

    function testZeroDurationStepsCompleteWithinTheFrameThatReachesThem() {
        final fixture = openSequence([
            new SequenceStep(5.0, linear(0)),
            new SequenceStep(6.0, linear(0)),
            new SequenceStep(10.0, linear(100)),
        ]);
        assertSample(lastSequence(fixture), 6.0, 2, Running);
        assertSample(advanceSequence(fixture, 50), 8.0, 2, Running);
    }

    function testASequenceReportsFinishedOnceAndThenStopsRequestingFrames() {
        final fixture = openSequence([
            new SequenceStep(10.0, linear(100)),
            new SequenceStep(20.0, linear(100)),
        ]);
        assertEquals(1, simulateNextFrame(fixture.window));
        runUntilParked();

        advanceClock(100);
        assertEquals(1, simulateNextFrame(fixture.window));
        runUntilParked();
        assertEquals(Running, lastSequence(fixture).status());
        for (sample in (fixture.view : MotionSequenceView).samples) {
            assertFalse(sample.isFinished(), "the first step's end must not read as the sequence finishing");
        }

        assertSample(advanceSequence(fixture, 100), 20.0, 1, Finished);
        simulateNextFrame(fixture.window);
        runUntilParked();
        assertEquals(0, simulateNextFrame(fixture.window));
        assertSample(advanceSequence(fixture, 1000), 20.0, 1, Finished);
    }

    function testReducedMotionAdoptsASequencesLastTargetWithoutRequestingAFrame() {
        app.setReduceMotion(true);
        final fixture = openSequence([
            new SequenceStep(10.0, linear(100)),
            new SequenceStep(20.0, linear(100)),
        ]);
        assertSample(lastSequence(fixture), 20.0, 1, Finished);
        assertEquals(0, simulateNextFrame(fixture.window));
    }

    function testAChangedStepTargetRestartsTheSequenceFromTheSampledValue() {
        final fixture = openSequence([
            new SequenceStep(10.0, linear(100)),
            new SequenceStep(20.0, linear(100)),
        ]);
        advanceSequence(fixture, 150);
        assertSample(lastSequence(fixture), 15.0, 1, Running);

        (fixture.view : MotionSequenceView).steps = [
            new SequenceStep(10.0, linear(100)),
            new SequenceStep(35.0, linear(100)),
        ];
        assertSample(renderSequence(fixture), 15.0, 0, Running);
        assertSample(advanceSequence(fixture, 50), 12.5, 0, Running);
        assertSample(advanceSequence(fixture, 100), 22.5, 1, Running);

        // Fewer steps than the one being played is a different sequence too.
        (fixture.view : MotionSequenceView).steps = [new SequenceStep(0.0, linear(100))];
        assertSample(renderSequence(fixture), 22.5, 0, Running);
        assertSample(advanceSequence(fixture, 100), 0.0, 0, Finished);
    }

    function testAChangeToAStepNotBeingPlayedDoesNotRestartTheSequence() {
        final fixture = openSequence([
            new SequenceStep(10.0, linear(100)),
            new SequenceStep(20.0, linear(100)),
        ]);
        advanceSequence(fixture, 50);
        (fixture.view : MotionSequenceView).steps = [
            new SequenceStep(10.0, linear(100)),
            new SequenceStep(30.0, linear(100)),
        ];
        assertSample(renderSequence(fixture), 5.0, 0, Running);
        assertSample(advanceSequence(fixture, 100), 20.0, 1, Running);
    }

    function testASingleStepSequenceMatchesAPlainTransition() {
        final opened = openWindow(_ -> new MotionSingleStepView());
        final view:MotionSingleStepView = opened.view;
        view.armed = true;
        for (millis in [0, 10, 30, 70, 120]) {
            advanceClock(millis);
            refresh(opened.window);
            final sequence = view.sequenceSamples[view.sequenceSamples.length - 1];
            final plain = view.plainSamples[view.plainSamples.length - 1];
            assertEquals(plain.value, sequence.value(), 'value after $millis ms');
            assertEquals(plain.status, sequence.status(), 'status after $millis ms');
            assertEquals(0, sequence.step());
        }
    }

    function testAnEmptySequenceIdlesAtItsStartingValue() {
        final fixture = openSequence([]);
        assertSample(lastSequence(fixture), 0.0, 0, Idle);
        assertEquals(0, simulateNextFrame(fixture.window));
    }

    function testTransitionIdsAcceptElementLikeScalarsAndNamedChannels() {
        assertTrue((('opacity' : TransitionId)).equals(ElementId.Name('opacity')));
        assertFalse(TransitionId.named('terms', 'fill').equals(TransitionId.named('terms', 'mark-opacity')));
        final fromInt:TransitionId = 7;
        assertTrue(fromInt.equals(ElementId.Integer(7)));
    }

    // tests: transition

    function openTransition(duration:Float) {
        return openWindow(_ -> new MotionTestView(duration));
    }

    function renderTransition(opened:{window:Window, view:gpui.Entity<MotionTestView>}, target:Float):Float {
        (opened.view : MotionTestView).target = target;
        refresh(opened.window);
        return lastFloat((opened.view : MotionTestView).samples);
    }

    static function lastFloat(values:Array<Float>):Float {
        return values[values.length - 1];
    }

    function testAZeroDurationTargetChangeIsImmediate() {
        final fixture = openTransition(0);
        assertEquals(1.0, renderTransition(fixture, 1.0));
    }

    function testAChangedTargetTransitionsOverTime() {
        final fixture = openTransition(0.1);
        assertEquals(0.0, renderTransition(fixture, 10.0));

        advanceClock(50);
        assertEquals(5.0, renderTransition(fixture, 10.0));
    }

    function testRequestedAnimationFramesResampleWithoutManualRefresh() {
        final fixture = openTransition(0.1);
        assertEquals(0.0, renderTransition(fixture, 10.0));

        advanceClock(50);
        assertEquals(1, simulateNextFrame(fixture.window));
        runUntilParked();

        assertEquals(5.0, lastFloat((fixture.view : MotionTestView).samples));
    }

    function testReversingUsesTheCurrentSampleAndShortensTheReturn() {
        final fixture = openTransition(0.1);
        assertEquals(0.0, renderTransition(fixture, 10.0));

        advanceClock(50);
        assertEquals(5.0, renderTransition(fixture, 0.0));
        advanceClock(25);
        assertEquals(2.5, renderTransition(fixture, 0.0));
    }

    function testDelayHoldsThePreviousValueBeforeInterpolation() {
        final opened = openWindow(_ -> new MotionDelayedView());
        final view:MotionDelayedView = opened.view;

        view.target = 10.0;
        refresh(opened.window);
        assertEquals(0.0, lastFloat(view.samples));

        advanceClock(50);
        refresh(opened.window);
        assertEquals(0.0, lastFloat(view.samples));

        advanceClock(50);
        refresh(opened.window);
        assertEquals(5.0, lastFloat(view.samples));
    }

    function testACompletedTransitionStopsRequestingFrames() {
        final fixture = openTransition(0.1);
        renderTransition(fixture, 1.0);
        assertEquals(1, simulateNextFrame(fixture.window));

        advanceClock(100);
        assertEquals(1.0, renderTransition(fixture, 1.0));
        simulateNextFrame(fixture.window);
        runUntilParked();
        assertEquals(0, simulateNextFrame(fixture.window));
    }

    function testReducedMotionAdoptsTheTargetWithoutRequestingAFrame() {
        app.setReduceMotion(true);
        final fixture = openTransition(0.1);
        assertEquals(1.0, renderTransition(fixture, 1.0));
        assertEquals(0, simulateNextFrame(fixture.window));
    }

    // tests: spring

    function openSpring(policy:Spring) {
        return openWindow(_ -> new MotionSpringView(policy));
    }

    function renderSpring(opened:{window:Window, view:gpui.Entity<MotionSpringView>}, target:Float):Float {
        (opened.view : MotionSpringView).target = target;
        refresh(opened.window);
        return lastFloat((opened.view : MotionSpringView).samples);
    }

    function advanceSpring(opened:{window:Window, view:gpui.Entity<MotionSpringView>}, millis:Float, target:Float):Float {
        advanceClock(millis);
        return renderSpring(opened, target);
    }

    function testASpringAdoptsItsFirstTargetImmediately() {
        final fixture = openSpring(new Spring(0.3));
        assertEquals(0.0, (fixture.view : MotionSpringView).samples[0]);
    }

    function testASpringTravelsTowardItsTargetOverTime() {
        final fixture = openSpring(new Spring(0.3));
        assertEquals(0.0, renderSpring(fixture, 1.0));

        final early = advanceSpring(fixture, 50, 1.0);
        final late = advanceSpring(fixture, 50, 1.0);
        assertTrue(0.0 < early && early < late && late < 1.0, 'expected monotonic approach, got $early then $late');
    }

    function testAReversedSpringKeepsItsMomentumBeforeTurningAround() {
        final fixture = openSpring(new Spring(0.3));
        renderSpring(fixture, 1.0);
        final reversedAt = advanceSpring(fixture, 100, 1.0);

        // Retarget mid-flight. A duration-based transition restarts its easing
        // here and moves away from 1.0 on the very next frame.
        assertEquals(reversedAt, renderSpring(fixture, 0.0));

        final next = advanceSpring(fixture, 16, 0.0);
        assertTrue(next > reversedAt, 'expected the spring to carry its velocity past $reversedAt, got $next');

        assertEquals(0.0, advanceSpring(fixture, 1000, 0.0));
    }

    function testABouncySpringOvershootsItsTarget() {
        final fixture = openSpring(new Spring(0.35).withDamping(0.7));
        renderSpring(fixture, 1.0);
        for (_ in 0...30) {
            advanceSpring(fixture, 16, 1.0);
        }

        var peak = Math.NEGATIVE_INFINITY;
        for (sample in (fixture.view : MotionSpringView).samples) {
            if (sample > peak) peak = sample;
        }
        assertTrue(peak > 1.0, 'expected an overshoot past 1.0, got $peak');
    }

    function testASettledSpringStopsRequestingFrames() {
        final fixture = openSpring(new Spring(0.3));
        renderSpring(fixture, 1.0);
        assertEquals(1, simulateNextFrame(fixture.window));

        assertEquals(1.0, advanceSpring(fixture, 2000, 1.0));
        simulateNextFrame(fixture.window);
        runUntilParked();
        assertEquals(0, simulateNextFrame(fixture.window));
    }

    function testASpringThatIsNotTravellingAdoptsItsTargetOnTheSpot() {
        final travelling = new Spring(0.3);
        final fixture = openSpring(travelling.withTravel(false));

        assertEquals(1.0, renderSpring(fixture, 1.0));
        assertEquals(0, simulateNextFrame(fixture.window));
        assertEquals(5.0, advanceSpring(fixture, 100, 5.0));

        // Travel resumes from the value the suspension left behind. A spring
        // that had kept the state it held beforehand would jump back to it here.
        (fixture.view : MotionSpringView).policy = travelling;
        assertEquals(5.0, renderSpring(fixture, 6.0));
        final next = advanceSpring(fixture, 50, 6.0);
        assertTrue(5.0 < next && next < 6.0, 'expected travel to resume from 5.0, got $next');
    }

    function testAZeroResponseSpringResolvesInsteadOfDividingByItsPeriod() {
        final fixture = openSpring(new Spring(0));
        assertEquals(1.0, renderSpring(fixture, 1.0));
        assertEquals(0, simulateNextFrame(fixture.window));
    }

    function testSpringRejectsNonFiniteOrNegativePhysicalParameters() {
        final spring = new Spring(0.3);

        assertEquals(InvalidDamping, springError(() -> spring.tryWithDamping(Math.NaN)));
        assertEquals(InvalidDamping, springError(() -> spring.tryWithDamping(-0.1)));
        assertEquals(InvalidEpsilon, springError(() -> spring.tryWithEpsilon(Math.POSITIVE_INFINITY)));
        assertEquals(InvalidEpsilon, springError(() -> spring.tryWithEpsilon(-0.1)));
    }

    function testSpringReportsItsUnitSpecificSettlingTolerance() {
        final normalized = new Spring(0.18);
        final pixels = new Spring(0.18).withEpsilon(0.1);

        assertTrue(normalized.epsilon() < 0.01);
        assertEquals(f32(0.1), pixels.epsilon());
    }

    function testReducedMotionAdoptsTheSpringTargetWithoutRequestingAFrame() {
        app.setReduceMotion(true);
        final fixture = openSpring(new Spring(0.35).withDamping(0.7));
        assertEquals(1.0, renderSpring(fixture, 1.0));
        assertEquals(0, simulateNextFrame(fixture.window));
    }

    // Helpers

    /** Rust's `f32::EPSILON`. */
    static final F32_EPSILON:Float = 1.1920929e-7;

    static function easingError(f:() -> Easing):Null<EasingError> {
        try {
            f();
        }
        catch (e:EasingError) {
            return e;
        }
        return null;
    }

    static function keyframeError(f:() -> Keyframes<Float>):Null<KeyframeError> {
        try {
            f();
        }
        catch (e:KeyframeError) {
            return e;
        }
        return null;
    }

    static function springError(f:() -> Spring):Null<SpringError> {
        try {
            f();
        }
        catch (e:SpringError) {
            return e;
        }
        return null;
    }

}

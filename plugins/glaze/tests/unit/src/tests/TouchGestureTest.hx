// Ported from gpui-pre 0.3.10: src/gestures.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.Axis;
import gpui.GestureTuning;
import gpui.OngoingScroll;
import gpui.Point;
import gpui.ScrollEvent;
import gpui.ScrollPhysics;
import gpui.ScrollPhysics.FrictionSplineModel;
import gpui.ScrollSource;
import gpui.TouchEvent;
import gpui.TouchGestureRecognizer;
import gpui.TouchGestureRecognizer.RecognizedTouchGesture;
import gpui.TouchGestureRecognizer.VelocityTracker;
import gpui.TouchId;
import gpui.TouchPhase;
import testing.TestCase;

using gpui.ScrollPhysics.ScrollPhysicsTools;

/**
 * Tests of `gestures.rs`: the dominant axis lock of `OngoingScroll`, the
 * touch gesture recognizer (taps, pans, momentum, long press and touch drag
 * offers), the fling physics and the velocity tracker.
 *
 * Times are seconds from 0 (Rust `Instant::now()` plus durations), passed to
 * the `*_at` variants as in the originals.
 */
@:access(gpui.OngoingScroll)
@:access(gpui.TouchGestureRecognizer)
class TouchGestureTest extends TestCase {

    static inline function ms(value:Float):Float {
        return value / 1000.;
    }

    static function touchEvent(id:Int, phase:TouchPhase, x:Float, y:Float):TouchEvent {
        return new TouchEvent(id, phase, new Point(x, y));
    }

    static function pixelDelta(scroll:ScrollEvent):Point {
        return scroll.delta.pixelDelta(16);
    }

    function assertPoint(x:Float, y:Float, point:Point, ?message:String, ?pos:haxe.PosInfos):Void {
        assertFloatEquals(x, point.x, 0.00001, message, pos);
        assertFloatEquals(y, point.y, 0.00001, message, pos);
    }

    /** The single scroll of `recognized`, failing otherwise. */
    function singleScroll(recognized:Array<RecognizedTouchGesture>, ?pos:haxe.PosInfos):ScrollEvent {
        assertEquals(1, recognized.length, 'expected one gesture, got $recognized', pos);
        return switch recognized[0] {
            case Scroll(event): event;
            case other:
                fail('expected scroll, got $other', pos);
                null;
        }
    }

    static function newRecognizer():TouchGestureRecognizer {
        return new TouchGestureRecognizer(GestureTuning.defaults());
    }

/// OngoingScroll

    function testOngoingScrollLocksToDominantAxis() {
        final now = 0.;
        final ongoingScroll = new OngoingScroll();
        final horizontalDelta = ongoingScroll.filter(new Point(10, 2), Started, now);
        assertEquals(Horizontal, ongoingScroll.axis);
        assertPoint(10, 0, horizontalDelta);

        final continuedDelta = ongoingScroll.filter(new Point(3, 2), Moved, now + ms(1));
        assertEquals(Horizontal, ongoingScroll.axis);
        assertPoint(3, 0, continuedDelta);
    }

    function testOngoingScrollUnlocksWhenDirectionChanges() {
        final now = 0.;
        final ongoingScroll = new OngoingScroll();
        ongoingScroll.filter(new Point(10, 2), Started, now);
        final verticalDelta = ongoingScroll.filter(new Point(2, 10), Moved, now + ms(1));
        assertNull(ongoingScroll.axis);
        assertPoint(2, 10, verticalDelta);
    }

    function testOngoingScrollStartsNewGestureAtTimeoutBoundary() {
        final now = 0.;
        final ongoingScroll = new OngoingScroll();
        ongoingScroll.filter(new Point(10, 2), Moved, now);
        final verticalDelta = ongoingScroll.filter(new Point(2, 10), Moved, now + OngoingScroll.SCROLL_EVENT_SEPARATION);
        assertEquals(Vertical, ongoingScroll.axis);
        assertPoint(0, 10, verticalDelta);
    }

    function testOngoingScrollIgnoresZeroDeltaAndResetsWhenEnded() {
        final now = 0.;
        final ongoingScroll = new OngoingScroll();
        ongoingScroll.filter(new Point(10, 2), Started, now);
        ongoingScroll.filter(new Point(0, 0), Ended, now + ms(1));
        assertNull(ongoingScroll.axis);
        final verticalDelta = ongoingScroll.filter(new Point(2, 3), Moved, now + ms(2));
        assertEquals(Vertical, ongoingScroll.axis);
        assertPoint(0, 3, verticalDelta);
    }

    function testOngoingScrollIgnoresZeroDeltaMovement() {
        final now = 0.;
        final ongoingScroll = new OngoingScroll();
        ongoingScroll.filter(new Point(10, 2), Started, now);
        ongoingScroll.filter(new Point(0, 0), Moved, now + OngoingScroll.SCROLL_EVENT_SEPARATION);
        final verticalDelta = ongoingScroll.filter(new Point(2, 10), Moved, now + OngoingScroll.SCROLL_EVENT_SEPARATION);
        assertEquals(Vertical, ongoingScroll.axis);
        assertPoint(0, 10, verticalDelta);
    }

    function testOngoingScrollSupportsMovedOnlyPlatforms() {
        final ongoingScroll = new OngoingScroll();
        final horizontalDelta = ongoingScroll.filter(new Point(10, 2), Moved, 0.);
        assertEquals(Horizontal, ongoingScroll.axis);
        assertPoint(10, 0, horizontalDelta);
    }

/// Taps and pans

    function testTouchWithinSlopResolvesToTap() {
        final recognizer = newRecognizer();
        final now = 0.;
        final touch = 1;

        assertEquals(0, recognizer.handleEvent(touchEvent(touch, Started, 10, 10), now).length);
        assertEquals(0, recognizer.handleEvent(touchEvent(touch, Moved, 12, 11), now + ms(20)).length);

        final recognized = recognizer.handleEvent(touchEvent(touch, Ended, 12, 11), now + ms(60));
        assertEquals(1, recognized.length);
        switch recognized[0] {
            case Tap(down, up):
                assertEquals(1, down.clickCount);
                assertPoint(12, 11, down.position);
                assertEquals(1, up.clickCount);
            case other:
                fail('expected tap, got $other');
        }
    }

    function tapCount(recognized:Array<RecognizedTouchGesture>):Int {
        assertEquals(1, recognized.length);
        return switch recognized[0] {
            case Tap(down, _): down.clickCount;
            case other:
                fail('expected tap, got $other');
                -1;
        }
    }

    function testConsecutiveTapsAccumulateTapCount() {
        final recognizer = newRecognizer();
        final now = 0.;

        recognizer.handleEvent(touchEvent(1, Started, 10, 10), now);
        recognizer.handleEvent(touchEvent(1, Ended, 10, 10), now + ms(40));

        final secondDown = now + ms(200);
        recognizer.handleEvent(touchEvent(2, Started, 14, 10), secondDown);
        assertEquals(2, tapCount(recognizer.handleEvent(touchEvent(2, Ended, 14, 10), secondDown + ms(40))));

        final lateDown = secondDown + 2.;
        recognizer.handleEvent(touchEvent(3, Started, 14, 10), lateDown);
        assertEquals(1, tapCount(recognizer.handleEvent(touchEvent(3, Ended, 14, 10), lateDown + ms(40))));
    }

    function testTouchBeyondSlopResolvesToPan() {
        final recognizer = newRecognizer();
        final now = 0.;
        final touch = 1;

        recognizer.handleEvent(touchEvent(touch, Started, 100, 100), now);

        var scroll = singleScroll(recognizer.handleEvent(touchEvent(touch, Moved, 100, 120), now + ms(16)));
        assertEquals(Started, scroll.touchPhase);
        assertEquals(ScrollSource.Touch, scroll.source);
        assertPoint(100, 100, scroll.position);
        assertPoint(0, 20, pixelDelta(scroll));

        scroll = singleScroll(recognizer.handleEvent(touchEvent(touch, Moved, 100, 135), now + ms(32)));
        assertEquals(Moved, scroll.touchPhase);
        assertPoint(100, 100, scroll.position);
        assertPoint(0, 15, pixelDelta(scroll));

        scroll = singleScroll(recognizer.handleEvent(touchEvent(touch, Ended, 100, 135), now + ms(48)));
        assertEquals(Ended, scroll.touchPhase);
    }

    function testTouchPanStaysLockedToItsInitialDominantAxis() {
        final recognizer = newRecognizer();
        final now = 0.;
        final touch = 1;

        recognizer.handleEvent(touchEvent(touch, Started, 100, 100), now);
        var scroll = singleScroll(recognizer.handleEvent(touchEvent(touch, Moved, 104, 120), now + ms(16)));
        assertPoint(0, 20, pixelDelta(scroll));
        scroll = singleScroll(recognizer.handleEvent(touchEvent(touch, Moved, 134, 125), now + ms(32)));
        assertPoint(0, 5, pixelDelta(scroll));
    }

    function testTouchPanLocksToHorizontalAxis() {
        final recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 100, 100), now);
        final scroll = singleScroll(recognizer.handleEvent(touchEvent(1, Moved, 120, 104), now + ms(16)));
        assertPoint(20, 0, pixelDelta(scroll));
    }

    function testPredictedPositionsLeadThePanButTotalsConvergeOnRelease() {
        final recognizer = newRecognizer();
        final now = 0.;
        final touch = 1;

        recognizer.handleEvent(touchEvent(touch, Started, 100, 100), now);

        // The first pan step scrolls to the predicted position, not the raw one.
        var moved = touchEvent(touch, Moved, 100, 120);
        moved.predictedPosition = new Point(106, 128);
        var scroll = singleScroll(recognizer.handleEvent(moved, now + ms(16)));
        assertPoint(0, 28, pixelDelta(scroll));

        // The next step is measured from where the previous prediction left
        // the content, so an overshoot is paid back here.
        moved = touchEvent(touch, Moved, 100, 130);
        moved.predictedPosition = new Point(104, 134);
        scroll = singleScroll(recognizer.handleEvent(moved, now + ms(32)));
        assertPoint(0, 6, pixelDelta(scroll));

        // A release without a fling targets the raw position.
        scroll = singleScroll(recognizer.handleEvent(touchEvent(touch, Ended, 100, 130), now + ms(120)));
        assertEquals(Ended, scroll.touchPhase);
        assertFalse(recognizer.hasMomentum());
        assertPoint(0, -4, pixelDelta(scroll));
    }

    function testPredictedPositionsDoNotEmitFalseReversals() {
        final recognizer = newRecognizer();
        final now = 0.;
        final touch = 1;

        recognizer.handleEvent(touchEvent(touch, Started, 100, 100), now);

        final steps:Array<{y:Float, predicted:Float, time:Float, expected:Float}> = [
            {y: 120, predicted: 130, time: 16, expected: 30},
            {y: 125, predicted: 127, time: 32, expected: 0},
            {y: 125, predicted: 126, time: 40, expected: 0},
            {y: 132, predicted: 136, time: 48, expected: 6},
            {y: 124, predicted: 140, time: 64, expected: -12},
        ];
        for (step in steps) {
            final moved = touchEvent(touch, Moved, 100, step.y);
            moved.predictedPosition = new Point(100, step.predicted);
            final scroll = singleScroll(recognizer.handleEvent(moved, now + ms(step.time)));
            assertPoint(0, step.expected, pixelDelta(scroll), 'at ${step.time} ms');
        }
    }

    function testPredictedOvershootFoldsIntoTheFlingWithoutScrollingBackwards() {
        final now = 0.;
        var totalWithPrediction = 0.;
        var totalWithoutPrediction = 0.;
        for (usePrediction in [true, false]) {
            final recognizer = newRecognizer();
            var total = 0.;
            function drain(recognized:Array<RecognizedTouchGesture>, upwardOnly:Bool) {
                for (gesture in recognized) {
                    switch gesture {
                        case Scroll(scroll):
                            final delta = pixelDelta(scroll).y;
                            if (upwardOnly) {
                                assertTrue(delta <= 0, 'content moved backwards by $delta during an upward gesture');
                            }
                            total += delta;
                        case other:
                            fail('expected scroll, got $other');
                    }
                }
            }

            recognizer.handleEvent(touchEvent(1, Started, 100, 500), now);
            for (step in 1...6) {
                final rawY = 500. - step * 40.;
                final moved = touchEvent(1, Moved, 100, rawY);
                if (usePrediction) {
                    moved.predictedPosition = new Point(100, rawY - 25);
                }
                drain(recognizer.handleEvent(moved, now + ms(step * 16)), usePrediction);
            }
            drain(recognizer.handleEvent(touchEvent(1, Ended, 100, 300), now + ms(90)), usePrediction);
            assertTrue(recognizer.hasMomentum());
            var tick = now + ms(91);
            while (recognizer.hasMomentum()) {
                final gesture = recognizer.tickMomentum(tick);
                if (gesture != null) drain([gesture], usePrediction);
                tick += ms(16);
            }

            if (usePrediction) {
                totalWithPrediction = total;
            }
            else {
                totalWithoutPrediction = total;
            }
        }
        assertTrue(Math.abs(totalWithPrediction - totalWithoutPrediction) < 0.01, 'totals diverged: $totalWithPrediction vs $totalWithoutPrediction');
    }

/// Momentum

    function testFastReleaseStartsMomentumThatDecaysToAStop() {
        final recognizer = newRecognizer();
        final now = 0.;
        final touch = 1;

        recognizer.handleEvent(touchEvent(touch, Started, 100, 300), now);
        for (step in 1...6) {
            recognizer.handleEvent(touchEvent(touch, Moved, 100, 300 - step * 20), now + ms(step * 16));
        }
        recognizer.handleEvent(touchEvent(touch, Ended, 100, 200), now + ms(6 * 16));
        assertTrue(recognizer.hasMomentum());

        final tick = now + ms(6 * 16 + 16);
        final gesture = recognizer.tickMomentum(tick);
        assertNotNull(gesture);
        final scroll = singleScroll([gesture]);
        assertEquals(Moved, scroll.touchPhase);
        assertPoint(100, 300, scroll.position);
        final delta = pixelDelta(scroll);
        assertTrue(delta.y < 0, 'momentum should continue upward, got $delta');
        // The least-squares fit may leave float residue on the motionless axis.
        assertTrue(Math.abs(delta.x) < 0.001, 'expected no x motion, got $delta');

        var lastPhase:TouchPhase = Moved;
        var ticks = 0;
        var time = tick;
        while (recognizer.hasMomentum()) {
            time += ms(16);
            ticks++;
            assertTrue(ticks < 1000, 'momentum never stopped');
            if (ticks >= 1000) break;
            final gesture = recognizer.tickMomentum(time);
            if (gesture != null) {
                switch gesture {
                    case Scroll(scroll): lastPhase = scroll.touchPhase;
                    case _:
                }
            }
        }
        assertEquals(Ended, lastPhase);
        assertNull(recognizer.tickMomentum(time));
    }

    function testDiagonalReleaseFlingsOnlyOnLockedAxis() {
        final recognizer = newRecognizer();
        final now = 0.;
        final touch = 1;

        recognizer.handleEvent(touchEvent(touch, Started, 100, 300), now);
        for (step in 1...6) {
            final scroll = singleScroll(recognizer.handleEvent(touchEvent(touch, Moved, 100 + step * 3, 300 - step * 20), now + ms(step * 16)));
            assertEquals(0., pixelDelta(scroll).x);
        }
        recognizer.handleEvent(touchEvent(touch, Ended, 115, 200), now + ms(6 * 16));
        assertTrue(recognizer.hasMomentum());

        var time = now + ms(6 * 16);
        while (recognizer.hasMomentum()) {
            time += ms(16);
            final gesture = recognizer.tickMomentum(time);
            if (gesture != null) {
                final delta = pixelDelta(singleScroll([gesture]));
                assertEquals(0., delta.x);
                assertTrue(delta.y <= 0);
            }
        }
    }

    function testSlowReleaseDoesNotStartMomentum() {
        final recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 100, 300), now);
        recognizer.handleEvent(touchEvent(1, Moved, 100, 280), now + ms(16));
        recognizer.handleEvent(touchEvent(1, Moved, 100, 279), now + ms(500));
        recognizer.handleEvent(touchEvent(1, Ended, 100, 279), now + ms(600));
        assertFalse(recognizer.hasMomentum());
    }

    function flingUpward(recognizer:TouchGestureRecognizer, now:Float):Void {
        recognizer.handleEvent(touchEvent(1, Started, 100, 300), now);
        for (step in 1...4) {
            recognizer.handleEvent(touchEvent(1, Moved, 100, 300 - step * 33), now + ms(step * 16));
        }
        recognizer.handleEvent(touchEvent(1, Ended, 100, 200), now + ms(64));
        assertTrue(recognizer.hasMomentum());
    }

    function testNewTouchInterruptsMomentum() {
        final recognizer = newRecognizer();
        final now = 0.;
        flingUpward(recognizer, now);

        final recognized = recognizer.handleEvent(touchEvent(2, Started, 100, 200), now + ms(200));
        assertFalse(recognizer.hasMomentum());
        assertEquals(2, recognized.length);
        final closing = singleScroll([recognized[0]]);
        final opening = singleScroll([recognized[1]]);
        assertEquals(Ended, closing.touchPhase);
        assertTrue(pixelDelta(closing).isZero());
        assertEquals(Started, opening.touchPhase);
        assertTrue(pixelDelta(opening).isZero());
    }

    function testCatchingAFlingPansImmediatelyAndNeverTaps() {
        final recognizer = newRecognizer();
        final now = 0.;
        flingUpward(recognizer, now);

        recognizer.handleEvent(touchEvent(2, Started, 100, 200), now + ms(200));

        // A movement well within the slop scrolls immediately.
        var scroll = singleScroll(recognizer.handleEvent(touchEvent(2, Moved, 100, 197), now + ms(216)));
        assertEquals(Moved, scroll.touchPhase);
        assertPoint(0, -3, pixelDelta(scroll));

        // Releasing the catch is not a tap.
        scroll = singleScroll(recognizer.handleEvent(touchEvent(2, Ended, 100, 197), now + ms(232)));
        assertEquals(Ended, scroll.touchPhase);
    }

    function testCatchingAFlingTakesTheAxisFromTheNewTouch() {
        final recognizer = newRecognizer();
        final now = 0.;

        // A fast horizontal pan flings sideways.
        recognizer.handleEvent(touchEvent(1, Started, 300, 300), now);
        for (step in 1...4) {
            recognizer.handleEvent(touchEvent(1, Moved, 300 - step * 33, 300), now + ms(step * 16));
        }
        recognizer.handleEvent(touchEvent(1, Ended, 200, 300), now + ms(64));
        assertTrue(recognizer.hasMomentum());

        // A finger that catches it and moves up scrolls up.
        recognizer.handleEvent(touchEvent(2, Started, 200, 300), now + ms(200));
        var scroll = singleScroll(recognizer.handleEvent(touchEvent(2, Moved, 201, 280), now + ms(216)));
        assertEquals(Moved, scroll.touchPhase);
        assertPoint(0, -20, pixelDelta(scroll));

        // And stays on that axis for the rest of the pan.
        scroll = singleScroll(recognizer.handleEvent(touchEvent(2, Moved, 205, 260), now + ms(232)));
        assertPoint(0, -20, pixelDelta(scroll));
    }

    function testCancelledPanEmitsCancelledScrollAndNoTap() {
        var recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 100, 100), now);
        recognizer.handleEvent(touchEvent(1, Moved, 100, 150), now + ms(16));
        final scroll = singleScroll(recognizer.handleEvent(touchEvent(1, Cancelled, 100, 150), now + ms(32)));
        assertEquals(Cancelled, scroll.touchPhase);
        assertFalse(recognizer.hasMomentum());

        recognizer = newRecognizer();
        recognizer.handleEvent(touchEvent(1, Started, 100, 100), now);
        assertEquals(0, recognizer.handleEvent(touchEvent(1, Cancelled, 100, 102), now + ms(16)).length, 'cancelled tap must not click');
    }

    function testConcurrentTouchesAreIgnoredWhileOneIsActive() {
        final recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 100, 100), now);
        assertEquals(0, recognizer.handleEvent(touchEvent(2, Started, 200, 200), now + ms(8)).length);
        assertEquals(0, recognizer.handleEvent(touchEvent(2, Moved, 200, 300), now + ms(16)).length);
        assertEquals(0, recognizer.handleEvent(touchEvent(2, Ended, 200, 300), now + ms(24)).length);

        // The first touch still resolves normally.
        final scroll = singleScroll(recognizer.handleEvent(touchEvent(1, Moved, 100, 150), now + ms(32)));
        assertEquals(Started, scroll.touchPhase);
    }

/// Fling physics

    function testSplinePositionTableMatchesTheBezierCurve() {
        final samples = FrictionSplineModel.splinePositionSamples();
        // AOSP's initializer solves sample 0 numerically like every other
        // sample, so it lands within solver tolerance of zero, not at zero.
        assertTrue(Math.abs(samples[0]) < 1e-4);
        assertEquals(1., samples[100]);
        for (i in 0...100) {
            assertTrue(samples[i] < samples[i + 1], 'table must be strictly increasing');
        }
        for (i in 0...100) {
            final storedPosition = samples[i];
            final alpha = i / 100;
            var lower = 0.;
            var upper = 1.;
            for (_ in 0...50) {
                final middle = (lower + upper) / 2.;
                if (FrictionSplineModel.bezierTimeAndPosition(middle).time > alpha) {
                    upper = middle;
                }
                else {
                    lower = middle;
                }
            }
            final result = FrictionSplineModel.bezierTimeAndPosition((lower + upper) / 2.);
            assertTrue(Math.abs(result.time - alpha) < 1e-4, 'sample $i: time ${result.time} != $alpha');
            assertTrue(Math.abs(result.position - storedPosition) < 1e-3, 'sample $i: position ${result.position} != stored $storedPosition');
        }
    }

    function testFlingCurvesAreSaneForBothPhysics() {
        for (physics in [ScrollPhysicsTools.ios(), ScrollPhysicsTools.android()]) {
            final slow = physics.flingDuration(500.);
            final fast = physics.flingDuration(4000.);
            assertTrue(slow > 0, '$physics');
            assertTrue(fast > slow, 'faster flings must coast longer: $physics');

            final halfway = physics.flingDistance(4000., fast / 2);
            final total = physics.flingDistance(4000., fast);
            assertTrue(halfway > 0 && halfway < total, '$physics');
            assertTrue(physics.flingDistance(4000., fast * 2) == total, 'distance must not grow past the fling duration: $physics');
            assertTrue(physics.flingDistance(4000., fast) > physics.flingDistance(500., slow), 'faster flings must travel further: $physics');
        }
    }

    function testMomentumIsFrameRateIndependent() {
        // The same fling ticked at 60Hz and as one huge stalled frame must
        // cover identical ground.
        function totalDistanceWithTickLength(tick:Float):Float {
            final recognizer = new TouchGestureRecognizer(new GestureTuning(8., 0.4, 16., 0.5, ScrollPhysicsTools.android(), 50.));
            final now = 0.;
            recognizer.handleEvent(touchEvent(1, Started, 100, 500), now);
            for (step in 1...4) {
                recognizer.handleEvent(touchEvent(1, Moved, 100, 500 - step * 40), now + ms(step * 16));
            }
            recognizer.handleEvent(touchEvent(1, Ended, 100, 380), now + ms(64));
            assertTrue(recognizer.hasMomentum());

            var total = 0.;
            var time = now + ms(64);
            var guard = 0;
            while (recognizer.hasMomentum()) {
                time += tick;
                guard++;
                if (guard >= 10000) {
                    fail('momentum never stopped');
                    break;
                }
                final gesture = recognizer.tickMomentum(time);
                if (gesture != null) total += pixelDelta(singleScroll([gesture])).y;
            }
            return total;
        }

        final smooth = totalDistanceWithTickLength(ms(16));
        final stalled = totalDistanceWithTickLength(10.);
        assertTrue(Math.abs(smooth - stalled) < 0.01, 'expected identical fling distance, got $smooth vs $stalled');
    }

    function testFlickVelocityReflectsReleaseSpeedNotWindowAverage() {
        // A uniformly accelerating flick: the speed at the newest sample is
        // twice the window average. The estimator must report the former.
        final velocityTracker = new VelocityTracker();
        for (step in 0...7) {
            final t = step * 0.016;
            velocityTracker.push(ms(step * 16), new Point(0, 1000 * t * t));
        }
        final velocity = velocityTracker.velocity();
        final releaseSpeed = 2. * 1000. * 0.096;
        assertTrue(Math.abs(velocity.y - releaseSpeed) < 1., 'expected about $releaseSpeed px/s at release, got ${velocity.y} px/s');
        assertEquals(0., velocity.x);
    }

    function testSamplesBeforeAPauseDoNotContributeVelocity() {
        final velocityTracker = new VelocityTracker();
        velocityTracker.push(0, new Point(0, 0));
        velocityTracker.push(ms(16), new Point(0, 50));
        velocityTracker.push(ms(80), new Point(0, 52));
        velocityTracker.push(ms(96), new Point(0, 54));
        final velocity = velocityTracker.velocity();
        assertTrue(velocity.y < 200., 'pre-pause motion leaked into the estimate: ${velocity.y} px/s');
    }

/// Touch drag and long press offers

    function testClaimedTouchDragEmitsPhasedStreamWithoutPanOrTap() {
        final recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 10, 20), now);
        switch recognizer.offerTouchDrag(1) {
            case TouchDrag(started):
                assertEquals(Started, started.phase);
                assertPoint(10, 20, started.startPosition);
            case other:
                fail('expected touch drag, got $other');
        }
        recognizer.resolveTouchDrag(true);

        var recognized = recognizer.handleEvent(touchEvent(1, Moved, 40, 50), now + ms(10));
        assertEquals(1, recognized.length);
        switch recognized[0] {
            case TouchDrag(moved):
                assertEquals(Moved, moved.phase);
                assertPoint(40, 50, moved.position);
            case other:
                fail('expected moved touch drag, got $other');
        }

        recognized = recognizer.handleEvent(touchEvent(1, Ended, 45, 55), now + ms(20));
        assertEquals(1, recognized.length);
        switch recognized[0] {
            case TouchDrag(ended):
                assertEquals(Ended, ended.phase);
                assertPoint(45, 55, ended.position);
            case other:
                fail('expected ended touch drag, got $other');
        }
    }

    function testUnclaimedTouchDragRemainsAPanCandidate() {
        final recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 0, 0), now);
        assertNotNull(recognizer.offerTouchDrag(1));
        recognizer.resolveTouchDrag(false);
        final scroll = singleScroll(recognizer.handleEvent(touchEvent(1, Moved, 20, 0), now + ms(10)));
        assertEquals(Started, scroll.touchPhase);
    }

    function testClaimedLongPressEmitsPhasedStreamWithoutTap() {
        final recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 10, 20), now);
        switch recognizer.offerLongPress(1) {
            case LongPress(started):
                assertEquals(Started, started.phase);
                assertPoint(10, 20, started.startPosition);
            case other:
                fail('expected long press, got $other');
        }
        recognizer.resolveLongPress(true);

        var recognized = recognizer.handleEvent(touchEvent(1, Moved, 12, 21), now + ms(510));
        assertEquals(1, recognized.length);
        switch recognized[0] {
            case LongPress(moved): assertEquals(Moved, moved.phase);
            case other: fail('expected moved long press, got $other');
        }

        recognized = recognizer.handleEvent(touchEvent(1, Ended, 12, 21), now + ms(520));
        assertEquals(1, recognized.length);
        switch recognized[0] {
            case LongPress(ended): assertEquals(Ended, ended.phase);
            case other: fail('expected ended long press, got $other');
        }
    }

    function testUnclaimedLongPressRemainsATapCandidate() {
        final recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 10, 20), now);
        assertNotNull(recognizer.offerLongPress(1));
        recognizer.resolveLongPress(false);
        final ended = recognizer.handleEvent(touchEvent(1, Ended, 10, 20), now + ms(510));
        assertEquals(1, ended.length);
        assertTrue(ended[0].match(Tap(_, _)));
    }

    function testUnclaimedLongPressCanStillBecomeAPan() {
        final recognizer = newRecognizer();
        final now = 0.;
        recognizer.handleEvent(touchEvent(1, Started, 0, 0), now);
        assertNotNull(recognizer.offerLongPress(1));
        recognizer.resolveLongPress(false);
        final scroll = singleScroll(recognizer.handleEvent(touchEvent(1, Moved, 20, 0), now + ms(510)));
        assertEquals(Started, scroll.touchPhase);
    }

    function testLongPressOfferIsOneShotAndSpecificToPendingTouch() {
        final recognizer = newRecognizer();
        recognizer.handleEvent(touchEvent(1, Started, 0, 0), 0);
        assertEquals(0, recognizer.handleEvent(touchEvent(2, Moved, 20, 0), 0).length);
        assertNull(recognizer.offerLongPress(2));
        assertNotNull(recognizer.offerLongPress(1));
        assertNull(recognizer.offerLongPress(1));
    }

    function testLongPressCannotBeOfferedAfterPendingTouchResolves() {
        for (phase in [TouchPhase.Ended, TouchPhase.Cancelled, TouchPhase.Moved]) {
            final recognizer = newRecognizer();
            final now = 0.;
            recognizer.handleEvent(touchEvent(1, Started, 0, 0), now);
            final position = phase == Moved ? 20. : 0.;
            recognizer.handleEvent(touchEvent(1, phase, position, 0), now + ms(10));
            assertNull(recognizer.offerLongPress(1));
        }
    }

    function testClaimedLongPressEmitsCancelledForItsTouchOnly() {
        final recognizer = newRecognizer();
        recognizer.handleEvent(touchEvent(1, Started, 4, 5), 0);
        assertNotNull(recognizer.offerLongPress(1));
        recognizer.resolveLongPress(true);

        assertEquals(0, recognizer.handleEvent(touchEvent(2, Cancelled, 9, 9), 0).length);
        final cancelled = recognizer.handleEvent(touchEvent(1, Cancelled, 6, 7), 0);
        assertEquals(1, cancelled.length);
        switch cancelled[0] {
            case LongPress(event):
                assertEquals(Cancelled, event.phase);
                assertPoint(4, 5, event.startPosition);
                assertPoint(6, 7, event.position);
            case other:
                fail('expected cancelled long press, got $other');
        }
    }

    function testUnrelatedTouchCannotEndOrCancelPendingTouch() {
        for (phase in [TouchPhase.Ended, TouchPhase.Cancelled]) {
            final recognizer = newRecognizer();
            recognizer.handleEvent(touchEvent(1, Started, 4, 5), 0);
            assertEquals(0, recognizer.handleEvent(touchEvent(2, phase, 9, 9), 0).length);
            assertNotNull(recognizer.offerLongPress(1));
        }
    }

    function testCompletedTouchIdCannotClaimReplacementTouch() {
        final recognizer = newRecognizer();
        recognizer.handleEvent(touchEvent(1, Started, 0, 0), 0);
        recognizer.handleEvent(touchEvent(1, Cancelled, 0, 0), 0);
        recognizer.handleEvent(touchEvent(2, Started, 5, 5), 0);
        assertNull(recognizer.offerLongPress(1));
        assertNotNull(recognizer.offerLongPress(2));
    }

}

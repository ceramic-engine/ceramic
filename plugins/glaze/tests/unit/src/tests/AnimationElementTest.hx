// Ported from gpui-pre 0.3.10: src/elements/animation.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.Animation;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.SpringAnimation;
import gpui.SpringConfig;
import gpui.SpringPlayback;
import gpui.TestDispatcher;
import gpui.Window;
import testing.InteractionScript;
import testing.TestCase;

import gpui.Prelude.*;

class SpringAnimationTestView extends Model implements Render {

    public var target:Float = 0;

    public var initial:Null<Float> = null;

    public var playback:SpringPlayback = Running;

    public final renderedValues:Array<Float>;

    public function new(target:Float, initial:Null<Float>, playback:SpringPlayback, renderedValues:Array<Float>) {
        super();
        this.target = target;
        this.initial = initial;
        this.playback = playback;
        this.renderedValues = renderedValues;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        var animation = new SpringAnimation<Float>(new SpringConfig(100.0, 2.0, 1.0)).toValue(target).withEpsilon(0.01).withPlayback(playback);
        if (initial != null) {
            animation = animation.fromValue(initial);
        }
        return div().withSpring('spring-animation', animation, (element, value) -> {
            renderedValues.push(value);
            return element.left(px(value));
        });
    }

}

class SyncedAnimationTestView extends Model implements Render {

    public var showSecond:Bool = false;

    public final firstDeltas:Array<Float>;

    public final secondDeltas:Array<Float>;

    public function new(firstDeltas:Array<Float>, secondDeltas:Array<Float>) {
        super();
        this.firstDeltas = firstDeltas;
        this.secondDeltas = secondDeltas;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        function recordDeltas(deltas:Array<Float>) {
            return (element, delta) -> {
                deltas.push(delta);
                return element;
            };
        }
        return div().sizeFull()
            .child(div().withAnimation('first-synced-animation', new Animation(1).repeatSynced(), recordDeltas(firstDeltas)))
            .when(showSecond, d -> d.child(div().withAnimation('second-synced-animation', new Animation(1).repeatSynced(), recordDeltas(secondDeltas))));
    }

}

class AnimationTestView extends Model implements Render {

    public final renderedDeltas:Array<Float>;

    public final maxFps:Null<Float>;

    public function new(renderedDeltas:Array<Float>, maxFps:Null<Float>) {
        super();
        this.renderedDeltas = renderedDeltas;
        this.maxFps = maxFps;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        // The throttled variant syncs to the shared clock so the deltas
        // follow the test scheduler's clock rather than wall time.
        var animation = new Animation(1);
        if (maxFps != null) {
            animation = animation.repeatSynced().withMaxFps(maxFps);
        }
        else {
            animation = animation.repeat();
        }
        return div().sizeFull().child(div().withAnimation('repeating-animation', animation, (element, delta) -> {
            renderedDeltas.push(delta);
            return element;
        }));
    }

}

/**
 * Tests of the animation elements (`withAnimation`, `withSpring`), ported from
 * GPUI. Like GPUI's `TestAppContext`, the app draws dirty windows when it
 * flushes its effects, and `simulateNextFrame` runs the next frame callbacks.
 */
class AnimationElementTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = InteractionScript.testApp(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (window in windows) window.destroy();
        windows = [];
        app.onEffectsFlushed = null;
        ceramic.App.app.flushImmediate();
    }

    function openWindow<V:Model & Render>(build:() -> V):{window:Window, view:Entity<V>} {
        var view:Entity<V> = null;
        var window:Window = null;
        app.update(cx -> {
            window = Window.open(cx, {width: 100, height: 100, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                view = cx.newEntity(_ -> build());
                return view;
            });
        });
        windows.push(window);
        runUntilParked();
        return {window: window, view: view};
    }

    function runUntilParked():Void {
        dispatcher.runUntilParked();
    }

    function advanceClock(ms:Float):Void {
        dispatcher.advanceClock(ms / 1000.0);
    }

    function simulateNextFrame(window:Window):Int {
        final count = window.simulateNextFrame(app);
        runUntilParked();
        return count;
    }

    function updateView<V:Model>(view:Entity<V>, f:(V) -> Void):Void {
        view.update(app, (view, cx) -> {
            f(view);
            cx.notify();
        });
        runUntilParked();
    }

    static inline function last(values:Array<Float>):Float {
        return values[values.length - 1];
    }

    // Before parent-animation-element, using .with_animation
    // would not allow chaining .parent after. This is just a
    // build check that we can call div().id().with_animation().child()
    function testAnimationParent() {
        final element = div().id('id').withAnimation('animation', new Animation(1), (el, _) -> el).child(div());
        assertNotNull(element);
    }

    function testSpringAnimationParent() {
        final element = div().id('id').withSpring(
            'spring-animation',
            new SpringAnimation<Float>(new SpringConfig(100.0, 10.0, 1.0)).toValue(10.0).fromValue(0.0),
            (element, value) -> element.left(px(value))
        ).child(div());
        assertNotNull(element);
    }

    function testSpringAnimationPreservesVelocityWhenRetargeted() {
        final renderedValues:Array<Float> = [];
        final opened = openWindow(() -> new SpringAnimationTestView(0.0, null, Running, renderedValues));
        assertEquals('0', renderedValues.join(','));

        updateView(opened.view, view -> view.target = 100.0);

        advanceClock(50);
        assertTrue(simulateNextFrame(opened.window) > 0);
        final valueBeforeRetargeting = last(renderedValues);
        assertTrue(valueBeforeRetargeting > 0.0);
        assertTrue(valueBeforeRetargeting < 100.0);

        updateView(opened.view, view -> view.target = 0.0);

        advanceClock(5);
        assertTrue(simulateNextFrame(opened.window) > 0);
        final valueAfterRetargeting = last(renderedValues);
        assertTrue(valueAfterRetargeting > valueBeforeRetargeting);
    }

    function testPausedSpringResumesWithItsVelocity() {
        final renderedValues:Array<Float> = [];
        final opened = openWindow(() -> new SpringAnimationTestView(0.0, null, Running, renderedValues));

        updateView(opened.view, view -> view.target = 100.0);
        advanceClock(50);
        assertTrue(simulateNextFrame(opened.window) > 0);

        updateView(opened.view, view -> {
            view.target = 0.0;
            view.playback = Paused;
        });
        final pausedValue = last(renderedValues);

        advanceClock(500);
        assertTrue(simulateNextFrame(opened.window) > 0);
        assertEquals(pausedValue, last(renderedValues));
        assertEquals(0, simulateNextFrame(opened.window));

        updateView(opened.view, view -> view.playback = Running);
        advanceClock(5);
        assertTrue(simulateNextFrame(opened.window) > 0);
        assertTrue(last(renderedValues) > pausedValue);
    }

    function testStoppedSpringResumesWithoutVelocity() {
        final renderedValues:Array<Float> = [];
        final opened = openWindow(() -> new SpringAnimationTestView(0.0, null, Running, renderedValues));

        updateView(opened.view, view -> view.target = 1000000.0);
        advanceClock(50);
        assertTrue(simulateNextFrame(opened.window) > 0);

        updateView(opened.view, view -> {
            view.target = 0.0;
            view.playback = Stopped;
        });
        final stoppedValue = last(renderedValues);

        advanceClock(500);
        assertTrue(simulateNextFrame(opened.window) > 0);
        assertEquals(stoppedValue, last(renderedValues));
        assertEquals(0, simulateNextFrame(opened.window));

        updateView(opened.view, view -> {
            view.target = stoppedValue;
            view.playback = Running;
        });
        assertEquals(stoppedValue, last(renderedValues));
        assertEquals(0, simulateNextFrame(opened.window));
    }

    function testCancelledAndCompletedSpringsResolveTheirEndpoints() {
        final renderedValues:Array<Float> = [];
        final opened = openWindow(() -> new SpringAnimationTestView(100.0, 20.0, Running, renderedValues));
        assertEquals('20', renderedValues.join(','));

        advanceClock(50);
        assertTrue(simulateNextFrame(opened.window) > 0);
        assertTrue(last(renderedValues) > 20.0);

        updateView(opened.view, view -> view.playback = Cancelled);
        assertEquals(20.0, last(renderedValues));
        assertTrue(simulateNextFrame(opened.window) > 0);
        assertEquals(0, simulateNextFrame(opened.window));

        updateView(opened.view, view -> view.playback = Completed);
        assertEquals(100.0, last(renderedValues));
        assertEquals(0, simulateNextFrame(opened.window));
    }

    function testSpringAnimationRespectsReducedMotion() {
        app.setReduceMotion(true);
        final renderedValues:Array<Float> = [];
        final opened = openWindow(() -> new SpringAnimationTestView(100.0, null, Running, renderedValues));

        assertEquals('100', renderedValues.join(','));
        assertEquals(0, simulateNextFrame(opened.window));
    }

    function testRepeatingAnimationSchedulesAnimationFrames() {
        final renderedDeltas:Array<Float> = [];
        final opened = openWindow(() -> new AnimationTestView(renderedDeltas, null));

        assertEquals(1, renderedDeltas.length);

        for (expectedFrames in 2...4) {
            assertEquals(1, simulateNextFrame(opened.window));
            assertEquals(expectedFrames, renderedDeltas.length);
        }
    }

    function testMaxFpsSchedulesTimerDrivenFrames() {
        final renderedDeltas:Array<Float> = [];
        final opened = openWindow(() -> new AnimationTestView(renderedDeltas, 10.0));

        function assertDeltasApproxEq(expected:Array<Float>) {
            assertEquals(expected.length, renderedDeltas.length, 'deltas: $renderedDeltas');
            for (i in 0...expected.length) {
                assertTrue(Math.abs(renderedDeltas[i] - expected[i]) < 1e-2, 'expected ${expected[i]}, got ${renderedDeltas[i]}');
            }
        }

        assertDeltasApproxEq([0.0]);

        // No per-frame callback is scheduled; re-renders are timer-driven.
        assertEquals(0, simulateNextFrame(opened.window));
        assertDeltasApproxEq([0.0]);

        advanceClock(105);
        runUntilParked();
        assertDeltasApproxEq([0.0, 0.105]);

        advanceClock(105);
        runUntilParked();
        assertDeltasApproxEq([0.0, 0.105, 0.21]);
    }

    function testSyncedAnimationsSharePhaseAcrossElements() {
        final firstDeltas:Array<Float> = [];
        final secondDeltas:Array<Float> = [];
        final opened = openWindow(() -> new SyncedAnimationTestView(firstDeltas, secondDeltas));

        assertEquals('0', firstDeltas.join(','));

        advanceClock(250);
        simulateNextFrame(opened.window);
        assertEquals('0,0.25', firstDeltas.join(','));

        // The second element mounts a quarter through the cycle, yet renders
        // the shared phase rather than starting at zero.
        updateView(opened.view, view -> view.showSecond = true);
        advanceClock(250);
        simulateNextFrame(opened.window);

        assertEquals(0.5, last(secondDeltas));
        assertEquals(last(firstDeltas), last(secondDeltas));
        assertTrue(Lambda.foreach(secondDeltas, delta -> delta > 0.0));

        // The phase wraps around each full cycle.
        advanceClock(2250);
        simulateNextFrame(opened.window);
        assertEquals(0.75, last(firstDeltas));

        // Sub-second precision survives months of uptime: converting the raw
        // elapsed time to f32 would round 0.25 away entirely.
        advanceClock(300.0 * 24 * 60 * 60 * 1000 + 500);
        simulateNextFrame(opened.window);
        assertEquals(0.25, last(firstDeltas));
    }

    function testReduceMotionRendersSingleStaticFrame() {
        app.setReduceMotion(true);
        final renderedDeltas:Array<Float> = [];
        final opened = openWindow(() -> new AnimationTestView(renderedDeltas, null));

        assertEquals('0', renderedDeltas.join(','));

        assertEquals(0, simulateNextFrame(opened.window));
        assertEquals('0', renderedDeltas.join(','));
    }

}

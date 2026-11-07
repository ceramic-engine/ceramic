// Ported from gpui-pre 0.3.10: src/window.rs and src/elements/div.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.App;
import gpui.Context;
import gpui.DispatchPhase;
import gpui.Entity;
import gpui.GestureTuning;
import gpui.IntoElement;
import gpui.LongPressEvent;
import gpui.Model;
import gpui.MouseDownEvent;
import gpui.MouseUpEvent;
import gpui.Point;
import gpui.Render;
import gpui.ScrollEvent;
import gpui.ScrollSource;
import gpui.TestDispatcher;
import gpui.TouchDragEvent;
import gpui.TouchEvent;
import gpui.TouchPhase;
import gpui.Window;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.ScrollDelta.ScrollDeltaTools;

/**
 * Touch dispatch through the window (Rust `Window::dispatch_touch_event`):
 * the tests of `window.rs` on touch drags and long presses, the touch tests
 * of `div.rs` (mouse down out after a tap, not after a pan or a cancelled
 * touch; long press tooltips are in `DivInteractivityTest`), and checks of
 * what the recognizer hands to ordinary mouse listeners (taps as presses
 * with their tap count, pans as touch scrolls, hover suppressed).
 *
 * Not ported: `back_gesture_is_claimed_by_the_innermost_listener` (back
 * gestures are not ported: no Ceramic backend reports them).
 */
class TouchWindowTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function addWindow<V:Model & Render>(build:(Window, Context<V>) -> V):Entity<V> {
        if (cx != null) {
            cx.destroy();
            cx = null;
            ceramic.App.app.flushImmediate();
        }
        final opened = VisualTestContext.addWindowView(app, dispatcher, build);
        cx = opened.cx;
        return opened.view;
    }

    /** Rust `dispatch_touch(window, cx, id, phase, x)`: a touch at (x, 0). */
    function dispatchTouch(id:Int, phase:TouchPhase, x:Float, y:Float = 0):Void {
        cx.update((window, cx) -> {
            window.dispatchEvent(new TouchEvent(id, phase, new Point(x, y)), cx);
        });
    }

/// window.rs

    function testClaimedTouchDragReceivesMovementAndRelease() {
        final events:Array<{phase:TouchPhase, x:Float}> = [];
        addWindow((_, _) -> new TouchDragListener(events));

        dispatchTouch(1, Started, 10);
        dispatchTouch(1, Moved, 30);
        dispatchTouch(1, Ended, 40);

        assertEquals(3, events.length);
        assertEquals(Started, events[0].phase);
        assertEquals(10., events[0].x);
        assertEquals(Moved, events[1].phase);
        assertEquals(30., events[1].x);
        assertEquals(Ended, events[2].phase);
        assertEquals(40., events[2].x);
    }

    function testLongPressIsClaimedOnlyWhenStartedPreventsDefault() {
        for (response in [LongPressResponse.PreventDefault, LongPressResponse.StopPropagation, LongPressResponse.None]) {
            final phases:Array<TouchPhase> = [];
            addWindow((_, _) -> new LongPressListener(phases, response));
            dispatchTouch(1, Started, 0);
            cx.advanceClock(0.501);
            cx.runUntilParked();
            cx.update((window, _) -> {
                assertEquals(response == PreventDefault, @:privateAccess window.longPressCapture != -1);
            });
            dispatchTouch(1, Moved, 2);
            dispatchTouch(1, Ended, 2);
            cx.update((window, _) -> {
                assertEquals(-1, @:privateAccess window.longPressCapture);
            });

            if (response == PreventDefault) {
                assertEquals('Started,Moved,Ended', phaseNames(phases));
            }
            else {
                assertEquals('Started', phaseNames(phases));
            }
        }
    }

    function testStaleDefaultPreventionDoesNotClaimLongPress() {
        final phases:Array<TouchPhase> = [];
        addWindow((_, _) -> new LongPressListener(phases, None));
        cx.update((window, _) -> window.preventDefault());

        dispatchTouch(1, Started, 0);
        cx.advanceClock(0.501);
        cx.runUntilParked();
        dispatchTouch(1, Moved, 2);

        assertEquals('Started', phaseNames(phases));
    }

    function testResolvedTouchCancelsScheduledLongPress() {
        for (step in [{phase: TouchPhase.Ended, x: 0.}, {phase: TouchPhase.Cancelled, x: 0.}, {phase: TouchPhase.Moved, x: 20.}]) {
            final phases:Array<TouchPhase> = [];
            addWindow((_, _) -> new LongPressListener(phases, PreventDefault));
            dispatchTouch(1, Started, 0);
            dispatchTouch(1, step.phase, step.x);
            cx.advanceClock(0.501);
            cx.runUntilParked();
            assertEquals(0, phases.length, '${step.phase} allowed long press');
        }
    }

    function testStaleLongPressTimerCannotAffectReplacementTouch() {
        final phases:Array<TouchPhase> = [];
        addWindow((_, _) -> new LongPressListener(phases, PreventDefault));
        dispatchTouch(1, Started, 0);
        cx.advanceClock(0.25);
        dispatchTouch(1, Cancelled, 0);
        dispatchTouch(2, Started, 10);

        cx.advanceClock(0.251);
        cx.runUntilParked();
        assertEquals(0, phases.length);

        cx.advanceClock(0.25);
        cx.runUntilParked();
        assertEquals('Started', phaseNames(phases));
    }

/// div.rs

    function testTouchTapOutFiresOnceAfterRelease() {
        final counter = [0];
        addWindow((_, _) -> new MouseDownOutOwner(counter));
        cx.update((window, _) -> window.draw());
        cx.update((window, cx) -> {
            window.dispatchEvent(new TouchEvent(1, Started, new Point(75, 75)), cx);
            assertEquals(0, counter[0]);
            window.dispatchEvent(new TouchEvent(1, Ended, new Point(75, 75)), cx);
        });
        assertEquals(1, counter[0], 'a touch tap outside the element should use mouse-down-out listeners');
    }

    function testTouchPanAndCancelDoNotFireMouseDownOut() {
        final counter = [0];
        addWindow((_, _) -> new MouseDownOutOwner(counter));
        cx.update((window, cx) -> {
            window.draw();
            final samples:Array<{id:Int, steps:Array<{phase:TouchPhase, y:Float}>}> = [
                {id: 1, steps: [{phase: Started, y: 100}, {phase: Moved, y: 75}, {phase: Ended, y: 75}]},
                {id: 2, steps: [{phase: Started, y: 100}, {phase: Moved, y: 100}, {phase: Cancelled, y: 100}]},
            ];
            for (sample in samples) {
                for (step in sample.steps) {
                    window.dispatchEvent(new TouchEvent(sample.id, step.phase, new Point(75, step.y)), cx);
                }
            }
        });
        assertEquals(0, counter[0]);
    }

/// Recognized gestures seen by mouse listeners

    function testTapsReachMouseListenersWithTheirTapCount() {
        final log:Array<String> = [];
        addWindow((_, _) -> new MouseLogger(log));
        dispatchTouch(1, Started, 20, 30);
        dispatchTouch(1, Ended, 21, 30);
        cx.advanceClock(0.1);
        dispatchTouch(2, Started, 24, 31);
        dispatchTouch(2, Ended, 24, 31);
        assertEquals('down 21,30 x1|up 21,30 x1|down 24,31 x2|up 24,31 x2', log.join('|'));
        cx.update((window, _) -> assertTrue(window.lastInputWasTouch()));
    }

    function testPansReachScrollListenersAsTouchScrolls() {
        final log:Array<String> = [];
        addWindow((_, _) -> new MouseLogger(log));
        dispatchTouch(1, Started, 50, 200);
        cx.advanceClock(0.016);
        dispatchTouch(1, Moved, 50, 180);
        cx.advanceClock(0.016);
        dispatchTouch(1, Moved, 50, 170);
        cx.advanceClock(0.2);
        dispatchTouch(1, Ended, 50, 170);
        assertEquals('scroll 50,200 0,-20 Started touch|scroll 50,200 0,-10 Moved touch|scroll 50,200 0,0 Ended touch', log.join('|'));
    }

    function testFlingMomentumTicksOnFramesUntilItEnds() {
        final log:Array<String> = [];
        addWindow((_, _) -> new MouseLogger(log));
        dispatchTouch(1, Started, 50, 300);
        for (step in 1...4) {
            cx.advanceClock(0.016);
            dispatchTouch(1, Moved, 50, 300 - step * 33);
        }
        cx.advanceClock(0.016);
        dispatchTouch(1, Ended, 50, 200);
        log.resize(0);
        var frames = 0;
        while (frames < 1000) {
            cx.advanceClock(0.016);
            cx.update((window, cx) -> window.simulateNextFrame(cx));
            frames++;
            if (log.length > 0 && StringTools.endsWith(log[log.length - 1], 'Ended touch'))
                break;
        }
        assertTrue(log.length > 2, 'momentum produced ${log.length} steps');
        for (i in 0...log.length - 1) {
            assertTrue(StringTools.endsWith(log[i], 'Moved touch'), log[i]);
        }
        assertTrue(StringTools.endsWith(log[log.length - 1], 'Ended touch'), log[log.length - 1]);
    }

    static function phaseNames(phases:Array<TouchPhase>):String {
        return [for (phase in phases) switch phase {
            case Started: 'Started';
            case Moved: 'Moved';
            case Ended: 'Ended';
            case Cancelled: 'Cancelled';
        }].join(',');
    }

}

private enum abstract LongPressResponse(Int) {
    var PreventDefault = 0;
    var StopPropagation = 1;
    var None = 2;
}

private class TouchDragListener extends Model implements Render {

    final events:Array<{phase:TouchPhase, x:Float}>;

    public function new(events:Array<{phase:TouchPhase, x:Float}>) {
        super();
        this.events = events;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final events = this.events;
        return canvas((_, _, _) -> 0, (_, _, window, _) -> {
            window.onMouseEvent(TouchDrag, (e, phase, window, _) -> {
                if (phase != Bubble)
                    return;
                final event:TouchDragEvent = cast e;
                events.push({phase: event.phase, x: event.position.x});
                if (event.phase == Started) {
                    window.preventDefault();
                }
            });
        });
    }

}

private class LongPressListener extends Model implements Render {

    final phases:Array<TouchPhase>;

    final response:LongPressResponse;

    public function new(phases:Array<TouchPhase>, response:LongPressResponse) {
        super();
        this.phases = phases;
        this.response = response;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final entity = cx.entity();
        final phases = this.phases;
        final response = this.response;
        return canvas((_, _, _) -> 0, (_, _, window, _) -> {
            window.onMouseEvent(LongPress, (e, phase, window, cx) -> {
                if (phase != Bubble)
                    return;
                final event:LongPressEvent = cast e;
                phases.push(event.phase);
                switch response {
                    case PreventDefault:
                        window.captureLongPress(entity);
                        window.preventDefault();
                    case StopPropagation:
                        cx.stopPropagation();
                    case None:
                }
            });
        });
    }

}

private class MouseDownOutOwner extends Model implements Render {

    final counter:Array<Int>;

    public function new(counter:Array<Int>) {
        super();
        this.counter = counter;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final counter = this.counter;
        return div()
            .sizeFull()
            .child(div().id('target').w(px(50)).h(px(50)).onMouseDownOut((_, _, _) -> {
                counter[0]++;
            }));
    }

}

private class MouseLogger extends Model implements Render {

    final log:Array<String>;

    public function new(log:Array<String>) {
        super();
        this.log = log;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final log = this.log;
        return canvas((_, _, _) -> 0, (_, _, window, _) -> {
            window.onMouseEvent(MouseDown, (e, phase, _, _) -> {
                if (phase != Bubble) return;
                final event:MouseDownEvent = cast e;
                log.push('down ${event.position.x},${event.position.y} x${event.clickCount}');
            });
            window.onMouseEvent(MouseUp, (e, phase, _, _) -> {
                if (phase != Bubble) return;
                final event:MouseUpEvent = cast e;
                log.push('up ${event.position.x},${event.position.y} x${event.clickCount}');
            });
            window.onMouseEvent(Scroll, (e, phase, window, _) -> {
                if (phase != Bubble) return;
                final event:ScrollEvent = cast e;
                final delta = event.delta.pixelDelta(16);
                final phaseName = switch event.touchPhase {
                    case Started: 'Started';
                    case Moved: 'Moved';
                    case Ended: 'Ended';
                    case Cancelled: 'Cancelled';
                };
                log.push('scroll ${event.position.x},${event.position.y} ${Math.round(delta.x)},${Math.round(delta.y)} $phaseName ${event.source == ScrollSource.Touch ? 'touch' : 'pointer'}');
            });
        });
    }

}

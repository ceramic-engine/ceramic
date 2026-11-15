package tests;

import glaze.App;
import glaze.Context;
import glaze.GlazeInput;
import glaze.IntoElement;
import glaze.Model;
import glaze.OngoingScroll;
import glaze.Point;
import glaze.Render;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.TouchPhase;
import glaze.Window;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.ScrollDelta.ScrollDeltaTools;

/**
 * The phase of Ceramic's scroll events (`screen.mouseScrollPhase`, reported
 * by clay on macOS) becomes the `touchPhase` of GPUI's `ScrollEvent` the way
 * GPUI's macOS platform reads `NSEvent.phase` (gpui_macos events.rs
 * 262-267), and `Moved` where there is no phase, as before. The headless
 * backend feeds the phases like clay does.
 */
class GlazeInputScrollPhaseTest extends TestCase {

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
            GlazeInput.unbind(cx.window);
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    /** Runs Ceramic's queued input callbacks, like the start of an update. */
    static function flushInput():Void {
        final ceramicApp = ceramic.App.app;
        final callbacks:Array<() -> Void> = @:privateAccess ceramicApp.beginUpdateCallbacks;
        @:privateAccess ceramicApp.beginUpdateCallbacks = [];
        for (callback in callbacks) {
            callback();
        }
        ceramicApp.flushImmediate();
    }

    public static function nameOf(phase:TouchPhase):String {
        return switch phase {
            case Started: 'Started';
            case Moved: 'Moved';
            case Ended: 'Ended';
            case Cancelled: 'Cancelled';
        }
    }

    /** GPUI macOS: may begin and began are Started, ended is Ended, the rest Moved (momentum and cancelled included). */
    function testTouchPhaseOfFollowsGpuiMacPlatform() {
        final phases:Array<ceramic.ScrollPhase> = [
            NONE, GESTURE_MAY_BEGIN, GESTURE_BEGAN, GESTURE, GESTURE_ENDED, GESTURE_CANCELLED,
            MOMENTUM_BEGAN, MOMENTUM, MOMENTUM_ENDED
        ];
        assertEquals(
            'Moved Started Started Moved Ended Moved Moved Moved Moved',
            [for (phase in phases) nameOf(GlazeInput.touchPhaseOf(phase))].join(' ')
        );
    }

    function testCeramicScrollPhaseIsNoneByDefault() {
        assertEquals('NONE', ceramic.App.app.screen.mouseScrollPhase.toString());
        assertEquals('NONE', ceramic.App.app.backend.screen.getMouseScrollPhase().toString());
    }

    /** A trackpad gesture and its momentum, as clay emits them on macOS, then a mouse wheel. */
    function testBackendPhasesReachScrollEvents() {
        final log:Array<String> = [];
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScrollLogView(log), 400, 300, 1);
        cx = opened.cx;
        GlazeInput.bind(cx.window);
        final screen = ceramic.App.app.backend.screen;
        final density = ceramic.App.app.screen.nativeDensity;
        @:privateAccess screen.emitMouseMove(100 / density, 100 / density);
        flushInput();

        final pixels = ceramic.ScrollUnit.PIXELS;
        screen.emitMouseScrollWithPhase(0, 0, pixels, GESTURE_MAY_BEGIN);
        screen.emitMouseScrollWithPhase(0, 4, pixels, GESTURE_BEGAN);
        screen.emitMouseScrollWithPhase(0, 6, pixels, GESTURE);
        screen.emitMouseScrollWithPhase(0, 0, pixels, GESTURE_ENDED);
        screen.emitMouseScrollWithPhase(0, 3, pixels, MOMENTUM_BEGAN);
        screen.emitMouseScrollWithPhase(0, 2, pixels, MOMENTUM);
        screen.emitMouseScrollWithPhase(0, 0, pixels, MOMENTUM_ENDED);
        screen.emitMouseScrollWithPhase(0, 0, pixels, GESTURE_CANCELLED);
        @:privateAccess screen.emitMouseScroll(0, 1, ceramic.ScrollUnit.LINES);
        flushInput();

        assertEquals(
            '0 Started|-4 Started|-6 Moved|0 Ended|-3 Moved|-2 Moved|0 Moved|0 Moved|-16 Moved',
            log.join('|')
        );
        assertEquals('NONE', ceramic.App.app.screen.mouseScrollPhase.toString());
    }

    /**
     * `OngoingScroll` locks a gesture to the axis it started on. Without
     * phases a new gesture is only told apart by a pause (28 ms); with the
     * macOS phases a `Started` event starts a new lock at once, and `Ended`
     * drops it, like GPUI on macOS.
     */
    function testStartedAndEndedDelimitTheAxisLock() {
        final moved = new OngoingScroll();
        assertEquals('6,0', str(moved.filter(new Point(6, 1), Moved, 0)));
        // 10 ms later, still the same gesture without phases: stays horizontal
        assertEquals('1,0', str(moved.filter(new Point(1, 5), Moved, 0.01)));

        final phased = new OngoingScroll();
        assertEquals('6,0', str(phased.filter(new Point(6, 1), Started, 0)));
        // A new gesture 10 ms later: locked to its own axis
        assertEquals('0,5', str(phased.filter(new Point(1, 5), Started, 0.01)));
        // The end of the gesture (zero deltas) drops the lock: the momentum
        // that follows takes the axis of its first event
        assertEquals('0,0', str(phased.filter(new Point(0, 0), Ended, 0.02)));
        assertEquals('4,0', str(phased.filter(new Point(4, 1), Moved, 0.025)));
    }

    static function str(point:Point):String {
        return '${point.x},${point.y}';
    }

}

private class ScrollLogView extends Model implements Render {

    final log:Array<String>;

    public function new(log:Array<String>) {
        super();
        this.log = log;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final log = this.log;
        return div().sizeFull().child(canvas((_, _, _) -> 0, (_, _, window, _) -> {
            window.onMouseEvent(Scroll, (e, phase, _, _) -> {
                if (phase != Bubble) return;
                final event:ScrollEvent = cast e;
                final delta = event.delta.pixelDelta(16);
                log.push('${Math.round(delta.y)} ${GlazeInputScrollPhaseTest.nameOf(event.touchPhase)}');
            });
        }).sizeFull());
    }

}

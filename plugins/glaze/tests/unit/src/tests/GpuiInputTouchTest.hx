package tests;

import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.ElementInputHandler;
import gpui.Entity;
import gpui.EntityInputHandler;
import gpui.FocusHandle;
import gpui.GpuiInput;
import gpui.IntoElement;
import gpui.Model;
import gpui.MouseDownEvent;
import gpui.MouseUpEvent;
import gpui.Point;
import gpui.Range;
import gpui.Render;
import gpui.ScrollEvent;
import gpui.ScrollSource;
import gpui.TestDispatcher;
import gpui.TextInputConfiguration;
import gpui.UTF16Selection;
import gpui.Window;
import gpui.util.Ref;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.ScrollDelta.ScrollDeltaTools;

/**
 * Ceramic touches through `GpuiInput`: touch events injected in Ceramic's
 * backend screen (like the clay and headless backends emit them) become the
 * GPUI events the recognizer makes of them (taps with their click count,
 * pans as touch scrolls with their phases, cancelled touches). Also Ceramic's
 * tap rules for the web virtual keyboard (`ceramic.TouchTapTracker`), the
 * tap filter answered from the text inputs of the last frame, the touch
 * cancel event and the per touch deltas of `ceramic.Screen`.
 */
class GpuiInputTouchTest extends TestCase {

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
            GpuiInput.unbind(cx.window);
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function open<V:Model & Render>(build:(Window, Context<V>) -> V):Entity<V> {
        final opened = VisualTestContext.addWindowView(app, dispatcher, build, 400, 300, 1);
        cx = opened.cx;
        GpuiInput.bind(cx.window);
        return opened.view;
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

    /**
     * Ceramic touch at screen (x, y), as a backend emits it (in native
     * coordinates: screen coordinates over the density), flushed.
     */
    static function touch(kind:String, index:Int, x:Float, y:Float):Void {
        final density = ceramic.App.app.screen.nativeDensity;
        x /= density;
        y /= density;
        final screen = ceramic.App.app.backend.screen;
        switch kind {
            case 'down': @:privateAccess screen.emitTouchDown(index, x, y);
            case 'move': @:privateAccess screen.emitTouchMove(index, x, y);
            case 'up': @:privateAccess screen.emitTouchUp(index, x, y);
            case 'cancel': @:privateAccess screen.emitTouchCancel(index, x, y);
        }
        flushInput();
    }

    /** The window position of screen (x, y). */
    function windowPoint(x:Float, y:Float):Point {
        final point = new ceramic.Point();
        cx.window.renderable.screenToVisual(x, y, point);
        return new Point(point.x, point.y);
    }

    /**
     * GPUI asks Ceramic for frame aligned smooth scrolling on the web (Safari dispatches
     * wheel events on its own clock: frames without motion, then double steps). The
     * resampler itself is tested in clay (`test/WheelResamplerTest.hx`).
     */
    function testBindingInputEnablesWebWheelResampling() {
        final settings = ceramic.App.app.settings;
        @:privateAccess if (GpuiInput.instance != null) GpuiInput.instance.destroy();
        settings.webWheelResampling = false;
        open((_, _) -> new TouchLogView([]));
        assertTrue(settings.webWheelResampling);
    }

    function testTapsBecomeMouseClicksWithTheirCount() {
        final log:Array<String> = [];
        open((_, _) -> new TouchLogView(log));
        final at = windowPoint(40, 50);
        touch('down', 0, 40, 50);
        touch('up', 0, 41, 50);
        touch('down', 0, 42, 51);
        touch('up', 0, 42, 51);
        final p1 = windowPoint(41, 50);
        final p2 = windowPoint(42, 51);
        assertEquals('down ${p1.x},${p1.y} x1|up ${p1.x},${p1.y} x1|down ${p2.x},${p2.y} x2|up ${p2.x},${p2.y} x2', log.join('|'));
        assertTrue(at.x > 0);
        cx.update((window, _) -> assertTrue(window.lastInputWasTouch()));
    }

    function testPansBecomeTouchScrollsWithTheirPhases() {
        final log:Array<String> = [];
        open((_, _) -> new TouchLogView(log));
        touch('down', 0, 100, 200);
        cx.advanceClock(0.016);
        touch('move', 0, 100, 180);
        cx.advanceClock(0.016);
        touch('move', 0, 100, 170);
        cx.advanceClock(0.2);
        touch('up', 0, 100, 170);
        final start = windowPoint(100, 200);
        final scale = windowPoint(100, 180).y - start.y;
        assertEquals(
            'scroll ${start.x},${start.y} 0,${Math.round(scale)} Started touch'
            + '|scroll ${start.x},${start.y} 0,${Math.round(scale / 2)} Moved touch'
            + '|scroll ${start.x},${start.y} 0,0 Ended touch',
            log.join('|'));
    }

    function testCancelledTouchUnwindsThePanWithoutAnEnd() {
        final log:Array<String> = [];
        open((_, _) -> new TouchLogView(log));
        touch('down', 0, 100, 200);
        touch('move', 0, 100, 150);
        log.resize(0);
        // Ceramic emits the cancel, then the up that ends the touch
        touch('cancel', 0, 100, 150);
        final start = windowPoint(100, 200);
        assertEquals('scroll ${start.x},${start.y} 0,0 Cancelled touch', log.join('|'));
    }

    function testCancelledTapDoesNotClick() {
        final log:Array<String> = [];
        open((_, _) -> new TouchLogView(log));
        touch('down', 0, 40, 50);
        touch('cancel', 0, 40, 50);
        assertEquals('', log.join('|'));
    }

    function testTouchIdentifiersAreNeverReused() {
        final log:Array<String> = [];
        open((_, _) -> new TouchLogView(log));
        final input:GpuiInput = @:privateAccess GpuiInput.instance;
        final before:Int = @:privateAccess input.nextTouchId;
        touch('down', 0, 40, 50);
        touch('up', 0, 40, 50);
        touch('down', 0, 40, 50);
        touch('up', 0, 40, 50);
        assertEquals(before + 2, @:privateAccess input.nextTouchId);
        assertFalse((@:privateAccess input.touchIds).exists(0));
    }

/// Virtual keyboard

    function testTapFilterAnswersFromTheTextInputsOfTheLastFrame() {
        final view = open((_, cx) -> new TwoInputsView(cx.focusHandle(), cx.focusHandle()));
        final filter = ceramic.App.app.input.textEditingTapFilter;
        assertNotNull(filter);
        // Window coordinates are screen coordinates here (scale 1, at the origin)
        assertTrue(filter(20, 20), 'tap on the editable input');
        assertFalse(filter(20, 120), 'tap on the input that does not accept text');
        assertFalse(filter(300, 250), 'tap outside of any input');
        // Not focused: the regions come from every painted input
        cx.update((window, _) -> assertFalse(window.hasFocusedTextInput()));
    }

    function testTapTrackerTellsTapsApart() {
        final taps = new ceramic.TouchTapTracker();
        // Released where it started
        taps.touchDown(1, 10, 10, 800);
        assertTrue(taps.touchUp(1, 12, 13, 800));
        // Moved beyond the slop, even when released back at the start
        taps.touchDown(2, 10, 10, 800);
        taps.touchMove(2, 19, 10);
        assertFalse(taps.touchUp(2, 10, 10, 800));
        // Within the slop
        taps.touchDown(3, 10, 10, 800);
        taps.touchMove(3, 15, 16);
        assertTrue(taps.touchUp(3, 15, 16, 800));
        // Cancelled
        taps.touchDown(4, 10, 10, 800);
        taps.touchCancel(4);
        assertFalse(taps.touchUp(4, 10, 10, 800));
        // The viewport changed during the gesture (a keyboard opened or closed)
        taps.touchDown(5, 10, 10, 800);
        assertFalse(taps.touchUp(5, 10, 10, 500));
        // Only the first touch of a gesture can be a tap
        taps.touchDown(6, 10, 10, 800);
        taps.touchDown(7, 50, 50, 800);
        assertFalse(taps.touchUp(7, 50, 50, 800));
        assertTrue(taps.touchUp(6, 10, 10, 800));
    }

/// Ceramic screen

    function testTouchCancelIsFollowedByTheTouchUp() {
        final screen = ceramic.App.app.screen;
        final events:Array<String> = [];
        final owner = new ceramic.Entity();
        screen.onTouchCancel(owner, (index, _, _) -> events.push('cancel $index'));
        screen.onTouchUp(owner, (index, _, _) -> events.push('up $index'));
        final backendScreen = ceramic.App.app.backend.screen;
        @:privateAccess backendScreen.emitTouchDown(3, 10, 10);
        @:privateAccess backendScreen.emitTouchCancel(3, 12, 10);
        flushInput();
        owner.destroy();
        assertEquals('cancel 3,up 3', events.join(','));
        assertFalse(screen.isPointerDown);
    }

    function testTouchDeltasFollowEachMove() {
        final screen = ceramic.App.app.screen;
        final backendScreen = ceramic.App.app.backend.screen;
        @:privateAccess screen.resetDeltas();
        @:privateAccess backendScreen.emitTouchDown(5, 10, 10);
        flushInput();
        @:privateAccess backendScreen.emitTouchMove(5, 15, 10);
        @:privateAccess backendScreen.emitTouchMove(5, 20, 12);
        flushInput();
        final touch = screen.touches.get(5);
        final density = screen.nativeDensity;
        assertFloatEquals(10 * density, touch.deltaX);
        assertFloatEquals(2 * density, touch.deltaY);
        // The next frame measures from the last position
        @:privateAccess screen.resetDeltas();
        @:privateAccess backendScreen.emitTouchMove(5, 25, 12);
        flushInput();
        assertFloatEquals(5 * density, touch.deltaX);
        assertFloatEquals(0, touch.deltaY);
        @:privateAccess backendScreen.emitTouchUp(5, 25, 12);
        flushInput();
    }

}

private class TouchLogView extends Model implements Render {

    final log:Array<String>;

    public function new(log:Array<String>) {
        super();
        this.log = log;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final log = this.log;
        return div().sizeFull().child(canvas((_, _, _) -> 0, (_, _, window, _) -> {
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
            window.onMouseEvent(Scroll, (e, phase, _, _) -> {
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
        }).sizeFull());
    }

}

/**
 * Two text inputs, none focused: an editable one at (0, 0, 200, 40) and one
 * that does not accept text at (0, 100, 200, 40).
 */
private class TwoInputsView extends Model implements Render {

    final editable:FocusHandle;

    final readonly:FocusHandle;

    public function new(editable:FocusHandle, readonly:FocusHandle) {
        super();
        this.editable = editable;
        this.readonly = readonly;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final editable = this.editable;
        final readonly = this.readonly;
        final editableView = cx.newEntity(_ -> new FakeInput(true));
        final readonlyView = cx.newEntity(_ -> new FakeInput(false));
        return div().sizeFull()
            .child(div().absolute().top(px(0)).left(px(0)).w(px(200)).h(px(40)).child(canvas((_, _, _) -> 0, (bounds, _, window, cx) -> {
                window.handleInput(editable, new ElementInputHandler(bounds, editableView), cx);
            }).sizeFull()))
            .child(div().absolute().top(px(100)).left(px(0)).w(px(200)).h(px(40)).child(canvas((_, _, _) -> 0, (bounds, _, window, cx) -> {
                window.handleInput(readonly, new ElementInputHandler(bounds, readonlyView), cx);
            }).sizeFull()));
    }

}

private class FakeInput extends Model implements EntityInputHandler {

    final accepts:Bool;

    public function new(accepts:Bool) {
        super();
        this.accepts = accepts;
    }

    public function acceptsTextInput(window:Window, cx:Context<Dynamic>):Bool {
        return accepts;
    }

    public function textForRange(range:Range, adjustedRange:Ref<Null<Range>>, window:Window, cx:Context<Dynamic>):Null<String> {
        return null;
    }

    public function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:Context<Dynamic>):Null<UTF16Selection> {
        return null;
    }

    public function markedTextRange(window:Window, cx:Context<Dynamic>):Null<Range> {
        return null;
    }

    public function unmarkText(window:Window, cx:Context<Dynamic>):Void {}

    public function replaceTextInRange(range:Null<Range>, text:String, window:Window, cx:Context<Dynamic>):Void {}

    public function replaceAndMarkTextInRange(range:Null<Range>, newText:String, newSelectedRange:Null<Range>, window:Window, cx:Context<Dynamic>):Void {}

    public function boundsForRange(rangeUtf16:Range, elementBounds:Bounds, window:Window, cx:Context<Dynamic>):Null<Bounds> {
        return null;
    }

    public function characterIndexForPoint(point:Point, window:Window, cx:Context<Dynamic>):Null<Int> {
        return null;
    }

    public function textInputConfiguration(window:Window, cx:Context<Dynamic>):TextInputConfiguration {
        return TextInputConfiguration.defaultValue();
    }

}

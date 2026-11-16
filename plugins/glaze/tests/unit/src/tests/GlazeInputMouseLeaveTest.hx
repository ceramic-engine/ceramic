package tests;

import glaze.App;
import glaze.Context;
import glaze.GlazeInput;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import testing.VisualTestContext;
import glaze.Prelude.*;

/**
 * The mouse leaving the app window (`ceramic.Screen.windowMouseLeave`, from
 * the backend's leave event) ends the hover of what was under it: no mouse
 * move comes after it, like GPUI's `MouseExited` on macOS. While a button is
 * held the events keep going to the pressed window, so the hover stays.
 */
class GlazeInputMouseLeaveTest extends TestCase {

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

    static function move(x:Float, y:Float):Void {
        final density = ceramic.App.app.screen.nativeDensity;
        @:privateAccess ceramic.App.app.backend.screen.emitMouseMove(x / density, y / density);
        flushInput();
    }

    static function leave():Void {
        @:privateAccess ceramic.App.app.backend.screen.emitWindowMouseLeave();
        flushInput();
    }

    function frame():Void {
        cx.runUntilParked();
    }

    function open(view:HoverView):Void {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> view, 400, 300, 1);
        cx = opened.cx;
        GlazeInput.bind(cx.window);
        frame();
    }

    function testLeavingTheWindowEndsTheHover() {
        final view = new HoverView();
        open(view);
        move(50, 50);
        frame();
        assertTrue(view.hovered, 'hovered after a move over the element');
        leave();
        frame();
        assertFalse(view.hovered, 'the hover ends when the mouse leaves the window');
        move(60, 60);
        frame();
        assertTrue(view.hovered, 'hovered again when the mouse comes back');
    }

    function testAHeldButtonKeepsTheHover() {
        final view = new HoverView();
        open(view);
        move(50, 50);
        @:privateAccess ceramic.App.app.backend.screen.emitMouseDown(0, 50 / ceramic.App.app.screen.nativeDensity, 50 / ceramic.App.app.screen.nativeDensity);
        flushInput();
        frame();
        leave();
        frame();
        assertTrue(view.hovered, 'a drag that leaves the window keeps its target');
        @:privateAccess ceramic.App.app.backend.screen.emitMouseUp(0, 50 / ceramic.App.app.screen.nativeDensity, 50 / ceramic.App.app.screen.nativeDensity);
        flushInput();
        frame();
    }

}

private class HoverView extends Model implements Render {

    public var hovered:Bool = false;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(
            div().id('target').w(px(200)).h(px(200)).onHover((over, _, _) -> hovered = over)
        );
    }

}

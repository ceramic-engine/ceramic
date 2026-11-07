// Ported from gpui-kit 0.8.1: crates/base/src (the TestAppContext helpers used by the motion and nav_stack tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.Model;
import gpui.Render;
import gpui.TestDispatcher;
import gpui.Window;
import testing.InteractionScript;
import testing.TestCase;

/**
 * Base of the gpui-kit tests that need an app and windows, standing for
 * GPUI's `TestAppContext`: the app draws dirty windows when it flushes its
 * effects, the clock is a `TestDispatcher`, and `simulateNextFrame` runs the
 * next frame callbacks.
 */
class KitTestCase extends TestCase {

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

    /**
     * `cx.open_window(...)` followed by `run_until_parked()`.
     */
    function openWindow<V:Model & Render>(build:(Context<V>) -> V):{window:Window, view:Entity<V>} {
        var view:Entity<V> = null;
        var window:Window = null;
        app.update(cx -> {
            window = Window.open(cx, {width: 100, height: 100, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                view = cx.newEntity(viewCx -> build(viewCx));
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

    /**
     * `window.update(cx, |_, window, _| window.refresh())` then `run_until_parked()`.
     */
    function refresh(window:Window):Void {
        app.update(_ -> window.refresh());
        runUntilParked();
    }

    /**
     * `window.update(cx, |_, window, cx| window.simulate_next_frame(cx))`: runs
     * the next frame callbacks (the frame they request is drawn as the
     * effects flush) and returns how many ran.
     */
    function simulateNextFrame(window:Window):Int {
        return window.simulateNextFrame(app);
    }

}

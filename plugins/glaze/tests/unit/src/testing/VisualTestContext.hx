// Ported from gpui-pre 0.3.10: src/app/test_context.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package testing;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.ModifiersChangedEvent;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.PlatformInput;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;

/**
 * A window driven like GPUI's `VisualTestContext`: the app draws every dirty
 * window when its effects are flushed (`GlazeMode::Test`), simulated events go
 * through `Window.dispatchEvent` and run the dispatcher until parked.
 *
 * The default window matches the test platform: 1920x1080 at scale factor 2.
 */
class VisualTestContext {

    public final app:App;

    public final dispatcher:TestDispatcher;

    public final window:Window;

    function new(app:App, dispatcher:TestDispatcher, window:Window) {
        this.app = app;
        this.dispatcher = dispatcher;
        this.window = window;
    }

    /**
     * Rust `TestAppContext::add_window_view`: opens a window whose root view is built by
     * `build`, draws it and runs until parked.
     */
    public static function addWindowView<V:Model & Render>(app:App, dispatcher:TestDispatcher, build:(Window, Context<V>) -> V, width:Float = 1920, height:Float = 1080, scaleFactor:Float = 2):{view:Entity<V>, cx:VisualTestContext} {
        if (app.onEffectsFlushed == null) {
            app.onEffectsFlushed = drawDirtyWindows;
        }
        var view:Entity<V> = null;
        final window = Window.open(app, {width: width, height: height, scaleFactor: scaleFactor, autoDraw: false, active: false, bindInput: false}, (window, cx) -> {
            view = cx.newEntity((viewCx:Context<V>) -> build(window, viewCx));
            return view;
        });
        // `open_window` draws once
        app.update(_ -> window.draw());
        final cx = new VisualTestContext(app, dispatcher, window);
        cx.runUntilParked();
        return {view: view, cx: cx};
    }

    /**
     * Like `addWindowView`, with the view `build` returns hosted in a kit
     * `Root` (Rust `common::open_window`): the window's root view is the
     * root, `view` is the content. `build` gets the `App` of the window
     * builder (Rust `&mut App`) and returns the content entity.
     */
    public static function addWindowRoot<V:Model & Render>(app:App, dispatcher:TestDispatcher, build:(Window, App) -> Entity<V>, width:Float = 1920, height:Float = 1080, scaleFactor:Float = 2):{view:Entity<V>, cx:VisualTestContext} {
        if (app.onEffectsFlushed == null) {
            app.onEffectsFlushed = drawDirtyWindows;
        }
        var view:Entity<V> = null;
        final window = Window.open(app, {width: width, height: height, scaleFactor: scaleFactor, autoDraw: false, active: false, bindInput: false}, (window, cx) -> {
            view = build(window, cx);
            return Root.component().child(view);
        });
        // `open_window` draws once
        app.update(_ -> window.draw());
        final cx = new VisualTestContext(app, dispatcher, window);
        cx.runUntilParked();
        return {view: view, cx: cx};
    }

    /**
     * Most frames the effect flushes may draw between two calls of `update`
     * or `runUntilParked`: a window that keeps asking for a new frame fails
     * the test instead of hanging it.
     */
    public static var maxDrawsPerStep:Int = 1000;

    static var drawsThisStep:Int = 0;

    static function drawDirtyWindows(app:App):Void {
        for (window in Window.windows.copy()) {
            if (window.app == app && window.dirty && !window.isDestroyed()) {
                if (++drawsThisStep > maxDrawsPerStep) {
                    drawsThisStep = 0;
                    throw 'Window ${window.id} was drawn more than $maxDrawsPerStep times in one step: it never goes idle';
                }
                window.draw();
            }
        }
    }

    public function destroy():Void {
        window.destroy();
        ceramic.App.app.flushImmediate();
    }

    /**
     * Rust `VisualTestContext::update`: runs `f` with the window and the app, in an app update.
     */
    public function update<R>(f:(Window, App) -> R):R {
        drawsThisStep = 0;
        return app.update(cx -> f(window, cx));
    }

    /**
     * Wait until there are no more pending tasks.
     */
    public function runUntilParked():Void {
        drawsThisStep = 0;
        dispatcher.runUntilParked();
        ceramic.App.app.flushImmediate();
    }

    /**
     * Rust `cx.executor().advance_clock(duration)` (seconds).
     *
     * Rust durations are integer nanoseconds, so ten advances of 100ms add up to
     * exactly one second. To keep that, the clock is moved to a target computed in
     * whole microseconds instead of accumulating float increments.
     */
    public function advanceClock(seconds:Float):Void {
        final nowMicros = Math.fround(dispatcher.now() * 1000000);
        final targetMicros = nowMicros + Math.fround(seconds * 1000000);
        dispatcher.advanceClock(targetMicros / 1000000 - dispatcher.now());
        ceramic.App.app.flushImmediate();
    }

    /**
     * Simulate a sequence of keystrokes (`"cmd-p escape"`). Runs until parked.
     */
    public function simulateKeystrokes(keystrokes:String):Void {
        for (source in keystrokes.split(' ')) {
            final keystroke = Keystroke.parse(source);
            update((window, cx) -> window.dispatchKeystroke(keystroke, cx));
        }
        runUntilParked();
    }

    /**
     * Simulate an event from the platform. Runs until parked.
     */
    public function simulateEvent(event:PlatformInput):Void {
        window.dispatchEvent(event, app);
        runUntilParked();
    }

    public function simulateModifiersChange(modifiers:Modifiers):Void {
        simulateEvent(new ModifiersChangedEvent(modifiers, false));
    }

    public function simulateMouseMove(position:Point, ?button:MouseButton, ?modifiers:Modifiers):Void {
        simulateEvent(new MouseMoveEvent(position, button, modifiers != null ? modifiers : Modifiers.none()));
    }

    public function simulateMouseDown(position:Point, button:MouseButton, ?modifiers:Modifiers):Void {
        simulateEvent(new MouseDownEvent(button, position, modifiers != null ? modifiers : Modifiers.none(), 1, false));
    }

    public function simulateMouseUp(position:Point, button:MouseButton, ?modifiers:Modifiers):Void {
        simulateEvent(new MouseUpEvent(button, position, modifiers != null ? modifiers : Modifiers.none(), 1));
    }

    /**
     * Simulate a primary mouse click at the given point.
     */
    public function simulateClick(position:Point, ?modifiers:Modifiers):Void {
        final m = modifiers != null ? modifiers : Modifiers.none();
        simulateEvent(new MouseDownEvent(Left, position, m, 1, false));
        simulateEvent(new MouseUpEvent(Left, position, m, 1));
    }

}

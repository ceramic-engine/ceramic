package testing;

import glaze.App;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.PlatformInput;
import glaze.Point;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.Window;

/**
 * Replays the scripts of the interaction behaviours of the reference harness
 * (`reference/src/interaction.rs`, `Script`) on the port, following the same
 * replay rule:
 *
 * 1. open a 512x512 window (scale factor 2, like the headless test window),
 *    activate it, draw once;
 * 2. every step: log `> <step>`, perform it inside an app update, run the
 *    dispatcher until parked, refresh and draw, run until parked, then run the
 *    state hook.
 *
 * Like GPUI's `GlazeMode::Test`, the app draws every dirty window when its
 * effect queue is flushed (`App.onEffectsFlushed`).
 */
class InteractionScript {

    public final app:App;

    public final dispatcher:TestDispatcher;

    public final window:Window;

    public final log:Array<String>;

    var pressed:Null<MouseButton> = null;

    var state:Null<(Window, App) -> Void> = null;

    function new(app:App, dispatcher:TestDispatcher, window:Window, log:Array<String>) {
        this.app = app;
        this.dispatcher = dispatcher;
        this.window = window;
        this.log = log;
    }

    /**
     * Creates the app in test mode (draws dirty windows when effects are flushed).
     */
    public static function testApp(dispatcher:TestDispatcher):App {
        final app = new App(dispatcher);
        app.onEffectsFlushed = drawDirtyWindows;
        return app;
    }

    static function drawDirtyWindows(app:App):Void {
        for (window in Window.windows.copy()) {
            if (window.app == app && window.dirty && !window.isDestroyed()) {
                window.draw();
            }
        }
    }

    /**
     * Opens the window with the view built by `build`, activates it and draws once.
     */
    public static function open<V:Model & Render>(app:App, dispatcher:TestDispatcher, log:Array<String>, build:(Window, Context<V>) -> V):{script:InteractionScript, view:Entity<V>} {
        var view:Entity<V> = null;
        final window = Window.open(app, {width: 512, height: 512, scaleFactor: 2, autoDraw: false, active: false, bindInput: false}, (window, cx) -> {
            view = cx.newEntity((viewCx:Context<V>) -> build(window, viewCx));
            return view;
        });
        // `open_window` draws once
        window.draw();
        final script = new InteractionScript(app, dispatcher, window, log);
        app.update(_ -> window.setActive(true));
        script.runUntilParked();
        script.draw();
        return {script: script, view: view};
    }

    public function destroy():Void {
        window.destroy();
        app.onEffectsFlushed = null;
    }

    public function setState(state:(Window, App) -> Void):Void {
        this.state = state;
    }

    function runUntilParked():Void {
        dispatcher.runUntilParked();
        ceramic.App.app.flushImmediate();
    }

    function draw():Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        runUntilParked();
    }

    function settle():Void {
        runUntilParked();
        draw();
        if (state != null) {
            final state = this.state;
            app.update(cx -> state(window, cx));
        }
    }

    /**
     * A generic step: `f` runs inside an app update.
     */
    public function step(desc:String, f:(Window, App) -> Void):Void {
        log.push('> ' + desc);
        app.update(cx -> f(window, cx));
        settle();
    }

    /**
     * A step without refresh (`reference/src/view_cache.rs`): `f` runs inside
     * an app update (dirty windows are drawn when its effects are flushed),
     * then the dispatcher runs until parked. View caches are used.
     */
    public function stepWithoutRefresh(desc:String, f:(Window, App) -> Void):Void {
        log.push('> ' + desc);
        app.update(cx -> f(window, cx));
        runUntilParked();
    }

    function event(desc:String, input:PlatformInput):Void {
        step(desc, (window, cx) -> window.dispatchEvent(input, cx));
    }

    public function moveTo(x:Float, y:Float):Void {
        final desc = pressed != null ? 'move ${f(x)} ${f(y)} pressed=${button(pressed)}' : 'move ${f(x)} ${f(y)}';
        event(desc, new MouseMoveEvent(new Point(x, y), pressed, Modifiers.none()));
    }

    public function down(b:MouseButton, x:Float, y:Float, count:Int):Void {
        pressed = b;
        event('down ${button(b)} ${f(x)} ${f(y)} count=$count', new MouseDownEvent(b, new Point(x, y), Modifiers.none(), count, false));
    }

    public function up(b:MouseButton, x:Float, y:Float, count:Int):Void {
        pressed = null;
        event('up ${button(b)} ${f(x)} ${f(y)} count=$count', new MouseUpEvent(b, new Point(x, y), Modifiers.none(), count));
    }

    public function scroll(x:Float, y:Float, delta:ScrollDelta, shift:Bool):Void {
        final desc = 'scroll ${f(x)} ${f(y)} ${deltaDesc(delta)}' + (shift ? ' shift' : '');
        event(desc, new ScrollEvent(new Point(x, y), delta, Modifiers.of(false, false, shift)));
    }

    public function key(ks:String):Void {
        step('key $ks', (window, cx) -> {
            window.dispatchKeystroke(Keystroke.parse(ks), cx);
        });
    }

    public function keyUp(ks:String):Void {
        event('key_up $ks', new KeyUpEvent(Keystroke.parse(ks).withSimulatedIme()));
    }

    public function advance(ms:Int):Void {
        log.push('> advance ${ms}ms');
        dispatcher.advanceClock(ms / 1000.0);
        settle();
    }

/// Formatting (Rust `{:.1}`)

    /**
     * `{:.1}` of a float, like Rust (including `-0.0`).
     */
    public static function f(v:Float):String {
        final negative = v < 0 || (v == 0 && 1 / v < 0);
        final abs = Math.abs(v);
        var tenths = Math.round(abs * 10);
        // Round half to even on exact halves
        final scaled = abs * 10;
        if (scaled - Math.floor(scaled) == 0.5 && Math.floor(scaled) % 2 == 0) {
            tenths = Std.int(Math.floor(scaled));
        }
        final intPart = Std.int(tenths / 10);
        final decimal = tenths - intPart * 10;
        return (negative ? '-' : '') + intPart + '.' + decimal;
    }

    public static function pt(p:Point):String {
        return f(p.x) + ' ' + f(p.y);
    }

    public static function button(b:MouseButton):String {
        return switch b {
            case Left: 'left';
            case Right: 'right';
            case Middle: 'middle';
            case _: 'other';
        }
    }

    public static function keystroke(k:Keystroke):String {
        final m = k.modifiers;
        var s = '';
        if (m.control) s += 'ctrl-';
        if (m.alt) s += 'alt-';
        if (m.shift) s += 'shift-';
        if (m.platform) s += 'cmd-';
        if (m.function_) s += 'fn-';
        return s + k.key;
    }

    public static function deltaDesc(delta:ScrollDelta):String {
        return switch delta {
            case Pixels(p): 'pixels ' + pt(p);
            case Lines(l): 'lines ${f(l.x)} ${f(l.y)}';
        }
    }

/// Listener builders shared by the scenarios

    public static function downLogger(log:Array<String>, name:String):(MouseDownEvent, Window, App) -> Void {
        return (e, _, _) -> log.push('$name ${button(e.button)} ${pt(e.position)} count=${e.clickCount}');
    }

    public static function upLogger(log:Array<String>, name:String):(MouseUpEvent, Window, App) -> Void {
        return (e, _, _) -> log.push('$name ${button(e.button)} ${pt(e.position)} count=${e.clickCount}');
    }

    public static function moveLogger(log:Array<String>, name:String):(MouseMoveEvent, Window, App) -> Void {
        return (e, _, _) -> log.push('$name ${pt(e.position)}');
    }

    public static function hoverLogger(log:Array<String>, name:String):(Bool, Window, App) -> Void {
        return (hovered, _, _) -> log.push('$name hover $hovered');
    }

    public static function clickLogger(log:Array<String>, name:String):(ClickEvent, Window, App) -> Void {
        return (e, _, _) -> log.push('$name click count=${e.clickCount()} keyboard=${e.isKeyboard()} standard=${e.standardClick()} ${pt(e.position())}');
    }

    public static function keyDownLogger(log:Array<String>, name:String):(KeyDownEvent, Window, App) -> Void {
        return (e, _, _) -> log.push('$name ${keystroke(e.keystroke)}');
    }

    public static function keyUpLogger(log:Array<String>, name:String):(KeyUpEvent, Window, App) -> Void {
        return (e, _, _) -> log.push('$name ${keystroke(e.keystroke)}');
    }

}

/**
 * A view rendering through a function.
 */
class ScriptView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}

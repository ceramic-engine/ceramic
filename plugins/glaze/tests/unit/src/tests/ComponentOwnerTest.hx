package tests;

import glaze.AnyView;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * A persistent `glaze.Component` is a `tracker.Owner`: `this` is a valid owner
 * for tracker events, timers, tweens and immediates. The subscriptions live as
 * long as the component is in the tree, and the destroy handlers receive the
 * component.
 */
class ComponentOwnerTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        OwnerCounters.reset();
        flushImmediate();
    }

    override function teardown() {
        for (window in windows) {
            window.destroy();
        }
        windows.resize(0);
        flushImmediate();
    }

    inline function flushImmediate():Void {
        ceramic.App.app.flushImmediate();
    }

    function openWindow(root:AnyView):Window {
        final window = Window.open(app, {width: 400, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false, viewCaching: true}, (_, _) -> root);
        windows.push(window);
        return window;
    }

    function view(render:(Window, Context<Dynamic>) -> IntoElement):Entity<OwnerParentView> {
        return app.newEntity((_:Context<OwnerParentView>) -> new OwnerParentView(render));
    }

    /** Draws the dirty windows, like the GlazeSystem does every frame. */
    function frame():Void {
        flushImmediate();
        for (window in windows) {
            window.drawIfDirty();
        }
    }

    /** Advances Ceramic's clock and runs the timers that are due. */
    function advanceTimers(seconds:Float):Void {
        @:privateAccess ceramic.Timer.now += seconds;
        @:privateAccess ceramic.Timer.flush();
    }

    function testPersistentComponentOwnsAModelEventHandler() {
        final toggle = app.newEntity(_ -> new OwnerToggle());
        final feed = new Feed();
        final parent = view((_, cx) -> div().child(toggle.read(cx).on ? OwnerTicker.component().feed(feed) : null));
        openWindow(parent);
        frame();
        assertEquals(1, OwnerCounters.tickersInit);

        feed.emitMessage('a');
        assertEquals('a', OwnerCounters.messages.join(','), 'the handler bound with `this` runs');

        toggle.read(app).on = false;
        frame();
        assertEquals(1, OwnerCounters.tickersDestroyed);
        assertTrue(OwnerCounters.lastDestroyedOwner != null, 'the destroy handler ran');
        assertTrue(Std.isOfType(OwnerCounters.lastDestroyedOwner, OwnerTicker), 'the destroy handler receives the component');

        feed.emitMessage('b');
        assertEquals('a', OwnerCounters.messages.join(','), 'no more handler once the component left the tree');
    }

    function testPersistentComponentOwnsATimer() {
        final toggle = app.newEntity(_ -> new OwnerToggle());
        final feed = new Feed();
        final parent = view((_, cx) -> div().child(toggle.read(cx).on ? OwnerTicker.component().feed(feed) : null));
        openWindow(parent);
        frame();

        advanceTimers(1);
        advanceTimers(1);
        assertEquals(2, OwnerCounters.ticks, 'the interval owned by the component runs');

        toggle.read(app).on = false;
        frame();
        advanceTimers(1);
        advanceTimers(1);
        assertEquals(2, OwnerCounters.ticks, 'the interval stops once the component left the tree');
    }

    function testEmitterDestroyedFirstUnbindsFromTheComponent() {
        final feed = new Feed();
        final parent = view((_, cx) -> div().child(OwnerTicker.component().feed(feed)));
        openWindow(parent);
        frame();
        final ticker = OwnerCounters.live[0];
        final before:Array<(tracker.Owner) -> Void> = @:privateAccess ticker.__destroyHandlers;
        final bound = before == null ? 0 : before.length;

        feed.destroy();
        final after:Array<(tracker.Owner) -> Void> = @:privateAccess ticker.__destroyHandlers;
        assertEquals(bound - 1, after == null ? 0 : after.length, 'the destroyed emitter removed its handler from the component');
        assertFalse(ticker.destroyed);
    }

    function testOnceDestroyWithAnOwnerGoesAwayWithIt() {
        final feed = new Feed();
        final parent = view((_, cx) -> div().child(OwnerTicker.component().feed(feed)));
        final window = openWindow(parent);
        frame();
        final ticker = OwnerCounters.live[0];
        final other = new Feed();
        var calls = 0;
        ticker.onceDestroy(other, _ -> calls++);
        other.destroy();
        window.destroy();
        windows.remove(window);
        flushImmediate();
        assertEquals(1, OwnerCounters.tickersDestroyed);
        assertEquals(0, calls, 'the destroy handler went away with its own owner');
    }

    function testKitRootIsAnOwner() {
        final feed = new Feed();
        final window = Window.open(app, {width: 400, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false, viewCaching: true}, (window, cx) -> {
            return Root.component().child(cx.newEntity((_:Context<OwnerParentView>) -> new OwnerParentView((_, _) -> div().child('content'))));
        });
        windows.push(window);
        frame();
        final root = Root.tryRead(window);
        assertTrue(root != null, 'the root view is a Root');
        var received = 0;
        var ticks = 0;
        feed.onMessage(root, _ -> received++);
        ceramic.Timer.interval(root, 1, () -> ticks++);
        feed.emitMessage('a');
        advanceTimers(1);
        assertEquals(1, received);
        assertEquals(1, ticks);

        window.destroy();
        windows.remove(window);
        flushImmediate();
        assertTrue(root.destroyed, 'the Root is destroyed with its window');
        feed.emitMessage('b');
        advanceTimers(1);
        assertEquals(1, received, 'no handler once the Root is destroyed');
        assertEquals(1, ticks, 'no timer once the Root is destroyed');
    }

    function testComponentIsDestroyedWithTheWindow() {
        final feed = new Feed();
        final parent = view((_, cx) -> div().child(OwnerTicker.component().feed(feed)));
        final window = openWindow(parent);
        frame();
        assertFalse(OwnerCounters.live[0].destroyed);

        window.destroy();
        windows.remove(window);
        flushImmediate();
        assertEquals(1, OwnerCounters.tickersDestroyed);
        feed.emitMessage('x');
        assertEquals(0, OwnerCounters.messages.length);
    }

}

class OwnerParentView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}

class OwnerToggle extends Model {

    @observe public var on:Bool = true;

    public function new() {
        super();
    }

}

class Feed extends ceramic.Entity {

    @event public function message(text:String);

    public function new() {
        super();
    }

}

class OwnerCounters {

    public static var tickersInit = 0;
    public static var tickersDestroyed = 0;
    public static var ticks = 0;
    public static var messages:Array<String> = [];
    public static var live:Array<OwnerTicker> = [];
    public static var lastDestroyedOwner:tracker.Owner = null;

    public static function reset() {
        tickersInit = 0;
        tickersDestroyed = 0;
        ticks = 0;
        messages = [];
        live = [];
        lastDestroyedOwner = null;
    }

}

/**
 * A persistent component (it has `init()` and `destroy()`) subscribing with
 * `this` as the owner.
 */
class OwnerTicker extends Component {

    @prop(unobserved) var feed:Feed = null;

    public function new() {
        super();
    }

    override function init(window:Window, cx:App) {
        OwnerCounters.tickersInit++;
        OwnerCounters.live.push(this);
        feed.onMessage(this, text -> OwnerCounters.messages.push(text));
        ceramic.Timer.interval(this, 1, () -> OwnerCounters.ticks++);
        onceDestroy(null, owner -> OwnerCounters.lastDestroyedOwner = owner);
    }

    override function destroy() {
        OwnerCounters.tickersDestroyed++;
        OwnerCounters.live.remove(this);
    }

    function render(window:Window, cx:App):IntoElement {
        return div().child('tick');
    }

}

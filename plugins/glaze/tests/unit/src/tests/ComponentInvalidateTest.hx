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
import testing.TestCase;

import glaze.Prelude.*;

/**
 * `Component.invalidate()`: a component whose rendering reads data tracker
 * does not see (a plain field here) says its cached rendering is stale. A
 * persistent component renders again; a stateless one makes the view or
 * persistent component it renders in render again. Siblings stay cached.
 */
class ComponentInvalidateTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        InvalidateProbe.reset();
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

    function view(render:(Window, Context<Dynamic>) -> IntoElement):Entity<InvalidateParentView> {
        return app.newEntity((_:Context<InvalidateParentView>) -> new InvalidateParentView(render));
    }

    /** Draws the dirty windows, like the GlazeSystem does every frame. */
    function frame():Void {
        flushImmediate();
        for (window in windows) {
            window.drawIfDirty();
        }
    }

/// Persistent

    function testPersistentComponentRendersAgainAfterInvalidate() {
        countsRenders();
        final parent = view((_, _) -> div()
            .child(PlainPersistent.component().at('a').name('a'))
            .child(PlainPersistent.component().at('b').name('b'))
        );
        openWindow(parent);
        frame();
        final a = InvalidateProbe.persistent.get('a');
        final b = InvalidateProbe.persistent.get('b');
        assertEquals(1, a.renders);
        assertEquals(1, b.renders);
        assertEquals(1, parent.read(app).renders);

        // A plain field: tracker does not see the change, the cache stays
        a.plain = 'changed';
        frame();
        assertEquals(1, a.renders, 'a plain field change alone renders nothing');
        assertEquals('a:', a.shown);

        a.invalidate();
        frame();
        assertEquals(2, a.renders, 'invalidate() renders the component again');
        assertEquals('a:changed', a.shown);
        assertEquals(1, b.renders, 'its sibling stays cached');

        // The same as a change of an observable it read
        final parentRenders = parent.read(app).renders;
        a.tracked++;
        frame();
        assertEquals(3, a.renders);
        assertEquals(1, b.renders);
        final trackedDelta = parent.read(app).renders - parentRenders;
        final beforeInvalidate = parent.read(app).renders;
        a.invalidate();
        frame();
        assertEquals(4, a.renders);
        assertEquals(1, b.renders);
        // Its size is the same: rendered alone, in place (a tracked change
        // that keeps its size does the same). `glaze_verify_layout` lays the
        // whole tree out again from scratch after each layout: the caches it
        // leaves can make this frame a full one (the same frame)
        #if !glaze_verify_layout
        assertEquals(0, parent.read(app).renders - beforeInvalidate, 'the ancestors do not render');
        assertTrue(trackedDelta <= 1);
        assertEquals(1, windows[0].inPlaceViewCount);
        #end

        // Nothing else to draw
        frame();
        assertEquals(4, a.renders);
    }

    function testRepeatedInvalidateRendersOnce() {
        final parent = view((_, _) -> div().child(PlainPersistent.component().at('a').name('a')));
        openWindow(parent);
        frame();
        final a = InvalidateProbe.persistent.get('a');
        a.plain = 'x';
        a.invalidate();
        a.plain = 'y';
        a.invalidate();
        a.invalidate();
        frame();
        assertEquals(2, a.renders, 'one render for the calls made before the frame');
        assertEquals('a:y', a.shown);
        frame();
        assertEquals(2, a.renders);
    }

    function testInvalidateDuringItsOwnRenderIsIgnored() {
        final parent = view((_, _) -> div().child(PlainPersistent.component().at('a').name('a')));
        final window = openWindow(parent);
        InvalidateProbe.invalidateInRender = true;
        frame();
        final a = InvalidateProbe.persistent.get('a');
        assertEquals(1, a.renders);
        frame();
        frame();
        assertEquals(1, a.renders, 'the render in progress is the one drawn: no loop');
        assertFalse(window.dirty);
        InvalidateProbe.invalidateInRender = false;
        a.plain = 'later';
        a.invalidate();
        frame();
        assertEquals(2, a.renders);
        assertEquals('a:later', a.shown);
    }

    function testInvalidateAfterDestroyDoesNothing() {
        final toggle = new InvalidateToggle();
        final parent = view((_, _) -> div()
            .child(toggle.on ? PlainPersistent.component().at('a').name('a') : null)
            .child(PlainPersistent.component().at('b').name('b'))
        );
        final window = openWindow(parent);
        frame();
        final a = InvalidateProbe.persistent.get('a');
        final b = InvalidateProbe.persistent.get('b');
        toggle.on = false;
        frame();
        assertTrue(a.destroyed);
        final parentRenders = parent.read(app).renders;
        final bRenders = b.renders;
        a.invalidate();
        frame();
        assertFalse(window.dirty);
        assertEquals(1, a.renders);
        assertEquals(bRenders, b.renders);
        assertEquals(parentRenders, parent.read(app).renders, 'nothing renders');
    }

    function testInvalidateBeforeAnyRenderDoesNothing() {
        final component = new PlainPersistent();
        component.invalidate();
        final stateless = new PlainStateless();
        stateless.invalidate();
        assertEquals(0, component.renders);
    }

/// Stateless

    function testStatelessComponentInAViewRendersTheView() {
        countsRenders();
        final parent = view((_, _) -> div()
            .child(PlainStateless.component().name('s'))
            .child(PlainPersistent.component().at('b').name('b'))
        );
        final other = view((_, _) -> div().child(PlainStateless.component().name('other')));
        openWindow(view((_, _) -> div().child(parent).child(other)));
        frame();
        final s = InvalidateProbe.stateless.get('s');
        final b = InvalidateProbe.persistent.get('b');
        assertEquals(1, parent.read(app).renders);
        assertEquals(1, other.read(app).renders);
        assertEquals(1, InvalidateProbe.statelessRenders.get('s'));

        InvalidateProbe.statelessPlain = 'changed';
        frame();
        assertEquals(1, InvalidateProbe.statelessRenders.get('s'), 'a plain value change alone renders nothing');

        s.invalidate();
        frame();
        assertEquals(2, parent.read(app).renders, 'the enclosing view renders again');
        assertEquals(2, InvalidateProbe.statelessRenders.get('s'));
        assertEquals('s:changed', InvalidateProbe.statelessShown.get('s'));
        assertEquals(1, b.renders, 'a persistent sibling stays cached');
        assertEquals(1, other.read(app).renders, 'a sibling view stays cached');
        assertEquals(1, InvalidateProbe.statelessRenders.get('other'));

        // The instance of the last render, or one kept from an earlier one
        // (a closure of a reused cached view): the same view renders
        s.invalidate();
        InvalidateProbe.stateless.get('s').invalidate();
        frame();
        assertEquals(3, parent.read(app).renders, 'one render');
        frame();
        assertEquals(3, parent.read(app).renders);
    }

    function testStatelessComponentInAPersistentOneRendersIt() {
        countsRenders();
        final parent = view((_, _) -> div()
            .child(PlainPersistent.component().at('host').name('host').inner('s'))
            .child(PlainPersistent.component().at('b').name('b'))
        );
        openWindow(parent);
        frame();
        final host = InvalidateProbe.persistent.get('host');
        final b = InvalidateProbe.persistent.get('b');
        final s = InvalidateProbe.stateless.get('s');
        assertEquals(1, host.renders);
        assertEquals(1, InvalidateProbe.statelessRenders.get('s'));

        InvalidateProbe.statelessPlain = 'changed';
        s.invalidate();
        frame();
        assertEquals(2, host.renders, 'the persistent component it renders in renders again');
        assertEquals(2, InvalidateProbe.statelessRenders.get('s'));
        assertEquals('s:changed', InvalidateProbe.statelessShown.get('s'));
        assertEquals(1, b.renders, 'the sibling stays cached');
    }

    function testStatelessInvalidateDuringRenderIsIgnored() {
        final parent = view((_, _) -> div().child(PlainStateless.component().name('s')));
        final window = openWindow(parent);
        InvalidateProbe.invalidateInRender = true;
        frame();
        frame();
        assertEquals(1, parent.read(app).renders);
        assertFalse(window.dirty);
    }

    function testStatelessInvalidateAfterItsViewIsGone() {
        final toggle = new InvalidateToggle();
        final inner = view((_, _) -> div().child(PlainStateless.component().name('s')));
        final root = view((_, _) -> div().child(toggle.on ? inner : null));
        final window = openWindow(root);
        frame();
        final s = InvalidateProbe.stateless.get('s');
        toggle.on = false;
        frame();
        inner.read(app).destroy();
        final rootRenders = root.read(app).renders;
        s.invalidate();
        frame();
        assertEquals(rootRenders, root.read(app).renders);
        assertFalse(window.dirty);
    }

}

class InvalidateProbe {

    public static var persistent:Map<String, PlainPersistent> = new Map();

    public static var stateless:Map<String, PlainStateless> = new Map();

    public static var statelessRenders:Map<String, Int> = new Map();

    public static var statelessShown:Map<String, String> = new Map();

    /** Read by the stateless components, not observable */
    public static var statelessPlain:String = '';

    public static var invalidateInRender:Bool = false;

    public static function reset():Void {
        persistent = new Map();
        stateless = new Map();
        statelessRenders = new Map();
        statelessShown = new Map();
        statelessPlain = '';
        invalidateInRender = false;
    }

}

class InvalidateParentView extends Model implements Render {

    public var renders:Int = 0;

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders++;
        return renderFn(window, cx);
    }

}

class InvalidateToggle extends Model {

    @observe public var on:Bool = true;

    public function new() {
        super();
    }

}

/**
 * A persistent component showing a plain field (not observable) and an
 * observable one; `inner` places a `PlainStateless` of that name inside it.
 */
@persist
class PlainPersistent extends Component {

    @prop public var name:String = '';

    @prop public var inner:String = null;

    @observe public var tracked:Int = 0;

    public var plain:String = '';

    public var renders:Int = 0;

    public var shown:String = '';

    override function init(window:Window, cx:App) {
        InvalidateProbe.persistent.set(name, this);
    }

    function render(window:Window, cx:App):IntoElement {
        renders++;
        shown = '$name:$plain';
        if (InvalidateProbe.invalidateInRender) {
            invalidate();
        }
        return div().child('$shown $tracked').child(inner != null ? PlainStateless.component().name(inner) : null);
    }

}

/**
 * A stateless component showing a plain static value.
 */
class PlainStateless extends Component {

    @prop public var name:String = '';

    function render(window:Window, cx:App):IntoElement {
        InvalidateProbe.stateless.set(name, this);
        final count = InvalidateProbe.statelessRenders.get(name);
        InvalidateProbe.statelessRenders.set(name, count == null ? 1 : count + 1);
        final shown = '$name:${InvalidateProbe.statelessPlain}';
        InvalidateProbe.statelessShown.set(name, shown);
        if (InvalidateProbe.invalidateInRender) {
            invalidate();
        }
        return div().child(shown);
    }

}

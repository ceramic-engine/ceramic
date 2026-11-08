package tests;

import glaze.AnyView;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Glaze;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;

import glaze.Prelude.*;

class GlazeTest extends TestCase {

    var app:App;

    var glazes:Array<Glaze> = [];

    override function setup() {
        app = new App(new TestDispatcher());
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (glaze in glazes) {
            if (!glaze.destroyed) glaze.destroy();
        }
        glazes = [];
        ceramic.App.app.flushImmediate();
    }

    function create(?width:Float, ?height:Float):Glaze {
        final glaze = new Glaze(
            (window, cx) -> cx.newEntity((_:Context<GlazeTestView>) -> new GlazeTestView()),
            width != null ? {width: width, height: height, autoDraw: false} : {autoDraw: false},
            app
        );
        glazes.push(glaze);
        return glaze;
    }

    function testPluginIsAvailable() {
        assertEquals('0.0.1', glaze.Glaze.VERSION);
    }

    /**
     * `new Glaze(...)` takes the root view directly: a `Render` model, an
     * `Entity<T>` of one, an `AnyView` or a `Component`, besides the
     * `(window, cx) -> AnyView` builder.
     */
    function testAcceptsAViewOrAComponentAsItsRoot() {
        final view = new GlazeTestView();
        final fromRender = new Glaze(view, {autoDraw: false}, app);
        glazes.push(fromRender);
        assertTrue((fromRender.window.rootView() : Model) == view, 'the Render model is the root view');

        final entity = app.newEntity((_:Context<GlazeTestView>) -> new GlazeTestView());
        final fromEntity = new Glaze(entity, {autoDraw: false}, app);
        glazes.push(fromEntity);
        assertEquals(entity.entityId(), fromEntity.window.rootView().entityId());

        final anyView:AnyView = entity;
        final fromAnyView = new Glaze(anyView, {autoDraw: false}, app);
        glazes.push(fromAnyView);
        assertEquals(entity.entityId(), fromAnyView.window.rootView().entityId());

        final fromComponent = new Glaze(GlazeTestComponent.component().label('root'), {autoDraw: false}, app);
        glazes.push(fromComponent);
        final host:Model = fromComponent.window.rootView();
        assertTrue(Std.isOfType(host, glaze.ComponentBuilder.ComponentHost), 'a component is drawn by its host entity');
        final instance:GlazeTestComponent = cast (cast host : glaze.ComponentBuilder.ComponentHost).instance;
        assertEquals('root', @:privateAccess instance.labelProp);
        assertEquals(app, @:privateAccess host.slot().app, 'the host is an entity of the app of the window');
        assertTrue(instance.initialized, 'a persistent component is initialized with the window');
    }

    function testOpensAWindowShownByTheVisual() {
        final glaze = create(300, 200);
        assertTrue(glaze.window != null);
        assertTrue(glaze.window.rootView() != null);
        assertTrue(glaze.window.renderable.parent == glaze);
        assertEquals(300.0, glaze.width);
        assertEquals(200.0, glaze.height);
        assertEquals(300.0, glaze.window.viewportSize().width);
        assertEquals(200.0, glaze.window.viewportSize().height);
    }

    function testDefaultSizeComesFromTheWindowOptions() {
        final glaze = create();
        assertEquals(512.0, glaze.width);
        assertEquals(512.0, glaze.height);
        assertEquals(512.0, glaze.window.viewportSize().width);
    }

    function testResizingTheVisualResizesTheWindow() {
        final glaze = create(300, 200);
        glaze.size(640, 480);
        assertEquals(640.0, glaze.window.viewportSize().width);
        assertEquals(480.0, glaze.window.viewportSize().height);
        assertEquals(640.0, glaze.window.renderable.width);
        assertEquals(480.0, glaze.window.renderable.height);
        glaze.width = 100;
        assertEquals(100.0, glaze.window.viewportSize().width);
        assertEquals(480.0, glaze.window.viewportSize().height);
    }

    function testTheWindowDrawsTheRootView() {
        final glaze = create(300, 200);
        glaze.window.draw();
        assertTrue(glaze.window.renderedScene().quads.length > 0);
    }

    function testDestroyingTheVisualClosesTheWindow() {
        final glaze = create(300, 200);
        final window = glaze.window;
        glaze.destroy();
        assertTrue(window.isDestroyed());
        assertEquals(null, glaze.window);
    }

}

/** A persistent component (it overrides `init`) with one prop. */
class GlazeTestComponent extends Component {

    @prop var label:String = '';

    public var initialized:Bool = false;

    override function init(window:Window, cx:App):Void {
        initialized = true;
    }

    function render(window:Window, cx:App):IntoElement {
        return div().size(px(50)).child(label);
    }

}

class GlazeTestView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().size(px(50)).bg(red());
    }

}

package tests;

import glaze.App;
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

class GlazeTestView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().size(px(50)).bg(red());
    }

}

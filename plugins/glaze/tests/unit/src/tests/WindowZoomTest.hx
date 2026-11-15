package tests;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.platform.CeramicWindowOperations;
import glaze.scene.Quad;
import testing.InteractionScript.ScriptView;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Port addition (no GPUI equivalent): the zoom of a window
 * (`Window.setZoom`, `WindowOptions.zoom`), like the zoom of a web page.
 *
 * The expected values are written by hand from the definition: the scale
 * factor is the scale factor of the platform window times the zoom, the
 * viewport is the size of the window on the screen divided by the zoom, and
 * a zoomed window draws what a window of that viewport draws at that scale
 * factor (compared with such a window, opened without zoom).
 */
class WindowZoomTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (window in windows) window.destroy();
        windows.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement, width:Float, height:Float, scaleFactor:Float, zoom:Float = 1.0):Window {
        final root:AnyView = app.newEntity((_:Context<ScriptView>) -> new ScriptView(render));
        final window = Window.open(app, {width: width, height: height, scaleFactor: scaleFactor, zoom: zoom, autoDraw: false, active: false, bindInput: false},
            (_, _) -> root);
        windows.push(window);
        app.update(_ -> window.draw());
        ceramic.App.app.flushImmediate();
        return window;
    }

    function frame():Void {
        ceramic.App.app.flushImmediate();
        for (window in windows) app.update(_ -> window.drawIfDirty());
    }

    static function content(window:Window, _:Context<Dynamic>):IntoElement {
        return div().relative().sizeFull().bg(hsla(0.6, 1, 0.5, 1))
            .child(div().absolute().left(px(10)).top(px(20)).w(px(100)).h(px(50)).bg(hsla(0.1, 1, 0.5, 1)))
            .child(div().absolute().left(px(10)).top(px(80)).fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).textColor(hsla(0, 0, 0, 1)).child('Zoom'));
    }

    static function quad(window:Window, h:Float):String {
        for (quad in window.renderedScene().quads) {
            if (quad.backgroundSolidA > 0 && Math.abs(quad.backgroundSolidH - h) < 1e-6)
                return '${quad.boundsX},${quad.boundsY} ${quad.boundsWidth}x${quad.boundsHeight}';
        }
        return 'none';
    }

    static function sprites(window:Window):String {
        return [for (s in window.renderedScene().monochromeSprites) '${s.boundsX},${s.boundsY} ${s.boundsWidth}x${s.boundsHeight} ${s.tileWidth}x${s.tileHeight}'].join(' | ');
    }

    function testViewportAndScaleFactor() {
        final window = open(content, 600, 400, 2);
        assertEquals(1.0, window.zoom());
        assertEquals('600x400', '${window.viewportSize().width}x${window.viewportSize().height}');
        assertEquals(2.0, window.scaleFactor());

        // Zoom 2: half the logical pixels, twice the device pixels per logical pixel
        window.setZoom(2);
        assertEquals(2.0, window.zoom());
        assertEquals('300x200', '${window.viewportSize().width}x${window.viewportSize().height}');
        assertEquals(4.0, window.scaleFactor());
        // The window keeps its size on the screen, shown at the density of the screen
        assertEquals(600.0, window.renderable.width);
        assertEquals(400.0, window.renderable.height);
        frame();
        assertEquals(2.0, window.renderable.sceneScale);
        // The root fills the viewport: 300x200 logical pixels, 1200x800 device pixels
        assertEquals('0,0 1200x800', quad(window, 0.6));
        // (10, 20) 100x50 at 4 device pixels per logical pixel
        assertEquals('40,80 400x200', quad(window, 0.1));

        // Zoom 0.5: twice the logical pixels
        window.setZoom(0.5);
        assertEquals('1200x800', '${window.viewportSize().width}x${window.viewportSize().height}');
        assertEquals(1.0, window.scaleFactor());
        frame();
        assertEquals('0,0 1200x800', quad(window, 0.6));
        assertEquals('10,20 100x50', quad(window, 0.1));

        // 150 %: 600 / 1.5 = 400
        window.setZoom(1.5);
        assertEquals('400x${400 / 1.5}', '${window.viewportSize().width}x${window.viewportSize().height}');
        assertEquals(3.0, window.scaleFactor());

        assertRaises(() -> window.setZoom(0));
        assertRaises(() -> window.setZoom(-1));
        assertRaises(() -> window.setZoom(Math.NaN));
        assertEquals(1.5, window.zoom());
    }

    function testAZoomedWindowDrawsLikeAWindowOfThatViewportAndScale() {
        // 600x400 on the screen at density 2, zoomed twice: a 300x200 window at scale factor 4
        final zoomed = open(content, 600, 400, 2, 2);
        final reference = open(content, 300, 200, 4);
        assertEquals(4.0, zoomed.scaleFactor());
        assertEquals('300x200', '${zoomed.viewportSize().width}x${zoomed.viewportSize().height}');
        assertEquals(quad(reference, 0.6), quad(zoomed, 0.6));
        assertEquals(quad(reference, 0.1), quad(zoomed, 0.1));
        // The text is rasterized at the scale factor with the zoom: the same glyph sprites and tiles
        assertEquals(4, zoomed.renderedScene().monochromeSprites.length);
        assertEquals(sprites(reference), sprites(zoomed));
        // and larger than without zoom
        final plain = open(content, 600, 400, 2);
        assertTrue(zoomed.renderedScene().monochromeSprites[0].tileHeight > plain.renderedScene().monochromeSprites[0].tileHeight * 1.8);

        // The same through setZoom, and back
        plain.setZoom(2);
        frame();
        assertEquals(sprites(reference), sprites(plain));
        assertEquals(quad(reference, 0.1), quad(plain, 0.1));
        final never = open(content, 600, 400, 2);
        plain.setZoom(1);
        frame();
        assertEquals(sprites(never), sprites(plain));
        assertEquals(quad(never, 0.6), quad(plain, 0.6));
        assertEquals(quad(never, 0.1), quad(plain, 0.1));
        assertEquals(2.0, plain.scaleFactor());
    }

    function testResizeAndBoundsObservers() {
        final window = open(content, 600, 400, 2, 1.5);
        var observed = 0;
        final observer = @:privateAccess window.newBoundsObserver((_, _) -> {
            observed++;
            return true;
        });
        observer.activate();
        final subscription = observer.subscription;
        // The size on the screen changes: the viewport is that size divided by the zoom
        window.resize(900, 600);
        assertEquals('600x400', '${window.viewportSize().width}x${window.viewportSize().height}');
        assertEquals(900.0, window.renderable.width);
        assertEquals(1, observed);
        // A zoom changes the viewport like a resize
        window.setZoom(3);
        assertEquals('300x200', '${window.viewportSize().width}x${window.viewportSize().height}');
        assertEquals(2, observed);
        // The same zoom again: nothing
        window.setZoom(3);
        assertEquals(2, observed);
        // A change of the scale factor of the platform window keeps the zoom
        window.setScaleFactor(1);
        assertEquals(3.0, window.scaleFactor());
        assertEquals('300x200', '${window.viewportSize().width}x${window.viewportSize().height}');
        subscription.dispose();
    }

    function testMousePositions() {
        var clicks:Array<String> = [];
        final window = open((_, _) -> div().relative().sizeFull()
            .child(div().id('button').absolute().left(px(100)).top(px(50)).w(px(40)).h(px(20))
                .onClick((event, _, _) -> clicks.push('${event.position().x},${event.position().y}'))), 600, 400, 2, 2);
        final point = new ceramic.Point();
        // The renderable of the test window sits at the screen origin: screen
        // (300, 200) is the middle of the window, (150, 100) in its viewport
        window.screenToWindow(300, 200, point);
        assertEquals('150,100', '${point.x},${point.y}');
        window.windowToScreen(150, 100, point);
        assertEquals('300,200', '${point.x},${point.y}');
        // The button (100, 50) 40x20 is on the screen at (200, 100) 80x40: a
        // press at screen (210, 110) is at (105, 55) in the window
        window.screenToWindow(210, 110, point);
        final position = new Point(point.x, point.y);
        app.update(cx -> {
            window.dispatchEvent(new MouseMoveEvent(position, null, Modifiers.none()), cx);
            window.dispatchEvent(new MouseDownEvent(Left, position, Modifiers.none(), 1, false), cx);
            window.dispatchEvent(new MouseUpEvent(Left, position, Modifiers.none(), 1), cx);
        });
        assertEquals('105,55', clicks.join(' '));

        // Without zoom the conversions are the renderable's own
        final plain = open(content, 600, 400, 2);
        plain.screenToWindow(300, 200, point);
        assertEquals('300,200', '${point.x},${point.y}');
        plain.windowToScreen(150, 100, point);
        assertEquals('150,100', '${point.x},${point.y}');
    }

    function testRegionsGivenToThePlatformFollowTheZoom() {
        // A drag bar (0, 0) 300x40 with a button (100, 8) 60x24, zoomed twice
        final window = open((_, _) -> div().relative().sizeFull().child(
            div().id('bar').absolute().left(px(0)).top(px(0)).w(px(300)).h(px(40)).windowControlArea(Drag)
                .child(div().id('button').absolute().left(px(100)).top(px(8)).w(px(60)).h(px(24)).onClick((_, _, _) -> {}))), 600, 400, 2, 2);
        final flat = app.update(_ -> CeramicWindowOperations.hitRegions(window, new ceramic.Point()));
        assertEquals('0,0,600,80,1,200,16,120,48,0', flat.join(','));
    }

}

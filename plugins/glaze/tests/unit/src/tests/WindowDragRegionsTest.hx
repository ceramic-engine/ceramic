package tests;

import ceramic.WindowHitKind;
import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.WindowControlArea;
import glaze.platform.CeramicWindowOperations;
import testing.InteractionScript.ScriptView;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Port addition (no GPUI equivalent): the regions a window publishes to the
 * native window (`CeramicWindowOperations.hitRegions`) have holes where an
 * interactive element is drawn above a window drag area, so a button in a
 * title bar gets its click instead of moving the window.
 *
 * The expected rectangles are the layout of the test trees, written by hand
 * (fixed sizes and absolute positions): the test window's renderable sits at
 * the screen origin, so window and screen coordinates are the same.
 */
class WindowDragRegionsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (window in windows) window.destroy();
        windows.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement, viewCaching:Bool = false):Window {
        final root:AnyView = app.newEntity((_:Context<ScriptView>) -> new ScriptView(render));
        final window = Window.open(app, {width: 600, height: 400, scaleFactor: 2, autoDraw: false, active: false, bindInput: false, viewCaching: viewCaching},
            (_, _) -> root);
        windows.push(window);
        app.update(_ -> window.draw());
        ceramic.App.app.flushImmediate();
        return window;
    }

    /** The regions as `kind:x,y,w,h` joined by spaces. */
    function regions(window:Window):String {
        final flat = app.update(_ -> CeramicWindowOperations.hitRegions(window, new ceramic.Point()));
        final out:Array<String> = [];
        var i = 0;
        while (i + 4 < flat.length) {
            final kind = Std.int(flat[i + 4]);
            final name = kind == (WindowHitKind.DRAGGABLE:Int) ? 'drag' : kind == (WindowHitKind.NORMAL:Int) ? 'normal' : 'kind$kind';
            out.push('$name:${flat[i]},${flat[i + 1]},${flat[i + 2]},${flat[i + 3]}');
            i += 5;
        }
        return out.join(' ');
    }

    /** A 600x40 drag bar at the top of the window, with `children` positioned in it. */
    static function bar(children:Array<IntoElement>):glaze.Div {
        final bar = div().id('bar').relative().w(px(600)).h(px(40)).windowControlArea(Drag);
        for (child in children) bar.child(child);
        return bar;
    }

    static function box(id:String, left:Float, top:Float, width:Float, height:Float):glaze.Div {
        return div().id(id).absolute().left(px(left)).top(px(top)).w(px(width)).h(px(height));
    }

    function testADragAreaAloneIsOneDraggableRegion() {
        final window = open((_, _) -> div().w(px(600)).h(px(400)).child(bar([])));
        assertEquals('drag:0,0,600,40', regions(window));
    }

    function testAClickableElementAboveTheDragAreaIsAHole() {
        final window = open((_, _) -> div().w(px(600)).h(px(400)).child(bar([
            box('button', 100, 8, 60, 24).onClick((_, _, _) -> {}),
            box('down', 200, 8, 30, 24).onMouseDown(Left, (_, _, _) -> {}),
            box('up', 240, 8, 30, 24).onMouseUp(Left, (_, _, _) -> {}),
            box('any', 280, 8, 30, 24).onAnyMouseDown((_, _, _) -> {})
        ])));
        assertEquals('drag:0,0,600,40 normal:100,8,60,24 normal:200,8,30,24 normal:240,8,30,24 normal:280,8,30,24', regions(window));
    }

    function testElementsThatDoNotAnswerTheLeftButtonStayDraggable() {
        final window = open((_, _) -> div().w(px(600)).h(px(400)).child(bar([
            box('hover', 100, 8, 60, 24).hover(s -> s.opacity(0.5)),
            box('right', 200, 8, 30, 24).onMouseDown(Right, (_, _, _) -> {}),
            box('move', 240, 8, 30, 24).onMouseMove((_, _, _) -> {}),
            box('out', 280, 8, 30, 24).onMouseDownOut((_, _, _) -> {}),
            box('scroll', 320, 8, 30, 24).onScrollWheel((_, _, _) -> {}),
            box('aux', 360, 8, 30, 24).onAuxClick((_, _, _) -> {})
        ])));
        assertEquals('drag:0,0,600,40', regions(window));
    }

    function testBlockingElementsOtherControlAreasAndExplicitMarksAreHoles() {
        final window = open((_, _) -> div().w(px(600)).h(px(400)).child(bar([
            box('occlude', 100, 0, 50, 40).occlude(),
            box('block', 160, 0, 50, 40).blockMouseExceptScroll(),
            box('label', 220, 0, 50, 40).noWindowDrag(),
            box('min', 450, 0, 50, 40).windowControlArea(Min),
            box('max', 500, 0, 50, 40).windowControlArea(Max),
            box('close', 550, 0, 50, 40).windowControlArea(Close)
        ])));
        assertEquals(
            'drag:0,0,600,40 normal:100,0,50,40 normal:160,0,50,40 normal:220,0,50,40 normal:450,0,50,40 normal:500,0,50,40 normal:550,0,50,40',
            regions(window));
    }

    function testOnlyElementsDrawnAboveADragAreaCount() {
        // The parent listens to the left button but is drawn under the bar;
        // the button below the bar does not touch it
        final window = open((_, _) -> div().id('root').relative().w(px(600)).h(px(400)).onMouseDown(Left, (_, _, _) -> {})
            .child(bar([]))
            .child(box('below', 100, 100, 60, 24).onClick((_, _, _) -> {})));
        assertEquals('drag:0,0,600,40', regions(window));

        // Drawn before the bar (under it): not a hole either
        final under = open((_, _) -> div().relative().w(px(600)).h(px(400))
            .child(box('under', 100, 8, 60, 24).onClick((_, _, _) -> {}))
            .child(bar([]).absolute().top(px(0)).left(px(0))));
        assertEquals('drag:0,0,600,40', regions(under));
    }

    function testAHoleIsClippedToItsContentMask() {
        // The button overflows the clipping container (x 100..150, y 10..30)
        final window = open((_, _) -> div().w(px(600)).h(px(400)).child(bar([
            box('clip', 100, 10, 50, 20).overflowHidden().child(
                box('button', -10, -10, 100, 100).onClick((_, _, _) -> {}))
        ])));
        assertEquals('drag:0,0,600,40 normal:100,10,50,20', regions(window));

        // Entirely clipped out: no region
        final hidden = open((_, _) -> div().w(px(600)).h(px(400)).child(bar([
            box('clip', 100, 10, 50, 20).overflowHidden().child(
                box('button', 60, 0, 20, 20).onClick((_, _, _) -> {}))
        ])));
        assertEquals('drag:0,0,600,40', regions(hidden));
    }

    function testADragAreaAboveAHoleIsDraggableAgain() {
        final window = open((_, _) -> div().w(px(600)).h(px(400)).child(bar([
            box('tabs', 100, 0, 300, 40).onClick((_, _, _) -> {})
                .child(box('gap', 50, 0, 40, 40).windowControlArea(Drag))
        ])));
        assertEquals('drag:0,0,600,40 normal:100,0,300,40 drag:150,0,40,40', regions(window));
    }

    function testAnElementAboveADragAreaInAnotherBranch() {
        // A popup drawn later over the bar (absolute sibling)
        final window = open((_, _) -> div().relative().w(px(600)).h(px(400))
            .child(bar([]))
            .child(box('popup', 300, 20, 100, 100).occlude()));
        assertEquals('drag:0,0,600,40 normal:300,20,100,100', regions(window));
    }

    function testAHitboxMarkedByHand() {
        var marked:Null<glaze.Hitbox> = null;
        final window = open((_, _) -> div().w(px(600)).h(px(400)).child(bar([
            canvas((bounds, window, _) -> {
                final hitbox = window.insertHitbox(bounds, Normal);
                window.excludeFromWindowDrag(hitbox);
                marked = hitbox;
                return hitbox;
            }, (_, _, _, _) -> {}).absolute().left(px(10)).top(px(5)).w(px(20)).h(px(30))
        ])));
        assertNotNull(marked);
        assertEquals('drag:0,0,600,40 normal:10,5,20,30', regions(window));
    }

    /**
     * The regions are read from the hitboxes of the frame, which a view
     * reused from the cache brings back: its drag area and holes stay.
     */
    function testRegionsOfAViewReusedFromTheCacheAreKept() {
        // The cache check renders the reused views for real: off here, so
        // the render count shows the reuse (the runner turns it back on)
        #if glaze_verify_cache
        Window.verifyCache = false;
        #end
        var titleRenders = 0;
        final toggle = new DragRegionsToggle();
        final title:Entity<ScriptView> = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) -> {
            titleRenders++;
            return bar([box('button', 100, 8, 60, 24).onClick((_, _, _) -> {})]);
        }));
        final window = open((_, _) -> div().w(px(600)).h(px(400))
            .child(title)
            .child(div().child(toggle.on ? 'on' : 'off')), true);
        final expected = 'drag:0,0,600,40 normal:100,8,60,24';
        assertEquals(expected, regions(window));
        assertEquals(1, titleRenders);

        toggle.on = false;
        ceramic.App.app.flushImmediate();
        app.update(_ -> window.drawIfDirty());
        assertEquals(1, titleRenders, 'the title view is reused from the cache');
        assertEquals(expected, regions(window));
    }

}

class DragRegionsToggle extends glaze.Model {

    @observe public var on:Bool = true;

    public function new() {
        super();
    }

}

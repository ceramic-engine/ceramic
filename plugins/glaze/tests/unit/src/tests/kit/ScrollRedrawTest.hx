package tests.kit;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseMoveEvent;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.text.TextView;
import glaze.scene.SceneDump;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Scrolling redraws the scrolled content with default view caching.
 *
 * A scroll event changes a scroll offset and notifies a view; the window
 * draws its next frame from that (`drawIfDirty`, like the `GlazeSystem`),
 * never from an explicit `draw()`. Each frame of a window caching views
 * must equal the frame of a window rendering every view, as in GPUI where
 * views are not cached unless embedded with `.cached(style)`.
 */
class ScrollRedrawTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> TextViewTest.initBase(cx));
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

    function openWindow(root:AnyView, caching:Bool):Window {
        final window = Window.open(app, {width: 400, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false, viewCaching: caching}, (_, _) -> root);
        window.viewCachingDisabled = !caching;
        windows.push(window);
        return window;
    }

    function view(render:(Window, Context<Dynamic>) -> IntoElement):Entity<ScrollRedrawView> {
        return app.newEntity((_:Context<ScrollRedrawView>) -> new ScrollRedrawView(render));
    }

    /** Draws the dirty windows, like the GlazeSystem does every frame. */
    function frame():Void {
        flushImmediate();
        for (window in windows) {
            window.drawIfDirty();
        }
    }

    static function dump(window:Window):String {
        return SceneDump.toJson(window.renderedScene(), window.viewportSize().width * 2, window.viewportSize().height * 2);
    }

    function wheel(x:Float, y:Float, dy:Float):Void {
        for (window in windows) {
            window.dispatchEvent(new ScrollEvent(point(px(x), px(y)), ScrollDelta.Pixels(point(px(0), px(dy)))));
        }
    }

    /**
     * The vertical positions of the glyphs and quads of the scene, in device
     * pixels.
     */
    static function tops(window:Window):Array<Float> {
        final scene = window.renderedScene();
        final result = [for (sprite in scene.monochromeSprites) sprite.boundsY];
        for (quad in scene.quads) {
            result.push(quad.boundsY);
        }
        return result;
    }

    /**
     * How many primitives of `after` are found `shift` device pixels above
     * a primitive of `before`.
     */
    static function shifted(before:Array<Float>, after:Array<Float>, shift:Float):Int {
        final positions = new Map<String, Bool>();
        for (y in before) {
            positions.set(Std.string(Math.round(y * 100)), true);
        }
        var count = 0;
        for (y in after) {
            if (positions.exists(Std.string(Math.round((y + shift) * 100)))) {
                count++;
            }
        }
        return count;
    }

    /**
     * Moves the mouse over the scroll area (so the hit test does not change
     * with the wheel events), then scrolls `steps` times by `amount` logical
     * pixels. Every frame is drawn only because the scroll made the window
     * dirty; in the window caching views and in the one rendering every view,
     * the content must move up by the scrolled amount, and both frames must
     * be identical.
     */
    function assertScrollsLikeUncached(cached:Window, reference:Window, x:Float, y:Float, steps:Int, amount:Float, ?pos:haxe.PosInfos):Void {
        frame();
        for (window in windows) {
            window.dispatchEvent(new MouseMoveEvent(point(px(x), px(y))));
        }
        frame();
        assertEquals(dump(reference), dump(cached), 'first frame', pos);
        for (step in 0...steps) {
            final previous = [for (window in [cached, reference]) tops(window)];
            final drawCounts = [for (window in [cached, reference]) window.drawCount];
            wheel(x, y, -amount);
            frame();
            for (i => window in [cached, reference]) {
                final name = i == 0 ? 'caching' : 'not caching';
                assertTrue(window.drawCount > drawCounts[i], 'step $step, $name: the scroll redraws the window', pos);
                final current = tops(window);
                // Most of the content moved up by the scrolled amount (in
                // device pixels), the rest is fixed or scrolled in.
                final moved = shifted(previous[i], current, amount * 2);
                assertTrue(moved * 2 > current.length, 'step $step, $name: $moved of ${current.length} primitives moved up by $amount px', pos);
            }
            assertTrue(dump(cached) == dump(reference), 'step $step: same frame with and without view caching', pos);
        }
    }

    static function markdown():String {
        final buf = new StringBuf();
        buf.add('# Introduction\n\n```rust\nfn main() {\n    println!("hello");\n}\n```\n\n');
        for (i in 0...6) {
            buf.add('Paragraph $i of the introduction, long enough to wrap over a couple of lines in the view.\n\n');
        }
        buf.add('## Features\n\n');
        for (i in 0...30) {
            buf.add('- Feature $i: a bullet of the long features list\n');
        }
        return buf.toString();
    }

    /**
     * The story's introduction page: a scrollable markdown `TextView` in a
     * view nested in the root. Its `ScrollBounce` moves the list of the
     * text view state (a child view) and notifies the page.
     */
    function testScrollableTextViewInNestedView() {
        final source = markdown();
        final page = view((_, _) -> TextView.markdown('intro', source).px4().scrollable(true).selectable(true));
        final root = view((_, _) -> div().w(px(320)).h(px(240)).flex().flexCol().child((page : AnyView)));
        final cached = openWindow(root, true);
        final reference = openWindow(root, false);
        assertScrollsLikeUncached(cached, reference, 100, 100, 4, 30);
    }

    /** A plain `overflowYScroll` div in a nested view. */
    function testOverflowScrollDivInNestedView() {
        final page = view((_, _) -> div().id('page').sizeFull().overflowYScroll().flex().flexCol()
            .children([for (i in 0...40) div().h(px(24)).bg(hsla(i / 40, 0.5, 0.8, 1)).child('Row $i')]));
        final root = view((_, _) -> div().w(px(320)).h(px(240)).flex().flexCol().child((page : AnyView)));
        final cached = openWindow(root, true);
        final reference = openWindow(root, false);
        assertScrollsLikeUncached(cached, reference, 100, 100, 4, 30);
    }


    /**
     * Handles moved from outside the view showing their element (a toolbar
     * scrolling a list, then notifying its own view): the next frame shows
     * the new positions, like GPUI rendering every view.
     */
    function testHandlesScrolledFromAnotherView() {
        final handle = new glaze.ScrollHandle();
        final listState = new glaze.ListState(40, glaze.ListAlignment.Top, 0);
        final uniformHandle = new glaze.UniformListScrollHandle();
        final row = (i:Int) -> div().h(px(24)).bg(hsla(i / 40, 0.5, 0.8, 1)).child('Row $i');
        final divPage = view((_, _) -> div().id('div-page').w(px(100)).h(px(200)).overflowYScroll().trackScroll(handle).flex().flexCol()
            .children([for (i in 0...40) row(i)]));
        final listPage = view((_, _) -> div().w(px(100)).h(px(200)).flex().flexCol()
            .child(list(listState, (i, _, _) -> row(i)).flexGrow1()));
        final uniformPage = view((_, _) -> div().w(px(100)).h(px(200)).flex().flexCol()
            .child(uniformList('rows', 40, (start, end, _, _) -> [for (i in start...end) row(i)]).trackScroll(uniformHandle).flexGrow1()));
        final root = view((_, _) -> div().size(px(400)).flex().child((divPage : AnyView)).child((listPage : AnyView)).child((uniformPage : AnyView)));
        final cached = openWindow(root, true);
        final reference = openWindow(root, false);
        frame();
        assertEquals(dump(reference), dump(cached));
        final moves:Array<{name:String, move:() -> Void}> = [
            {name: 'div', move: () -> handle.setOffset(point(px(0), px(-50)))},
            {name: 'list', move: () -> listState.scrollTo(new glaze.ListOffset(5, 0))},
            {name: 'uniform list', move: () -> uniformHandle.scrollToItem(20, glaze.ScrollStrategy.Top)}
        ];
        for (step in moves) {
            final before = dump(cached);
            step.move();
            app.notify(root.entityId());
            frame();
            final after = dump(cached);
            assertTrue(after != before, '${step.name}: moved');
            assertTrue(after == dump(reference), '${step.name}: same frame with and without view caching');
        }
    }

    /**
     * GPUI's `.cached(style)` is unchanged: a view cached with a style is
     * reused while it is not notified, even if a handle it shows moved.
     */
    function testCachedWithStyleKeepsGpuiBehaviour() {
        final handle = new glaze.ScrollHandle();
        final page = view((_, _) -> div().id('page').sizeFull().overflowYScroll().trackScroll(handle).flex().flexCol()
            .children([for (i in 0...40) div().h(px(24)).bg(hsla(i / 40, 0.5, 0.8, 1)).child('Row $i')]));
        final root = view((_, _) -> div().w(px(320)).h(px(240)).child(page.cached(glaze.StyleBuilder.build(s -> s.sizeFull()))));
        final cached = openWindow(root, true);
        frame();
        final before = dump(cached);
        handle.setOffset(point(px(0), px(-50)));
        app.notify(root.entityId());
        frame();
        assertEquals(before, dump(cached));
        // Notified, it renders with the new offset
        app.notify(page.entityId());
        frame();
        assertTrue(dump(cached) != before);
    }

}

private class ScrollRedrawView extends Model implements Render {

    public var renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}

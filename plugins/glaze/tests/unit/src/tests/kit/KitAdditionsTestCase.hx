// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Element;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Point;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.scene.Quad;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

/**
 * Base of the tests of the kit additions that have no upstream equivalent
 * (KIT-nnn in docs/DEVIATIONS.md): a window whose view is a render closure,
 * bounds recorded by `probe(selector, element)`, and the quads of the frame
 * drawn last.
 */
class KitAdditionsTestCase extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    final views:Array<Entity<ScriptView>> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        views.resize(0);
        ceramic.App.app.flushImmediate();
    }

    /** Opens a window (800 x 600 by default) drawing what `render` returns. */
    function open(render:(Window, Context<Dynamic>) -> IntoElement, width:Float = 800, height:Float = 600, root:Bool = false):VisualTestContext {
        final opened = root
            ? VisualTestContext.addWindowRoot(app, dispatcher, (_, cx) -> cx.newEntity(_ -> new ScriptView(render)), width, height)
            : VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render), width, height);
        contexts.push(opened.cx);
        views.push(opened.view);
        draw(opened.cx);
        return opened.cx;
    }

    /** Renders the view of `cx` again and draws. */
    function rerender(cx:VisualTestContext):Void {
        final view = views[contexts.indexOf(cx)];
        cx.update((_, app) -> app.notify(view.entityId()));
        draw(cx);
    }

    function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
    }

    /** 16 ms later: the next frame callbacks, then a draw. */
    function nextFrame(cx:VisualTestContext):Void {
        cx.advanceClock(0.016);
        cx.update((window, app) -> window.simulateNextFrame(app));
        draw(cx);
    }

    function boundsOf(cx:VisualTestContext, selector:String):Null<Bounds> {
        return AdditionsProbe.boundsOf(cx.window, selector);
    }

    function probe(selector:String, element:IntoElement):IntoElement {
        return new AdditionsProbe(selector, element);
    }

    /** The quads of the frame drawn last, in logical pixels. */
    function quads(cx:VisualTestContext):Array<{bounds:Bounds, quad:Quad}> {
        return cx.update((window, _) -> {
            final scaleFactor = window.scaleFactor();
            return [for (quad in window.renderedScene().quads) {
                bounds: new Bounds(new Point(quad.boundsX / scaleFactor, quad.boundsY / scaleFactor), new glaze.Size(quad.boundsWidth / scaleFactor, quad.boundsHeight / scaleFactor)),
                quad: quad
            }];
        });
    }

    function hasBackground(quad:Quad, color:Hsla):Bool {
        return quad.backgroundTag == 0
            && Math.abs(quad.backgroundSolidH - color.h) < 0.0001 && Math.abs(quad.backgroundSolidS - color.s) < 0.0001
            && Math.abs(quad.backgroundSolidL - color.l) < 0.0001 && Math.abs(quad.backgroundSolidA - color.a) < 0.0001;
    }

    /** The quads filled with `color` whose bounds equal `area` (within half a pixel). */
    function quadsFilled(cx:VisualTestContext, color:Hsla, ?area:Bounds):Array<{bounds:Bounds, quad:Quad}> {
        return [for (entry in quads(cx)) if (hasBackground(entry.quad, color) && (area == null || near(entry.bounds, area))) entry];
    }

    function near(a:Bounds, b:Bounds):Bool {
        return Math.abs(a.origin.x - b.origin.x) < 0.5 && Math.abs(a.origin.y - b.origin.y) < 0.5
            && Math.abs(a.size.width - b.size.width) < 0.5 && Math.abs(a.size.height - b.size.height) < 0.5;
    }

    /** A signature of the frame drawn last: every quad's bounds, background, border and corners. */
    function sceneSignature(cx:VisualTestContext):String {
        final parts:Array<String> = [];
        for (entry in quads(cx)) {
            final q = entry.quad;
            parts.push('${q.boundsX},${q.boundsY},${q.boundsWidth},${q.boundsHeight}|${q.backgroundTag}:${q.backgroundSolidH},${q.backgroundSolidS},${q.backgroundSolidL},${q.backgroundSolidA}'
                + '|${q.borderColorH},${q.borderColorS},${q.borderColorL},${q.borderColorA}|${q.cornerRadiusTopLeft},${q.cornerRadiusTopRight},${q.cornerRadiusBottomRight},${q.cornerRadiusBottomLeft}');
        }
        final sprites = cx.update((window, _) -> window.renderedScene().monochromeSprites.length);
        parts.push('sprites:$sprites');
        return parts.join('\n');
    }

}

/** Records the bounds of its child in prepaint, under a selector and per window. */
class AdditionsProbe extends Element {

    static final recorded:Map<Int, Map<String, Bounds>> = new Map();

    final selector:String;

    final child:AnyElement;

    public function new(selector:String, child:IntoElement) {
        this.selector = selector;
        this.child = child.intoAnyElement();
    }

    public static function boundsOf(window:Window, selector:String):Null<Bounds> {
        final map = recorded.get(window.id);
        return map != null ? map.get(selector) : null;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        var map = recorded.get(window.id);
        if (map == null) {
            map = new Map();
            recorded.set(window.id, map);
        }
        map.set(selector, bounds);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}

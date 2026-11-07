// New code for the Haxe port of gpui-kit (no gpui-kit origin): regression
// test of a resizable panel at its minimum size. Expected values come from
// the same cases run against gpui-kit 0.8.1 on gpui-pre 0.3.10. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.Pixels;
import gpui.Render;
import gpui.StyleBuilder;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.Base;
import gpui.base.resizable.PixelsRange;
import gpui.base.resizable.Resizable;
import gpui.base.resizable.ResizableState;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * A panel at exactly `PANEL_MIN_SIZE` (100 px) reports a size change to its
 * state on every prepaint (gpui-kit's `panel_size_changes`), and the state
 * notifies while the window draws. In GPUI that notify schedules no frame:
 * the window goes idle once the layout has settled. The port drew it again
 * forever, and `runUntilParked` never returned.
 *
 * Each case renders a group of panels in 400 px beside a view cached with a
 * style that reads the state, settles it with three draws, and checks the
 * values GPUI gives: the widths, the stored sizes, whether a panel still
 * reports a change, no render nor draw while idle, one render of the group's
 * view after one notify of it, and no render of the cached reader.
 */
@:access(testing.VisualTestContext)
class ResizableIdleTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Base.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        DebugProbe.clear();
        ceramic.App.app.flushImmediate();
    }

    function check(sizes:Array<Null<Float>>, max:Null<Float>, resizeFirstTo:Null<Float>, expectedWidths:String, expectedChanges:String):Void {
        final state = app.update(cx -> cx.newEntity((_:Context<ResizableState>) -> new ResizableState()));
        final renders = [0];
        final readerRenders = [0];
        DebugProbe.clear();
        var inner:Null<Entity<IdleHarness>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, cx:Context<IdleOuter>) -> {
            inner = cx.newEntity((_:Context<IdleHarness>) -> new IdleHarness(state, renders, sizes, max));
            return new IdleOuter(inner, cx.newEntity((_:Context<IdleReader>) -> new IdleReader(state, readerRenders)));
        });
        final cx = opened.cx;
        contexts.push(cx);
        function settle() {
            for (_ in 0...3) {
                DebugProbe.clear();
                cx.update((window, _) -> window.draw());
                cx.runUntilParked();
            }
        }
        settle();
        if (resizeFirstTo != null) {
            cx.update((window, app) -> state.update(app, (state, c) -> state.resizePanel(0, resizeFirstTo, window, c)));
            settle();
        }

        final widths = [for (ix in 0...sizes.length) (DebugProbe.bounds('ri-' + ix).size.width : Float)].join(',');
        assertEquals(expectedWidths, widths);
        final stored = cx.update((_, app) -> {
            final s = state.read(app);
            [s.sizes().join(','), [for (panel in s.panels) (panel.size : Null<Float>)].join(',')];
        });
        assertEquals(expectedWidths, stored[0]);
        assertEquals(expectedWidths, stored[1]);
        final changes = cx.update((_, app) -> {
            final s = state.read(app);
            [for (ix in 0...sizes.length) s.panelSizeChanges(ix, s.panels[ix].bounds, s.panels[ix].sizeRange, s.panels[ix].fixed)].join(',');
        });
        assertEquals(expectedChanges, changes);

        // Idle: nothing renders or draws, and the window does not ask for a frame
        final rendersBefore = renders[0];
        final readerBefore = readerRenders[0];
        final drawsBefore = cx.window.drawCount;
        for (_ in 0...3) cx.runUntilParked();
        assertEquals(0, renders[0] - rendersBefore);
        assertEquals(0, cx.window.drawCount - drawsBefore);
        assertFalse(cx.window.dirty);

        // One notify of the group's view renders it once
        cx.update((_, app) -> inner.update(app, (_, c) -> c.notify()));
        cx.runUntilParked();
        assertEquals(1, renders[0] - rendersBefore);
        assertEquals(0, readerRenders[0] - readerBefore);
        assertFalse(cx.window.dirty);
    }

    function testAPanelAtExactlyTheMinimumGoesIdle() {
        check([100., null], null, null, '100,300', 'true,false');
    }

    function testAPanelAboveTheMinimumGoesIdle() {
        check([100.5, null], null, null, '100.5,299.5', 'false,false');
    }

    function testAPanelClampedToTheMinimumGoesIdle() {
        check([99.99, null], null, null, '100,300', 'true,false');
    }

    function testAPanelClampedToItsMaximumGoesIdle() {
        check([300., null], 200., null, '200,200', 'false,false');
    }

    function testTwoPanelsAtTheMinimumGoIdle() {
        check([100., 100., null], null, null, '100,100,200', 'true,true,false');
    }

    function testAPanelDraggedToTheMinimumGoesIdle() {
        check([150., null], null, 50., '100,300', 'true,false');
    }

    function testAFlexiblePanelLaidOutAtTheMinimumGoesIdle() {
        check([300., null], null, null, '300,100', 'false,true');
    }

    function testAPanelAwayFromTheMinimumGoesIdle() {
        check([150., null], null, null, '150,250', 'false,false');
    }

}

private class IdleHarness extends Model implements Render {

    final state:Entity<ResizableState>;
    final renders:Array<Int>;
    final sizes:Array<Null<Float>>;
    final max:Null<Float>;

    public function new(state:Entity<ResizableState>, renders:Array<Int>, sizes:Array<Null<Float>>, max:Null<Float>) {
        super();
        this.state = state;
        this.renders = renders;
        this.sizes = sizes;
        this.max = max;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders[0] = renders[0] + 1;
        final group = Resizable.hResizable('min-size').withState(state);
        for (ix in 0...sizes.length) {
            final panel = Resizable.resizablePanel();
            if (sizes[ix] != null) panel.size(sizes[ix]);
            if (ix == 0 && max != null) panel.sizeRange(new PixelsRange(100., max));
            group.child(panel.child(new DebugProbe('ri-' + ix, div().sizeFull())));
        }
        return div().w(px(400.)).h(px(100.)).child(group);
    }

}

/**
 * A view reading the state, cached with a style, beside the group.
 */
private class IdleReader extends Model implements Render {

    final state:Entity<ResizableState>;
    final renders:Array<Int>;

    public function new(state:Entity<ResizableState>, renders:Array<Int>) {
        super();
        this.state = state;
        this.renders = renders;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders[0] = renders[0] + 1;
        final count = state.read(cx).sizes().length;
        return div().sizeFull();
    }

}

private class IdleOuter extends Model implements Render {

    final inner:Entity<IdleHarness>;
    final reader:Entity<IdleReader>;

    public function new(inner:Entity<IdleHarness>, reader:Entity<IdleReader>) {
        super();
        this.inner = inner;
        this.reader = reader;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().w(px(800.)).h(px(100.)).flex()
            .child(div().w(px(400.)).h(px(100.)).child(reader.cached(new StyleBuilder().sizeFull().style())))
            .child(inner);
    }

}

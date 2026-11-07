// Ported from gpui-pre 0.3.10: src/elements/uniform_list.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.Action;
import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Point;
import gpui.Render;
import gpui.ScrollStrategy;
import gpui.TestDispatcher;
import gpui.UniformListScrollHandle;
import gpui.Window;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * Tests of `uniform_list.rs`, all ported. The list items of
 * `test_scroll_strategy_nearest` have no text child (`Item {ix}` in Rust):
 * the test only checks the rendered ranges.
 */
class UniformListTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    /** Rust `cx.dispatch_action(action)`: dispatches to the focused element and runs until parked. */
    function dispatchAction(action:Action):Void {
        cx.update((window, cx) -> window.dispatchAction(action, cx));
        cx.runUntilParked();
    }

    function testScrollStrategyNearest() {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, viewCx:Context<UniformListNearestView>) -> {
            final focusHandle = viewCx.focusHandle();
            window.focus(focusHandle, viewCx.app);
            return new UniformListNearestView(focusHandle, 47);
        });
        cx = opened.cx;
        final view:UniformListNearestView = opened.view;

        // 10 out of 47 items are visible

        // First 9 times selecting next item does not scroll
        for (ix in 1...10) {
            dispatchAction(new UniformListSelectNext());
            assertEquals(ix, view.index);
            assertEquals('0..10', view.visibleRange());
        }

        // Now each time the list scrolls down by 1
        for (ix in 10...47) {
            dispatchAction(new UniformListSelectNext());
            assertEquals(ix, view.index);
            assertEquals((ix - 9) + '..' + (ix + 1), view.visibleRange());
        }

        // After the last item we move back to the start
        dispatchAction(new UniformListSelectNext());
        assertEquals(0, view.index);
        assertEquals('0..10', view.visibleRange());

        // Return to the last element
        dispatchAction(new UniformListSelectPrev());
        assertEquals(46, view.index);
        assertEquals('37..47', view.visibleRange());

        // First 9 times selecting previous does not scroll
        var ix = 45;
        while (ix >= 37) {
            dispatchAction(new UniformListSelectPrev());
            assertEquals(ix, view.index);
            assertEquals('37..47', view.visibleRange());
            ix--;
        }

        // Now each time the list scrolls up by 1
        ix = 36;
        while (ix >= 0) {
            dispatchAction(new UniformListSelectPrev());
            assertEquals(ix, view.index);
            assertEquals(ix + '..' + (ix + 10), view.visibleRange());
            ix--;
        }
    }

    function testItemPositionsFarDownLongList() {
        final itemBounds:Array<{ix:Int, bounds:Bounds}> = [];
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _:Context<UniformListLongView>) -> new UniformListLongView(itemBounds));
        cx = opened.cx;

        // Past 2^27px, f32 can only represent multiples of 16px. This offset is 16px into item
        // 9_000_002, and the items must still be laid out 24px apart from that point.
        itemBounds.resize(0);
        opened.view.update(app, (view, viewCx) -> {
            view.scrollHandle.state.baseHandle.setOffset(new Point(0, -216000064));
            viewCx.notify();
        });
        cx.runUntilParked();

        final itemTops = [for (entry in itemBounds) entry.ix + ':' + entry.bounds.origin.y].join(' ');
        final expectedTops = [for (ix in 9000002...9000011) ix + ':' + (-16.0 + 24.0 * (ix - 9000002))].join(' ');
        assertEquals(expectedTops, itemTops);
    }

}

@:action(namespace = uniform_list_test) private class UniformListSelectNext implements Action {}

@:action(namespace = uniform_list_test) private class UniformListSelectPrev implements Action {}

private class UniformListNearestView extends Model implements Render {

    public var index:Int = 0;

    public final length:Int;

    public final scrollHandle:UniformListScrollHandle = new UniformListScrollHandle();

    public final focusHandle:FocusHandle;

    public var visibleStart:Int = 0;

    public var visibleEnd:Int = 0;

    public function new(focusHandle:FocusHandle, length:Int) {
        super();
        this.focusHandle = focusHandle;
        this.length = length;
    }

    public function visibleRange():String {
        return visibleStart + '..' + visibleEnd;
    }

    function selectNext(_:UniformListSelectNext, window:Window, _:App):Void {
        if (index + 1 == length) {
            index = 0;
        }
        else {
            index += 1;
        }
        scrollHandle.scrollToItem(index, ScrollStrategy.Nearest);
        window.refresh();
    }

    function selectPrevious(_:UniformListSelectPrev, window:Window, _:App):Void {
        if (index == 0) {
            index = length - 1;
        }
        else {
            index -= 1;
        }
        scrollHandle.scrollToItem(index, ScrollStrategy.Nearest);
        window.refresh();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .id('list-example')
            .trackFocus(focusHandle)
            .onAction(UniformListSelectNext, selectNext)
            .onAction(UniformListSelectPrev, selectPrevious)
            .sizeFull()
            .child(
                uniformList('entries', length, (start, end, _, _) -> {
                    visibleStart = start;
                    visibleEnd = end;
                    return [for (ix in start...end) div().id(ix).h(px(20))];
                })
                .trackScroll(scrollHandle)
                .h(px(200))
            );
    }

}

private class UniformListLongView extends Model implements Render {

    public final scrollHandle:UniformListScrollHandle = new UniformListScrollHandle();

    final itemBounds:Array<{ix:Int, bounds:Bounds}>;

    public function new(itemBounds:Array<{ix:Int, bounds:Bounds}>) {
        super();
        this.itemBounds = itemBounds;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final itemBounds = this.itemBounds;
        return uniformList('entries', 10000000, (start, end, _, _) -> {
            return [for (ix in start...end) canvas((bounds, _, _) -> {
                itemBounds.push({ix: ix, bounds: bounds});
                return 0;
            }, (_, _, _, _) -> {}).wFull().h(px(24))];
        })
        .trackScroll(scrollHandle)
        .h(px(200));
    }

}

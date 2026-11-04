// Ported from gpui-pre 0.3.10: src/elements/list.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.FollowMode;
import gpui.IntoElement;
import gpui.ListAlignment;
import gpui.ListOffset;
import gpui.ListState;
import gpui.Model;
import gpui.Point;
import gpui.Render;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.util.Ref;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * Tests of `list.rs`, all ported.
 *
 * Rust's `VisualTestContext::draw(origin, size, f)` lays out and paints an
 * element directly into the window; its listeners stay live until the next
 * draw. Here the window root renders the element inside a box of the given
 * size, and the window is only drawn by `drawAt` (no draw when effects are
 * flushed), which keeps the same frame boundaries.
 */
class ListTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Null<Window> = null;

    var host:Null<ListTestHost> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) {
            window.destroy();
            window = null;
        }
        host = null;
        ceramic.App.app.flushImmediate();
    }

/// Helpers

    /** Rust `cx.add_empty_window()` */
    function addEmptyWindow():Void {
        window = Window.open(app, {width: 1920, height: 1080, scaleFactor: 2, autoDraw: false, active: false, bindInput: false}, (window, cx) -> {
            final entity = cx.newEntity((_:Context<ListTestHost>) -> new ListTestHost());
            host = entity;
            return entity;
        });
        app.update(_ -> window.draw());
        runUntilParked();
    }

    function runUntilParked():Void {
        dispatcher.runUntilParked();
        ceramic.App.app.flushImmediate();
    }

    /** Rust `cx.draw(point(px(0.), px(0.)), size(px(width), px(height)), ...)` */
    function drawAt(width:Float, height:Float, build:() -> gpui.Element):Void {
        host.width = width;
        host.height = height;
        host.build = build;
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        runUntilParked();
    }

    /** Rust `draw_list` */
    function drawList(state:ListState, viewportHeight:Float, renderItem:(Int) -> IntoElement):Void {
        drawAt(100, viewportHeight, () -> list(state, (index, _, _) -> renderItem(index)).wFull().hFull());
    }

    /** Rust `TestListView` */
    function drawTestListView(state:ListState, height:Float):Void {
        drawAt(100, height, () -> list(state, (_, _, _) -> div().h(px(20)).wFull()).wFull().hFull());
    }

    /** Rust `cx.simulate_event(ScrollEvent { position, delta: ScrollDelta::Pixels(delta), .. })` */
    function simulateScroll(x:Float, y:Float, dx:Float, dy:Float):Void {
        window.dispatchEvent(new ScrollEvent(new Point(x, y), ScrollDelta.Pixels(new Point(dx, dy))), app);
        runUntilParked();
    }

    /** A painted item: `index:top:bottom` */
    static function p(index:Int, top:Float, bottom:Float):String {
        // -0 is printed as 0 (hxcpp prints -0, JS prints 0)
        return index + ':' + (top == 0 ? 0.0 : top) + ':' + (bottom == 0 ? 0.0 : bottom);
    }

    /** Rust `painted_item` */
    static function paintedItem(index:Int, height:Float, painted:Array<String>):IntoElement {
        return canvas((_, _, _) -> 0, (bounds, _, _, _) -> {
            painted.push(p(index, bounds.top(), bounds.bottom()));
        }).h(px(height)).wFull();
    }

    /** Rust `item_readiness` */
    static function itemReadiness(state:ListState, ready:Bool):Ref<Bool> {
        final cell = new Ref(ready);
        state.setItemMeasurementReadiness((_, _) -> cell.value);
        return cell;
    }

    static inline function listOffset(itemIx:Int, offset:Float):ListOffset {
        return new ListOffset(itemIx, offset);
    }

    function assertOffset(expected:ListOffset, actual:ListOffset, ?message:String, ?pos:haxe.PosInfos):Void {
        assertEquals(expected.toString(), actual.toString(), message, pos);
    }

    function assertPainted(expected:Array<String>, painted:Array<String>, ?message:String, ?pos:haxe.PosInfos):Void {
        assertEquals(expected.join(' '), painted.join(' '), message, pos);
    }

    function firstPainted(painted:Array<String>):Null<String> {
        return painted.length > 0 ? painted[0] : null;
    }

    function findPainted(painted:Array<String>, index:Int):Null<String> {
        for (entry in painted) {
            if (entry.split(':')[0] == Std.string(index))
                return entry;
        }
        return null;
    }

/// Tests

    function testAutoscrollAboveItemTopRendersItemsAbove() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10));
        state.scrollTo(new ListOffset(2, 0));

        drawAt(100, 60, () -> list(state, (ix, _, _) -> {
            if (ix == 2) {
                // Request an autoscroll whose top sits 30px above item 2's
                // own top, mimicking a scroll-margin overshoot.
                return canvas((bounds, window, _) -> {
                    window.requestAutoscroll(Bounds.fromCorners(
                        new Point(bounds.left(), bounds.top() - 30),
                        new Point(bounds.right(), bounds.top() + 5)
                    ));
                    return 0;
                }, (_, _, _, _) -> {}).h(px(20)).wFull();
            }
            else {
                return div().h(px(20)).wFull();
            }
        }).wFull().hFull());

        // 30px above item 2's top, with 20px items, lands 10px into item 0.
        final scrollTop = state.logicalScrollTop();
        assertTrue(scrollTop.offsetInItem >= 0, 'offset_in_item must never be negative (would leave blank space above)');
        assertEquals(0, scrollTop.itemIx);
        assertFloatEquals(10, scrollTop.offsetInItem);
    }

    function testResetAfterPaintBeforeScroll() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10));

        // Ensure that the list is scrolled to the top
        state.scrollTo(new ListOffset(0, 0));

        // Paint
        drawAt(100, 20, () -> list(state, (_, _, _) -> div().h(px(10)).wFull()).wFull().hFull());

        // Reset
        state.reset(5);

        // And then receive a scroll event _before_ the next paint
        simulateScroll(1, 1, 0, -500);

        // Scroll position should stay at the top of the list
        assertEquals(0, state.logicalScrollTop().itemIx);
        assertFloatEquals(0, state.logicalScrollTop().offsetInItem);
    }

    function testScrollByPositiveAndNegativeDistance() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10));

        // Paint
        drawAt(100, 100, () -> list(state, (_, _, _) -> div().h(px(20)).wFull()).wFull().hFull());

        // Test positive distance: start at item 1, move down 30px
        state.scrollBy(px(30));

        // Should move to item 2
        var offset = state.logicalScrollTop();
        assertEquals(1, offset.itemIx);
        assertFloatEquals(10, offset.offsetInItem);

        // Test negative distance: start at item 2, move up 30px
        state.scrollBy(px(-30));

        // Should move back to item 1
        offset = state.logicalScrollTop();
        assertEquals(0, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);

        // Test zero distance
        state.scrollBy(px(0));
        offset = state.logicalScrollTop();
        assertEquals(0, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
    }

    function testChildScrollHandlerCanStopListScroll() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10));
        var childSawEvent = false;

        drawAt(100, 100, () -> list(state, (_, _, _) -> {
            return div().h(px(20)).wFull().onScroll((_, _, cx) -> {
                childSawEvent = true;
                cx.stopPropagation();
            });
        }).wFull().hFull());

        simulateScroll(50, 10, 0, -30);

        assertTrue(childSawEvent, 'the child\'s scroll-wheel handler should run');
        // The child stopped propagation, so the list must not have scrolled.
        final offset = state.logicalScrollTop();
        assertEquals(0, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
    }

    function testItemViewportQueriesReturnNoneBeforeLayout() {
        final state = new ListState(5, ListAlignment.Top, px(10)).measureAll();

        assertEquals(null, state.itemIsAboveViewport(0));
        assertEquals(null, state.itemIsBelowViewport(0));
    }

    function testItemViewportQueriesBeforeLogicalScrollTop() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10)).measureAll();

        state.scrollTo(new ListOffset(2, 0));
        drawTestListView(state, 20);

        assertEquals(true, state.itemIsAboveViewport(1));
        assertEquals(false, state.itemIsBelowViewport(1));
    }

    function testItemViewportQueriesMeasuredItemInsideViewport() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10)).measureAll();

        state.scrollTo(new ListOffset(2, 0));
        drawTestListView(state, 20);

        assertEquals(false, state.itemIsAboveViewport(2));
        assertEquals(false, state.itemIsBelowViewport(2));
    }

    function testItemViewportQueriesMeasuredItemAboveViewport() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10)).measureAll();

        state.scrollTo(new ListOffset(2, 20));
        drawTestListView(state, 20);

        assertEquals(true, state.itemIsAboveViewport(2));
        assertEquals(false, state.itemIsBelowViewport(2));
    }

    function testItemViewportQueriesMeasuredItemBelowViewport() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10)).measureAll();

        state.scrollTo(new ListOffset(2, 0));
        drawTestListView(state, 20);

        assertEquals(false, state.itemIsAboveViewport(3));
        assertEquals(true, state.itemIsBelowViewport(3));
    }

    function testItemViewportQueriesRemainStableWithZeroHeightViewport() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10)).measureAll();

        state.scrollTo(new ListOffset(2, 0));
        drawTestListView(state, 20);

        assertEquals(false, state.itemIsAboveViewport(3));
        assertEquals(true, state.itemIsBelowViewport(3));

        // Squeeze the list to zero height, e.g. because a sibling element
        // (sized based on the queries above) consumed all the space. The
        // answers must remain definitive rather than becoming `null`,
        // otherwise the sibling's size can oscillate between frames.
        drawTestListView(state, 0);

        assertEquals(true, state.itemIsAboveViewport(1));
        assertEquals(false, state.itemIsBelowViewport(1));
        assertEquals(false, state.itemIsAboveViewport(3));
        assertEquals(true, state.itemIsBelowViewport(3));
    }

    function testItemViewportQueriesAfterScrollToEndBeforeLayout() {
        addEmptyWindow();

        final state = new ListState(5, ListAlignment.Top, px(10)).measureAll();

        drawTestListView(state, 20);

        state.scrollToEnd();

        assertEquals(state.itemCount(), state.logicalScrollTop().itemIx);
        assertEquals(true, state.itemIsAboveViewport(0));
        assertEquals(false, state.itemIsBelowViewport(0));
    }

    function testMeasureAllAfterWidthChange() {
        addEmptyWindow();

        final state = new ListState(10, ListAlignment.Top, px(0)).measureAll();
        final build = () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull();

        // First draw at width 100: all 10 items measured (total 500px).
        // Viewport is 200px, so max scroll offset should be 300px.
        drawAt(100, 200, build);
        assertFloatEquals(300, state.maxOffsetForScrollbar().y);

        // Second draw at a different width: items get invalidated.
        // Without the fix, max_offset would drop because unmeasured items
        // contribute 0 height.
        drawAt(200, 200, build);
        assertFloatEquals(300, state.maxOffsetForScrollbar().y);
    }

    function testRemeasure() {
        addEmptyWindow();

        // Create a list with 10 items, each 100px tall. We'll keep a reference
        // to the item height so we can later change the height and assert how
        // `ListState` handles it.
        var itemHeight = 100;
        final state = new ListState(10, ListAlignment.Top, px(10));
        final build = () -> {
            final height = itemHeight;
            return list(state, (_, _, _) -> div().h(px(height)).wFull()).wFull().hFull();
        };

        // Simulate scrolling 40px inside the element with index 2. Since the
        // original item height is 100px, this equates to 40% inside the item.
        state.scrollTo(new ListOffset(2, 40));

        drawAt(100, 200, build);

        var offset = state.logicalScrollTop();
        assertEquals(2, offset.itemIx);
        assertFloatEquals(40, offset.offsetInItem);

        // Update the `item_height` to be 50px instead of 100px so we can assert
        // that the scroll position is proportionally preserved, that is,
        // instead of 40px from the top of item 2, it should be 20px, since the
        // item's height has been halved.
        itemHeight = 50;
        state.remeasure();

        drawAt(100, 200, build);

        offset = state.logicalScrollTop();
        assertEquals(2, offset.itemIx);
        assertFloatEquals(20, offset.offsetInItem);
    }

    function testRemeasureItemPreservesScrollOffset() {
        addEmptyWindow();

        var itemHeight = 100;
        final state = new ListState(20, ListAlignment.Top, px(10));
        final build = () -> {
            final height = itemHeight;
            return list(state, (index, _, _) -> {
                final height = index == 5 ? height : 100;
                return div().h(px(height)).wFull();
            }).wFull().hFull();
        };

        state.scrollTo(new ListOffset(5, 40));

        drawAt(100, 200, build);

        itemHeight = 200;
        state.remeasureItems(5, 6);

        drawAt(100, 200, build);

        final offset = state.logicalScrollTop();
        assertEquals(5, offset.itemIx);
        assertFloatEquals(40, offset.offsetInItem);
    }

    function testProvisionalItemHeightsKeepScrollAnchor() {
        addEmptyWindow();
        final state = new ListState(20, ListAlignment.Top, px(100));
        final painted:Array<String> = [];
        var firstRendered:Null<Int> = null;
        final ready = itemReadiness(state, false);
        state.setFollowMode(FollowMode.Tail);
        state.scrollTo(listOffset(10, 40));

        for (frame in [{height: 0.0, measurementReady: false}, {height: 100.0, measurementReady: false}, {height: 100.0, measurementReady: true}]) {
            final height = frame.height;
            ready.value = frame.measurementReady;
            painted.resize(0);
            firstRendered = null;
            drawList(state, 200, index -> {
                firstRendered = firstRendered == null ? index : (index < firstRendered ? index : firstRendered);
                return paintedItem(index, height, painted);
            });
            assertOffset(listOffset(10, 40), state.logicalScrollTop());
            assertFalse(state.isFollowingTail());
            assertEquals(frame.measurementReady ? 9 : 10, firstRendered);
            if (height > 0) {
                assertPainted([p(10, -40, 60), p(11, 60, 160), p(12, 160, 260)], painted);
            }
        }
    }

    function testUnreadyMeasurementsPreservePendingFraction() {
        addEmptyWindow();
        final cases:Array<{provisionalHeight:Null<Float>, destination:Null<Float>, finalHeight:Float, expectedOffset:Float}> = [
            {provisionalHeight: 200, destination: null, finalHeight: 200, expectedOffset: 100},
            {provisionalHeight: null, destination: 40, finalHeight: 200, expectedOffset: 80},
            {provisionalHeight: 200, destination: 50, finalHeight: 200, expectedOffset: 50},
            {provisionalHeight: 0, destination: 40, finalHeight: 20, expectedOffset: 20},
            {provisionalHeight: 10, destination: 40, finalHeight: 100, expectedOffset: 40},
            {provisionalHeight: 200, destination: 50, finalHeight: 300, expectedOffset: 50},
        ];
        for (c in cases) {
            final state = new ListState(10, ListAlignment.Top, px(0));
            final painted:Array<String> = [];
            final draw = (height:Float) -> {
                painted.resize(0);
                drawList(state, 200, index -> paintedItem(index, index == 5 ? height : 100, painted));
            };
            final ready = itemReadiness(state, true);
            state.scrollTo(listOffset(5, 50));
            draw(100);
            ready.value = false;
            state.remeasure();
            if (c.provisionalHeight != null) {
                for (height in [0, c.provisionalHeight, c.provisionalHeight]) {
                    draw(height);
                    assertOffset(listOffset(5, 50), state.logicalScrollTop());
                }
            }
            if (c.destination != null) {
                state.scrollTo(listOffset(5, c.destination));
            }
            ready.value = true;
            for (_ in 0...2) {
                draw(c.finalHeight);
                assertOffset(listOffset(5, c.expectedOffset), state.logicalScrollTop());
                assertEquals(p(5, -c.expectedOffset, c.finalHeight - c.expectedOffset), firstPainted(painted));
            }
        }
    }

    function testNavigationCancelsProvisionalAndPaintsDestination() {
        addEmptyWindow();
        for (measured in [false, true]) {
            final navigations:Array<{name:String, navigate:(ListState) -> Void, destination:Int, top:Float}> = [
                {name: 'scroll_to', navigate: state -> state.scrollTo(listOffset(12, 0)), destination: 12, top: 0},
                {name: 'end', navigate: state -> state.scrollToEnd(), destination: 19, top: 150},
                {name: 'down', navigate: state -> state.scrollBy(px(5000)), destination: 19, top: 150},
                {name: 'up', navigate: state -> state.scrollBy(px(-5000)), destination: measured ? 0 : 6, top: 0},
                {name: 'reveal_below', navigate: state -> state.scrollToRevealItem(10), destination: 10, top: 150},
                {name: 'reveal_above', navigate: state -> state.scrollToRevealItem(0), destination: 0, top: 0},
                {name: 'follow_tail', navigate: state -> state.setFollowMode(FollowMode.Tail), destination: 19, top: 150},
            ];
            for (navigation in navigations) {
                final name = navigation.name;
                final state = new ListState(20, ListAlignment.Top, px(0));
                if (measured) state.measureAll();
                final painted:Array<String> = [];
                final draw = () -> {
                    painted.resize(0);
                    drawList(state, 200, index -> paintedItem(index, index == 5 ? 0 : 50, painted));
                };
                state.setItemMeasurementReadiness((index, _) -> index != 5);
                state.scrollTo(listOffset(5, 20));
                state.remeasureItems(5, 6);
                draw();
                assertTrue(state.isProvisional(), name);
                navigation.navigate(state);
                assertFalse(state.isProvisional(), name);
                draw();
                assertFalse(state.isProvisional(), name);
                assertEquals(
                    p(navigation.destination, navigation.top, navigation.top + 50),
                    findPainted(painted, navigation.destination),
                    '$name, measured=$measured'
                );
            }
        }

        final navigations:Array<{name:String, navigate:(ListState) -> Void}> = [
            {name: 'end_sentinel', navigate: state -> state.scrollTo(listOffset(3, 0))},
            {name: 'scroll_to_end', navigate: state -> state.scrollToEnd()},
            {name: 'follow_tail', navigate: state -> state.setFollowMode(FollowMode.Tail)},
            {name: 'horizontal', navigate: state -> state.scrollToEnd()},
            {name: 'pause_tail', navigate: state -> state.setFollowMode(FollowMode.Tail)},
            {name: 'disable_tail', navigate: state -> state.setFollowMode(FollowMode.Tail)},
        ];
        for (navigation in navigations) {
            final name = navigation.name;
            final state = new ListState(3, ListAlignment.Top, px(0)).measureAll();
            final ready = itemReadiness(state, false);
            final painted:Array<String> = [];
            final draw = (height:Float) -> {
                painted.resize(0);
                drawList(state, 200, index -> paintedItem(index, height, painted));
            };
            navigation.navigate(state);
            for (frame in [
                {height: 100.0, measurementReady: false, expected: [p(1, 0, 100), p(2, 100, 200)]},
                {height: 150.0, measurementReady: true, expected: [p(1, -100, 50), p(2, 50, 200)]},
            ]) {
                final measurementReady = frame.measurementReady;
                if (measurementReady) {
                    switch name {
                        case 'horizontal':
                            simulateScroll(50, 100, 20, 0);
                        case 'pause_tail':
                            state.pauseFollowingTail();
                        case 'disable_tail':
                            state.setFollowMode(FollowMode.Normal);
                        case _:
                    }
                }
                ready.value = measurementReady;
                draw(frame.height);
                if (!measurementReady) {
                    assertFloatEquals(-100, state.scrollPxOffsetForScrollbar().y, name);
                    assertOffset(listOffset(1, 0), state.logicalScrollTop(), name);
                    assertEquals(null, state.itemIsAboveViewport(2), name);
                }
                final paused = name == 'pause_tail' || name == 'disable_tail';
                final expected = if (measurementReady && paused) {
                    [p(1, 0, 150), p(2, 150, 300)];
                }
                else {
                    frame.expected;
                }
                assertEquals(name == 'follow_tail' || (paused && !measurementReady), state.isFollowingTail(), name);
                assertPainted(expected, painted, name);
            }
            ready.value = false;
            navigation.navigate(state);
            draw(150);
            state.scrollBy(px(-20));
            draw(150);
            assertOffset(listOffset(1, 80), state.logicalScrollTop(), name);
            assertFalse(state.isFollowingTail(), name);
            assertPainted([p(1, -80, 70), p(2, 70, 220)], painted, name);
        }
    }

    function testUnreadyOverdrawAndBackfillPreserveScrollAnchor() {
        addEmptyWindow();
        for (c in [{overdraw: 100.0, anchor: listOffset(0, 0), unreadyItem: 2}, {overdraw: 0.0, anchor: listOffset(2, 40), unreadyItem: 1}]) {
            final unreadyItem = c.unreadyItem;
            final anchor = c.anchor;
            final state = new ListState(3, ListAlignment.Top, px(c.overdraw));
            final ready = new Ref(false);
            state.setItemMeasurementReadiness((index, _) -> index != unreadyItem || ready.value);
            final painted:Array<String> = [];
            final draw = (height:Float) -> {
                painted.resize(0);
                drawList(state, 200, index -> paintedItem(index, index == unreadyItem ? height : 100, painted));
            };
            state.setFollowMode(FollowMode.Tail);
            state.scrollTo(anchor);
            draw(0);
            assertOffset(anchor, state.logicalScrollTop());
            assertFalse(state.isFollowingTail());
            assertPainted(
                unreadyItem == 2 ? [p(0, 0, 100), p(1, 100, 200)] : [p(2, -40, 60)],
                painted
            );
            ready.value = true;
            draw(500);
            if (unreadyItem == 2) {
                assertOffset(anchor, state.logicalScrollTop());
                assertFalse(state.isFollowingTail());
                assertFloatEquals(500, state.maxOffsetForScrollbar().y);
                assertPainted([p(0, 0, 100), p(1, 100, 200)], painted);
            }
            else {
                assertOffset(listOffset(1, 400), state.logicalScrollTop());
                assertTrue(state.isFollowingTail());
                assertPainted([p(1, -400, 100), p(2, 100, 200)], painted);
            }
        }
    }

    function testUnreadyOverdrawStopsAtFirstPendingItem() {
        addEmptyWindow();
        for (anchor in [0, 10]) {
            final state = new ListState(13, ListAlignment.Top, px(100));
            final ready = new Ref(false);
            final initiallyReady = (index:Int) -> anchor == 0 ? index < 2 : index >= 10;
            state.setItemMeasurementReadiness((index, _) -> initiallyReady(index) || ready.value);
            state.scrollTo(listOffset(anchor, 0));
            final rendered:Array<Int> = [];
            final painted:Array<String> = [];
            final expectedFrames = if (anchor == 0) {
                [[0, 1, 2], [0, 1, 2], [0, 1, 2], [0, 1]];
            }
            else {
                [[10, 11, 12, 9], [10, 11, 9], [10, 11, 9], [10, 11]];
            }
            for (frame in 0...expectedFrames.length) {
                final expectedRendered = expectedFrames[frame];
                final measurementReady = frame >= 2;
                ready.value = measurementReady;
                rendered.resize(0);
                painted.resize(0);
                drawList(state, 200, index -> {
                    rendered.push(index);
                    final height = initiallyReady(index) || measurementReady ? 100 : 0;
                    return paintedItem(index, height, painted);
                });
                assertEquals(expectedRendered.join(','), rendered.join(','));
                assertEquals(13, state.itemCount());
                assertOffset(listOffset(anchor, 0), state.logicalScrollTop());
                assertPainted([p(anchor, 0, 100), p(anchor + 1, 100, 200)], painted);
            }
        }
    }

    function testScrollbarAndResetDoNotResurrectProvisional() {
        addEmptyWindow();
        final state = new ListState(20, ListAlignment.Top, px(0));
        final painted:Array<String> = [];
        final draw = () -> {
            painted.resize(0);
            drawList(state, 200, index -> paintedItem(index, index == 5 ? 0 : 50, painted));
        };
        state.setItemMeasurementReadiness((index, _) -> index != 5);
        assertFalse(state.isProvisional());
        state.setFollowMode(FollowMode.Tail);
        for (interveningFrame in [false, true]) {
            state.scrollTo(listOffset(5, 20));
            state.remeasureItems(5, 6);
            draw();
            state.scrollbarDragStarted();
            if (interveningFrame) {
                draw();
                assertTrue(state.isProvisional());
            }
            state.setOffsetFromScrollbar(new Point(0, -10000));
            assertFalse(state.isProvisional());
            state.scrollbarDragEnded();
            assertFalse(state.isScrollbarDragging());
            draw();
            assertEquals(p(19, 150, 200), painted[painted.length - 1]);
            assertFalse(state.isProvisional());
            state.scrollTo(listOffset(5, 20));
            assertFalse(state.isProvisional());
            draw();
            assertTrue(state.isProvisional());
            assertOffset(listOffset(5, 20), state.logicalScrollTop());
        }
        state.remeasureItems(5, 6);
        state.reset(20);
        assertFalse(state.isProvisional());
        draw();
        assertFalse(state.isProvisional());
        assertOffset(new ListOffset(), state.logicalScrollTop());
        assertEquals(p(0, 0, 50), firstPainted(painted));
    }

    function testSplicePreservesOnlySurvivingScrollOffsets() {
        addEmptyWindow();
        final painted:Array<String> = [];
        final draw = (state:ListState, height:Float) -> {
            painted.resize(0);
            drawList(state, 200, index -> paintedItem(index, height, painted));
        };
        for (c in [{provisional: true, replacementCount: 0}, {provisional: false, replacementCount: 1}]) {
            final state = new ListState(20, ListAlignment.Top, px(0));
            final ready = itemReadiness(state, !c.provisional);
            state.scrollTo(listOffset(8, 50));
            state.remeasureItems(8, 9);
            if (c.provisional) {
                draw(state, 100);
            }
            state.splice(8, 9, c.replacementCount);
            assertFalse(state.isProvisional());
            ready.value = true;
            draw(state, 100);
            assertOffset(listOffset(8, 0), state.logicalScrollTop());
            assertEquals(p(8, 0, 100), firstPainted(painted));
        }
        final state = new ListState(20, ListAlignment.Top, px(0)).measureAll();
        state.scrollTo(listOffset(8, 50));
        draw(state, 100);
        state.remeasure();
        state.splice(0, 2, 0);
        draw(state, 80);
        assertOffset(listOffset(6, 40), state.logicalScrollTop());
        assertEquals(p(6, -40, 40), firstPainted(painted));
        final ready = itemReadiness(state, false);
        state.remeasureItems(6, 7);
        state.splice(8, 10, 3);
        draw(state, 100);
        assertTrue(state.isProvisional());
        assertOffset(listOffset(6, 40), state.logicalScrollTop());
        state.splice(0, 0, 2);
        assertFalse(state.isProvisional());
        draw(state, 100);
        assertTrue(state.isProvisional());
        assertOffset(listOffset(8, 40), state.logicalScrollTop());
        ready.value = true;
        draw(state, 100);
        assertOffset(listOffset(8, 40), state.logicalScrollTop());
        assertEquals(p(8, -40, 60), firstPainted(painted));
    }

    function testChildAutoscrollOverridesPendingAndReleaseFillsViewport() {
        addEmptyWindow();
        final cases = [
            {count: 10, child: 2, requestStart: 40.0, requestEnd: 45.0, expected: listOffset(2, 40), released: listOffset(2, 40)},
            {count: 3, child: 2, requestStart: 40.0, requestEnd: 45.0, expected: listOffset(2, 40), released: listOffset(1, 0)},
            {count: 10, child: 4, requestStart: 80.0, requestEnd: 90.0, expected: listOffset(2, 90), released: listOffset(2, 90)},
            {count: 10, child: 2, requestStart: -130.0, requestEnd: 5.0, expected: listOffset(0, 70), released: listOffset(0, 70)},
            {count: 10, child: 2, requestStart: -250.0, requestEnd: 5.0, expected: listOffset(0, 0), released: listOffset(0, 0)},
        ];
        for (c in cases) {
            final state = new ListState(c.count, ListAlignment.Top, px(0));
            var requested = false;
            final painted:Array<String> = [];
            final draw = () -> {
                painted.resize(0);
                drawList(state, 200, index -> {
                    return canvas((bounds, window, _) -> {
                        if (index == c.child && !requested) {
                            requested = true;
                            window.requestAutoscroll(Bounds.fromCorners(
                                new Point(bounds.left(), bounds.top() + c.requestStart),
                                new Point(bounds.right(), bounds.top() + c.requestEnd)
                            ));
                        }
                        return 0;
                    }, (bounds, _, _, _) -> {
                        painted.push(p(index, bounds.top(), bounds.bottom()));
                    }).h(px(100)).wFull();
                });
            };
            final ready = itemReadiness(state, false);
            state.scrollTo(listOffset(2, 50));
            state.remeasureItems(2, 3);
            final expected = c.expected;
            for (_ in 0...2) {
                draw();
                assertTrue(requested);
                assertTrue(state.isProvisional());
                assertOffset(expected, state.logicalScrollTop());
                assertEquals(p(expected.itemIx, -expected.offsetInItem, 100 - expected.offsetInItem), firstPainted(painted));
            }
            ready.value = true;
            draw();
            assertFalse(state.isProvisional());
            final released = c.released;
            assertOffset(released, state.logicalScrollTop());
            final visibleCount = released.offsetInItem == 0 ? 2 : 3;
            assertPainted([for (index in 0...visibleCount) {
                final top = index * 100 - released.offsetInItem;
                p(released.itemIx + index, top, top + 100);
            }], painted);
        }
    }

    function testRemeasureThenScrollDoesNotRevertScrollPosition() {
        addEmptyWindow();

        final state = new ListState(20, ListAlignment.Top, px(10));
        final build = () -> list(state, (_, _, _) -> div().h(px(100)).wFull()).wFull().hFull();

        state.scrollTo(new ListOffset(5, 40));

        drawAt(100, 200, build);

        state.remeasureItems(5, 6);

        simulateScroll(50, 100, 0, -30);

        var offset = state.logicalScrollTop();
        assertEquals(5, offset.itemIx);
        assertFloatEquals(70, offset.offsetInItem);

        drawAt(100, 200, build);

        offset = state.logicalScrollTop();
        assertEquals(5, offset.itemIx);
        assertFloatEquals(70, offset.offsetInItem, 0.00001, 'scrolling after a remeasure should not be reverted by the stale pending scroll');
    }

    function testScrollAfterRemeasureClampsToShrunkItemHeight() {
        addEmptyWindow();
        for (provisional in [false, true]) {
            final state = new ListState(20, ListAlignment.Top, px(10));
            final painted:Array<String> = [];
            final draw = (height:Float) -> {
                painted.resize(0);
                drawList(state, 200, index -> paintedItem(index, index == 5 ? height : 100, painted));
            };
            final ready = itemReadiness(state, true);
            state.scrollTo(listOffset(5, 40));
            draw(100);
            ready.value = !provisional;
            state.remeasureItems(5, 6);
            if (provisional) {
                draw(100);
            }
            ready.value = true;
            simulateScroll(50, 100, 0, -30);
            assertOffset(listOffset(5, 70), state.logicalScrollTop());
            for (_ in 0...2) {
                draw(50);
                assertOffset(listOffset(5, 50), state.logicalScrollTop());
                assertEquals(p(6, 0, 100), findPainted(painted, 6));
            }
        }
    }

    function testFollowTailStaysAtBottomAsItemsGrow() {
        addEmptyWindow();

        // 10 items, each 50px tall: 500px total content, 200px viewport.
        // With follow-tail on, the list should always show the bottom.
        var itemHeight = 50;
        final state = new ListState(10, ListAlignment.Top, px(0));
        final build = () -> {
            final height = itemHeight;
            return list(state, (_, _, _) -> div().h(px(height)).wFull()).wFull().hFull();
        };

        state.setFollowMode(FollowMode.Tail);

        // First paint: items are 50px, total 500px, viewport 200px.
        // Follow-tail should anchor to the end.
        drawAt(100, 200, build);

        // The scroll should be at the bottom: the last visible items fill the
        // 200px viewport from the end of 500px of content (offset 300px).
        var offset = state.logicalScrollTop();
        assertEquals(6, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
        assertTrue(state.isFollowingTail());

        // Simulate items growing (e.g. streaming content makes each item taller).
        // 10 items x 80px = 800px total.
        itemHeight = 80;
        state.remeasure();

        drawAt(100, 200, build);

        // After growth, follow-tail should have re-anchored to the new end:
        // 800px total - 200px viewport = 600px offset, item 7 at offset 40px.
        offset = state.logicalScrollTop();
        assertEquals(7, offset.itemIx);
        assertFloatEquals(40, offset.offsetInItem);
        assertTrue(state.isFollowingTail());
    }

    function testPauseFollowingTailReengagesWhenStillAtBottom() {
        addEmptyWindow();

        // 10 items x 50px = 500px total, 200px viewport.
        final state = new ListState(10, ListAlignment.Top, px(0));
        final build = () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull();

        state.setFollowMode(FollowMode.Tail);

        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail());

        // Pausing while the view is still at the bottom (e.g. a no-op zoom)
        // must not strand follow-tail: the next layout has to re-engage so the
        // invariant "at the bottom + new content => visible" is preserved.
        state.pauseFollowingTail();
        assertFalse(state.isFollowingTail());

        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail(), 'pausing while at the bottom must re-engage follow-tail on the next layout');
    }

    function testPauseFollowingTailFreezesOffBottom() {
        addEmptyWindow();

        // 10 items, 200px viewport. Item height is adjustable to simulate a
        // diagram block growing/shrinking on zoom.
        var itemHeight = 50;
        final state = new ListState(10, ListAlignment.Top, px(0));
        final build = () -> {
            final height = itemHeight;
            return list(state, (_, _, _) -> div().h(px(height)).wFull()).wFull().hFull();
        };
        state.setFollowMode(FollowMode.Tail);

        // At the bottom: 500px content, 200px viewport, top at item 6.
        drawAt(100, 200, build);
        assertEquals(6, state.logicalScrollTop().itemIx);
        assertTrue(state.isFollowingTail());

        // Pause, then grow items (a zoom-in that pushes content below the fold).
        // The frozen top must stay put rather than snapping to the new end, and
        // following stays paused since we're no longer at the bottom.
        state.pauseFollowingTail();
        itemHeight = 80;
        state.remeasure();
        drawAt(100, 200, build);
        final offset = state.logicalScrollTop();
        assertEquals(6, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
        assertFalse(state.isFollowingTail(), 'a paused list must not re-engage while the frozen top is off the bottom');

        // Shrink back (zoom-out) so the frozen top once again reaches the
        // bottom: follow-tail must re-engage on its own.
        itemHeight = 50;
        state.remeasure();
        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail(), 'returning to the bottom must restore follow-tail');
    }

    function testFollowTailDisengagesOnUserScroll() {
        addEmptyWindow();

        // 10 items x 50px = 500px total, 200px viewport.
        final state = new ListState(10, ListAlignment.Top, px(0));

        state.setFollowMode(FollowMode.Tail);

        // Paint with follow-tail: scroll anchored to the bottom.
        drawAt(100, 200, () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull());
        assertTrue(state.isFollowingTail());

        // Simulate the user scrolling up.
        // This should disengage follow-tail.
        simulateScroll(50, 100, 0, 100);

        assertFalse(state.isFollowingTail(), 'follow-tail should disengage when the user scrolls toward the start');
    }

    function testFollowTailDisengagesOnScrollbarReposition() {
        addEmptyWindow();

        // 10 items x 50px = 500px total, 200px viewport.
        final state = new ListState(10, ListAlignment.Top, px(0)).measureAll();
        final build = () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull();

        state.setFollowMode(FollowMode.Tail);

        // Paint with follow-tail: scroll anchored to the bottom.
        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail());

        // Simulate the scrollbar moving the viewport to the middle.
        state.setOffsetFromScrollbar(new Point(0, -150));

        var offset = state.logicalScrollTop();
        assertEquals(3, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
        assertFalse(state.isFollowingTail(), 'follow-tail should disengage when the scrollbar manually repositions the list');

        // A subsequent draw should preserve the user's manual position instead
        // of snapping back to the end.
        drawAt(100, 200, build);

        offset = state.logicalScrollTop();
        assertEquals(3, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
    }

    function testScrollbarDragWithGrowingContent() {
        addEmptyWindow();

        var lastItemHeight = 50;
        final state = new ListState(10, ListAlignment.Top, px(0)).measureAll();
        final build = () -> list(state, (index, _, _) -> {
            final height = index == 9 ? lastItemHeight : 50;
            return div().h(px(height)).wFull();
        }).wFull().hFull();

        drawAt(100, 200, build);

        state.scrollbarDragStarted();

        state.setOffsetFromScrollbar(new Point(0, -150));
        final scrollbarOffsetBeforeGrowth = state.scrollPxOffsetForScrollbar();

        var offset = state.logicalScrollTop();
        assertEquals(3, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);

        lastItemHeight = 550;
        state.remeasureItems(9, 10);
        drawAt(100, 200, build);

        assertFloatEquals(300, state.maxOffsetForScrollbar().y);
        assertTrue(state.scrollPxOffsetForScrollbar().equals(scrollbarOffsetBeforeGrowth));

        state.setOffsetFromScrollbar(new Point(0, -150));
        offset = state.logicalScrollTop();
        assertEquals(3, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
    }

    function testSetFollowTailSnapsToBottom() {
        addEmptyWindow();

        // 10 items x 50px = 500px total, 200px viewport.
        final state = new ListState(10, ListAlignment.Top, px(0));
        final build = () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull();

        // Scroll to the middle of the list (item 3).
        state.scrollTo(new ListOffset(3, 0));

        drawAt(100, 200, build);

        var offset = state.logicalScrollTop();
        assertEquals(3, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
        assertFalse(state.isFollowingTail());

        // Enable follow-tail: this should immediately snap the scroll anchor
        // to the end, like the user just sent a prompt.
        state.setFollowMode(FollowMode.Tail);

        drawAt(100, 200, build);

        // After paint, scroll should be at the bottom.
        // 500px total - 200px viewport = 300px offset: item 6, offset 0.
        offset = state.logicalScrollTop();
        assertEquals(6, offset.itemIx);
        assertFloatEquals(0, offset.offsetInItem);
        assertTrue(state.isFollowingTail());
    }

    function testBottomAlignedScrollbarOffsetAtEnd() {
        addEmptyWindow();

        final items = 10;
        final itemSize = 50.0;

        final state = new ListState(items, ListAlignment.Bottom, px(items * itemSize));

        drawAt(100, 100, () -> list(state, (_, _, _) -> div().h(px(itemSize)).wFull()).wFull().hFull());

        // Bottom-aligned lists start pinned to the end: logicalScrollTop returns
        // itemIx == item count, meaning no explicit scroll position has been set.
        assertEquals(items, state.logicalScrollTop().itemIx);

        final maxOffset = state.maxOffsetForScrollbar();
        final scrollOffset = state.scrollPxOffsetForScrollbar();

        assertFloatEquals(maxOffset.y, -scrollOffset.y, 0.00001, 'scrollbar offset should equal max offset when list is pinned to bottom');
    }

    /**
     * When the user scrolls away from the bottom during follow_tail,
     * follow_tail suspends. If they scroll back to the bottom, the
     * next paint should re-engage follow_tail using fresh measurements.
     */
    function testFollowTailReengagesWhenScrolledBackToBottom() {
        addEmptyWindow();

        // 10 items x 50px = 500px total, 200px viewport.
        final state = new ListState(10, ListAlignment.Top, px(0));
        final build = () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull();

        state.setFollowMode(FollowMode.Tail);

        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail());

        // Scroll up: follow_tail should suspend (not fully disengage).
        simulateScroll(50, 100, 0, 50);
        assertFalse(state.isFollowingTail());

        // Scroll back down to the bottom.
        simulateScroll(50, 100, 0, -10000);

        // After a paint, follow_tail should re-engage because the
        // layout confirmed we're at the true bottom.
        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail(), 'follow_tail should re-engage after scrolling back to the bottom');
    }

    /**
     * When an item is spliced to unmeasured (0px) while follow_tail
     * is suspended, the re-engagement check should still work correctly.
     */
    function testFollowTailReengagementNotFooledByUnmeasuredItems() {
        addEmptyWindow();

        // 20 items x 50px = 1000px total, 200px viewport, 1000px
        // overdraw so all items get measured during the follow_tail
        // paint (matching realistic production settings).
        final state = new ListState(20, ListAlignment.Top, px(1000));
        final build = () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull();

        state.setFollowMode(FollowMode.Tail);

        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail());

        // Scroll up a meaningful amount: suspends follow_tail.
        // 20 items x 50px = 1000px. viewport 200px. scroll_max = 800px.
        // Scrolling up 200px puts us at 600px, clearly not at bottom.
        simulateScroll(50, 100, 0, 200);
        assertFalse(state.isFollowingTail());

        // Invalidate the last item (simulates EntryUpdated calling
        // remeasure_items). This makes the summary height
        // temporarily wrong (0px for the invalidated item).
        state.remeasureItems(19, 20);

        // Paint: layout re-measures the invalidated item with its true
        // height. Since we scrolled 200px up from the 800px max, we're at
        // ~600px, NOT at the bottom, so follow_tail should NOT re-engage.
        drawAt(100, 200, build);
        assertFalse(state.isFollowingTail(), 'follow_tail should not falsely re-engage due to an unmeasured item reducing the summary height');
    }

    function testFollowTailReengagesAfterScrollbarDisengagement() {
        addEmptyWindow();

        // 10 items x 50px = 500px total, 200px viewport, scroll_max = 300px.
        final state = new ListState(10, ListAlignment.Top, px(0)).measureAll();
        final build = () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull();

        state.setFollowMode(FollowMode.Tail);
        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail());

        // Drag the scrollbar up to the middle: follow_tail should suspend.
        state.setOffsetFromScrollbar(new Point(0, -150));
        assertFalse(state.isFollowingTail());

        // Drag the scrollbar back to the bottom: follow_tail should re-engage
        // on the next paint.
        state.setOffsetFromScrollbar(new Point(0, -300));
        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail(), 'follow_tail should re-engage after scrolling back to the bottom via the scrollbar');
    }

    function testFollowTailReengagesAfterScrollbarDragToBottomWhileGrowing() {
        addEmptyWindow();

        final state = new ListState(10, ListAlignment.Top, px(0)).measureAll();
        final build = () -> list(state, (_, _, _) -> div().h(px(50)).wFull()).wFull().hFull();

        state.setFollowMode(FollowMode.Tail);
        drawAt(100, 200, build);
        assertTrue(state.isFollowingTail());

        state.scrollbarDragStarted();

        state.splice(10, 10, 10);
        drawAt(100, 200, build);

        state.setOffsetFromScrollbar(new Point(0, -300));
        state.scrollbarDragEnded();

        drawAt(100, 200, build);

        assertTrue(state.isFollowingTail(),
            'follow_tail should re-engage when the user drags the scrollbar to the bottom of its track, even when content has grown during the drag');
    }

}

/**
 * The window root of `ListTest`: renders the element under test in a box of
 * the given size at the window origin (stands for Rust's `cx.draw`).
 */
class ListTestHost extends Model implements Render {

    public var width:Float = 0;

    public var height:Float = 0;

    public var build:Null<() -> gpui.Element> = null;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final root = div().sizeFull();
        if (build != null) {
            root.child(div().absolute().left(px(0)).top(px(0)).w(px(width)).h(px(height)).child(build()));
        }
        return root;
    }

}

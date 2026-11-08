// Ported from gpui-kit 0.8.1: crates/component/src/message_scroller.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.ListOffset;
import glaze.Point;
import glaze.ScrollEvent;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.messagescroller.MessageScroller;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's `message_scroller` module.
 */
class MessageScrollerTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function newState(itemCount:Int):Entity<MessageScrollerState> {
        return app.update(cx -> cx.newEntity((c:Context<MessageScrollerState>) -> new MessageScrollerState(itemCount, c)));
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        return opened.cx;
    }

    /** The `ScrollerHarness` view of the Rust tests. */
    function harness(state:Entity<MessageScrollerState>):VisualTestContext {
        return open((_, _) -> div().size(px(400.)).child(
            MessageScroller.component('messages', state, (_, _, _) -> div().h(px(40.)))
                .scrollbar(false)
                .jumpButton(false)
        ));
    }

    static function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
    }

    function testMessageScrollerStateBuilder() {
        final state = newState(3);

        app.update(cx -> {
            assertEquals(3, state.read(cx).itemCount());
            assertFalse(state.read(cx).isScrolledUp());
            assertTrue(state.read(cx).isFollowingTail());

            state.update(cx, (state, cx) -> {
                assertFalse(state.scrollToItem(3, cx));
                assertTrue(state.append(2, cx));
                assertEquals(5, state.itemCount());
                assertTrue(state.prepend(1, cx));
                assertEquals(6, state.itemCount());
                assertFalse(state.splice(5, 7, 0, cx));
                assertTrue(state.remeasureItems(0, 6, cx));
                assertFalse(state.remeasureItems(6, 7, cx));
                assertTrue(state.scrollToItem(2, cx));
                assertFalse(state.isScrolledUp());
                assertFalse(state.isFollowingTail());
                state.scrollToEnd(cx);
                assertTrue(state.isFollowingTail());
                state.reset(2, cx);
                assertEquals(2, state.itemCount());
                assertTrue(state.isFollowingTail());
            });
        });
    }

    function testLogicalScrollTopReportsTheRowAtTheTop() {
        final state = newState(30);
        final cx = harness(state);
        function top():ListOffset {
            return cx.update((_, cx) -> state.read(cx).logicalScrollTop());
        }
        draw(cx);

        // Following the tail, layout settles on the row the tail starts on.
        final tail = top();
        assertTrue(tail.itemIx > 0 && tail.itemIx < 30, 'the row at the top while following the tail: $tail');

        cx.update((_, cx) -> state.update(cx, (state, cx) -> state.scrollToItem(10, cx)));
        draw(cx);
        assertEquals(10, top().itemIx);

        // A wheel scroll by one row: its 40px and the 32px gap after it.
        cx.simulateEvent(new ScrollEvent(new Point(200., 200.), Pixels(new Point(0., -72.))));
        final afterWheel = top();
        assertEquals(11, afterWheel.itemIx);
        assertEquals(0., afterWheel.offsetInItem);
    }

    /**
     * A scrollbar drag to the bottom of the track must reach the end of the
     * content: the thumb's range is the list's scroll extent, and an extent
     * that stops short of the end leaves the reader above the last row, with
     * the tail-follow off and the jump button showing.
     */
    function testTheScrollbarDragRangeReachesTheEndOfTheContent() {
        final state = newState(10);
        final cx = harness(state);
        draw(cx);

        // Drag the thumb to the bottom of the track: the scrollbar maps that
        // to the largest offset it reports for the list.
        cx.update((_, cx) -> {
            final listState = state.read(cx).listState;
            listState.scrollbarDragStarted();
            final max = listState.maxOffsetForScrollbar().y;
            listState.setOffsetFromScrollbar(new Point(0., -max));
            listState.scrollbarDragEnded();
        });

        cx.update((_, cx) -> {
            final listState = state.read(cx).listState;
            assertEquals(true, listState.isScrolledToEnd(), 'the drag must land on the end of the content');
            assertTrue(listState.isFollowingTail(), 'the drag to the end must resume the tail');
            assertFalse(state.read(cx).isScrolledUp(), 'the jump-to-latest button must hide at the end of the content');
        });
    }

    /**
     * A custom list padding must ride on the first and the last row, the way
     * the list's own padding does. Carried by every row it would give every
     * message the list's padding instead of giving it to the list.
     */
    function testACustomListPaddingRidesOnTheFirstAndTheLastRow() {

        final first = newState(10);
        final second = newState(10);
        final third = newState(10);

        function extent(state:Entity<MessageScrollerState>, listStyle:StyleRefinement):Float {
            final context = open((_, _) -> div().size(px(400.)).child(
                MessageScroller.component('messages', state, (_, _, _) -> div().h(px(40.)))
                    .scrollbar(false)
                    .jumpButton(false)
                    .withListStyle(listStyle.clone())
                    .withRowStyle(StyleBuilder.build(s -> s.pt(px(6.)).pb(px(6.))))
            ));
            context.runUntilParked();
            return context.update((window, cx) -> {
                window.draw();
                return state.read(cx).listState.maxOffsetForScrollbar().y;
            });
        }

        final firstExtent = extent(first, StyleBuilder.build(s -> s.pt(px(20.)).pb(px(40.))));
        final secondExtent = extent(second, StyleBuilder.build(s -> s.pt(px(20.)).pb(px(20.))));
        final thirdExtent = extent(third, StyleBuilder.build(s -> s.pt(px(40.)).pb(px(20.))));

        // The bottom inset rides on the last row only, so the content grows
        // by the difference between the two bottom insets, not once per row.
        assertEquals(20., firstExtent - secondExtent, 'the bottom inset must ride on the last row only');
        // The top inset rides on the first row only.
        assertEquals(20., thirdExtent - secondExtent, 'the top inset must ride on the first row only');
    }

    function testMessageScrollerBuilder() {
        final state = newState(0);
        final scroller = MessageScroller.component('message-scroller', state, (_, _, _) -> div())
            .scrollbar(false)
            .jumpButton(false)
            .withJumpButtonLabel('Latest')
            .withContentStyle(new StyleRefinement())
            .withListStyle(new StyleRefinement())
            .withRowStyle(new StyleRefinement())
            .withJumpButtonStyle(new StyleRefinement())
            .withJumpButtonRenderer(button -> button.large())
            .withJumpButtonTransition(0.3)
            .withBottomFade(white());

        assertFalse(scroller.scrollbarValue);
        assertFalse(scroller.jumpButtonValue);
        assertEquals('Latest', scroller.jumpButtonLabel);
        assertNotNull(scroller.jumpButtonRenderer);
        assertEquals(0.3, scroller.jumpButtonTransition);
        assertTrue(scroller.bottomFade.equals(white()));
    }

}

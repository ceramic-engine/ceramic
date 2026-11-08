// Ported from gpui-kit 0.8.1: crates/component/src/carousel/state.rs (tests),
// crates/component/src/carousel/carousel.rs (tests), crates/component/src/carousel/scroll_mask.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Axis;
import glaze.Bounds;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.Point;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.Size;
import glaze.Subscription;
import glaze.TestDispatcher;
import glaze.TouchPhase;
import glaze.Window;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.button.Button;
import glaze.kit.carousel.Carousel;
import glaze.kit.carousel.CarouselContent;
import glaze.kit.carousel.CarouselItem;
import glaze.kit.carousel.CarouselNext;
import glaze.kit.carousel.CarouselPaginationItem;
import glaze.kit.carousel.CarouselPrevious;
import glaze.kit.carousel.CarouselState;
import glaze.kit.carousel.CarouselState.CarouselEvent;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's carousel (`state.rs`,
 * `carousel.rs`, `scroll_mask.rs`). The tests that take no `TestAppContext`
 * run on a bare state, like in Rust; the others on a test app.
 */
class ComponentCarouselTest extends TestCase {

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

    static function b(x:Float, y:Float, w:Float, h:Float):Bounds {
        return new Bounds(new Point(x, y), new Size(w, h));
    }

    static function p(x:Float, y:Float):Point {
        return new Point(x, y);
    }

    function assertPoint(expected:Null<Point>, actual:Null<Point>, ?pos:haxe.PosInfos) {
        if (expected == null || actual == null) {
            assertEquals(expected == null ? 'null' : expected.toString(), actual == null ? 'null' : actual.toString(), pos);
            return;
        }
        assertEquals(expected.x + ',' + expected.y, actual.x + ',' + actual.y, pos);
    }

    function newState(build:() -> CarouselState):Entity<CarouselState> {
        var state:Entity<CarouselState> = null;
        app.update(cx -> state = cx.newEntity((_:Context<CarouselState>) -> build()));
        return state;
    }

    function update(state:Entity<CarouselState>, f:(CarouselState, Context<CarouselState>) -> Void):Void {
        app.update(cx -> state.update(cx, (s, cx) -> f(s, cx)));
    }

    function events(state:Entity<CarouselState>):{list:Array<Int>, subscription:Subscription} {
        final list:Array<Int> = [];
        var subscription:Subscription = null;
        app.update(cx -> subscription = cx.subscribe(state, CarouselEvent, (_, event, _) -> switch event {
            case Change(index): list.push(index);
        }));
        return {list: list, subscription: subscription};
    }

    function runUntilParked() {
        dispatcher.runUntilParked();
    }

    function advanceClock(seconds:Float) {
        dispatcher.advanceClock(seconds);
    }

/// state.rs

    function testConstructorsAndProgrammaticSettersClampWithoutEvents() {
        final state = new CarouselState(3).withSelectedIndex(99).withAxis(Vertical).withLooping(true);
        assertEquals(3, state.itemCount());
        assertEquals(2, state.selectedIndex());
        assertEquals(Vertical, state.axis());
        assertTrue(state.isLooping());
        assertTrue(state.hasPrevious());
        assertTrue(state.hasNext());

        final empty = new CarouselState(0);
        assertEquals(null, empty.selectedIndex());
        assertFalse(empty.hasPrevious());
        assertFalse(empty.hasNext());
    }

    function testGeometryProducesAxisSpecificSnapPoints() {
        final state = new CarouselState(2).withAxis(Horizontal);
        state.setGeometry(b(10, 20, 100, 40), [b(10, 20, 100, 40), b(110, 20, 100, 40)]);
        assertPoint(p(0, 0), state.snapTargetFor(0));
        assertPoint(p(-100, 0), state.snapTargetFor(1));
        final vertical = new CarouselState(2).withAxis(Vertical);
        vertical.setGeometry(b(10, 20, 40, 100), [b(10, 20, 40, 100), b(10, 120, 40, 100)]);
        assertPoint(p(0, -100), vertical.snapTargetFor(1));

        final narrow = new CarouselState(3);
        narrow.setGeometry(b(0, 0, 100, 40), [b(0, 0, 50, 40), b(50, 0, 50, 40), b(100, 0, 50, 40)]);
        assertPoint(p(-50, 0), narrow.snapTargetFor(2));
    }

    function testNearestIndexKeepsTheFirstTrailingDuplicateAsCanonical() {
        final state = new CarouselState(3);
        state.setGeometry(b(0, 0, 100, 40), [b(0, 0, 50, 40), b(50, 0, 50, 40), b(100, 0, 50, 40)]);
        assertPoint(p(-50, 0), state.snapTargetFor(1));
        assertPoint(p(-50, 0), state.snapTargetFor(2));
        assertEquals(1, state.nearestIndex(p(-50, 0)));
    }

    function testGeometryNavigationSkipsDuplicateSnapPoints() {
        final state = newState(() -> new CarouselState(3));
        update(state, (state, cx) -> {
            state.setGeometry(b(0, 0, 100, 40), [b(0, 0, 50, 40), b(50, 0, 50, 40), b(100, 0, 50, 40)]);
            state.setSelectedIndex(1, cx);
            assertFalse(state.hasNext());
            assertTrue(state.hasPrevious());

            assertTrue(state.selectPrevious(cx));
            assertEquals(0, state.selectedIndex());
            assertTrue(state.selectNext(cx));
            assertEquals(1, state.selectedIndex());

            state.setSelectedIndex(2, cx);
            assertFalse(state.hasNext());
            assertTrue(state.selectPrevious(cx));
            assertEquals(0, state.selectedIndex());
        });
    }

    function testNonLoopingNavigationStopsAtBothBoundaries() {
        final state = newState(() -> new CarouselState(3));
        final events = events(state);
        update(state, (state, cx) -> {
            assertFalse(state.selectPrevious(cx));
            assertFalse(state.selectFirst(cx));
            assertTrue(state.selectLast(cx));
            assertFalse(state.selectNext(cx));
            assertFalse(state.selectLast(cx));
        });
        assertEquals('2', events.list.join(','));
    }

    function testUserNavigationEmitsOnceAndProgrammaticChangesStaySilent() {
        final state = newState(() -> new CarouselState(3));
        final events = events(state);
        update(state, (state, cx) -> {
            assertTrue(state.selectNext(cx));
            assertFalse(state.selectIndex(1, cx));
            assertFalse(state.selectIndex(99, cx));
            state.setSelectedIndex(2, cx);
            state.setAxis(Vertical, cx);
            state.setLooping(true, cx);
        });
        assertEquals('1', events.list.join(','));
        assertEquals(2, state.read(app).selectedIndex());
        assertEquals(Vertical, state.read(app).axis());
        assertTrue(state.read(app).isLooping());

        final empty = newState(() -> new CarouselState(0));
        update(empty, (state, cx) -> {
            state.setItemCount(2, cx);
            state.setSelectedIndex(99, cx);
        });
        assertEquals(1, empty.read(app).selectedIndex());
    }

    function testPointerDragLocksToThePrimaryAxis() {
        final state = newState(() -> new CarouselState(3));
        update(state, (state, cx) -> {
            assertTrue(state.beginDrag(p(0, 0), cx));
            assertFalse(state.updateDrag(p(1, 1), cx));
            assertTrue(state.isInteracting());
            assertFalse(state.isPointerDragLocked());
            assertFalse(state.updateDrag(p(4, 20), cx));
            assertFalse(state.isInteracting());
            assertTrue(state.shouldSuppressPointerClick());
            assertFalse(state.finishDrag(cx));
            assertFalse(state.shouldSuppressPointerClick());

            assertTrue(state.beginDrag(p(0, 0), cx));
            assertTrue(state.updateDrag(p(20, 4), cx));
            assertTrue(state.isInteracting());
            assertTrue(state.isPointerDragLocked());
            state.finishDrag(cx);
            assertFalse(state.isInteracting());
        });
    }

    function testFinishingADragKeepsTheOffsetAsTheSnapAnimationOrigin() {
        final state = newState(() -> new CarouselState(2));
        update(state, (state, cx) -> {
            state.setGeometry(b(0, 0, 100, 40), [b(0, 0, 100, 40), b(100, 0, 100, 40)]);
            assertTrue(state.beginDrag(p(0, 0), cx));
            state.scrollHandleValue.setOffset(p(-60, 0));
            assertTrue(state.finishDrag(cx));
            assertEquals(1, state.selectedIndex());
            assertPoint(p(-60, 0), state.scrollHandleValue.offset());
        });
    }

    function testUserNavigationInvalidatesAnActiveTrackpadGesture() {
        final state = newState(() -> new CarouselState(3));
        final events = events(state);
        update(state, (state, cx) -> {
            state.handleScrollDelta(Horizontal, -20, Started, cx);
            assertTrue(state.isInteracting());
            assertTrue(state.selectNext(cx));
            assertFalse(state.isInteracting());
            assertFalse(state.handleScrollDelta(Horizontal, -20, Moved, cx));
            assertFalse(state.isInteracting());
            assertTrue(state.ignoreScrollUntilQuiet);
        });

        runUntilParked();
        advanceClock(CarouselState.SCROLL_EVENT_SEPARATION);
        runUntilParked();

        update(state, (state, cx) -> {
            assertFalse(state.ignoreScrollUntilQuiet);
            assertFalse(state.handleScrollDelta(Horizontal, -20, Moved, cx));
            assertTrue(state.isInteracting());
            assertFalse(state.finishScroll(true, cx));
            assertFalse(state.isInteracting());

            assertFalse(state.handleScrollDelta(Horizontal, -20, Started, cx));
            assertTrue(state.isInteracting());
            assertFalse(state.finishScroll(true, cx));
            assertFalse(state.isInteracting());
        });

        assertEquals('1', events.list.join(','));
    }

    function testMovedOnlyTrackpadGestureSettlesAfterTheQuietPeriod() {
        final state = newState(() -> new CarouselState(2));
        final events = events(state);
        update(state, (state, cx) -> {
            state.setGeometry(b(0, 0, 100, 40), [b(0, 0, 100, 40), b(100, 0, 100, 40)]);
            state.handleScrollDelta(Horizontal, -60, Moved, cx);
            state.scrollHandleValue.setOffset(p(-60, 0));
            assertTrue(state.isInteracting());
        });

        runUntilParked();
        advanceClock(CarouselState.SCROLL_EVENT_SEPARATION);
        runUntilParked();

        assertEquals(1, state.read(app).selectedIndex());
        assertFalse(state.read(app).isInteracting());
        assertEquals('1', events.list.join(','));
    }

    function testInvalidBoundaryNavigationStillCancelsTheActiveGesture() {
        final state = newState(() -> new CarouselState(2));
        update(state, (state, cx) -> {
            state.handleScrollDelta(Horizontal, 20, Started, cx);
            assertTrue(state.isInteracting());
            assertFalse(state.selectPrevious(cx));
            assertFalse(state.isInteracting());
            assertFalse(state.handleScrollDelta(Horizontal, 20, Moved, cx));
            assertFalse(state.finishScroll(false, cx));

            assertTrue(state.selectLast(cx));
            state.handleScrollDelta(Horizontal, -20, Started, cx);
            assertTrue(state.isInteracting());
            assertFalse(state.selectNext(cx));
            assertFalse(state.isInteracting());
            assertFalse(state.finishScroll(false, cx));
        });
    }

    function testLoopingBoundariesEmitOneEventAndAdvanceMotionRevision() {
        final state = newState(() -> new CarouselState(2).withLooping(true));
        final events = events(state);
        update(state, (state, cx) -> {
            assertTrue(state.selectPrevious(cx));
            assertEquals(1, state.selectedIndex());
            assertEquals(1, state.motionRevision());
            assertTrue(state.selectNext(cx));
            assertEquals(0, state.selectedIndex());
            assertEquals(2, state.motionRevision());
        });
        assertEquals('1,0', events.list.join(','));
    }

    function testLoopingUsesAdjacentCycleTargetsAndRebasesWithoutAnExtraEvent() {
        final state = newState(() -> new CarouselState(2).withLooping(true));
        final events = events(state);
        update(state, (state, cx) -> {
            final viewport = b(0, 0, 100, 40);
            state.setGeometry(viewport, [b(0, 0, 100, 40), b(100, 0, 100, 40)]);
            assertEquals(200., state.loopRunway());

            state.setGeometry(viewport, [b(200, 0, 100, 40), b(300, 0, 100, 40)]);
            assertPoint(p(-200, 0), state.scrollHandleValue.offset());

            assertTrue(state.selectPrevious(cx));
            assertEquals(1, state.selectedIndex());
            final previousTarget = state.motionTargetFor(1);
            assertPoint(p(-100, 0), previousTarget);
            assertEquals(100., previousTarget.x - state.scrollHandleValue.offset().x);
            assertPoint(p(-300, 0), state.settleLoopMotion(previousTarget, cx));

            assertTrue(state.selectNext(cx));
            assertEquals(0, state.selectedIndex());
            final nextTarget = state.motionTargetFor(0);
            assertPoint(p(-400, 0), nextTarget);
            assertEquals(-100., nextTarget.x - state.scrollHandleValue.offset().x);
            assertPoint(p(-200, 0), state.settleLoopMotion(nextTarget, cx));
        });
        assertEquals('1,0', events.list.join(','));
    }

    function testProgrammaticLoopWrapUsesTheAdjacentCycleWithoutEmitting() {
        final state = newState(() -> new CarouselState(2).withLooping(true));
        final events = events(state);
        update(state, (state, cx) -> {
            final viewport = b(0, 0, 100, 40);
            state.setGeometry(viewport, [b(0, 0, 100, 40), b(100, 0, 100, 40)]);
            state.setGeometry(viewport, [b(200, 0, 100, 40), b(300, 0, 100, 40)]);

            state.setSelectedIndex(1, cx);
            state.scrollHandleValue.setOffset(state.snapTargetFor(1));
            state.setSelectedIndex(0, cx);

            assertEquals(0, state.selectedIndex());
            assertPoint(p(-400, 0), state.motionTargetFor(0));
            assertPoint(p(-200, 0), state.settleLoopMotion(p(-400, 0), cx));
        });
        assertEquals(0, events.list.length);
    }

    function testVerticalLoopWrapUsesTheAdjacentCycle() {
        final state = newState(() -> new CarouselState(2).withAxis(Vertical).withLooping(true));
        update(state, (state, cx) -> {
            final viewport = b(0, 0, 40, 100);
            state.setGeometry(viewport, [b(0, 0, 40, 100), b(0, 100, 40, 100)]);
            state.setGeometry(viewport, [b(0, 200, 40, 100), b(0, 300, 40, 100)]);

            assertTrue(state.selectPrevious(cx));
            assertPoint(p(0, -100), state.motionTargetFor(1));
            assertPoint(p(0, -300), state.settleLoopMotion(p(0, -100), cx));
        });
    }

    function testUnequalItemsKeepTheRequestedDirectionAcrossALoopBoundary() {
        final state = newState(() -> new CarouselState(2).withLooping(true));
        update(state, (state, cx) -> {
            final viewport = b(0, 0, 100, 40);
            state.setGeometry(viewport, [b(0, 0, 80, 40), b(96, 0, 200, 40)]);
            state.setGeometry(viewport, [b(328, 0, 80, 40), b(424, 0, 200, 40)]);

            state.setSelectedIndex(1, cx);
            state.scrollHandleValue.setOffset(p(-424, 0));
            assertTrue(state.selectNext(cx));
            assertPoint(p(-640, 0), state.motionTargetFor(0));
            assertPoint(p(-328, 0), state.settleLoopMotion(p(-640, 0), cx));

            assertTrue(state.selectPrevious(cx));
            assertPoint(p(-112, 0), state.motionTargetFor(1));
        });
    }

    function testActiveLoopGestureRebasesBeforeReachingARunwayEdge() {
        final state = newState(() -> new CarouselState(2).withLooping(true));
        update(state, (state, cx) -> {
            final viewport = b(0, 0, 100, 40);
            state.setGeometry(viewport, [b(0, 0, 100, 40), b(100, 0, 100, 40)]);
            state.setGeometry(viewport, [b(200, 0, 100, 40), b(300, 0, 100, 40)]);

            assertTrue(state.beginDrag(p(0, 0), cx));
            state.scrollHandleValue.setOffset(p(-420, 0));
            assertTrue(state.normalizeLoopCoordinate());
            assertPoint(p(-220, 0), state.scrollHandleValue.offset());
            assertPoint(p(0, 0), state.pointerGesture.startOffset);

            assertEquals(1, state.nearestIndex(p(-110, 0)));
            assertEquals(0, state.nearestIndex(p(-390, 0)));
        });
    }

    function testLoopingFallsBackWhenOneCycleCannotCoverTheViewport() {
        final state = new CarouselState(2).withLooping(true);
        state.setGeometry(b(0, 0, 100, 40), [b(0, 0, 40, 40), b(40, 0, 40, 40)]);

        assertEquals(null, state.loopRunway());
        assertPoint(p(0, 0), state.loopItemOffset(0));
        assertFalse(state.hasPrevious());
        assertFalse(state.hasNext());

        state._selectedIndex = 1;
        assertFalse(state.hasPrevious());
        assertFalse(state.hasNext());
    }

    function testLoopRunwayAccountsForTheTrackGapAndContentInset() {
        final state = new CarouselState(2).withLooping(true);
        final viewport = b(0, 0, 100, 40);
        state.setGeometry(viewport, [b(16, 0, 100, 40), b(132, 0, 100, 40)]);

        assertEquals(232., state.loopRunway());
        state.setGeometry(viewport, [b(264, 0, 100, 40), b(380, 0, 100, 40)]);
        assertPoint(p(-248, 0), state.scrollHandleValue.offset());
        assertPoint(p(-248, 0), state.snapTargetFor(0));
        assertPoint(p(-364, 0), state.snapTargetFor(1));
    }

    function testLoopRunwayResizeAndRemovalPreserveTheVisibleCoordinate() {
        final state = newState(() -> new CarouselState(2).withLooping(true));
        update(state, (state, cx) -> {
            final viewport = b(0, 0, 100, 40);
            state.setGeometry(viewport, [b(0, 0, 100, 40), b(100, 0, 100, 40)]);
            state.setGeometry(viewport, [b(200, 0, 100, 40), b(300, 0, 100, 40)]);

            state.setGeometry(viewport, [b(200, 0, 150, 40), b(350, 0, 150, 40)]);
            assertEquals(300., state.loopRunway());
            assertTrue(state.isLoopLayoutTransitioning());
            assertPoint(p(0, 0), state.scrollHandleValue.offset());

            state.setGeometry(viewport, [b(300, 0, 150, 40), b(450, 0, 150, 40)]);
            assertFalse(state.isLoopLayoutTransitioning());
            assertPoint(p(-300, 0), state.scrollHandleValue.offset());

            state.setLooping(false, cx);
            assertEquals(null, state.loopRunway());
            assertTrue(state.isLoopLayoutTransitioning());
            assertPoint(p(0, 0), state.scrollHandleValue.offset());
            state.setGeometry(viewport, [b(0, 0, 150, 40), b(150, 0, 150, 40)]);
            assertFalse(state.isLoopLayoutTransitioning());
        });
    }

    function testLayingOutTheRunwayNormalizesAnActiveDragSnapshot() {
        final state = newState(() -> new CarouselState(2).withLooping(true));
        update(state, (state, cx) -> {
            final viewport = b(0, 0, 100, 40);
            state.setGeometry(viewport, [b(0, 0, 100, 40), b(100, 0, 100, 40)]);
            assertTrue(state.beginDrag(p(0, 0), cx));
            state.setGeometry(viewport, [b(200, 0, 100, 40), b(300, 0, 100, 40)]);

            assertPoint(p(-200, 0), state.scrollHandleValue.offset());
            assertPoint(p(-200, 0), state.pointerGesture.startOffset);
        });
    }

/// carousel.rs

    function testAxisHelpersOnlyChangeTheRequestedCoordinate() {
        var value = p(3, 7);
        value = Carousel.setAxisValue(value, Horizontal, 11);
        assertPoint(p(11, 7), value);
        value = Carousel.setAxisValue(value, Vertical, -5);
        assertPoint(p(11, -5), value);
    }

    function testCarouselControlsAcceptSemanticSizes() {
        final state = newState(() -> new CarouselState(2));
        assertEquals(glaze.kit.Size.Medium, new CarouselPrevious(state).size);
        assertEquals(glaze.kit.Size.Medium, new CarouselNext(state).size);
        assertEquals(glaze.kit.Size.Large, new CarouselPrevious(state).large().size);
        assertEquals(glaze.kit.Size.XSmall, new CarouselNext(state).xsmall().size);
        assertEquals(glaze.kit.Size.Small, new CarouselPaginationItem('pagination', 0, state).small().size);
    }

    function testCarouselFocusRingIsConfigurable() {
        final state = newState(() -> new CarouselState(2));
        assertTrue(new Carousel('carousel', state).isFocusRingEnabled());
        assertFalse(new Carousel('carousel', state).focusRing(false).isFocusRingEnabled());
    }

    function openHarness<V:Model & Render>(build:(Context<V>) -> V):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, cx:Context<V>) -> build(cx));
        contexts.push(opened.cx);
        draw(opened.cx);
        return opened.cx;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
        cx.runUntilParked();
    }

    function assertContextualNavigationKeys(axis:Axis) {
        final state = newState(() -> new CarouselState(3).withAxis(axis));
        final cx = openHarness(_ -> new KeyboardHarness(state));

        cx.update((window, cx) -> window.focusNext(cx));
        final primary = axis == Horizontal ? 'right' : 'down';
        final secondary = axis == Horizontal ? 'down' : 'right';
        cx.simulateKeystrokes(primary);
        assertEquals(1, state.read(app).selectedIndex());
        cx.simulateKeystrokes(secondary);
        assertEquals(1, state.read(app).selectedIndex());
        cx.simulateKeystrokes('end');
        assertEquals(2, state.read(app).selectedIndex());
        cx.simulateKeystrokes('home');
        assertEquals(0, state.read(app).selectedIndex());
    }

    function testHorizontalCarouselDispatchesContextualNavigationKeys() {
        assertContextualNavigationKeys(Horizontal);
    }

    function testVerticalCarouselDispatchesContextualNavigationKeys() {
        assertContextualNavigationKeys(Vertical);
    }

    function testUnhandledNavigationKeysReachAncestors() {
        final state = newState(() -> new CarouselState(3));
        final outerActions = [0];
        final cx = openHarness(_ -> new PropagationHarness(state, outerActions));
        cx.update((window, cx) -> window.focusNext(cx));

        cx.simulateKeystrokes('down');
        assertEquals(1, outerActions[0]);

        cx.simulateKeystrokes('left');
        assertEquals(2, outerActions[0]);
        assertEquals(0, state.read(app).selectedIndex());

        cx.simulateKeystrokes('right');
        assertEquals(1, state.read(app).selectedIndex());
        assertEquals(2, outerActions[0]);
    }

    function testTrackGrowsByItsLeadingMarginSoItemsFillTheFrame() {
        for (axis in [Horizontal, Vertical]) {
            final state = newState(() -> new CarouselState(3).withAxis(axis));
            final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new KeyboardHarness(state));
            contexts.push(opened.cx);
            draw(opened.cx);

            final s = state.read(app);
            final handle = s.scrollHandle();
            final track = handle.bounds();
            final firstItem = handle.boundsForItem(0);
            final frameSize = s.frameSize();
            assertEquals('100,100', frameSize.width + ',' + frameSize.height);
            final expected = axis == Horizontal ? b(-16, 0, 116, 100) : b(0, -16, 100, 116);
            assertTrue(track.equals(expected), 'track $track');
            assertTrue(firstItem.equals(expected), 'first item $firstItem');
        }
    }

    function testClickingASlideFocusesTheCarouselForKeyboardNavigation() {
        final state = newState(() -> new CarouselState(3));
        final cx = openHarness(_ -> new KeyboardHarness(state));
        assertTrue(cx.update((window, cx) -> window.focused(cx) == null));

        cx.simulateClick(p(50, 50));
        assertTrue(cx.update((window, cx) -> window.focused(cx) != null));

        cx.simulateKeystrokes('right');
        assertEquals(1, state.read(app).selectedIndex());
    }

    function testClickingAControlFocusesTheCarouselForKeyboardNavigation() {
        final state = newState(() -> new CarouselState(3));
        final cx = openHarness(_ -> new ControlsHarness(state));
        final selected = () -> state.read(app).selectedIndex();
        final rootFocused = () -> cx.update((window, cx) -> state.read(cx).focusHandle(cx).isFocused(window));

        // A pointer click on Next moves focus to the carousel.
        cx.simulateClick(p(134, 50));
        assertEquals(1, selected());
        assertTrue(rootFocused());
        cx.simulateKeystrokes('right');
        assertEquals(2, selected());

        // Keyboard activation of a control leaves focus on the control.
        cx.simulateKeystrokes('left');
        cx.update((window, cx) -> window.focusNext(cx));
        cx.update((window, cx) -> window.focusNext(cx));
        draw(cx);
        final keystroke = Keystroke.parse('enter');
        cx.simulateEvent(new KeyDownEvent(keystroke, false, false));
        cx.simulateEvent(new KeyUpEvent(keystroke));
        assertEquals(2, selected());
        assertFalse(rootFocused());
        assertTrue(cx.update((window, cx) -> window.focused(cx) != null));
    }

    function testCarouselControlsAcceptAccessibilityLabelsAndChildren() {
        final state = newState(() -> new CarouselState(2));
        final previous = new CarouselPrevious(state).accessibilityLabel('Previous project').child('Back');
        final next = new CarouselNext(state).accessibilityLabel('Next project').child('Forward');

        assertEquals('Previous project', previous.accessibilityLabelValue);
        assertEquals('Next project', next.accessibilityLabelValue);
        assertEquals(1, previous.childElements.length);
        assertEquals(1, next.childElements.length);
    }

/// scroll_mask.rs

    function testDraggingOverChildButtonSuppressesClickWithoutLeavingItPending() {
        final state = newState(() -> new CarouselState(2));
        final clicks = [0];
        final cx = openHarness(_ -> new ButtonDragHarness(state, clicks));

        cx.simulateClick(p(10, 10));
        assertEquals(1, clicks[0]);
        clicks[0] = 0;

        cx.simulateMouseDown(p(30, 10), Left);
        assertTrue(state.read(app).isInteracting());
        cx.simulateMouseMove(p(10, 10), Left);
        assertTrue(state.read(app).isPointerDragLocked());
        cx.simulateMouseUp(p(10, 10), Left);
        assertEquals(0, clicks[0]);

        draw(cx);
        cx.simulateClick(p(10, 10));
        assertEquals(1, clicks[0]);
    }

    function nestedVerticalCarousel(state:Entity<CarouselState>):{handle:ScrollHandle, cx:VisualTestContext} {
        final outerHandle = new ScrollHandle();
        final cx = openHarness(_ -> new NestedVerticalCarouselHarness(state, outerHandle));
        return {handle: outerHandle, cx: cx};
    }

    static function wheelLine(cx:VisualTestContext, lines:Float):Void {
        cx.simulateEvent(new ScrollEvent(p(20, 20), ScrollDelta.Lines(p(0, lines)), Modifiers.none(), Moved));
    }

    static function swipe(cx:VisualTestContext, delta:Float, touchPhase:TouchPhase):Void {
        cx.simulateEvent(new ScrollEvent(p(20, 20), ScrollDelta.Pixels(p(0, delta)), Modifiers.none(), touchPhase));
    }

    function testVerticalCarouselHandsScrollToParentAtEdge() {
        final state = newState(() -> new CarouselState(2).withAxis(Vertical).withSelectedIndex(1));
        final nested = nestedVerticalCarousel(state);

        wheelLine(nested.cx, -1);

        assertEquals(1, state.read(app).selectedIndex());
        assertTrue(nested.handle.offset().y < 0);
    }

    function testVerticalCarouselKeepsAWheelBurstAwayFromTheParent() {
        final state = newState(() -> new CarouselState(2).withAxis(Vertical));
        final nested = nestedVerticalCarousel(state);
        final cx = nested.cx;

        // One notch steps once; the rest of its burst stays here.
        wheelLine(cx, -1);
        wheelLine(cx, -1);
        assertEquals(1, state.read(app).selectedIndex());
        assertEquals(0., nested.handle.offset().y);

        // A new notch at the edge scrolls the surrounding document instead.
        advanceClock(CarouselState.SCROLL_EVENT_SEPARATION);
        runUntilParked();
        wheelLine(cx, -1);
        assertEquals(1, state.read(app).selectedIndex());
        assertTrue(nested.handle.offset().y < 0);
    }

    function testVerticalCarouselOwnsATrackpadGestureUntilItEnds() {
        final state = newState(() -> new CarouselState(2).withAxis(Vertical));
        final nested = nestedVerticalCarousel(state);
        final cx = nested.cx;

        // The swipe overshoots the last item; the leftover stays here.
        swipe(cx, -50, Started);
        swipe(cx, -50, Moved);
        swipe(cx, -50, Moved);
        swipe(cx, 0, Ended);
        assertEquals(0., nested.handle.offset().y);
        assertEquals(1, state.read(app).selectedIndex());

        // A gesture that begins at the edge scrolls the document instead.
        swipe(cx, -50, Started);
        assertTrue(nested.handle.offset().y < 0);
    }

}

private class KeyboardHarness extends Model implements Render {

    final state:Entity<CarouselState>;

    public function new(state:Entity<CarouselState>) {
        super();
        this.state = state;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div().tabGroup().child(new Carousel('carousel', state)
            .w(px(100.))
            .h(px(100.))
            .child(new CarouselContent(state)
                .h(px(100.))
                .children([for (index in 0...3) new CarouselItem(ElementId.NamedInteger('carousel-item', index), index, state).child(Std.string(index))])));
    }

}

private class PropagationHarness extends Model implements Render {

    final state:Entity<CarouselState>;

    final outerActions:Array<Int>;

    public function new(state:Entity<CarouselState>, outerActions:Array<Int>) {
        super();
        this.state = state;
        this.outerActions = outerActions;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        final outerActions = this.outerActions;
        return div()
            .tabGroup()
            .onAction(SelectDown, (_, _, _) -> outerActions[0]++)
            .onAction(SelectLeft, (_, _, _) -> outerActions[0]++)
            .onAction(SelectRight, (_, _, _) -> outerActions[0]++)
            .child(new Carousel('carousel', state)
                .w(px(100.))
                .h(px(100.))
                .child(new CarouselContent(state)
                    .h(px(100.))
                    .children([for (index in 0...3) new CarouselItem(ElementId.NamedInteger('carousel-item', index), index, state).child(Std.string(index))])));
    }

}

private class ControlsHarness extends Model implements Render {

    final state:Entity<CarouselState>;

    public function new(state:Entity<CarouselState>) {
        super();
        this.state = state;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div().tabGroup().child(new Carousel('carousel', state)
            .w(px(100.))
            .h(px(100.))
            .child(new CarouselContent(state)
                .h(px(100.))
                .children([for (index in 0...3) new CarouselItem(ElementId.NamedInteger('carousel-item', index), index, state).child(Std.string(index))]))
            .child(new CarouselPrevious(state))
            .child(new CarouselNext(state)));
    }

}

private class ButtonDragHarness extends Model implements Render {

    final state:Entity<CarouselState>;

    final clicks:Array<Int>;

    public function new(state:Entity<CarouselState>, clicks:Array<Int>) {
        super();
        this.state = state;
        this.clicks = clicks;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        final clicks = this.clicks;
        return new Carousel('button-drag-carousel', state)
            .w(px(100.))
            .h(px(40.))
            .child(new CarouselContent(state)
                .h(px(40.))
                .child(new CarouselItem('button-slide', 0, state)
                    .h(px(40.))
                    .child(new Button('slide-button')
                        .wFull()
                        .h(px(40.))
                        .onClick((_, _, _) -> clicks[0]++)))
                .child(new CarouselItem('plain-slide', 1, state)
                    .h(px(40.))
                    .child('Second')));
    }

}

private class NestedVerticalCarouselHarness extends Model implements Render {

    final state:Entity<CarouselState>;

    final outerHandle:ScrollHandle;

    public function new(state:Entity<CarouselState>, outerHandle:ScrollHandle) {
        super();
        this.state = state;
        this.outerHandle = outerHandle;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div()
            .id('outer-scroll')
            .w(px(100.))
            .h(px(100.))
            .overflowYScroll()
            .trackScroll(outerHandle)
            .child(new Carousel('vertical-carousel', state)
                .w(px(100.))
                .h(px(60.))
                .child(new CarouselContent(state)
                    .hFull()
                    .children([for (index in 0...2) new CarouselItem(ElementId.NamedInteger('vertical-slide', index), index, state).child(Std.string(index))])))
            .child(div().wFull().h(px(400.)));
    }

}

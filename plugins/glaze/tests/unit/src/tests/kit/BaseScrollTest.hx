// Ported from gpui-kit 0.8.1: crates/base/src/overscroll.rs, scroll_bounce.rs,
// scrollable_mask.rs, auto_scroll.rs and virtual_list.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.ListAlignment;
import gpui.ListOffset;
import gpui.ListState;
import gpui.Model;
import gpui.Point;
import gpui.Render;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.ScrollHandle;
import gpui.ScrollStrategy;
import gpui.Size;
import gpui.StyleRefinement;
import gpui.TestDispatcher;
import gpui.TouchPhase;
import gpui.Window;
import gpui.base.AutoScroll;
import gpui.base.Overscroll;
import gpui.base.ScrollBounce;
import gpui.base.ScrollableMask;
import gpui.base.Scrollbar.ListStateScrollbar;
import gpui.base.VirtualList;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The tests of gpui-base's scrolling modules: `overscroll.rs`,
 * `scroll_bounce.rs`, `scrollable_mask.rs`, `auto_scroll.rs` and
 * `virtual_list.rs`. Instants are `Float` seconds.
 */
class BaseScrollTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        newApp();
    }

    function newApp():Void {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        @:privateAccess ScrollableMask.lastHorizontalScrollClaimValue = null;
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        return opened.cx;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    /// overscroll.rs

    /** Text that can scroll `room` further toward its end. */
    static function text(room:Array<Float>):(Float) -> Float {
        return dy -> {
            final used = Math.max(dy, -room[0]);
            room[0] += used;
            return used;
        };
    }

    function testASwipePastTheEndStretchesAndSpringsBack() {
        final now = 10.;
        final overscroll = new Overscroll();
        final room = [30.];
        overscroll.packet(-10., Started, 400., now, text(room));
        overscroll.packet(-100., Moved, 400., now, text(room));
        // The text used the 30px it had left; the rest stretches the edge.
        assertEquals(0., room[0]);
        final stretched = overscroll.offset();
        assertTrue(stretched < 0. && stretched > -80., '$stretched');

        overscroll.packet(0., Ended, 400., now, text(room));
        // Momentum after the release is answered by the spring alone.
        assertFalse(overscroll.packet(-40., Moved, 400., now, text(room)));
        var later = now;
        while (overscroll.step(later)) {
            later += 0.016;
        }
        assertEquals(0., overscroll.offset());
    }

    function testPullingBackUnstretchesBeforeScrollingTheText() {
        final now = 10.;
        final overscroll = new Overscroll();
        final room = [0.];
        overscroll.packet(0., Started, 400., now, text(room));
        overscroll.packet(-50., Moved, 400., now, text(room));
        assertTrue(overscroll.offset() < 0.);
        // Back the other way: the first 50px return the edge, the next 20px
        // scroll the text back from its end.
        var scrolled = 0.;
        overscroll.packet(70., Moved, 400., now, dy -> {
            scrolled += dy;
            return dy;
        });
        assertEquals(0., overscroll.offset());
        assertEquals(20., scrolled);
    }

    /**
     * A momentum stream of `speed` px/s decaying as AppKit's does, through
     * `room` px of text first, with every packet from frame `stall` to the
     * impact handed over in one go. Returns the edge's offset at each frame.
     */
    static function flingThrough(speed:Float, room:Float, stall:Int):Array<Float> {
        final start = 10.;
        final frame = 0.016667;
        final overscroll = new Overscroll();
        var dy = gpui.SpringMath.f32(-speed / 60.);
        final held:Array<Float> = [];
        final path:Array<Float> = [];
        final roomRef = [room];
        for (n in 0...120) {
            final at = start + frame * n;
            // Momentum keeps arriving well after the edge has settled.
            if (n < 100) {
                held.push(dy);
                dy = gpui.SpringMath.f32(dy * 0.95);
                var sum = 0.;
                for (d in held) sum += d;
                if (stall == 0 || n < stall || roomRef[0] == 0. || -sum > roomRef[0]) {
                    for (d in held) {
                        overscroll.packet(d, Moved, 300., at, text(roomRef));
                    }
                    held.resize(0);
                }
            }
            overscroll.step(at);
            path.push(overscroll.offset());
        }
        return path;
    }

    static function fling(speed:Float):Array<Float> {
        return flingThrough(speed, 0., 0);
    }

    static function minOf(path:Array<Float>):Float {
        var result = 0.;
        for (v in path) if (v < result) result = v;
        return result;
    }

    function testAFlingThrowsTheEdgeAsFarAsNsscrollviewDoes() {
        // Measured on NSScrollView: a fling arriving at 1500 px/s peaks about
        // 14 px out, roughly 80 ms after impact, and settles within 0.65 s.
        final path = fling(1500.);
        final peak = minOf(path);
        assertTrue(peak >= -16. && peak <= -12., 'peak $peak');
        final turned = path.indexOf(peak);
        assertTrue(turned >= 4 && turned <= 6, 'turned at frame $turned');
        assertEquals(0., path[50], 'the edge settles');
        // The momentum still arriving after impact never throws it again.
        for (i in turned...path.length - 1) assertTrue(path[i + 1] >= path[i]);
        for (i in 50...path.length) assertEquals(0., path[i]);
        // Twice the speed throws it about twice as far.
        final faster = minOf(fling(3000.));
        assertTrue(Math.abs(faster / peak - 2.) < 0.15, '$faster vs $peak');
        // But no fling throws it past the limit, as none does in Finder.
        final hardest = minOf(fling(20000.));
        assertTrue(hardest >= -36. && hardest <= -34., '$hardest');
    }

    function testPacketsHandedOverAtOnceDoNotThrowTheEdgeFurther() {
        final even = minOf(flingThrough(4000., 500., 0));
        final stalled = minOf(flingThrough(4000., 500., 3));
        assertTrue(even < -10., '$even');
        // Read per packet, the burst threw it out to the limit. Read over
        // the span, only the longer span's slower decay shows.
        assertTrue(Math.abs(stalled / even - 1.) < 0.25, '$stalled vs $even');
    }

    function testATouchThatLiftsWithoutMovingLetsGoOfTheEdge() {
        final start = 10.;
        final overscroll = new Overscroll();
        final room = [0.];
        overscroll.packet(-80., Moved, 400., start, text(room));
        final later = start + 0.03;
        overscroll.step(later);
        final held = overscroll.offset();
        // Touch, then lift: GPUI reports `MayBegin` as `Started` and the
        // cancel as a `Moved` of nothing.
        overscroll.packet(0., Started, 400., later, text(room));
        assertTrue(overscroll.packet(0., Moved, 400., later, text(room)));
        var at = later;
        while (overscroll.step(at)) {
            at += 0.016;
        }
        assertTrue(held < 0.);
        assertEquals(0., overscroll.offset());
    }

    function testAStretchFollowsTheTravelAsNsscrollviewDoes() {
        // Measured on a 300 px NSScrollView: 100 px of travel past the end
        // stretches it 7 px. Further on, AppKit reads unaccelerated travel
        // and Finder never goes past 36 px; the stretch eases into that.
        function stretch(travel:Float):Float {
            final start = 10.;
            final overscroll = new Overscroll();
            final room = [0.];
            overscroll.packet(0., Started, 300., start, text(room));
            overscroll.packet(-travel, Moved, 300., start, text(room));
            return -overscroll.offset();
        }
        assertTrue(stretch(100.) >= 6.5 && stretch(100.) <= 8., '${stretch(100.)}');
        assertTrue(stretch(764.) >= 28. && stretch(764.) <= 34., '${stretch(764.)}');
        assertTrue(stretch(2400.) >= 35. && stretch(2400.) < 36., '${stretch(2400.)}');
        assertTrue(stretch(100000.) < 36.);
    }

    function testAStillReleaseReturnsAtFullSpeed() {
        // NSScrollView lets go of a stretch held still and halves it in
        // 55 ms, starting at once rather than easing out.
        final start = 10.;
        final overscroll = new Overscroll();
        final room = [0.];
        overscroll.packet(0., Started, 300., start, text(room));
        overscroll.packet(-800., Moved, 300., start, text(room));
        final held = overscroll.offset();
        final lifted = start + 0.2;
        overscroll.packet(0., Ended, 300., lifted, text(room));
        overscroll.step(lifted + 0.008);
        assertTrue(overscroll.offset() / held < 0.92, 'starts at once');
        overscroll.step(lifted + 0.055);
        final half = overscroll.offset() / held;
        assertTrue(half >= 0.45 && half <= 0.55, '$half');
    }

    /** Text `end` px long whose offset is an `f32`, as a scroll handle's is. */
    static function longText(offset:Array<Float>, end:Float):(Float) -> Float {
        return dy -> {
            final before = offset[0];
            var next = gpui.SpringMath.f32(before + dy);
            next = next < -end ? -end : (next > 0. ? 0. : next);
            offset[0] = next;
            return gpui.SpringMath.f32(next - before);
        };
    }

    function testADragBackOffAFarEdgeKeepsScrollingTheText() {
        final start = 10.;
        final end = 8902.5;
        for (returnedMs in 1...60) {
            final overscroll = new Overscroll();
            final offset = [-end];
            overscroll.packet(0., Started, 600., start, longText(offset, end));
            overscroll.packet(-200., Moved, 600., start, longText(offset, end));
            final lifted = start + 0.1;
            overscroll.packet(0., Ended, 600., lifted, longText(offset, end));
            // Caught on its way back, then dragged past the edge into the text.
            final caught = lifted + returnedMs / 1000.;
            overscroll.step(caught);
            overscroll.packet(0., Started, 600., caught, longText(offset, end));
            overscroll.packet(300., Moved, 600., caught, longText(offset, end));
            final before = offset[0];
            overscroll.packet(122., Moved, 600., caught, longText(offset, end));
            assertEquals(0., overscroll.offset(), 'the edge stays put ($returnedMs ms)');
            assertTrue(Math.abs(offset[0] - before - 122.) < 0.01, 'the drag scrolls the text');
        }
    }

    function testAFlickAwayFromTheEdgesLeavesTheNextDragToTheText() {
        final start = 10.;
        final frame = 0.016;
        final overscroll = new Overscroll();
        final room = [10000.];
        overscroll.packet(0., Started, 400., start, text(room));
        for (n in 1...7) {
            overscroll.packet(-70., Moved, 400., start + frame * n, text(room));
        }
        final lifted = start + frame * 7;
        overscroll.packet(0., Ended, 400., lifted, text(room));
        overscroll.step(lifted + frame);
        assertEquals(0., overscroll.offset(), 'no edge to throw');
        // Fingers back down at once, dragging on the same way.
        final before = room[0];
        final again = lifted + frame * 2;
        overscroll.packet(0., Started, 400., again, text(room));
        overscroll.packet(-50., Moved, 400., again + frame, text(room));
        assertEquals(50., before - room[0], 'the drag scrolls the text');
        assertEquals(0., overscroll.offset());
    }

    function testAfterAPauseTheNextFlickThrowsTheEdgeAgain() {
        final start = 10.;
        final overscroll = new Overscroll();
        final room = [0.];
        assertTrue(overscroll.packet(-40., Moved, 400., start, text(room)));
        var at = start;
        while (overscroll.step(at)) {
            at += 0.016;
        }
        final later = at + Overscroll.GESTURE_GAP;
        assertTrue(overscroll.packet(-40., Moved, 400., later, text(room)));
    }

    function testMomentumBackIntoTheTextScrollsWhileTheEdgeReturns() {
        final start = 10.;
        final overscroll = new Overscroll();
        final room = [0.];
        overscroll.packet(0., Started, 400., start, text(room));
        overscroll.packet(-800., Moved, 400., start, text(room));
        final lifted = start + 0.1;
        overscroll.packet(0., Ended, 400., lifted, text(room));
        final later = lifted + 0.016;
        overscroll.step(later);
        final before = overscroll.offset();
        assertTrue(before < 0.);
        overscroll.packet(20., Moved, 400., later, text(room));
        assertEquals(20., room[0]);
        assertEquals(before, overscroll.offset(), 'the edge does not jump');
        overscroll.step(later + 0.016);
        assertTrue(overscroll.offset() > before && overscroll.offset() < 0.);
    }

    function testANewPreciseGestureTakesOverWithoutJumping() {
        final start = 10.;
        final overscroll = new Overscroll();
        final room = [0.];
        overscroll.packet(-80., Moved, 400., start, text(room));
        overscroll.step(start + 0.016);
        final later = start + 0.2;
        overscroll.step(later);
        assertTrue(overscroll.offset() < 0.);
        final before = overscroll.offset();
        overscroll.packet(0., Started, 400., later, text(room));
        assertTrue(Math.abs(overscroll.offset() - before) < 0.001, 'interruption does not jump');
        assertTrue(overscroll.packet(-40., Moved, 400., later, text(room)));
        overscroll.step(later + 0.016);
        assertTrue(overscroll.offset() < before, 'the new input pushes outward again');
    }

    /// scroll_bounce.rs

    function scrollTest(handle:ScrollHandle, enabled:Bool):VisualTestContext {
        final cx = open((_, _) -> div().p(px(20.)).child(
            new ScrollBounce('bounce', handle, div()
                .id('viewport')
                .w(px(200.))
                .h(px(200.))
                .overflowYScroll()
                .trackScroll(handle)
                .child(div().h(px(600.)).wFull()))
                .enabled(enabled)
                .scrollWheel(false)));
        draw(cx);
        return cx;
    }

    static function scroll(cx:VisualTestContext, delta:Float, phase:TouchPhase):Void {
        cx.simulateEvent(new ScrollEvent(new Point(100., 100.), Pixels(new Point(0., delta)), null, phase));
    }

    function wheelViewport(handle:ScrollHandle, height:Float):VisualTestContext {
        final cx = open((_, _) -> new ScrollBounce('wheel-bounce', handle, div()
            .id('wheel-viewport')
            .w(px(200.))
            .h(px(200.))
            .overflowYScroll()
            .trackScroll(handle)
            .child(div().h(px(height)).wFull()))
            .enabled(true)
            .scrollWheel(true));
        draw(cx);
        return cx;
    }

    function testFractionalWheelInputKeepsScrollingDeepInALongList() {
        for (delta in [-0.09, 0.09]) {
            newApp();
            final handle = new ScrollHandle();
            final cx = wheelViewport(handle, 2000000.);
            handle.setOffset(new Point(0., -1000000.));
            draw(cx);
            final origin = handle.bounds().origin;
            scroll(cx, delta, Started);
            scroll(cx, MathSign.of(delta) * 20., Moved);
            scroll(cx, 0., Ended);
            cx.advanceClock(0.016);
            draw(cx);
            scroll(cx, delta, Moved);
            scroll(cx, 0., Started);
            scroll(cx, MathSign.of(delta) * 20., Moved);
            draw(cx);
            // Here each 0.09px delta rounds to 0.0625px in the stored offset.
            final expected = -1000000. + MathSign.of(delta) * 40.125;
            assertTrue(Math.abs(handle.offset().y - expected) < 0.001, '${handle.offset().y}');
            assertTrue(handle.bounds().origin.equals(origin));
        }
    }

    function testOrdinaryMouseWheelKeepsTheSharedViewportUndisplaced() {
        final handle = new ScrollHandle();
        final cx = wheelViewport(handle, 600.);
        final origin = handle.bounds().origin;
        cx.simulateEvent(new ScrollEvent(new Point(100., 100.), Lines(new Point(0., -100.))));
        draw(cx);
        cx.advanceClock(0.016);
        draw(cx);
        assertEquals(-handle.maxOffset().y, handle.offset().y);
        assertTrue(handle.bounds().origin.equals(origin));
    }

    function testWheelScrollingInterruptsTheSharedReturn() {
        final handle = new ScrollHandle();
        final cx = wheelViewport(handle, 600.);
        scroll(cx, -1000., Started);
        scroll(cx, 0., Ended);
        draw(cx);
        assertEquals(-handle.maxOffset().y, handle.offset().y);
        cx.advanceClock(0.2);
        draw(cx);
        final end = handle.offset().y;
        cx.simulateEvent(new ScrollEvent(new Point(100., 100.), Lines(new Point(0., 2.))));
        assertTrue(handle.offset().y > end, 'the new wheel input scrolls before the next frame');
        draw(cx);
    }

    /** A scroll area with a shorter one inside it, 100 px down. */
    function nested(innerEnabled:Bool):{outer:ScrollHandle, inner:ScrollHandle, cx:VisualTestContext} {
        final outer = new ScrollHandle();
        final inner = new ScrollHandle();
        final cx = open((_, _) -> new ScrollBounce('outer', outer, div()
            .id('outer-viewport')
            .w(px(200.))
            .h(px(300.))
            .overflowYScroll()
            .trackScroll(outer)
            .child(div().h(px(100.)).wFull())
            .child(new ScrollBounce('inner', inner, div()
                .id('inner-viewport')
                .w(px(200.))
                .h(px(100.))
                .overflowYScroll()
                .trackScroll(inner)
                .child(div().h(px(400.)).wFull()))
                .enabled(innerEnabled))
            .child(div().h(px(600.)).wFull()))
            .enabled(true));
        draw(cx);
        return {outer: outer, inner: inner, cx: cx};
    }

    static function scrollAt(cx:VisualTestContext, y:Float, delta:Float, phase:TouchPhase):Void {
        cx.simulateEvent(new ScrollEvent(new Point(100., y), Pixels(new Point(0., delta)), null, phase));
        draw(cx);
    }

    function testTheInnermostAreaTakesTheWholeGesture() {
        final areas = nested(true);
        final cx = areas.cx;
        final innerOrigin = areas.inner.bounds().origin.y;
        scrollAt(cx, 150., 0., Started);
        scrollAt(cx, 150., -200., Moved);
        assertEquals(-200., areas.inner.offset().y, 'the inner area scrolls');
        assertEquals(0., areas.outer.offset().y, 'the outer one does not');
        // At its end the inner area stretches instead of handing over.
        scrollAt(cx, 150., -200., Moved);
        assertEquals(-300., areas.inner.offset().y);
        assertEquals(0., areas.outer.offset().y);
        assertTrue(areas.inner.bounds().origin.y < innerOrigin);
        // Outside the inner area, the outer one scrolls.
        scrollAt(cx, 150., 0., Ended);
        scrollAt(cx, 20., -50., Moved);
        assertEquals(-50., areas.outer.offset().y);
    }

    function testADisabledInnerAreaStillKeepsItsScroll() {
        final areas = nested(false);
        final cx = areas.cx;
        final innerOrigin = areas.inner.bounds().origin.y;
        scrollAt(cx, 150., -50., Moved);
        assertEquals(-50., areas.inner.offset().y, 'the inner area scrolls');
        assertEquals(0., areas.outer.offset().y, 'the outer one does not');
        // At its end it stops without stretching.
        scrollAt(cx, 150., -500., Moved);
        assertEquals(-300., areas.inner.offset().y);
        assertEquals(innerOrigin, areas.inner.bounds().origin.y);
        assertEquals(0., areas.outer.offset().y);
    }

    function listTest(state:ListState):VisualTestContext {
        final cx = open((_, _) -> new ScrollBounce('bounce-list', state, list(state, (_, _, _) -> div().h(px(40.))).w(px(200.)).h(px(200.)))
            .enabled(true)
            .scrollWheel(false));
        draw(cx);
        return cx;
    }

    static function listHandle(state:ListState):ListStateScrollbar {
        return new ListStateScrollbar(state);
    }

    function testListReverseDragPreservesEventsBeforeTheNextFrame() {
        final state = new ListState(30, Top, 0.).measureAll();
        final cx = listTest(state);
        final handle = listHandle(state);
        scroll(cx, 100., Started);
        scroll(cx, -140., Moved);
        assertEquals(-40., handle.offset().y);
        scroll(cx, -10., Moved);
        draw(cx);
        assertEquals(-50., handle.offset().y);
    }

    function dispatchScrolls(cx:VisualTestContext, packets:Array<{delta:Point, phase:TouchPhase}>):Void {
        cx.update((window, app) -> {
            for (packet in packets) {
                window.dispatchEvent(new ScrollEvent(new Point(100., 100.), Pixels(packet.delta), null, packet.phase), app);
            }
            return null;
        });
    }

    function testTrackpadReleaseBetweenFramesDoesNotBounceInTheMiddle() {
        final state = new ListState(30, Top, 0.).measureAll();
        final cx = listTest(state);
        final handle = listHandle(state);
        handle.setOffset(new Point(0., -400.));
        draw(cx);
        final origin = handle.viewportBounds().origin.y;
        dispatchScrolls(cx, [{delta: new Point(0., -30.), phase: Started}, {delta: new Point(0., 0.), phase: Ended}]);
        draw(cx);
        assertEquals(origin, handle.viewportBounds().origin.y);
        assertTrue(handle.offset().y < -300. && handle.offset().y > -500.);
    }

    function testTrackpadDirectionChangeBetweenFramesDoesNotBounceInTheMiddle() {
        final state = new ListState(30, Top, 0.).measureAll();
        final cx = listTest(state);
        final handle = listHandle(state);
        handle.setOffset(new Point(0., -400.));
        draw(cx);
        final origin = handle.viewportBounds().origin.y;
        dispatchScrolls(cx, [{delta: new Point(0., -30.), phase: Started}, {delta: new Point(0., 5.), phase: Moved}]);
        draw(cx);
        assertTrue(handle.offset().y < -300. && handle.offset().y > -500.);
        assertEquals(origin, handle.viewportBounds().origin.y);
    }

    function testListStretchesOnlyTheDistancePastEitherEdge() {
        for (c in [{start: -30., delta: 50., end: 0.}, {start: -970., delta: -50., end: -1000.}]) {
            newApp();
            final state = new ListState(30, Top, 0.).measureAll();
            final cx = listTest(state);
            final handle = listHandle(state);
            handle.setOffset(new Point(0., c.start));
            draw(cx);
            final origin = handle.viewportBounds().origin.y;
            scroll(cx, c.delta, Started);
            draw(cx);
            assertEquals(c.end, handle.offset().y);
            final stretch = handle.viewportBounds().origin.y - origin;
            assertEquals(MathSign.of(c.delta), MathSign.of(stretch));
            // Of the 50 px input, 30 px is ordinary scrolling. Only the
            // remaining 20 px may be rubber-banded (resistance reduces it).
            assertTrue(Math.abs(stretch) > 0. && Math.abs(stretch) < 20.);
        }
    }

    function testReverseDragConsumesStretchBeforeScrollingContent() {
        final handle = new ScrollHandle();
        final cx = scrollTest(handle, true);
        final origin = handle.bounds().origin.y;
        assertEquals(20., origin);
        scroll(cx, 100., Started);
        draw(cx);
        assertEquals(0., handle.offset().y);
        assertTrue(handle.bounds().origin.y > origin);
        scroll(cx, -140., Moved);
        draw(cx);
        assertEquals(-40., handle.offset().y);
        assertEquals(origin, handle.bounds().origin.y);
    }

    function testTouchReleaseIgnoresMomentumUntilANewTouchTakesOver() {
        final handle = new ScrollHandle();
        final cx = scrollTest(handle, true);
        final origin = handle.bounds().origin.y;
        scroll(cx, 100., Started);
        draw(cx);
        assertTrue(handle.bounds().origin.y > origin);
        scroll(cx, 0., Ended);
        draw(cx);
        final released = handle.bounds().origin.y;
        // Momentum packets after finger-up must not move the logical list
        // while the returning edge owns this gesture.
        scroll(cx, -400., Moved);
        draw(cx);
        assertEquals(0., handle.offset().y);
        assertTrue(handle.bounds().origin.y <= released);
        // A new finger-down must end suppression and take over immediately.
        scroll(cx, 0., Started);
        scroll(cx, -250., Moved);
        draw(cx);
        assertTrue(handle.offset().y < 0.);
        assertEquals(origin, handle.bounds().origin.y);
    }

    function testPhaselessWheelScrollsBackRightAfterBouncing() {
        final state = new ListState(30, Top, 0.).measureAll();
        final cx = listTest(state);
        final handle = listHandle(state);
        handle.setOffset(new Point(0., -1000.));
        draw(cx);
        final origin = handle.viewportBounds().origin.y;
        // Smooth-scrolling mouse drivers on macOS: precise deltas, no phase.
        scroll(cx, -50., Moved);
        draw(cx);
        assertTrue(handle.viewportBounds().origin.y < origin);
        scroll(cx, 200., Moved);
        draw(cx);
        assertTrue(handle.offset().y > -1000.);
        assertEquals(origin, handle.viewportBounds().origin.y);
    }

    function testPhaselessWheelBouncesAgainOnlyAfterAPause() {
        final handle = new ScrollHandle();
        final cx = scrollTest(handle, true);
        scroll(cx, 50., Moved);
        draw(cx);
        final bounced = handle.bounds().origin.y;
        // Momentum after an edge hit keeps pushing outward; it must not
        // stretch further.
        scroll(cx, 50., Moved);
        draw(cx);
        assertTrue(handle.bounds().origin.y <= bounced);
        cx.advanceClock(ScrollBounce.MOMENTUM_GAP);
        scroll(cx, 50., Moved);
        draw(cx);
        assertTrue(handle.bounds().origin.y > bounced);
        assertEquals(0., handle.offset().y);
    }

    function testTinyDragCatchingMomentumDoesNotStartAReverseFling() {
        final handle = new ScrollHandle();
        final cx = scrollTest(handle, true);
        handle.setOffset(new Point(0., -200.));
        draw(cx);

        // GPUI ends the old momentum stream, then starts a drag at zero
        // displacement when a finger catches the moving content.
        scroll(cx, -60., Started);
        scroll(cx, 0., Ended);
        draw(cx);
        scroll(cx, -100., Moved);
        draw(cx);
        scroll(cx, 0., Ended);
        draw(cx);
        final beforeCatch = handle.offset().y;
        assertTrue(beforeCatch < 0.);
        scroll(cx, 0., Started);
        scroll(cx, 8., Moved);
        scroll(cx, 0., Ended);
        draw(cx);
        final stopped = handle.offset().y;
        assertEquals(beforeCatch + 8., stopped);

        // The recognizer can synthesize a large reverse momentum packet from
        // that 8 px movement. It must not move the logical viewport.
        scroll(cx, 100., Moved);
        draw(cx);
        assertEquals(stopped, handle.offset().y);

        // A fresh gesture restores ordinary scrolling and momentum.
        scroll(cx, -20., Started);
        scroll(cx, 0., Ended);
        scroll(cx, -10., Moved);
        draw(cx);
        assertEquals(stopped - 30., handle.offset().y);
    }

    function testDeliberateDragAfterCatchingMomentumCanFling() {
        final handle = new ScrollHandle();
        final cx = scrollTest(handle, true);
        handle.setOffset(new Point(0., -200.));
        draw(cx);

        scroll(cx, 0., Started);
        scroll(cx, 24., Moved);
        scroll(cx, 0., Ended);
        draw(cx);
        assertEquals(-176., handle.offset().y);
        scroll(cx, 40., Moved);
        draw(cx);
        assertEquals(-136., handle.offset().y);
    }

    function testShortCatchReleaseStillStretchesPastTheEdge() {
        final handle = new ScrollHandle();
        final cx = scrollTest(handle, true);
        handle.setOffset(new Point(0., -4.));
        draw(cx);
        final origin = handle.bounds().origin.y;

        scroll(cx, 0., Started);
        scroll(cx, 8., Ended);
        draw(cx);
        assertEquals(0., handle.offset().y);
        assertTrue(handle.bounds().origin.y > origin);
    }

    function testDisabledAndReducedMotionLeaveTheViewportFixed() {
        for (enabled in [false, true]) {
            newApp();
            if (enabled) {
                app.update(cx -> cx.setReduceMotion(true));
            }
            final handle = new ScrollHandle();
            final cx = scrollTest(handle, enabled);
            final origin = handle.bounds().origin.y;
            scroll(cx, 100., Started);
            draw(cx);
            assertEquals(origin, handle.bounds().origin.y);
            scroll(cx, -40., Moved);
            draw(cx);
            assertEquals(-40., handle.offset().y);
        }
    }

    function testResistanceAndReversePreserveUnconsumedDistance() {
        final scroll = new gpui.base.ScrollBounce.Physics();
        scroll.begin(600.);
        assertEquals(0., scroll.pull(100.));
        assertTrue(scroll.offset() > 0. && scroll.offset() < 55.);
        assertEquals(-30., scroll.pull(-130.));
        assertEquals(0., scroll.offset());
    }

    function testDiagonalWobbleStaysWithTheStretch() {
        final handle = new ScrollHandle();
        final cx = scrollTest(handle, true);
        final origin = handle.bounds().origin.y;
        scroll(cx, 100., Started);
        draw(cx);
        final stretched = handle.bounds().origin.y;
        assertTrue(stretched > origin);
        // A trackpad swipe that started vertical wobbles horizontal-dominant
        // for a packet. Dispatch within one update so the packets stay within
        // the axis lock's gesture separation.
        dispatchScrolls(cx, [{delta: new Point(30., -20.), phase: Moved}, {delta: new Point(0., -20.), phase: Moved}]);
        draw(cx);
        // Both packets shrink the stretch; neither scrolls the list.
        assertTrue(handle.bounds().origin.y < stretched);
        assertTrue(handle.bounds().origin.y > origin);
        assertTrue(handle.offset().equals(new Point(0., 0.)));
    }

    function testMotionBuilderConfiguresTrackingAndResponse() {
        final motion = new gpui.base.ScrollBounce.ScrollBounceMotion().withTracking(0.4).withResponse(0.3).withMaxStretch(24.);
        assertEquals(0.4, motion.tracking());
        assertEquals(0.3, motion.response());
        assertEquals(24., motion.maxStretch());
    }

    function testTrackingScalesTheFirstStretch() {
        function stretch(tracking:Float):Float {
            final scroll = new gpui.base.ScrollBounce.Physics();
            scroll.setMotion(new gpui.base.ScrollBounce.ScrollBounceMotion().withTracking(tracking));
            scroll.begin(600.);
            scroll.pull(100.);
            return scroll.offset();
        }
        assertTrue(stretch(0.3) < stretch(0.55));
        assertTrue(stretch(0.55) < stretch(0.8));
    }

    function testResponseScalesTheReturnAndZeroSnaps() {
        function remaining(response:Float):Float {
            final scroll = new gpui.base.ScrollBounce.Physics();
            scroll.setMotion(new gpui.base.ScrollBounce.ScrollBounceMotion().withResponse(response));
            scroll.begin(600.);
            scroll.pull(180.);
            scroll.release();
            scroll.step(0.25);
            return scroll.offset();
        }
        assertTrue(remaining(1.) > remaining(0.524));
        assertTrue(remaining(0.524) > remaining(0.2));
        assertEquals(0., remaining(0.));
    }

    function testRegrabbingADisplacedEdgeKeepsItsExtent() {
        final scroll = new gpui.base.ScrollBounce.Physics();
        scroll.begin(600.);
        scroll.pull(-150.);
        scroll.release();
        scroll.step(0.08);
        final before = scroll.offset();
        // The viewport shrank below the displacement while the edge was
        // returning. The finger still lands on the edge where it is.
        scroll.begin(40.);
        assertTrue(Math.abs(scroll.offset() - before) < 0.001);
        // And a short pull inward moves the edge right away.
        scroll.pull(10.);
        assertTrue(scroll.offset() > before);
        assertTrue(scroll.offset() < before + 10.);
    }

    function testAGestureFromRestAdoptsTheCurrentExtent() {
        final scroll = new gpui.base.ScrollBounce.Physics();
        scroll.begin(600.);
        scroll.begin(40.);
        scroll.pull(-100.);
        // The stretch saturates below the 40 px viewport, not the 600 px one.
        assertTrue(scroll.offset() > -40.);
    }

    function testGrabbingTheSpringDoesNotJump() {
        final scroll = new gpui.base.ScrollBounce.Physics();
        scroll.begin(600.);
        scroll.pull(-150.);
        scroll.release();
        scroll.step(0.08);
        final before = scroll.offset();
        scroll.begin(600.);
        assertTrue(Math.abs(scroll.offset() - before) < 0.001);
        final held = scroll.offset();
        assertFalse(scroll.step(0.1));
        assertEquals(held, scroll.offset());
    }

    function testSpringHasTheSameTrajectoryAt60And120Hz() {
        function at(hz:Int):Float {
            final scroll = new gpui.base.ScrollBounce.Physics();
            scroll.begin(600.);
            scroll.pull(180.);
            scroll.release();
            for (_ in 0...Std.int(hz / 4)) {
                scroll.step(gpui.SpringMath.f32(1. / hz));
            }
            return scroll.offset();
        }
        assertTrue(Math.abs(at(60) - at(120)) < 0.001);
    }

    function testReturnKeepsAVisibleTailAfterAQuarterSecond() {
        final scroll = new gpui.base.ScrollBounce.Physics();
        @:privateAccess scroll.position = 100.;
        assertTrue(scroll.step(0.25));
        // A 100 px release should still have a visible, decelerating tail
        // after 250 ms instead of snapping almost completely back by then.
        assertTrue(scroll.offset() > 10. && scroll.offset() < 30.);
        assertTrue(@:privateAccess scroll.velocity < 0.);
    }

    function testSpringSettlesWithoutCrossingTheBoundary() {
        final scroll = new gpui.base.ScrollBounce.Physics();
        scroll.begin(600.);
        scroll.pull(-200.);
        scroll.release();
        var previous = scroll.offset();
        for (_ in 0...120) {
            scroll.step(gpui.SpringMath.f32(1. / 120.));
            assertTrue(scroll.offset() >= previous && scroll.offset() <= 0.);
            previous = scroll.offset();
        }
        assertEquals(0., scroll.offset());
        assertTrue(@:privateAccess scroll.suppressMomentum);
        scroll.begin(600.);
        assertFalse(@:privateAccess scroll.suppressMomentum);
    }

    /// scrollable_mask.rs

    function testCornerNotchPathsStayInsideTheirCornerSquares() {
        final width = 200.;
        final height = 100.;
        final radius = 8.;
        final cases = [
            {name: 'top left', corner: new Point(0., 0.), xDir: 1., yDir: 1.},
            {name: 'top right', corner: new Point(width, 0.), xDir: -1., yDir: 1.},
            {name: 'bottom right', corner: new Point(width, height), xDir: -1., yDir: -1.},
            {name: 'bottom left', corner: new Point(0., height), xDir: 1., yDir: -1.}
        ];
        for (c in cases) {
            final path = @:privateAccess gpui.base.ScrollableMask.RoundedFrameCover.cornerNotchPath(c.corner, c.xDir, c.yDir, radius);
            assertNotNull(path, 'the notch tessellates');
            final bounds = path.bounds;
            // Curve tessellation may inset fractionally; one pixel of slack.
            final tolerance = 1.0;
            assertTrue(Math.abs(bounds.size.width - radius) <= tolerance && Math.abs(bounds.size.height - radius) <= tolerance, '${c.name}: notch size');
            final expectedOrigin = new Point(c.xDir > 0. ? c.corner.x : c.corner.x - radius, c.yDir > 0. ? c.corner.y : c.corner.y - radius);
            assertTrue(Math.abs(bounds.origin.x - expectedOrigin.x) <= tolerance && Math.abs(bounds.origin.y - expectedOrigin.y) <= tolerance, '${c.name}: notch bounds must anchor at the frame corner');
        }
    }

    function horizontalAreaTest(scrollHandle:ScrollHandle):VisualTestContext {
        final cx = open((_, _) -> div().w(px(100.)).h(px(40.)).child(@:privateAccess ScrollableMask.horizontalScrollArea(
            'horizontal-scroll-area', scrollHandle, new StyleRefinement(), div().w(px(300.)).h(px(40.)))));
        cx.runUntilParked();
        draw(cx);
        return cx;
    }

    static function wheelEvent(x:Float, y:Float, delta:ScrollDelta):ScrollEvent {
        return new ScrollEvent(new Point(x, y), delta);
    }

    function testHorizontalScrollAreaIgnoresVerticalWheel() {
        final scrollHandle = new ScrollHandle();
        final cx = horizontalAreaTest(scrollHandle);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(0., -40.))));
        assertEquals(0., scrollHandle.offset().x);
    }

    /** The markdown table case: the scroll area lives inside a `list` item. */
    function listWithHorizontalArea(scrollHandle:ScrollHandle, listState:ListState, occluded:Bool):VisualTestContext {
        final cx = open((_, _) -> {
            final root = div().w(px(100.)).h(px(100.)).child(list(listState, (ix, _, _) -> {
                if (ix == 0) {
                    return @:privateAccess ScrollableMask.horizontalScrollArea('horizontal-scroll-area', scrollHandle, new StyleRefinement(), div().w(px(300.)).h(px(40.)));
                }
                return div().w(px(100.)).h(px(40.));
            }).wFull().hFull());
            if (occluded) {
                // An overlay above the list, like an open dialog or menu.
                root.child(div().absolute().top0().left0().sizeFull().occlude());
            }
            return root;
        });
        cx.runUntilParked();
        draw(cx);
        return cx;
    }

    static function scrollTop(listState:ListState):String {
        final top = listState.logicalScrollTop();
        return '${top.itemIx},${top.offsetInItem}';
    }

    function testHorizontalScrollAreaInListKeepsHorizontalDominantWheel() {
        final scrollHandle = new ScrollHandle();
        final listState = new ListState(10, Top, 0.);
        final cx = listWithHorizontalArea(scrollHandle, listState, false);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-40., -10.))));
        assertEquals(-40., scrollHandle.offset().x);
        assertEquals('0,0', scrollTop(listState));
    }

    function testHorizontalScrollAreaInListBubblesVerticalDominantWheel() {
        final scrollHandle = new ScrollHandle();
        final listState = new ListState(10, Top, 0.);
        final cx = listWithHorizontalArea(scrollHandle, listState, false);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-10., -40.))));
        assertEquals(0., scrollHandle.offset().x);
        assertTrue(scrollTop(listState) != '0,0');
    }

    function listWithVerticalMask(outerHandle:ScrollHandle, listState:ListState):VisualTestContext {
        final cx = open((_, _) -> div()
            .id('outer')
            .w(px(100.))
            .h(px(100.))
            .overflowYScroll()
            .trackScroll(outerHandle)
            .child(div().wFull().h(px(400.)).child(div()
                .relative()
                .wFull()
                .h(px(80.))
                .overflowHidden()
                .child(list(listState, (_, _, _) -> div().wFull().h(px(40.))).wFull().hFull())
                .child(new ScrollableMask(Vertical, listState)))));
        cx.runUntilParked();
        draw(cx);
        return cx;
    }

    function testVerticalMaskContainsWheelInsideTheList() {
        final outerHandle = new ScrollHandle();
        // A large overdraw measures every row up front, so the mask sees the
        // full content height.
        final listState = new ListState(10, Top, 1000.);
        final cx = listWithVerticalMask(outerHandle, listState);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(0., -40.))));
        assertEquals(-40., listState.scrollPxOffsetForScrollbar().y);
        assertEquals(0., outerHandle.offset().y);
    }

    function testVerticalMaskChainsToTheAncestorAtTheEdge() {
        final outerHandle = new ScrollHandle();
        final listState = new ListState(10, Top, 1000.);
        // Start the inner list at its bottom edge (400 - 80 = 320).
        listState.scrollTo(new ListOffset(8, 0.));
        final cx = listWithVerticalMask(outerHandle, listState);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(0., -40.))));
        assertEquals(-320., listState.scrollPxOffsetForScrollbar().y);
        assertEquals(-40., outerHandle.offset().y);
    }

    function testHorizontalScrollAreaCoversViewportAfterScrolled() {
        final scrollHandle = new ScrollHandle();
        final listState = new ListState(10, Top, 0.);
        final cx = listWithHorizontalArea(scrollHandle, listState, false);
        // Scroll the area to the middle, then repaint.
        scrollHandle.setOffset(new Point(-150., 0.));
        draw(cx);
        // Swipe over the right side of the viewport. The mask must still
        // cover it: it must not slide away with the scrolled content.
        cx.simulateEvent(wheelEvent(90., 10., Pixels(new Point(-40., -10.))));
        assertEquals(-190., scrollHandle.offset().x);
        assertEquals('0,0', scrollTop(listState));
    }

    function testHorizontalScrollAreaTrapsWheelAtEdge() {
        final scrollHandle = new ScrollHandle();
        final listState = new ListState(10, Top, 0.);
        final cx = listWithHorizontalArea(scrollHandle, listState, false);
        // Scroll the area to its right edge (300 - 100 = 200).
        scrollHandle.setOffset(new Point(-200., 0.));
        draw(cx);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-40., -10.))));
        // A horizontal mask consumes even at the edge.
        assertEquals('0,0', scrollTop(listState));
    }

    function testHorizontalScrollAreaIgnoresWheelWhenOccluded() {
        final scrollHandle = new ScrollHandle();
        final listState = new ListState(10, Top, 0.);
        final cx = listWithHorizontalArea(scrollHandle, listState, true);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-40., -10.))));
        assertEquals(0., scrollHandle.offset().x);
    }

    function testHorizontalScrollAreaUsesHorizontalWheel() {
        final scrollHandle = new ScrollHandle();
        final cx = horizontalAreaTest(scrollHandle);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-40., 0.))));
        assertEquals(-40., scrollHandle.offset().x);
    }

    function testHorizontalScrollAreaClaimsOnlyStepsThatMove() {
        final scrollHandle = new ScrollHandle();
        final cx = horizontalAreaTest(scrollHandle);

        // At the left edge, a swipe toward the start has no room: no claim.
        @:privateAccess ScrollableMask.lastHorizontalScrollClaimValue = null;
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(40., 0.))));
        assertNull(ScrollableMask.lastHorizontalScrollClaim());

        // The overscroll only lasts until the next prepaint clamps it, so
        // dispatch these steps within one update.
        cx.update((window, app) -> {
            function dispatch(deltaX:Float) {
                window.dispatchEvent(wheelEvent(10., 10., Pixels(new Point(deltaX, 0.))), app);
            }
            // Reversing an overscroll without re-entering the range does not
            // move content.
            scrollHandle.setOffset(new Point(40., 0.));
            dispatch(-10.);
            assertNull(ScrollableMask.lastHorizontalScrollClaim());
            assertEquals(30., scrollHandle.offset().x);

            // Only the part of a step that re-enters the range counts as movement.
            dispatch(-40.);
            return null;
        });
        final claim = ScrollableMask.lastHorizontalScrollClaim();
        assertNotNull(claim, 'a moving step claims');
        assertEquals(-10., claim.deltaX());
        assertEquals(-10., scrollHandle.offset().x);

        // Ignored input keeps the last meaningful claim intact.
        for (delta in [new Point(0., -40.), new Point(-0.25, 0.)]) {
            cx.simulateEvent(wheelEvent(10., 10., Pixels(delta)));
            assertTrue(claim.equals(ScrollableMask.lastHorizontalScrollClaim()));
        }
    }

    function testHorizontalMaskKeepsAxisLockWithinAGesture() {
        final scrollHandle = new ScrollHandle();
        final cx = horizontalAreaTest(scrollHandle);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-40., -10.))));
        assertEquals(-40., scrollHandle.offset().x);
        // Same gesture, now leaning vertical but under the unlock ratio: the
        // lock holds and the horizontal offset keeps moving.
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-10., -15.))));
        assertEquals(-50., scrollHandle.offset().x);
    }

    function testHorizontalMaskReleasesAxisLockOnAStrongTurn() {
        final scrollHandle = new ScrollHandle();
        final cx = horizontalAreaTest(scrollHandle);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-40., -10.))));
        assertEquals(-40., scrollHandle.offset().x);
        // Past the unlock ratio the gesture is no longer horizontal, so the
        // event stops driving this scroller.
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(-10., -25.))));
        assertEquals(-40., scrollHandle.offset().x);
    }

    /** The DataTable case: a vertically scrollable element nested inside an outer vertical scroller. */
    function nestedVertical(outerHandle:ScrollHandle, innerHandle:ScrollHandle, innerContentHeight:Float):VisualTestContext {
        final cx = open((_, _) -> div()
            .id('outer')
            .w(px(100.))
            .h(px(100.))
            .overflowYScroll()
            .trackScroll(outerHandle)
            .child(div()
                .relative()
                .wFull()
                .h(px(60.))
                .child(div()
                    .id('inner')
                    .sizeFull()
                    .overflowYScroll()
                    .trackScroll(innerHandle)
                    .child(div().wFull().h(px(innerContentHeight))))
                .child(new ScrollableMask(Vertical, innerHandle)))
            .child(div().wFull().h(px(400.))));
        cx.runUntilParked();
        draw(cx);
        return cx;
    }

    function testVerticalMaskConsumesWheelWhenScrollable() {
        final outerHandle = new ScrollHandle();
        final innerHandle = new ScrollHandle();
        final cx = nestedVertical(outerHandle, innerHandle, 300.);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(0., -40.))));
        assertEquals(-40., innerHandle.offset().y);
        assertEquals(0., outerHandle.offset().y);
    }

    function testVerticalMaskHandsOffToParentAtEdge() {
        final outerHandle = new ScrollHandle();
        final innerHandle = new ScrollHandle();
        final cx = nestedVertical(outerHandle, innerHandle, 300.);
        // Scroll the inner element to its bottom edge (300 - 60 = 240).
        innerHandle.setOffset(new Point(0., -240.));
        draw(cx);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(0., -40.))));
        assertEquals(-40., outerHandle.offset().y);
        draw(cx);
        assertEquals(-240., innerHandle.offset().y);
    }

    function testVerticalMaskBubblesWhenNoOverflow() {
        final outerHandle = new ScrollHandle();
        final innerHandle = new ScrollHandle();
        // Inner content (40) fits its 60px viewport: nothing to scroll.
        final cx = nestedVertical(outerHandle, innerHandle, 40.);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(0., -40.))));
        assertEquals(-40., outerHandle.offset().y);
        draw(cx);
        assertEquals(0., innerHandle.offset().y);
    }

    function testVerticalMaskIgnoresTransientOverscroll() {
        final outerHandle = new ScrollHandle();
        final innerHandle = new ScrollHandle();
        final cx = nestedVertical(outerHandle, innerHandle, 300.);
        innerHandle.setOffset(new Point(0., -240.));
        draw(cx);
        // Two wheel events at the edge with no redraw in between.
        for (_ in 0...2) {
            cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(0., -40.))));
        }
        assertEquals(-80., outerHandle.offset().y);
        draw(cx);
        assertEquals(-240., innerHandle.offset().y);
    }

    function testVerticalMaskInListConsumesWheelWhenScrollable() {
        final scrollHandle = new ScrollHandle();
        final listState = new ListState(10, Top, 0.);
        final cx = open((_, _) -> div().w(px(100.)).h(px(100.)).child(list(listState, (ix, _, _) -> {
            if (ix == 0) {
                return div()
                    .relative()
                    .wFull()
                    .h(px(60.))
                    .child(div()
                        .id('inner')
                        .sizeFull()
                        .overflowYScroll()
                        .trackScroll(scrollHandle)
                        .child(div().wFull().h(px(300.))))
                    .child(new ScrollableMask(Vertical, scrollHandle));
            }
            return div().w(px(100.)).h(px(40.));
        }).wFull().hFull()));
        cx.runUntilParked();
        draw(cx);
        cx.simulateEvent(wheelEvent(10., 10., Pixels(new Point(0., -40.))));
        assertEquals(-40., scrollHandle.offset().y);
        assertEquals('0,0', scrollTop(listState));
    }

    /** A 100px strip of 300px content, locked to its axis like a tab strip, with a vertical-wheel mask, inside a vertical scroller. */
    function verticalWheelTest():{cx:VisualTestContext, strip:ScrollHandle, page:ScrollHandle} {
        final strip = new ScrollHandle();
        final page = new ScrollHandle();
        final cx = open((_, _) -> div()
            .id('page')
            .w(px(100.))
            .h(px(60.))
            .overflowYScroll()
            .trackScroll(page)
            .child(div()
                .relative()
                .w(px(100.))
                .h(px(40.))
                .child(div()
                    .id('strip')
                    .sizeFull()
                    .flex()
                    .overflowXScroll()
                    .restrictScrollToAxis()
                    .trackScroll(strip)
                    .child(div().flexNone().w(px(300.)).h(px(40.))))
                .child(ScrollableMask.verticalWheel(strip)))
            .child(div().h(px(200.))));
        cx.runUntilParked();
        draw(cx);
        return {cx: cx, strip: strip, page: page};
    }

    static function wheel(cx:VisualTestContext, delta:ScrollDelta):Void {
        cx.simulateEvent(wheelEvent(10., 10., delta));
        draw(cx);
    }

    function testVerticalWheelScrollsTheStripAndThenTheParent() {
        final t = verticalWheelTest();
        final lineHeight = t.cx.update((window, _) -> window.lineHeight());

        wheel(t.cx, Lines(new Point(0., -1.)));
        assertEquals(-lineHeight, t.strip.offset().x);
        assertEquals(0., t.page.offset().y);

        // Past the strip's end, the wheel scrolls the page.
        wheel(t.cx, Lines(new Point(0., -100.)));
        assertEquals(-200., t.strip.offset().x);
        assertEquals(0., t.page.offset().y);
        wheel(t.cx, Lines(new Point(0., -1.)));
        assertEquals(-200., t.strip.offset().x);
        assertTrue(t.page.offset().y < 0.);

        // A delta that is no number does not move the strip.
        wheel(t.cx, Lines(new Point(0., Math.NaN)));
        assertEquals(-200., t.strip.offset().x);
    }

    function testVerticalWheelLeavesTrackpadsAndHorizontalWheelsToTheScroller() {
        final t = verticalWheelTest();
        final lineHeight = t.cx.update((window, _) -> window.lineHeight());

        // A vertical trackpad swipe keeps the strip's axis lock.
        wheel(t.cx, Pixels(new Point(0., -20.)));
        assertEquals(0., t.strip.offset().x);
        assertEquals(-20., t.page.offset().y);

        // A horizontal wheel reaches the strip's own listener.
        wheel(t.cx, Lines(new Point(-1., 0.)));
        assertEquals(-lineHeight, t.strip.offset().x);
    }

    /// auto_scroll.rs

    function testDeltaUsesDeadZoneAndSymmetricEdgeRamps() {
        final bounds = new Bounds(new Point(0., 100.), new Size(200., 100.));
        assertNull(AutoScroll.computeDelta(150., bounds));
        final top = AutoScroll.computeDelta(80., bounds);
        final bottom = AutoScroll.computeDelta(220., bounds);
        assertEquals(-bottom, top);
        assertTrue(top < -12.);
    }

    function testStopClearsDeltaAndDragPosition() {
        final scroll = new AutoScroll();
        @:privateAccess scroll.shared = 20.;
        scroll.lastDragPosition = new Point(1., 2.);
        scroll.stop();
        assertFalse(scroll.isActive());
        assertNull(scroll.lastDragPosition);
    }

    /// virtual_list.rs

    function exerciseAxis(axis:Axis) {
        final itemSize = axis == Horizontal ? new Size(20., 10.) : new Size(10., 20.);
        final itemSizes = [for (_ in 0...20) itemSize];
        final scrollHandle = new gpui.base.VirtualList.VirtualListScrollHandle();
        final visibleRanges:Array<Array<Int>> = [];
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new VirtualListHarness(axis, itemSizes, scrollHandle, visibleRanges));
        contexts.push(opened.cx);
        final cx = opened.cx;

        draw(cx);
        final initialRange = visibleRanges[visibleRanges.length - 1];
        assertEquals(0, initialRange[0]);
        assertTrue(initialRange[1] < itemSizes.length);

        scrollHandle.scrollToItem(12, Top);
        draw(cx);
        final scrolledRange = visibleRanges[visibleRanges.length - 1];
        assertTrue(scrolledRange[0] <= 12 && 12 < scrolledRange[1]);
        if (axis == Horizontal) {
            assertTrue(scrollHandle.offset().x < 0.);
        }
        else {
            assertTrue(scrollHandle.offset().y < 0.);
        }
    }

    static function layout(sizes:Array<Float>):{origins:Array<Float>, sizes:Array<Float>} {
        final origins = [];
        var cumulative = 0.;
        for (size in sizes) {
            origins.push(cumulative);
            cumulative += size;
        }
        return {origins: origins, sizes: sizes};
    }

    static function range(l:{origins:Array<Float>, sizes:Array<Float>}, start:Float, end:Float):String {
        final r = @:privateAccess VirtualList.visibleRange(l.origins, l.sizes, start, end);
        return '${r[0]}..${r[1]}';
    }

    function testVisibleRangeStartsAtTheFirstItemCrossingTheViewport() {
        final l = layout([for (_ in 0...10) 20.]);
        assertEquals('0..5', range(l, 0., 60.));
        assertEquals('2..7', range(l, 50., 110.));
    }

    function testVisibleRangeOverdrawsOneItemPastTheViewportButNotPastTheEnd() {
        final l = layout([for (_ in 0...10) 20.]);
        assertEquals('7..10', range(l, 150., 210.));
        assertEquals('0..10', range(l, 0., 500.));
    }

    function testVisibleRangeHandlesUnevenSizes() {
        final l = layout([10., 30., 5., 50.]);
        assertEquals('1..4', range(l, 12., 44.));
        assertEquals('3..4', range(l, 45., 50.));
    }

    function testVisibleRangeIsEmptyWithoutItemsOrPastTheContent() {
        assertEquals('0..0', range(layout([]), 0., 60.));
        final r = @:privateAccess VirtualList.visibleRange(layout([for (_ in 0...10) 20.]).origins, layout([for (_ in 0...10) 20.]).sizes, 300., 360.);
        assertTrue(r[0] >= r[1]);
    }

    function testVerticalVisibleRangeAndDeferredScrollArePreserved() {
        exerciseAxis(Vertical);
    }

    function testHorizontalVisibleRangeAndDeferredScrollArePreserved() {
        exerciseAxis(Horizontal);
    }

    function testEmptyListDrawsWithoutRequestingItems() {
        final visibleRanges:Array<Array<Int>> = [];
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new VirtualListHarness(Vertical, [], new gpui.base.VirtualList.VirtualListScrollHandle(), visibleRanges));
        contexts.push(opened.cx);
        draw(opened.cx);
        assertEquals(0, visibleRanges.length);
    }

}

private class MathSign {

    public static inline function of(value:Float):Float {
        return gpui.util.MathUtil.signum(value);
    }

}

/**
 * The view of the virtual list tests (Rust `VirtualListHarness`).
 */
private class VirtualListHarness extends Model implements Render {

    final axis:Axis;

    final itemSizes:Array<Size>;

    final scrollHandle:gpui.base.VirtualList.VirtualListScrollHandle;

    final visibleRanges:Array<Array<Int>>;

    public function new(axis:Axis, itemSizes:Array<Size>, scrollHandle:gpui.base.VirtualList.VirtualListScrollHandle, visibleRanges:Array<Array<Int>>) {
        super();
        this.axis = axis;
        this.itemSizes = itemSizes;
        this.scrollHandle = scrollHandle;
        this.visibleRanges = visibleRanges;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final itemSizes = this.itemSizes;
        final visibleRanges = this.visibleRanges;
        final entity:Entity<VirtualListHarness> = cx.entity();
        return VirtualList.virtualList(entity, 'virtual-list-test', axis, itemSizes, (_, start, end, _, _) -> {
            visibleRanges.push([start, end]);
            return [for (ix in start...end) (div().w(px(itemSizes[ix].width)).h(px(itemSizes[ix].height)) : IntoElement)];
        })
            .trackScroll(scrollHandle)
            .w(px(60.))
            .h(px(60.));
    }

}

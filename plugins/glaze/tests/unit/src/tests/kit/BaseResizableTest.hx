// Ported from gpui-kit 0.8.1: crates/base/src/resizable/mod.rs (tests), crates/base/src/resizable/resize_handle.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.Context;
import gpui.DragMoveEvent;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.MouseUpEvent;
import gpui.Pixels;
import gpui.Point;
import gpui.Render;
import gpui.Size;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.Base;
import gpui.base.resizable.Resizable;
import gpui.base.resizable.ResizableState;
import gpui.base.resizable.PixelsRange;
import gpui.base.resizable.ResizeHandle;
import gpui.base.resizable.ResizeHandle.HandleEdge;
import gpui.base.resizable.ResizeHandle.ResizeHandleState;
import gpui.base.resizable.ResizeHandle.SharedHandleState;
import gpui.base.resizable.ResizableState.ResizablePanelState;
import gpui.base.theme.ResizableTheme;
import gpui.base.theme.Theme;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.base.ElementExt;
using gpui.base.InteractiveElementExt;

/**
 * The `#[cfg(test)]` tests of gpui-base's `resizable` module (the group,
 * the panels and the resize handle). Element bounds are read through
 * `DebugProbe` (Rust `debug_selector`).
 *
 * Not ported: `redrawing_panels_where_they_were_leaves_their_readers_retained`
 * (only built with gpui-kit's `gpui-fast` feature, absent from the reference
 * build), and `a_hugging_handle_paints_beneath_a_popover_deferred_before_it`
 * (it counts prepaint hooks across deferred draws; the hairline and the mask
 * it is painted under are checked by `testAHuggingHandleDrawsItsLineOnTheSeam`).
 */
class BaseResizableTest extends TestCase {

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

    function open<V:Model & Render>(build:(Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        DebugProbe.clear();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, cx:Context<V>) -> build(cx));
        contexts.push(opened.cx);
        return opened;
    }

    static function draw(cx:VisualTestContext):Void {
        DebugProbe.clear();
        cx.update((window, _) -> window.draw());
    }

    static inline function b(selector:String):Null<Bounds> {
        return DebugProbe.bounds(selector);
    }

    static function sizesString(state:Entity<ResizableState>, cx:VisualTestContext):String {
        return cx.update((_, cx) -> state.read(cx).sizes().join(','));
    }

    function newState():Entity<ResizableState> {
        return app.update(cx -> cx.newEntity((_:Context<ResizableState>) -> new ResizableState()));
    }

    function testMixedSizingIsStableBetweenResizeAndFollowupFrame() {
        final opened = open((_:Context<MixedSizingHarness>) -> new MixedSizingHarness(800.));
        final cx = opened.cx;
        draw(cx);
        draw(cx);
        final before = b('fixed-sidebar').size.width;

        cx.update((_, app) -> opened.view.update(app, (view, cx) -> {
            view.width = 1200.;
            cx.notify();
        }));
        cx.runUntilParked();
        final settledFrame = b('fixed-sidebar').size.width;
        draw(cx);
        final followupFrame = b('fixed-sidebar').size.width;

        // Resizable panels preserve their proportional sizing across a
        // container resize; the important invariant is that applying the
        // state on the follow-up frame does not move the divider again.
        assertTrue(settledFrame != before);
        assertEquals(settledFrame, followupFrame);
    }

    function widths():String {
        return [for (selector in ['fp-sidebar', 'fp-main', 'fp-aside']) b(selector).size.width].join(',');
    }

    /**
     * A fixed panel keeps its size when the container resizes, the other
     * panels share the rest in their proportions, and a container briefly
     * too small for the fixed panel does not lose those proportions. A drag
     * on another handle does not take space from it either.
     */
    function testFixedPanelKeepsItsSizeAcrossAContainerResize() {
        final state = newState();
        final opened = open((_:Context<FixedPanelHarness>) -> new FixedPanelHarness(840., true, state));
        final cx = opened.cx;
        draw(cx);
        draw(cx);
        assertEquals('240,400,200', widths());

        for (entry in [
            {width: 1140., expected: '240,600,300'},
            {width: 200., expected: null},
            {width: 600., expected: '240,240,120'},
        ]) {
            cx.update((_, app) -> opened.view.update(app, (view, cx) -> {
                view.width = entry.width;
                cx.notify();
            }));
            cx.runUntilParked();
            draw(cx);
            assertEquals(240., b('fp-sidebar').size.width);
            if (entry.expected != null) {
                assertEquals(entry.expected, widths());
            }
        }

        // Dragging the main panel below its minimum takes the rest from the
        // panel after it, not from the fixed sidebar before it.
        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> state.resizePanel(1, 50., window, cx));
            DebugProbe.clear();
            window.draw();
        });
        assertEquals('240,100,260', widths());

        // Its own handle still resizes the fixed sidebar, and it keeps the
        // new width when the container resizes again.
        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> state.resizePanel(0, 300., window, cx));
            DebugProbe.clear();
            window.draw();
        });
        assertEquals('300,100,200', widths());
        cx.update((_, app) -> opened.view.update(app, (view, cx) -> {
            view.width = 900.;
            cx.notify();
        }));
        cx.runUntilParked();
        draw(cx);
        assertEquals(300., b('fp-sidebar').size.width);
    }

    /**
     * A panel made fixed after its first frame, while its bounds stay the
     * same, keeps its size on the next container resize.
     */
    function testPanelMadeFixedInPlaceKeepsItsSizeAcrossAContainerResize() {
        final state = newState();
        final opened = open((_:Context<FixedPanelHarness>) -> new FixedPanelHarness(840., false, state));
        final cx = opened.cx;
        function update(f:(FixedPanelHarness) -> Void) {
            cx.update((_, app) -> opened.view.update(app, (view, cx) -> {
                f(view);
                cx.notify();
            }));
            cx.runUntilParked();
            draw(cx);
        }
        update(_ -> {});
        update(view -> view.fixed = true);
        update(view -> view.width = 1140.);

        assertEquals(240., b('fp-sidebar').size.width);
    }

    /**
     * A group whose state the caller owns (`withState`, as the dock does)
     * has no keyed state observer behind it, so the settling frame has to be
     * scheduled by the deferred notify rather than by that observer.
     */
    function testCallerOwnedStateSettlesOnTheSameFrame() {
        final state = newState();
        final opened = open((_:Context<CallerStateHarness>) -> new CallerStateHarness(800., state));
        final cx = opened.cx;
        draw(cx);
        draw(cx);

        cx.update((_, app) -> opened.view.update(app, (view, cx) -> {
            view.width = 1200.;
            cx.notify();
        }));
        cx.runUntilParked();
        final settled = b('cs-sidebar').size.width;
        draw(cx);
        final followup = b('cs-sidebar').size.width;

        assertEquals(settled, followup);
    }

    function harness():{cx:VisualTestContext, state:Entity<ResizableState>, resizes:Array<Int>} {
        final state = newState();
        final resizes = [0];
        final opened = open((_:Context<ResizableHarness>) -> new ResizableHarness(state, resizes));
        draw(opened.cx);
        draw(opened.cx);
        return {cx: opened.cx, state: state, resizes: resizes};
    }

    function testDynamicPanelLifecycleIsOwnedByResizableState() {
        final state = newState();

        app.update(cx -> {
            state.update(cx, (state, cx) -> {
                state.bounds = new Bounds(new Point(0., 0.), new Size(400., 100.));
                state.panels.push(new ResizablePanelState());
                state.sizesValue.push(400.);
                state.insertPanel(200., null, cx);
                assertEquals('200,200', state.sizes().join(','));

                state.resetPanel(0, cx);
                assertEquals('200,200', state.sizes().join(','));

                state.removePanel(0, cx);
                assertEquals('400', state.sizes().join(','));

                state.clear();
                assertEquals(0, state.sizes().length);
            });
        });
    }

    function testGroupMeasuresPanelsAndProgrammaticResizeUsesDragRules() {
        final h = harness();
        final cx = h.cx;
        final first = b('first-panel');
        final second = b('second-panel');
        assertEquals(400., first.size.width + second.size.width);

        cx.update((window, cx) -> {
            h.state.update(cx, (state, cx) -> state.resizePanel(0, 220., window, cx));
            window.draw();
        });

        assertEquals('220,180', sizesString(h.state, cx));
    }

    function testDraggingTheHandleResizesAndEmitsOnce() {
        final h = harness();
        final cx = h.cx;
        final boundary = b('second-panel').left();

        cx.simulateMouseDown(new Point(boundary - 2., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 10., 50.), Left);
        cx.simulateMouseMove(new Point(220., 50.), Left);
        cx.simulateMouseUp(new Point(220., 50.), Left);

        assertEquals('220,180', sizesString(h.state, cx));
        assertEquals(1, h.resizes[0]);
    }

    function testDraggingBeforeTheNextPaintResizesAndEmitsOnce() {
        final h = harness();
        final cx = h.cx;
        final state = h.state;
        final boundary = b('second-panel').left();

        // Dispatch the whole gesture in one update. The simulation helpers
        // allow a paint between events and hide stale listener state.
        cx.update((window, cx) -> {
            window.dispatchEvent(new MouseDownEvent(Left, new Point(boundary - 2., 50.), null, 1), cx);
            for (x in [boundary + 10., 220.]) {
                window.dispatchEvent(new MouseMoveEvent(new Point(x, 50.), Left), cx);
            }
            assertEquals(0, state.read(cx).resizingPanelIx);
            assertEquals('220,180', state.read(cx).sizes().join(','));
            assertEquals(0, h.resizes[0]);

            // Repeated release and subsequent movement must not reuse the
            // active index from the gesture that just finished.
            for (_ in 0...2) {
                window.dispatchEvent(new MouseUpEvent(Left, new Point(220., 50.), null, 1), cx);
            }
            window.dispatchEvent(new MouseMoveEvent(new Point(260., 50.)), cx);
            assertEquals(null, state.read(cx).resizingPanelIx);
            assertEquals('220,180', state.read(cx).sizes().join(','));
            assertEquals(1, h.resizes[0]);
        });
    }

    function testCancelledDragDoesNotReuseThePaintedIndex() {
        final h = harness();
        final cx = h.cx;
        final state = h.state;
        final boundary = b('second-panel').left();
        cx.simulateMouseDown(new Point(boundary - 2., 50.), Left);
        cx.simulateMouseMove(new Point(boundary + 10., 50.), Left);
        cx.update((window, cx) -> {
            assertEquals(0, state.read(cx).resizingPanelIx);
            window.draw();
            state.update(cx, (state, cx) -> state.resizePanel(0, 210., window, cx));
            cx.stopActiveDrag(window);
            assertEquals(null, state.read(cx).resizingPanelIx);

            // Cancel after painting the active index, then deliver queued
            // events without replacing that frame's listeners.
            window.dispatchEvent(new MouseMoveEvent(new Point(260., 50.), Left), cx);
            window.dispatchEvent(new MouseUpEvent(Left, new Point(260., 50.), null, 1), cx);
            assertEquals('210,190', state.read(cx).sizes().join(','));
            assertEquals(null, state.read(cx).resizingPanelIx);
            assertEquals(0, h.resizes[0]);
        });
    }

    /**
     * A handle under something else does not answer the pointer.
     */
    function testACoveredHandleStaysIdle() {
        final seen:Array<ResizeHandleState> = [];
        final opened = open((_:Context<HandleStateHarness>) -> new HandleStateHarness(seen, true));
        final cx = opened.cx;
        draw(cx);
        draw(cx);

        final boundary = b('hs-second').left();
        final onHandle = new Point(boundary - 2., 50.);

        cx.simulateMouseMove(onHandle);
        draw(cx);
        cx.simulateMouseDown(onHandle, Left);
        draw(cx);
        cx.simulateMouseUp(onHandle, Left);
        draw(cx);

        assertEquals('${[Idle]}', '$seen');
    }

    function testAHandleReportsThePressAndTheDragToItsRenderer() {
        final seen:Array<ResizeHandleState> = [];
        final opened = open((_:Context<HandleStateHarness>) -> new HandleStateHarness(seen, false));
        final cx = opened.cx;
        draw(cx);
        draw(cx);

        final boundary = b('hs-second').left();
        final onHandle = new Point(boundary - 2., 50.);

        cx.simulateMouseMove(onHandle);
        draw(cx);
        cx.simulateMouseDown(onHandle, Left);
        draw(cx);
        cx.simulateMouseMove(new Point(260., 50.), Left);
        draw(cx);
        cx.simulateMouseUp(new Point(390., 90.), Left);
        draw(cx);

        final expected:Array<ResizeHandleState> = [Idle, Hovered, Pressed, Dragging, Idle];
        assertEquals('$expected', '$seen');
    }

    function testAGroupSizeBindsTheCrossAxis() {
        final opened = open((_:Context<SizedGroupHarness>) -> new SizedGroupHarness());
        final cx = opened.cx;
        draw(cx);
        draw(cx);

        final panel = b('sized-panel');
        assertEquals(400., panel.size.width);
        assertEquals(40., panel.size.height);
    }

/// resize_handle.rs

    /**
     * The seam a hugging handle marks, along its axis: the dock spans
     * 100..300 in the harness.
     */
    static function seam(edge:HandleEdge):Float {
        return switch edge {
            case Leading: 100.;
            case Trailing: 300.;
        }
    }

    static function along(axis:Axis, bounds:Bounds):Array<Float> {
        return switch axis {
            case Horizontal: [bounds.left(), bounds.right()];
            case Vertical: [bounds.top(), bounds.bottom()];
        }
    }

    function drawHugging(axis:Axis, edge:HandleEdge):HuggingProbe {
        final probe = new HuggingProbe();
        final opened = open((_:Context<HuggingHarness>) -> new HuggingHarness(axis, edge, probe));
        draw(opened.cx);
        return probe;
    }

    /**
     * A hugging handle's hairline is the container's outermost pixel, and it
     * is painted under its container's clip.
     */
    function testAHuggingHandleDrawsItsLineOnTheSeam() {
        for (axis in [Axis.Horizontal, Axis.Vertical]) {
            for (edge in [HandleEdge.Leading, HandleEdge.Trailing]) {
                final probe = drawHugging(axis, edge);
                assertTrue(probe.line != null);
                final range = along(axis, probe.line);
                final expected = switch edge {
                    case Leading: [seam(edge), seam(edge) + 1.];
                    case Trailing: [seam(edge) - 1., seam(edge)];
                };
                assertEquals('$expected', '$range');
                assertEquals('[100,300]', '${along(axis, probe.mask)}');
            }
        }
    }

    /**
     * A renderer is told which edge the handle hugs.
     */
    function testARendererIsToldTheEdgeAHandleHugs() {
        for (axis in [Axis.Horizontal, Axis.Vertical]) {
            for (edge in [HandleEdge.Leading, HandleEdge.Trailing]) {
                final probe = drawHugging(axis, edge);
                assertTrue(probe.edgeTold);
                assertEquals(edge, probe.edge);
            }
        }
    }

    function testAListenerWritesItsProgressBackIntoTheStoredState() {
        final stored = new SharedHandleState();
        // What `paint` hands each mouse listener: the same object.
        final listener = stored;

        assertTrue(listener.set(Pressed));

        assertEquals(ResizeHandleState.Pressed, stored.get());
        assertTrue(stored.get().isActive());
    }

    function testSettingTheStateItAlreadyHasAsksForNoRepaint() {
        final state = new SharedHandleState();

        assertTrue(state.set(Hovered));
        assertFalse(state.set(Hovered));
    }

    function testOnlyAHeldHandleIsActive() {
        assertFalse(ResizeHandleState.Idle.isActive());
        assertFalse(ResizeHandleState.Hovered.isActive());
        assertTrue(ResizeHandleState.Pressed.isActive());
        assertTrue(ResizeHandleState.Dragging.isActive());
    }

    function testAnUnprojectedHandleResolvesFromTheThemeTokens() {
        app.update(cx -> {
            final border = hsla(0., 0., 0.5, 1.0);
            final ring = hsla(0.6, 0.5, 0.5, 1.0);
            final theme = Theme.globalMut(cx);
            theme.tokens.colors.border = border;
            theme.tokens.colors.ring = ring;
            theme.resizable = new ResizableTheme();

            final theme = Theme.global(cx);
            assertTrue(ResizeHandle.handleColor(theme, false).equals(border));
            assertTrue(ResizeHandle.handleColor(theme, true).equals(ring));
            // The point of the change: the default used to be transparent.
            assertFalse(ResizeHandle.handleColor(theme, false).equals(hsla(0., 0., 0., 0.)));
        });
    }

    function testAProjectedHandleStillWins() {
        app.update(cx -> {
            final projected = hsla(0.3, 0.4, 0.5, 1.0);
            final active = hsla(0.9, 0.4, 0.5, 1.0);
            final theme = Theme.globalMut(cx);
            theme.tokens.colors.border = hsla(0., 0., 0.5, 1.0);
            final resizable = new ResizableTheme();
            resizable.handle = projected;
            resizable.activeHandle = active;
            theme.resizable = resizable;

            final theme = Theme.global(cx);
            assertTrue(ResizeHandle.handleColor(theme, false).equals(projected));
            assertTrue(ResizeHandle.handleColor(theme, true).equals(active));
        });
    }

    /**
     * Listeners a caller attaches to a handle reach the band, and leave the
     * progression base reports to the appearance as it was.
     */
    function testACallersListenersReachTheBand() {
        final heard = new Heard();
        final opened = open((_:Context<CallerHarness>) -> new CallerHarness(heard));
        final cx = opened.cx;
        function press(clickCount:Int) {
            cx.simulateEvent(new MouseDownEvent(Left, new Point(198., 50.), null, clickCount, false));
        }
        function release(x:Float, clickCount:Int) {
            cx.simulateEvent(new MouseUpEvent(Left, new Point(x, 50.), null, clickCount));
        }
        draw(cx);

        // The container spans 0..200, and the band hugs its last five pixels.
        cx.simulateMouseMove(new Point(100., 50.));
        draw(cx);
        assertEquals(true, heard.containerHovered);

        cx.simulateMouseMove(new Point(198., 50.));
        draw(cx);
        assertEquals(true, heard.handleHovered);
        // The band occludes, so its own container stops reading as hovered.
        assertEquals(false, heard.containerHovered);

        for (clickCount in [1, 2]) {
            press(clickCount);
            draw(cx);
            release(198., clickCount);
            draw(cx);
        }
        assertEquals(1, heard.doubleClicks);

        press(1);
        draw(cx);
        for (x in [190., 120.]) {
            cx.simulateMouseMove(new Point(x, 50.), Left);
            draw(cx);
        }
        release(120., 1);
        draw(cx);

        // The drag carries `Resize` itself.
        assertEquals(120., heard.dragMoves[heard.dragMoves.length - 1]);
        // A drag is no click, let alone a double one.
        assertEquals(1, heard.doubleClicks);
        final expected:Array<ResizeHandleState> = [Idle, Hovered, Pressed, Hovered, Pressed, Hovered, Pressed, Dragging, Idle];
        assertEquals('$expected', '${heard.states}');
    }

}

private class MixedSizingHarness extends Model implements Render {

    public var width:Float;

    public function new(width:Float) {
        super();
        this.width = width;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().w(px(width)).h(px(100.)).child(
            Resizable.hResizable('mixed-sizing')
                .child(Resizable.resizablePanel().size(240.).child(new DebugProbe('fixed-sidebar', div().sizeFull())))
                .child(Resizable.resizablePanel().child(new DebugProbe('flexible-content', div().sizeFull())))
        );
    }

}

private class FixedPanelHarness extends Model implements Render {

    public var width:Float;

    public var fixed:Bool;

    final state:Entity<ResizableState>;

    public function new(width:Float, fixed:Bool, state:Entity<ResizableState>) {
        super();
        this.width = width;
        this.fixed = fixed;
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final sidebar = Resizable.resizablePanel()
            .size(240.)
            .sizeRange(new PixelsRange(100., 480.));
        if (fixed) sidebar.fixed();
        return div().w(px(width)).h(px(100.)).child(
            Resizable.hResizable('fixed-panel')
                .withState(state)
                .child(sidebar.child(new DebugProbe('fp-sidebar', div().sizeFull())))
                .child(Resizable.resizablePanel().size(400.).child(new DebugProbe('fp-main', div().sizeFull())))
                .child(Resizable.resizablePanel().child(new DebugProbe('fp-aside', div().sizeFull())))
        );
    }

}

private class CallerStateHarness extends Model implements Render {

    public var width:Float;

    final state:Entity<ResizableState>;

    public function new(width:Float, state:Entity<ResizableState>) {
        super();
        this.width = width;
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().w(px(width)).h(px(100.)).child(
            Resizable.hResizable('caller-state')
                .withState(state)
                .child(Resizable.resizablePanel().size(240.).child(new DebugProbe('cs-sidebar', div().sizeFull())))
                .child(Resizable.resizablePanel().child(div().sizeFull()))
        );
    }

}

private class ResizableHarness extends Model implements Render {

    final state:Entity<ResizableState>;

    final resizes:Array<Int>;

    public function new(state:Entity<ResizableState>, resizes:Array<Int>) {
        super();
        this.state = state;
        this.resizes = resizes;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final resizes = this.resizes;
        return div().w(px(400.)).h(px(100.)).child(
            Resizable.hResizable('resizable')
                .withState(state)
                .onResize((_, _, _) -> resizes[0] = resizes[0] + 1)
                .child(Resizable.resizablePanel().size(150.).child(new DebugProbe('first-panel', div().sizeFull())))
                .child(Resizable.resizablePanel().size(250.).child(new DebugProbe('second-panel', div().sizeFull())))
        );
    }

}

/**
 * Reports every state its divider is rendered in. `covered` lays an
 * occluding overlay over the whole group after it.
 */
private class HandleStateHarness extends Model implements Render {

    final seen:Array<ResizeHandleState>;

    final covered:Bool;

    public function new(seen:Array<ResizeHandleState>, covered:Bool) {
        super();
        this.seen = seen;
        this.covered = covered;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final seen = this.seen;
        final root = div()
            .relative()
            .w(px(400.))
            .h(px(100.))
            .child(
                Resizable.hResizable('handle-state')
                    .withHandleAppearance((handle, _, _) -> {
                        if (seen.length == 0 || seen[seen.length - 1] != handle.state()) {
                            seen.push(handle.state());
                        }
                        // Nothing painted: this renderer is here to watch.
                        return null;
                    })
                    .child(Resizable.resizablePanel().size(150.).child(div().sizeFull()))
                    .child(Resizable.resizablePanel().size(250.).child(new DebugProbe('hs-second', div().sizeFull())))
            );
        if (covered) {
            root.child(div().absolute().inset0().occlude());
        }
        return root;
    }

}

private class SizedGroupHarness extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .w(px(400.))
            .h(px(100.))
            .child(
                Resizable.hResizable('sized-resizable').size(40.).child(
                    Resizable.resizablePanel().child(new DebugProbe('sized-panel', div().sizeFull()))
                )
            );
    }

}

/**
 * What a hugging handle's renderer was told and drew, and the mask it was
 * drawn under.
 */
private class HuggingProbe {

    public var edgeTold:Bool = false;

    public var edge:Null<HandleEdge> = null;

    public var line:Null<Bounds> = null;

    public var mask:Null<Bounds> = null;

    public function new() {}

}

/**
 * A drag payload for a handle nobody drags in these tests.
 */
private class NoDrag {}

/**
 * A dock-shaped box: 200px along the axis, clipped to itself, sitting
 * between two 100px neighbours so both of its edges are seams. The handle
 * hugs one of them.
 */
private class HuggingHarness extends Model implements Render {

    final axis:Axis;

    final edge:HandleEdge;

    final probe:HuggingProbe;

    public function new(axis:Axis, edge:HandleEdge, probe:HuggingProbe) {
        super();
        this.axis = axis;
        this.edge = edge;
        this.probe = probe;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final axis = this.axis;
        final probe = this.probe;
        function neighbour() {
            return switch axis {
                case Horizontal: div().w(px(100.)).hFull();
                case Vertical: div().h(px(100.)).wFull();
            }
        }
        final row = div().flex();
        switch axis {
            case Horizontal: row.flexRow().w(px(400.)).h(px(100.));
            case Vertical: row.flexCol().h(px(400.)).w(px(100.));
        }
        final dock = div().relative().overflowHidden();
        switch axis {
            case Horizontal: dock.w(px(200.)).hFull();
            case Vertical: dock.h(px(200.)).wFull();
        }
        dock.child(
            ResizeHandle.resizeHandle('hugging', axis)
                .inside(edge)
                .withAppearance((handle, _, _) -> {
                    probe.edgeTold = true;
                    probe.edge = handle.edge();
                    // A hairline filling the handle's content box, the way a
                    // styled divider rests.
                    final line = div().flexNone();
                    switch handle.axis() {
                        case Horizontal: line.w(px(1.)).hFull();
                        case Vertical: line.h(px(1.)).wFull();
                    }
                    line.onPrepaint((bounds, window, _) -> {
                        probe.line = bounds;
                        probe.mask = window.contentMask().bounds;
                    });
                    return line.intoAnyElement();
                })
        );
        return row
            .child(neighbour())
            .child(dock)
            .child(neighbour());
    }

}

/**
 * The payload a caller drags a handle with.
 */
private class Resize {

    public function new() {}

}

private class ResizeView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new gpui.Empty();
    }

}

/**
 * What the listeners a caller put on a handle, and on its container, heard.
 */
private class Heard {

    public var containerHovered:Null<Bool> = null;

    public var handleHovered:Null<Bool> = null;

    public var doubleClicks:Int = 0;

    public final dragMoves:Array<Float> = [];

    /** Every state the appearance was drawn in, repeats collapsed. */
    public final states:Array<ResizeHandleState> = [];

    public function new() {}

}

/**
 * A 200px container whose trailing edge a handle hugs, listened to the way
 * an application's own sidebar would be.
 */
private class CallerHarness extends Model implements Render {

    final heard:Heard;

    public function new(heard:Heard) {
        super();
        this.heard = heard;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final heard = this.heard;
        final handle = ResizeHandle.resizeHandle('edge', Axis.Horizontal)
            .inside(Trailing)
            .withAppearance((handle, _, _) -> {
                final states = heard.states;
                if (states.length == 0 || states[states.length - 1] != handle.state()) {
                    states.push(handle.state());
                }
                return null;
            })
            .onDrag(new Resize(), (_, _, _, cx) -> cx.newEntity((_:Context<ResizeView>) -> new ResizeView()));
        handle.base
            .onHover((hovered, _, _) -> heard.handleHovered = hovered)
            .onDoubleClick((_, _, _) -> heard.doubleClicks = heard.doubleClicks + 1);
        return div().w(px(400.)).h(px(100.)).child(
            div()
                .id('container')
                .relative()
                .w(px(200.))
                .hFull()
                .onHover((hovered, _, _) -> heard.containerHovered = hovered)
                .onDragMove(Resize, (event:DragMoveEvent<Resize>, _, _) -> heard.dragMoves.push(event.event.position.x))
                .child(handle)
        );
    }

}

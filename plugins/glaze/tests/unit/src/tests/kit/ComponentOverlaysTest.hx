// Ported from gpui-kit 0.8.1: crates/component/src/popover.rs, tooltip.rs and hover_card.rs (tests),
// crates/kit/tests/integration/components.rs and controls.rs (the popover and hover card tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Anchor;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.StyleBuilder;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.Popup as BasePopup;
import glaze.kit.base.Root;
import glaze.Modifiers;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.kit.WindowState;
import glaze.kit.button.Button;
import glaze.kit.popover.Popover;
import tests.kit.BaseOverlaysTest.OverlayProbe;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.tooltip.Tooltip.ManagedTooltip;

/**
 * The tests of gpui-component's overlays: `popover.rs`, `tooltip.rs` and
 * `hover_card.rs`, and the popover and hover card tests of gpui-kit's
 * integration tests.
 *
 * Element bounds are read with `OverlayProbe` (Rust `debug_selector` /
 * `debug_bounds`).
 */
class ComponentOverlaysTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        OverlayProbe.reset();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        OverlayProbe.reset();
        ceramic.App.app.flushImmediate();
    }

    function open<V:Model & Render>(build:(Window, Context<V>) -> V, width:Float = 1920, height:Float = 1080):{view:Entity<V>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, build, width, height);
        contexts.push(opened.cx);
        return opened;
    }

    /** A window whose kit `Root` hosts the view `build` returns. */
    function openInRoot<V:Model & Render>(build:(Window, App) -> Entity<V>, width:Float = 1920, height:Float = 1080):{view:Entity<V>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowRoot(app, dispatcher, build, width, height);
        contexts.push(opened.cx);
        return opened;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    static function bounds(cx:VisualTestContext, selector:String):Null<Bounds> {
        return OverlayProbe.debugBounds(cx.window, selector);
    }

/// popover.rs

    function testPopoverBuilderChaining() {
        final popover = Popover.component('test')
            .anchor(Anchor.BottomCenter)
            .mouseButton(MouseButton.Right)
            .defaultOpen(true)
            .appearance(false)
            .overlayClosable(false);
        assertEquals(Anchor.BottomCenter, @:privateAccess popover.anchorProp);
        assertEquals(MouseButton.Right, @:privateAccess popover.mouseButtonProp);
        assertTrue(@:privateAccess popover.defaultOpenProp);
        assertFalse(@:privateAccess popover.appearanceProp);
        assertFalse(@:privateAccess popover.overlayClosableProp);
    }

    function testResolvedCornerTopPositions() {
        final bounds = new Bounds(new Point(100., 100.), new Size(200., 50.));
        for (entry in [
            {anchor: Anchor.TopLeft, x: 100., y: 100.},
            {anchor: Anchor.TopCenter, x: 200., y: 100.},
            {anchor: Anchor.TopRight, x: 300., y: 100.},
            {anchor: Anchor.BottomLeft, x: 100., y: 50.},
            {anchor: Anchor.BottomCenter, x: 200., y: 50.},
            {anchor: Anchor.BottomRight, x: 300., y: 50.}
        ]) {
            final pos = BasePopup.resolvedCorner(entry.anchor, bounds);
            assertEquals(entry.x, pos.x);
            assertEquals(entry.y, pos.y);
        }
    }

    function testAnchorAndOffsetPositionTheSurfaceOnEachTriggerEdge() {
        final opened = open((_, _) -> new AnchorHarness(Anchor.TopLeft, null, new Point(200., 200.), false));
        final cx = opened.cx;
        draw(cx);
        draw(cx);
        // Legacy TopLeft means below the trigger, including the default 0.25rem gap.
        final legacy = bounds(cx, 'positioned-content');
        assertEquals(200., legacy.left());
        assertEquals(244., legacy.top());

        for (entry in [
            {side: Anchor.BottomLeft, x: 200., y: 128.},
            {side: Anchor.BottomCenter, x: 190., y: 128.},
            {side: Anchor.BottomRight, x: 180., y: 128.},
            {side: Anchor.TopLeft, x: 200., y: 252.},
            {side: Anchor.TopCenter, x: 190., y: 252.},
            {side: Anchor.TopRight, x: 180., y: 252.},
            {side: Anchor.RightCenter, x: 128., y: 190.},
            {side: Anchor.LeftCenter, x: 252., y: 190.}
        ]) {
            cx.update((window, cx) -> {
                opened.view.update(cx, (view, cx) -> {
                    view.anchor = entry.side;
                    view.offset = px(12.);
                    cx.notify();
                });
                window.draw();
            });
            assertTrue(bounds(cx, 'positioned-content').origin.equals(new Point(entry.x, entry.y)), 'anchor ${entry.side}: ${bounds(cx, 'positioned-content').origin}');
        }
        // Current-frame trigger bounds must be used after the owner moves.
        cx.update((window, cx) -> {
            opened.view.update(cx, (view, cx) -> {
                view.origin = new Point(260., 240.);
                cx.notify();
            });
            window.draw();
        });
        assertTrue(bounds(cx, 'positioned-content').origin.equals(new Point(312., 230.)));
    }

    /**
     * `triggerStyle` styles the container the parent lays out and the popup
     * is anchored to.
     */
    function testTriggerStyleIsAppliedToTheTriggerContainer() {
        final opened = open((_, _) -> new TriggerStyleHarness());
        final cx = opened.cx;
        draw(cx);
        draw(cx);
        // Unstyled: the container wraps the 40px trigger, so the content's right
        // edge meets the trigger's right edge at 140px.
        assertTrue(bounds(cx, 'styled-content').origin.equals(new Point(120., 140.)));

        cx.update((window, cx) -> {
            opened.view.update(cx, (view, cx) -> {
                view.styled = true;
                cx.notify();
            });
            window.draw();
        });
        draw(cx);
        // `wFull` stretches the container across the 200px row, and the popup
        // follows the container's right edge at 300px.
        assertTrue(bounds(cx, 'styled-content').origin.equals(new Point(280., 140.)));
    }

    function testArrowReservesSpaceWithoutChangingAnchorAlignment() {
        final opened = open((_, _) -> new AnchorHarness(Anchor.TopLeft, px(12.), new Point(200., 8.), true));
        final cx = opened.cx;
        draw(cx);
        draw(cx);
        // Bottom edge 48 + tip gap 12 + arrow depth 6.
        assertTrue(bounds(cx, 'positioned-content').origin.equals(new Point(200., 66.)));
        cx.update((window, cx) -> {
            opened.view.update(cx, (view, cx) -> {
                view.anchor = Anchor.TopRight;
                view.arrow = false;
                cx.notify();
            });
            window.draw();
        });
        assertTrue(bounds(cx, 'positioned-content').origin.equals(new Point(180., 60.)));
    }

    function testAnchorDoesNotFlipWhenOffsetOrArrowIsEnabled() {
        final cx = open((_, _) -> new AnchorHarness(Anchor.BottomCenter, px(12.), new Point(200., 8.), true)).cx;
        draw(cx);
        draw(cx);
        // Clamp to the window margin instead of flipping below the trigger.
        assertEquals(8., bounds(cx, 'positioned-content').top());
    }

    function testArrowAlignmentUsesTheAnchorInsteadOfTriggerCenter() {
        final trigger = new Bounds(new Point(120., 120.), new Size(40., 20.));
        for (entry in [
            {anchor: Anchor.TopLeft, side: Placement.Bottom, target: new Point(120., 140.)},
            {anchor: Anchor.TopCenter, side: Placement.Bottom, target: new Point(140., 140.)},
            {anchor: Anchor.TopRight, side: Placement.Bottom, target: new Point(160., 140.)},
            {anchor: Anchor.BottomLeft, side: Placement.Top, target: new Point(120., 120.)},
            {anchor: Anchor.BottomCenter, side: Placement.Top, target: new Point(140., 120.)},
            {anchor: Anchor.BottomRight, side: Placement.Top, target: new Point(160., 120.)},
            {anchor: Anchor.LeftCenter, side: Placement.Right, target: new Point(160., 130.)},
            {anchor: Anchor.RightCenter, side: Placement.Left, target: new Point(120., 130.)}
        ]) {
            final resolved = @:privateAccess Popover.arrowAnchor(entry.anchor, trigger);
            assertEquals(entry.side, resolved.side);
            assertTrue(resolved.point.equals(entry.target));
        }
    }

    function testArrowsPointTowardTheTriggerOnEveryResolvedSide() {
        final surface = new Bounds(new Point(100., 100.), new Size(80., 60.));
        for (entry in [
            {side: Placement.Bottom, trigger: new Bounds(new Point(120., 50.), new Size(40., 20.)), tip: new Point(140., 94.)},
            {side: Placement.Top, trigger: new Bounds(new Point(120., 180.), new Size(40., 20.)), tip: new Point(140., 166.)},
            {side: Placement.Right, trigger: new Bounds(new Point(40., 120.), new Size(40., 20.)), tip: new Point(94., 130.)},
            {side: Placement.Left, trigger: new Bounds(new Point(200., 120.), new Size(40., 20.)), tip: new Point(186., 130.)}
        ]) {
            assertTrue(@:privateAccess Popover.arrowPoints(surface, entry.trigger, entry.side, 6., 4.)[1].equals(entry.tip));
        }
        final clamped = @:privateAccess Popover.arrowPoints(surface, new Bounds(new Point(0., 50.), new Size(20., 20.)), Placement.Bottom, 6., 4.);
        assertTrue(clamped[0].equals(new Point(104., 100.)));
        assertTrue(clamped[1].equals(new Point(110., 94.)));
    }

    function testArrowJoinCoversBothSidesOfTheSurfaceEdge() {
        final surface = new Bounds(new Point(100., 100.), new Size(80., 60.));
        final trigger = new Bounds(new Point(120., 120.), new Size(40., 20.));
        for (entry in [
            {side: Placement.Bottom, expected: new Bounds(new Point(135., 99.), new Size(10., 2.))},
            {side: Placement.Top, expected: new Bounds(new Point(135., 159.), new Size(10., 2.))},
            {side: Placement.Right, expected: new Bounds(new Point(99., 125.), new Size(2., 10.))},
            {side: Placement.Left, expected: new Bounds(new Point(179., 125.), new Size(2., 10.))}
        ]) {
            final points = @:privateAccess Popover.arrowPoints(surface, trigger, entry.side, 6., 4.);
            assertTrue(@:privateAccess Popover.arrowJoinBounds(points, entry.side, 1.).equals(entry.expected));
        }
    }

    function testPointerOpenAndOutsideDismissUseTheBasePopupHost() {
        app.update(cx -> {
            glaze.kit.base.GlobalState.init(cx);
            glaze.kit.theme.Theme.init(cx);
            Popover.bindKeys(cx);
        });
        final changes:Array<Bool> = [];
        final cx = open((_, _) -> new ScriptView((_, _) -> Popover.component('runtime-popover')
            .trigger(Button.component('runtime-trigger').label('Open').size(px(100.)))
            .content((_, _, _) -> new OverlayProbe('runtime-popover-content', div().size(px(40.))))
            .onOpenChange((open, _, _) -> changes.push(open)))).cx;
        draw(cx);

        cx.simulateClick(new Point(20., 20.));
        draw(cx);
        assertTrue(bounds(cx, 'runtime-popover-content') != null);

        cx.simulateClick(new Point(300., 300.));
        draw(cx);
        assertTrue(bounds(cx, 'runtime-popover-content') == null);
        // A change callback reports state transitions, not redundant dismissal
        // requests. The base host may see both paths, but only the first closes.
        assertEquals('[true,false]', haxe.Json.stringify(changes));
    }

    function testDefaultOpenIsForwardedToTheBasePopover() {
        app.update(cx -> {
            glaze.kit.base.GlobalState.init(cx);
            glaze.kit.theme.Theme.init(cx);
            Popover.bindKeys(cx);
        });
        final cx = open((_, _) -> new ScriptView((_, _) -> Popover.component('default-open-popover')
            .defaultOpen(true)
            .trigger(Button.component('default-open-trigger').label('Open'))
            .child(new OverlayProbe('default-open-content', div().size(px(40.)))))).cx;
        draw(cx);
        draw(cx);
        assertTrue(bounds(cx, 'default-open-content') != null);
    }

    /**
     * A dropdown that reused one animation key across opens would play its
     * enter motion the first time and then appear already settled on every
     * open after that.
     */
    function testTheEnterMotionStartsOverEveryTimeTheDropdownOpens() {
        final opened = open((_, _) -> new DropdownHarness());
        final cx = opened.cx;

        draw(cx);
        final opening = bounds(cx, 'surface').origin;

        // Rust sleeps on the wall clock; the port's animations read the
        // executor clock.
        BaseOverlaysTest.advanceClock(cx, 0.15 * 4);
        draw(cx);
        final settled = bounds(cx, 'surface').origin;
        assertTrue(opening.y < settled.y, 'the surface should slide down into place, from $opening to $settled');

        for (open in [false, true]) {
            cx.update((window, cx) -> {
                opened.view.update(cx, (view, cx) -> {
                    view.open = open;
                    cx.notify();
                });
                window.draw();
            });
        }

        final reopening = bounds(cx, 'surface').origin;
        assertTrue(reopening.y < settled.y, 'reopening should start the motion over at $opening rather than showing a settled surface, but the first frame was already at $reopening');
    }


/// tooltip.rs

    // Distinct scene markers let assertions observe retained tooltip output
    // without requiring its renderer to run on every frame.
    static final TOOLTIP_COLORS:Array<Int> = [0x7a135e, 0x136b7a];

    static function tooltipPainted(cx:VisualTestContext, index:Int):Bool {
        final marker = rgb(TOOLTIP_COLORS[index]).toHsla();
        for (quad in cx.window.renderedScene().quads) {
            if (quad.backgroundTag == 0
                && Math.abs(quad.backgroundSolidH - marker.h) < 1e-4
                && Math.abs(quad.backgroundSolidS - marker.s) < 1e-4
                && Math.abs(quad.backgroundSolidL - marker.l) < 1e-4
                && Math.abs(quad.backgroundSolidA - marker.a) < 1e-4) {
                return true;
            }
        }
        return false;
    }

    function assertTooltipPainted(cx:VisualTestContext, index:Int, shown:Bool):Void {
        tooltipDraw(cx);
        assertEquals(shown, tooltipPainted(cx, index), 'tooltip $index visibility in the rendered scene');
    }

    /** Rust `draw`: `window.draw(cx)` (without clearing). */
    static function tooltipDraw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    /** Lets any show delay or grace period run out, then draws. */
    static function wait(cx:VisualTestContext):Void {
        BaseOverlaysTest.advanceClock(cx, 1.);
        cx.runUntilParked();
        tooltipDraw(cx);
    }

    /** Presses at `at` and releases a pixel away, as most real clicks do. */
    static function clickWithDrift(cx:VisualTestContext, at:Point):Void {
        final drift = new Point(at.x + 1., at.y);
        cx.simulateMouseDown(at, Left);
        cx.simulateMouseMove(drift, Left);
        cx.simulateMouseUp(drift, Left);
    }

    function openRoot<V:Model & Render>(view:Entity<V>):VisualTestContext {
        app.update(cx -> {
            // These tests cover tooltip lifetime, not intermediate fade frames.
            cx.setReduceMotion(true);
        });
        final cx = openInRoot((window, rootCx) -> view).cx;
        tooltipDraw(cx);
        return cx;
    }

    function openProbe(removesOnClick:Bool, builds:Array<Int>):{cx:VisualTestContext, probe:Entity<TooltipProbe>} {
        final probe = app.newEntity((_:Context<TooltipProbe>) -> new TooltipProbe(removesOnClick, builds));
        return {cx: openRoot(probe), probe: probe};
    }

    function openAdjacentTriggers():{cx:VisualTestContext, probe:Entity<AdjacentTriggers>} {
        final probe = app.newEntity((_:Context<AdjacentTriggers>) -> new AdjacentTriggers());
        return {cx: openRoot(probe), probe: probe};
    }

    function assertTooltipShown(cx:VisualTestContext, index:Int):Void {
        assertTooltipPainted(cx, index, true);
        assertTooltipPainted(cx, 1 - index, false);
    }

    function testTooltipsSwitchInBothDirections() {
        final opened = openAdjacentTriggers();
        final cx = opened.cx;
        var step = 0;
        for (index in [0, 1, 0]) {
            final at = new Point(50. + index * 100., 25.);
            cx.simulateMouseMove(at);
            if (step > 0) {
                tooltipDraw(cx);
                assertTooltipShown(cx, index);
            }
            wait(cx);
            assertTooltipShown(cx, index);
            // Rebuilding the triggers must preserve ownership for hover-leave.
            cx.update((_, cx) -> opened.probe.update(cx, (_, cx) -> cx.notify()));
            tooltipDraw(cx);
            step++;
        }
        cx.simulateMouseMove(new Point(300., 300.));
        wait(cx);
        assertTooltipPainted(cx, 0, false);
        assertTooltipPainted(cx, 1, false);
    }

    function testLeavingATriggerDoesNotCancelTheNextTooltipDelay() {
        for (pair in [[0, 1], [1, 0]]) {
            final source = pair[0];
            final destination = pair[1];
            final cx = openAdjacentTriggers().cx;
            cx.simulateMouseMove(new Point(50. + source * 100., 25.));
            BaseOverlaysTest.advanceClock(cx, 0.1);
            cx.runUntilParked();
            cx.simulateMouseMove(new Point(50. + destination * 100., 25.));
            wait(cx);
            assertTooltipShown(cx, destination);
        }
    }

    /**
     * A press dismisses the tooltip, and it stays dismissed while the
     * pointer stays on the trigger; leaving and coming back shows it again.
     */
    function testAPressDismissesTheTooltipUntilThePointerLeaves() {
        final builds = [0];
        final cx = openProbe(false, builds).cx;
        final at = new Point(50., 25.);
        cx.simulateMouseMove(at);
        wait(cx);
        assertTrue(builds[0] > 0, 'the hovered trigger shows its tooltip');

        // Hover reads false while the button is held, so the move after the
        // release is a hover-enter that must not show the tooltip.
        clickWithDrift(cx, at);
        cx.simulateMouseMove(new Point(52., 25.));
        wait(cx);
        assertTooltipPainted(cx, 0, false);

        cx.simulateMouseMove(new Point(300., 300.));
        wait(cx);
        cx.simulateMouseMove(at);
        wait(cx);
        assertTooltipPainted(cx, 0, true);
    }

    /**
     * A pointer move that lands between the release and the next frame is
     * dispatched to the old frame, where the trigger is still hovered, so it
     * used to request the tooltip again.
     */
    function testClickingATriggerAwayDoesNotLeaveItsTooltip() {
        final builds = [0];
        final cx = openProbe(true, builds).cx;

        final at = new Point(50., 25.);
        cx.simulateMouseMove(at);
        tooltipDraw(cx);
        wait(cx);
        tooltipDraw(cx);
        assertTrue(builds[0] > 0, 'the hovered trigger shows its tooltip');

        // Press, drift a pixel while held, release, and drift again before
        // the next frame is drawn.
        cx.simulateMouseDown(at, Left);
        final drift = new Point(51., 25.);
        cx.simulateMouseMove(drift, Left);
        // One update, so no frame is drawn between the two.
        cx.update((window, cx) -> {
            window.dispatchEvent(new MouseUpEvent(Left, drift, Modifiers.none(), 1), cx);
            window.dispatchEvent(new MouseMoveEvent(new Point(52., 25.), null, Modifiers.none()), cx);
        });
        tooltipDraw(cx);
        wait(cx);

        final before = builds[0];
        tooltipDraw(cx);
        assertEquals(before, builds[0], 'no tooltip may be shown for a trigger the click removed');
    }

    /**
     * A trigger that a click removed never reports a hover-leave, so the
     * press must end when the pointer moves away, or a trigger later shown
     * at the same bounds would lose its tooltip.
     */
    function testAPressOnARemovedTriggerEndsWhenThePointerMovesAway() {
        final builds = [0];
        final opened = openProbe(true, builds);
        final cx = opened.cx;
        final at = new Point(50., 25.);
        cx.simulateMouseMove(at);
        wait(cx);

        cx.simulateClick(at);
        wait(cx);
        cx.simulateMouseMove(new Point(300., 300.));
        wait(cx);

        cx.update((_, cx) -> opened.probe.update(cx, (probe, cx) -> {
            probe.shown = true;
            cx.notify();
        }));
        wait(cx);
        final before = builds[0];
        cx.simulateMouseMove(at);
        wait(cx);
        tooltipDraw(cx);
        assertTrue(builds[0] > before, 'the trigger shown again has its tooltip');
    }

    function openButtons(shown:Array<Bool>, delay:Float):{cx:VisualTestContext, buttons:Entity<TooltipButtons>, builds:Array<Int>} {
        app.update(cx -> {
            // These tests cover tooltip lifetime, not intermediate fade frames.
            cx.setReduceMotion(true);
        });
        final buttons = app.newEntity((_:Context<TooltipButtons>) -> new TooltipButtons(shown, delay));
        final cx = openInRoot((window, rootCx) -> {
            final content = rootCx.newEntity((_:Context<CachedButtons>) -> new CachedButtons(buttons));
            return content;
        }).cx;
        tooltipDraw(cx);
        final builds = [0];
        cx.update((window, cx) -> {
            // Observe the real Button's overlay without changing Base's public
            // API or adding test-only markup to the production Tooltip.
            WindowState.tooltipOverlay(window, cx).update(cx, (overlay, _) -> {
                overlay.renderWith((view, transition, window, cx) -> {
                    builds[0]++;
                    return div()
                        .bg(rgb(TOOLTIP_COLORS[0]))
                        .child(@:privateAccess glaze.kit.tooltip.Tooltip.renderTooltip(view, transition, window, cx))
                        .intoAnyElement();
                });
            });
        });
        return {cx: cx, buttons: buttons, builds: builds};
    }

    function testRemovingButtonHidesVisibleTooltip() {
        final opened = openButtons([true, false], 0.);
        final cx = opened.cx;
        cx.simulateMouseMove(new Point(50., 25.));
        wait(cx);
        assertTooltipPainted(cx, 0, true);
        // A redraw reusing the cached button subtree preserves the owner.
        tooltipDraw(cx);
        assertTooltipPainted(cx, 0, true);
        cx.update((_, cx) -> opened.buttons.update(cx, (buttons, cx) -> {
            buttons.shown[0] = false;
            cx.notify();
        }));
        tooltipDraw(cx);
        cx.runUntilParked();
        assertTooltipPainted(cx, 0, false);
    }

    function testRemovingButtonCancelsPendingTooltip() {
        final opened = openButtons([true, false], 0.5);
        final cx = opened.cx;
        cx.simulateMouseMove(new Point(50., 25.));
        tooltipDraw(cx);
        // Finish the hover frame and drain its deferred cleanup before removal,
        // without advancing the pending tooltip's show delay.
        cx.runUntilParked();
        assertEquals(0, opened.builds[0], 'tooltip is still pending');
        cx.update((_, cx) -> opened.buttons.update(cx, (buttons, cx) -> {
            buttons.shown[0] = false;
            cx.notify();
        }));
        tooltipDraw(cx);
        cx.runUntilParked();
        wait(cx);
        assertEquals(0, opened.builds[0], 'a removed trigger must never build its tooltip');
        assertTooltipPainted(cx, 0, false);
    }

    function testPendingButtonShowsAfterDeferredWorkDrains() {
        final opened = openButtons([true, false], 0.5);
        final cx = opened.cx;
        cx.simulateMouseMove(new Point(50., 25.));
        tooltipDraw(cx);
        cx.runUntilParked();
        assertEquals(0, opened.builds[0], 'tooltip is still pending');
        wait(cx);
        assertTrue(opened.builds[0] > 0, 'a surviving trigger builds its delayed tooltip');
        assertTooltipPainted(cx, 0, true);
    }

    function testRemovingOldButtonPreservesNewTooltip() {
        final opened = openButtons([true, true], 0.);
        final cx = opened.cx;
        cx.simulateMouseMove(new Point(50., 25.));
        wait(cx);
        cx.simulateMouseMove(new Point(150., 25.));
        wait(cx);
        assertTooltipPainted(cx, 0, true);
        cx.update((_, cx) -> opened.buttons.update(cx, (buttons, cx) -> {
            buttons.shown[0] = false;
            cx.notify();
        }));
        tooltipDraw(cx);
        cx.runUntilParked();
        assertTooltipPainted(cx, 0, true);
    }


/// hover_card.rs

    /**
     * `triggerStyle` styles the container the parent lays out and the card
     * is anchored to.
     */
    function testHoverCardTriggerStyleIsAppliedToTheTriggerContainer() {
        final opened = open((_, _) -> new HoverCardTriggerStyleHarness());
        final cx = opened.cx;
        draw(cx);
        cx.simulateMouseMove(new Point(110., 110.));
        cx.runUntilParked();
        draw(cx);
        draw(cx);
        // Unstyled: the container wraps the 40px trigger, so the content's right
        // edge meets the trigger's right edge at 140px.
        assertEquals(140., bounds(cx, 'styled-content').topRight().x);

        cx.update((window, cx) -> {
            opened.view.update(cx, (view, cx) -> {
                view.styled = true;
                cx.notify();
            });
            window.draw();
            window.draw();
        });
        // `wFull` stretches the container across the 200px row, and the card
        // follows the container's right edge at 300px.
        assertEquals(300., bounds(cx, 'styled-content').topRight().x);
    }

/// crates/kit/tests/integration (components.rs, controls.rs)

    /**
     * `kit_controls_use_native_events_and_report_state`, the popover part:
     * a click on the trigger opens the content below it. (The disabled button
     * and text input parts belong to their own waves; the port has no test
     * query layer, the content is read through a probe.)
     */
    function testKitPopoverOpensBelowItsTriggerOnClick() {
        final cx = open((_, _) -> new ScriptView((_, _) -> div()
            .sizeFull()
            .flex()
            .flexCol()
            .gap4()
            .child(Popover.component('popover-host')
                .trigger(Button.component('open').label('Open'))
                .content((_, _, _) -> new OverlayProbe('popover-content', div().id('popover-content').w(px(120.)).h(px(50.)).child('Details')))))
        , 600, 500).cx;
        draw(cx);
        assertTrue(bounds(cx, 'popover-content') == null);
        cx.simulateClick(new Point(20., 10.));
        draw(cx);
        final content = bounds(cx, 'popover-content');
        assertTrue(content != null);
        // The trigger is a small button at the top left: the content opens below it.
        assertTrue(content.top() >= 20.);
    }

    /**
     * `popover_content_keeps_keyboard_activation_and_text_input`, without the
     * textarea (wave 6): Enter or Space on the focused trigger opens the
     * popover, Tab moves into it, the same key activates the inner button
     * without closing the popover, and Escape dismisses it and returns the
     * focus to the trigger.
     */
    function testPopoverContentKeepsKeyboardActivation() {
        for (activation in ['enter', 'space']) {
            final applied = [0];
            final trigger = app.update(cx -> cx.focusHandle());
            final apply = app.update(cx -> cx.focusHandle());
            // Rust `common::open_window` mounts the view in a gpui-kit `Root` (Tab, Shift-Tab).
            final view = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) -> Popover.component('keyboard-popover')
                .trigger(Button.component('keyboard-trigger').label('Compose').trackFocus(trigger))
                .content((_, _, _) -> new OverlayProbe('keyboard-content', div()
                    .id('keyboard-content')
                    .w(px(280.))
                    .flex()
                    .flexCol()
                    .gap2()
                    .child(Button.component('keyboard-apply').label('Apply').trackFocus(apply).onClick((_, _, _) -> applied[0]++))))));
            final cx = openInRoot((window, rootCx) -> view, 600, 500).cx;
            draw(cx);
            cx.update((window, cx) -> window.focusNext(cx));
            draw(cx);
            assertTrue(cx.update((window, _) -> trigger.isFocused(window)));
            press(cx, activation);
            assertTrue(bounds(cx, 'keyboard-content') != null);
            press(cx, 'tab');
            assertTrue(cx.update((window, _) -> apply.isFocused(window)), 'tab focuses the inner button, focused=' + cx.update((window, cx) -> window.focused(cx)));
            press(cx, activation);
            assertEquals(1, applied[0], '$activation activates the child');
            assertTrue(bounds(cx, 'keyboard-content') != null);

            press(cx, 'escape');
            assertTrue(bounds(cx, 'keyboard-content') == null);
            assertTrue(cx.update((window, _) -> trigger.isFocused(window)));
            assertEquals(1, applied[0], 'dismissal must not activate again');
        }
    }

    /** A key press (down and up), then a frame. */
    static function press(cx:VisualTestContext, key:String):Void {
        cx.update((window, cx) -> window.dispatchKeystroke(glaze.Keystroke.parse(key), cx));
        cx.simulateEvent(new glaze.KeyUpEvent(glaze.Keystroke.parse(key)));
        cx.runUntilParked();
        draw(cx);
    }

    /**
     * `real_hover_card_opens_and_closes_after_pointer_delays`.
     */
    function testRealHoverCardOpensAndClosesAfterPointerDelays() {
        final cx = open((_, _) -> new ScriptView((_, _) -> div().sizeFull().flex().flexCol().gap8().children([
            glaze.kit.hovercard.HoverCard.component('help')
                .openDelay(0.03)
                .closeDelay(0.02)
                .trigger(Button.component('help-trigger').label('Help'))
                .content((_, _, _) -> new OverlayProbe('help-content', div().id('help-content').w(px(100.)).h(px(40.)).child('Explanation'))),
            Button.component('away').label('Away').absolute().bottom0().right0()
        ])), 640, 480).cx;
        draw(cx);
        assertTrue(bounds(cx, 'help-content') == null);
        cx.simulateMouseMove(new Point(10., 10.));
        BaseOverlaysTest.advanceClock(cx, 0.1);
        draw(cx);
        draw(cx);
        assertTrue(bounds(cx, 'help-content') != null);
        cx.simulateMouseMove(new Point(630., 470.));
        BaseOverlaysTest.advanceClock(cx, 0.1);
        draw(cx);
        assertTrue(bounds(cx, 'help-content') == null);
    }

}

private class AnchorHarness extends Model implements Render {

    public var anchor:Anchor;

    public var offset:Null<Float>;

    public var origin:Point;

    public var arrow:Bool;

    public function new(anchor:Anchor, offset:Null<Float>, origin:Point, arrow:Bool) {
        super();
        this.anchor = anchor;
        this.offset = offset;
        this.origin = origin;
        this.arrow = arrow;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final popover = Popover.component('positioned-popover')
            .defaultOpen(true)
            .appearance(false)
            .arrow(arrow)
            .anchor(anchor);
        if (offset != null) popover.offset(offset);
        popover
            .trigger(Button.component('positioned-trigger').size(px(40.)))
            .child(new OverlayProbe('positioned-content', div().size(px(60.))));
        return div().sizeFull().child(
            div()
                .absolute()
                .left(px(origin.x))
                .top(px(origin.y))
                .child(popover)
        );
    }

}

private class TriggerStyleHarness extends Model implements Render {

    public var styled:Bool = false;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final popover = Popover.component('trigger-style-popover')
            .defaultOpen(true)
            .appearance(false)
            .offset(px(0.))
            .anchor(Anchor.TopRight);
        if (styled) popover.triggerStyle(new StyleBuilder().wFull().style());
        popover
            .trigger(Button.component('styled-trigger').size(px(40.)))
            .child(new OverlayProbe('styled-content', div().size(px(20.))));
        // Keep the trigger clear of the popup's window margin so the
        // content origin reflects only the trigger container's bounds.
        return div().sizeFull().child(
            hFlex()
                .absolute()
                .left(px(100.))
                .top(px(100.))
                .w(px(200.))
                .child(popover)
        );
    }

}

private class DropdownHarness extends Model implements Render {

    public var open:Bool = true;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final root = div().sizeFull();
        if (open) {
            root.child(@:privateAccess Popover.dropdownPopup(
                'dropdown',
                new Bounds(new Point(0., 100.), new Size(120., 30.)),
                // The probe fills the surface (Rust `debug_selector` on it)
                div().size(px(50.)).child(new OverlayProbe('surface', div().sizeFull())),
                cx.app
            ));
        }
        return root;
    }

}

/**
 * A trigger that removes itself when clicked, like a button that replaces
 * the view it sits in.
 */
private class TooltipProbe extends Model implements Render {

    public var shown:Bool = true;

    final removesOnClick:Bool;

    final builds:Array<Int>;

    public function new(removesOnClick:Bool, builds:Array<Int>) {
        super();
        this.removesOnClick = removesOnClick;
        this.builds = builds;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final builds = this.builds;
        final root = div().sizeFull();
        if (shown) {
            final listener:(glaze.ClickEvent, Window, App) -> Void = (cast cx : Context<TooltipProbe>).listener((this_, _, _, cx) -> {
                if (this_.removesOnClick) {
                    this_.shown = false;
                }
                cx.notify();
            });
            root.child(
                div()
                    .id('trigger')
                    .absolute()
                    .left(px(10.))
                    .top(px(10.))
                    .w(px(100.))
                    .h(px(30.))
                    .managedTooltip((_, cx) -> {
                        builds[0]++;
                        return (cx.newEntity((_:Context<glaze.kit.tooltip.Tooltip>) -> new glaze.kit.tooltip.Tooltip('tip').bg(rgb(0x7a135e))) : glaze.AnyView);
                    })
                    .onClick(listener)
            );
        }
        return root;
    }

}

private class AdjacentTriggers extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final colors = [0x7a135e, 0x136b7a];
        return div().sizeFull().children([for (index in 0...2) div()
            .id(glaze.ElementId.NamedInteger('trigger', index))
            .absolute()
            .left(px(10. + index * 100.))
            .top(px(10.))
            .w(px(100.))
            .h(px(30.))
            .managedTooltip((_, cx) -> (cx.newEntity((_:Context<glaze.kit.tooltip.Tooltip>) -> new glaze.kit.tooltip.Tooltip('tip').bg(rgb(colors[index]))) : glaze.AnyView))]);
    }

}

private class TooltipButtons extends Model implements Render {

    public final shown:Array<Bool>;

    final delay:Float;

    public function new(shown:Array<Bool>, delay:Float) {
        super();
        this.shown = shown;
        this.delay = delay;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final children:Array<IntoElement> = [];
        for (index in 0...2) {
            if (shown[index]) {
                children.push(Button.component(glaze.ElementId.NamedInteger('button', index))
                    .absolute()
                    .left(px(10. + index * 100.))
                    .top(px(10.))
                    .w(px(80.))
                    .h(px(30.))
                    .label(index == 0 ? 'A' : 'B')
                    .tooltip(index == 0 ? 'First' : 'Second')
                    .tooltipShowDelay(delay));
            }
        }
        return div().sizeFull().children(children);
    }

}

private class CachedButtons extends Model implements Render {

    final buttons:Entity<TooltipButtons>;

    public function new(buttons:Entity<TooltipButtons>) {
        super();
        this.buttons = buttons;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(buttons.cached(new StyleBuilder().sizeFull().style()));
    }

}

private class HoverCardTriggerStyleHarness extends Model implements Render {

    public var styled:Bool = false;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final card = glaze.kit.hovercard.HoverCard.component('trigger-style-hover-card')
            .appearance(false)
            .openDelay(0.)
            .anchor(Anchor.TopRight);
        if (styled) card.triggerStyle(new StyleBuilder().wFull().style());
        card
            .trigger(Button.component('styled-trigger').size(px(40.)))
            .child(new OverlayProbe('styled-content', div().size(px(20.))));
        // Keep the trigger clear of the popup's window margin so the
        // content position reflects only the trigger container's bounds.
        return div().sizeFull().child(
            hFlex()
                .absolute()
                .left(px(100.))
                .top(px(100.))
                .w(px(200.))
                .child(card)
        );
    }

}

// Ported from gpui-kit 0.8.1: crates/base/src/positioner.rs, popup.rs, popover.rs, tooltip.rs and
// hover_card.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Decorations;
import glaze.Decorations.Tiling;
import glaze.Edges;
import glaze.Element;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.RenderOnce;
import glaze.Size;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Base;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.GlobalState;
import glaze.kit.base.Popover;
import glaze.kit.base.Popover.PopoverState;
import glaze.kit.base.Popup;
import glaze.kit.base.Positioner;
import glaze.kit.base.Positioner.Align;
import glaze.kit.base.Positioner.PositionerStrategy;
import glaze.kit.base.Positioner.ResolvedPosition;
import glaze.kit.base.HoverCard;
import glaze.kit.base.Tooltip.TooltipDefaults;
import glaze.kit.base.Tooltip.TooltipOverlay;
import glaze.kit.base.Tooltip.TooltipRequest;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The tests of gpui-base's overlays: `positioner.rs`, `popup.rs`,
 * `popover.rs`, `tooltip.rs` and `hover_card.rs`.
 *
 * Rust reads element bounds through `debug_selector` / `debug_bounds` (the
 * bounds of the last drawn frame); the port records them with
 * `OverlayProbe`, an element wrapping the same `Div`, per frame.
 */
class BaseOverlaysTest extends TestCase {

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

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    /**
     * Rust `cx.executor().advance_clock(duration)` (seconds): runs the pending
     * tasks, then moves the clock timer by timer (`TestDispatcher.advanceClock`).
     */
    public static function advanceClock(cx:VisualTestContext, seconds:Float):Void {
        cx.advanceClock(seconds);
    }

/// positioner.rs

    static inline final MARGIN:Float = 4.;

    static function trigger(x:Float, y:Float, w:Float, h:Float):Bounds {
        return new Bounds(new Point(x, y), new Size(w, h));
    }

    static function viewport():Size {
        return new Size(500., 400.);
    }

    static function side(triggerBounds:Bounds, placement:Null<Placement>, align:Align, popup:Size):ResolvedPosition {
        return @:privateAccess Positioner.resolve(Side(triggerBounds, placement, align, 0.), popup, viewport(), Edges.all(MARGIN));
    }

    function testPrefersTheRequestedSideWhenItFits() {
        final position = side(trigger(200., 200., 40., 20.), Placement.Top, Center, new Size(80., 30.));
        assertEquals(Placement.Top, position.placement);
        assertEquals(200., position.bounds.bottom());
    }

    function testFlipsToTheOppositeSideWhenThePreferredSideDoesNotFit() {
        final position = side(trigger(200., 10., 40., 20.), Placement.Top, Center, new Size(80., 60.));
        assertEquals(Placement.Bottom, position.placement);
        assertEquals(30., position.bounds.top());
    }

    function testClampsIntoTheViewportWhileKeepingTheFlippedSide() {
        final position = side(trigger(480., 200., 40., 20.), Placement.Bottom, Center, new Size(120., 30.));
        assertEquals(Placement.Bottom, position.placement);
        assertEquals(viewport().width - MARGIN, position.bounds.right());
    }

    function testAlignmentSelectsTheLeadingCenterOrTrailingEdge() {
        final triggerBounds = trigger(200., 200., 100., 20.);
        final popup = new Size(40., 30.);
        final start = side(triggerBounds, Placement.Bottom, Start, popup);
        final center = side(triggerBounds, Placement.Bottom, Center, popup);
        final end = side(triggerBounds, Placement.Bottom, End, popup);
        assertEquals(200., start.bounds.left());
        assertEquals(230., center.bounds.left());
        assertEquals(260., end.bounds.left());
    }

    function testSideOffsetAddsAGapBetweenTriggerAndPopup() {
        final position = @:privateAccess Positioner.resolve(Side(trigger(200., 200., 40., 20.), Placement.Bottom, Center, 8.), new Size(40., 30.), viewport(), Edges.all(MARGIN));
        assertEquals(228., position.bounds.top());
    }

    function testCornerPositioningPlacesTheNamedCornerAndNeverReportsASide() {
        final position = @:privateAccess Positioner.resolve(Corner(Anchor.TopLeft, new Point(100., 100.)), new Size(40., 30.), viewport(), Edges.all(MARGIN));
        assertEquals(null, position.placement);
        assertTrue(position.bounds.origin.equals(new Point(100., 100.)));
    }

    function testCornerPositioningClampsButDoesNotFlip() {
        final position = @:privateAccess Positioner.resolve(Corner(Anchor.TopLeft, new Point(480., 390.)), new Size(40., 30.), viewport(), Edges.all(MARGIN));
        assertEquals(null, position.placement);
        assertEquals(viewport().width - MARGIN, position.bounds.right());
        assertEquals(viewport().height - MARGIN, position.bounds.bottom());
    }

    function testCornerPositionCanBeUpdatedWithoutRebuildingThePositioner() {
        final positioner = Positioner.corner(Anchor.TopLeft, new Point(10., 20.)).position(new Point(30., 40.));
        switch @:privateAccess positioner.strategy {
            case Corner(_, position):
                assertTrue(position.equals(new Point(30., 40.)));
            case _:
                fail('expected a corner strategy');
        }
    }

    /**
     * A tiled edge draws no shadow, so a popup may run right up to the
     * margin there; an untiled edge keeps the whole client inset as well.
     */
    function testFrameInsetsApplyTheClientInsetOnlyOnUntiledEdges() {
        final inset = 20.;
        assertTrue(@:privateAccess Positioner.frameInsets(Decorations.Server, inset).equals(new Edges()), 'a server-decorated window has no frame to keep clear of');
        assertTrue(@:privateAccess Positioner.frameInsets(Decorations.Client(Tiling.tiled()), inset).equals(new Edges()), 'a window tiled on every side draws no shadow padding');
        assertTrue(@:privateAccess Positioner.frameInsets(Decorations.Client(new Tiling(false, true, false, true)), inset).equals(new Edges(inset, inset, 0., 0.)));
    }

    /**
     * The bug this guards: a menu opened from a trigger near the right edge
     * of a tiled window was pushed inward by the client inset although no
     * shadow was drawn there, so it no longer lined up with its trigger.
     */
    function testClampingKeepsOnlyTheMarginOnATiledEdge() {
        final popup = new Size(120., 30.);
        final corner = Corner(Anchor.TopRight, new Point(viewport().width - 10., 100.));
        final margin = Edges.all(MARGIN);
        final inset = 20.;
        final tiled = @:privateAccess Positioner.resolve(corner, popup, viewport(), margin);
        assertEquals(viewport().width - 10., tiled.bounds.right());
        final untiled = @:privateAccess Positioner.resolve(corner, popup, viewport(), margin.map(margin -> margin + inset));
        assertEquals(viewport().width - MARGIN - inset, untiled.bounds.right());
    }

    // Migrated from the tooltip module when its private positioning logic was
    // merged into this one.
    static inline final WINDOW_MARGIN:Float = 4.;

    static function tooltipPlacement(triggerBounds:Bounds, popup:Size, viewport:Size, margin:Float, placement:Null<Placement>):{bounds:Bounds, placement:Placement} {
        final resolved = @:privateAccess Positioner.resolve(Side(triggerBounds, placement, Center, 0.), popup, viewport, Edges.all(margin));
        return {bounds: resolved.bounds, placement: resolved.placement};
    }

    function testPrefersAboveWhenSpaceAllows() {
        final position = tooltipPlacement(trigger(100., 80., 80., 24.), new Size(120., 30.), new Size(300., 200.), WINDOW_MARGIN, null);
        assertEquals(Placement.Top, position.placement);
        assertTrue(position.bounds.origin.equals(new Point(80., 50.)));
    }

    function testFlipsAndClampsOnEachAxis() {
        final top = tooltipPlacement(trigger(24., 4., 120., 32.), new Size(240., 32.), new Size(520., 260.), WINDOW_MARGIN, null);
        assertEquals(Placement.Bottom, top.placement);
        final right = tooltipPlacement(trigger(260., 60., 32., 32.), new Size(120., 30.), new Size(300., 200.), WINDOW_MARGIN, Placement.Right);
        assertEquals(Placement.Left, right.placement);
        final leftEdge = tooltipPlacement(trigger(4., 80., 24., 24.), new Size(120., 30.), new Size(300., 200.), WINDOW_MARGIN, null);
        assertEquals(WINDOW_MARGIN, leftEdge.bounds.left());
    }

    function testPlacesTooltipToTheRight() {
        final triggerBounds = trigger(20., 60., 32., 32.);
        final position = tooltipPlacement(triggerBounds, new Size(120., 30.), new Size(300., 200.), WINDOW_MARGIN, Placement.Right);
        assertEquals(Placement.Right, position.placement);
        assertEquals(triggerBounds.right(), position.bounds.left());
        assertEquals(triggerBounds.center().y, position.bounds.center().y);
    }

    function testRightPlacementClampsVerticalEdges() {
        final triggerBounds = trigger(20., 2., 32., 20.);
        final position = tooltipPlacement(triggerBounds, new Size(120., 40.), new Size(300., 200.), WINDOW_MARGIN, Placement.Right);
        assertEquals(Placement.Right, position.placement);
        assertEquals(WINDOW_MARGIN, position.bounds.top());
        assertEquals(triggerBounds.right(), position.bounds.left());
    }

    function testUsesLargerSideWhenNeitherVerticalSideFits() {
        final position = tooltipPlacement(trigger(120., 20., 40., 20.), new Size(160., 120.), new Size(300., 100.), WINDOW_MARGIN, null);
        assertEquals(Placement.Bottom, position.placement);
        assertEquals(WINDOW_MARGIN, position.bounds.top());
        assertEquals(60., position.bounds.left());
    }

/// popup.rs

    function testResolvedCornerPreservesExistingAnchorMath() {
        final bounds = new Bounds(new Point(100., 100.), new Size(200., 50.));
        assertTrue(Popup.resolvedCorner(Anchor.TopCenter, bounds).equals(new Point(200., 100.)));
        assertTrue(Popup.resolvedCorner(Anchor.BottomRight, bounds).equals(new Point(300., 50.)));
    }


    /**
     * A caller that styles its own surface (a hover card, a dropdown) does
     * not have to remember to block the mouse. The host does it, so the panel
     * a popup covers stops reacting to a pointer that is over the popup.
     */
    function testThePopupSurfaceBlocksThePanelItCovers() {
        var backgroundHovered = false;
        var contentHovered = false;
        final cx = open((_, _) -> new ScriptView((_, _) -> div()
            .relative()
            .size(px(200.))
            .child(div().id('background').absolute().sizeFull().onMouseMove((_, _, _) -> backgroundHovered = true))
            .child(new Popup('popup', div().size(px(100.))).content(div()
                .id('content')
                .size(px(40.))
                .onMouseMove((_, _, _) -> contentHovered = true))))).cx;
        draw(cx);
        draw(cx);

        cx.simulateMouseMove(new Point(20., 110.));
        assertFalse(backgroundHovered);
        // The surface blocks what is behind it, not its own content: the
        // hitbox goes in ahead of the children, never over them.
        assertTrue(contentHovered);

        // The same pointer outside the surface still reaches the panel, so the
        // assertion above is about occlusion and not a dead listener.
        cx.simulateMouseMove(new Point(150., 180.));
        assertTrue(backgroundHovered);
    }

    /**
     * A closed popup notes its trigger's bounds without asking for another
     * frame: a list of rows holding closed popups is not drawn again for
     * each row that shows. Opened, it places its content at once.
     */
    function testAClosedPopupAsksForNoFrameAndOpensAtOnce() {
        final opened = open((_, _) -> new ClosedHarness());
        final cx = opened.cx;
        cx.update((window, cx) -> {
            window.draw();
            assertEquals(0, window.simulateNextFrame(cx), 'no frame was asked for');
        });

        opened.view.update(app, (harness, cx) -> {
            harness.open = true;
            cx.notify();
        });
        draw(cx);
        final bounds = OverlayProbe.debugBounds(cx.window, 'popup-content');
        assertTrue(bounds != null && bounds.size.equals(new Size(20., 20.)));
    }

    function testTriggerCaptureEnablesDeferredContentOnTheNextFrame() {
        final cx = open((_, _) -> new ScriptView((_, _) -> new Popup('popup', new OverlayProbe('popup-trigger', div().size(px(100.))))
            .content(new OverlayProbe('popup-content', div().size(px(20.)))))).cx;
        draw(cx);
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'popup-trigger').size.equals(new Size(100., 100.)));
        assertTrue(OverlayProbe.debugBounds(cx.window, 'popup-content').size.equals(new Size(20., 20.)));
    }

/// popover.rs

    /**
     * Popover state lives in element state, which is collected as soon as it
     * stops being rendered. A registration that outlived it would leave the
     * application believing a popup is open for the rest of the session.
     */
    function testAStateDroppedWhileOpenClosesTheDeferredContext() {
        final state = app.update(cx -> {
            GlobalState.init(cx);
            final state = cx.newEntity((stateCx:Context<PopoverState>) -> new PopoverState(false, stateCx.app));
            state.update(cx, (state, cx) -> state.setOpen(true, cx.app));
            assertTrue(GlobalState.isInDeferredContext(cx));
            return state;
        });

        app.update(_ -> (state : PopoverState).destroy());
        app.update(cx -> assertFalse(GlobalState.isInDeferredContext(cx)));
    }

    function testOpenStateRegistersAndUnregistersDeferredContext() {
        app.update(cx -> {
            GlobalState.init(cx);
            final state = cx.newEntity((stateCx:Context<PopoverState>) -> new PopoverState(false, stateCx.app));

            state.update(cx, (state, cx) -> state.setOpen(true, cx.app));
            assertTrue((state : PopoverState).isOpen());
            assertTrue(GlobalState.isInDeferredContext(cx));

            state.update(cx, (state, cx) -> state.setOpen(false, cx.app));
            assertFalse((state : PopoverState).isOpen());
            assertFalse(GlobalState.isInDeferredContext(cx));
        });
    }

    function popoverHarness(changes:Array<Bool>, defaultOpen:Bool):VisualTestContext {
        return open((_, _) -> new ScriptView((_, _) -> new Popover('base-popover')
            .defaultOpen(defaultOpen)
            .triggerWith((_, _, _) -> div().child('Open').intoAnyElement())
            .content((_, _, _) -> new OverlayProbe('base-popover-content', div().size(px(40.))))
            .onOpenChange((open, _, _) -> changes.push(open)))).cx;
    }

    function testUnstyledPopoverOwnsPointerOpenAndOutsideDismiss() {
        app.update(cx -> Base.init(cx));
        final changes = [];
        final cx = popoverHarness(changes, false);
        draw(cx);

        cx.simulateClick(new Point(20., 10.));
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'base-popover-content') != null);

        cx.simulateClick(new Point(300., 300.));
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'base-popover-content') == null);
        assertEquals('[true,false]', haxe.Json.stringify(changes));
    }

    function testDefaultOpenRendersContentWithoutActivation() {
        app.update(cx -> Base.init(cx));
        final cx = popoverHarness([], true);
        draw(cx);
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'base-popover-content') != null);
    }

    function testAnOpenPopoverTellsItsTriggerItIsOpenNotSelected() {
        app.update(cx -> Base.init(cx));
        final calls:Array<String> = [];
        final cx = open((_, _) -> new ScriptView((_, _) -> new Popover('recording-popover')
            .trigger(new RecordingTrigger(calls))
            .content((_, _, _) -> div().size(px(40.))))).cx;
        draw(cx);
        calls.resize(0);

        cx.simulateClick(new Point(20., 10.));
        draw(cx);

        assertTrue(calls.indexOf('open true') != -1, 'an open popover marks its trigger open, got $calls');
        assertTrue(calls.filter(call -> StringTools.startsWith(call, 'selected')).length == 0, 'opening must not touch the trigger\'s own selection, got $calls');
    }

    function testKeyboardActivationOpensThePopover() {
        app.update(cx -> Base.init(cx));
        final opened = open((_, cx) -> new KeyboardPopoverHarness(cx.focusHandle()));
        final cx = opened.cx;
        draw(cx);

        cx.update((window, cx) -> {
            final focus = (opened.view : KeyboardPopoverHarness).triggerFocus;
            focus.focus(window, cx);
        });
        cx.simulateKeystrokes('enter');
        draw(cx);

        assertTrue(OverlayProbe.debugBounds(cx.window, 'keyboard-popover-content') != null);
    }


/// tooltip.rs

    static function bounds(x:Float, y:Float, width:Float, height:Float):Bounds {
        return new Bounds(new Point(x, y), new Size(width, height));
    }

    function emptyWindow():VisualTestContext {
        return open((_, _) -> new ScriptView((_, _) -> div())).cx;
    }

    function testProviderOwnsGraceSwitchAndDismiss() {
        final state = app.newEntity((_:Context<TooltipOverlay>) -> new TooltipOverlay());
        final cx = emptyWindow();
        cx.update((window, cx) -> {
            state.update(cx, (tooltip, cx) -> {
                tooltip.hadRecentTooltip = true;
                tooltip.requestShow(new TooltipRequest(bounds(0., 0., 20., 20.), (_, _) -> throw 'content is not rendered by this lifecycle test'), window, cx);
            });
        });
        cx.update((_, cx) -> assertTrue((state : TooltipOverlay).content != null));

        cx.update((_, cx) -> state.update(cx, (tooltip, cx) -> tooltip.hide(cx)));
        cx.update((_, cx) -> assertTrue((state : TooltipOverlay).content == null));
    }

    function testShowDelayFollowsDefaultsAndRequestOverride() {
        app.update(cx -> new TooltipDefaults().withShowDelay(0.1).install(cx));
        // The delayed show updates the overlay in the window it was drawn in.
        final opened = open((_, _) -> new TooltipOverlay());
        final state = opened.view;
        final cx = opened.cx;
        draw(cx);
        final request = () -> new TooltipRequest(bounds(0., 0., 20., 20.), (_, cx) -> (cx.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) -> new glaze.Empty())) : glaze.AnyView));

        cx.update((window, cx) -> state.update(cx, (tooltip, cx) -> tooltip.requestShow(request(), window, cx)));
        advanceClock(cx, 0.099);
        cx.runUntilParked();
        cx.update((_, cx) -> assertTrue((state : TooltipOverlay).content == null));
        advanceClock(cx, 0.001);
        cx.runUntilParked();
        cx.update((_, cx) -> assertTrue((state : TooltipOverlay).content != null));

        cx.update((_, cx) -> state.update(cx, (tooltip, cx) -> tooltip.hide(cx)));
        cx.update((window, cx) -> {
            state.update(cx, (tooltip, cx) -> {
                tooltip.requestShow(request().withShowDelay(0.), window, cx);
                assertTrue(tooltip.content != null);
                assertTrue(tooltip.showTask == null);
            });
        });
    }

    function testTooltipPriorityExceedsPopupLayer() {
        assertTrue(@:privateAccess TooltipOverlay.TOOLTIP_PRIORITY > Popup.POPUP_PRIORITY);
    }

    function testDisabledProviderIgnoresDelayedAndImmediateRequests() {
        final state = app.newEntity((_:Context<TooltipOverlay>) -> {
            final overlay = new TooltipOverlay();
            overlay.enabled = false;
            overlay;
        });
        final cx = emptyWindow();
        for (hadRecentTooltip in [false, true]) {
            cx.update((window, cx) -> {
                state.update(cx, (tooltip, cx) -> {
                    tooltip.hadRecentTooltip = hadRecentTooltip;
                    tooltip.requestShow(new TooltipRequest(bounds(0., 0., 20., 20.), (_, _) -> throw 'disabled tooltips must not build content'), window, cx);
                    assertTrue(tooltip.content == null);
                    assertTrue(tooltip.showTask == null);
                    assertTrue(tooltip.hideTask == null);
                    assertEquals(0, tooltip.animationEpoch);
                });
            });
        }
    }

/// hover_card.rs

    function hoverCardHarness(openChanges:Array<Bool>, tapToOpen:Bool):VisualTestContext {
        final delay = 0.1;
        return open((_, _) -> new ScriptView((_, _) -> {
            final card = new HoverCard('hover-card');
            @:privateAccess card.tapToOpen = tapToOpen;
            return card
                .openDelay(delay)
                .closeDelay(delay)
                .onOpenChange((open, _, _) -> openChanges.push(open))
                .trigger(new OverlayProbe('hover-card-trigger', div().size(px(20.))))
                .content((_, _, _) -> div().id('hover-card-content').child(new OverlayProbe('hover-card-content', div().size(px(10.)))));
        })).cx;
    }

    function testPublicHoverCardOwnsDelayedOpenAndClose() {
        final delay = 0.1;
        final cx = hoverCardHarness([], false);
        draw(cx);

        cx.simulateMouseMove(new Point(10., 10.));
        advanceClock(cx, delay);
        cx.runUntilParked();
        draw(cx);
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'hover-card-content') != null);

        cx.simulateMouseMove(new Point(100., 100.));
        advanceClock(cx, delay);
        cx.runUntilParked();
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'hover-card-content') == null);
    }

    function testPublicHoverCardReportsEachOpenChange() {
        final delay = 0.1;
        final openChanges:Array<Bool> = [];
        final cx = hoverCardHarness(openChanges, false);
        draw(cx);

        cx.simulateMouseMove(new Point(10., 10.));
        assertEquals('[]', haxe.Json.stringify(openChanges));

        advanceClock(cx, delay);
        cx.runUntilParked();
        draw(cx);
        draw(cx);
        assertEquals('[true]', haxe.Json.stringify(openChanges));

        cx.simulateMouseMove(new Point(100., 100.));
        advanceClock(cx, delay);
        cx.runUntilParked();
        draw(cx);
        assertEquals('[true,false]', haxe.Json.stringify(openChanges));
    }

    function testTapCardIgnoresHoverAndTogglesAndDismisses() {
        final changes:Array<Bool> = [];
        final cx = hoverCardHarness(changes, true);
        draw(cx);
        cx.simulateMouseMove(new Point(10., 10.));
        advanceClock(cx, 1.);
        cx.runUntilParked();
        assertEquals(0, changes.length);

        cx.simulateClick(new Point(10., 10.));
        draw(cx);
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'hover-card-content') != null);
        cx.simulateMouseMove(new Point(100., 100.));
        advanceClock(cx, 1.);
        cx.runUntilParked();
        assertEquals('[true]', haxe.Json.stringify(changes));

        cx.simulateClick(new Point(10., 10.));
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'hover-card-content') == null);
        assertEquals('[true,false]', haxe.Json.stringify(changes));

        cx.simulateClick(new Point(10., 10.));
        draw(cx);
        draw(cx);
        final contentBounds = OverlayProbe.debugBounds(cx.window, 'hover-card-content');
        cx.simulateClick(contentBounds.center());
        assertEquals('[true,false,true]', haxe.Json.stringify(changes));
        cx.simulateClick(new Point(100., 100.));
        draw(cx);
        assertTrue(OverlayProbe.debugBounds(cx.window, 'hover-card-content') == null);
        assertEquals('[true,false,true,false]', haxe.Json.stringify(changes));
    }

}

/**
 * Records the bounds of its child during prepaint, per frame (Rust
 * `debug_selector` read back with `debug_bounds`).
 */
class OverlayProbe extends Element {

    static final bounds:Map<String, Bounds> = new Map();

    static final frames:Map<String, Int> = new Map();

    public static function reset():Void {
        bounds.clear();
        frames.clear();
    }

    /**
     * The bounds the selector had in the last frame drawn by `window`, or null.
     */
    public static function debugBounds(window:Window, selector:String):Null<Bounds> {
        final frame = frames.get(selector);
        return frame != null && frame == window.drawCount ? bounds.get(selector) : null;
    }

    final selector:String;

    final child:AnyElement;

    public function new(selector:String, child:IntoElement) {
        this.selector = selector;
        this.child = child.intoAnyElement();
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        OverlayProbe.bounds.set(selector, bounds);
        // The frame being drawn
        frames.set(selector, window.drawCount + 1);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}

/** A popup that may open later. */
private class ClosedHarness extends Model implements Render {

    public var open:Bool = false;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final popup = new Popup('popup', new OverlayProbe('popup-trigger', div().size(px(100.))));
        if (open) {
            return popup.content(new OverlayProbe('popup-content', div().size(px(20.))));
        }
        return popup;
    }

}

private class KeyboardPopoverHarness extends Model implements Render {

    public final triggerFocus:FocusHandle;

    public function new(triggerFocus:FocusHandle) {
        super();
        this.triggerFocus = triggerFocus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new Popover('keyboard-popover')
            .trigger(new glaze.kit.base.Button('keyboard-trigger').trackFocus(triggerFocus).child('Open'))
            .content((_, _, _) -> new OverlayProbe('keyboard-popover-content', div().size(px(40.))));
    }

}

/**
 * A trigger that keeps "open" and "selected" apart, the way a downstream
 * sidebar row does: it is selected when it is the current view, and open
 * only while its popover is showing.
 */
private class RecordingTrigger implements RenderOnce implements Selectable {

    final calls:Array<String>;

    var selectedValue:Bool = false;

    var openValue:Bool = false;

    public function new(calls:Array<String>) {
        this.calls = calls;
    }

    public function setSelected(selected:Bool):Void {
        calls.push('selected $selected');
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    public function setOpen(open:Bool):Void {
        calls.push('open $open');
        openValue = open;
    }

    public function isOpen():Bool {
        return openValue;
    }

    public function render(window:Window, cx:App):IntoElement {
        return div().size(px(40.)).child('Open');
    }

}

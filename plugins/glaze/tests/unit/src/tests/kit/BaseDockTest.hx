// Ported from gpui-kit 0.8.1: crates/base/src/dock/active.rs (tests), crates/base/src/dock/drag.rs (tests),
// crates/base/src/dock/dock_placement.rs (tests), crates/base/src/dock/panel.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Point;
import glaze.Size;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.dock.ActiveTracker;
import glaze.kit.base.dock.Dock;
import glaze.kit.base.dock.DockPlacement;
import glaze.kit.base.dock.DockSizing;
import glaze.kit.base.dock.Drag;
import glaze.kit.base.dock.DropPlaceholderBounds;
import glaze.kit.base.dock.EntityPanelView;
import glaze.kit.base.dock.JsonValue;
import glaze.kit.base.dock.PanelBase;
import glaze.kit.base.dock.PanelId;
import glaze.kit.base.dock.PanelInfo;
import glaze.kit.base.dock.PanelView;
import glaze.kit.base.resizable.Resizable;
import testing.TestCase;

using glaze.kit.base.dock.PanelInfo.PanelInfoTools;

/**
 * The `#[cfg(test)]` tests of gpui-base's dock modules that need no tree:
 * `active.rs`, `drag.rs`, `dock_placement.rs` and `panel.rs`.
 */
@:access(glaze.kit.base.dock.ActiveTracker)
@:access(glaze.kit.base.dock.Drag)
@:access(glaze.kit.base.dock.DropPlaceholderBounds)
class BaseDockTest extends TestCase {

    static function panel(n:Int):PanelId {
        return PanelId.fromU64(n);
    }

    static function changes(list:Array<{panel:PanelId, active:Bool}>):String {
        return [for (change in list) change.panel.asU64() + ' ' + change.active].join(', ');
    }

/// active.rs

    function testTheFirstReconcileAnnouncesTheDisplayedPanelOnly() {
        final tracker = new ActiveTracker();
        assertEquals('1 true', changes(tracker.reconcile([panel(1), panel(2)], panel(1))));
    }

    function testSwitchingReportsTheOldPanelFalseThenTheNewPanelTrue() {
        final tracker = new ActiveTracker();
        tracker.reconcile([panel(1), panel(2)], panel(1));

        assertEquals('1 false, 2 true', changes(tracker.reconcile([panel(1), panel(2)], panel(2))));
    }

    function testReselectingTheDisplayedPanelIsSilent() {
        final tracker = new ActiveTracker();
        tracker.reconcile([panel(1)], panel(1));

        assertEquals(0, tracker.reconcile([panel(1)], panel(1)).length);
    }

    function testARemovedPanelIsForgottenRatherThanToldFalse() {
        final tracker = new ActiveTracker();
        tracker.reconcile([panel(1), panel(2)], panel(1));

        final result = tracker.reconcile([panel(2)], panel(2));

        assertEquals('2 true', changes(result), 'panel 1 left the group; on_removed is its deactivation signal');
        assertFalse(tracker.tracks(panel(1)));
    }

    function testSeedingAMovedPanelPreventsASpuriousReactivation() {
        final tracker = new ActiveTracker();
        tracker.seed(panel(1), true);

        assertEquals(0, tracker.reconcile([panel(1)], panel(1)).length, 'a panel dragged in while displayed must not be told true twice');
    }

    function testNoPanelDisplayedDeactivatesThePreviousOne() {
        final tracker = new ActiveTracker();
        tracker.reconcile([panel(1)], panel(1));

        assertEquals('1 false', changes(tracker.reconcile([panel(1)], null)));
    }

    function testLastNotifiedReadsAPanelsStateForHandoffToAnotherTracker() {
        final source = new ActiveTracker();
        source.reconcile([panel(1), panel(2)], panel(1));

        assertEquals(true, source.lastNotified(panel(1)));
        assertEquals(false, source.lastNotified(panel(2)));
        assertNull(source.lastNotified(panel(3)), 'a panel never reconciled has no recorded state');

        final destination = new ActiveTracker();
        destination.seed(panel(1), source.lastNotified(panel(1)));

        assertEquals(0, destination.reconcile([panel(1)], panel(1)).length,
            'seeded from the source\'s last_notified value, the move must not look like a fresh edge');
    }

/// drag.rs

    static function bounds(x:Float, y:Float, w:Float, h:Float):Bounds {
        return new Bounds(new Point(x, y), new Size(w, h));
    }

    static function placeholder(x:Float, y:Float, w:Float, h:Float):DropPlaceholderBounds {
        return new DropPlaceholderBounds(new Point(x, y), new Size(w, h));
    }

    function testDropPlaceholderBoundsCoverEachTargetPlacement() {
        final b = bounds(120., 80., 400., 300.);

        assertTrue(DropPlaceholderBounds.forPlacement(b, Placement.Left).equals(placeholder(0., 0., 200., 300.)));
        assertTrue(DropPlaceholderBounds.forPlacement(b, Placement.Right).equals(placeholder(200., 0., 200., 300.)));
        assertTrue(DropPlaceholderBounds.forPlacement(b, Placement.Top).equals(placeholder(0., 0., 400., 150.)));
        assertTrue(DropPlaceholderBounds.forPlacement(b, Placement.Bottom).equals(placeholder(0., 150., 400., 150.)));
        assertTrue(DropPlaceholderBounds.forPlacement(b, null).equals(placeholder(0., 0., 400., 300.)));
    }

    function testSplitPlacementFollowsTheCursorZone() {
        final b = bounds(120., 80., 400., 300.);
        // 35% / 65% of 400x300 from origin (120, 80).
        final at = (x:Float, y:Float) -> Drag.splitPlacementAt(b, new Point(x, y));

        assertEquals(Placement.Left, at(130., 230.));
        assertEquals(Placement.Right, at(510., 230.));
        assertEquals(Placement.Top, at(320., 90.));
        assertEquals(Placement.Bottom, at(320., 370.));
        assertNull(at(320., 230.), 'centre merges into the tab group');
    }

    function testSplitPlacementPrefersHorizontalInTheCorners() {
        final b = bounds(0., 0., 400., 300.);

        // Top-left corner satisfies both Left and Top; x is tested first.
        assertEquals(Placement.Left, Drag.splitPlacementAt(b, new Point(10., 10.)));
        assertEquals(Placement.Right, Drag.splitPlacementAt(b, new Point(390., 290.)));
    }

    function testSplitPlacementBoundariesFallIntoTheCentre() {
        final b = bounds(0., 0., 400., 300.);

        // Comparisons are strict, so the threshold itself is the centre zone.
        assertNull(Drag.splitPlacementAt(b, new Point(140., 150.)));
        assertNull(Drag.splitPlacementAt(b, new Point(260., 150.)));
        assertNull(Drag.splitPlacementAt(b, new Point(200., 105.)));
        assertNull(Drag.splitPlacementAt(b, new Point(200., 195.)));
    }

/// dock_placement.rs

    function testALeftDockCannotSqueezePastTheRightDock() {
        final sizing = new DockSizing(DockPlacement.Left).withAreaWidth(1000.).withOppositeDockSize(300.);

        assertEquals(1000. - (Resizable.PANEL_MIN_SIZE : Float) - 300., (sizing.clamp(900.) : Float));
    }

    function testADockNeverClampsBelowTheMinimum() {
        final sizing = new DockSizing(DockPlacement.Bottom).withAreaHeight(120.);
        assertEquals((Resizable.PANEL_MIN_SIZE : Float), (sizing.clamp(1.) : Float));
    }

    function testABottomDockMeasuresFromTheAreaBottom() {
        final sizing = new DockSizing(DockPlacement.Bottom).withAreaBounds(bounds(0., 0., 800., 600.));

        assertEquals(200., (sizing.sizeFromPointer(new Point(400., 400.)) : Float));
    }

    function testARightDockMeasuresFromTheAreaRightEdge() {
        final sizing = new DockSizing(DockPlacement.Right).withAreaBounds(bounds(0., 0., 800., 600.));

        assertEquals(300., (sizing.sizeFromPointer(new Point(500., 0.)) : Float));
    }

    /**
     * `DockArea.setDockSize` is public and hands its argument straight here,
     * so without this floor a caller could collapse a dock to nothing and
     * persist it that way.
     */
    function testADockNeverShrinksBelowTheMinimum() {
        final dock = new Dock(240.);
        dock.setSize(1.);
        assertEquals((Resizable.PANEL_MIN_SIZE : Float), (dock.size() : Float));

        dock.setSize(400.);
        assertEquals(400., (dock.size() : Float), 'a size above the floor is kept');
    }

    /**
     * Both are public and take a public enum, so a caller can name the
     * center. Answering it is what keeps a base arithmetic helper from
     * failing over a value its own type permits.
     */
    function testTheCenterPlacementIsAnsweredRatherThanPanicking() {
        final sizing = new DockSizing(DockPlacement.Center).withAreaBounds(bounds(0., 0., 800., 600.));

        assertEquals(7., (sizing.clamp(7.) : Float), 'the center clamps nothing');
        assertEquals(0., (sizing.sizeFromPointer(new Point(400., 300.)) : Float));
    }

    function testDockStateDefaultsToOpenAndCollapsible() {
        final dock = new Dock(240.);
        assertTrue(dock.isOpen());
        assertTrue(dock.isCollapsible());
        assertEquals(240., (dock.size() : Float));
        assertFalse(dock.isResizing());
    }

/// panel.rs

    function testAPanelEntityAnswersThroughTheObjectSafeView() {
        final app = new App(new TestDispatcher());
        final probe = app.newEntity((cx:Context<Probe>) -> new Probe(cx, false));
        final view:PanelView = new EntityPanelView(probe);

        assertEquals('Probe', view.panelName(app));
        assertEquals(false, view.visible(app));
        assertEquals(PanelId.fromEntityId(probe.entityId()), view.panelId(app));
    }

    function testTheDefaultDumpRecordsOnlyThePanelName() {
        final app = new App(new TestDispatcher());
        final probe = app.newEntity((cx:Context<Probe>) -> new Probe(cx, true));
        final state = probe.read(app).dump(app);

        assertEquals('Probe', state.panelName);
        assertEquals(0, state.children.length);
        assertTrue(state.info.equals(PanelInfoTools.panel(JNull)));
    }

}

private class Probe extends PanelBase {

    final focus:FocusHandle;

    final visibleValue:Bool;

    public function new(cx:Context<Probe>, visible:Bool) {
        super();
        this.focus = cx.focusHandle();
        this.visibleValue = visible;
    }

    public function panelName():String {
        return 'Probe';
    }

    override public function visible(cx:App):Bool {
        return visibleValue;
    }

    public function focusHandle(cx:App):FocusHandle {
        return focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new glaze.Empty();
    }

}

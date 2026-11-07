// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_area.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.AnyElement;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Pixels;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.Base;
import gpui.base.Geometry.Placement;
import gpui.base.dock.DockArea;
import gpui.base.dock.DockAreaRendererBase;
import gpui.base.dock.DockAreaState;
import gpui.base.dock.DockEvent;
import gpui.base.dock.DockLayout;
import gpui.base.dock.DockPlacement;
import gpui.base.dock.EntityPanelView;
import gpui.base.dock.InsertTarget;
import gpui.base.dock.JsonValue;
import gpui.base.dock.NodeId;
import gpui.base.dock.PaneNode;
import gpui.base.dock.PanelBase;
import gpui.base.dock.PanelId;
import gpui.base.dock.PanelInfo;
import gpui.base.dock.PanelRegistry;
import gpui.base.dock.PanelState;
import gpui.base.dock.PanelView;
import gpui.base.dock.TabGroup;
import gpui.base.dock.TabGroupContext;
import gpui.base.dock.TabGroupRenderer;
import gpui.base.dock.TabGroupRendererBase;
import gpui.base.theme.Theme;
import tests.kit.DockTestSupport;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.base.dock.JsonValue.JsonValueTools;
using gpui.base.dock.PanelInfo.PanelInfoTools;

/**
 * The `#[cfg(test)]` tests of gpui-base's `DockArea` (`dock_area.rs`),
 * including the ones gpui-kit ported from the old `TabPanel` tests. Element
 * bounds are read through `DebugProbe` (Rust `debug_selector`).
 */
@:access(gpui.base.dock.DockArea)
@:access(gpui.base.dock.TabGroup)
class BaseDockAreaTest extends TestCase {

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

    static function sizes(list:Array<Null<Pixels>>):String {
        return [for (size in list) size == null ? 'None' : Std.string((size : Float))].join(',');
    }

    static function measuredOf(area:Entity<DockArea>, node:NodeId, cx:VisualTestContext):Array<Pixels> {
        return cx.update((_, cx) -> area.read(cx).splits.get(node.asU64()).entity.read(cx).sizes().copy());
    }

    /**
     * The file holds pixels measured in whatever window last saved it, so its
     * total is off the container the layout is restored into.
     */
    function testSlotSizesAreReExpressedAsSharesOfTheContainer() {
        assertEquals('600,200', sizes(DockArea.scaleSizesTo(800., [300., 100.])));
    }

    /**
     * An unconstrained slot is laid out by flex and takes the leftover, so
     * scaling only its siblings would move a divider nothing asked to move.
     */
    function testAnUnconstrainedSlotLeavesEverySizeAlone() {
        assertEquals('300,None', sizes(DockArea.scaleSizesTo(800., [300., null])));
    }

    /**
     * Nothing to scale against before the first layout pass, or when the
     * recorded sizes carry no length at all.
     */
    function testAnUnusableContainerOrTotalLeavesEverySizeAlone() {
        assertEquals('300,100', sizes(DockArea.scaleSizesTo(0., [300., 100.])));
        assertEquals('0,0', sizes(DockArea.scaleSizesTo(800., [0., 0.])));
    }

    function setup_():{area:Entity<DockArea>, cx:VisualTestContext} {
        app.update(cx -> Theme.globalMut(cx));
        return open(null);
    }

    function open(renderer:Null<DockAreaRendererBase>):{area:Entity<DockArea>, cx:VisualTestContext} {
        DebugProbe.clear();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<DockArea>) -> {
            final area = new DockArea('test-dock', null, window, cx);
            renderer != null ? area.withRenderer(renderer) : area;
        });
        contexts.push(opened.cx);
        return {area: opened.view, cx: opened.cx};
    }

    function layoutEvents(area:Entity<DockArea>, cx:VisualTestContext):{count:Int} {
        final events = {count: 0};
        cx.update((window, cx) -> window.subscribe(area, DockEvent, cx, (_, event, _, _) -> {
            if (event.match(LayoutChanged)) events.count += 1;
        }).detach());
        return events;
    }

    function testDockSizeChangeEmitsOneLayoutEvent() {
        final s = setup_();
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> {
            area.setDock(DockPlacement.Left, DockLayout.tabs().panel(TestPanel.create('Left', cx)), window, acx);
        }));

        final events = layoutEvents(s.area, s.cx);

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> {
            area.setDockSize(DockPlacement.Left, 320., window, acx);
            area.setDockSize(DockPlacement.Left, 320., window, acx);
        }));
        assertEquals(1, events.count, 'only an effective size change is persisted');
    }

    /**
     * Two tab groups side by side, holding one logging panel each.
     */
    function twoGroups(log:DockLog):{area:Entity<DockArea>, alpha:Entity<TestPanel>, cx:VisualTestContext} {
        final s = setup_();
        final alpha = s.cx.update((window, cx) -> {
            final alpha = TestPanel.logging('Alpha', log, cx);
            final beta = TestPanel.logging('Beta', log, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), null)
                .child(DockLayout.tabs().panel(beta), null), window, acx));
            alpha;
        });
        return {area: s.area, alpha: alpha, cx: s.cx};
    }

    /**
     * The id of the center split's `ix`-th child container.
     */
    static function childNode(area:Entity<DockArea>, ix:Int, cx:VisualTestContext):NodeId {
        return cx.update((_, cx) -> switch area.read(cx).layout(DockPlacement.Center).root().kind() {
            case Split(_, children, _): children[ix].id();
            case _: throw 'the center root is a split';
        });
    }

    static function rootOf(area:Entity<DockArea>, placement:DockPlacement, cx:VisualTestContext):NodeId {
        return cx.update((_, cx) -> area.read(cx).layout(placement).root().id());
    }

    static inline function panelIdOf(panel:Entity<TestPanel>):PanelId {
        return DockTestSupport.panelId(panel);
    }

    static function moveAlphaIntoTheOtherGroup(area:Entity<DockArea>, alpha:Entity<TestPanel>, cx:VisualTestContext):Void {
        final target = childNode(area, 1, cx);
        final alphaId = panelIdOf(alpha);
        cx.update((window, cx) -> area.update(cx, (area, acx) -> area.movePanel(alphaId, InsertTarget.Tabs(target, null, true), window, acx)));
        cx.runUntilParked();
    }

    static function collectSizes(state:PanelState, out:Array<Float>):Void {
        switch state.info {
            case Stack(sizes, _): for (size in sizes) out.push(size);
            case _:
        }
        for (child in state.children) collectSizes(child, out);
    }

    static function registerTestPanels(cx:App):Void {
        for (name in ['Alpha', 'Beta', 'Gamma']) {
            PanelRegistry.registerPanel(cx, name, (_, _, cx) -> new EntityPanelView(TestPanel.create(name, cx)));
        }
    }

    /**
     * One tab group holding `names`, installed as the whole center.
     */
    function oneGroup(log:DockLog, names:Array<String>, activeIx:Null<Int>):{area:Entity<DockArea>, panels:Array<Entity<TestPanel>>, cx:VisualTestContext} {
        final s = setup_();
        final panels = s.cx.update((window, cx) -> {
            final panels = [for (name in names) TestPanel.logging(name, log, cx)];
            var layout = DockLayout.tabs();
            for (panel in panels) layout = layout.panel(panel);
            layout = layout.activeIndex(activeIx != null ? activeIx : 0);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
            panels;
        });
        return {area: s.area, panels: panels, cx: s.cx};
    }

    /**
     * The live group behind the center split's `ix`-th child.
     */
    static function groupOf(area:Entity<DockArea>, ix:Int, cx:VisualTestContext):Entity<TabGroup> {
        final node = childNode(area, ix, cx);
        return cx.update((_, cx) -> area.read(cx).groups.get(node.asU64()).entity);
    }

    static function movePanelInto(area:Entity<DockArea>, panel:PanelId, node:NodeId, ix:Null<Int>, activate:Bool, cx:VisualTestContext):Void {
        cx.update((window, cx) -> area.update(cx, (area, acx) -> area.movePanel(panel, InsertTarget.Tabs(node, ix, activate), window, acx)));
        cx.runUntilParked();
    }

    static function isCenterEmpty(area:Entity<DockArea>, cx:VisualTestContext):Bool {
        return cx.update((_, cx) -> area.read(cx).isEmpty(DockPlacement.Center, cx));
    }

    static function dump(area:Entity<DockArea>, cx:VisualTestContext):DockAreaState {
        return cx.update((_, cx) -> area.read(cx).dump(cx));
    }

    function testALayoutInstallsAndDumpsBackToTheSameState() {
        final s = setup_();
        s.cx.update((window, cx) -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), 300.)
                .child(DockLayout.tabs().panel(beta), null), window, acx));
        });

        final state = dump(s.area, s.cx);
        assertEquals('StackPanel', state.center.panelName);
        assertEquals(2, state.center.children.length);
        assertEquals('Alpha', state.center.children[0].children[0].panelName);
        assertEquals('Beta', state.center.children[1].children[0].panelName);
    }

    function testMovingAPanelReusesItsEntity() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        log.drain();

        final destination = childNode(t.area, 1, t.cx);
        final destinationEntity = t.cx.update((_, cx) -> t.area.read(cx).groups.get(destination.asU64()).entity.entityId());

        moveAlphaIntoTheOtherGroup(t.area, t.alpha, t.cx);

        assertEquals(destinationEntity, t.cx.update((_, cx) -> t.area.read(cx).groups.get(destination.asU64()).entity.entityId()),
            'the group the panel arrived in was reused, not rebuilt');

        final alphaId = panelIdOf(t.alpha);
        assertNotNull(t.cx.update((_, cx) -> t.area.read(cx).layout(DockPlacement.Center).findPanelNode(alphaId)), 'the moved panel is still in the tree');

        final state = dump(t.area, t.cx);
        // One child, not two: emptying the first group removes it, and a
        // `RootKind.Split` root is never collapsed.
        assertEquals(1, state.center.children.length, 'the emptied group collapsed out of the split');
        assertEquals(2, state.center.children[0].children.length, 'both panels now share the surviving group');
    }

    function testAMovedPanelIsNotToldItWasRemoved() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        log.drain();

        moveAlphaIntoTheOtherGroup(t.area, t.alpha, t.cx);

        assertFalse(log.drain().contains('Alpha Removed'), 'moving a panel between groups must never deliver on_removed');
    }

    function testRemovingAPanelDoesTellItItWasRemoved() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        log.drain();

        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.removePanel(t.alpha, window, acx)));
        t.cx.runUntilParked();

        assertTrue(log.drain().contains('Alpha Removed'), 'a genuine removal must deliver on_removed');
    }

    function testReconcilingAnUnchangedTreeCreatesNoEntities() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        log.drain();

        final ids = () -> [for (id in t.cx.update((_, cx) -> t.area.read(cx).containerEntityIds())) id.node + ':' + id.entity].join(',');
        final before = ids();
        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.reconcile(window, acx)));
        final after = ids();

        assertTrue(before.length > 0, 'there were containers to preserve');
        assertEquals(before, after, 'a steady-state pass creates and drops nothing');
        t.cx.runUntilParked();
        assertEquals('', log.drain().join(', '), 'and no panel was re-added or re-activated by it');
    }

    function testALoadedLayoutRoundTripsThroughDump() {
        final s = setup_();
        s.cx.update((_, cx) -> registerTestPanels(cx));

        final state = DockAreaState.fromJson(@:privateAccess BaseDockStateTest.fixture('nested_splits.json'));

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.load(state.clone(), window, acx)));
        final dumped = dump(s.area, s.cx);

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.load(dumped.clone(), window, acx)));
        final again = dump(s.area, s.cx);

        assertTrue(dumped.equals(again), 'load/dump must reach a fixpoint');
        assertEquals(3, dumped.center.children.length, 'the fixture\'s nesting is flattened, as the state layer already pins');
        assertEquals('Alpha', dumped.center.children[0].children[0].panelName);
    }

    function testADumpedLiveLayoutHasNoZeroSizes() {
        final s = setup_();
        s.cx.update((window, cx) -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            final gamma = TestPanel.create('Gamma', cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.vSplit()
                // Unconstrained, which the tree stores as `null` and the
                // writer would otherwise emit as 0.0.
                .child(DockLayout.tabs().panel(alpha), null)
                // Already zero. Resolving only the `null` slots would leave
                // this one writing the same unsafe byte.
                .child(DockLayout.tabs().panel(beta), 0.)
                .child(DockLayout.tabs().panel(gamma), 240.), window, acx));
        });

        final state = dump(s.area, s.cx);
        final all:Array<Float> = [];
        collectSizes(state.center, all);

        assertTrue(all.length > 0, 'the layout has slots to check');
        for (size in all) assertTrue(size > 0, 'an older build reads a persisted 0.0 back as a real zero-pixel panel: $all');
    }

    /**
     * The tree only hears about slot sizes a drag finished on, so `dump`
     * reads the measurement for a split it has on screen.
     */
    function testADumpedSplitWritesTheSizesItIsActuallyDrawnAt() {
        final s = setup_();
        s.cx.update((window, cx) -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), 300.)
                .child(DockLayout.tabs().panel(beta), 300.), window, acx));
        });
        s.cx.runUntilParked();

        final root = rootOf(s.area, DockPlacement.Center, s.cx);
        final measured = measuredOf(s.area, root, s.cx);
        assertTrue(measured.join(',') != '300,300',
            'the split has to have been rescaled by a layout pass, or this test cannot tell the two preferences apart');

        final state = dump(s.area, s.cx);
        switch state.center.info {
            case Stack(written, _):
                assertEquals(measured.join(','), written.join(','), 'the written sizes are the ones on screen, not the ones the tree was built from');
            case _:
                fail('the center writes a stack');
        }
    }

    function testSetSplitSizesRestoresAShareAndReportsIt() {
        final s = setup_();
        s.cx.update((window, cx) -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), 300.)
                .child(DockLayout.tabs().panel(beta), 300.), window, acx));
        });
        s.cx.runUntilParked();

        final root = rootOf(s.area, DockPlacement.Center, s.cx);
        final events = layoutEvents(s.area, s.cx);

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.setSplitSizes(root, [100., 300.], window, acx)));
        s.cx.runUntilParked();
        assertEquals(1, events.count);
        final measured = measuredOf(s.area, root, s.cx);
        final share = measured[0] / (measured[0] + measured[1]);
        assertTrue(Math.abs(share - 0.25) < 0.01, 'measured $measured');

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.setSplitSizes(root, [10.], window, acx)));
        s.cx.runUntilParked();
        assertEquals(1, events.count);
        assertEquals(measured.join(','), measuredOf(s.area, root, s.cx).join(','));
    }

    static function assertHalves(test:TestCase, sizes:Array<Pixels>, ?label:String):Void {
        @:privateAccess test.assertEquals(2, sizes.length, (label != null ? '$label: ' : '') + 'the drop splits in two');
        final first:Float = sizes[0];
        final second:Float = sizes[1];
        @:privateAccess test.assertTrue(Math.abs(first - second) <= (first + second) * 0.02,
            (label != null ? '$label: ' : '') + 'the two halves must be within 2% of each other, got $first and $second');
    }

    /**
     * A drop that splits carries no size, so the split has to decide one, and
     * sharing the container equally is the decision.
     */
    function testAPanelDroppedBesideAnotherTakesHalfTheSplit() {
        final log = new DockLog();
        final o = oneGroup(log, ['Alpha', 'Beta'], null);
        final group = childNode(o.area, 0, o.cx);
        final beta = panelIdOf(o.panels[1]);

        o.cx.update((window, cx) -> o.area.update(cx, (area, acx) -> area.movePanel(beta, InsertTarget.Split(group, Placement.Right, null), window, acx)));
        o.cx.runUntilParked();

        final root = rootOf(o.area, DockPlacement.Center, o.cx);
        assertHalves(this, measuredOf(o.area, root, o.cx));
    }

    /**
     * Moving a panel this area does not own is a no-op, not a ghost insert.
     */
    function testAMoveOfAnUnownedPanelIsIgnored() {
        final log = new DockLog();
        final o = oneGroup(log, ['Alpha', 'Beta'], null);
        final group = childNode(o.area, 0, o.cx);
        final before = dump(o.area, o.cx);

        // A PanelId from nowhere, as if dropped from another DockArea.
        movePanelInto(o.area, PanelId.fromU64(9999999), group, null, true, o.cx);

        assertTrue(before.equals(dump(o.area, o.cx)), 'an unowned panel move must not touch the tree');
    }

    /**
     * The other drop geometry: a placement whose axis differs from the
     * parent's wraps the target in a fresh split.
     */
    function testAPanelDroppedAcrossTheAxisStillTakesHalf() {
        final log = new DockLog();
        final o = oneGroup(log, ['Alpha', 'Beta'], null);
        final group = childNode(o.area, 0, o.cx);
        final beta = panelIdOf(o.panels[1]);

        o.cx.update((window, cx) -> o.area.update(cx, (area, acx) -> area.movePanel(beta, InsertTarget.Split(group, Placement.Bottom, null), window, acx)));
        o.cx.runUntilParked();

        // Dropping across the axis wraps the target in a new split, which
        // becomes the center root's only child.
        final wrapper = childNode(o.area, 0, o.cx);
        assertHalves(this, measuredOf(o.area, wrapper, o.cx));
    }

    /**
     * A drop into a split that already holds more than one slot.
     */
    function testAPanelDroppedIntoAPopulatedSplitTakesAnEvenShare() {
        final s = setup_();
        final panels = s.cx.update((window, cx) -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            final gamma = TestPanel.create('Gamma', cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), 240.)
                .child(DockLayout.tabs().panel(beta).panel(gamma), null), window, acx));
            [alpha, beta, gamma];
        });
        s.cx.runUntilParked();

        final right = childNode(s.area, 1, s.cx);
        final gamma = panelIdOf(panels[2]);
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.movePanel(gamma, InsertTarget.Split(right, Placement.Right, null), window, acx)));
        s.cx.runUntilParked();

        final root = rootOf(s.area, DockPlacement.Center, s.cx);
        final measured = measuredOf(s.area, root, s.cx);
        assertEquals(3, measured.length, 'three slots side by side');
        final dropped:Float = measured[2];
        final neighbour:Float = measured[1];
        assertTrue(Math.abs(dropped - neighbour) <= (dropped + neighbour) * 0.02,
            'the dropped panel splits its neighbour evenly, got neighbour $neighbour and dropped $dropped');
    }

    /**
     * A dock's root is usually a bare tab group, so a drop beside it takes
     * the "wrap the target in a new split" path, and that split has never been
     * measured.
     */
    function testAPanelDroppedBesideADockTakesHalf() {
        for (placement in [DockPlacement.Bottom, DockPlacement.Left]) {
            final s = setup_();
            final dropped = s.cx.update((window, cx) -> {
                final resident = TestPanel.create('Resident', cx);
                final dropped = TestPanel.create('Dropped', cx);
                s.area.update(cx, (area, acx) -> {
                    area.setCenter(DockLayout.tabs().panel(TestPanel.create('Center', cx)), window, acx);
                    area.setDock(placement, DockLayout.tabs().panel(resident).panel(dropped), window, acx);
                    area.setDockSize(placement, 400., window, acx);
                });
                dropped;
            });
            s.cx.runUntilParked();

            final group = s.cx.update((_, cx) -> s.area.read(cx).layout(placement).findPanelNode(panelIdOf(dropped)));
            assertNotNull(group, 'both panels start in the dock\'s only group');

            s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.movePanel(panelIdOf(dropped), InsertTarget.Split(group, Placement.Bottom, null), window, acx)));
            s.cx.runUntilParked();

            final split = s.cx.update((_, cx) -> {
                final root = s.area.read(cx).layout(placement).root();
                switch root.kind() {
                    case Split(_, _, _): root.id();
                    case _: throw 'the drop must have produced a split';
                }
            });
            assertHalves(this, measuredOf(s.area, split, s.cx), Std.string(placement));
        }
    }

    /**
     * A slot given an explicit size keeps it on the frame after the first.
     */
    function testAnExplicitSlotSizeSurvivesTheFirstLayoutPass() {
        final s = setup_();
        s.cx.update((window, cx) -> {
            final sidebar = TestPanel.create('Sidebar', cx);
            final content = TestPanel.create('Content', cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(sidebar), 200.)
                .child(DockLayout.tabs().panel(content), null), window, acx));
        });
        s.cx.runUntilParked();

        final root = rootOf(s.area, DockPlacement.Center, s.cx);
        final measured = measuredOf(s.area, root, s.cx);
        assertTrue(measured.length > 0, 'the split has slots');
        // Within a couple of pixels of what was asked for. The bug this pins
        // made it 587px.
        final fixed:Float = measured[0];
        assertTrue(Math.abs(fixed - 200.) <= 4.,
            'the fixed slot keeps its 200px instead of being rescaled by the flexible sibling\'s placeholder, got $fixed');
    }

    static function drawFrames(cx:VisualTestContext, frames:Int):Void {
        for (_ in 0...frames) {
            DebugProbe.clear();
            cx.update((window, _) -> window.draw());
        }
    }

    /**
     * Switching a tab edits one group, yet `commit` reconciles every
     * container. Reconciling a split the edit did not touch must not re-adopt
     * the tree's `null` for its flexible slot.
     */
    function testSwitchingATabLeavesAnUntouchedSplitWhereItWasDrawn() {
        final s = setup_();
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> {
            area.setCenter(DockLayout.tabs().panel(TestPanel.create('Center', cx)), window, acx);
            area.setDock(DockPlacement.Left, DockLayout.vSplit()
                .child(DockLayout.tabs().panel(MeasuredPanel.create('upper-left', cx)), null)
                .child(DockLayout.tabs().panel(MeasuredPanel.create('lower-left', cx)), 360.), window, acx);
            area.setDockSize(DockPlacement.Left, 350., window, acx);
            area.setDock(DockPlacement.Bottom, DockLayout.tabs()
                .panel(TestPanel.create('Tooltip', cx))
                .panel(TestPanel.create('Icon', cx)), window, acx);
            area.setDockSize(DockPlacement.Bottom, 200., window, acx);
        }));
        s.cx.runUntilParked();
        drawFrames(s.cx, 3);
        final before = Std.string(DebugProbe.bounds('upper-left')) + ' ' + Std.string(DebugProbe.bounds('lower-left'));

        final bottom = rootOf(s.area, DockPlacement.Bottom, s.cx);
        final group = s.cx.update((_, cx) -> s.area.read(cx).groups.get(bottom.asU64()).entity);
        s.cx.update((window, cx) -> group.update(cx, (group, gcx) -> group.selectTab(1, window, gcx)));
        s.cx.runUntilParked();
        drawFrames(s.cx, 3);
        final after = Std.string(DebugProbe.bounds('upper-left')) + ' ' + Std.string(DebugProbe.bounds('lower-left'));

        assertTrue(DebugProbe.bounds('upper-left') != null);
        assertEquals(before, after, 'a tab change in the bottom dock must not move the left split');
    }

    /**
     * The other way a reconcile could move an untouched split: handing the
     * file's pixels back on a tab change slides the divider to a third
     * position.
     */
    function testSwitchingATabKeepsARestoredSplitAtItsRescaledShare() {
        final s = setup_();
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> {
            area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(TestPanel.create('Alpha', cx)).panel(TestPanel.create('Beta', cx)), 620.)
                .child(DockLayout.tabs().panel(MeasuredPanel.create('second', cx)), 350.), window, acx);
        }));
        s.cx.runUntilParked();
        drawFrames(s.cx, 3);
        // The second slot's box tells where the divider is.
        final before = DebugProbe.bounds('second');
        assertTrue(before.right() != 970.,
            'the window must not match the recorded total, or this test cannot tell a rescaled split from the file\'s pixels');

        final group = groupOf(s.area, 0, s.cx);
        s.cx.update((window, cx) -> group.update(cx, (group, gcx) -> group.selectTab(1, window, gcx)));
        s.cx.runUntilParked();
        drawFrames(s.cx, 3);
        final after = DebugProbe.bounds('second');

        assertTrue(before.equals(after), 'a tab change must not hand the file\'s pixels back to the split: $before vs $after');
    }

    /**
     * The headline claim of the whole extraction, in one place: a layout
     * written by the shipped dock loads into the tree world, draws, and saves
     * back to a state the next load reproduces exactly. Its panels are not
     * registered, so every leaf takes the placeholder path.
     */
    function testTheShippedFixtureSurvivesALoadDumpLoadRoundTrip() {
        final s = setup_();
        final fixture = DockAreaState.fromJson(@:privateAccess BaseDockStateTest.fixture('layout.json'));

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.load(fixture, window, acx)));
        s.cx.runUntilParked();
        final first = dump(s.area, s.cx);

        assertEquals(2, first.center.children.length, 'the center\'s two groups');
        assertEquals(15, first.center.children[0].children.length);
        assertEquals(1, first.center.children[1].children.length);
        for (dock in [first.leftDock, first.bottomDock, first.rightDock]) {
            assertNotNull(dock, 'all three docks are attached');
            assertTrue(dock.open());
            assertTrue(dock.panel().children.length > 0, 'a dock that loaded empty would round-trip just as stably');
        }
        assertEquals(350., (first.leftDock.size() : Float));
        assertEquals(200., (first.bottomDock.size() : Float));
        assertEquals(320., (first.rightDock.size() : Float));

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.load(first.clone(), window, acx)));
        s.cx.runUntilParked();
        final second = dump(s.area, s.cx);

        assertTrue(second.equals(first), 'dump == dump(load(dump))');
    }

    function testAnUnregisteredPanelSurvivesALoadAndSaveRoundTrip() {
        final s = setup_();
        s.cx.update((_, cx) -> registerTestPanels(cx));

        final state = DockAreaState.fromJson(@:privateAccess BaseDockStateTest.fixture('unregistered_panel.json'));
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.load(state, window, acx)));
        final dumped = dump(s.area, s.cx);

        final leaf = dumped.center.children[0].children[0];
        assertEquals('PanelFromTheFuture', leaf.panelName);
        assertTrue(leaf.info.equals(PanelInfoTools.panel(JsonValueTools.parse('{"keep": "me"}'))), 'a panel this build cannot construct keeps its payload');
    }

    function testADockCarriesItsOwnTreeAndSurvivesARoundTrip() {
        final s = setup_();
        s.cx.update((window, cx) -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            s.area.update(cx, (area, acx) -> {
                area.setCenter(DockLayout.tabs().panel(alpha), window, acx);
                area.setDock(DockPlacement.Left, DockLayout.tabs().panel(beta), window, acx);
            });
        });

        // Node ids are globally allocated, so the center and the dock never
        // claim the same entity-cache slot.
        final centerIds = s.cx.update((_, cx) -> s.area.read(cx).layout(DockPlacement.Center).nodeIds());
        final dockIds = s.cx.update((_, cx) -> s.area.read(cx).layout(DockPlacement.Left).nodeIds());
        assertTrue(centerIds.length > 0 && dockIds.length > 0);
        for (id in centerIds) assertFalse(dockIds.contains(id), 'every tree in one area must draw from one id space');

        final state = dump(s.area, s.cx);
        final left = state.leftDock;
        assertNotNull(left, 'the left dock is written');
        assertEquals(DockPlacement.Left, left.placement());
        assertTrue(left.open());
        assertEquals('Beta', left.panel().children[0].panelName);
        assertNull(state.rightDock);
    }

    function testAPanelMovedBetweenRegionsKeepsItsActiveState() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        // Alpha is the displayed tab of its own group, so it has been told
        // `true` exactly once.
        assertTrue(log.drain().contains('Alpha Active(true)'));

        moveAlphaIntoTheOtherGroup(t.area, t.alpha, t.cx);

        assertFalse(log.drain().contains('Alpha Active(true)'), 'a displayed panel dragged to another group must not be told `true` twice');
    }

    function testAGroupsCloseIntentReachesTheTree() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        log.drain();

        final node = childNode(t.area, 0, t.cx);
        final alphaId = panelIdOf(t.alpha);
        t.cx.update((_, cx) -> {
            final group = t.area.read(cx).groups.get(node.asU64()).entity;
            group.update(cx, (group, gcx) -> group.closePanel(alphaId, gcx));
        });
        t.cx.runUntilParked();

        assertNull(t.cx.update((_, cx) -> t.area.read(cx).layout(DockPlacement.Center).findPanelNode(alphaId)), 'the close intent was applied to the tree');
        assertTrue(log.drain().contains('Alpha Removed'));
    }

    function testReplacingTheCenterTellsThePanelsThatLeft() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        log.drain();

        t.cx.update((window, cx) -> {
            final gamma = TestPanel.create('Gamma', cx);
            t.area.update(cx, (area, acx) -> area.setCenter(DockLayout.tabs().panel(gamma), window, acx));
        });
        t.cx.runUntilParked();

        final seen = log.drain();
        assertTrue(seen.contains('Alpha Removed'));
        assertTrue(seen.contains('Beta Removed'));
    }

    function testClosingAZoomedPanelClearsTheZoom() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();

        final node = childNode(t.area, 0, t.cx);
        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.setZoomedIn(node, window, acx)));
        assertTrue(t.cx.update((_, cx) -> t.area.read(cx).isZoomed()));

        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.removePanel(t.alpha, window, acx)));

        assertFalse(t.cx.update((_, cx) -> t.area.read(cx).isZoomed()), 'a zoomed panel that left the dock must not keep filling it');
    }

    /**
     * A panel no builder answers for becomes the skin's placeholder rather
     * than base's draw-nothing one.
     */
    function testAnUnbuildablePanelBecomesTheSkinsPlaceholder() {
        app.update(cx -> Theme.globalMut(cx));
        final asked:Array<String> = [];
        final s = open(new PlaceholderSkin(asked));

        // Nothing is registered, so the round trip cannot rebuild this panel.
        s.cx.update((window, cx) -> {
            final ghost = TestPanel.create('Ghost', cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.tabs().panel(ghost), window, acx));
        });
        final state = dump(s.area, s.cx);
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.load(state, window, acx)));
        s.cx.runUntilParked();

        assertEquals('Ghost', asked.join(','));
        assertEquals('SkinPlaceholder', s.cx.update((_, cx) -> [for (panel in s.area.read(cx).panels) panel.panelName(cx)].join(',')),
            'base installed the skin\'s placeholder, not its own');
        assertEquals('Ghost', dump(s.area, s.cx).center.children[0].children[0].panelName, 'and the unknown panel still survives the next save');
    }

    function testRemovingANonTailChildShiftsTheSplitSizesWithIt() {
        final log = new DockLog();
        final s = setup_();
        final alpha = s.cx.update((window, cx) -> {
            final alpha = TestPanel.logging('Alpha', log, cx);
            final beta = TestPanel.logging('Beta', log, cx);
            final gamma = TestPanel.logging('Gamma', log, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), 100.)
                .child(DockLayout.tabs().panel(beta), 200.)
                .child(DockLayout.tabs().panel(gamma), 300.), window, acx));
            alpha;
        });

        final root = rootOf(s.area, DockPlacement.Center, s.cx);
        final split = s.cx.update((_, cx) -> s.area.read(cx).splits.get(root.asU64()).entity);
        final sizesOf = () -> s.cx.update((_, cx) -> split.read(cx).sizes().copy());

        // What is asserted is which slot disappeared, through the ratio the
        // survivors keep.
        final before = sizesOf();
        assertEquals(3, before.length);
        final keptIfCorrect = before[1] / before[2];
        final keptIfTruncated = before[0] / before[1];
        assertTrue(Math.abs(keptIfCorrect - keptIfTruncated) > 0.1, 'the fixture must be able to tell the two outcomes apart');

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.removePanel(alpha, window, acx)));

        final after = sizesOf();
        assertEquals(2, after.length);
        assertTrue(Math.abs(after[0] / after[1] - keptIfCorrect) < 0.01,
            'the survivors kept their own proportions: slot 0 was removed, not the tail, got $after from $before');
    }

    function testAPanelMovesBetweenTheCenterAndADock() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.update((window, cx) -> {
            final gamma = TestPanel.logging('Gamma', log, cx);
            t.area.update(cx, (area, acx) -> area.setDock(DockPlacement.Left, DockLayout.tabs().panel(gamma), window, acx));
        });
        t.cx.runUntilParked();
        log.drain();

        final alphaId = panelIdOf(t.alpha);
        final dockGroup = rootOf(t.area, DockPlacement.Left, t.cx);

        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.movePanel(alphaId, InsertTarget.Tabs(dockGroup, null, true), window, acx)));
        t.cx.runUntilParked();

        assertNull(t.cx.update((_, cx) -> t.area.read(cx).layout(DockPlacement.Center).findPanelNode(alphaId)), 'the panel left the center');
        assertEquals(dockGroup, t.cx.update((_, cx) -> t.area.read(cx).layout(DockPlacement.Left).findPanelNode(alphaId)), 'and arrived in the dock\'s group');

        final seen = log.drain();
        assertFalse(seen.contains('Alpha Removed'), 'crossing regions is still a move, not a removal');
        assertFalse(seen.contains('Alpha Active(true)'), 'and it was displayed in both, so it is not told `true` twice');
    }

    function testAMoveOntoAnUnusableTargetLeavesNoStrandedPanel() {
        final log = new DockLog();
        final t = twoGroups(log);
        final gamma = t.cx.update((window, cx) -> {
            final gamma = TestPanel.logging('Gamma', log, cx);
            t.area.update(cx, (area, acx) -> area.setDock(DockPlacement.Left, DockLayout.tabs().panel(gamma), window, acx));
            gamma;
        });
        t.cx.runUntilParked();
        log.drain();

        final gammaId = panelIdOf(gamma);
        // The center root is a split, so a `Tabs` insert naming it does
        // nothing at all.
        final centerRoot = rootOf(t.area, DockPlacement.Center, t.cx);

        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.movePanel(gammaId, InsertTarget.Tabs(centerRoot, null, true), window, acx)));
        t.cx.runUntilParked();

        assertNull(t.cx.update((_, cx) -> t.area.read(cx).panel(gammaId)),
            'the view map agrees with the trees straight away, rather than carrying a panel that belongs to no tree');
        assertTrue(log.drain().contains('Gamma Removed'), 'and the panel was told so at the point of the call');
    }

    function testAnAllHiddenContainerReportsItselfInvisible() {
        final s = setup_();
        final beta = s.cx.update((window, cx) -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), null)
                .child(DockLayout.tabs().panel(beta), null), window, acx));
            beta;
        });

        final visible = (ix:Int) -> {
            final node = childNode(s.area, ix, s.cx);
            s.cx.update((_, cx) -> {
                final area = s.area.read(cx);
                area.isNodeVisible(area.layout(DockPlacement.Center).findNode(node), cx);
            });
        };

        assertTrue(visible(0) && visible(1));

        s.cx.update((_, cx) -> beta.update(cx, (beta, pcx) -> beta.setVisible(false, pcx)));

        assertTrue(visible(0), 'the visible group still holds its slot');
        assertFalse(visible(1), 'a group whose every panel is hidden must give its slot up');
    }

    function testALockedAreaSealsItsGroups() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();

        final node = childNode(t.area, 0, t.cx);
        final group = t.cx.update((_, cx) -> t.area.read(cx).groups.get(node.asU64()).entity);
        assertTrue(t.cx.update((_, cx) -> group.read(cx).isClosable(cx)), 'an unlocked group\'s panel can be closed');

        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.setLocked(true, window, acx)));

        assertFalse(t.cx.update((_, cx) -> group.read(cx).isClosable(cx)), 'the lock reaches every group through the constraints push');
    }

    // The tests below were ported by gpui-kit from the old `TabPanel` tests
    // when the dock skin was rebuilt on this crate.

    /**
     * An empty `StackPanel` used to dump as `PanelInfo::Panel`, the
     * `PanelState` default, so restoring looked it up in `PanelRegistry` and
     * failed.
     */
    function testEmptyCenterRoundTripsAsAStack() {
        final s = setup_();
        final center = dump(s.area, s.cx).center;

        assertEquals('StackPanel', center.panelName);
        assertTrue(center.info.match(Stack(_, _)), 'got ${center.info.describe()}');
    }

    function testFreshCenterIsEmpty() {
        final s = setup_();
        assertTrue(isCenterEmpty(s.area, s.cx), 'DockArea.new starts with an empty split centre');
    }

    function testCenterHoldingATabGroupIsNotEmpty() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B'], null);
        o.cx.runUntilParked();

        assertFalse(isCenterEmpty(o.area, o.cx));
    }

    /**
     * The tree still lists the group's node here until the last panel goes,
     * so anything reading node counts rather than panels would report
     * non-empty.
     */
    function testCenterIsEmptyAgainOnceEveryPanelIsRemoved() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B'], null);
        o.cx.runUntilParked();

        for (panel in o.panels) {
            o.cx.update((window, cx) -> o.area.update(cx, (area, acx) -> area.removePanel(panel, window, acx)));
        }
        o.cx.runUntilParked();

        assertTrue(isCenterEmpty(o.area, o.cx));
    }

    function testCenterIsNotEmptyAfterAddingToATabGroup() {
        final s = setup_();
        assertTrue(isCenterEmpty(s.area, s.cx));

        s.cx.update((window, cx) -> {
            final alpha = TestPanel.create('Alpha', cx);
            s.area.update(cx, (area, acx) -> area.addPanel(alpha, DockPlacement.Center, null, window, acx));
        });
        s.cx.runUntilParked();

        assertFalse(isCenterEmpty(s.area, s.cx));
    }

    /**
     * The pre-wrapped companion of `addPanel`, for a layer that hands base its
     * own handle. The panel it registers is the very handle it was given,
     * keyed by the id that handle reports.
     */
    function testAddPanelViewRegistersTheHandleItWasGiven() {
        final s = setup_();

        final view = s.cx.update((window, cx) -> {
            final view:PanelView = new EntityPanelView(TestPanel.create('Alpha', cx));
            s.area.update(cx, (area, acx) -> area.addPanelView(view, DockPlacement.Center, null, window, acx));
            view;
        });
        s.cx.runUntilParked();

        final id = s.cx.update((_, cx) -> view.panelId(cx));
        assertTrue(s.cx.update((_, cx) -> s.area.read(cx).panel(id) == view), 'the stored handle is the one that was handed over, under its own id');
        assertFalse(isCenterEmpty(s.area, s.cx));
    }

    /**
     * Rendering skips invisible panels, so a centre holding only hidden ones
     * draws nothing and counts as empty.
     */
    function testCenterHoldingOnlyHiddenPanelsIsEmpty() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B'], null);
        o.cx.runUntilParked();
        assertFalse(isCenterEmpty(o.area, o.cx));

        o.cx.update((_, cx) -> for (panel in o.panels) panel.update(cx, (panel, pcx) -> panel.setVisible(false, pcx)));
        o.cx.runUntilParked();

        assertEquals(2, o.cx.update((_, cx) -> o.area.read(cx).layout(DockPlacement.Center).panels().length), 'hiding a panel does not remove it from the tab group');
        assertTrue(isCenterEmpty(o.area, o.cx));
    }

    function testSinglePanelGroupReceivesInitialActive() {
        final log = new DockLog();
        final o = oneGroup(log, ['A'], null);
        o.cx.runUntilParked();

        assertEquals('A true', log.drainActive().join(', '));
    }

    function testMultiTabConstructionNotifiesOnlyDisplayedPanel() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B', 'C'], null);
        o.cx.runUntilParked();

        // No false-then-true flip on A, no duplicate true, B/C silent.
        assertEquals('A true', log.drainActive().join(', '));
    }

    function testActiveIndexRestoreNotifiesThatPanelOnly() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B', 'C'], 2);
        o.cx.runUntilParked();

        assertEquals('C true', log.drainActive().join(', '));
    }

    function testSwitchingTabsSendsFalseThenTrue() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B'], null);
        o.cx.runUntilParked();
        log.drain();

        final group = groupOf(o.area, 0, o.cx);
        o.cx.update((window, cx) -> group.update(cx, (group, gcx) -> group.selectTab(1, window, gcx)));
        o.cx.runUntilParked();

        assertEquals('A false, B true', log.drainActive().join(', '));
    }

    function testSelectPanelDisplaysThatTabWhereItSits() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B', 'C'], null);
        o.cx.runUntilParked();
        log.drain();

        final b = panelIdOf(o.panels[1]);
        o.cx.update((window, cx) -> o.area.update(cx, (area, acx) -> area.selectPanel(b, window, acx)));
        o.cx.runUntilParked();

        assertEquals('A false, B true', log.drainActive().join(', '));
        final result = o.cx.update((_, cx) -> {
            final tree = o.area.read(cx).layout(DockPlacement.Center);
            final node = tree.findPanelNode(b);
            switch tree.findNode(node).kind() {
                case Tabs(panels, activeIx): {order: [for (panel in panels) panel.asU64()].join(','), activeIx: activeIx};
                case _: throw 'a tab group';
            }
        });
        assertEquals(1, result.activeIx, 'the selected tab is displayed');
        assertEquals([for (panel in o.panels) panelIdOf(panel).asU64()].join(','), result.order, 'selecting a tab does not move it');
    }

    function testSelectPanelIsSilentForTheDisplayedOrAnUnknownPanel() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B'], null);
        o.cx.runUntilParked();
        log.drain();

        final a = panelIdOf(o.panels[0]);
        final stranger = o.cx.update((_, cx) -> panelIdOf(TestPanel.logging('Z', log, cx)));
        o.cx.update((window, cx) -> o.area.update(cx, (area, acx) -> {
            area.selectPanel(a, window, acx);
            area.selectPanel(stranger, window, acx);
        }));
        o.cx.runUntilParked();

        assertEquals('', log.drainActive().join(', '));
    }

    function testReselectingActiveTabStaysSilent() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B'], null);
        o.cx.runUntilParked();
        log.drain();

        final group = groupOf(o.area, 0, o.cx);
        o.cx.update((window, cx) -> group.update(cx, (group, gcx) -> group.selectTab(0, window, gcx)));
        o.cx.runUntilParked();

        assertEquals('', log.drainActive().join(', '));
    }

    /**
     * The tree API inserts a panel that is already in the dock, so `C`
     * arrives from a second group, where it was a background tab and so has
     * been told nothing: a genuine activation rather than a seeded handoff.
     */
    function testInsertingAtActiveIxSwapsNotifications() {
        final log = new DockLog();
        final s = setup_();
        final c = s.cx.update((window, cx) -> {
            final a = TestPanel.logging('A', log, cx);
            final b = TestPanel.logging('B', log, cx);
            final x = TestPanel.logging('X', log, cx);
            final c = TestPanel.logging('C', log, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(a).panel(b), null)
                .child(DockLayout.tabs().panel(x).panel(c), null), window, acx));
            c;
        });
        s.cx.runUntilParked();
        log.drain();

        final destination = childNode(s.area, 0, s.cx);
        final cId = panelIdOf(c);
        movePanelInto(s.area, cId, destination, 0, true, s.cx);

        assertEquals('A false, C true', log.drainActive().join(', '));
        final group = groupOf(s.area, 0, s.cx);
        assertEquals(0, s.cx.update((_, cx) -> group.read(cx).activeIx()));
        assertEquals(cId, s.cx.update((_, cx) -> group.read(cx).panels()[0].panelId(cx)), 'the arriving panel took the slot it named');
    }

    function testRemovingBeforeActiveKeepsDisplayedPanel() {
        final log = new DockLog();
        final o = oneGroup(log, ['A', 'B', 'C'], null);
        final group = groupOf(o.area, 0, o.cx);
        o.cx.update((window, cx) -> group.update(cx, (group, gcx) -> group.selectTab(1, window, gcx)));
        o.cx.runUntilParked();
        log.drain();

        o.cx.update((window, cx) -> o.area.update(cx, (area, acx) -> area.removePanel(o.panels[0], window, acx)));
        o.cx.runUntilParked();

        assertEquals('', log.drainActive().join(', '));
        assertEquals(0, o.cx.update((_, cx) -> group.read(cx).activeIx()));
        assertEquals(panelIdOf(o.panels[1]), o.cx.update((_, cx) -> group.read(cx).panels()[0].panelId(cx)),
            'the same panel is still displayed, at its new index');
    }

    /**
     * Collapsing is now a dock closing, which is what
     * `TabGroupConstraints.collapsed` carries.
     */
    function testCollapseAndExpandNotifyActivePanel() {
        final log = new DockLog();
        final s = setup_();
        s.cx.update((window, cx) -> {
            final a = TestPanel.logging('A', log, cx);
            final b = TestPanel.logging('B', log, cx);
            s.area.update(cx, (area, acx) -> area.setDock(DockPlacement.Left, DockLayout.tabs().panel(a).panel(b), window, acx));
        });
        s.cx.runUntilParked();
        log.drain();

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.toggleDock(DockPlacement.Left, window, acx)));
        s.cx.runUntilParked();
        assertEquals('A false', log.drainActive().join(', '));

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.toggleDock(DockPlacement.Left, window, acx)));
        s.cx.runUntilParked();
        assertEquals('A true', log.drainActive().join(', '));
    }

    function testBackgroundAddIsSilentButFirstPanelIsNot() {
        final log = new DockLog();
        final s = setup_();
        final d = s.cx.update((window, cx) -> {
            final a = TestPanel.logging('A', log, cx);
            final b = TestPanel.logging('B', log, cx);
            final c = TestPanel.logging('C', log, cx);
            final d = TestPanel.logging('D', log, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(a).panel(b), null)
                .child(DockLayout.tabs().panel(c).panel(d), null), window, acx));
            d;
        });
        s.cx.runUntilParked();
        log.drain();

        // D is a background tab in its own group and arrives as a background
        // tab in the other one, so nothing changes for anybody.
        final destination = childNode(s.area, 0, s.cx);
        movePanelInto(s.area, panelIdOf(d), destination, null, false, s.cx);
        assertEquals('', log.drainActive().join(', '));

        // The first panel of a region that had none is displayed regardless,
        // so it must be told.
        s.cx.update((window, cx) -> {
            final e = TestPanel.logging('E', log, cx);
            s.area.update(cx, (area, acx) -> area.addPanel(e, DockPlacement.Left, null, window, acx));
        });
        s.cx.runUntilParked();
        assertEquals('E true', log.drainActive().join(', '));
    }

    function testDragActivePanelToOtherGroupStaysSilentForIt() {
        final log = new DockLog();
        final s = setup_();
        final a = s.cx.update((window, cx) -> {
            final a = TestPanel.logging('A', log, cx);
            final b = TestPanel.logging('B', log, cx);
            final c = TestPanel.logging('C', log, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(a).panel(b), null)
                .child(DockLayout.tabs().panel(c), null), window, acx));
            a;
        });
        s.cx.runUntilParked();
        log.drain();

        // A was already told `true`; becoming the target's displayed tab must
        // not repeat it.
        final destination = childNode(s.area, 1, s.cx);
        movePanelInto(s.area, panelIdOf(a), destination, null, true, s.cx);

        // Two groups reconcile independently, so their deliveries interleave
        // in no guaranteed order; what is pinned is which ones happen.
        final seen = log.drainActive();
        assertTrue(seen.contains('B true'), 'got $seen');
        assertTrue(seen.contains('C false'), 'got $seen');
        for (entry in seen) assertFalse(StringTools.startsWith(entry, 'A '), 'the moved panel was displayed before and after: $seen');
    }

    function testDragActivePanelToBackgroundSlotDeactivatesIt() {
        final log = new DockLog();
        final s = setup_();
        final a = s.cx.update((window, cx) -> {
            final a = TestPanel.logging('A', log, cx);
            final c = TestPanel.logging('C', log, cx);
            final d = TestPanel.logging('D', log, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(a), null)
                .child(DockLayout.tabs().panel(c).panel(d), null), window, acx));
            a;
        });
        s.cx.runUntilParked();
        log.drain();

        // A was told `true` and becomes a background tab, so it gets one
        // `false`.
        final destination = childNode(s.area, 1, s.cx);
        movePanelInto(s.area, panelIdOf(a), destination, null, false, s.cx);

        assertEquals('A false', log.drainActive().join(', '));
    }

    // Adapted from gpui-kit's `crates/kit/tests/integration/dock.rs`, which
    // drives the styled `DockSkin`: here the bare area, whose tab group
    // tracks the displayed panel's focus handle on its frame.

    function twoTabs():{area:Entity<DockArea>, alpha:Entity<TestPanel>, beta:Entity<TestPanel>, elsewhere:FocusHandle, cx:VisualTestContext} {
        app.update(cx -> Theme.globalMut(cx));
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<TwoTabsView>) -> new TwoTabsView(window, cx));
        contexts.push(opened.cx);
        final view = opened.view;
        final cx = opened.cx;
        final panels = cx.update((window, cx) -> {
            final alpha = TestPanel.create('alpha', cx);
            final beta = TestPanel.create('beta', cx);
            view.read(cx).area.update(cx, (area, acx) -> area.setCenter(DockLayout.tabs().panel(alpha).panel(beta), window, acx));
            {alpha: alpha, beta: beta};
        });
        return {area: cx.update((_, cx) -> view.read(cx).area), alpha: panels.alpha, beta: panels.beta, elsewhere: cx.update((_, cx) -> view.read(cx).elsewhere), cx: cx};
    }

    function testDockHandsTheFocusToTheTabThatReplacesAClosedOne() {
        final t = twoTabs();
        t.cx.update((window, _) -> window.draw());
        t.cx.update((window, cx) -> t.alpha.read(cx).focusHandle(cx).focus(window, cx));
        t.cx.update((window, _) -> window.draw());
        assertTrue(t.cx.update((window, cx) -> t.alpha.read(cx).focusHandle(cx).isFocused(window)));

        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.removePanel(t.alpha, window, acx)));
        t.cx.update((window, _) -> window.draw());
        assertTrue(t.cx.update((window, cx) -> t.beta.read(cx).focusHandle(cx).isFocused(window)),
            'closing the focused tab must leave the keyboard on the one shown in its place');
    }

    function testDockLeavesTheFocusAloneWhenATabWithoutItCloses() {
        final t = twoTabs();
        t.cx.update((window, _) -> window.draw());
        t.cx.update((window, cx) -> t.elsewhere.focus(window, cx));
        t.cx.update((window, _) -> window.draw());

        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.removePanel(t.alpha, window, acx)));
        t.cx.update((window, _) -> window.draw());
        assertTrue(t.cx.update((window, _) -> t.elsewhere.isFocused(window)));
    }

    /**
     * `setup` with a skin that records the tab bars drawn.
     */
    function setupRecording():{area:Entity<DockArea>, tabBars:Array<NodeId>, cx:VisualTestContext} {
        app.update(cx -> Theme.globalMut(cx));
        final tabBars:Array<NodeId> = [];
        final s = open(new RecordingSkin(tabBars));
        return {area: s.area, tabBars: tabBars, cx: s.cx};
    }

    /**
     * The regression this exists for: zooming shows the group, tab bar and
     * all, not the panel inside it. Only the tab bar tells the two apart.
     */
    function testAZoomedGroupIsDrawnWholeRatherThanAsItsBarePanel() {
        final log = new DockLog();
        final r = setupRecording();
        r.cx.update((window, cx) -> {
            final alpha = TestPanel.logging('Alpha', log, cx);
            final beta = TestPanel.logging('Beta', log, cx);
            r.area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), null)
                .child(DockLayout.tabs().panel(beta), null), window, acx));
        });
        r.cx.runUntilParked();

        final zoomed = childNode(r.area, 0, r.cx);
        final other = childNode(r.area, 1, r.cx);
        assertTrue(r.tabBars.contains(zoomed) && r.tabBars.contains(other), 'both groups draw their own tab bar while nothing is zoomed');

        r.tabBars.resize(0);
        final group = groupOf(r.area, 0, r.cx);
        r.cx.update((window, cx) -> group.update(cx, (group, gcx) -> group.toggleZoom(window, gcx)));
        r.cx.runUntilParked();

        assertTrue(r.tabBars.contains(zoomed),
            'a zoomed group is rendered whole: its own tab bar is still drawn, which is exactly what the bare panel does not carry');
        assertFalse(r.tabBars.contains(other), 'and it is the only thing on screen');
    }

    /**
     * The area's zoom and the container's own flag are written together, so
     * neither can be left believing something the other does not.
     */
    function testClearingTheZoomFromOutsidePutsTheGroupsOwnFlagBack() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        log.drain();

        final node = childNode(t.area, 0, t.cx);
        final group = groupOf(t.area, 0, t.cx);
        t.cx.update((window, cx) -> group.update(cx, (group, gcx) -> group.toggleZoom(window, gcx)));
        t.cx.runUntilParked();
        assertEquals(node, t.cx.update((_, cx) -> t.area.read(cx).zoomedGroup()));
        assertTrue(t.cx.update((_, cx) -> group.read(cx).isZoomed()));
        assertEquals('Alpha true', log.drainZoomed().join(', '));

        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.setZoomedOut(window, acx)));
        t.cx.runUntilParked();

        assertFalse(t.cx.update((_, cx) -> t.area.read(cx).isZoomed()));
        assertFalse(t.cx.update((_, cx) -> group.read(cx).isZoomed()), 'a group left flagged zoomed would stay locked and refuse every drop');
        assertTrue(t.cx.update((_, cx) -> group.read(cx).context(cx).isDroppable()), 'and the lock the zoom imposed is lifted with it');
        assertEquals('Alpha false', log.drainZoomed().join(', '), 'the panel hears the zoom end too, not just the group');
    }

    /**
     * A group that refuses to zoom must not leave the area showing it as
     * zoomed: the area records a zoom only once the container agrees.
     */
    function testAGroupThatRefusesToZoomLeavesTheAreaUnzoomed() {
        final log = new DockLog();
        final t = twoGroups(log);
        t.cx.runUntilParked();
        t.cx.update((_, cx) -> t.alpha.update(cx, (panel, pcx) -> panel.setZoomable(false, pcx)));

        final node = childNode(t.area, 0, t.cx);
        final group = groupOf(t.area, 0, t.cx);
        t.cx.update((window, cx) -> t.area.update(cx, (area, acx) -> area.setZoomedIn(node, window, acx)));
        t.cx.runUntilParked();

        assertFalse(t.cx.update((_, cx) -> group.read(cx).isZoomed()));
        assertFalse(t.cx.update((_, cx) -> t.area.read(cx).isZoomed()), 'the area must not fill itself with a group that never zoomed');
    }

}

/**
 * A panel that draws a measurable box, so a test can read where a slot
 * actually landed rather than what `ResizableState` believes about it.
 */
private class MeasuredPanel extends PanelBase {

    final name:String;

    final focus:FocusHandle;

    public function new(name:String, cx:Context<MeasuredPanel>) {
        super();
        this.name = name;
        this.focus = cx.focusHandle();
    }

    public static function create(name:String, cx:App):Entity<MeasuredPanel> {
        return cx.newEntity((pcx:Context<MeasuredPanel>) -> new MeasuredPanel(name, pcx));
    }

    public function panelName():String {
        return name;
    }

    public function focusHandle(cx:App):FocusHandle {
        return focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new DebugProbe(name, div().sizeFull());
    }

}

/**
 * The skin's stand-in for a panel this build cannot construct. It keeps the
 * original state, which is the obligation `buildPlaceholder` documents.
 */
private class SkinPlaceholder extends PanelBase {

    final state:PanelState;

    final focus:FocusHandle;

    public function new(state:PanelState, cx:Context<SkinPlaceholder>) {
        super();
        this.state = state;
        this.focus = cx.focusHandle();
    }

    public function panelName():String {
        return 'SkinPlaceholder';
    }

    override public function dump(cx:App):PanelState {
        return state.clone();
    }

    public function focusHandle(cx:App):FocusHandle {
        return focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new gpui.Empty();
    }

}

private class PlaceholderSkin extends DockAreaRendererBase {

    final asked:Array<String>;

    public function new(asked:Array<String>) {
        super();
        this.asked = asked;
    }

    override public function buildPlaceholder(state:PanelState, window:Window, cx:App):Null<PanelView> {
        asked.push(state.panelName);
        final copy = state.clone();
        return new EntityPanelView(cx.newEntity((pcx:Context<SkinPlaceholder>) -> new SkinPlaceholder(copy, pcx)));
    }

    public function tabGroupRenderer():TabGroupRenderer {
        return new gpui.base.dock.BareTabGroup();
    }

}

/**
 * A skin that records what it was asked to draw. The chrome is the point: a
 * tab bar is drawn by the group, and it does not run if the area renders the
 * bare panel instead.
 */
private class RecordingSkin extends DockAreaRendererBase {

    final tabBars:Array<NodeId>;

    public function new(tabBars:Array<NodeId>) {
        super();
        this.tabBars = tabBars;
    }

    public function tabGroupRenderer():TabGroupRenderer {
        return new RecordingTabGroup(tabBars);
    }

}

private class RecordingTabGroup extends TabGroupRendererBase {

    final drawn:Array<NodeId>;

    public function new(drawn:Array<NodeId>) {
        super();
        this.drawn = drawn;
    }

    public function renderTabBar(group:TabGroupContext, window:Window, cx:App):AnyElement {
        drawn.push(group.node());
        return new gpui.Empty().intoAnyElement();
    }

}

/**
 * A 20 pixel strip tracking `elsewhere` above the dock area (the
 * integration tests' `TwoTabs` view).
 */
private class TwoTabsView extends gpui.Model implements gpui.Render {

    public final area:Entity<DockArea>;

    public final elsewhere:FocusHandle;

    public function new(window:Window, cx:Context<TwoTabsView>) {
        super();
        this.area = cx.newEntity((acx:Context<DockArea>) -> new DockArea('editor', null, window, acx));
        this.elsewhere = cx.focusHandle();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(div().trackFocus(elsewhere).h(px(20.))).child(area);
    }

}

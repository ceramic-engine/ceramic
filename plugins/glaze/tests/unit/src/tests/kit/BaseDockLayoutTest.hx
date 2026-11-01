// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/tree.rs (tests), crates/base/src/dock/layout/edit.rs (tests),
// crates/base/src/dock/layout/normalize.rs (tests), crates/base/src/dock/layout/builder.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Axis;
import gpui.Pixels;
import gpui.TestDispatcher;
import gpui.base.Geometry.Placement;
import gpui.base.dock.DockLayout;
import gpui.base.dock.InsertTarget;
import gpui.base.dock.NodeId;
import gpui.base.dock.PaneNode;
import gpui.base.dock.PaneTree;
import gpui.base.dock.PanelId;
import gpui.base.dock.RootKind;
import tests.kit.DockTestSupport;
import testing.TestCase;

/**
 * The `#[cfg(test)]` tests of gpui-base's dock layout tree: `tree.rs`,
 * `edit.rs`, `normalize.rs` and `builder.rs`.
 */
@:access(gpui.base.dock.PaneTree)
class BaseDockLayoutTest extends TestCase {

    static function panel(n:Int):PanelId {
        return PanelId.fromU64(n);
    }

    static function panelsString(panels:Array<PanelId>):String {
        return [for (panel in panels) panel.asU64()].join(',');
    }

    static function sizesString(sizes:Array<Null<Pixels>>):String {
        return [for (size in sizes) size == null ? 'None' : Std.string((size : Float))].join(',');
    }

    static function tabs(node:PaneNode):{panels:Array<PanelId>, activeIx:Int} {
        return switch node.kind() {
            case Tabs(panels, activeIx): {panels: panels, activeIx: activeIx};
            case Split(_, _, _): throw 'expected a tab group';
        }
    }

    static function split(node:PaneNode):{axis:Axis, children:Array<PaneNode>, sizes:Array<Null<Pixels>>} {
        return switch node.kind() {
            case Split(axis, children, sizes): {axis: axis, children: children, sizes: sizes};
            case Tabs(_, _): throw 'expected a split';
        }
    }

/// tree.rs

    function testAFreshSplitRootTreeHasNoPanels() {
        final tree = new PaneTree(RootKind.Split);
        assertEquals(0, split(tree.root()).children.length);
        assertEquals(0, tree.panels().length);
    }

    function testNodeIdsAreUniqueAndResolvable() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        final tabs = tree.pushTabsForTest(root, [panel(1)]);
        assertTrue(tabs != tree.root().id());
        assertNotNull(tree.findNode(tabs));
        assertEquals(tabs, tree.findPanelNode(panel(1)));
    }

/// edit.rs

    static function treeWithOneGroup():{tree:PaneTree, tabs:NodeId} {
        final tree = new PaneTree(RootKind.Split);
        final tabs = tree.pushTabsForTest(tree.root().id(), [panel(1)]);
        tree.normalize();
        return {tree: tree, tabs: tabs};
    }

    function testInsertingIntoATabGroupAppendsAndCanActivate() {
        final t = treeWithOneGroup();
        final result = t.tree.insertPanel(panel(2), InsertTarget.Tabs(t.tabs, null, true));

        assertTrue(result.changed());
        final group = tabs(t.tree.findNode(t.tabs));
        assertEquals('1,2', panelsString(group.panels));
        assertEquals(1, group.activeIx, 'the inserted panel becomes the displayed one');
    }

    function testABackgroundInsertLeavesTheActivePanelAlone() {
        final t = treeWithOneGroup();
        final result = t.tree.insertPanel(panel(2), InsertTarget.Tabs(t.tabs, null, false));

        assertTrue(result.changed());
        final group = tabs(t.tree.findNode(t.tabs));
        assertEquals('1,2', panelsString(group.panels));
        assertEquals(0, group.activeIx, 'the displayed panel is left alone');
    }

    function testRemovingTheLastPanelCollapsesTheGroupAndReportsIt() {
        final t = treeWithOneGroup();
        final result = t.tree.removePanel(panel(1));

        assertTrue(result.changed());
        assertFalse(t.tree.containsPanel(panel(1)), 'the panel left the tree');
        assertNull(t.tree.findNode(t.tabs), 'its empty group collapsed');
        assertEquals(0, split(t.tree.root()).children.length);
    }

    function testSplittingCreatesASiblingGroupOnTheRequestedSide() {
        final t = treeWithOneGroup();
        final result = t.tree.split(t.tabs, panel(2), Placement.Right, 240.);

        assertTrue(result.changed());
        final root = split(t.tree.root());
        assertEquals(Axis.Horizontal, root.axis);
        assertEquals(2, root.children.length);
        assertEquals(240., (root.sizes[1] : Float));
        assertEquals('1', panelsString(tabs(root.children[0]).panels));
        assertEquals('2', panelsString(tabs(root.children[1]).panels));
    }

    function testSplittingLeftPutsTheNewGroupFirst() {
        final t = treeWithOneGroup();
        t.tree.split(t.tabs, panel(2), Placement.Left, null);

        final root = split(t.tree.root());
        assertEquals('2', panelsString(tabs(root.children[0]).panels));
    }

    function testSplittingAcrossTheParentAxisNestsANewSplit() {
        final t = treeWithOneGroup();
        t.tree.pushTabsForTest(t.tree.root().id(), [panel(9)]);
        t.tree.normalize();

        t.tree.split(t.tabs, panel(2), Placement.Bottom, null);

        final root = split(t.tree.root());
        assertEquals(Axis.Horizontal, root.axis);
        final inner = split(root.children[0]);
        assertEquals(Axis.Vertical, inner.axis);
        assertEquals(2, inner.children.length);
        // `Bottom` puts the new group after the original target.
        assertEquals('1', panelsString(tabs(inner.children[0]).panels), 'the original target stays first');
        assertEquals('2', panelsString(tabs(inner.children[1]).panels), 'the new group lands second, below');
    }

    function testSplittingTopAcrossTheParentAxisPutsTheNewGroupFirst() {
        final t = treeWithOneGroup();
        t.tree.pushTabsForTest(t.tree.root().id(), [panel(9)]);
        t.tree.normalize();

        t.tree.split(t.tabs, panel(2), Placement.Top, null);

        final root = split(t.tree.root());
        final inner = split(root.children[0]);
        assertEquals(Axis.Vertical, inner.axis);
        assertEquals(2, inner.children.length);
        assertEquals('2', panelsString(tabs(inner.children[0]).panels), 'the new group lands first, above');
        assertEquals('1', panelsString(tabs(inner.children[1]).panels), 'the original target moves second');
    }

    function testTheSplitTargetKeepsItsNodeIdSoItsEntitySurvives() {
        final t = treeWithOneGroup();
        t.tree.split(t.tabs, panel(2), Placement.Right, null);

        assertNotNull(t.tree.findNode(t.tabs), 'the target group is reused, not rebuilt');
    }

    function testMovingAPanelBetweenGroupsPreservesItsIdentity() {
        final t = treeWithOneGroup();
        assertTrue(t.tree.split(t.tabs, panel(2), Placement.Right, null).changed());
        final other = t.tree.findPanelNode(panel(2));
        assertNotNull(other, 'the split put panel 2 in a group of its own');

        final result = t.tree.movePanel(panel(1), InsertTarget.Tabs(other, null, true));

        assertTrue(result.changed());
        assertEquals('2,1', panelsString(t.tree.panels()), 'a move is not a removal; both panels are still in the tree');
        assertNull(t.tree.findNode(t.tabs), 'the emptied group collapses');
    }

    function testANoOpEditReportsNoChange() {
        final t = treeWithOneGroup();
        final result = t.tree.setActive(t.tabs, 0);
        assertFalse(result.changed());
    }

    function testSetSizesReplacesAMatchingLengthVector() {
        final t = treeWithOneGroup();
        t.tree.split(t.tabs, panel(2), Placement.Right, null);
        final root = t.tree.root().id();

        final result = t.tree.setSizes(root, [100., 200.]);

        assertTrue(result.changed());
        assertEquals('100,200', sizesString(split(t.tree.root()).sizes));
    }

    function testSetSizesIgnoresAMismatchedLengthVector() {
        final t = treeWithOneGroup();
        t.tree.split(t.tabs, panel(2), Placement.Right, null);
        final root = t.tree.root().id();
        final before = sizesString(split(t.tree.root()).sizes);

        // The split has 2 children; hand it 3 sizes.
        final result = t.tree.setSizes(root, [10., 20., 30.]);

        assertFalse(result.changed(), 'a mismatched vector must not report a change');
        assertEquals(before, sizesString(split(t.tree.root()).sizes), 'the mismatched vector is rejected');
    }

    function testEveryEditLeavesTheTreeNormalized() {
        final t = treeWithOneGroup();
        t.tree.split(t.tabs, panel(2), Placement.Bottom, null);
        t.tree.insertPanel(panel(3), InsertTarget.Tabs(t.tabs, null, false));
        t.tree.removePanel(panel(2));
        t.tree.removePanel(panel(3));

        assertTrue(t.tree.isNormalized());
    }

/// normalize.rs

    function testEmptyTabGroupsAreDropped() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        tree.pushTabsForTest(root, []);
        tree.pushTabsForTest(root, [panel(1)]);

        tree.normalize();

        // The empty tab group is dropped by rule 1, leaving the root split
        // holding the one surviving child.
        assertEquals(1, split(tree.root()).children.length);
        assertEquals('1', panelsString(tree.panels()));
    }

    function testASingleChildSplitIsReplacedByItsChildKeepingTheChildId() {
        final tree = new PaneTree(RootKind.Any);
        final outer = tree.setRootSplitForTest(Axis.Horizontal);
        final inner = tree.pushSplitForTest(outer, Axis.Vertical, 120.);
        final tabs = tree.pushTabsForTest(inner, [panel(1)]);

        tree.normalize();

        assertEquals(tabs, tree.root().id(), 'child keeps its own NodeId');
        assertNull(tree.findNode(inner));
    }

    function testACollapsingSplitHandsItsSlotSizeToTheChild() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        final inner = tree.pushSplitForTest(root, Axis.Vertical, 300.);
        tree.pushTabsForTest(inner, [panel(1)]);
        tree.pushTabsForTest(root, [panel(2)]);

        tree.normalize();

        assertEquals(300., (split(tree.root()).sizes[0] : Float), 'the child inherits the collapsed split\'s slot');
    }

    function testSameAxisNestingIsSplicedIntoTheParent() {
        final tree = new PaneTree(RootKind.Split);
        tree.setRootAxisForTest(Axis.Horizontal);
        final root = tree.root().id();
        tree.pushTabsForTest(root, [panel(1)]);
        final inner = tree.pushSplitForTest(root, Axis.Horizontal, null);
        tree.pushTabsForTest(inner, [panel(2)]);
        tree.pushTabsForTest(inner, [panel(3)]);

        tree.normalize();

        final r = split(tree.root());
        assertEquals(Axis.Horizontal, r.axis);
        assertEquals(3, r.children.length, 'the inner split\'s children are spliced in');
        assertEquals('1,2,3', panelsString(tree.panels()), 'order is preserved');
    }

    function testActiveIndexIsClampedToThePanelCount() {
        final tree = new PaneTree(RootKind.Any);
        final tabsId = tree.setRootTabsForTest([panel(1), panel(2)], 9);

        tree.normalize();

        assertEquals(1, tabs(tree.findNode(tabsId)).activeIx);
    }

    function testASplitRootSurvivesBeingEmptied() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        tree.pushTabsForTest(root, []);

        tree.normalize();

        assertEquals(0, split(tree.root()).children.length, 'the center must still serialize as a StackPanel when empty');
    }

    /**
     * Rule 3 splices a same-axis child's slots into the parent, scaling them
     * to the slot they replace. When one inner slot is unconstrained there is
     * no total to scale against, so they pass through.
     */
    function testASameAxisSpliceWithOneUnknownInnerSizePassesThemThrough() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        final inner = tree.pushSplitForTest(root, Axis.Horizontal, 400.);
        tree.pushSizedTabsForTest(inner, [panel(1)], 100.);
        tree.pushSizedTabsForTest(inner, [panel(2)], null);

        tree.normalize();

        assertEquals('100,None', sizesString(split(tree.root()).sizes),
            'an unknown inner size leaves every sibling unscaled; the 400px slot they replaced constrains nothing');
    }

    /**
     * Dropping a container mid-row hands its space to nobody in the tree:
     * the surviving slots keep their absolute sizes.
     */
    function testRemovingAMiddleContainerLeavesItsSiblingsUntouched() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        tree.pushSizedTabsForTest(root, [panel(1)], 400.);
        tree.pushSizedTabsForTest(root, [], 800.);
        tree.pushSizedTabsForTest(root, [panel(3)], 400.);

        tree.normalize();

        final r = split(tree.root());
        assertEquals(2, r.children.length);
        assertEquals('400,400', sizesString(r.sizes),
            'the survivors keep their own sizes; the 800px the empty group held is not handed to either of them here');
    }

    function testNormalizeIsIdempotent() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        final inner = tree.pushSplitForTest(root, Axis.Horizontal, null);
        tree.pushTabsForTest(inner, [panel(1)]);
        tree.pushTabsForTest(inner, []);
        tree.pushTabsForTest(root, [panel(2)]);

        tree.normalize();
        final once = tree.clone();
        tree.normalize();

        assertTrue(once.equals(tree));
    }

    function testSameAxisSpliceScalesInnerSizesToFillTheOuterSlot() {
        final tree = new PaneTree(RootKind.Split);
        final root = tree.root().id();
        final inner = tree.pushSplitForTest(root, Axis.Horizontal, 400.);
        tree.pushSizedTabsForTest(inner, [panel(1)], 50.);
        tree.pushSizedTabsForTest(inner, [panel(2)], 150.);

        tree.normalize();

        final sizes = split(tree.root()).sizes;
        assertEquals('100,300', sizesString(sizes), 'sizes scale by the outer/inner ratio (400/200 = 2x), not by its reverse');
        var total = 0.;
        for (size in sizes) total += size;
        assertEquals(400., total, 'the scaled sizes sum back to the outer slot');
    }

    function testNormalizeConvergesWithinTwoPassesOnAnAdversarialTree() {
        // root(H) -> D(V) -> A(H) -> { empty, B(V) -> C(V) -> [leaf1, leaf2] }
        final tree = new PaneTree(RootKind.Any);
        final root = tree.root().id();
        final d = tree.pushSplitForTest(root, Axis.Vertical, null);
        final a = tree.pushSplitForTest(d, Axis.Horizontal, null);
        tree.pushTabsForTest(a, []);
        final b = tree.pushSplitForTest(a, Axis.Vertical, null);
        final c = tree.pushSplitForTest(b, Axis.Vertical, null);
        tree.pushTabsForTest(c, [panel(1)]);
        tree.pushTabsForTest(c, [panel(2)]);

        final passes = tree.normalizePassCountForTest();

        assertTrue(passes <= 2, 'expected the fixpoint within 2 passes, took $passes');
        assertTrue(tree.isNormalized());
        assertEquals('1,2', panelsString(tree.panels()), 'every panel survives the collapse, in order');
    }

/// builder.rs (the panels need an app)

    function withApp<R>(f:App -> R):R {
        final app = new App(new TestDispatcher());
        return app.update(cx -> f(cx));
    }

    function testADescribedSplitLowersToASplitOfTabGroups() {
        final built = withApp(cx -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            PaneTree.fromLayout(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), 300.)
                .child(DockLayout.tabs().panel(beta), null), RootKind.Split);
        });

        assertEquals(2, built.panels.length);
        final root = split(built.tree.root());
        assertEquals(Axis.Horizontal, root.axis);
        assertEquals(2, root.children.length);
        assertEquals('300,None', sizesString(root.sizes));
        assertEquals(1, tabs(root.children[0]).panels.length);
    }

    /**
     * Ported from `DockItem::split_with_sizes_adds_each_child_once`, which
     * guarded a `StackPanel` that once added every child twice.
     */
    function testSplitWithSizesAddsEachChildOnce() {
        final built = withApp(cx -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            PaneTree.fromLayout(DockLayout.hSplit()
                .child(DockLayout.tabs().panel(alpha), null)
                .child(DockLayout.tabs().panel(beta), null), RootKind.Split);
        });

        final root = split(built.tree.root());
        assertEquals(2, root.children.length, 'each described child appears exactly once');
        assertEquals(root.children.length, root.sizes.length);
        assertTrue(root.children[0].id() != root.children[1].id());
    }

    function testABareTabGroupIsWrappedForASplitRoot() {
        final built = withApp(cx -> PaneTree.fromLayout(DockLayout.tabs().panel(TestPanel.create('Alpha', cx)), RootKind.Split));

        split(built.tree.root());
    }

    function testAnActiveIndexSelectsTheDisplayedTab() {
        final built = withApp(cx -> {
            final alpha = TestPanel.create('Alpha', cx);
            final beta = TestPanel.create('Beta', cx);
            PaneTree.fromLayout(DockLayout.tabs().panel(alpha).panel(beta).activeIndex(1), RootKind.Any);
        });

        assertEquals(1, tabs(built.tree.root()).activeIx);
    }

}

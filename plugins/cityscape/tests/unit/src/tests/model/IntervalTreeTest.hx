// Ported from vscode src/vs/editor/test/common/model/intervalTree.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes of this module:
// - IntervalTree1GeneratedTest
// - IntervalTree1SearchingTest
// - IntervalTree2Test

import cityscape.common.Model.TrackedRangeStickiness;
import cityscape.common.model.IntervalTree;
import testing.TestCase;

// vscode's GENERATE_TESTS is false (TEST_COUNT is 0) and PRINT_TREE is false:
// the random test generation (AutoTest, getRandomInt, getRandomRange,
// TestState.getExistingNodeId) and the tree printing helpers are not used
// by any test, so they are not ported.

private class Interval {

    public var start:Int;
    public var end:Int;

    public function new(start:Int, end:Int) {
        this.start = start;
        this.end = end;
    }

}

private class Oracle {

    public var intervals:Array<Interval>;

    public function new() {
        this.intervals = [];
    }

    public function insert(interval:Interval):Interval {
        this.intervals.push(interval);
        this.intervals.sort((a, b) -> {
            if (a.start == b.start) {
                return a.end - b.end;
            }
            return a.start - b.start;
        });
        return interval;
    }

    public function delete(interval:Interval):Void {
        for (i in 0...this.intervals.length) {
            if (this.intervals[i] == interval) {
                this.intervals.splice(i, 1);
                return;
            }
        }
    }

    public function search(interval:Interval):Array<Interval> {
        final result:Array<Interval> = [];
        for (i in 0...this.intervals.length) {
            final int = this.intervals[i];
            if (int.start <= interval.end && int.end >= interval.start) {
                result.push(int);
            }
        }
        return result;
    }

}

/**
 * vscode's `TestState` fields. Its `acceptOp` asserts, so it lives in
 * `IntervalTree1GeneratedTest.acceptOp`.
 */
private class TestState {

    public var oracle:Oracle = new Oracle();
    public var tree:IntervalTree = new IntervalTree();
    public var lastNodeId:Int = -1;
    public var treeNodes:Array<Null<IntervalNode>> = [];
    public var oracleNodes:Array<Null<Interval>> = [];

    public function new() {}

}

/**
 * vscode's `IOperation` union (IInsertOperation | IDeleteOperation |
 * IChangeOperation | ISearchOperation), discriminated by `type`.
 */
private typedef IOperation = {
    var type:String;
    @:optional var id:Int;
    @:optional var begin:Int;
    @:optional var end:Int;
}

/**
 * suite('IntervalTree 1') > suite('generated')
 *
 * Not ported: test('force delta overflow'): its interval offsets
 * (686081138593427...) do not fit in the 32-bit Int offsets of the Haxe
 * IntervalNode.
 */
class IntervalTree1GeneratedTest extends TestCase {

    function acceptOp(state:TestState, op:IOperation):Void {

        if (op.type == 'insert') {
            final nodeId = (++state.lastNodeId);
            state.treeNodes[nodeId] = new IntervalNode(null, op.begin, op.end);
            state.tree.insert(state.treeNodes[nodeId]);
            state.oracleNodes[nodeId] = state.oracle.insert(new Interval(op.begin, op.end));
        }
        else if (op.type == 'delete') {
            final id:Int = op.id; // an Int index: `Null<Int>` cannot index an array on C#
            state.tree.delete(state.treeNodes[id]);
            state.oracle.delete(state.oracleNodes[id]);

            state.treeNodes[id] = null;
            state.oracleNodes[id] = null;
        }
        else if (op.type == 'change') {
            final id:Int = op.id;

            state.tree.delete(state.treeNodes[id]);
            state.treeNodes[id].reset(0, op.begin, op.end, null);
            state.tree.insert(state.treeNodes[id]);

            state.oracle.delete(state.oracleNodes[id]);
            state.oracleNodes[id].start = op.begin;
            state.oracleNodes[id].end = op.end;
            state.oracle.insert(state.oracleNodes[id]);

        }
        else {
            final actualNodes = state.tree.intervalSearch(op.begin, op.end, 0, false, 0, false);
            final actual = actualNodes.map(n -> new Interval(n.cachedAbsoluteStart, n.cachedAbsoluteEnd));
            final expected = state.oracle.search(new Interval(op.begin, op.end));
            assertDeepEquals(actual, expected);
            return;
        }

        assertTreeInvariants(state.tree);

        final actual = state.tree.getAllInOrder().map(n -> new Interval(n.cachedAbsoluteStart, n.cachedAbsoluteEnd));
        final expected = state.oracle.intervals;
        assertDeepEquals(actual, expected);
    }

    function _testIntervalTree(ops:Array<IOperation>):Void {
        final state = new TestState();
        for (i in 0...ops.length) {
            acceptOp(state, ops[i]);
        }
    }

    // #region Assertion

    function assertTreeInvariants(tree:IntervalTree):Void {
        final SENTINEL = tree.SENTINEL;
        assertTrue(IntervalTree.getNodeColor(SENTINEL) == NodeColor.Black);
        assertTrue(SENTINEL.parent == SENTINEL);
        assertTrue(SENTINEL.left == SENTINEL);
        assertTrue(SENTINEL.right == SENTINEL);
        assertTrue(SENTINEL.start == 0);
        assertTrue(SENTINEL.end == 0);
        assertTrue(SENTINEL.delta == 0);
        assertTrue(tree.root.parent == SENTINEL);
        assertValidTree(tree);
    }

    function depth(tree:IntervalTree, n:IntervalNode):Int {
        if (n == tree.SENTINEL) {
            // The leafs are black
            return 1;
        }
        assertTrue(depth(tree, n.left) == depth(tree, n.right));
        return (IntervalTree.getNodeColor(n) == NodeColor.Black ? 1 : 0) + depth(tree, n.left);
    }

    function assertValidNode(tree:IntervalTree, n:IntervalNode, delta:Int):Void {
        final SENTINEL = tree.SENTINEL;
        if (n == SENTINEL) {
            return;
        }

        final l = n.left;
        final r = n.right;

        if (IntervalTree.getNodeColor(n) == NodeColor.Red) {
            assertTrue(IntervalTree.getNodeColor(l) == NodeColor.Black);
            assertTrue(IntervalTree.getNodeColor(r) == NodeColor.Black);
        }

        var expectedMaxEnd = n.end;
        if (l != SENTINEL) {
            assertTrue(IntervalTree.intervalCompare(l.start + delta, l.end + delta, n.start + delta, n.end + delta) <= 0);
            expectedMaxEnd = maxInt(expectedMaxEnd, l.maxEnd);
        }
        if (r != SENTINEL) {
            assertTrue(IntervalTree.intervalCompare(n.start + delta, n.end + delta, r.start + delta + n.delta, r.end + delta + n.delta) <= 0);
            expectedMaxEnd = maxInt(expectedMaxEnd, r.maxEnd + n.delta);
        }
        assertTrue(n.maxEnd == expectedMaxEnd);

        assertValidNode(tree, l, delta);
        assertValidNode(tree, r, delta + n.delta);
    }

    function assertValidTree(tree:IntervalTree):Void {
        if (tree.root == tree.SENTINEL) {
            return;
        }
        assertTrue(IntervalTree.getNodeColor(tree.root) == NodeColor.Black);
        assertTrue(depth(tree, tree.root.left) == depth(tree, tree.root.right));
        assertValidNode(tree, tree.root, 0);
    }

    static inline function maxInt(a:Int, b:Int):Int {
        return a > b ? a : b;
    }

    // #endregion


    function testGen01():Void {
        _testIntervalTree([
            { type: 'insert', begin: 28, end: 35 },
            { type: 'insert', begin: 52, end: 54 },
            { type: 'insert', begin: 63, end: 69 }
        ]);
    }

    function testGen02():Void {
        _testIntervalTree([
            { type: 'insert', begin: 80, end: 89 },
            { type: 'insert', begin: 92, end: 100 },
            { type: 'insert', begin: 99, end: 99 }
        ]);
    }

    function testGen03():Void {
        _testIntervalTree([
            { type: 'insert', begin: 89, end: 96 },
            { type: 'insert', begin: 71, end: 74 },
            { type: 'delete', id: 1 }
        ]);
    }

    function testGen04():Void {
        _testIntervalTree([
            { type: 'insert', begin: 44, end: 46 },
            { type: 'insert', begin: 85, end: 88 },
            { type: 'delete', id: 0 }
        ]);
    }

    function testGen05():Void {
        _testIntervalTree([
            { type: 'insert', begin: 82, end: 90 },
            { type: 'insert', begin: 69, end: 73 },
            { type: 'delete', id: 0 },
            { type: 'delete', id: 1 }
        ]);
    }

    function testGen06():Void {
        _testIntervalTree([
            { type: 'insert', begin: 41, end: 63 },
            { type: 'insert', begin: 98, end: 98 },
            { type: 'insert', begin: 47, end: 51 },
            { type: 'delete', id: 2 }
        ]);
    }

    function testGen07():Void {
        _testIntervalTree([
            { type: 'insert', begin: 24, end: 26 },
            { type: 'insert', begin: 11, end: 28 },
            { type: 'insert', begin: 27, end: 30 },
            { type: 'insert', begin: 80, end: 85 },
            { type: 'delete', id: 1 }
        ]);
    }

    function testGen08():Void {
        _testIntervalTree([
            { type: 'insert', begin: 100, end: 100 },
            { type: 'insert', begin: 100, end: 100 }
        ]);
    }

    function testGen09():Void {
        _testIntervalTree([
            { type: 'insert', begin: 58, end: 65 },
            { type: 'insert', begin: 82, end: 96 },
            { type: 'insert', begin: 58, end: 65 }
        ]);
    }

    function testGen10():Void {
        _testIntervalTree([
            { type: 'insert', begin: 32, end: 40 },
            { type: 'insert', begin: 25, end: 29 },
            { type: 'insert', begin: 24, end: 32 }
        ]);
    }

    function testGen11():Void {
        _testIntervalTree([
            { type: 'insert', begin: 25, end: 70 },
            { type: 'insert', begin: 99, end: 100 },
            { type: 'insert', begin: 46, end: 51 },
            { type: 'insert', begin: 57, end: 57 },
            { type: 'delete', id: 2 }
        ]);
    }

    function testGen12():Void {
        _testIntervalTree([
            { type: 'insert', begin: 20, end: 26 },
            { type: 'insert', begin: 10, end: 18 },
            { type: 'insert', begin: 99, end: 99 },
            { type: 'insert', begin: 37, end: 59 },
            { type: 'delete', id: 2 }
        ]);
    }

    function testGen13():Void {
        _testIntervalTree([
            { type: 'insert', begin: 3, end: 91 },
            { type: 'insert', begin: 57, end: 57 },
            { type: 'insert', begin: 35, end: 44 },
            { type: 'insert', begin: 72, end: 81 },
            { type: 'delete', id: 2 }
        ]);
    }

    function testGen14():Void {
        _testIntervalTree([
            { type: 'insert', begin: 58, end: 61 },
            { type: 'insert', begin: 34, end: 35 },
            { type: 'insert', begin: 56, end: 62 },
            { type: 'insert', begin: 69, end: 78 },
            { type: 'delete', id: 0 }
        ]);
    }

    function testGen15():Void {
        _testIntervalTree([
            { type: 'insert', begin: 63, end: 69 },
            { type: 'insert', begin: 17, end: 24 },
            { type: 'insert', begin: 3, end: 13 },
            { type: 'insert', begin: 84, end: 94 },
            { type: 'insert', begin: 18, end: 23 },
            { type: 'insert', begin: 96, end: 98 },
            { type: 'delete', id: 1 }
        ]);
    }

    function testGen16():Void {
        _testIntervalTree([
            { type: 'insert', begin: 27, end: 27 },
            { type: 'insert', begin: 42, end: 87 },
            { type: 'insert', begin: 42, end: 49 },
            { type: 'insert', begin: 69, end: 71 },
            { type: 'insert', begin: 20, end: 27 },
            { type: 'insert', begin: 8, end: 9 },
            { type: 'insert', begin: 42, end: 49 },
            { type: 'delete', id: 1 }
        ]);
    }

    function testGen17():Void {
        _testIntervalTree([
            { type: 'insert', begin: 21, end: 23 },
            { type: 'insert', begin: 83, end: 87 },
            { type: 'insert', begin: 56, end: 58 },
            { type: 'insert', begin: 1, end: 55 },
            { type: 'insert', begin: 56, end: 59 },
            { type: 'insert', begin: 58, end: 60 },
            { type: 'insert', begin: 56, end: 65 },
            { type: 'delete', id: 1 },
            { type: 'delete', id: 0 },
            { type: 'delete', id: 6 }
        ]);
    }

    function testGen18():Void {
        _testIntervalTree([
            { type: 'insert', begin: 25, end: 25 },
            { type: 'insert', begin: 67, end: 79 },
            { type: 'delete', id: 0 },
            { type: 'search', begin: 65, end: 75 }
        ]);
    }
}

/**
 * suite('IntervalTree 1') > suite('searching')
 */
class IntervalTree1SearchingTest extends TestCase {

    static function createCormenTree():IntervalTree {
        final r = new IntervalTree();
        final data:Array<Array<Int>> = [
            [16, 21],
            [8, 9],
            [25, 30],
            [5, 8],
            [15, 23],
            [17, 19],
            [26, 26],
            [0, 3],
            [6, 10],
            [19, 20]
        ];
        for (int in data) {
            final node = new IntervalNode(null, int[0], int[1]);
            r.insert(node);
        }
        return r;
    }

    // vscode builds this tree once for the whole suite.
    static var _T:Null<IntervalTree> = null;

    static function getT():IntervalTree {
        if (_T == null) {
            _T = createCormenTree();
        }
        return _T;
    }

    function assertIntervalSearch(start:Int, end:Int, expected:Array<Array<Int>>):Void {
        final actualNodes = getT().intervalSearch(start, end, 0, false, 0, false);
        final actual = actualNodes.map(n -> [n.cachedAbsoluteStart, n.cachedAbsoluteEnd]);
        assertDeepEquals(actual, expected);
    }

    function testCormen12():Void {
        assertIntervalSearch(
            1, 2,
            [
                [0, 3],
            ]
        );
    }

    function testCormen48():Void {
        assertIntervalSearch(
            4, 8,
            [
                [5, 8],
                [6, 10],
                [8, 9],
            ]
        );
    }

    function testCormen1015():Void {
        assertIntervalSearch(
            10, 15,
            [
                [6, 10],
                [15, 23],
            ]
        );
    }

    function testCormen2125():Void {
        assertIntervalSearch(
            21, 25,
            [
                [15, 23],
                [16, 21],
                [25, 30],
            ]
        );
    }

    function testCormen2424():Void {
        assertIntervalSearch(
            24, 24,
            [
            ]
        );
    }

}

/**
 * suite('IntervalTree 2')
 */
class IntervalTree2Test extends TestCase {

    function assertNodeAcceptEdit(msg:String, nodeStart:Int, nodeEnd:Int, nodeStickiness:TrackedRangeStickiness, start:Int, end:Int, textLength:Int, forceMoveMarkers:Bool, expectedNodeStart:Int, expectedNodeEnd:Int):Void {
        final node = new IntervalNode('', nodeStart, nodeEnd);
        IntervalTree.setNodeStickiness(node, nodeStickiness);
        IntervalTree.nodeAcceptEdit(node, start, end, textLength, forceMoveMarkers);
        assertDeepEquals([node.start, node.end], [expectedNodeStart, expectedNodeEnd], msg);
    }

    function testNodeAcceptEdit():Void {
        // A. collapsed decoration
        {
            // no-op
            assertNodeAcceptEdit('A.000', 0, 0, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 0, 0, 0, false, 0, 0);
            assertNodeAcceptEdit('A.001', 0, 0, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 0, 0, 0, false, 0, 0);
            assertNodeAcceptEdit('A.002', 0, 0, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 0, 0, 0, false, 0, 0);
            assertNodeAcceptEdit('A.003', 0, 0, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 0, 0, 0, false, 0, 0);
            assertNodeAcceptEdit('A.004', 0, 0, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 0, 0, 0, true, 0, 0);
            assertNodeAcceptEdit('A.005', 0, 0, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 0, 0, 0, true, 0, 0);
            assertNodeAcceptEdit('A.006', 0, 0, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 0, 0, 0, true, 0, 0);
            assertNodeAcceptEdit('A.007', 0, 0, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 0, 0, 0, true, 0, 0);
            // insertion
            assertNodeAcceptEdit('A.008', 0, 0, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 0, 0, 1, false, 0, 1);
            assertNodeAcceptEdit('A.009', 0, 0, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 0, 0, 1, false, 1, 1);
            assertNodeAcceptEdit('A.010', 0, 0, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 0, 0, 1, false, 0, 0);
            assertNodeAcceptEdit('A.011', 0, 0, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 0, 0, 1, false, 1, 1);
            assertNodeAcceptEdit('A.012', 0, 0, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 0, 0, 1, true, 1, 1);
            assertNodeAcceptEdit('A.013', 0, 0, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 0, 0, 1, true, 1, 1);
            assertNodeAcceptEdit('A.014', 0, 0, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 0, 0, 1, true, 1, 1);
            assertNodeAcceptEdit('A.015', 0, 0, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 0, 0, 1, true, 1, 1);
        }

        // B. non collapsed decoration
        {
            // no-op
            assertNodeAcceptEdit('B.000', 0, 5, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 0, 0, 0, false, 0, 5);
            assertNodeAcceptEdit('B.001', 0, 5, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 0, 0, 0, false, 0, 5);
            assertNodeAcceptEdit('B.002', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 0, 0, 0, false, 0, 5);
            assertNodeAcceptEdit('B.003', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 0, 0, 0, false, 0, 5);
            assertNodeAcceptEdit('B.004', 0, 5, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 0, 0, 0, true, 0, 5);
            assertNodeAcceptEdit('B.005', 0, 5, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 0, 0, 0, true, 0, 5);
            assertNodeAcceptEdit('B.006', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 0, 0, 0, true, 0, 5);
            assertNodeAcceptEdit('B.007', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 0, 0, 0, true, 0, 5);
            // insertion at start
            assertNodeAcceptEdit('B.008', 0, 5, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 0, 0, 1, false, 0, 6);
            assertNodeAcceptEdit('B.009', 0, 5, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 0, 0, 1, false, 1, 6);
            assertNodeAcceptEdit('B.010', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 0, 0, 1, false, 0, 6);
            assertNodeAcceptEdit('B.011', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 0, 0, 1, false, 1, 6);
            assertNodeAcceptEdit('B.012', 0, 5, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 0, 0, 1, true, 1, 6);
            assertNodeAcceptEdit('B.013', 0, 5, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 0, 0, 1, true, 1, 6);
            assertNodeAcceptEdit('B.014', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 0, 0, 1, true, 1, 6);
            assertNodeAcceptEdit('B.015', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 0, 0, 1, true, 1, 6);
            // insertion in middle
            assertNodeAcceptEdit('B.016', 0, 5, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 2, 2, 1, false, 0, 6);
            assertNodeAcceptEdit('B.017', 0, 5, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 2, 2, 1, false, 0, 6);
            assertNodeAcceptEdit('B.018', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 2, 2, 1, false, 0, 6);
            assertNodeAcceptEdit('B.019', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 2, 2, 1, false, 0, 6);
            assertNodeAcceptEdit('B.020', 0, 5, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 2, 2, 1, true, 0, 6);
            assertNodeAcceptEdit('B.021', 0, 5, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 2, 2, 1, true, 0, 6);
            assertNodeAcceptEdit('B.022', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 2, 2, 1, true, 0, 6);
            assertNodeAcceptEdit('B.023', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 2, 2, 1, true, 0, 6);
            // insertion at end
            assertNodeAcceptEdit('B.024', 0, 5, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 5, 1, false, 0, 6);
            assertNodeAcceptEdit('B.025', 0, 5, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 5, 1, false, 0, 5);
            assertNodeAcceptEdit('B.026', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 5, 1, false, 0, 5);
            assertNodeAcceptEdit('B.027', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 5, 1, false, 0, 6);
            assertNodeAcceptEdit('B.028', 0, 5, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 5, 1, true, 0, 6);
            assertNodeAcceptEdit('B.029', 0, 5, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 5, 1, true, 0, 6);
            assertNodeAcceptEdit('B.030', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 5, 1, true, 0, 6);
            assertNodeAcceptEdit('B.031', 0, 5, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 5, 1, true, 0, 6);

            // replace with larger text until start
            assertNodeAcceptEdit('B.032', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 5, 2, false, 5, 11);
            assertNodeAcceptEdit('B.033', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 5, 2, false, 6, 11);
            assertNodeAcceptEdit('B.034', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 5, 2, false, 5, 11);
            assertNodeAcceptEdit('B.035', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 5, 2, false, 6, 11);
            assertNodeAcceptEdit('B.036', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 5, 2, true, 6, 11);
            assertNodeAcceptEdit('B.037', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 5, 2, true, 6, 11);
            assertNodeAcceptEdit('B.038', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 5, 2, true, 6, 11);
            assertNodeAcceptEdit('B.039', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 5, 2, true, 6, 11);
            // replace with smaller text until start
            assertNodeAcceptEdit('B.040', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 3, 5, 1, false, 4, 9);
            assertNodeAcceptEdit('B.041', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 3, 5, 1, false, 4, 9);
            assertNodeAcceptEdit('B.042', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 3, 5, 1, false, 4, 9);
            assertNodeAcceptEdit('B.043', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 3, 5, 1, false, 4, 9);
            assertNodeAcceptEdit('B.044', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 3, 5, 1, true, 4, 9);
            assertNodeAcceptEdit('B.045', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 3, 5, 1, true, 4, 9);
            assertNodeAcceptEdit('B.046', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 3, 5, 1, true, 4, 9);
            assertNodeAcceptEdit('B.047', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 3, 5, 1, true, 4, 9);

            // replace with larger text select start
            assertNodeAcceptEdit('B.048', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 6, 3, false, 5, 11);
            assertNodeAcceptEdit('B.049', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 6, 3, false, 5, 11);
            assertNodeAcceptEdit('B.050', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 6, 3, false, 5, 11);
            assertNodeAcceptEdit('B.051', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 6, 3, false, 5, 11);
            assertNodeAcceptEdit('B.052', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 6, 3, true, 7, 11);
            assertNodeAcceptEdit('B.053', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 6, 3, true, 7, 11);
            assertNodeAcceptEdit('B.054', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 6, 3, true, 7, 11);
            assertNodeAcceptEdit('B.055', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 6, 3, true, 7, 11);
            // replace with smaller text select start
            assertNodeAcceptEdit('B.056', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 6, 1, false, 5, 9);
            assertNodeAcceptEdit('B.057', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 6, 1, false, 5, 9);
            assertNodeAcceptEdit('B.058', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 6, 1, false, 5, 9);
            assertNodeAcceptEdit('B.059', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 6, 1, false, 5, 9);
            assertNodeAcceptEdit('B.060', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 6, 1, true, 5, 9);
            assertNodeAcceptEdit('B.061', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 6, 1, true, 5, 9);
            assertNodeAcceptEdit('B.062', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 6, 1, true, 5, 9);
            assertNodeAcceptEdit('B.063', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 6, 1, true, 5, 9);

            // replace with larger text from start
            assertNodeAcceptEdit('B.064', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 6, 2, false, 5, 11);
            assertNodeAcceptEdit('B.065', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 6, 2, false, 5, 11);
            assertNodeAcceptEdit('B.066', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 6, 2, false, 5, 11);
            assertNodeAcceptEdit('B.067', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 6, 2, false, 5, 11);
            assertNodeAcceptEdit('B.068', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 6, 2, true, 7, 11);
            assertNodeAcceptEdit('B.069', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 6, 2, true, 7, 11);
            assertNodeAcceptEdit('B.070', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 6, 2, true, 7, 11);
            assertNodeAcceptEdit('B.071', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 6, 2, true, 7, 11);
            // replace with smaller text from start
            assertNodeAcceptEdit('B.072', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 7, 1, false, 5, 9);
            assertNodeAcceptEdit('B.073', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 7, 1, false, 5, 9);
            assertNodeAcceptEdit('B.074', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 7, 1, false, 5, 9);
            assertNodeAcceptEdit('B.075', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 7, 1, false, 5, 9);
            assertNodeAcceptEdit('B.076', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 7, 1, true, 6, 9);
            assertNodeAcceptEdit('B.077', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 7, 1, true, 6, 9);
            assertNodeAcceptEdit('B.078', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 7, 1, true, 6, 9);
            assertNodeAcceptEdit('B.079', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 7, 1, true, 6, 9);

            // replace with larger text to end
            assertNodeAcceptEdit('B.080', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 10, 2, false, 5, 11);
            assertNodeAcceptEdit('B.081', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 10, 2, false, 5, 10);
            assertNodeAcceptEdit('B.082', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 10, 2, false, 5, 10);
            assertNodeAcceptEdit('B.083', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 10, 2, false, 5, 11);
            assertNodeAcceptEdit('B.084', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 10, 2, true, 5, 11);
            assertNodeAcceptEdit('B.085', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 10, 2, true, 5, 11);
            assertNodeAcceptEdit('B.086', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 10, 2, true, 5, 11);
            assertNodeAcceptEdit('B.087', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 10, 2, true, 5, 11);
            // replace with smaller text to end
            assertNodeAcceptEdit('B.088', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 8, 10, 1, false, 5, 9);
            assertNodeAcceptEdit('B.089', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 8, 10, 1, false, 5, 9);
            assertNodeAcceptEdit('B.090', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 8, 10, 1, false, 5, 9);
            assertNodeAcceptEdit('B.091', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 8, 10, 1, false, 5, 9);
            assertNodeAcceptEdit('B.092', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 8, 10, 1, true, 5, 9);
            assertNodeAcceptEdit('B.093', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 8, 10, 1, true, 5, 9);
            assertNodeAcceptEdit('B.094', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 8, 10, 1, true, 5, 9);
            assertNodeAcceptEdit('B.095', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 8, 10, 1, true, 5, 9);

            // replace with larger text select end
            assertNodeAcceptEdit('B.096', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 11, 3, false, 5, 10);
            assertNodeAcceptEdit('B.097', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 11, 3, false, 5, 10);
            assertNodeAcceptEdit('B.098', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 11, 3, false, 5, 10);
            assertNodeAcceptEdit('B.099', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 11, 3, false, 5, 10);
            assertNodeAcceptEdit('B.100', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 11, 3, true, 5, 12);
            assertNodeAcceptEdit('B.101', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 11, 3, true, 5, 12);
            assertNodeAcceptEdit('B.102', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 11, 3, true, 5, 12);
            assertNodeAcceptEdit('B.103', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 11, 3, true, 5, 12);
            // replace with smaller text select end
            assertNodeAcceptEdit('B.104', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 11, 1, false, 5, 10);
            assertNodeAcceptEdit('B.105', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 11, 1, false, 5, 10);
            assertNodeAcceptEdit('B.106', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 11, 1, false, 5, 10);
            assertNodeAcceptEdit('B.107', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 11, 1, false, 5, 10);
            assertNodeAcceptEdit('B.108', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 11, 1, true, 5, 10);
            assertNodeAcceptEdit('B.109', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 11, 1, true, 5, 10);
            assertNodeAcceptEdit('B.110', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 11, 1, true, 5, 10);
            assertNodeAcceptEdit('B.111', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 11, 1, true, 5, 10);

            // replace with larger text from end
            assertNodeAcceptEdit('B.112', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 10, 11, 3, false, 5, 10);
            assertNodeAcceptEdit('B.113', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 10, 11, 3, false, 5, 10);
            assertNodeAcceptEdit('B.114', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 10, 11, 3, false, 5, 10);
            assertNodeAcceptEdit('B.115', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 10, 11, 3, false, 5, 10);
            assertNodeAcceptEdit('B.116', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 10, 11, 3, true, 5, 13);
            assertNodeAcceptEdit('B.117', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 10, 11, 3, true, 5, 13);
            assertNodeAcceptEdit('B.118', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 10, 11, 3, true, 5, 13);
            assertNodeAcceptEdit('B.119', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 10, 11, 3, true, 5, 13);
            // replace with smaller text from end
            assertNodeAcceptEdit('B.120', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 10, 12, 1, false, 5, 10);
            assertNodeAcceptEdit('B.121', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 10, 12, 1, false, 5, 10);
            assertNodeAcceptEdit('B.122', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 10, 12, 1, false, 5, 10);
            assertNodeAcceptEdit('B.123', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 10, 12, 1, false, 5, 10);
            assertNodeAcceptEdit('B.124', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 10, 12, 1, true, 5, 11);
            assertNodeAcceptEdit('B.125', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 10, 12, 1, true, 5, 11);
            assertNodeAcceptEdit('B.126', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 10, 12, 1, true, 5, 11);
            assertNodeAcceptEdit('B.127', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 10, 12, 1, true, 5, 11);

            // delete until start
            assertNodeAcceptEdit('B.128', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 5, 0, false, 4, 9);
            assertNodeAcceptEdit('B.129', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 5, 0, false, 4, 9);
            assertNodeAcceptEdit('B.130', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 5, 0, false, 4, 9);
            assertNodeAcceptEdit('B.131', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 5, 0, false, 4, 9);
            assertNodeAcceptEdit('B.132', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 5, 0, true, 4, 9);
            assertNodeAcceptEdit('B.133', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 5, 0, true, 4, 9);
            assertNodeAcceptEdit('B.134', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 5, 0, true, 4, 9);
            assertNodeAcceptEdit('B.135', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 5, 0, true, 4, 9);

            // delete select start
            assertNodeAcceptEdit('B.136', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 6, 0, false, 4, 8);
            assertNodeAcceptEdit('B.137', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 6, 0, false, 4, 8);
            assertNodeAcceptEdit('B.138', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 6, 0, false, 4, 8);
            assertNodeAcceptEdit('B.139', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 6, 0, false, 4, 8);
            assertNodeAcceptEdit('B.140', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 4, 6, 0, true, 4, 8);
            assertNodeAcceptEdit('B.141', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 4, 6, 0, true, 4, 8);
            assertNodeAcceptEdit('B.142', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 4, 6, 0, true, 4, 8);
            assertNodeAcceptEdit('B.143', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 4, 6, 0, true, 4, 8);

            // delete from start
            assertNodeAcceptEdit('B.144', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 6, 0, false, 5, 9);
            assertNodeAcceptEdit('B.145', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 6, 0, false, 5, 9);
            assertNodeAcceptEdit('B.146', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 6, 0, false, 5, 9);
            assertNodeAcceptEdit('B.147', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 6, 0, false, 5, 9);
            assertNodeAcceptEdit('B.148', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 6, 0, true, 5, 9);
            assertNodeAcceptEdit('B.149', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 6, 0, true, 5, 9);
            assertNodeAcceptEdit('B.150', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 6, 0, true, 5, 9);
            assertNodeAcceptEdit('B.151', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 6, 0, true, 5, 9);

            // delete to end
            assertNodeAcceptEdit('B.152', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 10, 0, false, 5, 9);
            assertNodeAcceptEdit('B.153', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 10, 0, false, 5, 9);
            assertNodeAcceptEdit('B.154', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 10, 0, false, 5, 9);
            assertNodeAcceptEdit('B.155', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 10, 0, false, 5, 9);
            assertNodeAcceptEdit('B.156', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 10, 0, true, 5, 9);
            assertNodeAcceptEdit('B.157', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 10, 0, true, 5, 9);
            assertNodeAcceptEdit('B.158', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 10, 0, true, 5, 9);
            assertNodeAcceptEdit('B.159', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 10, 0, true, 5, 9);

            // delete select end
            assertNodeAcceptEdit('B.160', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 11, 0, false, 5, 9);
            assertNodeAcceptEdit('B.161', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 11, 0, false, 5, 9);
            assertNodeAcceptEdit('B.162', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 11, 0, false, 5, 9);
            assertNodeAcceptEdit('B.163', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 11, 0, false, 5, 9);
            assertNodeAcceptEdit('B.164', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 9, 11, 0, true, 5, 9);
            assertNodeAcceptEdit('B.165', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 9, 11, 0, true, 5, 9);
            assertNodeAcceptEdit('B.166', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 9, 11, 0, true, 5, 9);
            assertNodeAcceptEdit('B.167', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 9, 11, 0, true, 5, 9);

            // delete from end
            assertNodeAcceptEdit('B.168', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 10, 11, 0, false, 5, 10);
            assertNodeAcceptEdit('B.169', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 10, 11, 0, false, 5, 10);
            assertNodeAcceptEdit('B.170', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 10, 11, 0, false, 5, 10);
            assertNodeAcceptEdit('B.171', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 10, 11, 0, false, 5, 10);
            assertNodeAcceptEdit('B.172', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 10, 11, 0, true, 5, 10);
            assertNodeAcceptEdit('B.173', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 10, 11, 0, true, 5, 10);
            assertNodeAcceptEdit('B.174', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 10, 11, 0, true, 5, 10);
            assertNodeAcceptEdit('B.175', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 10, 11, 0, true, 5, 10);

            // replace with larger text entire
            assertNodeAcceptEdit('B.176', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 10, 3, false, 5, 8);
            assertNodeAcceptEdit('B.177', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 10, 3, false, 5, 8);
            assertNodeAcceptEdit('B.178', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 10, 3, false, 5, 8);
            assertNodeAcceptEdit('B.179', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 10, 3, false, 5, 8);
            assertNodeAcceptEdit('B.180', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 10, 3, true, 8, 8);
            assertNodeAcceptEdit('B.181', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 10, 3, true, 8, 8);
            assertNodeAcceptEdit('B.182', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 10, 3, true, 8, 8);
            assertNodeAcceptEdit('B.183', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 10, 3, true, 8, 8);
            // replace with smaller text entire
            assertNodeAcceptEdit('B.184', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 10, 7, false, 5, 12);
            assertNodeAcceptEdit('B.185', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 10, 7, false, 5, 10);
            assertNodeAcceptEdit('B.186', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 10, 7, false, 5, 10);
            assertNodeAcceptEdit('B.187', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 10, 7, false, 5, 12);
            assertNodeAcceptEdit('B.188', 5, 10, TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, 5, 10, 7, true, 12, 12);
            assertNodeAcceptEdit('B.189', 5, 10, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, 5, 10, 7, true, 12, 12);
            assertNodeAcceptEdit('B.190', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingBefore, 5, 10, 7, true, 12, 12);
            assertNodeAcceptEdit('B.191', 5, 10, TrackedRangeStickiness.GrowsOnlyWhenTypingAfter, 5, 10, 7, true, 12, 12);

        }
    }

}

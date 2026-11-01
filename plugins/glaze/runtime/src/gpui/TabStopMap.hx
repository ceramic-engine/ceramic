// Ported from gpui-pre 0.3.10: src/tab_stop.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import haxe.ds.IntMap;

/**
 * An operation recorded while building the tab order.
 */
enum TabStopOperation {
    Insert(focusHandle:FocusHandle);
    Group(tabIndex:Int);
    GroupEnd;
}

/**
 * A node of the tab order: its path of tab indices (groups first) and the
 * index of its insertion, to break ties.
 */
class TabStopNode {

    public final path:Array<Int>;

    public final nodeInsertionIndex:Int;

    /** Whether this node is a tab stop (otherwise it is only part of the order, and skipped). */
    public final tabStop:Bool;

    public function new(path:Array<Int>, nodeInsertionIndex:Int, tabStop:Bool) {
        this.path = path;
        this.nodeInsertionIndex = nodeInsertionIndex;
        this.tabStop = tabStop;
    }

    /**
     * Compares paths lexicographically, then insertion indices (Rust `Ord`).
     */
    public static function compare(a:TabStopNode, b:TabStopNode):Int {
        final n = a.path.length < b.path.length ? a.path.length : b.path.length;
        for (i in 0...n) {
            final x = a.path[i];
            final y = b.path[i];
            if (x != y)
                return x < y ? -1 : 1;
        }
        if (a.path.length != b.path.length)
            return a.path.length < b.path.length ? -1 : 1;
        if (a.nodeInsertionIndex != b.nodeInsertionIndex)
            return a.nodeInsertionIndex < b.nodeInsertionIndex ? -1 : 1;
        return 0;
    }

}

/**
 * The tab order of the focusable elements of a frame.
 *
 * Differences with GPUI: Rust keeps the order in a `SumTree`; here it is an
 * array kept sorted by insertion (binary search), which gives the same order.
 */
class TabStopMap {

    var currentPath:Array<Int> = [];

    /**
     * Every operation, in insertion order.
     */
    public final insertionHistory:Array<TabStopOperation> = [];

    final byId:IntMap<TabStopNode> = new IntMap();

    final order:Array<TabStopNode> = [];

    public function new() {}

    /**
     * Inserts the given focus handle in the order, at the current group path.
     */
    public function insert(focusHandle:FocusHandle):Void {
        insertionHistory.push(Insert(focusHandle));
        final path = currentPath.copy();
        path.push(focusHandle.tabIndexValue);
        final node = new TabStopNode(path, insertionHistory.length - 1, focusHandle.isTabStop);
        byId.set(focusHandle.id, node);
        // insert_or_replace: insertion indices are unique, so this always inserts
        final index = lowerBound(node);
        if (index < order.length && TabStopNode.compare(order[index], node) == 0) {
            order[index] = node;
        }
        else {
            order.insert(index, node);
        }
    }

    /**
     * Begins a tab group: the next insertions are ordered within `tabIndex`.
     */
    public function beginGroup(tabIndex:Int):Void {
        insertionHistory.push(Group(tabIndex));
        currentPath.push(tabIndex);
    }

    /**
     * Ends the current tab group.
     */
    public function endGroup():Void {
        insertionHistory.push(GroupEnd);
        currentPath.pop();
    }

    public function clear():Void {
        currentPath.resize(0);
        insertionHistory.resize(0);
        byId.clear();
        order.resize(0);
    }

    /**
     * The handle following the given focused one (wraps around), or the first
     * tab stop when nothing is focused (`focusedId == -1`).
     */
    public function next(focusedId:Int):Null<FocusHandle> {
        if (focusedId == -1) {
            if (order.length == 0)
                return null;
            final first = order[0];
            if (first.tabStop) {
                return focusHandleForOrder(first);
            }
            else {
                final item = nextInner(first);
                return item != null ? focusHandleForOrder(item) : null;
            }
        }

        final node = byId.get(focusedId);
        if (node == null) {
            return next(-1);
        }
        final item = nextInner(node);
        if (item != null) {
            return focusHandleForOrder(item);
        }
        else {
            return next(-1);
        }
    }

    function nextInner(node:TabStopNode):Null<TabStopNode> {
        var index = lowerBound(node) + 1;
        while (index < order.length && !order[index].tabStop) {
            index++;
        }
        return index < order.length ? order[index] : null;
    }

    /**
     * The handle preceding the given focused one (wraps around), or the last
     * tab stop when nothing is focused (`focusedId == -1`).
     */
    public function prev(focusedId:Int):Null<FocusHandle> {
        if (focusedId == -1) {
            if (order.length == 0)
                return null;
            final last = order[order.length - 1];
            if (last.tabStop) {
                return focusHandleForOrder(last);
            }
            else {
                final item = prevInner(last);
                return item != null ? focusHandleForOrder(item) : null;
            }
        }

        final node = byId.get(focusedId);
        if (node == null) {
            return prev(-1);
        }
        final item = prevInner(node);
        if (item != null) {
            return focusHandleForOrder(item);
        }
        else {
            return prev(-1);
        }
    }

    function prevInner(node:TabStopNode):Null<TabStopNode> {
        var index = lowerBound(node) - 1;
        while (index >= 0 && !order[index].tabStop) {
            index--;
        }
        return index >= 0 ? order[index] : null;
    }

    /**
     * Replays recorded operations (used when reusing a cached paint range).
     */
    public function replay(nodes:Array<TabStopOperation>):Void {
        for (node in nodes) {
            switch node {
                case Insert(focusHandle): insert(focusHandle);
                case Group(tabIndex): beginGroup(tabIndex);
                case GroupEnd: endGroup();
            }
        }
    }

    /**
     * Replays the operations `start...end` of another map's history (the
     * previous frame's), without copying them first.
     */
    public function replayRange(source:TabStopMap, start:Int, end:Int):Void {
        final history = source.insertionHistory;
        for (i in start...end) {
            switch history[i] {
                case Insert(focusHandle): insert(focusHandle);
                case Group(tabIndex): beginGroup(tabIndex);
                case GroupEnd: endGroup();
            }
        }
    }

    public inline function paintIndex():Int {
        return insertionHistory.length;
    }

    /**
     * Number of tab stops.
     */
    public function tabStopCount():Int {
        var count = 0;
        for (node in byId) {
            if (node.tabStop)
                count++;
        }
        return count;
    }

    function focusHandleForOrder(node:TabStopNode):Null<FocusHandle> {
        return switch insertionHistory[node.nodeInsertionIndex] {
            case Insert(focusHandle): focusHandle;
            case _: null;
        }
    }

    /** Index of the first node not less than `node` (Rust: `cursor.seek(node, Bias::Left)`). */
    function lowerBound(node:TabStopNode):Int {
        var lo = 0;
        var hi = order.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (TabStopNode.compare(order[mid], node) < 0) {
                lo = mid + 1;
            }
            else {
                hi = mid;
            }
        }
        return lo;
    }

}

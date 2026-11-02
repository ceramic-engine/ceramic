// Ported from gpui-pre 0.3.10: src/bounds_tree.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package gpui.scene;

/**
 * R-tree of axis aligned bounds used to compute the draw order of scene
 * primitives: inserting bounds returns `1 + the max order of all previously
 * inserted bounds that intersect them`, so primitives that don't overlap
 * can share the same order and be batched together.
 *
 * Nodes are stored in flat arrays (no allocation per insertion once the
 * arrays have grown), indexed by node index.
 *
 * Its methods are `@:noDebug` on hxcpp (no stack frame and no line
 * bookkeeping): they run for every primitive of every frame, and a crash
 * report would show the caller (`Scene.insert*`) anyway.
 */
class BoundsTree {

    static inline final MAX_CHILDREN:Int = 12;

    static inline final NONE:Int = -1;

    /** Number of nodes in use */
    var numNodes:Int = 0;

    var nodeX:Array<Float> = [];
    var nodeY:Array<Float> = [];
    var nodeW:Array<Float> = [];
    var nodeH:Array<Float> = [];
    var nodeMaxOrder:Array<Int> = [];
    /** Leaf order, or `NONE` for internal nodes */
    var nodeLeafOrder:Array<Int> = [];
    var nodeChildrenLen:Array<Int> = [];
    /** Child indices, `MAX_CHILDREN` slots per node */
    var nodeChildren:Array<Int> = [];

    var root:Int = NONE;
    var maxLeaf:Int = NONE;

    var insertPath:Array<Int> = [];
    var insertPathLen:Int = 0;

    var searchStack:Array<Int> = [];

    public function new() {}

    /** Rounds to `f32`: GPUI's bounds are `Bounds<ScaledPixels>` (f32). */
    static inline function f(v:Float):Float {
        return gpui.SpringMath.f32(v);
    }

    /**
     * Reads `array[index]` without the bounds check of hxcpp. Only used for
     * indices below `numNodes` (every node array is written up to it by
     * `addNode()`), child slots below `nodeChildrenLen` and stack entries
     * below their length.
     */
    static inline function at<T>(array:Array<T>, index:Int):T {
        #if cpp
        return cpp.NativeArray.unsafeGet(array, index);
        #else
        return array[index];
        #end
    }

    public function clear():Void {

        numNodes = 0;
        root = NONE;
        maxLeaf = NONE;
        insertPathLen = 0;

    }

    /**
     * Inserts the given bounds and returns their draw order.
     */
    @:noDebug
    public function insert(x:Float, y:Float, w:Float, h:Float):Int {

        final maxIntersecting = findMaxOrdering(x, y, w, h);
        final ordering = maxIntersecting + 1;

        final newLeafIdx = insertLeaf(x, y, w, h, ordering);

        if (maxLeaf == NONE || at(nodeMaxOrder, maxLeaf) < ordering) {
            maxLeaf = newLeafIdx;
        }

        return ordering;

    }

    inline function intersectsNode(x:Float, y:Float, w:Float, h:Float, node:Int):Bool {

        final nx = at(nodeX, node);
        final ny = at(nodeY, node);
        // GPUI adds in f32 (`Bounds<ScaledPixels>::bottom_right`)
        return x < f(nx + at(nodeW, node))
            && f(x + w) > nx
            && y < f(ny + at(nodeH, node))
            && f(y + h) > ny;

    }

    @:noDebug
    function findMaxOrdering(x:Float, y:Float, w:Float, h:Float):Int {

        if (root == NONE) {
            return 0;
        }

        // Fast path: if the query intersects the max ordered leaf, nothing can be higher
        if (maxLeaf != NONE && intersectsNode(x, y, w, h, maxLeaf)) {
            return at(nodeMaxOrder, maxLeaf);
        }

        var stackLen = 0;
        searchStack[stackLen++] = root;

        var maxFound = 0;

        while (stackLen > 0) {
            final node = at(searchStack, --stackLen);

            // Skip if this subtree can't improve our result
            if (at(nodeMaxOrder, node) <= maxFound) {
                continue;
            }

            if (!intersectsNode(x, y, w, h, node)) {
                continue;
            }

            final leafOrder = at(nodeLeafOrder, node);
            if (leafOrder != NONE) {
                if (leafOrder > maxFound) {
                    maxFound = leafOrder;
                }
            }
            else {
                final base = node * MAX_CHILDREN;
                final len = at(nodeChildrenLen, node);
                for (i in 0...len) {
                    final child = at(nodeChildren, base + i);
                    if (at(nodeMaxOrder, child) > maxFound) {
                        searchStack[stackLen++] = child;
                    }
                }
            }
        }

        return maxFound;

    }

    @:noDebug
    function addNode(x:Float, y:Float, w:Float, h:Float, maxOrder:Int, leafOrder:Int):Int {

        final idx = numNodes++;
        nodeX[idx] = x;
        nodeY[idx] = y;
        nodeW[idx] = w;
        nodeH[idx] = h;
        nodeMaxOrder[idx] = maxOrder;
        nodeLeafOrder[idx] = leafOrder;
        nodeChildrenLen[idx] = 0;
        return idx;

    }

    inline function pushChild(node:Int, child:Int):Void {

        final len = at(nodeChildrenLen, node);
        nodeChildren[node * MAX_CHILDREN + len] = child;
        nodeChildrenLen[node] = len + 1;

    }

    inline function swapChildren(node:Int, a:Int, b:Int):Void {

        final base = node * MAX_CHILDREN;
        final tmp = at(nodeChildren, base + a);
        nodeChildren[base + a] = at(nodeChildren, base + b);
        nodeChildren[base + b] = tmp;

    }

    /** Grows the node bounds to include the given bounds */
    inline function unionInto(node:Int, x:Float, y:Float, w:Float, h:Float):Void {

        final nx = at(nodeX, node);
        final ny = at(nodeY, node);
        final right = Math.max(f(nx + at(nodeW, node)), f(x + w));
        final bottom = Math.max(f(ny + at(nodeH, node)), f(y + h));
        final left = Math.min(nx, x);
        final top = Math.min(ny, y);
        nodeX[node] = left;
        nodeY[node] = top;
        nodeW[node] = f(right - left);
        nodeH[node] = f(bottom - top);

    }

    /** Half perimeter of the union of a node bounds and the given bounds */
    inline function unionHalfPerimeter(node:Int, x:Float, y:Float, w:Float, h:Float):Float {

        final nx = at(nodeX, node);
        final ny = at(nodeY, node);
        final right = Math.max(f(nx + at(nodeW, node)), f(x + w));
        final bottom = Math.max(f(ny + at(nodeH, node)), f(y + h));
        return f(f(right - Math.min(nx, x)) + f(bottom - Math.min(ny, y)));

    }

    @:noDebug
    function insertLeaf(x:Float, y:Float, w:Float, h:Float, order:Int):Int {

        final newLeafIdx = addNode(x, y, w, h, order, order);

        if (root == NONE) {
            root = newLeafIdx;
            return newLeafIdx;
        }

        // If root is a leaf, create a new internal node with both
        if (at(nodeLeafOrder, root) != NONE) {
            final rootOrder = at(nodeMaxOrder, root);
            final newRootIdx = addNode(at(nodeX, root), at(nodeY, root), at(nodeW, root), at(nodeH, root), rootOrder > order ? rootOrder : order, NONE);
            unionInto(newRootIdx, x, y, w, h);
            if (order > rootOrder) {
                pushChild(newRootIdx, root);
                pushChild(newRootIdx, newLeafIdx);
            }
            else {
                pushChild(newRootIdx, newLeafIdx);
                pushChild(newRootIdx, root);
            }
            root = newRootIdx;
            return newLeafIdx;
        }

        // Descent to find the best internal node to insert into
        insertPathLen = 0;
        var currentIdx = root;

        while (true) {
            insertPath[insertPathLen++] = currentIdx;

            // Find the best child using the SAH heuristic (minimize the union's half perimeter)
            final base = currentIdx * MAX_CHILDREN;
            final childrenLen = at(nodeChildrenLen, currentIdx);
            var bestChildIdx = at(nodeChildren, base);
            var bestChildPos = 0;
            var bestCost = unionHalfPerimeter(bestChildIdx, x, y, w, h);

            for (pos in 1...childrenLen) {
                final childIdx = at(nodeChildren, base + pos);
                final cost = unionHalfPerimeter(childIdx, x, y, w, h);
                if (cost < bestCost) {
                    bestCost = cost;
                    bestChildIdx = childIdx;
                    bestChildPos = pos;
                }
            }

            if (at(nodeLeafOrder, bestChildIdx) != NONE) {
                // Best child is a leaf
                if (childrenLen < MAX_CHILDREN) {
                    // Add the new leaf to this internal node
                    pushChild(currentIdx, newLeafIdx);
                    if (order <= at(nodeMaxOrder, currentIdx)) {
                        // Keep the child with the highest max order at the end
                        final last = childrenLen;
                        swapChildren(currentIdx, last - 1, last);
                    }
                    unionInto(currentIdx, x, y, w, h);
                    if (order > at(nodeMaxOrder, currentIdx)) {
                        nodeMaxOrder[currentIdx] = order;
                    }
                    break;
                }
                else {
                    // Node is full: replace the best leaf with a new internal node holding both
                    final siblingOrder = at(nodeMaxOrder, bestChildIdx);
                    final newInternalMax = siblingOrder > order ? siblingOrder : order;
                    final newInternalIdx = addNode(
                        at(nodeX, bestChildIdx), at(nodeY, bestChildIdx), at(nodeW, bestChildIdx), at(nodeH, bestChildIdx),
                        newInternalMax, NONE
                    );
                    unionInto(newInternalIdx, x, y, w, h);
                    if (order > siblingOrder) {
                        pushChild(newInternalIdx, bestChildIdx);
                        pushChild(newInternalIdx, newLeafIdx);
                    }
                    else {
                        pushChild(newInternalIdx, newLeafIdx);
                        pushChild(newInternalIdx, bestChildIdx);
                    }

                    // Replace the leaf with the new internal node in the parent
                    nodeChildren[base + bestChildPos] = newInternalIdx;

                    // If the new internal node has the highest max order, swap it to the end
                    if (newInternalMax > at(nodeMaxOrder, currentIdx)) {
                        swapChildren(currentIdx, bestChildPos, childrenLen - 1);
                    }
                    break;
                }
            }
            else {
                // Best child is internal, continue descent
                currentIdx = bestChildIdx;
            }
        }

        // Propagate bounds and max order updates up the tree
        var updatedChildIdx = NONE;
        var i = insertPathLen - 1;
        while (i >= 0) {
            final nodeIdx = at(insertPath, i);
            unionInto(nodeIdx, x, y, w, h);

            if (at(nodeMaxOrder, nodeIdx) < order) {
                nodeMaxOrder[nodeIdx] = order;

                // Swap the updated child to the end (the first iteration is
                // already handled by the cases above)
                if (updatedChildIdx != NONE) {
                    final base = nodeIdx * MAX_CHILDREN;
                    final len = at(nodeChildrenLen, nodeIdx);
                    for (pos in 0...len) {
                        if (at(nodeChildren, base + pos) == updatedChildIdx) {
                            if (pos != len - 1) {
                                swapChildren(nodeIdx, pos, len - 1);
                            }
                            break;
                        }
                    }
                }
            }

            updatedChildIdx = nodeIdx;
            i--;
        }

        return newLeafIdx;

    }

}

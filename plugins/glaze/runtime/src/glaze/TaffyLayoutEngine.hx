// Ported from gpui-pre 0.3.10: src/taffy.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.util.Stacks;
import haxe.ds.IntMap;
import taffy.compute.Leaf;
import taffy.geometry.LineOf;
import taffy.style.Dimension;
import taffy.style.GridHelpers;
import taffy.style.GridTemplateComponent;
import taffy.style.LengthPercentage;
import taffy.style.LengthPercentageAuto;
import taffy.style.MaxTrackSizingFunction;
import taffy.style.MinTrackSizingFunction;
import taffy.style.TrackSizingFunction;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;
import taffy.util.OptionalFloat;

/**
 * Measures a leaf node: given its known dimensions (`null` when unknown) and
 * the available space, in logical pixels, returns its size in logical pixels.
 */
typedef MeasureFn = (knownDimensions:SizeOf<Null<Float>>, availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App) -> Size;

/**
 * The measure of a measured layout node, as an object: the node keeps it as
 * its context. Internal: `requestMeasuredLayout()` wraps its function value
 * in one (`FunctionMeasuredNode`); an element state can extend it to be its
 * own measure (`TextLayout`: no closure and no context object per node).
 */
@:noCompletion
class MeasuredNode {

    /** Kinds of the available space of the last measure */
    @:allow(glaze) static inline final AVAILABLE_DEFINITE:Int = 0;
    @:allow(glaze) static inline final AVAILABLE_MIN_CONTENT:Int = 1;
    @:allow(glaze) static inline final AVAILABLE_MAX_CONTENT:Int = 2;

    /**
     * The arguments of the last measure, as values in logical pixels (no
     * `SizeOf` and `AvailableSpace` objects per measured leaf):
     * `measuredSet` is false before the first one
     */
    @:allow(glaze) var measuredSet:Bool = false;
    @:allow(glaze) var measuredHasKnownWidth:Bool = false;
    @:allow(glaze) var measuredKnownWidth:Float = 0.0;
    @:allow(glaze) var measuredHasKnownHeight:Bool = false;
    @:allow(glaze) var measuredKnownHeight:Float = 0.0;
    @:allow(glaze) var measuredAvailableWidthKind:Int = AVAILABLE_MAX_CONTENT;
    @:allow(glaze) var measuredAvailableWidth:Float = 0.0;
    @:allow(glaze) var measuredAvailableHeightKind:Int = AVAILABLE_MAX_CONTENT;
    @:allow(glaze) var measuredAvailableHeight:Float = 0.0;

    function new() {}

    /** Takes the arguments of the last measure of `other` */
    @:allow(glaze)
    inline function copyMeasuredFrom(other:MeasuredNode):Void {
        measuredSet = other.measuredSet;
        measuredHasKnownWidth = other.measuredHasKnownWidth;
        measuredKnownWidth = other.measuredKnownWidth;
        measuredHasKnownHeight = other.measuredHasKnownHeight;
        measuredKnownHeight = other.measuredKnownHeight;
        measuredAvailableWidthKind = other.measuredAvailableWidthKind;
        measuredAvailableWidth = other.measuredAvailableWidth;
        measuredAvailableHeightKind = other.measuredAvailableHeightKind;
        measuredAvailableHeight = other.measuredAvailableHeight;
    }

    /**
     * The size of the node for the arguments of the last measure (the
     * `measured*` values). By default, `measureNode()` with these arguments
     * as objects (shared while they are the same); an element state can read
     * the values directly instead (`TextLayout`).
     */
    @:allow(glaze)
    function measureValues(window:Window, cx:App):Size {
        return measureNode(knownObject(this), availableObject(this), window, cx);
    }

    /** The size of the node (what a `MeasureFn` returns) */
    @:allow(glaze)
    function measureNode(knownDimensions:SizeOf<Null<Float>>, availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App):Size {
        throw 'abstract';
    }

    static final NONE_KNOWN = new SizeOf<Null<Float>>(null, null);

    /** The known dimensions given to the last measure with some (immutable, reused while unchanged) */
    static var lastKnown:Null<SizeOf<Null<Float>>> = null;
    static var lastKnownHasWidth:Bool = false;
    static var lastKnownHasHeight:Bool = false;
    static var lastKnownWidth:Float = 0.0;
    static var lastKnownHeight:Float = 0.0;

    /** The available space given to the last measure (immutable values reused while unchanged) */
    static var lastAvailable:Null<SizeOf<AvailableSpace>> = null;
    static var lastAvailableWidth:AvailableSpace = AvailableSpace.MaxContent;
    static var lastAvailableHeight:AvailableSpace = AvailableSpace.MaxContent;

    /** The same value, zero signs included */
    static inline function sameFloat(a:Float, b:Float):Bool {
        return a == b && (b != 0.0 || 1.0 / a == 1.0 / b);
    }

    /** The known dimensions of the last measure of `node` as an object */
    static function knownObject(node:MeasuredNode):SizeOf<Null<Float>> {
        final hasWidth = node.measuredHasKnownWidth;
        final hasHeight = node.measuredHasKnownHeight;
        if (!hasWidth && !hasHeight) {
            return NONE_KNOWN;
        }
        final width = hasWidth ? node.measuredKnownWidth : 0.0;
        final height = hasHeight ? node.measuredKnownHeight : 0.0;
        final last = lastKnown;
        if (last != null && hasWidth == lastKnownHasWidth && hasHeight == lastKnownHasHeight
            && (!hasWidth || sameFloat(width, lastKnownWidth)) && (!hasHeight || sameFloat(height, lastKnownHeight))) {
            return last;
        }
        final known = new SizeOf<Null<Float>>(hasWidth ? width : null, hasHeight ? height : null);
        lastKnown = known;
        lastKnownHasWidth = hasWidth;
        lastKnownHasHeight = hasHeight;
        lastKnownWidth = width;
        lastKnownHeight = height;
        return known;
    }

    /** `previous` when it is the same available space, a new one otherwise */
    static function availableValue(kind:Int, value:Float, previous:AvailableSpace):AvailableSpace {
        return switch kind {
            case AVAILABLE_MIN_CONTENT: AvailableSpace.MinContent;
            case AVAILABLE_MAX_CONTENT: AvailableSpace.MaxContent;
            case _:
                switch previous {
                    case Definite(last) if (sameFloat(last, value)):
                        previous;
                    case _:
                        AvailableSpace.Definite(value);
                }
        }
    }

    /** The available space of the last measure of `node` as an object */
    static function availableObject(node:MeasuredNode):SizeOf<AvailableSpace> {
        final width = availableValue(node.measuredAvailableWidthKind, node.measuredAvailableWidth, lastAvailableWidth);
        final height = availableValue(node.measuredAvailableHeightKind, node.measuredAvailableHeight, lastAvailableHeight);
        var available = lastAvailable;
        if (available == null || available.width != width || available.height != height) {
            available = new SizeOf<AvailableSpace>(width, height);
            lastAvailable = available;
        }
        lastAvailableWidth = width;
        lastAvailableHeight = height;
        return available;
    }
}

/** A `MeasuredNode` over a `MeasureFn` (`TaffyLayoutEngine.requestMeasuredLayout`) */
private class FunctionMeasuredNode extends MeasuredNode {
    final measure:MeasureFn;

    public function new(measure:MeasureFn) {
        super();
        this.measure = measure;
    }

    override function measureNode(knownDimensions:SizeOf<Null<Float>>, availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App):Size {
        return measure(knownDimensions, availableSpace, window, cx);
    }
}

private typedef NodeContext = MeasuredNode;

/**
 * The layout nodes requested by one view while it renders (see
 * `TaffyLayoutEngine.beginViewNodes()`).
 */
private class ViewNodes {
    /** Ids of the nodes the view requested (created or adopted), in request order */
    public var nodes:Array<Int> = [];
    /** Retained nodes to adopt, in the order the view requested them last time, or null */
    public var adopt:Null<Array<Int>> = null;
    /** Index of the next node of `adopt` */
    public var index:Int = 0;
    /** Whether a request did not match `adopt` (the next nodes are created) */
    public var failed:Bool = false;
    /**
     * Whether the view renders because it changed (see `beginViewNodes()`):
     * a node is adopted only with the same style, and its children may differ
     */
    public var checked:Bool = false;
    public function new() {}
}

/**
 * The layout engine of a window: a taffy tree built every frame from the
 * styles of the elements, laid out in device pixels and snapped like GPUI.
 *
 * See the long comment in GPUI's `taffy.rs` about pixel snapping: authored
 * lengths are rounded to device pixels before layout (`toTaffy`), measured
 * sizes are rounded up, and the outer box edges are rounded in absolute
 * coordinates after layout (`layoutBounds`).
 *
 * Differences with GPUI (view caching): GPUI clears the tree every frame.
 * Here nodes live as long as they are used: every node created or retained
 * during a frame is kept for the next one, and freed at the end of the next
 * frame if that frame neither created nor retained it (`finishFrame()`).
 * A cached view that is not rendered retains the subtree it requested
 * during the previous frame (`retain()`), with the layout cache of its
 * nodes, so laying it out again is mostly cache hits. When such a view must
 * render after all (its bounds changed), its requests adopt the nodes of
 * the retained subtree when they match (`beginViewNodes()`), so nothing has
 * to be laid out again; otherwise its new subtree replaces the retained one
 * (`replaceRetained()`).
 *
 * Incremental layout (not in GPUI, where the whole tree is laid out every
 * frame; the layout is the same): a view that renders because it changed
 * also adopts the nodes it requested last time when they have the same
 * style and as many children (`beginViewNodes()` with `checked`), keeping
 * their layout cache. Where an adopted node's child changed (a new node in
 * its place), the new child is laid out for every input the old one was
 * laid out for (`TaffyTree.matchesRelayout`, from the old node's cache): if
 * every result is the same, the parent's cached layout stays valid and
 * nothing above the child is laid out again; otherwise the parent is laid
 * out again, checked the same way against its own previous results, up to
 * the first ancestor whose results do not change (`processChanges()`).
 * Retaining a subtree marks its root only (`retain()`); a node is alive
 * while its root, or an ancestor, was created, adopted or retained during
 * the frame (`finishFrame()`).
 */
class TaffyLayoutEngine implements taffy.tree.LayoutMeasurer<NodeContext> implements taffy.compute.Leaf.LeafMeasurer {

    final tree:TaffyTree<NodeContext>;

    /*
     * Per node caches of the current frame, dense arrays indexed by node id
     * (an `IntMap<Float>` boxes every value it returns on hxcpp). An entry
     * is valid when its stamp is the current `frame`, so advancing the frame
     * clears them all; 0 (never a frame number) marks a removed entry.
     */

    /** Frame of the cached `layoutBounds()` of each node (also stamps the outer origins) */
    final layoutBoundsFrames:Array<Int> = [];

    /** `layoutBounds()` objects, made on demand from the values below (null until asked) */
    final absoluteLayoutBounds:Array<Bounds> = [];

    /** The origin and size of `layoutBounds()` (no `Bounds` and `Point` for `Window.computeLayoutBounds()`) */
    final absoluteLefts:Array<Float> = [];

    final absoluteTops:Array<Float> = [];

    final absoluteSizes:Array<Size> = [];

    final absoluteOuterOriginsX:Array<Float> = [];

    final absoluteOuterOriginsY:Array<Float> = [];

    /** Frame in which each root was last laid out by `computeLayout()` */
    final computedLayoutFrames:Array<Int> = [];

    final layoutBoundsScratchSpace:Array<LayoutId> = [];

    /** Available space of the roots laid out during the current frame, in device pixels */
    var rootAvailableSpaces:IntMap<taffy.geometry.SizeAvail> = new IntMap();

    /** `rootAvailableSpaces` of the previous frame (used while amending it, see `beginAmend()`) */
    var previousRootAvailableSpaces:IntMap<taffy.geometry.SizeAvail> = new IntMap();

    /** The frame number, advanced by `finishFrame()` */
    var frame:Int = 1;

    /** The last frame each node was created or retained in, by node id */
    final nodeFrames:Array<Int> = [];

    /** Nodes created or retained during the current frame */
    var liveNodes:Array<Int> = [];

    /** Nodes created or retained during the previous frame */
    var previousLiveNodes:Array<Int> = [];

    final retainStack:Array<Int> = [];

    /**
     * Changes recorded while adopting nodes (see `processChanges()`): the
     * adopted parent, the node in its children, and the node it replaced
     * (or -1 when the reference is `changeSnapshots`, a copy of the node's
     * own cache before it was cleared)
     */
    final changeParents:Array<Int> = [];
    final changeNodes:Array<Int> = [];
    final changeOlds:Array<Int> = [];
    final changeSnapshots:Array<Null<taffy.tree.Cache>> = [];

    /** Depth of each change's parent, and the changes by depth (scratch of `processChanges()`) */
    final changeDepths:Array<Int> = [];
    final changeBuckets:Array<Array<Int>> = [];

    /** The scale factor of the layouts of the previous frame (nodes are adopted only at the same one) */
    var previousScaleFactor:Float = -1.0;

    /** The scale factor of the layouts of the current frame */
    var frameScaleFactor:Float = -1.0;

    /** Nodes detached from an adopted parent during the frame (freed by `finishFrame()` unless used) */
    final detachedNodes:Array<Int> = [];

    /** Marks of the children of the node being adopted (`markCounter`), to find the children it lost */
    final childMarks:Array<Int> = [];
    var markCounter:Int = 0;

    /** Node requests of the views rendering, innermost last (see `beginViewNodes()`) */
    final viewNodesStack:Array<ViewNodes> = [];

    final viewNodesPool:Array<ViewNodes> = [];

    /** Whether the last `endViewNodes()` adopted every node it was given */
    public var lastViewNodesAdopted(default, null):Bool = false;

    /** State of the measure function (no closure allocated per layout or per measured leaf) */
    var measureWindow:Null<Window> = null;
    var measureCx:Null<App> = null;
    var measureScaleFactor:Float = 1;
    var measureNodeContext:Null<NodeContext> = null;

    public function new() {
        tree = new TaffyTree<NodeContext>();
        tree.disableRounding();
    }

    /**
     * Drops every node.
     */
    public function clear():Void {
        tree.clear();
        layoutBoundsFrames.resize(0);
        absoluteLayoutBounds.resize(0);
        absoluteLefts.resize(0);
        absoluteTops.resize(0);
        absoluteSizes.resize(0);
        absoluteOuterOriginsX.resize(0);
        absoluteOuterOriginsY.resize(0);
        computedLayoutFrames.resize(0);
        rootAvailableSpaces.clear();
        previousRootAvailableSpaces.clear();
        nodeFrames.resize(0);
        liveNodes.resize(0);
        previousLiveNodes.resize(0);
        viewNodesStack.resize(0);
        changeParents.resize(0);
        changeNodes.resize(0);
        changeOlds.resize(0);
        changeSnapshots.resize(0);
        detachedNodes.resize(0);
        frame++;
    }

    /**
     * Ends the frame: frees the nodes of the previous frame that were neither
     * created nor retained during this one, and clears the per frame caches.
     * Nodes of this frame stay alive (and retainable) during the next frame.
     */
    public function finishFrame():Void {
        // Changes not laid out during the frame: their parents' caches can't be trusted
        if (changeParents.length > 0) {
            final nodes = @:privateAccess tree.nodes;
            for (parent in changeParents) {
                if (nodes[parent] != null) {
                    tree.markDirty(parent);
                }
            }
            changeParents.resize(0);
            changeNodes.resize(0);
            changeOlds.resize(0);
            changeSnapshots.resize(0);
        }
        // Frees the nodes of the previous frame, and the nodes detached
        // during this one, that nothing created, adopted or retained during
        // this frame holds (parents are exact: every attach sets them)
        // Detached nodes first: their children recorded during the previous
        // frame are then looked at with their parent gone
        freeUnused(detachedNodes);
        freeUnused(previousLiveNodes);
        detachedNodes.resize(0);
        previousScaleFactor = frameScaleFactor;
        final previous = previousLiveNodes;
        previousLiveNodes = liveNodes;
        liveNodes = previous;
        liveNodes.resize(0);
        // Advancing the frame also invalidates the per node caches
        frame++;
        final spaces = previousRootAvailableSpaces;
        previousRootAvailableSpaces = rootAvailableSpaces;
        rootAvailableSpaces = spaces;
        rootAvailableSpaces.clear();
    }

    /**
     * Frees each node of `candidates` (and its subtree) that is not alive:
     * neither it nor an ancestor was created, adopted or retained during
     * this frame.
     */
    function freeUnused(candidates:Array<Int>):Void {
        final nodes = @:privateAccess tree.nodes;
        final freeIds = @:privateAccess tree.freeIds;
        final current = frame;
        final previousFrame = frame - 1;
        final stack = retainStack;
        // Parents are recorded after their children: the last first, so that
        // a node's parent is freed before the node is looked at; then again
        // until nothing changes, for the nodes recorded in another order
        var freed = true;
        while (freed) {
            freed = false;
            var index = candidates.length - 1;
            while (index >= 0) {
                final id = candidates[index];
                index--;
                final data = nodes[id];
                if (data == null || nodeFrames[id] == current) {
                    continue;
                }
                // A node with a parent is alive through it, or garbage under
                // an unused top that is a candidate too (a node loses its
                // parent only by being detached, which makes it a candidate,
                // or when its parent is freed): only the unused tops are freed
                final parent = data.parent;
                if (parent != -1 && nodes[parent] != null) {
                    continue;
                }
                freed = true;
                stack.push(id);
                while (stack.length > 0) {
                    final nodeId = Stacks.popInt(stack);
                    final nodeData = nodes[nodeId];
                    for (child in nodeData.children) {
                        final childFrame = nodeFrames[child];
                        if (childFrame == previousFrame) {
                            // A candidate itself (its parent is gone when it is looked at)
                            continue;
                        }
                        final childData = nodes[child];
                        if (childData != null && childData.parent == nodeId) {
                            if (childFrame == current) {
                                // Used during this frame but not attached anywhere: kept, detached
                                childData.parent = -1;
                            }
                            else {
                                // Inside a subtree retained by its root only
                                stack.push(child);
                            }
                        }
                    }
                    nodes[nodeId] = null;
                    freeIds.push(nodeId);
                    @:privateAccess tree.nodeCount--;
                }
            }
        }
    }

    /**
     * The current frame number (a node recorded during frame `n` can be
     * retained during frame `n + 1`).
     */
    public inline function currentFrame():Int {
        return frame;
    }

/// Amending the previous frame (in place rendering of a view, see `Window`)

    /** Whether the previous frame is being amended (see `beginAmend()`) */
    public var amending(default, null):Bool = false;

    /** Marks of the nodes adopted while amending (`takenMark`): `nodeFrames` cannot tell them */
    final takenMarks:Array<Int> = [];

    var takenMark:Int = 0;

    /**
     * Starts amending the previous frame: until `endAmend()`, the engine
     * works as if that frame were still being drawn, so that a view
     * rendered again alone (`Window`, in place rendering) requests,
     * adopts and lays out its nodes as part of it. Its nodes are recorded
     * in that frame (they are retainable and adoptable during the next
     * one, and freed at its end when unused like any node of that frame),
     * and the per node caches of that frame (absolute bounds) stay valid
     * for the nodes that did not change. Nothing of the frame being drawn
     * next is touched.
     */
    public function beginAmend():Void {
        amending = true;
        frame--;
        final live = liveNodes;
        liveNodes = previousLiveNodes;
        previousLiveNodes = live;
        final spaces = rootAvailableSpaces;
        rootAvailableSpaces = previousRootAvailableSpaces;
        previousRootAvailableSpaces = spaces;
        takenMark++;
    }

    /**
     * Ends `beginAmend()`. Changes left (`processChanges()` not run) mark
     * their parents dirty, like at the end of a frame.
     */
    public function endAmend(freeDetached:Bool = false):Void {
        if (freeDetached) {
            freeDetachedWhileAmending();
        }
        if (changeParents.length > 0) {
            final nodes = @:privateAccess tree.nodes;
            for (parent in changeParents) {
                if (nodes[parent] != null) {
                    tree.markDirty(parent);
                }
            }
            changeParents.resize(0);
            changeNodes.resize(0);
            changeOlds.resize(0);
            changeSnapshots.resize(0);
        }
        final spaces = rootAvailableSpaces;
        rootAvailableSpaces = previousRootAvailableSpaces;
        previousRootAvailableSpaces = spaces;
        final live = liveNodes;
        liveNodes = previousLiveNodes;
        previousLiveNodes = live;
        frame++;
        amending = false;
    }

    /**
     * Frees the nodes detached while amending that nothing attached again
     * (the old nodes of a view rendered alone), with their subtrees: frames
     * drawn in place may follow each other without a full frame, which is
     * where `finishFrame()` frees them otherwise. Also drops the freed ids
     * from the list of the amended frame when it grew much larger than the
     * tree.
     */
    function freeDetachedWhileAmending():Void {
        final nodes = @:privateAccess tree.nodes;
        final freeIds = @:privateAccess tree.freeIds;
        final stack = retainStack;
        for (i in 0...detachedNodes.length) {
            final id = detachedNodes[i];
            final data = nodes[id];
            if (data == null || data.parent != -1) {
                continue;
            }
            stack.push(id);
            while (stack.length > 0) {
                final nodeId = Stacks.popInt(stack);
                final nodeData = nodes[nodeId];
                for (child in nodeData.children) {
                    final childData = nodes[child];
                    // Children attached elsewhere since stay
                    if (childData != null && childData.parent == nodeId) {
                        stack.push(child);
                    }
                }
                nodes[nodeId] = null;
                freeIds.push(nodeId);
                @:privateAccess tree.nodeCount--;
            }
        }
        detachedNodes.resize(0);
        final live = liveNodes;
        if (live.length > 4096 && live.length > 2 * tree.totalNodeCount()) {
            var kept = 0;
            for (i in 0...live.length) {
                final id = live[i];
                if (nodes[id] != null) {
                    live[kept++] = id;
                }
            }
            live.resize(kept);
        }
    }

    /** Whether a node was adopted already during this frame (or this amend) */
    inline function taken(id:Int):Bool {
        return amending ? (id < takenMarks.length && takenMarks[id] == takenMark) : nodeFrames[id] == frame;
    }

    inline function markTaken(id:Int):Void {
        if (amending) {
            while (takenMarks.length <= id) {
                takenMarks.push(0);
            }
            takenMarks[id] = takenMark;
        }
    }

    /** The parent of a node, -1 for a root or a node that does not exist */
    public function parentOf(id:LayoutId):Int {
        final data = @:privateAccess tree.nodes[id];
        return data != null ? data.parent : -1;
    }

    /**
     * While amending: `newRoot`, the root of a view rendered again alone,
     * takes the place of `oldRoot` in the children of its parent, as the
     * parent's own render would have placed it; the change is recorded for
     * `processChanges()`.
     */
    public function replaceViewRoot(oldRoot:LayoutId, newRoot:LayoutId):Void {
        final nodes = @:privateAccess tree.nodes;
        final oldData = nodes[oldRoot];
        final parent = oldData.parent;
        final siblings = nodes[parent].children;
        siblings[siblings.indexOf(oldRoot)] = newRoot;
        nodes[newRoot].parent = parent;
        oldData.parent = -1;
        detachedNodes.push(oldRoot);
        changeParents.push(parent);
        changeNodes.push(newRoot);
        changeOlds.push(oldRoot);
        changeSnapshots.push(null);
    }

    /** The root of the view rendered alone (`processViewChanges`), -1 otherwise */
    var amendRoot:Int = -1;

    /** Whether `processChanges()` left work to the layout of the whole tree (see `processViewChanges`) */
    var amendEscaped:Bool = false;

    /** The nodes checked one level up by the current `processChanges()` (`climbMark`) */
    final climbMarks:Array<Int> = [];

    var climbMark:Int = 0;

    /** Whether a change reached the root of the view rendered alone (see `processViewChanges`) */
    var amendRootChanged:Bool = false;

    /**
     * Runs the early cutoff of the recorded changes now (`processChanges()`,
     * which `computeLayout()` runs first otherwise) for a view rendered
     * again alone, whose root is `root` (`oldRoot` before it rendered), and
     * tells whether the view keeps its layout for its parent: true when its
     * root lays out the same for every input its parent gave it, and its
     * subtree then has its final layout; the parent's cache is untouched.
     *
     * The changes are checked up to the view's root (`processChanges()`
     * stops there). When one is left to the root, or to the layout of the
     * whole tree, the view's subtree is laid out again from scratch for the
     * inputs its parent gave its root (`TaffyTree.matchesRelayout` of the
     * root against a copy of its cache), when its root does not share its
     * parent's block formatting context. Otherwise, or when its results
     * differ, false: the change of the root is recorded for its parent, and
     * `computeLayout()` lays out what changed.
     */
    /**
     * Starts the render of a view alone, whose root is `root` (see
     * `processViewChanges`): from now on, the changes reaching that root are
     * left to `processViewChanges`, even when a layout root inside the view
     * (a uniform list measuring an item) runs `processChanges()` first.
     * Returns a copy of the root's cache: the inputs its parent gave it.
     */
    public function beginViewChanges(root:LayoutId):taffy.tree.Cache {
        amendRoot = root;
        amendEscaped = false;
        amendRootChanged = false;
        return @:privateAccess tree.nodes[root].cache.snapshot();
    }

    public function processViewChanges(root:LayoutId, oldRoot:LayoutId, reference:taffy.tree.Cache, window:Window, cx:App):Bool {
        measureWindow = window;
        measureCx = cx;
        measureScaleFactor = window.scaleFactor();
        final nodes = @:privateAccess tree.nodes;
        processChanges();
        amendRoot = -1;
        final parent = nodes[root].parent;
        if (!amendEscaped && !amendRootChanged && root == oldRoot) {
            return true;
        }
        final parentStyle = nodes[parent].style;
        final ownContext = parentStyle.display == taffy.style.Display.Flex || parentStyle.display == taffy.style.Display.Grid;
        // (changes never climb past the view's root: whatever was left inside
        // is laid out again here)
        if (ownContext && !reference.lossy && reference.hasFinalLayout() && nodes[root].style.layoutEquals(nodes[oldRoot].style)) {
            clearSubtreeCaches(root);
            if (tree.matchesRelayout(root, reference, this, true)) {
                if (root != oldRoot) {
                    // The parent placed the old root: the new one gets its place
                    nodes[root].unroundedLayout = nodes[oldRoot].unroundedLayout;
                }
                return true;
            }
        }
        // Its parent lays out again (see `processChanges()`)
        changeParents.push(parent);
        changeNodes.push(root);
        changeOlds.push(root != oldRoot ? oldRoot : -1);
        changeSnapshots.push(root != oldRoot ? null : reference);
        return false;
    }

    /** Clears the layout caches of a subtree (laid out again from scratch) */
    function clearSubtreeCaches(root:LayoutId):Void {
        final nodes = @:privateAccess tree.nodes;
        final stack = layoutBoundsScratchSpace;
        stack.push(root);
        while (stack.length > 0) {
            final id = Stacks.popInt(stack);
            final data = nodes[id];
            data.cache.clear();
            for (child in data.children) {
                stack.push(child);
            }
        }
    }

    /**
     * Forgets the absolute bounds computed for the subtree of `root` (its
     * layout changed while amending: the per node caches of the amended
     * frame are kept for the other nodes).
     */
    public function forgetSubtreeBounds(root:LayoutId):Void {
        final nodes = @:privateAccess tree.nodes;
        final stack = layoutBoundsScratchSpace;
        stack.push(root);
        while (stack.length > 0) {
            final id = Stacks.popInt(stack);
            if (id < layoutBoundsFrames.length) {
                layoutBoundsFrames[id] = 0;
                absoluteLayoutBounds[id] = null;
            }
            final data = nodes[id];
            if (data != null) {
                for (child in data.children) {
                    stack.push(child);
                }
            }
        }
    }

    #if glaze_verify_layout
    /**
     * `glaze_verify_layout` for a view rendered again alone: its subtree is
     * laid out again from scratch for the inputs its root was laid out for,
     * and every node must get the layout it has.
     */
    public function verifySubtreeLayout(root:LayoutId):Void {
        final nodes = @:privateAccess tree.nodes;
        final rootData = nodes[root];
        final rootStyle = rootData.style;
        if (rootStyle.position.isOutOfFlow() || rootData.cache.lossy || !rootData.cache.hasFinalLayout()
            || (rootData.children.length > 0 && (rootStyle.display == taffy.style.Display.Block || rootStyle.display == taffy.style.Display.FlowRoot))) {
            // Not checkable alone (see `TaffyTree.matchesRelayout`)
            return;
        }
        final reference = rootData.cache.snapshot();
        final ids:Array<Int> = [];
        final layouts:Array<taffy.tree.Layout> = [];
        final stack = [(root:Int)];
        while (stack.length > 0) {
            final id = stack.pop();
            final data = nodes[id];
            ids.push(id);
            layouts.push(data.unroundedLayout);
            data.cache.clear();
            for (child in data.children) {
                stack.push(child);
            }
        }
        final rootLayout = nodes[root].unroundedLayout;
        if (!tree.matchesRelayout(root, reference, this)) {
            verifyLayoutErrors++;
            ceramic.Shortcuts.log.error('glaze_verify_layout: view root $root does not lay out again like its cached results');
        }
        // The root's own placement comes from its parent
        nodes[root].unroundedLayout = rootLayout;
        for (i in 1...ids.length) {
            final a = layouts[i];
            final b = nodes[ids[i]].unroundedLayout;
            if (!sameLayout(a, b)) {
                verifyLayoutErrors++;
                ceramic.Shortcuts.log.error('glaze_verify_layout: node ${ids[i]} (view root $root) has layout ${layoutString(a)} instead of ${layoutString(b)}');
            }
        }
    }
    #end

    inline function created(id:NodeId):LayoutId {
        #if glaze_count_allocations glaze.util.AllocationCounters.layoutNodes++; #end
        final index:Int = id;
        if (amending && index < layoutBoundsFrames.length) {
            // A reused id may hold caches of the amended frame from its previous node
            layoutBoundsFrames[index] = 0;
            absoluteLayoutBounds[index] = null;
            if (index < computedLayoutFrames.length) {
                computedLayoutFrames[index] = 0;
            }
        }
        nodeFrames[id] = frame;
        liveNodes.push(id);
        if (viewNodesStack.length > 0) {
            viewNodesStack[viewNodesStack.length - 1].nodes.push(id);
        }
        return id;
    }

    /**
     * Starts recording the nodes a view requests while it renders and
     * requests its layout (nested views record their own). With `adopt` (the
     * nodes the same view requested last time, all retained during this
     * frame), each request takes the next of these nodes instead of creating
     * one, as long as it matches: a node with the same children, or a
     * measured leaf for a measured leaf (its measure function is replaced).
     * The style of an adopted node is kept: a view that renders again
     * without being notified renders the same elements (the contract that
     * already lets a clean view keep its retained layout without rendering).
     * At the first request that does not match, the next nodes are created.
     * When every node is adopted, the tree is unchanged and so is its layout:
     * a clean view that renders again only because it moved (scrolling)
     * costs no layout at all, like GPUI where its elements are part of the
     * single layout of the frame.
     *
     * With `checked` (a view that renders because it changed: `adopt` is
     * what it requested during the previous frame), the requests match by
     * position: a node is adopted when its style is the same (`toTaffy` of
     * the new style, `Style.layoutEquals`) and it has as many children; its
     * children are replaced by the requested ones, and each child that
     * changed is recorded for `processChanges()`. A measured leaf is never
     * adopted (its content may have changed): a new one takes its place. A
     * node with another number of children ends the matching (the next
     * nodes are created).
     */
    public function beginViewNodes(adopt:Null<Array<Int>>, checked:Bool = false):Void {
        final viewNodes = viewNodesPool.length > 0 ? viewNodesPool.pop() : new ViewNodes();
        viewNodes.nodes = [];
        viewNodes.adopt = adopt;
        viewNodes.index = 0;
        viewNodes.failed = adopt == null;
        viewNodes.checked = checked;
        viewNodesStack.push(viewNodes);
    }

    /**
     * Ends `beginViewNodes()`: returns the nodes the view requested, in
     * request order, and sets `lastViewNodesAdopted` (whether every node to
     * adopt was adopted and nothing else was requested).
     */
    public function endViewNodes():Array<Int> {
        final viewNodes = viewNodesStack.pop();
        lastViewNodesAdopted = viewNodes.adopt != null && !viewNodes.failed && viewNodes.index == viewNodes.adopt.length;
        final nodes = viewNodes.nodes;
        viewNodes.nodes = null;
        viewNodes.adopt = null;
        viewNodesPool.push(viewNodes);
        return nodes;
    }

    /**
     * The next node to adopt for a request of the innermost view (children,
     * or a measure function for a measured leaf), or -1 to create one.
     */
    function adoptNode(children:Null<Array<LayoutId>>, measure:Null<MeasuredNode>):Int {
        if (viewNodesStack.length == 0) {
            return -1;
        }
        final viewNodes = viewNodesStack[viewNodesStack.length - 1];
        if (viewNodes.failed || viewNodes.checked) {
            return -1;
        }
        final adopt = viewNodes.adopt;
        if (viewNodes.index >= adopt.length) {
            viewNodes.failed = true;
            return -1;
        }
        final id = adopt[viewNodes.index];
        final data = @:privateAccess tree.nodes[id];
        // The view's root was retained during this frame, so its nodes are
        // alive (retaining marks the root only)
        var matches = data != null && data.hasContext == (measure != null);
        if (matches) {
            final current = data.children;
            final count = children != null ? children.length : 0;
            if (current.length != count) {
                matches = false;
            }
            else {
                for (i in 0...count) {
                    if (current[i] != (children[i]:Int)) {
                        matches = false;
                        break;
                    }
                }
            }
        }
        if (!matches) {
            viewNodes.failed = true;
            return -1;
        }
        viewNodes.index++;
        if (measure != null) {
            // The new element measures like the one it replaces did last:
            // its state (text lines...) is the one its prepaint expects
            final context = data.context;
            measure.copyMeasuredFrom(context);
            data.context = measure;
            if (measure.measuredSet) {
                measure.measureValues(measureWindow, measureCx);
            }
        }
        // A retained nested view detached its root when it retained it again
        final nodes = @:privateAccess tree.nodes;
        for (child in data.children) {
            nodes[child].parent = id;
        }
        viewNodes.nodes.push(id);
        return id;
    }

    /**
     * The next node to adopt for a request of the innermost view rendering
     * because it changed (`beginViewNodes()` with `checked`), or -1 to
     * create one: the node of the same position with the same style and as
     * many children. Its children become `children`; each one that is not
     * the node it had there is recorded for `processChanges()`.
     */
    function adoptChecked(style:taffy.style.Style, children:Null<Array<LayoutId>>, owned:Bool, scaleFactor:Float):Int {
        if (viewNodesStack.length == 0) {
            return -1;
        }
        final viewNodes = viewNodesStack[viewNodesStack.length - 1];
        if (viewNodes.failed || !viewNodes.checked) {
            return -1;
        }
        if (scaleFactor != previousScaleFactor) {
            // Measured sizes depend on the scale factor, which taffy's caches do not record
            viewNodes.failed = true;
            return -1;
        }
        final adopt = viewNodes.adopt;
        if (viewNodes.index >= adopt.length) {
            viewNodes.failed = true;
            return -1;
        }
        final nodes = @:privateAccess tree.nodes;
        final id = adopt[viewNodes.index];
        final data = nodes[id];
        final count = children != null ? children.length : 0;
        // Alive since the previous frame (frees happen between frames), not
        // taken yet during this one, and of the same kind
        if (data == null || taken(id) || data.hasContext || data.children.length != count) {
            viewNodes.failed = true;
            return -1;
        }
        viewNodes.index++;
        if (!data.style.layoutEquals(style)) {
            // Another node takes its place (its parent sees the change)
            return -1;
        }
        final current = data.children;
        var same = true;
        for (i in 0...count) {
            if (current[i] != (children[i]:Int)) {
                same = false;
                break;
            }
        }
        if (same) {
            for (child in current) {
                nodes[child].parent = id;
            }
        }
        else {
            final mark = ++markCounter;
            for (i in 0...count) {
                final child:Int = children[i];
                nodes[child].parent = id;
                childMarks[child] = mark;
                final old = current[i];
                if (old != child) {
                    changeParents.push(id);
                    changeNodes.push(child);
                    changeOlds.push(old);
                    changeSnapshots.push(null);
                }
            }
            // The children it lost are detached (freed unless used elsewhere)
            for (oldChild in current) {
                final old:Int = oldChild;
                final oldData = nodes[old];
                if (oldData != null && oldData.parent == id && (old >= childMarks.length || childMarks[old] != mark)) {
                    oldData.parent = -1;
                    detachedNodes.push(old);
                }
            }
            final list:Array<NodeId> = cast children;
            data.children = owned ? list : list.copy();
        }
        markTaken(id);
        if (nodeFrames[id] != frame) {
            nodeFrames[id] = frame;
            liveNodes.push(id);
        }
        viewNodes.nodes.push(id);
        return id;
    }

    /**
     * A measured leaf requested by a view rendering because it changed: the
     * node of the same position is not adopted, but must be a measured leaf
     * for the next requests to keep matching by position.
     */
    function skipChecked():Void {
        if (viewNodesStack.length == 0) {
            return;
        }
        final viewNodes = viewNodesStack[viewNodesStack.length - 1];
        if (viewNodes.failed || !viewNodes.checked) {
            return;
        }
        final adopt = viewNodes.adopt;
        if (viewNodes.index >= adopt.length) {
            viewNodes.failed = true;
            return;
        }
        final data = @:privateAccess tree.nodes[adopt[viewNodes.index]];
        if (data == null || !data.hasContext) {
            viewNodes.failed = true;
            return;
        }
        viewNodes.index++;
    }

    /**
     * Keeps the subtree of `id`, recorded during frame `recordedFrame`, for
     * the current frame and detaches it from its previous parent. Returns
     * false (and does nothing) if that subtree can't be retained anymore.
     */
    public function retain(id:LayoutId, recordedFrame:Int):Bool {
        if (recordedFrame != frame && recordedFrame != frame - 1) {
            return false;
        }
        final nodes = @:privateAccess tree.nodes;
        final root = nodes[id];
        if (root == null) {
            return false;
        }
        root.parent = -1;
        // The root only: its subtree is alive through it (see `finishFrame()`)
        if (nodeFrames[id] != frame) {
            nodeFrames[id] = frame;
            liveNodes.push(id);
        }
        return true;
    }

    /**
     * Replaces a subtree retained during this frame, and already laid out,
     * by `newRoot` (the subtree of the same view, rendered again), then lays
     * out again the root containing it, so that the new nodes are measured
     * exactly as if they had been part of the tree from the start (the other
     * nodes hit their layout cache). Returns false if the new subtree did
     * not get the same layout as the retained one.
     */
    public function replaceRetained(oldRoot:LayoutId, newRoot:LayoutId):Bool {
        final nodes = @:privateAccess tree.nodes;
        final oldData = nodes[oldRoot];
        final newData = nodes[newRoot];
        final oldLayout = oldData.unroundedLayout;
        final parent = oldData.parent;
        var top:Int;
        if (parent == -1) {
            top = newRoot;
        }
        else {
            final siblings = nodes[parent].children;
            siblings[siblings.indexOf(oldRoot)] = newRoot;
            newData.parent = parent;
            oldData.parent = -1;
            tree.markDirty(parent);
            top = parent;
            while (nodes[top].parent != -1) {
                top = nodes[top].parent;
            }
        }
        var available = rootAvailableSpaces.get(top == newRoot ? oldRoot : top);
        if (available == null) {
            available = new taffy.geometry.SizeAvail(
                taffy.style.AvailableSpace.Definite(oldLayout.size.width),
                taffy.style.AvailableSpace.Definite(oldLayout.size.height)
            );
        }
        if (top == newRoot) {
            rootAvailableSpaces.set(newRoot, available);
        }
        runLayout(top, available);
        final newLayout = newData.unroundedLayout;
        return newLayout.location.x == oldLayout.location.x
            && newLayout.location.y == oldLayout.location.y
            && newLayout.size.width == oldLayout.size.width
            && newLayout.size.height == oldLayout.size.height;
    }

    /**
     * Number of nodes currently in the tree.
     */
    public inline function nodeCount():Int {
        return tree.totalNodeCount();
    }

    public function requestLayout(style:Style, remSize:Pixels, scaleFactor:Float, children:Array<LayoutId>):LayoutId {
        return requestLayoutWith(style, remSize, scaleFactor, children, false);
    }

    /**
     * `requestLayout()`; with `owned`, a node made with these children keeps
     * the array instead of a copy (the caller gives it away and never
     * changes it again).
     */
    public function requestLayoutWith(style:Style, remSize:Pixels, scaleFactor:Float, children:Array<LayoutId>, owned:Bool):LayoutId {
        final adopted = adoptNode(children, null);
        if (adopted != -1) {
            return adopted;
        }
        final taffyStyle = toTaffy(style, remSize, scaleFactor);
        final checked = adoptChecked(taffyStyle, children, owned, scaleFactor);
        if (checked != -1) {
            return checked;
        }
        if (children == null || children.length == 0) {
            return created(tree.newLeaf(taffyStyle));
        }
        else {
            final nodes:Array<NodeId> = cast children;
            return created(owned ? tree.newWithChildrenOwned(taffyStyle, nodes) : tree.newWithChildren(taffyStyle, nodes));
        }
    }

    public function requestMeasuredLayout(style:Style, remSize:Pixels, scaleFactor:Float, measure:MeasureFn):LayoutId {
        return requestMeasuredNode(style, remSize, scaleFactor, new FunctionMeasuredNode(measure));
    }

    /** `requestMeasuredLayout()` with the measure as an object (the node's context). Internal. */
    @:noCompletion
    public function requestMeasuredNode(style:Style, remSize:Pixels, scaleFactor:Float, measure:MeasuredNode):LayoutId {
        final adopted = adoptNode(null, measure);
        if (adopted != -1) {
            return adopted;
        }
        skipChecked();
        final taffyStyle = toTaffy(style, remSize, scaleFactor);
        return created(tree.newLeafWithContext(taffyStyle, measure));
    }

    /**
     * Makes a node with an auto width / height fill the given size (used for
     * window roots, like the root element on the web).
     */
    public function stretchAutoSizeToFill(id:LayoutId, size:Size, scaleFactor:Float):Void {
        final style = tree.style(id);
        final stretchWidth = style.size.width.isAuto();
        final stretchHeight = style.size.height.isAuto();
        if (!stretchWidth && !stretchHeight) {
            return;
        }
        final width = stretchWidth ? Dimension.length(roundToDevicePixel(size.width, scaleFactor)) : style.size.width;
        final height = stretchHeight ? Dimension.length(roundToDevicePixel(size.height, scaleFactor)) : style.size.height;
        style.size = new taffy.geometry.SizeOf<Dimension>(width, height);
        tree.setStyle(id, style);
    }

    public function computeLayout(id:LayoutId, availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App):Void {
        if (computedLayoutFrames[id] == frame) {
            final stack = layoutBoundsScratchSpace;
            final boundsFrames = layoutBoundsFrames;
            stack.push(id);
            while (stack.length > 0) {
                final id = Stacks.popInt(stack);
                if (boundsFrames[id] == frame) {
                    boundsFrames[id] = 0;
                    absoluteLayoutBounds[id] = null;
                }
                // By index: `tree.children()` returns a copy
                for (i in 0...tree.childCount(id)) {
                    stack.push(tree.childAtIndex(id, i));
                }
            }
        }
        else {
            computedLayoutFrames[id] = frame;
        }

        final scaleFactor = window.scaleFactor();
        frameScaleFactor = scaleFactor;

        inline function transform(v:AvailableSpace):taffy.style.AvailableSpace {
            return switch v {
                case Definite(pixels): taffy.style.AvailableSpace.Definite(pixels * scaleFactor);
                case MinContent: taffy.style.AvailableSpace.MinContent;
                case MaxContent: taffy.style.AvailableSpace.MaxContent;
            }
        }
        final available = new taffy.geometry.SizeAvail(transform(availableSpace.width), transform(availableSpace.height));
        rootAvailableSpaces.set(id, available);

        measureWindow = window;
        measureCx = cx;
        // Inputs are recorded for the incremental layout of changed views,
        // which only happens with view caching (a little work per result)
        tree.recordInputs = window.viewCaching && !window.viewCachingDisabled;
        processChanges();
        runLayout(id, available);
        #if glaze_verify_layout
        verifyLayout(id, available);
        #end
    }

    /** Number of changed children checked by `processChanges()` and how many matched, for tests and benchmarks */
    public var changesChecked(default, null):Int = 0;
    public var changesMatched(default, null):Int = 0;

    /**
     * The early cutoff of incremental layout (see the class comment): for
     * each recorded change, deepest parents first, the new child is laid out
     * for the inputs of the node it replaced; when a result differs, its
     * parent's cache is cleared and the parent itself is checked the same
     * way against a copy of that cache, one level up. A parent whose cache
     * is already empty (new, or cleared) is laid out again anyway.
     */
    function processChanges():Void {
        final count = changeParents.length;
        if (count == 0) {
            return;
        }
        climbMark++;
        final nodes = @:privateAccess tree.nodes;
        final window = measureWindow;
        measureScaleFactor = window != null ? window.scaleFactor() : 1.0;

        // Changes by depth of their parent, deepest last
        final buckets = changeBuckets;
        for (bucket in buckets) {
            bucket.resize(0);
        }
        var maxDepth = 0;
        for (k in 0...count) {
            final depth = depthOf(changeParents[k]);
            changeDepths[k] = depth;
            while (buckets.length <= depth) {
                buckets.push([]);
            }
            buckets[depth].push(k);
            if (depth > maxDepth) {
                maxDepth = depth;
            }
        }

        var depth = maxDepth;
        while (depth >= 0) {
            final bucket = buckets[depth];
            var b = 0;
            while (b < bucket.length) {
                final k = bucket[b];
                b++;
                final parent = changeParents[k];
                final parentData = nodes[parent];
                if (changeNodes[k] == amendRoot) {
                    // The root of the view rendered alone: checked by `processViewChanges`
                    amendRootChanged = true;
                    continue;
                }
                if (parentData == null || parentData.isEmpty()) {
                    // Checked one level up already (another child of it
                    // changed), or laid out with the whole tree
                    if (parentData == null || parent >= climbMarks.length || climbMarks[parent] != climbMark) {
                        amendEscaped = true;
                    }
                    continue;
                }
                final node = changeNodes[k];
                final nodeData = nodes[node];
                final old = changeOlds[k];
                var matches = false;
                if (nodeData != null) {
                    changesChecked++;
                    if (old != -1) {
                        final oldData = nodes[old];
                        matches = oldData != null
                            && !taken(old)
                            && oldData.style.layoutEquals(nodeData.style)
                            && tree.matchesRelayout(node, oldData.cache, this);
                        if (matches) {
                            // The parent placed the old node: the new one gets its place
                            nodeData.unroundedLayout = oldData.unroundedLayout;
                        }
                    }
                    else {
                        matches = tree.matchesRelayout(node, changeSnapshots[k], this);
                    }
                    if (matches) {
                        changesMatched++;
                    }
                }
                if (!matches) {
                    // The parent may lay out differently: check it one level up
                    final grandParent = parentData.parent;
                    if (grandParent == -1 || depth == 0 || nodes[grandParent] == null || nodes[grandParent].isEmpty()) {
                        parentData.cache.clear();
                        // Left to the layout of the whole tree
                        amendEscaped = true;
                    }
                    else {
                        final snapshot = parentData.cache.snapshot();
                        parentData.cache.clear();
                        while (climbMarks.length <= parent) {
                            climbMarks.push(0);
                        }
                        climbMarks[parent] = climbMark;
                        final index = changeParents.length;
                        changeParents.push(grandParent);
                        changeNodes.push(parent);
                        changeOlds.push(-1);
                        changeSnapshots.push(snapshot);
                        changeDepths[index] = depth - 1;
                        buckets[depth - 1].push(index);
                    }
                }
            }
            depth--;
        }

        changeParents.resize(0);
        changeNodes.resize(0);
        changeOlds.resize(0);
        changeSnapshots.resize(0);
    }

    /** Number of ancestors of a node */
    function depthOf(id:Int):Int {
        final nodes = @:privateAccess tree.nodes;
        var depth = 0;
        var current = nodes[id].parent;
        while (current != -1 && nodes[current] != null) {
            depth++;
            current = nodes[current].parent;
        }
        return depth;
    }

    #if glaze_verify_layout
    /**
     * Checks the incremental layout (define `glaze_verify_layout`): the
     * subtree of `root` is laid out again with every cache cleared, and each
     * node must get exactly the layout it has; a difference is logged as an
     * error, and the fresh layout is kept.
     */
    function verifyLayout(root:LayoutId, available:taffy.geometry.SizeAvail):Void {
        final nodes = @:privateAccess tree.nodes;
        final ids:Array<Int> = [];
        final layouts:Array<taffy.tree.Layout> = [];
        final stack = [(root:Int)];
        while (stack.length > 0) {
            final id = stack.pop();
            final data = nodes[id];
            ids.push(id);
            layouts.push(data.unroundedLayout);
            data.cache.clear();
            for (child in data.children) {
                stack.push(child);
            }
        }
        runLayout(root, available);
        for (i in 0...ids.length) {
            final a = layouts[i];
            final b = nodes[ids[i]].unroundedLayout;
            if (!sameLayout(a, b)) {
                verifyLayoutErrors++;
                ceramic.Shortcuts.log.error('glaze_verify_layout: node ${ids[i]} (root $root) has layout ${layoutString(a)} instead of ${layoutString(b)}');
            }
        }
    }

    /** Number of differences found by `glaze_verify_layout` */
    public static var verifyLayoutErrors:Int = 0;

    static function sameLayout(a:taffy.tree.Layout, b:taffy.tree.Layout):Bool {
        inline function same(x:Float, y:Float):Bool {
            return x == y ? (x != 0.0 || 1.0 / x == 1.0 / y) : (x != x && y != y);
        }
        inline function sameRect(x:taffy.geometry.Rect, y:taffy.geometry.Rect):Bool {
            return same(x.left, y.left) && same(x.right, y.right) && same(x.top, y.top) && same(x.bottom, y.bottom);
        }
        return a == b || (a.order == b.order
            && same(a.location.x, b.location.x) && same(a.location.y, b.location.y)
            && same(a.size.width, b.size.width) && same(a.size.height, b.size.height)
            && sameRect(a.scrollableOverflowRect, b.scrollableOverflowRect)
            && same(a.scrollbarSize.width, b.scrollbarSize.width) && same(a.scrollbarSize.height, b.scrollbarSize.height)
            && sameRect(a.border, b.border) && sameRect(a.padding, b.padding) && sameRect(a.margin, b.margin));
    }

    static function layoutString(layout:taffy.tree.Layout):String {
        inline function rect(r:taffy.geometry.Rect):String {
            return '[${r.left} ${r.right} ${r.top} ${r.bottom}]';
        }
        return '(order ${layout.order}, ${layout.location.x}, ${layout.location.y}, ${layout.size.width} x ${layout.size.height}, overflow ${rect(layout.scrollableOverflowRect)}, scrollbar ${layout.scrollbarSize.width} x ${layout.scrollbarSize.height}, border ${rect(layout.border)}, padding ${rect(layout.padding)}, margin ${rect(layout.margin)})';
    }
    #end

    /** Number of layout runs (a root laid out by taffy) since the engine was created, for tests and benchmarks */
    public var runCount(default, null):Int = 0;

    function runLayout(id:LayoutId, available:taffy.geometry.SizeAvail):Void {
        runCount++;
        final window = measureWindow;
        measureScaleFactor = window != null ? window.scaleFactor() : 1.0;
        // The engine is the measurer: a typed call per leaf (a measure
        // function value would box the node id on hxcpp)
        tree.computeLayoutWithMeasurer(id, available, this);
    }

    @:noCompletion
    public function measureLeafNode(input:taffy.tree.LayoutInput, nodeId:NodeId, nodeContext:NodeContext, style:taffy.style.Style):taffy.tree.LayoutOutput {
        return measureNode(input, nodeId, nodeContext, style);
    }

    function measureNode(input:taffy.tree.LayoutInput, nodeId:NodeId, nodeContext:Null<NodeContext>, style:taffy.style.Style):taffy.tree.LayoutOutput {
        final previous = measureNodeContext;
        measureNodeContext = nodeContext;
        // The engine is the leaf measurer too: the known and available sizes come as values
        final output = Leaf.computeLeafLayoutWithMeasurer(input, style, this);
        measureNodeContext = previous;
        return output;
    }

    @:noCompletion
    public function measureLeafSize(knownWidth:OptionalFloat, knownHeight:OptionalFloat, availableWidth:taffy.style.AvailableSpace, availableHeight:taffy.style.AvailableSpace):Void {
        final nodeContext = measureNodeContext;
        if (nodeContext == null) {
            lastMeasuredWidth = 0.0;
            lastMeasuredHeight = 0.0;
            return;
        }
        final scaleFactor = measureScaleFactor;

        // The arguments in logical pixels, as values on the node (no objects
        // per measured leaf: see `MeasuredNode.measureValues`)
        nodeContext.measuredSet = true;
        final hasWidth = knownWidth.isSome();
        nodeContext.measuredHasKnownWidth = hasWidth;
        nodeContext.measuredKnownWidth = hasWidth ? knownWidth.unwrap() / scaleFactor : 0.0;
        final hasHeight = knownHeight.isSome();
        nodeContext.measuredHasKnownHeight = hasHeight;
        nodeContext.measuredKnownHeight = hasHeight ? knownHeight.unwrap() / scaleFactor : 0.0;
        switch availableWidth {
            case taffy.style.AvailableSpace.MinContent:
                nodeContext.measuredAvailableWidthKind = MeasuredNode.AVAILABLE_MIN_CONTENT;
                nodeContext.measuredAvailableWidth = 0.0;
            case taffy.style.AvailableSpace.MaxContent:
                nodeContext.measuredAvailableWidthKind = MeasuredNode.AVAILABLE_MAX_CONTENT;
                nodeContext.measuredAvailableWidth = 0.0;
            case definite:
                nodeContext.measuredAvailableWidthKind = MeasuredNode.AVAILABLE_DEFINITE;
                nodeContext.measuredAvailableWidth = definite.definiteValue() / scaleFactor;
        }
        switch availableHeight {
            case taffy.style.AvailableSpace.MinContent:
                nodeContext.measuredAvailableHeightKind = MeasuredNode.AVAILABLE_MIN_CONTENT;
                nodeContext.measuredAvailableHeight = 0.0;
            case taffy.style.AvailableSpace.MaxContent:
                nodeContext.measuredAvailableHeightKind = MeasuredNode.AVAILABLE_MAX_CONTENT;
                nodeContext.measuredAvailableHeight = 0.0;
            case definite:
                nodeContext.measuredAvailableHeightKind = MeasuredNode.AVAILABLE_DEFINITE;
                nodeContext.measuredAvailableHeight = definite.definiteValue() / scaleFactor;
        }

        final measured = nodeContext.measureValues(measureWindow, measureCx);
        // Set after the measure (which may measure other leaves)
        lastMeasuredWidth = ceilToDevicePixel(Math.max(measured.width, 0.0), scaleFactor);
        lastMeasuredHeight = ceilToDevicePixel(Math.max(measured.height, 0.0), scaleFactor);
    }

    /** The width of the last `measureLeafSize()` (taffy reads it right after) */
    var lastMeasuredWidth:Float = 0.0;

    /** The height of the last `measureLeafSize()` */
    var lastMeasuredHeight:Float = 0.0;

    @:noCompletion
    public function measuredWidth():Float {
        return lastMeasuredWidth;
    }

    @:noCompletion
    public function measuredHeight():Float {
        return lastMeasuredHeight;
    }

    /**
     * Bounds of a laid out node in logical pixels, relative to the root,
     * with outer edges snapped to device pixels in absolute coordinates.
     */
    public function layoutBounds(id:LayoutId, scaleFactor:Float):Bounds {
        computeBounds(id, scaleFactor);
        var bounds = absoluteLayoutBounds[id];
        if (bounds == null) {
            bounds = new Bounds(new Point(absoluteLefts[id], absoluteTops[id]), absoluteSizes[id]);
            absoluteLayoutBounds[id] = bounds;
        }
        return bounds;
    }

    /** The origin x of `layoutBounds()`, after `computeBounds()` in the same frame */
    public inline function boundsLeft(id:LayoutId):Float {
        return absoluteLefts[id];
    }

    /** The origin y of `layoutBounds()`, after `computeBounds()` in the same frame */
    public inline function boundsTop(id:LayoutId):Float {
        return absoluteTops[id];
    }

    /** The size of `layoutBounds()`, after `computeBounds()` in the same frame */
    public inline function boundsSize(id:LayoutId):Size {
        return absoluteSizes[id];
    }

    /**
     * Computes what `layoutBounds()` returns (`boundsLeft()`, `boundsTop()`,
     * `boundsSize()`) without making its `Bounds`.
     */
    public function computeBounds(id:LayoutId, scaleFactor:Float):Void {
        if (layoutBoundsFrames[id] == frame) {
            return;
        }

        final layout = tree.layout(id);
        // The parent id without `tree.parent()`, whose `Null<NodeId>` is boxed on hxcpp
        final parent:Int = @:privateAccess tree.node(id).parent;

        var originX:Float;
        var originY:Float;
        if (parent != -1) {
            final parentId:LayoutId = parent;
            computeBounds(parentId, scaleFactor);
            // GPUI adds `Pixels` (f32)
            originX = SpringMath.f32(absoluteOuterOriginsX[parentId] + layout.location.x);
            originY = SpringMath.f32(absoluteOuterOriginsY[parentId] + layout.location.y);
        }
        else {
            originX = layout.location.x;
            originY = layout.location.y;
        }
        absoluteOuterOriginsX[id] = originX;
        absoluteOuterOriginsY[id] = originY;

        final farX = SpringMath.f32(originX + layout.size.width);
        final farY = SpringMath.f32(originY + layout.size.height);
        final left = roundHalfTowardZero(originX);
        final top = roundHalfTowardZero(originY);
        final right = roundHalfTowardZero(farX);
        final bottom = roundHalfTowardZero(farY);

        absoluteLefts[id] = left / scaleFactor;
        absoluteTops[id] = top / scaleFactor;
        absoluteSizes[id] = new Size((right - left) / scaleFactor, (bottom - top) / scaleFactor);
        absoluteLayoutBounds[id] = null;
        layoutBoundsFrames[id] = frame;
    }

    /**
     * The taffy style of a node (for tests).
     */
    public inline function taffyStyle(id:LayoutId):taffy.style.Style {
        return tree.style(id);
    }

/// Pixel snapping (GPUI's util.rs)

    /**
     * Rounds to the nearest integer, midpoints toward zero.
     */
    public static inline function roundHalfTowardZero(value:Float):Float {
        // Rust: `(value.abs() - 0.5).ceil().copysign(value)`; the ceil of
        // a small magnitude is -0.0, so the sign must come from `value`
        return glaze.util.MathUtil.copysign(Math.fceil(Math.abs(value) - 0.5), value);
    }

    public static inline function roundToDevicePixel(logical:Float, scaleFactor:Float):Float {
        return roundHalfTowardZero(logical * scaleFactor);
    }

    public static inline function roundStrokeToDevicePixel(logical:Float, scaleFactor:Float):Float {
        return logical == 0.0 ? 0.0 : Math.max(roundToDevicePixel(Math.max(logical, 0.0), scaleFactor), 1.0);
    }

    public static inline function floorToDevicePixel(logical:Float, scaleFactor:Float):Float {
        return Math.ffloor(logical * scaleFactor);
    }

    public static inline function ceilToDevicePixel(logical:Float, scaleFactor:Float):Float {
        return Math.fceil(logical * scaleFactor);
    }

/// Style conversion (GPUI's `ToTaffy`)

    static inline function absoluteToTaffy(length:AbsoluteLength, remSize:Pixels, scaleFactor:Float):Float {
        return roundToDevicePixel(length.toPixels(remSize), scaleFactor);
    }

    static function definiteToLengthPercentage(length:DefiniteLength, remSize:Pixels, scaleFactor:Float):LengthPercentage {
        return switch length {
            case Absolute(length): LengthPercentage.length(absoluteToTaffy(length, remSize, scaleFactor));
            case Fraction(fraction): LengthPercentage.percent(fraction);
        }
    }

    static function definiteToLengthPercentageAuto(length:DefiniteLength, remSize:Pixels, scaleFactor:Float):LengthPercentageAuto {
        return switch length {
            case Absolute(length): LengthPercentageAuto.length(absoluteToTaffy(length, remSize, scaleFactor));
            case Fraction(fraction): LengthPercentageAuto.percent(fraction);
        }
    }

    static function definiteToDimension(length:DefiniteLength, remSize:Pixels, scaleFactor:Float):Dimension {
        return switch length {
            case Absolute(length): Dimension.length(absoluteToTaffy(length, remSize, scaleFactor));
            case Fraction(fraction): Dimension.percent(fraction);
        }
    }

    static function lengthToLengthPercentageAuto(length:Length, remSize:Pixels, scaleFactor:Float):LengthPercentageAuto {
        return switch length {
            case Definite(length): definiteToLengthPercentageAuto(length, remSize, scaleFactor);
            case Auto: LengthPercentageAuto.auto();
        }
    }

    static function lengthToDimension(length:Length, remSize:Pixels, scaleFactor:Float):Dimension {
        return switch length {
            case Definite(length): definiteToDimension(length, remSize, scaleFactor);
            case Auto: Dimension.auto();
        }
    }

    static function borderWidthToTaffy(width:AbsoluteLength, remSize:Pixels, scaleFactor:Float):LengthPercentage {
        return LengthPercentage.length(roundStrokeToDevicePixel(width.toPixels(remSize), scaleFactor));
    }

    static function toGridRepeat(template:Null<GridTemplate>):Array<GridTemplateComponent> {
        if (template == null) {
            return [];
        }
        final track = switch template.minSize {
            // grid-template-*: repeat(<number>, minmax(0, 1fr));
            case Zero: GridHelpers.minmax(MinTrackSizingFunction.length(0.0), MaxTrackSizingFunction.fr(1.0));
            // grid-template-*: repeat(<number>, minmax(min-content, 1fr));
            case MinContent: GridHelpers.minmax(MinTrackSizingFunction.minContent(), MaxTrackSizingFunction.fr(1.0));
            // grid-template-*: repeat(<number>, minmax(0, max-content))
            case MaxContent: GridHelpers.minmax(MinTrackSizingFunction.length(0.0), MaxTrackSizingFunction.maxContent());
        }
        return [GridHelpers.repeatCount(template.repeat, [track])];
    }

    static function toGridPlacement(placement:GridPlacement):taffy.style.GridPlacement {
        return switch placement {
            case Line(index): taffy.style.GridPlacement.Line(index);
            case Span(span): taffy.style.GridPlacement.Span(span);
            case Auto: taffy.style.GridPlacement.Auto;
        }
    }

    static function alignItemsToTaffy(value:AlignItems):taffy.style.AlignItems {
        return switch value {
            case Start: taffy.style.AlignItems.START;
            case End: taffy.style.AlignItems.END;
            case FlexStart: taffy.style.AlignItems.FLEX_START;
            case FlexEnd: taffy.style.AlignItems.FLEX_END;
            case Center: taffy.style.AlignItems.CENTER;
            case Baseline: taffy.style.AlignItems.BASELINE;
            case Stretch: taffy.style.AlignItems.STRETCH;
        }
    }

    static function alignContentToTaffy(value:AlignContent):taffy.style.AlignContent {
        return switch value {
            case Start: taffy.style.AlignContent.START;
            case End: taffy.style.AlignContent.END;
            case FlexStart: taffy.style.AlignContent.FLEX_START;
            case FlexEnd: taffy.style.AlignContent.FLEX_END;
            case Center: taffy.style.AlignContent.CENTER;
            case Stretch: taffy.style.AlignContent.STRETCH;
            case SpaceBetween: taffy.style.AlignContent.SPACE_BETWEEN;
            case SpaceEvenly: taffy.style.AlignContent.SPACE_EVENLY;
            case SpaceAround: taffy.style.AlignContent.SPACE_AROUND;
        }
    }

    static function displayToTaffy(value:Display):taffy.style.Display {
        return switch value {
            case Block: taffy.style.Display.Block;
            case Flex: taffy.style.Display.Flex;
            case Grid: taffy.style.Display.Grid;
            case None: taffy.style.Display.None;
        }
    }

    // Shared values of the common taffy geometry (taffy's geometry fields are
    // final, and taffy shares its own defaults the same way): `toTaffy()`
    // allocates a rect or size only when its values are not all the same
    // shared zero or auto length
    static final OVERFLOW_VISIBLE = new taffy.geometry.PointOf<taffy.style.Overflow>(taffy.style.Overflow.Visible, taffy.style.Overflow.Visible);
    static final LPA_RECT_AUTO = new taffy.geometry.RectOf<LengthPercentageAuto>(LengthPercentageAuto.AUTO, LengthPercentageAuto.AUTO, LengthPercentageAuto.AUTO, LengthPercentageAuto.AUTO);
    static final LPA_RECT_ZERO = new taffy.geometry.RectOf<LengthPercentageAuto>(LengthPercentageAuto.ZERO, LengthPercentageAuto.ZERO, LengthPercentageAuto.ZERO, LengthPercentageAuto.ZERO);
    static final LP_RECT_ZERO = new taffy.geometry.RectOf<LengthPercentage>(LengthPercentage.ZERO, LengthPercentage.ZERO, LengthPercentage.ZERO, LengthPercentage.ZERO);
    static final LPA_SIZE_AUTO = new taffy.geometry.SizeOf<LengthPercentageAuto>(LengthPercentageAuto.AUTO, LengthPercentageAuto.AUTO);
    static final DIMENSION_SIZE_AUTO = new taffy.geometry.SizeOf<Dimension>(Dimension.AUTO, Dimension.AUTO);
    static final LP_SIZE_ZERO = new taffy.geometry.SizeOf<LengthPercentage>(LengthPercentage.ZERO, LengthPercentage.ZERO);

    static function overflowPoint(x:taffy.style.Overflow, y:taffy.style.Overflow):taffy.geometry.PointOf<taffy.style.Overflow> {
        return x == taffy.style.Overflow.Visible && y == taffy.style.Overflow.Visible ? OVERFLOW_VISIBLE : new taffy.geometry.PointOf<taffy.style.Overflow>(x, y);
    }

    static function lpaRect(left:LengthPercentageAuto, right:LengthPercentageAuto, top:LengthPercentageAuto, bottom:LengthPercentageAuto):taffy.geometry.RectOf<LengthPercentageAuto> {
        final l = left.intoRaw();
        if (l == right.intoRaw() && l == top.intoRaw() && l == bottom.intoRaw()) {
            if (l == LengthPercentageAuto.AUTO.intoRaw()) return LPA_RECT_AUTO;
            if (l == LengthPercentageAuto.ZERO.intoRaw()) return LPA_RECT_ZERO;
        }
        return new taffy.geometry.RectOf<LengthPercentageAuto>(left, right, top, bottom);
    }

    static function lpRect(left:LengthPercentage, right:LengthPercentage, top:LengthPercentage, bottom:LengthPercentage):taffy.geometry.RectOf<LengthPercentage> {
        final l = left.intoRaw();
        if (l == LengthPercentage.ZERO.intoRaw() && l == right.intoRaw() && l == top.intoRaw() && l == bottom.intoRaw()) {
            return LP_RECT_ZERO;
        }
        return new taffy.geometry.RectOf<LengthPercentage>(left, right, top, bottom);
    }

    static function lpaSize(width:LengthPercentageAuto, height:LengthPercentageAuto):taffy.geometry.SizeOf<LengthPercentageAuto> {
        final w = width.intoRaw();
        if (w == LengthPercentageAuto.AUTO.intoRaw() && w == height.intoRaw()) {
            return LPA_SIZE_AUTO;
        }
        return new taffy.geometry.SizeOf<LengthPercentageAuto>(width, height);
    }

    static function dimensionSize(width:Dimension, height:Dimension):taffy.geometry.SizeOf<Dimension> {
        final w = width.intoRaw();
        if (w == Dimension.AUTO.intoRaw() && w == height.intoRaw()) {
            return DIMENSION_SIZE_AUTO;
        }
        return new taffy.geometry.SizeOf<Dimension>(width, height);
    }

    static function lpSize(width:LengthPercentage, height:LengthPercentage):taffy.geometry.SizeOf<LengthPercentage> {
        final w = width.intoRaw();
        if (w == LengthPercentage.ZERO.intoRaw() && w == height.intoRaw()) {
            return LP_SIZE_ZERO;
        }
        return new taffy.geometry.SizeOf<LengthPercentage>(width, height);
    }

    static function overflowToTaffy(value:Overflow):taffy.style.Overflow {
        return switch value {
            case Visible: taffy.style.Overflow.Visible;
            case Clip: taffy.style.Overflow.Clip;
            case Hidden: taffy.style.Overflow.Hidden;
            case Scroll: taffy.style.Overflow.Scroll;
        }
    }

    static function flexDirectionToTaffy(value:FlexDirection):taffy.style.FlexDirection {
        return switch value {
            case Row: taffy.style.FlexDirection.Row;
            case Column: taffy.style.FlexDirection.Column;
            case RowReverse: taffy.style.FlexDirection.RowReverse;
            case ColumnReverse: taffy.style.FlexDirection.ColumnReverse;
        }
    }

    static function flexWrapToTaffy(value:FlexWrap):taffy.style.FlexWrap {
        return switch value {
            case NoWrap: taffy.style.FlexWrap.NoWrap;
            case Wrap: taffy.style.FlexWrap.Wrap;
            case WrapReverse: taffy.style.FlexWrap.WrapReverse;
        }
    }

    /**
     * Converts a GPUI style to a taffy style, in device pixels (GPUI's
     * `Style::to_taffy`). Authored absolute lengths are rounded to device pixels.
     */
    public static function toTaffy(style:Style, remSize:Pixels, scaleFactor:Float):taffy.style.Style {
        final result = new taffy.style.Style();
        result.display = displayToTaffy(style.display);
        result.overflow = overflowPoint(overflowToTaffy(style.overflowX), overflowToTaffy(style.overflowY));
        result.scrollbarWidth = absoluteToTaffy(style.scrollbarWidth, remSize, scaleFactor);
        result.position = style.position == Absolute ? taffy.style.Position.Absolute : taffy.style.Position.Relative;
        // Taffy's RectOf constructor takes (left, right, top, bottom)
        result.inset = lpaRect(
            lengthToLengthPercentageAuto(style.insetLeft, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.insetRight, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.insetTop, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.insetBottom, remSize, scaleFactor)
        );
        result.size = dimensionSize(
            lengthToDimension(style.sizeWidth, remSize, scaleFactor),
            lengthToDimension(style.sizeHeight, remSize, scaleFactor)
        );
        result.minSize = lpaSize(
            lengthToLengthPercentageAuto(style.minSizeWidth, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.minSizeHeight, remSize, scaleFactor)
        );
        result.maxSize = lpaSize(
            lengthToLengthPercentageAuto(style.maxSizeWidth, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.maxSizeHeight, remSize, scaleFactor)
        );
        result.aspectRatio = style.isSome(StyleRefinement.ASPECT_RATIO) ? OptionalFloat.some(style.aspectRatio) : OptionalFloat.NONE;
        result.margin = lpaRect(
            lengthToLengthPercentageAuto(style.marginLeft, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.marginRight, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.marginTop, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.marginBottom, remSize, scaleFactor)
        );
        result.padding = lpRect(
            definiteToLengthPercentage(style.paddingLeft, remSize, scaleFactor),
            definiteToLengthPercentage(style.paddingRight, remSize, scaleFactor),
            definiteToLengthPercentage(style.paddingTop, remSize, scaleFactor),
            definiteToLengthPercentage(style.paddingBottom, remSize, scaleFactor)
        );
        result.border = lpRect(
            borderWidthToTaffy(style.borderWidthLeft, remSize, scaleFactor),
            borderWidthToTaffy(style.borderWidthRight, remSize, scaleFactor),
            borderWidthToTaffy(style.borderWidthTop, remSize, scaleFactor),
            borderWidthToTaffy(style.borderWidthBottom, remSize, scaleFactor)
        );
        result.alignItems = style.isSome(StyleRefinement.ALIGN_ITEMS) ? alignItemsToTaffy(style.alignItems) : taffy.style.AlignItems.NORMAL;
        result.alignSelf = style.isSome(StyleRefinement.ALIGN_SELF) ? alignItemsToTaffy(style.alignSelf) : null;
        result.alignContent = style.isSome(StyleRefinement.ALIGN_CONTENT) ? alignContentToTaffy(style.alignContent) : taffy.style.AlignContent.NORMAL;
        result.justifyContent = style.isSome(StyleRefinement.JUSTIFY_CONTENT) ? alignContentToTaffy(style.justifyContent) : taffy.style.AlignContent.NORMAL;
        result.gap = lpSize(
            definiteToLengthPercentage(style.gapWidth, remSize, scaleFactor),
            definiteToLengthPercentage(style.gapHeight, remSize, scaleFactor)
        );
        result.flexDirection = flexDirectionToTaffy(style.flexDirection);
        result.flexWrap = flexWrapToTaffy(style.flexWrap);
        result.flexBasis = lengthToDimension(style.flexBasis, remSize, scaleFactor);
        result.flexGrow = style.flexGrow;
        result.flexShrink = style.flexShrink;
        // Without a grid template, taffy's default (shared, empty) stays
        if (style.gridRows != null) result.gridTemplateRows = toGridRepeat(style.gridRows);
        if (style.gridCols != null) result.gridTemplateColumns = toGridRepeat(style.gridCols);
        final location = style.gridLocation;
        if (location != null) {
            result.gridRow = new LineOf<taffy.style.GridPlacement>(toGridPlacement(location.rowStart), toGridPlacement(location.rowEnd));
            result.gridColumn = new LineOf<taffy.style.GridPlacement>(toGridPlacement(location.columnStart), toGridPlacement(location.columnEnd));
        }
        return result;
    }

}

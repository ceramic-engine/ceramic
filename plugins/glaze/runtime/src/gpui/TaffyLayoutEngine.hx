// Ported from gpui-pre 0.3.10: src/taffy.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Stacks;
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

private class NodeContext {
    public var measure:MeasureFn;
    /** The arguments of the last call to `measure`, null before the first one */
    public var lastKnown:Null<SizeOf<Null<Float>>> = null;
    public var lastAvailable:Null<SizeOf<AvailableSpace>> = null;
    public function new(measure:MeasureFn) {
        this.measure = measure;
    }
}

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
    final rootAvailableSpaces:IntMap<taffy.geometry.SizeAvail> = new IntMap();

    /** The frame number, advanced by `finishFrame()` */
    var frame:Int = 1;

    /** The last frame each node was created or retained in, by node id */
    final nodeFrames:Array<Int> = [];

    /** Nodes created or retained during the current frame */
    var liveNodes:Array<Int> = [];

    /** Nodes created or retained during the previous frame */
    var previousLiveNodes:Array<Int> = [];

    final retainStack:Array<Int> = [];

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
        nodeFrames.resize(0);
        liveNodes.resize(0);
        previousLiveNodes.resize(0);
        viewNodesStack.resize(0);
        frame++;
    }

    /**
     * Ends the frame: frees the nodes of the previous frame that were neither
     * created nor retained during this one, and clears the per frame caches.
     * Nodes of this frame stay alive (and retainable) during the next frame.
     */
    public function finishFrame():Void {
        final nodes = @:privateAccess tree.nodes;
        final freeIds = @:privateAccess tree.freeIds;
        for (id in previousLiveNodes) {
            if (nodeFrames[id] != frame && nodes[id] != null) {
                nodes[id] = null;
                freeIds.push(id);
                @:privateAccess tree.nodeCount--;
            }
        }
        final previous = previousLiveNodes;
        previousLiveNodes = liveNodes;
        liveNodes = previous;
        liveNodes.resize(0);
        // Advancing the frame also invalidates the per node caches
        frame++;
        rootAvailableSpaces.clear();
    }

    /**
     * The current frame number (a node recorded during frame `n` can be
     * retained during frame `n + 1`).
     */
    public inline function currentFrame():Int {
        return frame;
    }

    inline function created(id:NodeId):LayoutId {
        #if gpui_count_allocations gpui.util.AllocationCounters.layoutNodes++; #end
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
     */
    public function beginViewNodes(adopt:Null<Array<Int>>):Void {
        final viewNodes = viewNodesPool.length > 0 ? viewNodesPool.pop() : new ViewNodes();
        viewNodes.nodes = [];
        viewNodes.adopt = adopt;
        viewNodes.index = 0;
        viewNodes.failed = adopt == null;
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
    function adoptNode(children:Null<Array<LayoutId>>, measure:Null<MeasureFn>):Int {
        if (viewNodesStack.length == 0) {
            return -1;
        }
        final viewNodes = viewNodesStack[viewNodesStack.length - 1];
        if (viewNodes.failed) {
            return -1;
        }
        final adopt = viewNodes.adopt;
        if (viewNodes.index >= adopt.length) {
            viewNodes.failed = true;
            return -1;
        }
        final id = adopt[viewNodes.index];
        final data = @:privateAccess tree.nodes[id];
        var matches = data != null && nodeFrames[id] == frame && data.hasContext == (measure != null);
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
            context.measure = measure;
            if (context.lastKnown != null) {
                measure(context.lastKnown, context.lastAvailable, measureWindow, measureCx);
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
        if (nodeFrames[id] == frame) {
            return true;
        }
        final stack = retainStack;
        stack.push(id);
        while (stack.length > 0) {
            final nodeId = Stacks.popInt(stack);
            if (nodeFrames[nodeId] != frame) {
                nodeFrames[nodeId] = frame;
                liveNodes.push(nodeId);
                for (child in nodes[nodeId].children) {
                    stack.push(child);
                }
            }
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
        if (children == null || children.length == 0) {
            return created(tree.newLeaf(taffyStyle));
        }
        else {
            final nodes:Array<NodeId> = cast children;
            return created(owned ? tree.newWithChildrenOwned(taffyStyle, nodes) : tree.newWithChildren(taffyStyle, nodes));
        }
    }

    public function requestMeasuredLayout(style:Style, remSize:Pixels, scaleFactor:Float, measure:MeasureFn):LayoutId {
        final adopted = adoptNode(null, measure);
        if (adopted != -1) {
            return adopted;
        }
        final taffyStyle = toTaffy(style, remSize, scaleFactor);
        return created(tree.newLeafWithContext(taffyStyle, new NodeContext(measure)));
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
        runLayout(id, available);
    }

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

    static final NONE_KNOWN = new SizeOf<Null<Float>>(null, null);

    /** The known dimensions given to the last measured leaf with some (reused while unchanged) */
    var lastKnown:Null<SizeOf<Null<Float>>> = null;
    var lastKnownHasWidth:Bool = false;
    var lastKnownHasHeight:Bool = false;
    var lastKnownWidth:Float = 0.0;
    var lastKnownHeight:Float = 0.0;

    /** The available space given to the last measured leaf (immutable values reused while unchanged) */
    var lastAvailable:Null<SizeOf<AvailableSpace>> = null;
    var lastAvailableWidth:AvailableSpace = AvailableSpace.MaxContent;
    var lastAvailableHeight:AvailableSpace = AvailableSpace.MaxContent;

    /**
     * The port's available space of a taffy one in logical pixels: `previous`
     * when it is the same `Definite` value (same bits), a new one otherwise.
     */
    /** The same value, zero signs included */
    static inline function sameFloat(a:Float, b:Float):Bool {
        return a == b && (b != 0.0 || 1.0 / a == 1.0 / b);
    }

    static function untransformAvailable(ev:taffy.style.AvailableSpace, scaleFactor:Float, previous:AvailableSpace):AvailableSpace {
        return switch ev {
            case taffy.style.AvailableSpace.MinContent: AvailableSpace.MinContent;
            case taffy.style.AvailableSpace.MaxContent: AvailableSpace.MaxContent;
            case definite:
                final value:Float = definite.definiteValue() / scaleFactor;
                switch previous {
                    case Definite(last) if (sameFloat(last, value)):
                        previous;
                    case _:
                        AvailableSpace.Definite(value);
                }
        }
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

        // Immutable values: none known shares one object, and the available
        // space of the last measure is reused when it is the same
        var known = NONE_KNOWN;
        if (knownWidth.isSome() || knownHeight.isSome()) {
            final hasWidth = knownWidth.isSome();
            final hasHeight = knownHeight.isSome();
            final width = hasWidth ? knownWidth.unwrap() / scaleFactor : 0.0;
            final height = hasHeight ? knownHeight.unwrap() / scaleFactor : 0.0;
            final last = lastKnown;
            if (last != null && hasWidth == lastKnownHasWidth && hasHeight == lastKnownHasHeight
                && (!hasWidth || sameFloat(width, lastKnownWidth)) && (!hasHeight || sameFloat(height, lastKnownHeight))) {
                known = last;
            }
            else {
                known = new SizeOf<Null<Float>>(hasWidth ? width : null, hasHeight ? height : null);
                lastKnown = known;
                lastKnownHasWidth = hasWidth;
                lastKnownHasHeight = hasHeight;
                lastKnownWidth = width;
                lastKnownHeight = height;
            }
        }

        final width = untransformAvailable(availableWidth, scaleFactor, lastAvailableWidth);
        final height = untransformAvailable(availableHeight, scaleFactor, lastAvailableHeight);
        var available = lastAvailable;
        if (available == null || available.width != width || available.height != height) {
            available = new SizeOf<AvailableSpace>(width, height);
            lastAvailable = available;
        }
        lastAvailableWidth = width;
        lastAvailableHeight = height;

        nodeContext.lastKnown = known;
        nodeContext.lastAvailable = available;
        final measured = nodeContext.measure(known, available, measureWindow, measureCx);
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
        return gpui.util.MathUtil.copysign(Math.fceil(Math.abs(value) - 0.5), value);
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

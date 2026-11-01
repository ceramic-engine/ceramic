// Ported from gpui-pre 0.3.10: src/taffy.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import haxe.ds.IntMap;
import taffy.compute.Leaf;
import taffy.geometry.LineOf;
import taffy.geometry.PointOf as TaffyPointOf;
import taffy.geometry.RectOf as TaffyRectOf;
import taffy.geometry.SizeOf as TaffySizeOf;
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

/**
 * Measures a leaf node: given its known dimensions (`null` when unknown) and
 * the available space, in logical pixels, returns its size in logical pixels.
 */
typedef MeasureFn = (knownDimensions:SizeOf<Null<Float>>, availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App) -> Size;

private class NodeContext {
    public final measure:MeasureFn;
    public function new(measure:MeasureFn) {
        this.measure = measure;
    }
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
 * render after all (its bounds changed), its new subtree replaces the
 * retained one (`replaceRetained()`).
 */
class TaffyLayoutEngine {

    final tree:TaffyTree<NodeContext>;

    final absoluteLayoutBounds:IntMap<Bounds> = new IntMap();

    final absoluteOuterOriginsX:IntMap<Float> = new IntMap();

    final absoluteOuterOriginsY:IntMap<Float> = new IntMap();

    final computedLayouts:IntMap<Bool> = new IntMap();

    final layoutBoundsScratchSpace:Array<LayoutId> = [];

    /** Available space of the roots laid out during the current frame, in device pixels */
    final rootAvailableSpaces:IntMap<TaffySizeOf<taffy.style.AvailableSpace>> = new IntMap();

    /** The frame number, advanced by `finishFrame()` */
    var frame:Int = 1;

    /** The last frame each node was created or retained in, by node id */
    final nodeFrames:Array<Int> = [];

    /** Nodes created or retained during the current frame */
    var liveNodes:Array<Int> = [];

    /** Nodes created or retained during the previous frame */
    var previousLiveNodes:Array<Int> = [];

    final retainStack:Array<Int> = [];

    /** State of the measure function (no closure allocated per layout or per measured leaf) */
    var measureWindow:Null<Window> = null;
    var measureCx:Null<App> = null;
    var measureScaleFactor:Float = 1;
    var measureNodeContext:Null<NodeContext> = null;
    final taffyMeasure:taffy.tree.TaffyTree.MeasureFunction<NodeContext>;
    final leafMeasure:taffy.compute.Leaf.LeafMeasureFunction;

    public function new() {
        tree = new TaffyTree<NodeContext>();
        tree.disableRounding();
        taffyMeasure = measureNode;
        leafMeasure = measureLeaf;
    }

    /**
     * Drops every node.
     */
    public function clear():Void {
        tree.clear();
        absoluteLayoutBounds.clear();
        absoluteOuterOriginsX.clear();
        absoluteOuterOriginsY.clear();
        computedLayouts.clear();
        rootAvailableSpaces.clear();
        nodeFrames.resize(0);
        liveNodes.resize(0);
        previousLiveNodes.resize(0);
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
        frame++;
        absoluteLayoutBounds.clear();
        absoluteOuterOriginsX.clear();
        absoluteOuterOriginsY.clear();
        computedLayouts.clear();
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
            final nodeId = stack.pop();
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
            available = new TaffySizeOf<taffy.style.AvailableSpace>(
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
        final taffyStyle = toTaffy(style, remSize, scaleFactor);
        if (children == null || children.length == 0) {
            return created(tree.newLeaf(taffyStyle));
        }
        else {
            final nodes:Array<NodeId> = cast children;
            return created(tree.newWithChildren(taffyStyle, nodes));
        }
    }

    public function requestMeasuredLayout(style:Style, remSize:Pixels, scaleFactor:Float, measure:MeasureFn):LayoutId {
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
        style.size = new TaffySizeOf<Dimension>(width, height);
        tree.setStyle(id, style);
    }

    public function computeLayout(id:LayoutId, availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App):Void {
        if (computedLayouts.exists(id)) {
            final stack = layoutBoundsScratchSpace;
            stack.push(id);
            while (stack.length > 0) {
                final id = stack.pop();
                absoluteLayoutBounds.remove(id);
                absoluteOuterOriginsX.remove(id);
                absoluteOuterOriginsY.remove(id);
                for (child in tree.children(id)) {
                    stack.push(child);
                }
            }
        }
        else {
            computedLayouts.set(id, true);
        }

        final scaleFactor = window.scaleFactor();

        inline function transform(v:AvailableSpace):taffy.style.AvailableSpace {
            return switch v {
                case Definite(pixels): taffy.style.AvailableSpace.Definite(pixels * scaleFactor);
                case MinContent: taffy.style.AvailableSpace.MinContent;
                case MaxContent: taffy.style.AvailableSpace.MaxContent;
            }
        }
        final available = new TaffySizeOf<taffy.style.AvailableSpace>(transform(availableSpace.width), transform(availableSpace.height));
        rootAvailableSpaces.set(id, available);

        measureWindow = window;
        measureCx = cx;
        runLayout(id, available);
    }

    function runLayout(id:LayoutId, available:TaffySizeOf<taffy.style.AvailableSpace>):Void {
        final window = measureWindow;
        measureScaleFactor = window != null ? window.scaleFactor() : 1.0;
        tree.computeLayoutWithMeasure(id, available, taffyMeasure);
    }

    function measureNode(input:taffy.tree.LayoutInput, nodeId:NodeId, nodeContext:Null<NodeContext>, style:taffy.style.Style):taffy.tree.LayoutOutput {
        final previous = measureNodeContext;
        measureNodeContext = nodeContext;
        final output = Leaf.computeLeafLayout(input, style, leafMeasure);
        measureNodeContext = previous;
        return output;
    }

    function measureLeaf(knownDimensions:TaffySizeOf<Null<Float>>, availableSpace:TaffySizeOf<taffy.style.AvailableSpace>):taffy.geometry.Size {
        final nodeContext = measureNodeContext;
        if (nodeContext == null) {
            return taffy.geometry.Size.ZERO;
        }
        final scaleFactor = measureScaleFactor;

        final knownWidth:Null<Float> = knownDimensions.width;
        final knownHeight:Null<Float> = knownDimensions.height;
        final known = new SizeOf<Null<Float>>(
            knownWidth != null ? knownWidth / scaleFactor : null,
            knownHeight != null ? knownHeight / scaleFactor : null
        );

        inline function untransform(ev:taffy.style.AvailableSpace):AvailableSpace {
            return switch ev {
                case Definite(value): AvailableSpace.Definite(value / scaleFactor);
                case MinContent: AvailableSpace.MinContent;
                case MaxContent: AvailableSpace.MaxContent;
            }
        }
        final available = new SizeOf<AvailableSpace>(untransform(availableSpace.width), untransform(availableSpace.height));

        final measured = nodeContext.measure(known, available, measureWindow, measureCx);
        return new taffy.geometry.Size(
            ceilToDevicePixel(Math.max(measured.width, 0.0), scaleFactor),
            ceilToDevicePixel(Math.max(measured.height, 0.0), scaleFactor)
        );
    }

    /**
     * Bounds of a laid out node in logical pixels, relative to the root,
     * with outer edges snapped to device pixels in absolute coordinates.
     */
    public function layoutBounds(id:LayoutId, scaleFactor:Float):Bounds {
        final cached = absoluteLayoutBounds.get(id);
        if (cached != null) {
            return cached;
        }

        final layout = tree.layout(id);
        final parent:Null<NodeId> = tree.parent(id);

        var originX:Float;
        var originY:Float;
        if (parent != null) {
            final parentId:LayoutId = (parent : NodeId);
            layoutBounds(parentId, scaleFactor);
            // GPUI adds `Pixels` (f32)
            originX = SpringMath.f32(absoluteOuterOriginsX.get(parentId) + layout.location.x);
            originY = SpringMath.f32(absoluteOuterOriginsY.get(parentId) + layout.location.y);
        }
        else {
            originX = layout.location.x;
            originY = layout.location.y;
        }
        absoluteOuterOriginsX.set(id, originX);
        absoluteOuterOriginsY.set(id, originY);

        final farX = SpringMath.f32(originX + layout.size.width);
        final farY = SpringMath.f32(originY + layout.size.height);
        final left = roundHalfTowardZero(originX);
        final top = roundHalfTowardZero(originY);
        final right = roundHalfTowardZero(farX);
        final bottom = roundHalfTowardZero(farY);

        final bounds = new Bounds(
            new Point(left / scaleFactor, top / scaleFactor),
            new Size((right - left) / scaleFactor, (bottom - top) / scaleFactor)
        );
        absoluteLayoutBounds.set(id, bounds);
        return bounds;
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
        result.overflow = new TaffyPointOf<taffy.style.Overflow>(overflowToTaffy(style.overflowX), overflowToTaffy(style.overflowY));
        result.scrollbarWidth = absoluteToTaffy(style.scrollbarWidth, remSize, scaleFactor);
        result.position = style.position == Absolute ? taffy.style.Position.Absolute : taffy.style.Position.Relative;
        // Taffy's RectOf constructor takes (left, right, top, bottom)
        result.inset = new TaffyRectOf<LengthPercentageAuto>(
            lengthToLengthPercentageAuto(style.insetLeft, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.insetRight, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.insetTop, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.insetBottom, remSize, scaleFactor)
        );
        result.size = new TaffySizeOf<Dimension>(
            lengthToDimension(style.sizeWidth, remSize, scaleFactor),
            lengthToDimension(style.sizeHeight, remSize, scaleFactor)
        );
        result.minSize = new TaffySizeOf<LengthPercentageAuto>(
            lengthToLengthPercentageAuto(style.minSizeWidth, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.minSizeHeight, remSize, scaleFactor)
        );
        result.maxSize = new TaffySizeOf<LengthPercentageAuto>(
            lengthToLengthPercentageAuto(style.maxSizeWidth, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.maxSizeHeight, remSize, scaleFactor)
        );
        result.aspectRatio = style.isSome(StyleRefinement.ASPECT_RATIO) ? style.aspectRatio : null;
        result.margin = new TaffyRectOf<LengthPercentageAuto>(
            lengthToLengthPercentageAuto(style.marginLeft, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.marginRight, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.marginTop, remSize, scaleFactor),
            lengthToLengthPercentageAuto(style.marginBottom, remSize, scaleFactor)
        );
        result.padding = new TaffyRectOf<LengthPercentage>(
            definiteToLengthPercentage(style.paddingLeft, remSize, scaleFactor),
            definiteToLengthPercentage(style.paddingRight, remSize, scaleFactor),
            definiteToLengthPercentage(style.paddingTop, remSize, scaleFactor),
            definiteToLengthPercentage(style.paddingBottom, remSize, scaleFactor)
        );
        result.border = new TaffyRectOf<LengthPercentage>(
            borderWidthToTaffy(style.borderWidthLeft, remSize, scaleFactor),
            borderWidthToTaffy(style.borderWidthRight, remSize, scaleFactor),
            borderWidthToTaffy(style.borderWidthTop, remSize, scaleFactor),
            borderWidthToTaffy(style.borderWidthBottom, remSize, scaleFactor)
        );
        result.alignItems = style.isSome(StyleRefinement.ALIGN_ITEMS) ? alignItemsToTaffy(style.alignItems) : taffy.style.AlignItems.NORMAL;
        result.alignSelf = style.isSome(StyleRefinement.ALIGN_SELF) ? alignItemsToTaffy(style.alignSelf) : null;
        result.alignContent = style.isSome(StyleRefinement.ALIGN_CONTENT) ? alignContentToTaffy(style.alignContent) : taffy.style.AlignContent.NORMAL;
        result.justifyContent = style.isSome(StyleRefinement.JUSTIFY_CONTENT) ? alignContentToTaffy(style.justifyContent) : taffy.style.AlignContent.NORMAL;
        result.gap = new TaffySizeOf<LengthPercentage>(
            definiteToLengthPercentage(style.gapWidth, remSize, scaleFactor),
            definiteToLengthPercentage(style.gapHeight, remSize, scaleFactor)
        );
        result.flexDirection = flexDirectionToTaffy(style.flexDirection);
        result.flexWrap = flexWrapToTaffy(style.flexWrap);
        result.flexBasis = lengthToDimension(style.flexBasis, remSize, scaleFactor);
        result.flexGrow = style.flexGrow;
        result.flexShrink = style.flexShrink;
        result.gridTemplateRows = toGridRepeat(style.gridRows);
        result.gridTemplateColumns = toGridRepeat(style.gridCols);
        final location = style.gridLocation;
        if (location != null) {
            result.gridRow = new LineOf<taffy.style.GridPlacement>(toGridPlacement(location.rowStart), toGridPlacement(location.rowEnd));
            result.gridColumn = new LineOf<taffy.style.GridPlacement>(toGridPlacement(location.columnStart), toGridPlacement(location.columnEnd));
        }
        return result;
    }

}

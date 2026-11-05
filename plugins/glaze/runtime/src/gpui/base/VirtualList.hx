// Ported from gpui-kit 0.8.1: crates/base/src/virtual_list.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-004 (Infer sizing of horizontal lists). See DEVIATIONS.md.
package gpui.base;

import gpui.AbsoluteLength;
import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Axis;
import gpui.Bounds;
import gpui.ContentMask;
import gpui.Context;
import gpui.UniformList.DeferredScrollToItem;
import gpui.Div;
import gpui.Edges;
import gpui.Element;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.GlobalElementId;
import gpui.Hitbox;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.ListSizingBehavior;
import gpui.Point;
import gpui.ScrollHandle;
import gpui.ScrollStrategy;
import gpui.Size;
import gpui.SizeOf;
import gpui.Style;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.Scrollbar.ScrollbarHandleImpl;

import gpui.Prelude.*;

using gpui.base.InteractiveElementExt;

/**
 * The state of a `VirtualListScrollHandle` (Rust `VirtualListScrollHandleState`).
 */
@:allow(gpui.base)
class VirtualListScrollHandleState {

    var axis:Axis = Vertical;

    var itemsCount:Int = 0;

    /** Content bounds size (excluding padding and border) from the last frame. */
    var lastContentSize:Null<Size> = null;

    public var deferredScrollToItem:Null<DeferredScrollToItem> = null;

    function new() {}

}

/**
 * A scroll handle for `VirtualList`. It forwards the `ScrollHandle` methods
 * to its base handle (Rust `Deref<Target = ScrollHandle>`).
 */
class VirtualListScrollHandle implements ScrollbarHandleImpl {

    @:allow(gpui.base) final state:VirtualListScrollHandleState = new VirtualListScrollHandleState();

    @:allow(gpui.base) var _baseHandle:ScrollHandle = new ScrollHandle();

    /** Create a new VirtualListScrollHandle. */
    public function new() {}

    /** Rust `From<ScrollHandle>`. */
    public static function fromScrollHandle(handle:ScrollHandle):VirtualListScrollHandle {
        final result = new VirtualListScrollHandle();
        result._baseHandle = handle;
        return result;
    }

    /** Get the base scroll handle. */
    public inline function baseHandle():ScrollHandle {
        return _baseHandle;
    }

    public function viewportBounds():Bounds {
        return _baseHandle.bounds();
    }

    public function offset():Point {
        return _baseHandle.offset();
    }

    public function setOffset(offset:Point):Void {
        _baseHandle.setOffset(offset);
    }

    public function contentSize():Size {
        final max = _baseHandle.maxOffset();
        final size = _baseHandle.bounds().size;
        return new Size(max.x + size.width, max.y + size.height);
    }

    public function startDrag():Void {}

    public function endDrag():Void {}

    /** `ScrollHandle::bounds`. */
    public inline function bounds():Bounds {
        return _baseHandle.bounds();
    }

    /** `ScrollHandle::max_offset`. */
    public inline function maxOffset():Point {
        return _baseHandle.maxOffset();
    }

    /** Scroll to the item at the given index. */
    public function scrollToItem(ix:Int, strategy:ScrollStrategy):Void {
        scrollToItemWithOffset(ix, strategy, 0);
    }

    /** Scroll to the item at the given index, with an additional offset items. */
    function scrollToItemWithOffset(ix:Int, strategy:ScrollStrategy, offset:Int):Void {
        state.deferredScrollToItem = new DeferredScrollToItem(ix, strategy, offset, false);
    }

    /** Scrolls to the bottom of the list. */
    public function scrollToBottom():Void {
        final itemsCount = state.itemsCount;
        scrollToItem(itemsCount > 0 ? itemsCount - 1 : 0, Top);
    }

}

/**
 * Per-item sizes along the list axis, gap included, and their prefix sums.
 */
@:allow(gpui.base)
class ItemSizeLayout {

    var itemsSizes:Array<Size> = [];

    var contentSize:Size = new Size();

    var sizes:Array<Float> = [];

    var origins:Array<Float> = [];

    var lastLayoutBounds:Bounds = new Bounds();

    function new() {}

    function copy():ItemSizeLayout {
        final result = new ItemSizeLayout();
        result.itemsSizes = itemsSizes;
        result.contentSize = contentSize;
        result.sizes = sizes;
        result.origins = origins;
        result.lastLayoutBounds = lastLayoutBounds;
        return result;
    }

    /**
     * The bounds of item `ix` in the list's content space: offset from the
     * content origin along the list axis, filling it on the other.
     */
    function itemBounds(ix:Int, axis:Axis, contentBounds:Bounds):Null<Bounds> {
        if (ix < 0 || ix >= origins.length) return null;
        final origin = origins[ix];
        final itemSize = sizes[ix];
        return switch axis {
            case Horizontal: new Bounds(new Point(contentBounds.left() + origin, 0.), new Size(itemSize, contentBounds.size.height));
            case Vertical: new Bounds(new Point(0., contentBounds.top() + origin), new Size(contentBounds.size.width, itemSize));
        }
    }

}

/**
 * VirtualList component for rendering a large number of differently sized items.
 *
 * Only visible range are rendered for performance reasons. Inspired by
 * `uniformList`, but each item can have a different size (each row height
 * or column width must be known in advance).
 *
 * Ranges are `start, end` arguments.
 */
class VirtualList extends Element implements Styled {

    final _id:ElementId;

    final axis:Axis;

    var base:Div;

    var scrollHandle:VirtualListScrollHandle;

    final itemsCount:Int;

    final itemSizes:Array<Size>;

    final renderItems:(Int, Int, Window, App) -> Array<AnyElement>;

    var sizingBehavior:ListSizingBehavior = ListSizingBehavior.Auto;

    var itemToMeasureIndex:Int = 0;

    // Frame state (Rust `VirtualListFrameState`) and prepaint state

    final items:Array<AnyElement> = [];

    var sizeLayout:ItemSizeLayout = new ItemSizeLayout();

    var hitbox:Null<Hitbox> = null;

    @:allow(gpui.base)
    function new(id:ElementId, axis:Axis, base:Div, scrollHandle:VirtualListScrollHandle, itemSizes:Array<Size>, renderItems:(Int, Int, Window, App) -> Array<AnyElement>) {
        _id = id;
        this.axis = axis;
        this.base = base;
        this.scrollHandle = scrollHandle;
        this.itemsCount = itemSizes.length;
        this.itemSizes = itemSizes;
        this.renderItems = renderItems;
    }

    /**
     * Create a `VirtualList` in vertical direction.
     *
     * The `itemSizes` is the size of each row. Only the `height` is used; `width` is inferred
     * by measuring the item selected with `withItemToMeasureIndex`, defaulting to the first item.
     */
    public static inline function vVirtualList<V:gpui.Model>(view:Entity<V>, id:ElementIdArg, itemSizes:Array<Size>, f:(V, Int, Int, Window, Context<V>) -> Array<IntoElement>):VirtualList {
        return virtualList(view, id, Vertical, itemSizes, f);
    }

    /**
     * Create a `VirtualList` in horizontal direction.
     *
     * The `itemSizes` is the size of each column. Only the `width` is used; `height` is inferred
     * by measuring the item selected with `withItemToMeasureIndex`, defaulting to the first item.
     */
    public static inline function hVirtualList<V:gpui.Model>(view:Entity<V>, id:ElementIdArg, itemSizes:Array<Size>, f:(V, Int, Int, Window, Context<V>) -> Array<IntoElement>):VirtualList {
        return virtualList(view, id, Horizontal, itemSizes, f);
    }

    public static function virtualList<V:gpui.Model>(view:Entity<V>, id:ElementIdArg, axis:Axis, itemSizes:Array<Size>, f:(V, Int, Int, Window, Context<V>) -> Array<IntoElement>):VirtualList {
        final id:ElementId = id;
        final scrollHandle = new VirtualListScrollHandle();
        final renderRange = (start:Int, end:Int, window:Window, cx:App) -> {
            return view.update(cx, (this_, cx) -> [for (component in f(this_, start, end, window, cx)) component.intoAnyElement()]);
        };

        return new VirtualList(
            id,
            axis,
            div()
                .id(id)
                .sizeFull()
                .overflowScroll()
                .lockScrollAxis()
                .trackScroll(scrollHandle._baseHandle),
            scrollHandle,
            itemSizes,
            renderRange
        );
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    override public function elementId():Null<ElementId> {
        return _id;
    }

    public function trackScroll(scrollHandle:VirtualListScrollHandle):VirtualList {
        base = base.trackScroll(scrollHandle._baseHandle);
        this.scrollHandle = scrollHandle;
        return this;
    }

    /** Set the sizing behavior for the list. */
    public function withSizingBehavior(behavior:ListSizingBehavior):VirtualList {
        sizingBehavior = behavior;
        return this;
    }

    /** Set the item index used to infer the list's cross-axis size. */
    public function withItemToMeasureIndex(index:Int):VirtualList {
        itemToMeasureIndex = index;
        return this;
    }

    /**
     * Specify for table.
     *
     * Table is special, because the `scrollHandle` is based on Table head (That is not a virtual list).
     */
    public function withScrollHandle(scrollHandle:VirtualListScrollHandle):VirtualList {
        base = div().id(_id).sizeFull();
        this.scrollHandle = scrollHandle;
        return this;
    }

    function scrollToDeferredItem(scrollOffset:Point, sizeLayout:ItemSizeLayout, contentBounds:Bounds, scrollToItem:DeferredScrollToItem):Point {
        final bounds = sizeLayout.itemBounds(scrollToItem.itemIndex + scrollToItem.offset, axis, contentBounds);
        if (bounds == null) {
            return scrollOffset;
        }

        var x = scrollOffset.x;
        var y = scrollOffset.y;
        switch scrollToItem.strategy {
            case Center:
                if (axis == Vertical) {
                    y = contentBounds.top() + contentBounds.size.height / 2. - bounds.top() - bounds.size.height / 2.;
                }
                else {
                    x = contentBounds.left() + contentBounds.size.width / 2. - bounds.left() - bounds.size.width / 2.;
                }
            case _:
                // Ref: https://github.com/zed-industries/zed/blob/0d145289e0867a8d5d63e5e1397a5ca69c9d49c3/crates/gpui/src/elements/div.rs#L3026
                if (axis == Vertical) {
                    if (bounds.top() + y < contentBounds.top()) {
                        y = contentBounds.top() - bounds.top();
                    }
                    else if (bounds.bottom() + y > contentBounds.bottom()) {
                        y = contentBounds.bottom() - bounds.bottom();
                    }
                }
                else {
                    if (bounds.left() + x < contentBounds.left()) {
                        x = contentBounds.left() - bounds.left();
                    }
                    else if (bounds.right() + x > contentBounds.right()) {
                        x = contentBounds.right() - bounds.right();
                    }
                }
        }
        final result = new Point(x, y);
        scrollHandle.setOffset(result);
        return result;
    }

    function measureItem(listWidth:Null<Float>, window:Window, cx:App):Size {
        if (itemsCount == 0) {
            return new Size();
        }

        final itemIx = Std.int(Math.min(itemToMeasureIndex, itemsCount - 1));
        final items = renderItems(itemIx, itemIx + 1, window, cx);
        final itemToMeasure = items.pop();
        if (itemToMeasure == null) {
            return new Size();
        }
        final availableSpace = new SizeOf<AvailableSpace>(
            listWidth != null ? AvailableSpace.Definite(listWidth) : AvailableSpace.MinContent,
            AvailableSpace.MinContent
        );
        return itemToMeasure.layoutAsRoot(availableSpace, window, cx);
    }

    static function sameSizes(a:Array<Size>, b:Array<Size>):Bool {
        if (a == b) return true;
        if (a.length != b.length) return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i])) return false;
        }
        return true;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final remSize = window.remSize();
        final fontSize = window.textStyle().fontSize.toPixels(remSize);
        var sizeLayout = new ItemSizeLayout();
        // Measure vertical lists at the last known content width so relative
        // widths and text truncation resolve like the visible rows; an
        // unconstrained measure would turn one long non-wrapping text into a
        // phantom horizontal scroll range.
        final listWidth:Null<Float> = if (axis == Vertical) {
            final last = scrollHandle.state.lastContentSize;
            last != null && last.width != 0. ? last.width : null;
        }
        else {
            null;
        }
        final longestItemSize = measureItem(listWidth, window, cx);

        // `base.interactivity.requestLayout(.., (style, window, cx) -> ..)` without
        // the closure
        final style = base.interactivity.requestLayoutStyle(globalId, #if gpui_inspector inspectorId, #end window, cx);
        sizeLayout = window.withElementState(globalId, ItemSizeLayout, (box, _) -> {
            if (box.value == null) box.value = new ItemSizeLayout();
            final state = box.value;

            // Including the gap between items for calculate the item size
            final gapLength = axis == Horizontal ? style.gapWidth : style.gapHeight;
            final gap = gapLength.toPixelsOf(fontSize, remSize);

            if (!sameSizes(state.itemsSizes, itemSizes)) {
                state.itemsSizes = itemSizes;
                // Prepare each item's size by axis
                final sizes = [];
                for (i in 0...itemSizes.length) {
                    final size = axis == Horizontal ? itemSizes[i].width : itemSizes[i].height;
                    sizes.push(i + 1 == itemsCount ? size : size + gap);
                }
                state.sizes = sizes;

                // Prepare each item's origin by axis
                var cumulative = 0.;
                final origins = [];
                for (size in sizes) {
                    origins.push(cumulative);
                    cumulative += size;
                }
                state.origins = origins;

                if (axis == Horizontal) {
                    state.contentSize = new Size(cumulative, state.contentSize.height);
                }
                else {
                    state.contentSize = new Size(state.contentSize.width, cumulative);
                }
            }

            if (axis == Horizontal) {
                state.contentSize = new Size(state.contentSize.width, longestItemSize.height);
            }
            else {
                state.contentSize = new Size(longestItemSize.width, state.contentSize.height);
            }

            return state.copy();
        });

        final axis = this.axis;
        final contentSize = sizeLayout.contentSize;
        // `withTextStyle(style.textStyle(), ...)` without the closures (a
        // `LayoutId` returned through a function value is boxed on hxcpp)
        final textStyle = style.textStyle();
        if (textStyle != null) window.pushTextStyle(textStyle);
        final layoutId = switch sizingBehavior {
            case ListSizingBehavior.Infer:
                window.requestMeasuredLayout(style, (knownDimensions, availableSpace, _, _) -> {
                    var width:Float;
                    var height:Float;
                    if (axis == Horizontal) {
                        width = knownDimensions.width != null ? knownDimensions.width : switch availableSpace.width {
                            case Definite(x): x;
                            case MinContent | MaxContent: contentSize.width;
                        }
                        // Deliberate deviation DEV-004: the original reads
                        // `known_dimensions.width` here (a list as high as it is wide).
                        height = knownDimensions.height != null ? knownDimensions.height : switch availableSpace.height {
                            case Definite(x): x;
                            case MinContent | MaxContent: contentSize.height;
                        }
                    }
                    else {
                        width = knownDimensions.width != null ? knownDimensions.width : switch availableSpace.width {
                            case Definite(x): x;
                            case MinContent | MaxContent: contentSize.width;
                        }
                        height = knownDimensions.height != null ? knownDimensions.height : switch availableSpace.height {
                            case Definite(x): x;
                            case MinContent | MaxContent: contentSize.height;
                        }
                    }
                    return new Size(width, height);
                });
            case ListSizingBehavior.Auto:
                window.requestLayout(style, null, cx);
        }
        if (textStyle != null) window.popTextStyle();

        items.resize(0);
        this.sizeLayout = sizeLayout;
        return layoutId;
    }

    static function paddingToPixels(style:Style, parentSize:Size, remSize:Float):Edges {
        return new Edges(
            style.paddingTop.toPixelsOf(parentSize.height, remSize),
            style.paddingRight.toPixelsOf(parentSize.width, remSize),
            style.paddingBottom.toPixelsOf(parentSize.height, remSize),
            style.paddingLeft.toPixelsOf(parentSize.width, remSize)
        );
    }

    /**
     * The items that intersect the viewport `[viewportStart, viewportEnd)`
     * along the list axis, plus one item of overdraw past its end, given each
     * item's origin and size (gap included). Returns `[start, end]`.
     *
     * Both edges are binary searches.
     */
    @:allow(gpui.base)
    /**
     * Item ends grow with the index, so the first item ending past `edge` is
     * a partition point over the indices (a static function: a local one
     * boxes `edge` on hxcpp).
     */
    static function endsBefore(origins:Array<Float>, sizes:Array<Float>, edge:Float):Int {
        var low = 0;
        var high = origins.length;
        while (low < high) {
            final mid = low + Std.int((high - low) / 2);
            if (origins[mid] + sizes[mid] <= edge) {
                low = mid + 1;
            }
            else {
                high = mid;
            }
        }
        return low;
    }

    static function visibleRange(origins:Array<Float>, sizes:Array<Float>, viewportStart:Float, viewportEnd:Float):Array<Int> {
        final count = origins.length;
        final first = endsBefore(origins, sizes, viewportStart);
        final pastEnd = endsBefore(origins, sizes, viewportEnd);
        final last = pastEnd == count ? count : Std.int(Math.min(pastEnd + 2, count));
        return [first, Std.int(Math.max(last, first))];
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final layout = sizeLayout;
        layout.lastLayoutBounds = bounds;

        final style = base.interactivity.computeStyle(globalId, null, window, cx);
        final remSize = window.remSize();
        final borderTop = style.borderWidthTop.toPixels(remSize);
        final borderRight = style.borderWidthRight.toPixels(remSize);
        final borderBottom = style.borderWidthBottom.toPixels(remSize);
        final borderLeft = style.borderWidthLeft.toPixels(remSize);
        final paddings = paddingToPixels(style, bounds.size, remSize);

        final itemSizes = layout.sizes;
        final itemOrigins = layout.origins;

        final contentBounds = Bounds.fromCorners(
            bounds.origin.add(new Point(borderLeft + paddings.left, borderTop + paddings.top)),
            bounds.bottomRight().sub(new Point(borderRight + paddings.right, borderBottom + paddings.bottom))
        );

        final axis = this.axis;

        final scrollState = scrollHandle.state;
        scrollState.axis = axis;
        scrollState.itemsCount = itemsCount;
        scrollState.lastContentSize = contentBounds.size;

        var scrollOffset = scrollHandle.offset();
        final scrollToItem = scrollState.deferredScrollToItem;
        if (scrollToItem != null) {
            scrollState.deferredScrollToItem = null;
            scrollOffset = scrollToDeferredItem(scrollOffset, layout, contentBounds, scrollToItem);
        }

        scrollOffset = scrollOffset
            .max(new Point(contentBounds.size.width - layout.contentSize.width, contentBounds.size.height - layout.contentSize.height))
            .min(new Point(0., 0.));
        if (!scrollOffset.equals(scrollHandle.offset())) {
            scrollHandle.setOffset(scrollOffset);
        }

        hitbox = base.interactivity.prepaint(globalId, #if gpui_inspector inspectorId, #end bounds, layout.contentSize, window, cx, (_style, _, hitbox, window, cx) -> {
            if (itemsCount > 0) {
                final minScrollOffset = axis == Horizontal
                    ? contentBounds.size.width - layout.contentSize.width
                    : contentBounds.size.height - layout.contentSize.height;

                final isScrolled = (axis == Horizontal ? scrollOffset.x : scrollOffset.y) != 0.;
                if (isScrolled) {
                    if (axis == Horizontal && scrollOffset.x < minScrollOffset) {
                        scrollOffset = new Point(minScrollOffset, scrollOffset.y);
                        scrollHandle.setOffset(scrollOffset);
                    }
                    else if (axis == Vertical && scrollOffset.y < minScrollOffset) {
                        scrollOffset = new Point(scrollOffset.x, minScrollOffset);
                        scrollHandle.setOffset(scrollOffset);
                    }
                }

                // The viewport in content space: the scroll offset is
                // negative, and the leading padding is admitted at the
                // start so an item under it is still drawn.
                final range = switch axis {
                    case Horizontal: visibleRange(itemOrigins, itemSizes, -(scrollOffset.x + paddings.left), -scrollOffset.x + contentBounds.size.width);
                    case Vertical: visibleRange(itemOrigins, itemSizes, -(scrollOffset.y + paddings.top), -scrollOffset.y + contentBounds.size.height);
                };

                final rendered = renderItems(range[0], range[1], window, cx);

                window.withContentMask(new ContentMask(bounds), window -> {
                    var ix = range[0];
                    for (item in rendered) {
                        if (ix >= range[1]) break;
                        final itemOrigin = switch axis {
                            case Horizontal: contentBounds.origin.add(new Point(itemOrigins[ix] + scrollOffset.x, scrollOffset.y));
                            case Vertical: contentBounds.origin.add(new Point(scrollOffset.x, itemOrigins[ix] + scrollOffset.y));
                        };

                        final availableSpace = switch axis {
                            case Horizontal: new SizeOf<AvailableSpace>(AvailableSpace.Definite(itemSizes[ix]), AvailableSpace.Definite(contentBounds.size.height));
                            case Vertical: new SizeOf<AvailableSpace>(AvailableSpace.Definite(contentBounds.size.width), AvailableSpace.Definite(itemSizes[ix]));
                        };

                        item.layoutAsRoot(availableSpace, window, cx);
                        item.prepaintAt(itemOrigin, window, cx);
                        items.push(item);
                        ix++;
                    }
                    return null;
                });
            }

            return hitbox;
        });
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final hitbox = this.hitbox;
        this.hitbox = null;
        base.interactivity.paint(globalId, #if gpui_inspector inspectorId, #end bounds, hitbox, window, cx, (_, window, cx) -> {
            for (item in items) {
                item.paint(window, cx);
            }
        });
        items.resize(0);
    }

}

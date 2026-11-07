// Ported from gpui-pre 0.3.10: src/elements/uniform_list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A scrollable list of elements with uniform height, optimized for large lists.
 * Rather than use the full taffy layout system, `UniformList` simply measures
 * the first element and then lays out all remaining elements in a line based on that
 * measurement. This is much faster than the full layout system, but only works for
 * elements with uniform height.
 *
 * Create one with `Prelude.uniformList(id, itemCount, (start, end, window, cx) -> [...])`:
 * the callback renders the items of the range `start...end`. When rendered into a
 * container with a fixed (or max) height, it only renders the visible subset of items.
 *
 * Differences with GPUI: Rust ranges are passed as `start, end`. The methods of
 * GPUI's `InteractiveElement` trait are not all mirrored: the common ones are,
 * and `interactivity` gives access to the others.
 */
class UniformList extends Element implements Styled {

    final itemCount:Int;

    var itemToMeasureIndex:Int = 0;

    final renderItems:(Int, Int, Window, App) -> Array<IntoElement>;

    final decorations:Array<UniformListDecoration> = [];

    /**
     * The interactivity of this element (Rust `InteractiveElement::interactivity`).
     */
    public final interactivity:Interactivity = new Interactivity();

    var scrollHandle:Null<UniformListScrollHandle> = null;

    var sizingBehavior:ListSizingBehavior = ListSizingBehavior.Auto;

    var horizontalSizingBehavior:ListHorizontalSizingBehavior = ListHorizontalSizingBehavior.FitList;

    // Frame state (Rust `UniformListFrameState`) and prepaint state

    final frameItems:Array<AnyElement> = [];

    final frameDecorations:Array<AnyElement> = [];

    var hitbox:Null<Hitbox> = null;

    public function new(id:ElementIdArg, itemCount:Int, renderItems:(Int, Int, Window, App) -> Array<IntoElement>) {
        this.itemCount = itemCount;
        this.renderItems = renderItems;
        interactivity.elementId = id;
        interactivity.baseStyle.overflowY = Overflow.Scroll;
    }

    public inline function style():StyleRefinement {
        return interactivity.baseStyle;
    }

    override function elementId():Null<ElementId> {
        return interactivity.elementId;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final maxItems = itemCount;
        final itemSize = measureItem(null, window, cx);
        return interactivity.requestLayout(globalId, #if glaze_inspector inspectorId, #end window, cx, (style, window, cx) -> {
            return switch sizingBehavior {
                case ListSizingBehavior.Infer:
                    window.withTextStyle(style.textStyle(), window -> {
                        return window.requestMeasuredLayout(style, (knownDimensions, availableSpace, _, _) -> {
                            final desiredHeight = itemSize.height * maxItems;
                            final width:Float = knownDimensions.width != null ? knownDimensions.width : switch availableSpace.width {
                                case Definite(x): x;
                                case MinContent | MaxContent: itemSize.width;
                            }
                            final height:Float = switch availableSpace.height {
                                case Definite(height): Math.min(desiredHeight, height);
                                case MinContent | MaxContent: desiredHeight;
                            }
                            return new Size(width, height);
                        });
                    });
                case ListSizingBehavior.Auto:
                    window.withTextStyle(style.textStyle(), window -> {
                        return window.requestLayout(style, null, cx);
                    });
            }
        });
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final style = interactivity.computeStyle(globalId, null, window, cx);
        final remSize = window.remSize();
        final borderTop = style.borderWidthTop.toPixels(remSize);
        final borderRight = style.borderWidthRight.toPixels(remSize);
        final borderBottom = style.borderWidthBottom.toPixels(remSize);
        final borderLeft = style.borderWidthLeft.toPixels(remSize);
        final padding = ListElement.paddingToPixels(style, bounds.size, remSize);

        final paddedBounds = Bounds.fromCorners(
            bounds.origin.add(new Point(borderLeft + padding.left, borderTop + padding.top)),
            bounds.bottomRight().sub(new Point(borderRight + padding.right, borderBottom + padding.bottom))
        );

        final canScrollHorizontally = horizontalSizingBehavior == ListHorizontalSizingBehavior.Unconstrained;

        final longestItemSize = measureItem(null, window, cx);
        final contentWidth = if (canScrollHorizontally) {
            Math.max(paddedBounds.size.width, longestItemSize.width);
        }
        else {
            paddedBounds.size.width;
        }
        final contentSize = new Size(contentWidth, longestItemSize.height * itemCount);

        final sharedScrollOffset = interactivity.scrollOffset;
        final itemHeight:Float = longestItemSize.height;
        var sharedScrollToItem:Null<DeferredScrollToItem> = null;
        if (scrollHandle != null) {
            final handle = scrollHandle.state;
            handle.lastItemSize = new ItemSize(paddedBounds.size, contentSize);
            sharedScrollToItem = handle.deferredScrollToItem;
            handle.deferredScrollToItem = null;
        }

        hitbox = interactivity.prepaint(globalId, #if glaze_inspector inspectorId, #end bounds, contentSize, window, cx, (_style, scrollOffset, hitbox, window, cx) -> {
            final yFlipped = scrollHandle != null ? scrollHandle.state.yFlipped : false;

            if (itemCount > 0) {
                final contentHeight = itemHeight * itemCount;

                final isScrolledVertically = scrollOffset.y != 0;
                final maxScrollOffset = paddedBounds.size.height - contentHeight;

                if (isScrolledVertically && scrollOffset.y < maxScrollOffset) {
                    sharedScrollOffset.value = new Point(sharedScrollOffset.value.x, maxScrollOffset);
                    scrollOffset = new Point(scrollOffset.x, maxScrollOffset);
                }

                final contentWidth = contentSize.width + padding.left + padding.right;
                final isScrolledHorizontally = canScrollHorizontally && scrollOffset.x != 0;
                if (isScrolledHorizontally && contentWidth <= paddedBounds.size.width) {
                    sharedScrollOffset.value = new Point(0, sharedScrollOffset.value.y);
                    scrollOffset = new Point(0, scrollOffset.y);
                }

                if (sharedScrollToItem != null) {
                    // Float: `scrollToBottom` passes the largest index
                    var itemIndex:Float = sharedScrollToItem.itemIndex;
                    var strategy = sharedScrollToItem.strategy;
                    final offset = sharedScrollToItem.offset;
                    final scrollStrict = sharedScrollToItem.scrollStrict;
                    if (yFlipped) {
                        itemIndex = Math.max(itemCount - (itemIndex + 1), 0);
                    }
                    final listHeight = paddedBounds.size.height;
                    final updatedScrollOffset = sharedScrollOffset.value;
                    var updatedY = updatedScrollOffset.y;
                    final itemTop = itemHeight * itemIndex;
                    final itemBottom = itemTop + itemHeight;
                    final scrollTop = -updatedScrollOffset.y;
                    final offsetPixels = itemHeight * offset;

                    // is the selected item above/below currently visible items
                    final isAbove = itemTop < scrollTop + offsetPixels;
                    final isBelow = itemBottom > scrollTop + listHeight;

                    if (scrollStrict || isAbove || isBelow) {
                        if (strategy == ScrollStrategy.Nearest) {
                            if (isAbove) {
                                strategy = ScrollStrategy.Top;
                            }
                            else if (isBelow) {
                                strategy = ScrollStrategy.Bottom;
                            }
                        }

                        final maxScrollOffset = Math.max(contentHeight - listHeight, 0);
                        switch strategy {
                            case ScrollStrategy.Top:
                                updatedY = -clamp(itemTop - offsetPixels, 0, maxScrollOffset);
                            case ScrollStrategy.Center:
                                final itemCenter = itemTop + itemHeight / 2.0;

                                final viewportHeight = listHeight - offsetPixels;
                                final viewportCenter = offsetPixels + viewportHeight / 2.0;
                                final targetScrollTop = itemCenter - viewportCenter;
                                updatedY = -clamp(targetScrollTop, 0, maxScrollOffset);
                            case ScrollStrategy.Bottom:
                                updatedY = -clamp(itemBottom - listHeight, 0, maxScrollOffset);
                            case ScrollStrategy.Nearest:
                                // Nearest, but the item is visible -> no scroll is required
                        }
                        sharedScrollOffset.value = new Point(updatedScrollOffset.x, updatedY);
                    }
                    scrollOffset = sharedScrollOffset.value;
                }

                final scrollTop:Float = -scrollOffset.y;
                final firstVisibleElementIx = toUsize(Math.floor((scrollTop - padding.top) / itemHeight));
                final lastVisibleElementIx = toUsize(Math.ceil((scrollTop + paddedBounds.size.height) / itemHeight));

                final visibleStart = firstVisibleElementIx;
                final visibleEnd = lastVisibleElementIx < itemCount ? lastVisibleElementIx : itemCount;

                final items:Array<IntoElement> = if (yFlipped) {
                    final flippedStart = saturatingSub(itemCount, visibleEnd);
                    final flippedEnd = saturatingSub(itemCount, visibleStart);
                    final items = renderItems(flippedStart, flippedEnd, window, cx);
                    items.reverse();
                    items;
                }
                else {
                    renderItems(visibleStart, visibleEnd, window, cx);
                }

                final contentMask = new ContentMask(bounds);
                window.withContentMask(contentMask, window -> {
                    var ix = visibleStart;
                    for (rendered in items) {
                        if (ix >= visibleEnd)
                            break;
                        final item:AnyElement = rendered;
                        final itemTop = itemHeight * ix - scrollTop;
                        final itemOrigin = paddedBounds.origin.add(new Point(scrollOffset.x, itemTop));

                        final availableWidth = if (canScrollHorizontally) {
                            paddedBounds.size.width + Math.abs(scrollOffset.x);
                        }
                        else {
                            paddedBounds.size.width;
                        }
                        final availableSpace = new SizeOf<AvailableSpace>(
                            AvailableSpace.Definite(availableWidth),
                            AvailableSpace.Definite(itemHeight)
                        );
                        item.layoutAsRoot(availableSpace, window, cx);
                        item.prepaintAt(itemOrigin, window, cx);
                        frameItems.push(item);
                        ix++;
                    }

                    final bounds = new Bounds(paddedBounds.origin.add(scrollOffset), paddedBounds.size);
                    for (decoration in decorations) {
                        final decorationElement:AnyElement = decoration.compute(
                            visibleStart,
                            visibleEnd,
                            bounds,
                            scrollOffset,
                            itemHeight,
                            itemCount,
                            window,
                            cx
                        );
                        final availableSpace = new SizeOf<AvailableSpace>(
                            AvailableSpace.Definite(bounds.size.width),
                            AvailableSpace.Definite(bounds.size.height)
                        );
                        decorationElement.layoutAsRoot(availableSpace, window, cx);
                        decorationElement.prepaintAt(bounds.origin, window, cx);
                        frameDecorations.push(decorationElement);
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
        // Port: a scroll request from another view draws the list again (default view caching)
        if (scrollHandle != null) {
            final scrollState = scrollHandle.state;
            final deferred = scrollState.deferredScrollToItem;
            window.viewDependencies.record(window, scrollState, () -> scrollState.deferredScrollToItem != deferred);
        }
        interactivity.paint(globalId, #if glaze_inspector inspectorId, #end bounds, hitbox, window, cx, (_, window, cx) -> {
            for (item in frameItems) {
                item.paint(window, cx);
            }
            for (decoration in frameDecorations) {
                decoration.paint(window, cx);
            }
        });
        frameItems.resize(0);
        frameDecorations.resize(0);
    }

    /**
     * Selects a specific list item for measurement.
     */
    public function withWidthFromItem(itemIndex:Null<Int>):UniformList {
        itemToMeasureIndex = itemIndex != null ? itemIndex : 0;
        return this;
    }

    /**
     * Sets the sizing behavior, similar to the `List` element.
     */
    public function withSizingBehavior(behavior:ListSizingBehavior):UniformList {
        sizingBehavior = behavior;
        return this;
    }

    /**
     * Sets the horizontal sizing behavior, controlling the way list items laid out horizontally.
     * With `Unconstrained` behavior, every item and the list itself will
     * have the size of the widest item and lay out pushing the `end_slot` to the right end.
     */
    public function withHorizontalSizingBehavior(behavior:ListHorizontalSizingBehavior):UniformList {
        horizontalSizingBehavior = behavior;
        switch behavior {
            case ListHorizontalSizingBehavior.FitList:
                interactivity.baseStyle.unset(StyleRefinement.OVERFLOW_X);
            case ListHorizontalSizingBehavior.Unconstrained:
                interactivity.baseStyle.overflowX = Overflow.Scroll;
        }
        return this;
    }

    /**
     * Adds a decoration element to the list.
     */
    public function withDecoration(decoration:UniformListDecoration):UniformList {
        decorations.push(decoration);
        return this;
    }

    function measureItem(listWidth:Null<Float>, window:Window, cx:App):Size {
        if (itemCount == 0) {
            return new Size();
        }

        final itemIx = itemToMeasureIndex < itemCount - 1 ? itemToMeasureIndex : itemCount - 1;
        final items = renderItems(itemIx, itemIx + 1, window, cx);
        final itemToMeasure:Null<AnyElement> = items.pop();
        if (itemToMeasure == null) {
            return new Size();
        }
        final availableSpace = new SizeOf<AvailableSpace>(
            listWidth != null ? AvailableSpace.Definite(listWidth) : AvailableSpace.MaxContent,
            AvailableSpace.MinContent
        );
        return itemToMeasure.layoutAsRoot(availableSpace, window, cx);
    }

    /**
     * Track and render scroll state of this list with reference to the given scroll handle.
     */
    public function trackScroll(handle:UniformListScrollHandle):UniformList {
        interactivity.trackedScrollHandle = handle.state.baseHandle;
        scrollHandle = handle;
        return this;
    }

    /**
     * Sets whether the list is flipped vertically, such that item 0 appears at the bottom.
     */
    public function yFlipped(yFlipped:Bool):UniformList {
        if (scrollHandle != null) {
            final scrollState = scrollHandle.state;
            final baseHandle = scrollState.baseHandle;
            final offset = baseHandle.offset();
            final lastSize = scrollState.lastItemSize;
            if (lastSize != null && scrollState.yFlipped != yFlipped) {
                final newYOffset = -(offset.y + lastSize.contents.height - lastSize.item.height);
                baseHandle.setOffset(new Point(offset.x, newYOffset));
                scrollState.yFlipped = yFlipped;
            }
            else if (lastSize == null && yFlipped) {
                // Handle case where list is initially flipped.
                baseHandle.setOffset(new Point(offset.x, PIXELS_MIN));
                scrollState.yFlipped = yFlipped;
            }
        }
        return this;
    }

/// InteractiveElement (subset)

    /**
     * Track the focus state of the given focus handle on this element.
     */
    public function trackFocus(focusHandle:FocusHandle):UniformList {
        interactivity.focusable = true;
        interactivity.trackedFocusHandle = focusHandle;
        return this;
    }

    /**
     * Set the keymap context for this element.
     */
    public function keyContext(keyContext:IntoKeyContext):UniformList {
        interactivity.keyContext = keyContext;
        return this;
    }

    /**
     * Apply the given style to this element when the mouse hovers over it.
     */
    public function hover(f:(StyleBuilder) -> StyleBuilder):UniformList {
        interactivity.hoverStyle = StyleBuilder.build(f);
        return this;
    }

    /**
     * Bind the given callback to the mouse down event for the given mouse button.
     */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):UniformList {
        interactivity.onMouseDown(button, listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse up event for the given button, during the bubble phase.
     */
    public function onMouseUp(button:MouseButton, listener:(MouseUpEvent, Window, App) -> Void):UniformList {
        interactivity.onMouseUp(button, listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse move event, during the bubble phase.
     */
    public function onMouseMove(listener:(MouseMoveEvent, Window, App) -> Void):UniformList {
        interactivity.onMouseMove(listener);
        return this;
    }

    /**
     * Bind the given callback to scroll events (wheel and trackpad), during the bubble phase.
     */
    public function onScroll(listener:(ScrollEvent, Window, App) -> Void):UniformList {
        interactivity.onScroll(listener);
        return this;
    }

    /**
     * Bind the given callback to an action dispatch during the bubble phase.
     */
    public function onAction<A:Action>(type:Class<A>, listener:(A, Window, App) -> Void):UniformList {
        interactivity.onAction(type, listener);
        return this;
    }

    /**
     * Bind the given callback to a key down event, during the bubble phase.
     */
    public function onKeyDown(listener:(KeyDownEvent, Window, App) -> Void):UniformList {
        interactivity.onKeyDown(listener);
        return this;
    }

    /**
     * Block the mouse from all interactions with elements behind this element's hitbox.
     */
    public function occlude():UniformList {
        interactivity.occludeMouse();
        return this;
    }

    /**
     * Block mouse interactions with elements behind this element's hitbox, except scrolling.
     */
    public function blockMouseExceptScroll():UniformList {
        interactivity.blockMouseExceptScroll();
        return this;
    }

    /** Rust `Pixels::MIN` (`f32::MIN`). */
    static inline final PIXELS_MIN:Float = -3.40282347e+38;

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    /** Rust `f64 as usize`: saturating, `NaN` gives 0. */
    static function toUsize(value:Float):Int {
        if (Math.isNaN(value) || value <= 0)
            return 0;
        if (value >= 2147483647.0)
            return 2147483647;
        return Std.int(value);
    }

    static inline function saturatingSub(a:Int, b:Int):Int {
        return a > b ? a - b : 0;
    }

}

/**
 * A decoration for a `UniformList`. This can be used for various things,
 * such as rendering indent guides, or other visual effects.
 */
interface UniformListDecoration {

    /**
     * Compute the decoration element, given the visible range of list items
     * (`visibleStart...visibleEnd`), the bounds of the list, and the height of each item.
     */
    function compute(visibleStart:Int, visibleEnd:Int, bounds:Bounds, scrollOffset:Point, itemHeight:Float, itemCount:Int, window:Window, cx:App):IntoElement;

}

/**
 * Rust `DeferredScrollToItem`.
 */
class DeferredScrollToItem {

    /** The item index to scroll to. */
    public final itemIndex:Int;

    /** The scroll strategy to use. */
    public final strategy:ScrollStrategy;

    /** The offset in number of items. */
    public final offset:Int;

    public final scrollStrict:Bool;

    public function new(itemIndex:Int, strategy:ScrollStrategy, offset:Int, scrollStrict:Bool) {
        this.itemIndex = itemIndex;
        this.strategy = strategy;
        this.offset = offset;
        this.scrollStrict = scrollStrict;
    }

}

/**
 * The size of the item and its contents.
 */
class ItemSize {

    /** The size of the item. */
    public final item:Size;

    /**
     * The size of the item's contents, which may be larger than the item itself,
     * if the item was bounded by a parent element.
     */
    public final contents:Size;

    public function new(item:Size, contents:Size) {
        this.item = item;
        this.contents = contents;
    }

}

/**
 * The state of a `UniformListScrollHandle`.
 */
class UniformListScrollState {

    public final baseHandle:ScrollHandle = new ScrollHandle();

    public var deferredScrollToItem:Null<DeferredScrollToItem> = null;

    /** Size of the item, captured during last layout. */
    public var lastItemSize:Null<ItemSize> = null;

    /** Whether the list was vertically flipped during last layout. */
    public var yFlipped:Bool = false;

    public function new() {}

}

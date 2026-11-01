// Ported from gpui-pre 0.3.10: src/elements/list.rs (`ListState`, `StateInner`, `ListItem`, `ListItemSummary`),
// src/window.rs (`Window::transact`), crates/sum_tree (the cursor operations used by the list)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The list state that views must hold on behalf of the list element
 * (`Prelude.list(state, renderItem)`).
 *
 * Clients of this API need to ensure that elements outside of the scrolled
 * area do not change their height for the list to function correctly. If your
 * elements do change height, notify the list via `splice()`, `reset()`,
 * `remeasure()` or `remeasureItems()`.
 *
 * Differences with GPUI: Rust wraps a `StateInner` in `Rc<RefCell<..>>`; here
 * the state is the object itself. Ranges are given as `start, end` arguments
 * (`splice(0, 2, 5)` for `splice(0..2, 5)`). The `SumTree` of items is replaced
 * by `ListItemTree`, an array with cached prefix heights that reproduces the
 * cursor operations the list uses (seek by count or height, with the same bias
 * rules).
 */
class ListState {

    var lastLayoutBounds:Null<Bounds> = null;

    var lastPadding:Null<Edges> = null;

    @:allow(gpui)
    var items:ListItemTree = ListItemTree.EMPTY;

    var scrollAnchor:Null<ListScrollAnchor> = null;

    final alignment:ListAlignment;

    final overdraw:Float;

    /** Rust `reset` (renamed: `reset()` is a method). */
    var resetPending:Bool = false;

    var scrollHandler:Null<(ListScrollEvent, Window, App) -> Void> = null;

    var scrollbarDragStartHeight:Null<Float> = null;

    var measuringBehavior:ListMeasuringBehavior = ListMeasuringBehavior.Visible;

    var itemMeasurementReady:Null<(Int, App) -> Bool> = null;

    var followState:FollowState = FollowState.Normal;

    /**
     * Construct a new list state, for storage on a view.
     *
     * The overdraw parameter controls how much extra space is rendered
     * above and below the visible area. Elements within this area will
     * be measured even though they are not visible. This can help ensure
     * that the list doesn't flicker or pop in when scrolling.
     */
    public function new(itemCount:Int, alignment:ListAlignment, overdraw:Float) {
        this.alignment = alignment;
        this.overdraw = overdraw;
        splice(0, 0, itemCount);
    }

    /**
     * Set the list to measure all items in the list in the first layout phase.
     *
     * This is useful for ensuring that the scrollbar size is correct instead of based on only rendered elements.
     */
    public function measureAll():ListState {
        measuringBehavior = Measure(false);
        return this;
    }

    /**
     * Pre-populate every unmeasured item with a uniform height hint so the scrollbar thumb
     * is correctly sized from the first frame, without measuring all items up front.
     *
     * As items are actually rendered their real heights replace the hint, so the scrollbar
     * converges to the exact size over time.
     */
    public function withUniformItemHeight(height:Float):ListState {
        applyUniformItemHeight(height);
        return this;
    }

    /**
     * Reset this instantiation of the list state.
     *
     * Note that this will cause scroll events to be dropped until the next paint.
     */
    public function reset(elementCount:Int):Void {
        resetPending = true;
        measuringBehavior = resetMeasuringBehavior(measuringBehavior);
        setScrollAnchor(null);
        scrollbarDragStartHeight = null;
        final oldCount = items.count;

        splice(0, oldCount, elementCount);
    }

    /**
     * Reset the list to `elementCount` items, pre-populating every item with a
     * uniform height hint so the scrollbar thumb is correctly sized from the first
     * frame even for off-screen items.
     */
    public function resetWithUniformHeight(elementCount:Int, height:Float):Void {
        reset(elementCount);
        applyUniformItemHeight(height);
    }

    function applyUniformItemHeight(height:Float):Void {
        final sizeHint = new Size(0, height);
        final newItems = [for (item in items.items) {
            final hint = item.sizeHint();
            ListItem.unmeasured(hint != null ? hint : sizeHint, item.focusHandle);
        }];
        items = new ListItemTree(newItems);
    }

    /**
     * Remeasure all items while preserving proportional scroll position.
     *
     * Use this when item heights may have changed (e.g., font size changes)
     * but the number and identity of items remains the same.
     */
    public function remeasure():Void {
        final count = itemCount();
        remeasureItemsWithScrollAnchor(0, count, Proportional);
    }

    /**
     * Mark items in `start...end` as needing remeasurement while preserving
     * the current scroll position. Unlike `splice()`, this does
     * not change the number of items or blow away `logicalScrollTop()`.
     *
     * Use this when an item's content has changed and its rendered
     * height may be different, but the item itself still exists at the same index.
     */
    public function remeasureItems(start:Int, end:Int):Void {
        remeasureItemsWithScrollAnchor(start, end, Absolute);
    }

    function remeasureItemsWithScrollAnchor(start:Int, end:Int, mode:ScrollAnchorMode):Void {
        final anchor = scrollAnchor;
        if (anchor != null && start <= anchor.position.itemIx && anchor.position.itemIx < end) {
            anchor.pending = switch mode {
                case Absolute:
                    PendingScroll.Absolute(anchor.position.offsetInItem);
                case Proportional:
                    final item = items.item(items.seekCount(anchor.position.itemIx));
                    final size = item != null ? item.size() : null;
                    if (size != null) {
                        final fraction = size.height > 0 ? clamp(anchor.position.offsetInItem / size.height, 0, 1) : 0.0;
                        PendingScroll.Proportional(fraction);
                    }
                    else {
                        anchor.pending;
                    }
            }
        }

        // Rebuild the tree, replacing items in the range with
        // Unmeasured copies that keep their focus handles.
        final count = items.count;
        final sliceStart = start < count ? start : count;
        final sliceEnd = end < sliceStart ? sliceStart : (end < count ? end : count);
        final newItems = items.items.slice(0, sliceStart);
        for (i in sliceStart...sliceEnd) {
            final item = items.items[i];
            newItems.push(ListItem.unmeasured(item.sizeHint(), item.focusHandle));
        }
        for (i in sliceEnd...count) {
            newItems.push(items.items[i]);
        }
        items = new ListItemTree(newItems);
        measuringBehavior = resetMeasuringBehavior(measuringBehavior);
    }

    /**
     * The number of items in this list.
     */
    public function itemCount():Int {
        return items.count;
    }

    /**
     * Whether the list is scrolled to the end, or `null` if the list is
     * not scrollable or the total content height is not yet known.
     */
    public function isScrolledToEnd():Null<Bool> {
        final bounds = lastLayoutBounds;
        if (bounds == null)
            return null;
        if (items.hasUnknownHeight) {
            return null;
        }
        final padding = lastPadding != null ? lastPadding : new Edges();
        final contentHeight = items.height + padding.top + padding.bottom;
        final scrollMax = Math.max(contentHeight - bounds.size.height, 0);
        if (scrollMax <= 0) {
            return null;
        }
        final scrollTop = this.scrollTop(logicalScrollTopInner());
        return scrollTop >= scrollMax;
    }

    /**
     * Inform the list state that the items in `oldStart...oldEnd` have been replaced
     * by `count` new items that must be recalculated.
     */
    public function splice(oldStart:Int, oldEnd:Int, count:Int):Void {
        spliceFocusable(oldStart, oldEnd, [for (_ in 0...count) null]);
    }

    /**
     * Register with the list state that the items in `oldStart...oldEnd` have been replaced
     * by new items. As opposed to `splice()`, this method allows optional focus handles
     * to be supplied to properly integrate with items in the list that can be focused. If a focused item
     * is scrolled out of view, the list will continue to render it to allow keyboard interaction.
     */
    public function spliceFocusable(oldStart:Int, oldEnd:Int, focusHandles:Array<Null<FocusHandle>>):Void {
        final count = items.count;
        final sliceStart = items.seekCount(oldStart);
        final sliceEnd = oldEnd < sliceStart ? sliceStart : items.seekCount(oldEnd);

        final newItems = items.items.slice(0, sliceStart);
        var splicedCount = 0;
        for (focusHandle in focusHandles) {
            splicedCount++;
            newItems.push(ListItem.unmeasured(null, focusHandle));
        }
        for (i in sliceEnd...count) {
            newItems.push(items.items[i]);
        }
        items = new ListItemTree(newItems);

        final anchor = scrollAnchor;
        if (anchor != null) {
            if (anchor.provisional && oldStart <= anchor.position.itemIx) {
                anchor.provisional = false;
                anchor.pending = null;
            }
            if (oldStart <= anchor.position.itemIx && anchor.position.itemIx < oldEnd) {
                anchor.position = new ListOffset(oldStart, 0);
                anchor.pending = null;
            }
            else if (oldEnd <= anchor.position.itemIx) {
                final oldLen = oldEnd > oldStart ? oldEnd - oldStart : 0;
                anchor.position = new ListOffset(anchor.position.itemIx - oldLen + splicedCount, anchor.position.offsetInItem);
            }
        }
    }

    /**
     * Set a handler that will be called when the list is scrolled.
     */
    public function setScrollHandler(handler:(ListScrollEvent, Window, App) -> Void):Void {
        scrollHandler = handler;
    }

    /**
     * Get the current scroll offset, in terms of the list's items.
     */
    public function logicalScrollTop():ListOffset {
        return logicalScrollTopInner();
    }

    /**
     * Scroll the list by the given offset.
     */
    public function scrollBy(distance:Float):Void {
        if (distance == 0) {
            return;
        }

        final currentOffset = logicalScrollTop();

        if (distance < 0) {
            followState = followState.stopFollowing();
        }

        var cursor = items.seekCount(currentOffset.itemIx);

        final startPixelOffset = items.startHeight(cursor) + currentOffset.offsetInItem;
        final newPixelOffset = Math.max(startPixelOffset + distance, 0);
        if (newPixelOffset > startPixelOffset) {
            cursor = items.seekHeight(newPixelOffset, true, cursor);
        }
        else {
            cursor = items.seekHeight(newPixelOffset, true, 0);
        }

        final scrollTop = new ListOffset(items.startCount(cursor), newPixelOffset - items.startHeight(cursor));
        setScrollAnchor(scrollTop);
    }

    /**
     * Scroll the list to the very end (past the last item).
     *
     * Unlike `scrollToRevealItem()`, this uses the total item count as the
     * anchor, so the list's layout pass will walk backwards from the end and
     * always show the bottom of the last item, even when that item is still
     * growing (e.g. during streaming).
     */
    public function scrollToEnd():Void {
        final itemCount = items.count;
        setScrollAnchor(new ListOffset(itemCount, 0));
    }

    /**
     * Set the follow mode for the list. In `Tail` mode, the list
     * will auto-scroll to the end and re-engage after the user
     * scrolls back to the bottom. In `Normal` mode, no automatic
     * following occurs.
     */
    public function setFollowMode(mode:FollowMode):Void {
        if (mode == FollowMode.Normal) {
            pauseFollowingTail();
        }

        switch mode {
            case FollowMode.Normal:
                followState = FollowState.Normal;
            case FollowMode.Tail:
                followState = FollowState.Tail(true);
                final itemCount = items.count;
                setScrollAnchor(new ListOffset(itemCount, 0));
        }
    }

    /**
     * Pause tail-following, freezing the list at its current scroll
     * position. Unlike `setFollowMode(Normal)`, this keeps the list in `Tail`
     * mode, so it will resume following automatically once the view returns
     * to the bottom. No-op when the list isn't currently following.
     */
    public function pauseFollowingTail():Void {
        if (followState.isFollowing() && scrollAnchor != null) {
            scrollAnchor.pendingEnd = false;
        }
        followState = followState.stopFollowing();
    }

    /**
     * Sets a predicate queried after item layout to determine whether the measured height is stable.
     * Measurements reported as `false` remain provisional and are retried on later layouts.
     * The consumer must request a new frame when measurement becomes ready.
     */
    public function setItemMeasurementReadiness(ready:(Int, App) -> Bool):Void {
        itemMeasurementReady = ready;
    }

    /**
     * Returns whether the list is currently actively following the
     * tail (snapping to the end on each layout).
     */
    public function isFollowingTail():Bool {
        return followState.isFollowing();
    }

    /**
     * Scroll the list to the given offset.
     */
    public function scrollTo(scrollTop:ListOffset):Void {
        final itemCount = items.count;
        if (scrollTop.itemIx >= itemCount) {
            scrollTop = new ListOffset(itemCount, 0);
        }

        if (scrollTop.itemIx < itemCount) {
            followState = followState.stopFollowing();
        }

        setScrollAnchor(scrollTop);
    }

    /**
     * Scroll the list to the given item, such that the item is fully visible.
     */
    public function scrollToRevealItem(ix:Int):Void {
        var scrollTop = logicalScrollTopInner();
        final height:Float = lastLayoutBounds != null ? lastLayoutBounds.size.height : 0;
        final padding = lastPadding != null ? lastPadding : new Edges();

        if (ix <= scrollTop.itemIx) {
            scrollTop = new ListOffset(ix, 0);
        }
        else {
            var cursor = items.seekCount(ix + 1);
            final bottom = items.startHeight(cursor) + padding.top;
            final goalTop = Math.max(0, bottom - height + padding.bottom);

            cursor = items.seekHeight(goalTop, false, 0);
            final startIx = items.startCount(cursor);
            final startItemTop = items.startHeight(cursor);

            if (startIx >= scrollTop.itemIx) {
                scrollTop = new ListOffset(startIx, goalTop - startItemTop);
            }
        }

        setScrollAnchor(scrollTop);
    }

    /**
     * Get the bounds for the given item in window coordinates, if it's
     * been rendered.
     */
    public function boundsForItem(ix:Int):Null<Bounds> {
        final bounds = lastLayoutBounds != null ? lastLayoutBounds : new Bounds();
        final logicalTop = logicalScrollTopInner();
        if (ix < logicalTop.itemIx) {
            return null;
        }

        var cursor = items.seekCount(logicalTop.itemIx);

        final scrollTop = items.startHeight(cursor) + logicalTop.offsetInItem;

        cursor = items.seekCount(ix);
        final item = items.item(cursor);
        if (item != null && item.measured) {
            final count = items.startCount(cursor);
            if (count == ix) {
                final top = bounds.top() + items.startHeight(cursor) - scrollTop;
                return Bounds.fromCorners(new Point(bounds.left(), top), new Point(bounds.right(), top + item.sizeValue.height));
            }
        }
        return null;
    }

    /**
     * Call this method when the user starts dragging the scrollbar.
     *
     * This will prevent the height reported to the scrollbar from changing during the drag
     * as items in the overdraw get measured, and help offset scroll position changes accordingly.
     */
    public function scrollbarDragStarted():Void {
        scrollbarDragStartHeight = items.height;
    }

    /**
     * Called when the user stops dragging the scrollbar. See `scrollbarDragStarted()`.
     */
    public function scrollbarDragEnded():Void {
        scrollbarDragStartHeight = null;
    }

    /**
     * Returns `true` if the scrollbar is currently being dragged (between
     * `scrollbarDragStarted()` and `scrollbarDragEnded()`).
     */
    public function isScrollbarDragging():Bool {
        return scrollbarDragStartHeight != null;
    }

    /**
     * Set the offset from the scrollbar.
     */
    public function setOffsetFromScrollbar(point:Point):Void {
        setOffsetFromScrollbarInner(point);
    }

    /**
     * Returns the maximum scroll offset according to the items we have measured.
     * This value remains constant while dragging to prevent the scrollbar from moving away unexpectedly.
     */
    public function maxOffsetForScrollbar():Point {
        return new Point(0, maxScrollOffset());
    }

    /**
     * Returns the current scroll offset adjusted for the scrollbar.
     *
     * The returned offset has a negative `y` component representing
     * how far the content has scrolled.
     */
    public function scrollPxOffsetForScrollbar():Point {
        if (scrollAnchor == null && alignment == ListAlignment.Bottom) {
            return new Point(0, -maxScrollOffset());
        }

        final logicalScrollTop = logicalScrollTopInner();

        final summaryHeight = items.startHeight(items.seekCount(logicalScrollTop.itemIx));
        final offset = summaryHeight + logicalScrollTop.offsetInItem;

        return new Point(0, -offset);
    }

    /**
     * Return the bounds of the viewport in pixels.
     */
    public function viewportBounds():Bounds {
        return lastLayoutBounds != null ? lastLayoutBounds : new Bounds();
    }

    /**
     * Returns whether the item is entirely above the viewport, or `null` if
     * the list has not measured enough layout to know.
     *
     * A zero-height viewport still yields a definitive answer: callers may
     * size sibling UI based on this query (potentially squeezing the list
     * itself to zero height), so returning `null` in that case would make
     * the answer oscillate from frame to frame.
     */
    public function itemIsAboveViewport(ix:Int):Null<Bool> {
        final viewportBounds = lastLayoutBounds;
        if (viewportBounds == null)
            return null;

        final scrollTop = logicalScrollTop();
        if (ix < scrollTop.itemIx) {
            // Rows before the logical scroll top have no item bounds, but
            // their position relative to the viewport is known from scroll state.
            return true;
        }

        final itemBounds = boundsForItem(ix);
        if (itemBounds == null)
            return null;
        return itemBounds.bottom() <= viewportBounds.top();
    }

    /**
     * Returns whether the item is entirely below the viewport, or `null` if
     * the list has not measured enough layout to know.
     *
     * See `itemIsAboveViewport()` for why a zero-height viewport
     * still yields a definitive answer.
     */
    public function itemIsBelowViewport(ix:Int):Null<Bool> {
        final viewportBounds = lastLayoutBounds;
        if (viewportBounds == null)
            return null;

        final scrollTop = logicalScrollTop();
        if (ix < scrollTop.itemIx) {
            // Rows before the logical scroll top have no item bounds, but
            // their position relative to the viewport is known from scroll state.
            return false;
        }

        final itemBounds = boundsForItem(ix);
        if (itemBounds == null)
            return null;
        return itemBounds.top() >= viewportBounds.bottom();
    }

/// StateInner

    function maxScrollOffset():Float {
        final bounds = lastLayoutBounds != null ? lastLayoutBounds : new Bounds();
        final height = scrollbarDragStartHeight != null ? (scrollbarDragStartHeight : Float) : items.height;
        return Math.max(height - bounds.size.height, 0);
    }

    static function visibleRangeEnd(items:ListItemTree, height:Float, scrollTop:ListOffset):Int {
        var cursor = items.seekCount(scrollTop.itemIx);
        final startY = items.startHeight(cursor) + scrollTop.offsetInItem;
        cursor = items.seekHeight(startY + height, false, cursor);
        return items.startCount(cursor) + 1;
    }

    @:allow(gpui)
    function scroll(scrollTop:ListOffset, height:Float, delta:Point, currentView:Int, window:Window, cx:App):Void {
        // Drop scroll events after a reset, since we can't calculate
        // the new logical scroll top without the item heights
        if (resetPending || delta.y == 0) {
            return;
        }

        final padding = lastPadding != null ? lastPadding : new Edges();
        final scrollMax = Math.max(items.height + padding.top + padding.bottom - height, 0);
        final newScrollTop = Math.min(Math.max(this.scrollTop(scrollTop) - delta.y, 0), scrollMax);

        if (alignment == ListAlignment.Bottom && newScrollTop == scrollMax) {
            setScrollAnchor(null);
        }
        else {
            final start = items.seekHeight(newScrollTop, true, 0);
            setScrollAnchor(new ListOffset(items.startCount(start), newScrollTop - items.startHeight(start)));
        }

        if (delta.y > 0) {
            followState = followState.stopFollowing();
        }

        if (scrollHandler != null) {
            final visibleEnd = visibleRangeEnd(items, height, scrollTop);
            scrollHandler(
                new ListScrollEvent(scrollTop.itemIx, visibleEnd, items.count, scrollAnchor != null, followState.isFollowing()),
                window,
                cx
            );
        }

        cx.notify(currentView);
    }

    function logicalScrollTopInner():ListOffset {
        if (scrollAnchor != null) {
            return scrollAnchor.position;
        }
        return switch alignment {
            case ListAlignment.Top: new ListOffset(0, 0);
            case ListAlignment.Bottom: new ListOffset(items.count, 0);
        }
    }

    function scrollTop(logicalScrollTop:ListOffset):Float {
        final start = items.seekCount(logicalScrollTop.itemIx);
        return items.startHeight(start) + logicalScrollTop.offsetInItem;
    }

    function isItemReady(index:Int, cx:App):Bool {
        return itemMeasurementReady == null || itemMeasurementReady(index, cx);
    }

    /**
     * Whether the scroll anchor waits for unready item measurements (test support).
     */
    public function isProvisional():Bool {
        return scrollAnchor != null && scrollAnchor.provisional;
    }

    function setScrollAnchor(position:Null<ListOffset>):Void {
        if (position == null) {
            scrollAnchor = null;
            return;
        }
        var pending:Null<PendingScroll> = null;
        if (scrollAnchor != null && scrollAnchor.pending != null && position.itemIx < items.count) {
            pending = switch scrollAnchor.pending {
                case Absolute(_):
                    PendingScroll.Absolute(position.offsetInItem);
                case Proportional(_) if (isProvisional()):
                    PendingScroll.Absolute(position.offsetInItem);
                case Proportional(_):
                    final item = items.item(items.seekCount(position.itemIx));
                    final size = item != null ? item.sizeHint() : null;
                    if (size != null && size.height > 0) {
                        PendingScroll.Proportional(clamp(position.offsetInItem / size.height, 0, 1));
                    }
                    else {
                        null;
                    }
            }
        }
        scrollAnchor = new ListScrollAnchor(position, pending, false, false);
    }

    @:allow(gpui)
    function layoutAllItems(availableWidth:Float, renderItem:(Int, Window, App) -> IntoElement, window:Window, cx:App):Void {
        switch measuringBehavior {
            case ListMeasuringBehavior.Visible:
                return;
            case Measure(hasMeasured):
                if (hasMeasured) {
                    return;
                }
                measuringBehavior = Measure(true);
        }

        final availableItemSpace = new SizeOf<AvailableSpace>(AvailableSpace.Definite(availableWidth), AvailableSpace.MinContent);

        final measuredItems:Array<ListItem> = [];

        for (ix in 0...items.count) {
            final item = items.items[ix];
            var size = item.size();
            if (size == null) {
                final element = renderItem(ix, window, cx);
                size = element.layoutAsRoot(availableItemSpace, window, cx);
            }

            measuredItems.push(item.withMeasurement(size, isItemReady(ix, cx)));
        }

        items = new ListItemTree(measuredItems);
        measuringBehavior = Measure(items.unrenderedCount == 0);
    }

    @:allow(gpui)
    function layoutItems(availableWidth:Null<Float>, availableHeight:Float, padding:Edges, renderItem:(Int, Window, App) -> IntoElement, window:Window, cx:App):LayoutItemsResponse {
        final oldItems = items;
        final measuredItems:Array<ListItem> = [];
        final itemLayouts:Array<ListItemLayout> = [];
        var renderedHeight:Float = padding.top;
        var maxItemWidth:Float = 0;
        var scrollTop = logicalScrollTopInner();

        if (followState.isFollowing() || (scrollAnchor != null && scrollAnchor.pendingEnd)) {
            scrollTop = new ListOffset(items.count, 0);
            setScrollAnchor(scrollTop);
        }

        final preserveAnchor = scrollTop.itemIx < items.count;
        if (!preserveAnchor) {
            followState = followState.startFollowing();
        }
        var provisional = false;
        var renderedFocusedItem = false;

        final availableItemSpace = new SizeOf<AvailableSpace>(
            availableWidth != null ? AvailableSpace.Definite(availableWidth) : AvailableSpace.MaxContent,
            AvailableSpace.MinContent
        );

        // Render items after the scroll top, including those in the trailing overdraw
        var cursor = oldItems.seekCount(scrollTop.itemIx);
        var ix = 0;
        while (cursor < oldItems.count) {
            final item = oldItems.items[cursor];
            cursor++;
            final visibleHeight = renderedHeight - scrollTop.offsetInItem;
            if (visibleHeight >= availableHeight + overdraw) {
                break;
            }

            final itemIndex = scrollTop.itemIx + ix;
            var size:Size;
            var ready:Bool;
            final measuredSize = item.size();
            if (visibleHeight >= availableHeight && measuredSize != null) {
                size = measuredSize;
                ready = isItemReady(itemIndex, cx);
            }
            else {
                final element:AnyElement = renderItem(itemIndex, window, cx);
                final elementSize = element.layoutAsRoot(availableItemSpace, window, cx);
                ready = isItemReady(itemIndex, cx);
                if (ix == 0 && ready && scrollAnchor != null && scrollAnchor.pending != null) {
                    final pending = scrollAnchor.pending;
                    scrollAnchor.pending = null;
                    scrollTop = new ListOffset(scrollTop.itemIx, switch pending {
                        case Absolute(offset): Math.min(offset, elementSize.height);
                        case Proportional(fraction): elementSize.height * fraction;
                    });
                    scrollAnchor.position = scrollTop;
                }

                if (visibleHeight < availableHeight) {
                    itemLayouts.push(new ListItemLayout(itemIndex, element, elementSize));
                    if (item.containsFocused(window, cx)) {
                        renderedFocusedItem = true;
                    }
                }
                size = elementSize;
            }

            renderedHeight += size.height;
            maxItemWidth = Math.max(maxItemWidth, size.width);
            provisional = provisional || !ready;
            measuredItems.push(item.withMeasurement(size, ready));
            if (!ready && visibleHeight >= availableHeight) {
                break;
            }
            ix++;
        }
        renderedHeight += padding.bottom;

        // Prepare to start walking upward from the item at the scroll top.
        cursor = oldItems.seekCount(scrollTop.itemIx);

        // If the rendered items do not fill the visible region, then adjust
        // the scroll top upward.
        if (!provisional && renderedHeight - scrollTop.offsetInItem < availableHeight) {
            final forwardLayoutCount = itemLayouts.length;
            final forwardFocused = renderedFocusedItem;
            while (renderedHeight < availableHeight) {
                cursor = ListItemTree.prev(cursor);
                final item = oldItems.item(cursor);
                if (item != null) {
                    final itemIndex = oldItems.startCount(cursor);
                    final element:AnyElement = renderItem(itemIndex, window, cx);
                    final elementSize = element.layoutAsRoot(availableItemSpace, window, cx);
                    final ready = isItemReady(itemIndex, cx);
                    provisional = provisional || !ready;
                    renderedHeight += elementSize.height;
                    measuredItems.unshift(item.withMeasurement(elementSize, ready));
                    itemLayouts.unshift(new ListItemLayout(itemIndex, element, elementSize));
                    if (item.containsFocused(window, cx)) {
                        renderedFocusedItem = true;
                    }
                    if (preserveAnchor && provisional) {
                        break;
                    }
                }
                else {
                    break;
                }
            }

            if (preserveAnchor && provisional) {
                itemLayouts.splice(0, itemLayouts.length - forwardLayoutCount);
                renderedFocusedItem = forwardFocused;
            }
            else {
                scrollTop = new ListOffset(oldItems.startCount(cursor), renderedHeight - availableHeight);

                switch alignment {
                    case ListAlignment.Top:
                        scrollTop = new ListOffset(scrollTop.itemIx, Math.max(scrollTop.offsetInItem, 0));
                        setScrollAnchor(scrollTop);
                    case ListAlignment.Bottom:
                        scrollTop = new ListOffset(oldItems.startCount(cursor), renderedHeight - availableHeight);
                        setScrollAnchor(null);
                }
            }
        }

        if (scrollAnchor != null) {
            scrollAnchor.provisional = preserveAnchor && provisional;
            scrollAnchor.pendingEnd = !preserveAnchor && provisional;
        }

        // Measure items in the leading overdraw
        if (!provisional) {
            var leadingOverdraw:Float = scrollTop.offsetInItem;
            while (leadingOverdraw < overdraw) {
                cursor = ListItemTree.prev(cursor);
                final item = oldItems.item(cursor);
                if (item != null) {
                    var size:Size;
                    if (item.measured) {
                        size = item.sizeValue;
                    }
                    else {
                        final element:AnyElement = renderItem(oldItems.startCount(cursor), window, cx);
                        size = element.layoutAsRoot(availableItemSpace, window, cx);
                    }

                    leadingOverdraw += size.height;
                    final ready = isItemReady(oldItems.startCount(cursor), cx);
                    measuredItems.unshift(item.withMeasurement(size, ready));
                    if (!ready) {
                        break;
                    }
                }
                else {
                    break;
                }
            }
        }

        final measuredStart = oldItems.startCount(cursor);
        final measuredEnd = measuredStart + measuredItems.length;
        final newItems = oldItems.items.slice(0, measuredStart);
        for (item in measuredItems) {
            newItems.push(item);
        }
        for (i in oldItems.seekCount(measuredEnd)...oldItems.count) {
            newItems.push(oldItems.items[i]);
        }
        items = new ListItemTree(newItems);

        // If follow_tail mode is on but the user scrolled away
        // (is_following is false), check whether the current scroll
        // position has returned to the bottom.
        if (!provisional && followState.hasStoppedFollowing()) {
            final padding = lastPadding != null ? lastPadding : new Edges();
            final totalHeight = items.height + padding.top + padding.bottom;
            final scrollOffset = this.scrollTop(scrollTop);
            if (scrollOffset + availableHeight >= totalHeight - 1.0) {
                followState = followState.startFollowing();
            }
        }

        // If none of the visible items are focused, check if an off-screen item is focused
        // and include it to be rendered after the visible items so keyboard interaction continues
        // to work for it.
        if (!renderedFocusedItem && items.hasFocusHandles) {
            for (itemIndex in 0...items.count) {
                final item = items.items[itemIndex];
                if (item.focusHandle != null && item.containsFocused(window, cx)) {
                    final element:AnyElement = renderItem(itemIndex, window, cx);
                    final size = element.layoutAsRoot(availableItemSpace, window, cx);
                    itemLayouts.push(new ListItemLayout(itemIndex, element, size));
                    break;
                }
            }
        }

        return new LayoutItemsResponse(maxItemWidth, scrollTop, itemLayouts);
    }

    @:allow(gpui)
    function prepaintItems(bounds:Bounds, padding:Edges, autoscroll:Bool, renderItem:(Int, Window, App) -> IntoElement, window:Window, cx:App):PrepaintItemsResult {
        return transact(window, () -> {
            switch measuringBehavior {
                case Measure(false):
                    layoutAllItems(bounds.size.width, renderItem, window, cx);
                case _:
            }

            final layoutResponse = layoutItems(bounds.size.width, bounds.size.height, padding, renderItem, window, cx);

            // Avoid honoring autoscroll requests from elements other than our children.
            window.takeAutoscroll();

            // Only paint the visible items, if there is actually any space for them (taking padding into account)
            if (bounds.size.height > padding.top + padding.bottom) {
                final itemOriginX = bounds.origin.x;
                var itemOriginY = bounds.origin.y + padding.top;
                itemOriginY -= layoutResponse.scrollTop.offsetInItem;
                for (item in layoutResponse.itemLayouts) {
                    window.withContentMask(new ContentMask(bounds), window -> {
                        item.element.prepaintAt(new Point(itemOriginX, itemOriginY), window, cx);
                        return null;
                    });

                    final autoscrollBounds = window.takeAutoscroll();
                    if (autoscrollBounds != null && autoscroll) {
                        if (autoscrollBounds.top() < bounds.top()) {
                            var itemIx = item.index;
                            var offsetInItem = autoscrollBounds.top() - itemOriginY;

                            // The requested top can sit above this item's own
                            // top. Walk into earlier items so the offset stays
                            // non-negative and no blank space appears above the
                            // list.
                            if (offsetInItem < 0) {
                                var cursor = items.seekCount(itemIx);
                                while (offsetInItem < 0) {
                                    cursor = ListItemTree.prev(cursor);
                                    final prevItem = items.item(cursor);
                                    if (prevItem == null) {
                                        offsetInItem = 0;
                                        break;
                                    }
                                    var size = prevItem.size();
                                    if (size == null) {
                                        final element:AnyElement = renderItem(items.startCount(cursor), window, cx);
                                        final itemAvailableSize = new SizeOf<AvailableSpace>(AvailableSpace.Definite(bounds.size.width), AvailableSpace.MinContent);
                                        size = element.layoutAsRoot(itemAvailableSize, window, cx);
                                    }
                                    itemIx = items.startCount(cursor);
                                    offsetInItem += size.height;
                                }
                            }

                            return PrepaintItemsResult.Err(new ListOffset(itemIx, offsetInItem));
                        }
                        else if (autoscrollBounds.bottom() > bounds.bottom()) {
                            var cursor = items.seekCount(item.index);
                            var height = bounds.size.height - padding.top - padding.bottom;

                            // Account for the height of the element down until the autoscroll bottom.
                            height -= autoscrollBounds.bottom() - itemOriginY;

                            // Keep decreasing the scroll top until we fill all the available space.
                            while (height > 0) {
                                cursor = ListItemTree.prev(cursor);
                                final item = items.item(cursor);
                                if (item == null)
                                    break;

                                var size = item.size();
                                if (size == null) {
                                    final element:AnyElement = renderItem(items.startCount(cursor), window, cx);
                                    final itemAvailableSize = new SizeOf<AvailableSpace>(AvailableSpace.Definite(bounds.size.width), AvailableSpace.MinContent);
                                    size = element.layoutAsRoot(itemAvailableSize, window, cx);
                                }
                                height -= size.height;
                            }

                            return PrepaintItemsResult.Err(new ListOffset(items.startCount(cursor), height < 0 ? -height : 0));
                        }
                    }

                    itemOriginY += item.size.height;
                }
            }
            else {
                layoutResponse.itemLayouts.resize(0);
            }

            return PrepaintItemsResult.Ok(layoutResponse);
        });
    }

    // Scrollbar support

    function setOffsetFromScrollbarInner(point:Point):Void {
        final bounds = lastLayoutBounds;
        if (bounds == null) {
            return;
        }
        final height = bounds.size.height;

        final padding = lastPadding != null ? lastPadding : new Edges();
        // Scrollbar drag positions are computed from the content height
        // captured at drag start, so map them back using the same height.
        final contentHeight = scrollbarDragStartHeight != null ? (scrollbarDragStartHeight : Float) : items.height;
        final scrollMax = Math.max(contentHeight + padding.top + padding.bottom - height, 0);
        final newScrollTop = Math.min(Math.max(-point.y, 0), scrollMax);

        // If content grew during the drag, the frozen bottom is below the
        // live bottom. Treat dragging to the frozen end as resuming tail follow.
        final draggedToEnd = scrollMax > 0 && newScrollTop >= Math.max(scrollMax - 1.0, 0);
        if (draggedToEnd && followState.isTail()) {
            followState = FollowState.Tail(true);
            final itemCount = items.count;
            setScrollAnchor(new ListOffset(itemCount, 0));
            return;
        }

        followState = followState.stopFollowing();

        if (alignment == ListAlignment.Bottom && newScrollTop == scrollMax) {
            setScrollAnchor(null);
        }
        else {
            final start = items.seekHeight(newScrollTop, true, 0);
            setScrollAnchor(new ListOffset(items.startCount(start), newScrollTop - items.startHeight(start)));
        }
    }

/// Element support

    @:allow(gpui)
    inline function getLastLayoutBounds():Null<Bounds> {
        return lastLayoutBounds;
    }

    @:allow(gpui)
    inline function setLastLayout(bounds:Bounds, padding:Edges):Void {
        lastLayoutBounds = bounds;
        lastPadding = padding;
    }

    @:allow(gpui)
    inline function getOverdraw():Float {
        return overdraw;
    }

    @:allow(gpui)
    inline function clearReset():Void {
        resetPending = false;
    }

    /**
     * If the width of the list has changed, invalidate all cached item heights.
     */
    @:allow(gpui)
    function invalidateIfWidthChanged(width:Float):Void {
        if (lastLayoutBounds == null || lastLayoutBounds.size.width != width) {
            final newItems = [for (item in items.items) ListItem.unmeasured(null, item.focusHandle)];

            items = new ListItemTree(newItems);
            measuringBehavior = resetMeasuringBehavior(measuringBehavior);
        }
    }

    @:allow(gpui)
    function applyAutoscrollRequest(request:ListOffset):Void {
        setScrollAnchor(request);
    }

    static function resetMeasuringBehavior(behavior:ListMeasuringBehavior):ListMeasuringBehavior {
        return switch behavior {
            case Measure(_): Measure(false);
            case ListMeasuringBehavior.Visible: ListMeasuringBehavior.Visible;
        }
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    /**
     * Rust `Window::transact`: runs `f`, and when it returns `Err`, rolls back
     * the prepaint state it added to the next frame (hitboxes, tooltip
     * requests, deferred draws, dispatch tree nodes, accessed element states).
     * Line layouts are not rolled back (the window text system has no
     * layout index yet).
     */
    static function transact(window:Window, f:() -> PrepaintItemsResult):PrepaintItemsResult {
        final frame = @:privateAccess window.nextFrame;
        final hitboxesIndex = frame.hitboxes.length;
        final tooltipsIndex = frame.tooltipRequests.length;
        final deferredDrawsIndex = frame.deferredDraws.length;
        final dispatchTreeIndex = frame.dispatchTree.len();
        final accessedElementStatesIndex = frame.accessedElementStates.length;
        final result = f();
        switch result {
            case Err(_):
                frame.hitboxes.resize(hitboxesIndex);
                frame.tooltipRequests.resize(tooltipsIndex);
                frame.deferredDraws.resize(deferredDrawsIndex);
                truncateDispatchTree(frame.dispatchTree, dispatchTreeIndex);
                frame.accessedElementStates.resize(accessedElementStatesIndex);
            case Ok(_):
        }
        return result;
    }

    /**
     * Rust `DispatchTree::truncate`.
     */
    @:access(gpui.DispatchTree)
    static function truncateDispatchTree(tree:DispatchTree, index:Int):Void {
        for (i in index...tree.nodeCount) {
            final node = tree.nodes[i];
            if (node.focusId != -1) {
                tree.focusableNodeIds.remove(node.focusId);
            }
            if (node.viewId != -1) {
                tree.viewNodeIds.remove(node.viewId);
            }
        }
        if (index < tree.nodeCount) {
            tree.nodeCount = index;
        }
    }

}

private enum ScrollAnchorMode {
    Absolute;
    Proportional;
}

private enum PendingScroll {
    Absolute(offset:Float);
    Proportional(fraction:Float);
}

/**
 * Rust `ScrollAnchor` of `list.rs` (named to avoid `gpui.ScrollAnchor`).
 */
private class ListScrollAnchor {

    public var position:ListOffset;

    public var pending:Null<PendingScroll>;

    public var provisional:Bool;

    public var pendingEnd:Bool;

    public function new(position:ListOffset, pending:Null<PendingScroll>, provisional:Bool, pendingEnd:Bool) {
        this.position = position;
        this.pending = pending;
        this.provisional = provisional;
        this.pendingEnd = pendingEnd;
    }

}

@:using(gpui.ListState.FollowStateTools)
private enum FollowState {
    Normal;
    Tail(isFollowing:Bool);
}

private class FollowStateTools {

    public static function isFollowing(self:FollowState):Bool {
        return switch self {
            case Tail(true): true;
            case _: false;
        }
    }

    public static function isTail(self:FollowState):Bool {
        return switch self {
            case Tail(_): true;
            case _: false;
        }
    }

    public static function hasStoppedFollowing(self:FollowState):Bool {
        return switch self {
            case Tail(false): true;
            case _: false;
        }
    }

    /** Rust mutates in place: here the new state is returned. */
    public static function startFollowing(self:FollowState):FollowState {
        return switch self {
            case Tail(false): Tail(true);
            case _: self;
        }
    }

    /** Rust mutates in place: here the new state is returned. */
    public static function stopFollowing(self:FollowState):FollowState {
        return switch self {
            case Tail(true): Tail(false);
            case _: self;
        }
    }

}

/**
 * A list item: Rust `ListItem::Unmeasured { size_hint, focus_handle }` or
 * `ListItem::Measured { size, focus_handle }`. `sizeValue` holds the size
 * (measured) or the size hint (unmeasured).
 */
@:allow(gpui)
private class ListItem {

    public final measured:Bool;

    public final sizeValue:Null<Size>;

    public final focusHandle:Null<FocusHandle>;

    function new(measured:Bool, sizeValue:Null<Size>, focusHandle:Null<FocusHandle>) {
        this.measured = measured;
        this.sizeValue = sizeValue;
        this.focusHandle = focusHandle;
    }

    public static inline function unmeasured(sizeHint:Null<Size>, focusHandle:Null<FocusHandle>):ListItem {
        return new ListItem(false, sizeHint, focusHandle);
    }

    public function withMeasurement(size:Size, ready:Bool):ListItem {
        return new ListItem(ready, size, focusHandle);
    }

    public inline function size():Null<Size> {
        return measured ? sizeValue : null;
    }

    public inline function sizeHint():Null<Size> {
        return sizeValue;
    }

    public function containsFocused(window:Window, cx:App):Bool {
        return focusHandle != null && focusHandle.containsFocused(window, cx);
    }

}

/**
 * Replaces GPUI's `SumTree<ListItem>`: the items, their summary
 * (`ListItemSummary`) and prefix heights.
 *
 * Cursor positions are plain indices: `-1` is before the first item (after
 * `prev()` from the first item; its start is 0), `count` is the end. A
 * cursor's `start()` is (`startCount(ix)`, `startHeight(ix)`).
 */
@:allow(gpui)
private class ListItemTree {

    public static final EMPTY:ListItemTree = new ListItemTree([]);

    public final items:Array<ListItem>;

    /** Prefix heights: `heights[i]` is the height of the items before `i`. */
    final heights:Array<Float>;

    public final count:Int;

    public final height:Float;

    public final renderedCount:Int;

    public final unrenderedCount:Int;

    public final hasFocusHandles:Bool;

    public final hasUnknownHeight:Bool;

    public function new(items:Array<ListItem>) {
        this.items = items;
        final heights:Array<Float> = [0.0];
        var height = 0.0;
        var renderedCount = 0;
        var unrenderedCount = 0;
        var hasFocusHandles = false;
        var hasUnknownHeight = false;
        for (item in items) {
            if (item.measured) {
                renderedCount++;
            }
            else {
                unrenderedCount++;
                if (item.sizeValue == null) {
                    hasUnknownHeight = true;
                }
            }
            if (item.sizeValue != null) {
                height += item.sizeValue.height;
            }
            if (item.focusHandle != null) {
                hasFocusHandles = true;
            }
            heights.push(height);
        }
        this.heights = heights;
        this.count = items.length;
        this.height = height;
        this.renderedCount = renderedCount;
        this.unrenderedCount = unrenderedCount;
        this.hasFocusHandles = hasFocusHandles;
        this.hasUnknownHeight = hasUnknownHeight;
    }

    /** The item at a cursor position, or `null` before the start or at the end. */
    public inline function item(ix:Int):Null<ListItem> {
        return ix >= 0 && ix < count ? items[ix] : null;
    }

    public inline function startCount(ix:Int):Int {
        return ix < 0 ? 0 : ix;
    }

    public inline function startHeight(ix:Int):Float {
        return heights[ix < 0 ? 0 : ix];
    }

    /** `cursor.seek(&Count(ix), Bias::Right)` (also `seek_forward` when moving forward). */
    public inline function seekCount(ix:Int):Int {
        return ix < 0 ? 0 : (ix < count ? ix : count);
    }

    /**
     * `cursor.seek(&Height(target), bias)` from the cursor position `from`
     * (`seek_forward`; 0 for `seek`): skips items ending before `target`, and
     * items ending exactly at `target` with `Bias::Right` (`right` true).
     */
    public function seekHeight(target:Float, right:Bool, from:Int):Int {
        var ix = from < 0 ? 0 : from;
        while (ix < count) {
            final end = heights[ix + 1];
            if (target > end || (target == end && right)) {
                ix++;
            }
            else {
                break;
            }
        }
        return ix;
    }

    /** `cursor.prev()` */
    public static inline function prev(ix:Int):Int {
        return ix >= 0 ? ix - 1 : -1;
    }

}

@:noCompletion
class ListItemLayout {

    public final index:Int;

    public final element:AnyElement;

    public final size:Size;

    public function new(index:Int, element:AnyElement, size:Size) {
        this.index = index;
        this.element = element;
        this.size = size;
    }

}

@:noCompletion
class LayoutItemsResponse {

    public final maxItemWidth:Float;

    public final scrollTop:ListOffset;

    public final itemLayouts:Array<ListItemLayout>;

    public function new(maxItemWidth:Float, scrollTop:ListOffset, itemLayouts:Array<ListItemLayout>) {
        this.maxItemWidth = maxItemWidth;
        this.scrollTop = scrollTop;
        this.itemLayouts = itemLayouts;
    }

}

/**
 * Rust `Result<LayoutItemsResponse, ListOffset>` of `prepaint_items`.
 */
@:noCompletion
enum PrepaintItemsResult {
    Ok(layout:LayoutItemsResponse);
    Err(autoscrollRequest:ListOffset);
}

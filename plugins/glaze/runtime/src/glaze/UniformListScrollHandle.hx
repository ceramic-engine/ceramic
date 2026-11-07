// Ported from gpui-pre 0.3.10: src/elements/uniform_list.rs (`UniformListScrollHandle`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.UniformList.DeferredScrollToItem;
import glaze.UniformList.UniformListScrollState;

/**
 * A handle for controlling the scroll position of a uniform list.
 * This should be stored in your view and passed to the uniform list on each
 * frame (`uniformList(...).trackScroll(handle)`).
 */
class UniformListScrollHandle {

    /** Rust `.0`: the shared state. */
    public final state:UniformListScrollState = new UniformListScrollState();

    /**
     * Create a new scroll handle to bind to a uniform list.
     */
    public function new() {}

    /**
     * Scroll the list so that the given item index is visible.
     *
     * This uses non-strict scrolling: if the item is already fully visible, no scrolling occurs.
     * If the item is out of view, it scrolls the minimum amount to bring it into view according
     * to the strategy.
     */
    public function scrollToItem(ix:Int, strategy:ScrollStrategy):Void {
        state.deferredScrollToItem = new DeferredScrollToItem(ix, strategy, 0, false);
    }

    /**
     * Scroll the list so that the given item index is at scroll strategy position.
     *
     * This uses strict scrolling: the item will always be scrolled to match the strategy position,
     * even if it's already visible. Use this when you need precise positioning.
     */
    public function scrollToItemStrict(ix:Int, strategy:ScrollStrategy):Void {
        state.deferredScrollToItem = new DeferredScrollToItem(ix, strategy, 0, true);
    }

    /**
     * Scroll the list to the given item index with an offset in number of items.
     *
     * This uses non-strict scrolling: if the item is already visible within the offset region,
     * no scrolling occurs.
     *
     * The offset parameter shrinks the effective viewport by the specified number of items
     * from the corresponding edge, then applies the scroll strategy within that reduced viewport:
     * - `Top`: shrinks from top, positions item at the new top;
     * - `Center`: shrinks from top, centers item in the reduced viewport;
     * - `Bottom`: shrinks from bottom, positions item at the new bottom.
     */
    public function scrollToItemWithOffset(ix:Int, strategy:ScrollStrategy, offset:Int):Void {
        state.deferredScrollToItem = new DeferredScrollToItem(ix, strategy, offset, false);
    }

    /**
     * Scroll the list so that the given item index is at the exact scroll strategy position with an offset.
     *
     * This uses strict scrolling: the item will always be scrolled to match the strategy position,
     * even if it's already visible. See `scrollToItemWithOffset()` for the offset.
     */
    public function scrollToItemStrictWithOffset(ix:Int, strategy:ScrollStrategy, offset:Int):Void {
        state.deferredScrollToItem = new DeferredScrollToItem(ix, strategy, offset, true);
    }

    /**
     * Check if the list is flipped vertically.
     */
    public function yFlipped():Bool {
        return state.yFlipped;
    }

    /**
     * Get the index of the topmost visible child (test support).
     */
    public function logicalScrollTopIndex():Int {
        final deferred = state.deferredScrollToItem;
        return deferred != null ? deferred.itemIndex : state.baseHandle.logicalScrollTop().index;
    }

    /**
     * Checks if the list can be scrolled vertically.
     */
    public function isScrollable():Bool {
        final size = state.lastItemSize;
        if (size != null) {
            return size.contents.height > size.item.height;
        }
        return false;
    }

    /**
     * Whether the list is scrolled to the end, or `null` if the list is
     * not scrollable.
     */
    public function isScrolledToEnd():Null<Bool> {
        final maxOffset = state.baseHandle.maxOffset();
        if (maxOffset.y <= 0) {
            return null;
        }
        final offset = state.baseHandle.offset();
        return -offset.y >= maxOffset.y;
    }

    /**
     * Scroll to the bottom of the list.
     */
    public function scrollToBottom():Void {
        // Rust `usize::MAX`
        scrollToItem(2147483647, ScrollStrategy.Bottom);
    }

}

// Ported from gpui-pre 0.3.10: src/elements/div.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Ref;

private enum abstract ScrollStrategy(Int) {
    var FirstVisible = 0;
    var Top = 1;
}

/**
 * The state of a `ScrollHandle`, shared with the element tracking it.
 */
@:allow(gpui)
class ScrollHandleState {

    final offset:Ref<Point> = new Ref(new Point(0, 0));

    final ongoingScroll:OngoingScroll = new OngoingScroll();

    var bounds:Bounds = new Bounds();

    var maxOffset:Point = new Point(0, 0);

    final childBounds:Array<Bounds> = [];

    var scrollToBottom:Bool = false;

    var overflowX:Overflow = Visible;

    var overflowY:Overflow = Visible;

    /** Index of the item to scroll to, -1 for none */
    var activeItemIndex:Int = -1;

    var activeItemStrategy:ScrollStrategy = FirstVisible;

    function new() {}

}

/**
 * A handle to the scrollable aspects of an element.
 * Used for accessing scroll state, like the current scroll offset,
 * and for mutating the scroll state, like scrolling to a specific child.
 */
class ScrollHandle {

    @:allow(gpui)
    final state:ScrollHandleState = new ScrollHandleState();

    /**
     * Construct a new scroll handle.
     */
    public function new() {}

    /**
     * Get the current scroll offset.
     */
    public function offset():Point {
        return state.offset.value;
    }

    /**
     * Get the maximum scroll offset.
     */
    public function maxOffset():Point {
        return state.maxOffset;
    }

    /**
     * Get the top child that's scrolled into view.
     */
    public function topItem():Int {
        final top = state.bounds.top() - state.offset.value.y;
        return searchItem(top);
    }

    /**
     * Get the bottom child that's scrolled into view.
     */
    public function bottomItem():Int {
        final bottom = state.bounds.bottom() - state.offset.value.y;
        return searchItem(bottom);
    }

    function searchItem(y:Float):Int {
        // Rust: binary_search_by on the child bounds
        final children = state.childBounds;
        var lo = 0;
        var hi = children.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            final bounds = children[mid];
            if (y < bounds.top()) {
                hi = mid;
            }
            else if (y > bounds.bottom()) {
                lo = mid + 1;
            }
            else {
                return mid;
            }
        }
        final last = children.length > 0 ? children.length - 1 : 0;
        return lo < last ? lo : last;
    }

    /**
     * Return the bounds into which this child is painted.
     */
    public function bounds():Bounds {
        return state.bounds;
    }

    /**
     * Get the bounds for a specific child.
     */
    public function boundsForItem(ix:Int):Null<Bounds> {
        return ix >= 0 && ix < state.childBounds.length ? state.childBounds[ix] : null;
    }

    /**
     * Update `activeItem` so that the child at the given index is scrolled into view on the
     * next prepaint.
     */
    public function scrollToItem(ix:Int):Void {
        state.activeItemIndex = ix;
        state.activeItemStrategy = FirstVisible;
    }

    /**
     * Scrolls to the item at the given index with the top of the item at the top of the viewport.
     */
    public function scrollToTopOfItem(ix:Int):Void {
        state.activeItemIndex = ix;
        state.activeItemStrategy = Top;
    }

    @:allow(gpui)
    function scrollToActiveItem():Void {
        if (state.activeItemIndex == -1)
            return;

        final index = state.activeItemIndex;
        if (index >= state.childBounds.length) {
            // Keep it for when the child exists
            return;
        }
        final bounds = state.childBounds[index];
        var offsetX = state.offset.value.x;
        var offsetY = state.offset.value.y;
        final viewport = state.bounds;

        switch state.activeItemStrategy {
            case FirstVisible:
                if (state.overflowY == Scroll) {
                    final childHeight = bounds.size.height;
                    final viewportHeight = viewport.size.height;
                    if (childHeight > viewportHeight) {
                        offsetY = viewport.top() - bounds.top();
                    }
                    else if (bounds.top() + offsetY < viewport.top()) {
                        offsetY = viewport.top() - bounds.top();
                    }
                    else if (bounds.bottom() + offsetY > viewport.bottom()) {
                        offsetY = viewport.bottom() - bounds.bottom();
                    }
                }
            case Top:
                offsetY = viewport.top() - bounds.top();
        }

        if (state.overflowX == Scroll) {
            final childWidth = bounds.size.width;
            final viewportWidth = viewport.size.width;
            if (childWidth > viewportWidth) {
                offsetX = viewport.left() - bounds.left();
            }
            else if (bounds.left() + offsetX < viewport.left()) {
                offsetX = viewport.left() - bounds.left();
            }
            else if (bounds.right() + offsetX > viewport.right()) {
                offsetX = viewport.right() - bounds.right();
            }
        }

        state.offset.value = new Point(offsetX, offsetY);
        state.activeItemIndex = -1;
    }

    /**
     * Scrolls to the bottom.
     */
    public function scrollToBottom():Void {
        state.scrollToBottom = true;
    }

    /**
     * Set the offset explicitly. The offset is the distance from the top left of the
     * parent container to the top left of the first child.
     * As you scroll further down the offset becomes more negative.
     */
    public function setOffset(position:Point):Void {
        state.offset.value = position;
    }

    /**
     * Get the logical scroll top, based on a child index and a pixel offset.
     */
    public function logicalScrollTop():{index:Int, offset:Float} {
        final ix = topItem();
        if (ix < state.childBounds.length) {
            final childBounds = state.childBounds[ix];
            return {index: ix, offset: childBounds.top() + state.offset.value.y - state.bounds.top()};
        }
        return {index: ix, offset: 0};
    }

    /**
     * Get the logical scroll bottom, based on a child index and a pixel offset.
     */
    public function logicalScrollBottom():{index:Int, offset:Float} {
        final ix = bottomItem();
        if (ix < state.childBounds.length) {
            final childBounds = state.childBounds[ix];
            return {index: ix, offset: childBounds.bottom() + state.offset.value.y - state.bounds.bottom()};
        }
        return {index: ix, offset: 0};
    }

    /**
     * Get the count of children for scrollable item.
     */
    public function childrenCount():Int {
        return state.childBounds.length;
    }

}

package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * A scrollable collection view that efficiently displays large data sets using view recycling.
 *
 * CollectionView is designed for performance when displaying many items by only creating
 * views for visible items and recycling them as the user scrolls. It supports both
 * vertical and horizontal scrolling layouts.
 *
 * Key features:
 * - Efficient view recycling for large data sets
 * - Customizable layouts via CollectionViewLayout
 * - Automatic item visibility management
 * - Smooth scrolling to specific items
 * - Multiple item behavior modes (RECYCLE, FREEZE, LAZY)
 *
 * @example
 * ```haxe
 * var collection = new CollectionView();
 * collection.size(400, 600);
 *
 * // Set up a flow layout
 * var layout = new CollectionViewFlowLayout();
 * layout.itemSize = { width: 100, height: 100 };
 * layout.spacing = 10;
 * collection.collectionViewLayout = layout;
 *
 * // Implement data source
 * collection.dataSource = new MyCustomCollectionViewDataSource();
 * ```
 *
 * @see CollectionViewDataSource
 * @see CollectionViewLayout
 * @see CollectionViewFlowLayout
 */
class CollectionView extends ScrollView {

    /**
     * Reference to the current layout if it's a CollectionViewFlowLayout.
     * This provides optimized access to flow layout specific properties.
     * Will be null if using a different layout type.
     */
    public var collectionViewFlowLayout(default,null):CollectionViewFlowLayout;

    /**
     * The layout object responsible for positioning items in the collection.
     * Changing the layout will trigger a full relayout of all items.
     *
     * @see CollectionViewFlowLayout for the default grid-based layout
     */
    public var collectionViewLayout(default,set):CollectionViewLayout;
    function set_collectionViewLayout(collectionViewLayout:CollectionViewLayout):CollectionViewLayout {
        if (this.collectionViewLayout != collectionViewLayout) {
            this.collectionViewLayout = collectionViewLayout;
            if (collectionViewLayout != null && Type.getClass(collectionViewLayout) == CollectionViewFlowLayout) {
                this.collectionViewFlowLayout = cast collectionViewLayout;
            }
            else {
                this.collectionViewFlowLayout = null;
            }
        }
        return collectionViewLayout;
    }

    /**
     * The data source that provides items for the collection view.
     * Setting a new data source will reload all data and recreate visible items.
     *
     * The data source must implement:
     * - collectionViewSize(): Number of items
     * - collectionViewItemAtIndex(): Create/configure item views
     * - collectionViewItemFrameAtIndex(): Set item dimensions
     * - collectionViewReleaseItemAtIndex(): Handle item recycling
     */
    public var dataSource(default,set):CollectionViewDataSource = null;

    /**
     * Whether to automatically destroy item views when they're removed.
     * Set to false if you want to manage item lifecycle manually.
     * Default is true for automatic memory management.
     */
    public var autoDestroyItems:Bool = true;

    /**
     * Maximum number of recycled views to keep in memory.
     * Higher values can improve scrolling performance but use more memory.
     * Lower values save memory but may cause more view creation during scrolling.
     * Default is 1.
     */
    public var maxReusableViewsCount:Int = 1;

    /**
     * Controls how item views are assigned depth values for rendering order.
     * - INCREMENT: Each item has higher depth (later items on top)
     * - DECREMENT: Each item has lower depth (earlier items on top)
     * - SAME: All items at same depth (order by index)
     * - CUSTOM: Manual depth assignment
     * Default is SAME.
     */
    public var childrenDepth(default,set):ChildrenDepth = SAME;
    function set_childrenDepth(childrenDepth:ChildrenDepth):ChildrenDepth {
        if (this.childrenDepth == childrenDepth) return childrenDepth;
        this.childrenDepth = childrenDepth;
        layoutDirty = true;
        return childrenDepth;
    }

    /**
     * Read-only array of frames representing the position and size of each item.
     * Frames are computed by the layout and used for visibility culling.
     */
    public var frames:ReadOnlyArray<CollectionViewItemFrame> = [];

    /**
     * Determines how item views are managed:
     * - RECYCLE: Reuse views for performance (default)
     * - FREEZE: Keep all created views active
     * - LAZY: Create views only when visible
     *
     * RECYCLE is recommended for large data sets.
     */
    public var itemsBehavior(default, set):CollectionViewItemsBehavior = RECYCLE;
    function set_itemsBehavior(itemsBehavior:CollectionViewItemsBehavior):CollectionViewItemsBehavior {
        if (this.itemsBehavior != itemsBehavior) {
            this.itemsBehavior = itemsBehavior;

            // Mark layout dirty so that invisible items are recycled
            if (itemsBehavior == RECYCLE) {
                layoutDirty = true;
            }
        }
        return itemsBehavior;
    }

    /**
     * Pool of recycled views available for reuse.
     * Managed automatically based on itemsBehavior and maxReusableViewsCount.
     */
    var reusableViews:Array<View> = [];

    /**
     * Previous layout width, used to detect size changes.
     */
    var prevLayoutWidth:Float = -1;

    /**
     * Previous layout height, used to detect size changes.
     */
    var prevLayoutHeight:Float = -1;

    /**
     * Creates a new CollectionView with a default flow layout.
     */
    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        collectionViewLayout = new CollectionViewFlowLayout();

        scroller.scrollTransform.onChange(this, computeVisibleItems);

    }

    override function destroy() {

        super.destroy();

        dataSource = null;
        for (i in 0...reusableViews.length) {
            var view = reusableViews.unsafeGet(i);
            view.destroy();
        }
        reusableViews = null;

    }

    function set_dataSource(dataSource:CollectionViewDataSource):CollectionViewDataSource {
        if (this.dataSource == dataSource) return dataSource;

        this.dataSource = dataSource;

        reloadData();

        return dataSource;
    }

    /**
     * Reloads all data from the data source.
     * This will:
     * - Destroy all existing item views
     * - Query the data source for the new item count
     * - Create frames for all items
     * - Trigger a layout update
     *
     * Call this when your underlying data changes.
     */
    public function reloadData():Void {

        if (this.frames.length > 0) {
            for (i in 0...this.frames.length) {
                var frame = this.frames.unsafeGet(i);

                if (frame.view != null) {
                    frame.view.destroy();
                }
            }
        }

        if (dataSource != null) {
            var numItems = dataSource.collectionViewSize(this);
            var frames:Array<CollectionViewItemFrame> = [];
            for (i in 0...numItems) {
                frames.push(new CollectionViewItemFrame(0, 0, 0, 0));
            }
            this.frames = cast frames;
        }
        else {
            this.frames = [];
        }

        layoutDirty = true;

    }

    override function layout() {

        var didResize = false;
        if (prevLayoutWidth != width || prevLayoutHeight != height) {
            prevLayoutWidth = width;
            prevLayoutHeight = height;
            didResize = true;
        }

        scroller.pos(0, 0);
        scroller.size(width, height);

        if (frames.length > 0) {
            // Get item sizes
            for (i in 0...frames.length) {
                dataSource.collectionViewItemFrameAtIndex(this, i, frames[i]);
            }
            // Layout items
            collectionViewLayout.collectionViewLayout(this, frames);
        }

        if (direction == VERTICAL) {
            contentView.height = Math.max(height, contentSize);

            if (didResize && contentView.height - scroller.scrollY < height) {
                scroller.scrollY = contentView.height - height;
            }
        } else {
            contentView.width = Math.max(width, contentSize);

            if (didResize && contentView.width - scroller.scrollX < width) {
                scroller.scrollX = contentView.width - width;
            }
        }

        computeVisibleItems();

    }

    /**
     * Finds the index of the item closest to the given coordinates.
     *
     * @param x X coordinate to test
     * @param y Y coordinate to test
     * @param includeScroll Whether to account for current scroll position
     * @return Index of the closest item, or -1 if no items
     */
    public function findClosestItem(x:Float, y:Float, includeScroll:Bool = true):Int {

        var bestDiffX = 99999999.0;
        var bestDiffY = 99999999.0;
        var diffX = 0.0;
        var diffY = 0.0;
        var itemIndex = -1;
        var scrollX = includeScroll ? scroller.scrollX : 0.0;
        var scrollY = includeScroll ? scroller.scrollY : 0.0;

        if (frames.length > 0) {
            for (i in 0...frames.length) {
                var frame = frames.unsafeGet(i);
                var minFrameX = frame.x - scrollX;
                var maxFrameX = frame.x + frame.width - scrollX;
                var minFrameY = frame.y - scrollY;
                var maxFrameY = frame.y + frame.height - scrollY;

                if (x < minFrameX) {
                    diffX = maxFrameX - x;
                }
                else if (x >= maxFrameX) {
                    diffX = x - minFrameX;
                }
                else {
                    diffX = 0;
                }

                if (y < minFrameY) {
                    diffY = maxFrameY - y;
                }
                else if (y >= maxFrameY) {
                    diffY = y - minFrameY;
                }
                else {
                    diffY = 0;
                }

                if (direction == VERTICAL) {
                    if (diffX < bestDiffX || (diffX == bestDiffX && diffY < bestDiffY)) {
                        bestDiffX = diffX;
                        bestDiffY = diffY;
                        itemIndex = i;
                    }
                } else { // HORIZONTAL
                    if (diffY < bestDiffY || (diffY == bestDiffY && diffX < bestDiffX)) {
                        bestDiffX = diffX;
                        bestDiffY = diffY;
                        itemIndex = i;
                    }
                }
            }
        }

        return itemIndex;

    }

    /**
     * Updates which items are visible and manages view recycling.
     * This is called automatically when scrolling or layout changes.
     *
     * The method will:
     * - Determine which frames are in the visible area
     * - Recycle views that moved off-screen
     * - Create or reuse views for newly visible items
     * - Position and size all visible views
     */
    public function computeVisibleItems():Void {

        if (dataSource == null) return;

        inline function handleVisible(itemIndex:Int, frame:CollectionViewItemFrame) {
            if (frame.visible) {
                // Add/Recycle views that become visible
                if (itemsBehavior != FREEZE && frame.view == null) {
                    if (reusableViews.length > 0) {
                        var reusableView = reusableViews.pop();
                        frame.view = dataSource.collectionViewItemAtIndex(this, itemIndex, reusableView);
                        if (frame.view != reusableView) {
                            if (autoDestroyItems) reusableView.destroy();
                        }
                    }
                    else {
                        frame.view = dataSource.collectionViewItemAtIndex(this, itemIndex, null);
                    }
                }

                var view = frame.view;
                if (view != null && !view.destroyed) {
                    if (childrenDepth == INCREMENT) {
                        view.depth = itemIndex;
                    }
                    else if (childrenDepth == DECREMENT) {
                        view.depth = frames.length - itemIndex;
                    }
                    else if (childrenDepth == SAME) {
                        view.depth = 1;
                    }
                    var prevWidth = view.width;
                    var prevHeight = view.height;
                    view.viewSize(frame.width, frame.height);
                    view.size(frame.width, frame.height);
                    if (view.layoutDirty) contentView.layoutDirty = true;
                    var newX = frame.x + frame.width * view.anchorX;
                    var newY = frame.y + frame.height * view.anchorY;
                    view.pos(newX, newY);
                    view.active = true;
                    if (view.parent != contentView) {
                        contentView.add(view);
                    }
                    if (prevWidth != frame.width || prevHeight != frame.height) {
                        // Size change may produce anchor change on layout,
                        // this we reassign again x and y in that case
                        view.onceLayout(this, function() {
                            var newX = frame.x + frame.width * view.anchorX;
                            var newY = frame.y + frame.height * view.anchorY;
                            view.pos(newX, newY);
                        });
                    }
                }
            }
        }

        inline function handleInvisible(itemIndex:Int, frame:CollectionViewItemFrame) {
            if (!frame.visible) {
                // Remove view which is not visible anymore
                if (frame.view != null) {
                    if (!dataSource.collectionViewReleaseItemAtIndex(this, itemIndex, frame.view)) {
                        if (!frame.view.destroyed) {
                            frame.view.active = false;
                            if (autoDestroyItems) frame.view.destroy();
                        }
                    }
                    else {
                        frame.view.active = false;
                        reusableViews.push(frame.view);
                    }
                    frame.view = null;
                }
            }
        }

        final shouldHandleInvisible = (itemsBehavior != FREEZE && itemsBehavior != LAZY);

        if (direction == VERTICAL) {

            if (collectionViewFlowLayout != null) {
                // Optimized code
                if (collectionViewFlowLayout.allItemsVisible) {
                    for (i in 0...frames.length) {
                        var frame = frames.unsafeGet(i);
                        frame.visible = true;
                        if (frame.width <= 0 || frame.height <= 0) {
                            frame.visible = false;
                        }
                    }
                }
                else {
                    final scrollTY = this.scroller.scrollTransform.ty;
                    final visibleOutset = collectionViewFlowLayout.visibleOutset;
                    final collectionViewHeight = this.height;
                    for (i in 0...frames.length) {
                        var frame = frames.unsafeGet(i);
                        var minY = -scrollTY - visibleOutset;
                        var maxY = minY + collectionViewHeight + visibleOutset * 2;
                        frame.visible = (frame.y < maxY && frame.y + frame.height >= minY);
                        if (frame.visible && frame.width <= 0 || frame.height <= 0) {
                            frame.visible = false;
                        }
                        if (shouldHandleInvisible) handleInvisible(i, frame);
                    }
                }
            }
            else {
                for (i in 0...frames.length) {
                    var frame = frames.unsafeGet(i);
                    frame.visible = collectionViewLayout.isFrameVisible(this, frame);
                    if (frame.visible && frame.width <= 0 || frame.height <= 0) {
                        frame.visible = false;
                    }

                    // We first handle all invisible frames, so that we can harvest reusable views
                    // and provide them on new frames right after
                    if (shouldHandleInvisible) handleInvisible(i, frame);
                }
            }

            for (i in 0...frames.length) {
                var frame = frames.unsafeGet(i);
                handleVisible(i, frame);
            }

        } else {

            if (collectionViewFlowLayout != null) {
                // Optimized code
                if (collectionViewFlowLayout.allItemsVisible) {
                    for (i in 0...frames.length) {
                        var frame = frames.unsafeGet(i);
                        frame.visible = true;
                        if (frame.width <= 0 || frame.height <= 0) {
                            frame.visible = false;
                        }
                    }
                }
                else {
                    final scrollTX = this.scroller.scrollTransform.tx;
                    final visibleOutset = collectionViewFlowLayout.visibleOutset;
                    final collectionViewWidth = this.width;
                    for (i in 0...frames.length) {
                        var frame = frames.unsafeGet(i);
                        var minX = -scrollTX - visibleOutset;
                        var maxX = minX + collectionViewWidth + visibleOutset * 2;
                        frame.visible = (frame.x < maxX && frame.x + frame.width >= minX);
                        if (frame.visible && frame.width <= 0 || frame.height <= 0) {
                            frame.visible = false;
                        }
                        if (shouldHandleInvisible) handleInvisible(i, frame);
                    }
                }
            }
            else {
                for (i in 0...frames.length) {
                    var frame = frames[i];
                    frame.visible = collectionViewLayout.isFrameVisible(this, frame);
                    if (frame.visible && frame.width <= 0 || frame.height <= 0) {
                        frame.visible = false;
                    }

                    // We first handle all invisible frames, so that we can harvest reusable views
                    // and provide them on new frames right after
                    if (shouldHandleInvisible) handleInvisible(i, frame);
                }
            }

            for (i in 0...frames.length) {
                var frame = frames.unsafeGet(i);
                handleVisible(i, frame);
            }
        }

        if (autoDestroyItems) {
            while (reusableViews.length > maxReusableViewsCount) {
                reusableViews.pop().destroy();
            }
        }

    }

/// Helpers

    /**
     * Calculates the scroll X position needed to show an item at the desired position.
     *
     * @param itemIndex Index of the item to scroll to
     * @param itemPosition Where to position the item (START, MIDDLE, END, ENSURE_VISIBLE)
     * @return Target scroll X value
     */
    public function getTargetScrollXForItem(itemIndex:Int, itemPosition:CollectionViewItemPosition = CollectionViewItemPosition.ENSURE_VISIBLE):Float {

        if (itemIndex < 0) {
            itemIndex = 0;
        }
        else if (itemIndex >= frames.length) {
            itemIndex = frames.length - 1;
        }

        var frame = frames[itemIndex];

        var targetScrollX = scroller.scrollX;

        switch itemPosition {
            case START:
                targetScrollX = frame.x;
            case MIDDLE:
                targetScrollX = frame.x - width * 0.5 + frame.width * 0.5;
            case END:
                targetScrollX = frame.x - width + frame.width;
            case ENSURE_VISIBLE:
                var min = frame.x - width + frame.width;
                var max = frame.x;
                if (targetScrollX > max) {
                    targetScrollX = max;
                }
                else if (targetScrollX < min) {
                    targetScrollX = min;
                }
        }

        // Check bounds
        var lastFrame = frames[frames.length - 1];
        var maxScrollX = lastFrame.x + lastFrame.width - width;
        if (targetScrollX > maxScrollX) {
            targetScrollX = maxScrollX;
        }
        if (targetScrollX < 0) {
            targetScrollX = 0;
        }

        return targetScrollX;

    }

    /**
     * Calculates the scroll Y position needed to show an item at the desired position.
     *
     * @param itemIndex Index of the item to scroll to
     * @param itemPosition Where to position the item (START, MIDDLE, END, ENSURE_VISIBLE)
     * @return Target scroll Y value
     */
    public function getTargetScrollYForItem(itemIndex:Int, itemPosition:CollectionViewItemPosition = CollectionViewItemPosition.ENSURE_VISIBLE):Float {

        if (itemIndex < 0) {
            itemIndex = 0;
        }
        else if (itemIndex >= frames.length) {
            itemIndex = frames.length - 1;
        }

        var frame = frames[itemIndex];

        var targetScrollY = scroller.scrollY;

        switch itemPosition {
            case START:
                targetScrollY = frame.y;
            case MIDDLE:
                targetScrollY = frame.y - height * 0.5 + frame.height * 0.5;
            case END:
                targetScrollY = frame.y - height + frame.height;
            case ENSURE_VISIBLE:
                var min = frame.y - height + frame.height;
                var max = frame.y;
                if (targetScrollY > max) {
                    targetScrollY = max;
                }
                else if (targetScrollY < min) {
                    targetScrollY = min;
                }
        }

        // Check bounds
        var lastFrame = frames[frames.length - 1];
        var maxScrollY = lastFrame.y + lastFrame.height - height;
        if (targetScrollY > maxScrollY) {
            targetScrollY = maxScrollY;
        }
        if (targetScrollY < 0) {
            targetScrollY = 0;
        }

        return targetScrollY;

    }

    /**
     * Immediately scrolls to show the specified item.
     *
     * @param itemIndex Index of the item to scroll to
     * @param itemPosition Where to position the item:
     *                     - ENSURE_VISIBLE: Scroll minimum amount to make visible
     *                     - START: Position at start of view
     *                     - MIDDLE: Center in view
     *                     - END: Position at end of view
     */
    public function scrollToItem(itemIndex:Int, itemPosition:CollectionViewItemPosition = CollectionViewItemPosition.ENSURE_VISIBLE):Void {

        var targetScrollX = scroller.scrollX;
        var targetScrollY = scroller.scrollY;

        if (frames.length == 0) return;

        if (direction == VERTICAL) {
            targetScrollY = getTargetScrollYForItem(itemIndex, itemPosition);
        }
        else {
            targetScrollX = getTargetScrollXForItem(itemIndex, itemPosition);
        }

        scroller.scrollTo(targetScrollX, targetScrollY);

    }

    /**
     * Smoothly animates scrolling to show the specified item.
     *
     * @param itemIndex Index of the item to scroll to
     * @param itemPosition Where to position the item (see scrollToItem)
     * @param duration Animation duration in seconds (default: 0.15)
     * @param easing Easing function for the animation
     */
    public function smoothScrollToItem(itemIndex:Int, itemPosition:CollectionViewItemPosition = CollectionViewItemPosition.ENSURE_VISIBLE, duration:Float = 0.15, ?easing:Easing) {

        var targetScrollX = scroller.scrollX;
        var targetScrollY = scroller.scrollY;

        if (frames.length == 0) return;

        if (direction == VERTICAL) {
            targetScrollY = getTargetScrollYForItem(itemIndex, itemPosition);
        }
        else {
            targetScrollX = getTargetScrollXForItem(itemIndex, itemPosition);
        }

        scroller.smoothScrollTo(targetScrollX, targetScrollY, duration, easing);

    }

}

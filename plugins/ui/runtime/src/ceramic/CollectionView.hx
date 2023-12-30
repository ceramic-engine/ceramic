package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

class CollectionView extends ScrollView {

    public var collectionViewFlowLayout(default,null):CollectionViewFlowLayout;

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

    public var dataSource(default,set):CollectionViewDataSource = null;

    public var autoDestroyItems:Bool = true;

    public var maxReusableViewsCount:Int = 1;

    /**
     * Control how children depth is sorted.
     */
    public var childrenDepth(default,set):ChildrenDepth = SAME;
    function set_childrenDepth(childrenDepth:ChildrenDepth):ChildrenDepth {
        if (this.childrenDepth == childrenDepth) return childrenDepth;
        this.childrenDepth = childrenDepth;
        layoutDirty = true;
        return childrenDepth;
    }

    public var frames:ReadOnlyArray<CollectionViewItemFrame> = [];

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

    var reusableViews:Array<View> = [];

    var prevLayoutWidth:Float = -1;

    var prevLayoutHeight:Float = -1;

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
                if (view != null) {
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

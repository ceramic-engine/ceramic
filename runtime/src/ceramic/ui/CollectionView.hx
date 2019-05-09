package ceramic.ui;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

class CollectionView extends ScrollView {

    public var collectionViewLayout:CollectionViewLayout = new CollectionViewFlowLayout();

    public var dataSource(default,set):CollectionViewDataSource = null;

    public var autoDestroyItems:Bool = true;

    public var depthPerItem:Bool = false;

    public var frames:ImmutableArray<CollectionViewItemFrame> = [];

    public var freezeVisibleItems:Bool = false;

    var reusableViews:Array<View> = [];

    public function new() {

        super();

        scroller.scrollTransform.onChange(this, computeVisibleItems);

    } //new

    override function destroy() {

        dataSource = null;
        for (i in 0...reusableViews.length) {
            var view = reusableViews.unsafeGet(i);
            view.destroy();
        }
        reusableViews = null;

    } //destroy

    function set_dataSource(dataSource:CollectionViewDataSource):CollectionViewDataSource {
        if (this.dataSource == dataSource) return dataSource;

        this.dataSource = dataSource;

        reloadData();

        return dataSource;
    } //dataSource

    public function reloadData():Void {

        if (this.frames.length > 0) {
            for (i in 0...this.frames.length) {
                var frame = this.frames.unsafeGet(i);

                if (frame.view != null) {
                    if (autoDestroyItems) frame.view.destroy();
                }
            }
        }

        if (dataSource != null) {
            var numItems = dataSource.collectionViewSize();
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

    } //reloadData

    override function layout() {

        scroller.pos(0, 0);
        scroller.size(width, height);

        if (frames.length > 0) {
            // Get item sizes
            for (i in 0...frames.length) {
                dataSource.collectionViewItemFrameAtIndex(i, frames[i]);
            }
            // Layout items
            collectionViewLayout.collectionViewLayout(this, frames);
        }

        if (direction == VERTICAL) {
            contentView.height = Math.max(height, contentSize);
        } else {
            contentView.width = Math.max(width, contentSize);
        }

        //scroller.scrollToBounds();
        computeVisibleItems();

    } //layout

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
                var maxFrameY = frame.y + frame.width - scrollY;

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

    } //findClosestItem

    public function computeVisibleItems():Void {

        if (dataSource == null) return;

        inline function handleVisible(itemIndex:Int, frame:CollectionViewItemFrame) {
            if (frame.visible) {
                // Add/Recycle views that become visible
                if (!freezeVisibleItems && frame.view == null) {
                    if (reusableViews.length > 0) {
                        var reusableView = reusableViews.pop();
                        frame.view = dataSource.collectionViewItemAtIndex(itemIndex, reusableView);
                        if (frame.view != reusableView) {
                            if (autoDestroyItems) reusableView.destroy();
                        }
                    }
                    else {
                        frame.view = dataSource.collectionViewItemAtIndex(itemIndex, null);
                    }
                }

                var view = frame.view;
                if (view != null) {
                    if (depthPerItem) {
                        view.depth = itemIndex;
                    } else {
                        view.depth = 0.5;
                    }
                    var prevWidth = view.width;
                    var prevHeight = view.height;
                    view.viewSize(frame.width, frame.height);
                    view.size(frame.width, frame.height);
                    if (view.layoutDirty) contentView.layoutDirty = true;
                    var newX = frame.x + frame.width * view.anchorX;
                    var newY = frame.y + frame.height * view.anchorY;
                    view.pos(newX, newY);
                    view.visible = true;
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
                    if (!dataSource.collectionViewReleaseItemAtIndex(itemIndex, frame.view)) {
                        if (!frame.view.destroyed) {
                            frame.view.visible = false;
                            if (autoDestroyItems) frame.view.destroy();
                        }
                    }
                    else {
                        frame.view.visible = false;
                        reusableViews.push(frame.view);
                    }
                    frame.view = null;
                }
            }
        }

        if (direction == VERTICAL) {

            for (i in 0...frames.length) {
                var frame = frames[i];
                frame.visible = collectionViewLayout.isFrameVisible(this, frame);

                // We first handle all invisible frames, so that we can harvest reusable views
                // and provide them on new frames right after
                if (!freezeVisibleItems) handleInvisible(i, frame);
            }

            for (i in 0...frames.length) {
                var frame = frames[i];
                handleVisible(i, frame);
            }

        } else {

            for (i in 0...frames.length) {
                var frame = frames[i];
                frame.visible = collectionViewLayout.isFrameVisible(this, frame);
                if (frame.visible && frame.width <= 0 || frame.height <= 0) {
                    frame.visible = false;
                }

                // We first handle all invisible frames, so that we can harvest reusable views
                // and provide them on new frames right after
                if (!freezeVisibleItems) handleInvisible(i, frame);
            }

            for (i in 0...frames.length) {
                var frame = frames[i];
                handleVisible(i, frame);
            }
        }

    } //computeVisibleItems

/// Helpers

    public function scrollToItem(itemIndex:Int, itemPosition:CollectionViewItemPosition = CollectionViewItemPosition.START) {

        // TODO handle itemPosition option

        var targetScrollX = scroller.scrollX;
        var targetScrollY = scroller.scrollY;

        if (frames.length == 0) return;

        if (itemIndex < 0) {
            itemIndex = 0;
        }
        else if (itemIndex >= frames.length) {
            itemIndex = frames.length - 1;
        }

        var frame = frames[itemIndex];

        if (direction == VERTICAL) {
            targetScrollY = frame.y;
        }
        else {
            if (targetScrollX > frame.x) {
                targetScrollX = frame.x;
            }
            else if (targetScrollX < frame.x + frame.width - width) {
                targetScrollX = frame.x + frame.width - width;
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

        scroller.scrollTo(targetScrollX, targetScrollY);

    } //scrollToItem

    public function smoothScrollToItem(itemIndex:Int) {

        var targetScrollX = scroller.scrollX;
        var targetScrollY = scroller.scrollY;

        if (frames.length == 0) return;

        if (itemIndex < 0) {
            itemIndex = 0;
        }
        else if (itemIndex >= frames.length) {
            itemIndex = frames.length - 1;
        }

        var frame = frames[itemIndex];

        if (direction == VERTICAL) {
            targetScrollY = frame.y;
        }
        else {
            if (targetScrollX > frame.x) {
                targetScrollX = frame.x;
            }
            else if (targetScrollX < frame.x + frame.width - width) {
                targetScrollX = frame.x + frame.width - width;
            }
        }

        scroller.smoothScrollTo(targetScrollX, targetScrollY);

    } //smoothScrollTo

} //CollectionView

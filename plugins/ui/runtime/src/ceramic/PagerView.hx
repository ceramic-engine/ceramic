package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * A scroll view that layouts its items as pages, where
 * each page is exactly the size of the pager view bounds.
 *
 * This implementation is designed to support a very large number
 * of items without consuming too much CPU, so it's a preferred option
 * over `CollectionView` if you just need a way to browse through
 * children with all the same size as the pager bounds.
 *
 * It also supports looping (when paging is enabled)
 */
class PagerView extends ScrollView {

    static var _didWarnPageSize:Bool = false;

    static var _tmpArray:Array<Int> = [];

    public var dataSource(default,set):PagerViewDataSource = null;

    public var autoDestroyItems:Bool = true;

    public var maxReusableViewsCount:Int = 1;

    public var visibleOutset(default,set):Float = 0.0;
    function set_visibleOutset(visibleOutset:Float):Float {
        if (this.visibleOutset != visibleOutset) {
            this.visibleOutset = visibleOutset;
            layoutDirty = true;
        }
        return visibleOutset;
    }

    /**
     * The number of pages to preload before and after, in advance.
     * - 0: no preload at all (but usually not recommended as you'll see it)
     * - 1: default value, with sibling pages automatically preloaded
     * - higher values will preload more pages before and after, usually not needed
     */
    public var preloadAmplitude(default,set):Int = 1;
    function set_preloadAmplitude(preloadAmplitude:Int):Int {
        if (this.preloadAmplitude != preloadAmplitude) {
            this.preloadAmplitude = preloadAmplitude;
            layoutDirty = true;
        }
        return preloadAmplitude;
    }

    public var hidePagesOutsideBounds(default,set):Bool = true;
    function set_hidePagesOutsideBounds(hidePagesOutsideBounds:Bool):Bool {
        if (this.hidePagesOutsideBounds != hidePagesOutsideBounds) {
            this.hidePagesOutsideBounds = hidePagesOutsideBounds;
            layoutDirty = true;
        }
        return hidePagesOutsideBounds;
    }

    /**
     * Loop to the beginning when reaching the end.
     * (ignored if paging is disabled)
     */
    public var loop(default,set):Bool = false;
    function set_loop(loop:Bool):Bool {
        if (this.loop != loop) {
            this.loop = loop;
            layoutDirty = true;
        }
        return loop;
    }

    override function set_pageSize(pageSize:Float):Float {
        if (!_didWarnPageSize) {
            _didWarnPageSize = true;
            log.warning('Setting pageSize to PagerView has no effect: page size is always the size of the pager view itself.');
        }
        return scroller.pageSize;
    }

    override function set_pageSpacing(pageSpacing:Float):Float {
        if (this.pageSpacing != pageSpacing) {
            scroller.pageSpacing = pageSpacing;
            layoutDirty = true;
        }
        return pageSpacing;
    }

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

    var pageViews:IntMap<View> = null;

    var numPages:Int = 0;

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        pageViews = new IntMap(16, 0.5, true);
        scroller.pagingEnabled = true;
        scroller.scrollTransform.onChange(this, computeLoadedPages);

        scroller.onDragEnd(this, handleDragEnd);

    }

    override function destroy() {

        super.destroy();

        dataSource = null;
        for (i in 0...reusableViews.length) {
            var view = reusableViews.unsafeGet(i);
            view.destroy();
        }
        reusableViews = null;

        if (pageViews != null) {
            for (pageView in pageViews) {
                pageView.destroy();
            }
            pageViews = null;
        }

    }

    function set_dataSource(dataSource:PagerViewDataSource):PagerViewDataSource {
        if (this.dataSource == dataSource) return dataSource;

        this.dataSource = dataSource;

        reloadData();

        return dataSource;
    }

    public function reloadData():Void {

        if (dataSource != null) {
            numPages = dataSource.pagerViewSize(this);
        }
        else {
            numPages = 0;
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
        scroller.overScrollResistance = loop && numPages > 1 ? 1.0 : 5.0;

        if (direction == VERTICAL) {
            scroller.pageSize = height;
            contentSize = Math.max(0, numPages * (height + pageSpacing) - pageSpacing);
            contentView.width = width;
            contentView.height = contentSize;

            if (didResize && contentView.height - scroller.scrollY < height) {
                scroller.scrollY = contentView.height - height;
            }
        } else {
            scroller.pageSize = width;
            contentSize = Math.max(0, numPages * (width + pageSpacing) - pageSpacing);
            contentView.width = contentSize;
            contentView.height = height;

            if (didResize && contentView.width - scroller.scrollX < width) {
                scroller.scrollX = contentView.width - width;
            }
        }

        computeLoadedPages();

    }

    public function closestPageIndex():Int {

        var scroll:Float = (direction == VERTICAL) ? scroller.scrollY : scroller.scrollX;
        final pageValue:Float = scroll / (pageSize + pageSpacing);
        final basePageValue:Int = Math.floor(pageValue);
        final pageRatio:Float = (pageValue - basePageValue) * ((pageSize + pageSpacing) / pageSize);
        var mainPageIndex:Int = basePageValue + (pageRatio >= pageSize * 0.5 ? 1 : 0);
        if (loop && numPages > 1) {
            while (mainPageIndex < 0) {
                mainPageIndex += numPages;
            }
            mainPageIndex = (mainPageIndex % numPages);
        }
        else if (numPages > 0) {
            mainPageIndex = Std.int(Math.max(0, mainPageIndex)) % numPages;
        }
        else {
            mainPageIndex = 0;
        }
        return mainPageIndex;

    }

    public function computeLoadedPages():Void {

        final shouldHandleUnloads = (itemsBehavior != FREEZE && itemsBehavior != LAZY && scroller.status != DRAGGING);

        var numUsed:Int = 0;

        if (dataSource != null) {

            final width:Float = this.width;
            final height:Float = this.height;
            final scroll:Float = (direction == VERTICAL) ? scroller.scrollY : scroller.scrollX;
            final pageValue:Float = scroll / (pageSize + pageSpacing);
            final basePageValue:Int = Math.floor(pageValue);
            final pageRatio:Float = (pageValue - basePageValue) * ((pageSize + pageSpacing) / pageSize);
            final mainPageIndex:Int = closestPageIndex();

            for (i in (mainPageIndex-preloadAmplitude)...(mainPageIndex+preloadAmplitude+1)) {
                var pageIndex = i;
                if (pageIndex < 0) {
                    if (loop && numPages > 1) {
                        while (pageIndex < 0) {
                            pageIndex += numPages;
                        }
                    }
                    else {
                        continue;
                    }
                }
                else if (pageIndex >= numPages) {
                    if (loop && numPages > 1) {
                        pageIndex = (pageIndex % numPages);
                    }
                    else {
                        continue;
                    }
                }

                _tmpArray[numUsed] = pageIndex;
                numUsed++;

                var pageView = pageViews.get(pageIndex);
                if (pageView == null) {
                    if (reusableViews.length > 0) {
                        var reusableView = reusableViews.pop();
                        pageView = dataSource.pagerViewPageAtIndex(this, pageIndex, reusableView);
                        if (pageView != reusableView) {
                            if (autoDestroyItems) reusableView.destroy();
                        }
                    }
                    else {
                        pageView = dataSource.pagerViewPageAtIndex(this, pageIndex, null);
                    }
                    if (pageView != null) {
                        pageViews.set(pageIndex, pageView);
                    }
                }

                if (pageView != null) {
                    handlePageView(pageIndex, pageView);
                }
            }
        }

        if (shouldHandleUnloads) {
            var numToRemove = 0;
            for (pageIndex => pageView in pageViews) {
                var isUsed = false;
                for (i in 0...numUsed) {
                    if (_tmpArray.unsafeGet(i) == pageIndex) {
                        isUsed = true;
                        break;
                    }
                }
                if (!isUsed) {
                    _tmpArray[numUsed + numToRemove] = pageIndex;
                    numToRemove++;
                }
            }
            if (numToRemove > 0) {
                for (key in (numUsed...numUsed+numToRemove)) {
                    var pageIndex = _tmpArray.unsafeGet(key);
                    var pageView = pageViews.get(pageIndex);

                    if (!dataSource.pagerViewReleasePageAtIndex(this, pageIndex, pageView)) {
                        if (!pageView.destroyed) {
                            pageView.active = false;
                            if (autoDestroyItems) pageView.destroy();
                        }
                    }
                    else {
                        pageView.active = false;
                        reusableViews.push(pageView);
                    }

                    pageViews.remove(pageIndex);
                }
            }
        }

        if (autoDestroyItems) {
            while (reusableViews.length > maxReusableViewsCount) {
                reusableViews.pop().destroy();
            }
        }

    }

    function handlePageView(pageIndex:Int, pageView:View) {

        var pageX:Float = 0;
        var pageY:Float = 0;
        if (direction == VERTICAL) {
            pageY = pageIndex * (pageSize + pageSpacing);
        }
        else {
            pageX = pageIndex * (pageSize + pageSpacing);
        }

        if (loop && numPages > 1) {
            if (direction == VERTICAL) {
                final centerY = scroller.scrollY + height * 0.5;
                var altPageY = (pageIndex - numPages) * (pageSize + pageSpacing);
                if (Math.abs(altPageY + height - centerY) < Math.abs(pageY - centerY)) {
                    pageY = altPageY;
                }
                else {
                    altPageY = (pageIndex + numPages) * (pageSize + pageSpacing);
                    if (Math.abs(altPageY + height - centerY) < Math.abs(pageY - centerY)) {
                        pageY = altPageY;
                    }
                }
            }
            else {
                final centerX = scroller.scrollX + width * 0.5;
                var altPageX = (pageIndex - numPages) * (pageSize + pageSpacing);
                if (Math.abs(altPageX + width - centerX) < Math.abs(pageX - centerX)) {
                    pageX = altPageX;
                }
                else {
                    altPageX = (pageIndex + numPages) * (pageSize + pageSpacing);
                    if (Math.abs(altPageX + width - centerX) < Math.abs(pageX - centerX)) {
                        pageX = altPageX;
                    }
                }
            }
        }

        if (childrenDepth == INCREMENT) {
            pageView.depth = pageIndex;
        }
        else if (childrenDepth == DECREMENT) {
            pageView.depth = numPages - pageIndex;
        }
        else if (childrenDepth == SAME) {
            pageView.depth = 1;
        }
        var prevWidth = pageView.width;
        var prevHeight = pageView.height;
        pageView.viewSize(width, height);
        pageView.size(width, height);
        if (pageView.layoutDirty) contentView.layoutDirty = true;
        var newX = pageX + width * pageView.anchorX;
        var newY = pageY + height * pageView.anchorY;
        pageView.pos(newX, newY);

        if (hidePagesOutsideBounds) {
            if (direction == VERTICAL) {
                final minY = scroller.scrollY - visibleOutset;
                final maxY = minY + height + visibleOutset * 2;
                pageView.active = (pageY < maxY && pageY + height >= minY);
            }
            else {
                final minX = scroller.scrollX - visibleOutset;
                final maxX = minX + width + visibleOutset * 2;
                pageView.active = (pageX < maxX && pageX + width >= minX);
            }
        }
        else {
            pageView.active = true;
        }

        if (pageView.parent != contentView) {
            contentView.add(pageView);
        }
        if (prevWidth != pageView.width || prevHeight != pageView.height) {
            // Size change may produce anchor change on layout,
            // this we reassign again x and y in that case
            pageView.onceLayout(this, function() {
                var newX = pageX + pageView.width * pageView.anchorX;
                var newY = pageY + pageView.height * pageView.anchorY;
                pageView.pos(newX, newY);
            });
        }

    }

    function handleDragEnd() {

        if (loop && numPages > 1) {

            var targetPage = scroller.computeTargetPageIndex();
            if (targetPage < 0) {
                while (targetPage < 0) {
                    targetPage += numPages;
                    if (direction == VERTICAL) {
                        scroller.scrollY += contentSize;
                    }
                    else {
                        scroller.scrollX += contentSize;
                    }
                }
            }
            else if (targetPage >= numPages) {
                while (targetPage >= numPages) {
                    targetPage -= numPages;
                    if (direction == VERTICAL) {
                        scroller.scrollY -= contentSize;
                    }
                    else {
                        scroller.scrollX -= contentSize;
                    }
                }
            }

        }

    }

/// Helpers

    public function getTargetScrollXForPageIndex(pageIndex:Int):Float {

        return scroller.getTargetScrollXForPageIndex(pageIndex);

    }

    public function getTargetScrollYForPageIndex(pageIndex:Int):Float {

        return scroller.getTargetScrollYForPageIndex(pageIndex);

    }

    public function scrollToPageIndex(pageIndex:Int):Void {

        scroller.scrollToPageIndex(pageIndex);

    }

    public function smoothScrollToPageIndex(pageIndex:Int, duration:Float = 0.15, ?easing:Easing) {

        scroller.smoothScrollToPageIndex(pageIndex, duration, easing);

    }

}

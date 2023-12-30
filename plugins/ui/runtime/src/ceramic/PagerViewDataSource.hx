package ceramic;

interface PagerViewDataSource {

    /**
     * Get the number of elements.
     */
    function pagerViewSize(pagerView:PagerView):Int;

    /**
     * Called when a view is not used anymore at the given index. Lets the dataSource
     * do some cleanup if needed, before this view gets reused (if it can).
     * Returns `true` if the view can be reused at another index of `false` otherwise.
     */
    function pagerViewReleasePageAtIndex(pagerView:PagerView, pageIndex:Int, view:View):Bool;

    /**
     * Get a view at the given index. If `reusableView` is provided,
     * it can be recycled as the new item to avoid creating new instances.
     */
    function pagerViewPageAtIndex(pagerView:PagerView, pageIndex:Int, reusableView:View):View;

}

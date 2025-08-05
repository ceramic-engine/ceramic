package ceramic;

/**
 * Data source interface for PagerView that provides page content
 * and manages view lifecycle.
 * 
 * Implementations of this interface control:
 * - The total number of pages
 * - Creation and configuration of page views
 * - Recycling behavior for efficient memory usage
 * 
 * ```haxe
 * class MyPagerDataSource implements PagerViewDataSource {
 *     var pages:Array<PageData>;
 *     
 *     public function pagerViewSize(pagerView:PagerView):Int {
 *         return pages.length;
 *     }
 *     
 *     public function pagerViewPageAtIndex(pagerView:PagerView, pageIndex:Int, reusableView:View):View {
 *         var view = (reusableView != null) ? reusableView : new MyPageView();
 *         view.configure(pages[pageIndex]);
 *         return view;
 *     }
 *     
 *     public function pagerViewReleasePageAtIndex(pagerView:PagerView, pageIndex:Int, view:View):Bool {
 *         // Clean up and return true to allow reuse
 *         view.reset();
 *         return true;
 *     }
 * }
 * ```
 */
interface PagerViewDataSource {

    /**
     * Get the number of elements.
     * @param pagerView The PagerView requesting the size
     * @return Total number of pages to display
     */
    function pagerViewSize(pagerView:PagerView):Int;

    /**
     * Called when a view is not used anymore at the given index. Lets the dataSource
     * do some cleanup if needed, before this view gets reused (if it can).
     * Returns `true` if the view can be reused at another index of `false` otherwise.
     * 
     * This method is called when:
     * - The page scrolls out of the visible range
     * - The PagerView is destroyed
     * - Data is reloaded
     * 
     * @param pagerView The PagerView releasing the view
     * @param pageIndex The index of the page being released
     * @param view The view to potentially recycle
     * @return true if the view can be reused, false to destroy it
     */
    function pagerViewReleasePageAtIndex(pagerView:PagerView, pageIndex:Int, view:View):Bool;

    /**
     * Get a view at the given index. If `reusableView` is provided,
     * it can be recycled as the new item to avoid creating new instances.
     * 
     * Implementation tips:
     * - Always check if reusableView is non-null before creating a new view
     * - Configure the view with data for the specified pageIndex
     * - The returned view will be sized to match the PagerView dimensions
     * 
     * @param pagerView The PagerView requesting the view
     * @param pageIndex The index of the page to display
     * @param reusableView Optional recycled view to configure and return
     * @return A configured View for the specified page index
     */
    function pagerViewPageAtIndex(pagerView:PagerView, pageIndex:Int, reusableView:View):View;

}

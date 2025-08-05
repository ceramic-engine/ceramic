package ceramic;

/**
 * Interface for providing data to a CollectionView.
 * 
 * The data source is responsible for:
 * - Reporting the total number of items
 * - Setting the size/position of each item frame
 * - Creating and configuring item views
 * - Managing view recycling
 * 
 * ```haxe
 * class MyDataSource implements CollectionViewDataSource {
 *     var items:Array<ItemData>;
 *     
 *     public function collectionViewSize(view:CollectionView):Int {
 *         return items.length;
 *     }
 *     
 *     public function collectionViewItemFrameAtIndex(view:CollectionView, index:Int, frame:CollectionViewItemFrame):Void {
 *         // Set item dimensions
 *         frame.width = 100;
 *         frame.height = 120;
 *     }
 *     
 *     public function collectionViewItemAtIndex(view:CollectionView, index:Int, reusableView:View):View {
 *         // Create or reuse a view
 *         var itemView = reusableView != null ? cast(reusableView, ItemView) : new ItemView();
 *         itemView.data = items[index];
 *         return itemView;
 *     }
 *     
 *     public function collectionViewReleaseItemAtIndex(view:CollectionView, index:Int, itemView:View):Bool {
 *         // Clean up and return true to allow reuse
 *         cast(itemView, ItemView).data = null;
 *         return true;
 *     }
 * }
 * ```
 * 
 * @see CollectionView
 * @see CollectionViewItemFrame
 */
interface CollectionViewDataSource {

    /**
     * Returns the total number of items in the collection.
     * This is called whenever the collection view needs to know how many items to display.
     * 
     * @param collectionView The collection view requesting the size
     * @return The total number of items
     */
    function collectionViewSize(collectionView:CollectionView):Int;

    /**
     * Sets the dimensions for an item at the specified index.
     * The frame object should be modified with the desired width and height.
     * Position (x, y) will be calculated by the layout.
     * 
     * @param collectionView The collection view displaying the item
     * @param itemIndex Zero-based index of the item
     * @param frame The frame object to configure (modify width and height)
     */
    function collectionViewItemFrameAtIndex(collectionView:CollectionView, itemIndex:Int, frame:CollectionViewItemFrame):Void;

    /**
     * Called when an item view is about to be recycled or removed.
     * This allows cleanup of the view before it's reused for a different item.
     * 
     * Common cleanup tasks:
     * - Remove event listeners
     * - Cancel animations
     * - Clear references to prevent memory leaks
     * 
     * @param collectionView The collection view containing the item
     * @param itemIndex The index of the item being released
     * @param view The view being released
     * @return true if the view can be recycled, false to destroy it
     */
    function collectionViewReleaseItemAtIndex(collectionView:CollectionView, itemIndex:Int, view:View):Bool;

    /**
     * Creates or configures a view for the item at the specified index.
     * 
     * If reusableView is provided, it should be reconfigured for the new item
     * to avoid creating new view instances. This improves performance.
     * 
     * The returned view will be automatically positioned and sized by the
     * collection view based on the frame data.
     * 
     * @param collectionView The collection view requesting the item
     * @param itemIndex Zero-based index of the item to display
     * @param reusableView An existing view that can be reconfigured, or null
     * @return The configured view to display for this item
     */
    function collectionViewItemAtIndex(collectionView:CollectionView, itemIndex:Int, reusableView:View):View;

}

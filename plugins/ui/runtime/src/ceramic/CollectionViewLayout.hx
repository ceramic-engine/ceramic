package ceramic;

/**
 * Interface for custom CollectionView layout implementations.
 * 
 * A layout is responsible for:
 * - Positioning items within the collection view
 * - Calculating content size for scrolling
 * - Determining item visibility for efficient rendering
 * 
 * The built-in CollectionViewFlowLayout provides a standard grid/flow layout,
 * but custom layouts can be created for specialized arrangements like:
 * - Circular/radial layouts
 * - Masonry/Pinterest-style layouts
 * - Custom stacking or cascading effects
 * 
 * @example
 * ```haxe
 * class CustomLayout implements CollectionViewLayout {
 *     public function new() {}
 *     
 *     public function collectionViewLayout(view:CollectionView, frames:ReadOnlyArray<CollectionViewItemFrame>):Void {
 *         // Position each frame
 *         var y = 0.0;
 *         for (frame in frames) {
 *             frame.x = 0;
 *             frame.y = y;
 *             y += frame.height + 10; // 10px spacing
 *         }
 *         
 *         // Set content size
 *         view.contentSize = y;
 *     }
 *     
 *     public function isFrameVisible(view:CollectionView, frame:CollectionViewItemFrame):Bool {
 *         // Check if frame intersects viewport
 *         var scrollY = view.scroller.scrollY;
 *         return frame.y < scrollY + view.height && frame.y + frame.height > scrollY;
 *     }
 * }
 * ```
 * 
 * @see CollectionView
 * @see CollectionViewFlowLayout
 * @see CollectionViewItemFrame
 */
interface CollectionViewLayout {

    /**
     * Performs layout calculation for all item frames.
     * 
     * This method should:
     * - Set the x and y position for each frame based on its width/height
     * - Calculate and set the total content size on the collection view
     * - Not modify frame width/height (those come from the data source)
     * 
     * The layout runs whenever the collection view size changes or data is reloaded.
     * 
     * @param collectionView The collection view being laid out
     * @param frames Array of frames to position (modify x and y properties)
     */
    function collectionViewLayout(collectionView:CollectionView, frames:ReadOnlyArray<CollectionViewItemFrame>):Void;

    /**
     * Determines whether a frame is visible within the current viewport.
     * 
     * This method is called frequently during scrolling to determine which
     * items need to be rendered. Efficient implementation is important.
     * 
     * Should account for:
     * - Current scroll position
     * - Collection view bounds
     * - Any pre-render margins (visibleOutset)
     * 
     * @param collectionView The collection view to test against
     * @param frame The frame to check for visibility
     * @return true if the frame intersects the visible area
     */
    function isFrameVisible(collectionView:CollectionView, frame:CollectionViewItemFrame):Bool;

}

package ceramic;

/**
 * Represents the position and dimensions of an item in a CollectionView.
 * 
 * Each item in the collection has a corresponding frame that defines where
 * it should be positioned and how large it should be. The CollectionView
 * uses this information to:
 * - Determine which items are visible
 * - Position item views correctly
 * - Calculate content size for scrolling
 * 
 * Frames are managed internally by CollectionView and its layout.
 * The data source provides width/height, while the layout sets x/y positions.
 * 
 * @see CollectionView
 * @see CollectionViewLayout
 * @see CollectionViewDataSource
 */
@:allow(ceramic.CollectionView)
class CollectionViewItemFrame {

    /**
     * The X coordinate of the item's position within the content area.
     * Set by the layout during positioning.
     */
    public var x:Float;

    /**
     * The Y coordinate of the item's position within the content area.
     * Set by the layout during positioning.
     */
    public var y:Float;

    /**
     * The width of the item in pixels.
     * Should be set by the data source in collectionViewItemFrameAtIndex().
     */
    public var width:Float;

    /**
     * The height of the item in pixels.
     * Should be set by the data source in collectionViewItemFrameAtIndex().
     */
    public var height:Float;

    /**
     * Whether this item is currently visible in the viewport.
     * Managed internally by CollectionView based on scroll position.
     * When false, the associated view may be recycled.
     */
    public var visible(default,null):Bool = false;

    /**
     * The view currently displaying this item, if any.
     * Will be null for items that are not visible or when using lazy loading.
     * Managed internally by CollectionView's view recycling system.
     */
    public var view(default,null):View = null;

    /**
     * Creates a new item frame with the specified dimensions.
     * 
     * @param x Initial X position
     * @param y Initial Y position
     * @param width Item width
     * @param height Item height
     */
    public function new(x:Float, y:Float, width:Float, height:Float) {

        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;

    }

/// Print

    /**
     * Returns a string representation of this frame for debugging.
     * @return String in format "Frame(x=X y=Y w=WIDTH h=HEIGHT)"
     */
    function toString() {
        return 'Frame(x=$x y=$y w=$width h=$height)';
    }

}

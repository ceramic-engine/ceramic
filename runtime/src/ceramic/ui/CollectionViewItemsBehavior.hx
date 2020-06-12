package ceramic.ui;

enum CollectionViewItemsBehavior {

    /**
     * Create new items that need to be displayed, recycle items that got out of bounds
     */
    RECYCLE;

    /**
     * No item is created or removed
     */
    FREEZE;

    /**
     * New items are created as needed, existing items are not removed or recycled
     */
    LAZY;

}
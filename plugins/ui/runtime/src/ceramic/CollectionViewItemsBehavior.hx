package ceramic;

import ceramic.macros.EnumAbstractMacro;

/**
 * Defines how a CollectionView manages item view creation and recycling.
 * 
 * Different behaviors offer trade-offs between performance and memory usage:
 * - RECYCLE: Best for large collections with scrolling
 * - FREEZE: Best for small, static collections
 * - LAZY: Best for progressively loaded content
 * 
 * @example
 * ```haxe
 * // Use recycling for a large list
 * collectionView.itemsBehavior = RECYCLE;
 * 
 * // Freeze items for a small grid that fits on screen
 * collectionView.itemsBehavior = FREEZE;
 * 
 * // Use lazy loading for content that builds up over time
 * collectionView.itemsBehavior = LAZY;
 * ```
 * 
 * @see CollectionView
 */
enum abstract CollectionViewItemsBehavior(Int) {

    /**
     * Creates views for visible items and recycles them when they scroll out of view.
     * 
     * This is the most memory-efficient behavior for large collections.
     * Views are reused via the data source's reusableView parameter.
     * 
     * Characteristics:
     * - Low memory usage
     * - Good scrolling performance
     * - Views must handle being reconfigured for different data
     * 
     * Recommended for: Large scrollable lists, grids with many items
     */
    var RECYCLE = 1;

    /**
     * Once created, item views are never removed or recycled.
     * 
     * All views remain in memory and active regardless of visibility.
     * Scrolling only changes what's rendered, not what exists.
     * 
     * Characteristics:
     * - High memory usage
     * - Fastest scrolling (no view creation/destruction)
     * - Views maintain their state
     * 
     * Recommended for: Small collections that fit in memory, static content
     */
    var FREEZE = 2;

    /**
     * Creates new views as items become visible but never removes them.
     * 
     * Views accumulate over time as more content is revealed.
     * Similar to FREEZE but with on-demand creation.
     * 
     * Characteristics:
     * - Memory usage grows with scrolling
     * - Good for progressively revealed content
     * - Views maintain their state once created
     * 
     * Recommended for: Expanding content, chat histories, infinite scroll with caching
     */
    var LAZY = 3;

    /**
     * Returns a string representation of this enum value.
     * @return The behavior name ("RECYCLE", "FREEZE", or "LAZY")
     */
    public function toString() {
        return EnumAbstractMacro.toStringSwitch(CollectionViewItemsBehavior, abstract);
    }

}
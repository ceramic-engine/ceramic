package ceramic;

import ceramic.macros.EnumAbstractMacro;

/**
 * Defines where an item should be positioned when scrolling to it in a CollectionView.
 * 
 * Used with scrollToItem() and smoothScrollToItem() methods to control
 * how the target item is positioned within the visible area.
 * 
 * @see CollectionView.scrollToItem
 * @see CollectionView.smoothScrollToItem
 */
enum abstract CollectionViewItemPosition(Int) {

    /**
     * Positions the item at the start of the visible area.
     * - For vertical scrolling: Item appears at the top
     * - For horizontal scrolling: Item appears at the left
     */
    var START = 0;

    /**
     * Centers the item in the middle of the visible area.
     * The item will be positioned at the center of the viewport.
     */
    var MIDDLE = 1;

    /**
     * Positions the item at the end of the visible area.
     * - For vertical scrolling: Item appears at the bottom
     * - For horizontal scrolling: Item appears at the right
     */
    var END = 2;

    /**
     * Scrolls the minimum amount necessary to make the item visible.
     * If the item is already visible, no scrolling occurs.
     * If partially visible, scrolls to show the entire item.
     * This is the default behavior.
     */
    var ENSURE_VISIBLE = 3;

    /**
     * Returns a string representation of this enum value.
     * @return The name of the position (e.g., "START", "MIDDLE", "END", "ENSURE_VISIBLE")
     */
    public function toString() {
        return EnumAbstractMacro.toStringSwitch(CollectionViewItemPosition, abstract);
    }

}

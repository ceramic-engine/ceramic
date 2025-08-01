package ceramic;

/**
 * Defines the direction of scrolling for scrollable components.
 * 
 * Used by various UI components to specify whether scrolling should
 * occur horizontally (left/right) or vertically (up/down). This enum
 * helps configure scroll behavior in components like Scroller, ScrollView,
 * and other scrollable containers.
 * 
 * Example usage:
 * ```haxe
 * // Create a vertical scroller
 * var scroller = new Scroller();
 * scroller.direction = VERTICAL;
 * 
 * // Check scroll direction
 * if (scrollView.direction == HORIZONTAL) {
 *     // Handle horizontal scrolling
 * }
 * ```
 * 
 * @see ceramic.Scroller For touch-based scrolling
 * @see ceramic.ScrollView For scrollable view containers
 */
enum ScrollDirection {

    /**
     * Horizontal scrolling direction (left/right).
     * Content moves along the X-axis.
     */
    HORIZONTAL;

    /**
     * Vertical scrolling direction (up/down).
     * Content moves along the Y-axis.
     */
    VERTICAL;

}

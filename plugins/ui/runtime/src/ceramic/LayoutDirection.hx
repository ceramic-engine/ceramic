package ceramic;

/**
 * Defines the primary axis direction for layout arrangements.
 * Used by various layout components to determine how child elements
 * should be arranged relative to each other.
 * 
 * ```haxe
 * var layout = new LinearLayout();
 * layout.direction = HORIZONTAL; // Children arranged left-to-right
 * layout.direction = VERTICAL;   // Children arranged top-to-bottom
 * ```
 * 
 * @see LinearLayout
 * @see RowLayout
 * @see ColumnLayout
 */
enum LayoutDirection {

    /**
     * Horizontal layout direction (left-to-right).
     * Child elements are arranged along the X-axis, typically from left to right.
     * Used for row-based layouts where elements are placed side by side.
     */
    HORIZONTAL;

    /**
     * Vertical layout direction (top-to-bottom).
     * Child elements are arranged along the Y-axis, typically from top to bottom.
     * Used for column-based layouts where elements are stacked vertically.
     */
    VERTICAL;

}

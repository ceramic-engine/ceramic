package ceramic;

/**
 * A specialized LinearLayout that arranges children vertically in a single column.
 * 
 * ColumnLayout is a convenience class that enforces vertical layout direction.
 * It provides all the features of LinearLayout but prevents direction changes,
 * making the layout intent clearer in code.
 * 
 * Features inherited from LinearLayout:
 * - Item spacing control
 * - Alignment options (horizontal and vertical)
 * - Padding support
 * - Auto-sizing based on content
 * 
 * ```haxe
 * var column = new ColumnLayout();
 * column.itemSpacing = 10;
 * column.align = CENTER;
 * column.verticalAlign = TOP;
 * 
 * // Add items vertically
 * column.add(new TextView("Title"));
 * column.add(new TextView("Subtitle"));
 * column.add(new Button("Click Me"));
 * ```
 * 
 * @see LinearLayout for the base implementation
 * @see RowLayout for horizontal arrangement
 */
class ColumnLayout extends LinearLayout {

    /**
     * Creates a new ColumnLayout with vertical direction.
     * The direction is permanently set to VERTICAL and cannot be changed.
     */
    public function new() {

        super();
        direction = VERTICAL;

    }

    /**
     * Overrides the direction setter to enforce vertical-only layout.
     * Attempting to set any direction other than VERTICAL will throw an exception.
     * 
     * @param direction Must be VERTICAL
     * @return Always returns VERTICAL
     * @throws String if attempting to set a non-vertical direction
     */
    override function set_direction(direction:LayoutDirection):LayoutDirection {

        if (direction != VERTICAL) throw('Changing direction of a ColumnLayout is not allowed. Use a LinearLayout if you want to change direction at runtime.');
        return this.direction = VERTICAL;

    }

}

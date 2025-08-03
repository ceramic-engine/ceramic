package ceramic;

/**
 * A layout that arranges its children horizontally in a single row.
 * This class is a `LinearLayout` subclass, restricted to its horizontal direction.
 * 
 * RowLayout provides a convenient way to create horizontal layouts without
 * the risk of accidentally changing the direction at runtime. It inherits
 * all the alignment, spacing, and distribution features of LinearLayout.
 * 
 * @example
 * ```haxe
 * var row = new RowLayout();
 * row.itemSpacing = 10;
 * row.align = CENTER;
 * row.add(button1);
 * row.add(button2);
 * row.add(button3);
 * ```
 * 
 * @see ColumnLayout For vertical arrangement
 * @see LinearLayout For layouts that can change direction
 */
class RowLayout extends LinearLayout {

    /**
     * Create a new RowLayout.
     * The direction is automatically set to HORIZONTAL and cannot be changed.
     */
    public function new() {

        super();
        direction = HORIZONTAL;

    }

    /**
     * Override to prevent direction changes.
     * RowLayout is always horizontal.
     * @param direction Must be HORIZONTAL
     * @return Always returns HORIZONTAL
     * @throws String If attempting to set direction to VERTICAL
     */
    override function set_direction(direction:LayoutDirection):LayoutDirection {

        if (direction != HORIZONTAL) throw('Changing direction of an RowLayout is not allowed. Use a LinearLayout if you want to change direction at runtime.');
        return this.direction = HORIZONTAL;

    }

}

package ceramic;

/**
 * A layout that arranges its children horizontally in a single row.
 * This class is a `LinearLayout` subclass, restricted to its horizontal direction.
 */
class RowLayout extends LinearLayout {

    public function new() {

        super();
        direction = HORIZONTAL;

    }

    override function set_direction(direction:LayoutDirection):LayoutDirection {

        if (direction != HORIZONTAL) throw('Changing direction of an RowLayout is not allowed. Use a LinearLayout if you want to change direction at runtime.');
        return this.direction = HORIZONTAL;

    }

}

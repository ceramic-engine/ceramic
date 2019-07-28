package ceramic.ui;

/** A layout that arranges its children horizontally in a single column.
    This class is a `LinearLayout` subclass, restricted to its horizontal direction. */
class HorizontalLayout extends LinearLayout {

    public function new() {

        super();
        direction = HORIZONTAL;

    } //new

    override function set_direction(direction:LayoutDirection):LayoutDirection {

        throw('Changing direction of an HorizontalLayout is not allowed. Use a LinearLayout if you want to change direction at runtime.');
        return HORIZONTAL;

    } //set_direction

} //HorizontalLayout

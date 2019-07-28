package ceramic.ui;

/** A layout that arranges its children vertically in a single row.
    This class is a `LinearLayout` subclass, restricted to its vertical direction. */
class VerticalLayout extends LinearLayout {

    public function new() {

        super();
        direction = VERTICAL;

    } //new

    override function set_direction(direction:LayoutDirection):LayoutDirection {

        throw('Changing direction of a VerticalLayout is not allowed. Use a LinearLayout if you want to change direction at runtime.');
        return VERTICAL;

    } //set_direction

} //VerticalLayout

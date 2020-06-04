package ceramic;

/** A typed (mouse) button id */
@:enum abstract MouseButton(Int) from Int to Int {

    /** No mouse buttons */
    var NONE = 0;
    /** Left mouse button */
    var LEFT = 1;
    /** Middle mouse button */
    var MIDDLE = 2;
    /** Right mouse button */
    var RIGHT = 3;
    /** Extra button pressed (4) */
    var EXTRA1 = 4;
    /** Extra button pressed (5) */
    var EXTRA2 = 5;

}
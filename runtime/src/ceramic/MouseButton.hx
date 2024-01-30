package ceramic;

/**
 * A typed (mouse) button id
 */
enum abstract MouseButton(Int) from Int to Int {

    /**
     * No mouse buttons
     */
    var NONE = -1;
    /**
     * Left mouse button
     */
    var LEFT = 0;
    /**
     * Middle mouse button
     */
    var MIDDLE = 1;
    /**
     * Right mouse button
     */
    var RIGHT = 2;
    /**
     * Extra button pressed
     */
    var EXTRA1 = 3;
    /**
     * Extra button pressed
     */
    var EXTRA2 = 4;

}
package ceramic;

/**
 * What dragging a region of the window does, for windows that draw their own
 * title bar and borders (see `Screen.setWindowHitRegions`). The values match
 * SDL's `SDL_HitTestResult`.
 */
enum abstract WindowHitKind(Int) from Int to Int {

    /** Nothing special: the app receives the pointer events. */
    var NORMAL = 0;

    /** Dragging moves the window (a title bar). */
    var DRAGGABLE = 1;

    /** Dragging resizes the window from its top left corner. */
    var RESIZE_TOP_LEFT = 2;

    /** Dragging resizes the window from its top edge. */
    var RESIZE_TOP = 3;

    /** Dragging resizes the window from its top right corner. */
    var RESIZE_TOP_RIGHT = 4;

    /** Dragging resizes the window from its right edge. */
    var RESIZE_RIGHT = 5;

    /** Dragging resizes the window from its bottom right corner. */
    var RESIZE_BOTTOM_RIGHT = 6;

    /** Dragging resizes the window from its bottom edge. */
    var RESIZE_BOTTOM = 7;

    /** Dragging resizes the window from its bottom left corner. */
    var RESIZE_BOTTOM_LEFT = 8;

    /** Dragging resizes the window from its left edge. */
    var RESIZE_LEFT = 9;

}

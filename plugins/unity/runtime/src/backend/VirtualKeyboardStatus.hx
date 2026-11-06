package backend;

/**
 * Status of a `VirtualKeyboard` (Unity's `TouchScreenKeyboard.Status`, plus
 * `CLOSED`).
 */
enum abstract VirtualKeyboardStatus(Int) from Int to Int {

    /** Not open. */
    var CLOSED = -1;

    /** Open, the user is editing. */
    var VISIBLE = 0;

    /** Closed with its return key (single line) or its done button. */
    var DONE = 1;

    /** Closed by the user without validating (Android back button). */
    var CANCELED = 2;

    /** Closed because the app or the field lost the focus. */
    var LOST_FOCUS = 3;

}

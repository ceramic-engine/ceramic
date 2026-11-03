package ceramic;

/**
 * What the system knows a `MenuItem` for, so that it can give it its
 * standard behavior.
 *
 * On macOS, `CUT`, `COPY`, `PASTE` and `SELECT_ALL` items send the standard
 * `cut:`, `copy:`, `paste:` and `selectAll:` actions: while a system panel
 * (a file dialog for example) has the keyboard, its text fields get them;
 * otherwise the app gets `screen.menuAction` like for any item. `UNDO` and
 * `REDO` behave like regular items (there is no native text view to undo
 * in). `WINDOW` makes a top level submenu the Window menu, which the system
 * completes with the list of windows.
 *
 * @see Screen.setMenuBar
 */
enum abstract MenuItemRole(Int) from Int to Int {

    /** No special role. */
    var NONE = 0;

    /** The "cut" item. */
    var CUT = 1;

    /** The "copy" item. */
    var COPY = 2;

    /** The "paste" item. */
    var PASTE = 3;

    /** The "select all" item. */
    var SELECT_ALL = 4;

    /** The "undo" item. */
    var UNDO = 5;

    /** The "redo" item. */
    var REDO = 6;

    /** The Window menu (on a top level submenu). */
    var WINDOW = 7;

}

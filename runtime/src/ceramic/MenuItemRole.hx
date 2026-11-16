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
 * completes with the list of windows. `HIDE`, `HIDE_OTHERS` and `SHOW_ALL`
 * items send `hide:`, `hideOtherApplications:` and `unhideAllApplications:`
 * to the application object, and `MINIMIZE`, `ZOOM` and
 * `TOGGLE_FULL_SCREEN` items send `performMiniaturize:`, `performZoom:` and
 * `toggleFullScreen:` to the key window: the system does the work, as in
 * every macOS application.
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

    /**
     * The "hide" item of the application menu. On macOS the system hides
     * the application itself (the app gets no `screen.menuAction`);
     * elsewhere it is a regular item.
     */
    var HIDE = 8;

    /** The "hide others" item (see `HIDE`). */
    var HIDE_OTHERS = 9;

    /** The "show all" item (see `HIDE`). */
    var SHOW_ALL = 10;

    /**
     * The "minimize" item of the Window menu. On macOS the system minimizes
     * the key window itself (`performMiniaturize:`, the app gets no
     * `screen.menuAction`); elsewhere it is a regular item.
     */
    var MINIMIZE = 11;

    /** The "zoom" item of the Window menu (`performZoom:`, see `MINIMIZE`). */
    var ZOOM = 12;

    /**
     * The full screen item (`toggleFullScreen:`, see `MINIMIZE`). On macOS
     * the system titles it Enter Full Screen or Exit Full Screen.
     */
    var TOGGLE_FULL_SCREEN = 13;

}

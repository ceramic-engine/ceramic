package ceramic;

/**
 * The kind of a `MenuItem` of the application menu bar.
 *
 * @see Screen.setMenuBar
 */
enum abstract MenuItemKind(Int) from Int to Int {

    /** An item that triggers `screen.menuAction` when chosen. */
    var ACTION = 0;

    /** A separator line between items. */
    var SEPARATOR = 1;

    /** An item that opens a submenu (`items`). The top level of a menu bar only has submenus. */
    var SUBMENU = 2;

    /** A submenu filled by the system: the Services menu on macOS. */
    var SERVICES = 3;

}

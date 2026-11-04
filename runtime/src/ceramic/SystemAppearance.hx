package ceramic;

/**
 * The light or dark appearance chosen in the system settings, read with
 * `screen.systemAppearance` (and `screen.onSystemAppearanceChange`).
 *
 * @see Screen.systemAppearance
 */
enum abstract SystemAppearance(Int) from Int to Int {

    /** A light appearance (also what is reported when the system does not tell). */
    var LIGHT = 0;

    /** A dark appearance. */
    var DARK = 1;

    /** Whether this is the dark appearance. */
    public inline function isDark():Bool {
        return this == DARK;
    }

    public function toString():String {
        return this == DARK ? 'DARK' : 'LIGHT';
    }

}

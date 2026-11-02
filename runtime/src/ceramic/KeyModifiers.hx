package ceramic;

/**
 * Modifier keys held (or locks enabled) when a key event happened.
 *
 * Stored as bit flags in a single `Int`, so reading it never allocates.
 *
 * ```haxe
 * input.onKeyDown(this, key -> {
 *     if (key.modifiers.meta && key.scanCode == ScanCode.KEY_S) save();
 * });
 * ```
 *
 * Backend support:
 * - Clay native (SDL): all flags.
 * - Clay web: all flags (from the DOM `KeyboardEvent`).
 * - Unity: `SHIFT`, `CTRL`, `ALT` and `META`, no lock state.
 * - Headless: always `NONE`.
 *
 * @see Key
 * @see Input.modifiers
 */
enum abstract KeyModifiers(Int) from Int to Int {

    /** No modifier */
    var NONE = 0;

    /** Left or right shift key is down */
    var SHIFT = 1;

    /** Left or right control key is down */
    var CTRL = 2;

    /** Left or right alt (option on mac) key is down */
    var ALT = 4;

    /** Left or right meta key is down (command on mac, windows/super key elsewhere) */
    var META = 8;

    /** Caps lock is enabled */
    var CAPS_LOCK = 16;

    /** Num lock is enabled */
    var NUM_LOCK = 32;

    /** Left or right shift key is down */
    public var shift(get, never):Bool;
    inline function get_shift():Bool return (this & SHIFT) != 0;

    /** Left or right control key is down */
    public var ctrl(get, never):Bool;
    inline function get_ctrl():Bool return (this & CTRL) != 0;

    /** Left or right alt (option on mac) key is down */
    public var alt(get, never):Bool;
    inline function get_alt():Bool return (this & ALT) != 0;

    /** Left or right meta key is down (command on mac, windows/super key elsewhere) */
    public var meta(get, never):Bool;
    inline function get_meta():Bool return (this & META) != 0;

    /** Caps lock is enabled */
    public var capsLock(get, never):Bool;
    inline function get_capsLock():Bool return (this & CAPS_LOCK) != 0;

    /** Num lock is enabled */
    public var numLock(get, never):Bool;
    inline function get_numLock():Bool return (this & NUM_LOCK) != 0;

    /**
     * Returns `true` if all the given flags are set.
     */
    inline public function has(flags:KeyModifiers):Bool {
        return (this & (flags:Int)) == (flags:Int);
    }

    public function toString():String {

        if (this == NONE) return 'NONE';
        var parts:Array<String> = [];
        if ((this & SHIFT) != 0) parts.push('SHIFT');
        if ((this & CTRL) != 0) parts.push('CTRL');
        if ((this & ALT) != 0) parts.push('ALT');
        if ((this & META) != 0) parts.push('META');
        if ((this & CAPS_LOCK) != 0) parts.push('CAPS_LOCK');
        if ((this & NUM_LOCK) != 0) parts.push('NUM_LOCK');
        return parts.join('|');

    }

}

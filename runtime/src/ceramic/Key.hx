package ceramic;

/**
 * Represents a keyboard key press event with both key code and scan code information.
 * 
 * Key provides two ways to identify a keyboard key:
 * - KeyCode: Layout-dependent (changes with QWERTY, AZERTY, etc.)
 * - ScanCode: Layout-independent (physical key position)
 * 
 * This dual representation allows games to support both:
 * - Localized controls (using key codes that match printed key labels)
 * - Position-based controls (using scan codes for consistent physical positions)
 * 
 * @see Input
 * @see KeyCode
 * @see ScanCode
 */
@:structInit class Key {

    /**
     * Creates a new Key instance with the specified key code and scan code.
     * @param keyCode The layout-dependent key code
     * @param scanCode The layout-independent scan code
     * @param modifiers The modifier keys held when the event happened
     * @param keyChar The character this key produces, if any
     */
    public function new(keyCode:KeyCode, scanCode:ScanCode, modifiers:KeyModifiers = KeyModifiers.NONE, keyChar:String = null) {

        this.keyCode = keyCode;
        this.scanCode = scanCode;
        this.modifiers = modifiers;
        this.keyChar = keyChar;

    }

    /**
     * Key code (localized key) depends on keyboard mapping (QWERTY, AZERTY, ...)
     */
    public var keyCode(default, null):KeyCode;

    /**
     * Name associated to the key code (localized key)
     */
    public var keyCodeName(get, null):String;
    inline function get_keyCodeName():String {
        return KeyCode.name(keyCode);
    }
    
    /**
     * Scan code (US international key) doesn't depend on keyboard mapping (QWERTY, AZERTY, ...)
     */
    public var scanCode(default, null):ScanCode;

    /**
     * Name associated to the scan code (US international key)
     */
    public var scanCodeName(get, null):String;
    inline function get_scanCodeName():String {
        return ScanCode.name(scanCode);
    }

    /**
     * Modifier keys held (and lock states) when this key event happened.
     * Always `NONE` on backends that don't report modifiers.
     */
    public var modifiers(default, null):KeyModifiers;

    /**
     * The character this key produces with the current keyboard layout, taking
     * shift, caps lock and alt (option) into account, or `null` if the key doesn't
     * produce a character (arrows, function keys, enter, backspace...) or if
     * control or meta are held (except control + alt, used as AltGr on windows).
     * Dead keys and IME composition are not resolved here: use `Input.onTextCommit`
     * and `Input.onTextComposition` for actual text entry.
     *
     * Available on clay native (SDL) and clay web, `null` on Unity and headless.
     */
    public var keyChar(default, null):String;

    /**
     * Returns a string representation of this key.
     * Format: "Key(keyCode keyCodeName / scanCode scanCodeName)"
     * @return String representation of the key
     */
    function toString() {

        if (modifiers == KeyModifiers.NONE && keyChar == null)
            return 'Key(${(keyCode:Int)} $keyCodeName / ${(scanCode:Int)} $scanCodeName)';
        return 'Key(${(keyCode:Int)} $keyCodeName / ${(scanCode:Int)} $scanCodeName / ${modifiers.toString()}${keyChar != null ? ' ' + haxe.Json.stringify(keyChar) : ''})';

    }

}

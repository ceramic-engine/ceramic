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
     */
    public function new(keyCode:KeyCode, scanCode:ScanCode) {

        this.keyCode = keyCode;
        this.scanCode = scanCode;

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
     * Returns a string representation of this key.
     * Format: "Key(keyCode keyCodeName / scanCode scanCodeName)"
     * @return String representation of the key
     */
    function toString() {

        return 'Key(${(keyCode:Int)} $keyCodeName / ${(scanCode:Int)} $scanCodeName)';

    }

}

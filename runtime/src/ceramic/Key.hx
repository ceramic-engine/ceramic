package ceramic;

@:structInit class Key {

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

    function toString() {

        return 'Key(${(keyCode:Int)} $keyCodeName / ${(scanCode:Int)} $scanCodeName)';

    }

}

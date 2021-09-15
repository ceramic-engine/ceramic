package ceramic;

@:allow(ceramic.App)
class Input extends Entity {

    /**
     * Internal value to store gamepad state
     */
    inline static final GAMEPAD_STORAGE_SIZE:Int = 32;

    /**
     * @event keyDown
     * Triggered when a key from the keyboard is being pressed.
     * @param key The key being pressed
     */
    @event function keyDown(key:Key);
    /**
     * @event keyUp
     * Triggered when a key from the keyboard is being released.
     * @param key The key being released
     */
    @event function keyUp(key:Key);

    @event function gamepadAxis(gamepadId:Int, axis:GamepadAxis, value:Float);
    @event function gamepadDown(gamepadId:Int, button:GamepadButton);
    @event function gamepadUp(gamepadId:Int, button:GamepadButton);
    @event function gamepadEnable(gamepadId:Int, name:String);
    @event function gamepadDisable(gamepadId:Int);

    var pressedScanCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedKeyCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedGamepadButtons:IntIntMap = new IntIntMap(16, 0.5, false);

    var gamepadAxisValues:IntFloatMap = new IntFloatMap(16, 0.5, false);

    public var activeGamepads:ReadOnlyArray<Int> = [];

    private function new() {

        super();

    }

    #if plugin_elements

    inline function canEmitKeyDown(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    inline function canEmitKeyUp(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    inline function canEmitGamepadDown(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    inline function canEmitGamepadUp(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    #end

/// Keyboard

    function willEmitKeyDown(key:Key):Void {

        var prevScan = pressedScanCodes.get(key.scanCode);
        var prevKey = pressedKeyCodes.get(key.keyCode);

        if (prevScan == -1) {
            prevScan = 0;
            prevKey = 0;
        }

        pressedScanCodes.set(key.scanCode, prevScan + 1);
        pressedKeyCodes.set(key.keyCode, prevKey + 1);

        if (prevScan == 0) {
            // Used to differenciate "pressed" and "just pressed" states
            ceramic.App.app.beginUpdateCallbacks.push(function() {
                if (pressedScanCodes.get(key.scanCode) == 1) {
                    pressedScanCodes.set(key.scanCode, 2);
                }
                if (pressedKeyCodes.get(key.keyCode) == 1) {
                    pressedKeyCodes.set(key.keyCode, 2);
                }
            });
        }

    }

    function willEmitKeyUp(key:Key):Void {

        pressedScanCodes.set(key.scanCode, -1);
        pressedKeyCodes.set(key.keyCode, -1);
        // Used to differenciate "released" and "just released" states
        ceramic.App.app.beginUpdateCallbacks.push(function() {
            if (pressedScanCodes.get(key.scanCode) == -1) {
                pressedScanCodes.set(key.scanCode, 0);
            }
            if (pressedKeyCodes.get(key.keyCode) == -1) {
                pressedKeyCodes.set(key.keyCode, 0);
            }
        });

    }

    public function keyPressed(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) > 0;

    }

    public function keyJustPressed(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) == 1;

    }

    public function keyJustReleased(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) == -1;

    }

    public function scanPressed(scanCode:ScanCode):Bool {

        return pressedScanCodes.get(scanCode) > 0;

    }

    public function scanJustPressed(scanCode:ScanCode):Bool {

        return pressedScanCodes.get(scanCode) == 1;

    }

    public function scanJustReleased(scanCode:ScanCode):Bool {

        return pressedScanCodes.get(scanCode) == -1;

    }

/// Gamepad

    function willEmitGamepadEnable(gamepadId:Int, name:String):Void {

        // Reset gamepad state
        var key = gamepadId * GAMEPAD_STORAGE_SIZE;
        for (i in 0...GAMEPAD_STORAGE_SIZE) {
            var k = key + i;
            pressedGamepadButtons.set(k, 0);
            gamepadAxisValues.set(k, 0.0);
        }

        // Add gamepad to active list
        if (activeGamepads.indexOf(gamepadId) == -1) {
            activeGamepads.original.push(gamepadId);
        }

    }

    function willEmitGamepadDisable(gamepadId:Int):Void {

        // Remove gamepad from active list
        var index = activeGamepads.indexOf(gamepadId);
        if (index != -1) {
            activeGamepads.original.splice(index, 1);
        }

    }

    function willEmitGamepadDown(gamepadId:Int, button:GamepadButton):Void {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        var prevValue = pressedGamepadButtons.get(key);

        if (prevValue == -1) {
            prevValue = 0;
        }

        pressedGamepadButtons.set(key, prevValue + 1);

        if (prevValue == 0) {
            // Used to differenciate "pressed" and "just pressed" states
            ceramic.App.app.beginUpdateCallbacks.push(function() {
                if (pressedGamepadButtons.get(key) == 1) {
                    pressedGamepadButtons.set(key, 2);
                }
            });
        }

    }

    function willEmitGamepadUp(gamepadId:Int, button:GamepadButton):Void {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        pressedGamepadButtons.set(key, -1);
        // Used to differenciate "released" and "just released" states
        ceramic.App.app.beginUpdateCallbacks.push(function() {
            if (pressedGamepadButtons.get(key) == -1) {
                pressedGamepadButtons.set(key, 0);
            }
        });

    }

    public function gamepadPressed(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) > 0;

    }

    public function gamepadJustPressed(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) == 1;

    }

    public function gamepadJustReleased(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) == -1;

    }

    inline function willEmitGamepadAxis(gamepadId:Int, axis:GamepadAxis, value:Float):Void {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + axis;
        gamepadAxisValues.set(key, value);

    }

    public function gamepadAxisValue(gamepadId:Int, axis:GamepadAxis):Float {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + axis;
        return gamepadAxisValues.get(key);

    }

}
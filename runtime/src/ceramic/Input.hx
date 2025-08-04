package ceramic;

/**
 * Manages all input handling for keyboard and gamepad devices.
 * 
 * The Input system provides:
 * - Keyboard input detection (key press, release, and hold states)
 * - Gamepad support (buttons, analog axes, gyroscope)
 * - Input state queries (pressed, just pressed, just released)
 * - Gamepad vibration/rumble control
 * - Integration with UI elements to prevent input conflicts
 * 
 * The system tracks three states for inputs:
 * - Just pressed: True only on the frame the input was pressed
 * - Pressed: True while the input is held down
 * - Just released: True only on the frame the input was released
 * 
 * @see Key
 * @see KeyCode
 * @see ScanCode
 * @see GamepadButton
 * @see GamepadAxis
 */
@:allow(ceramic.App)
class Input extends Entity {

    /**
     * Internal value to store gamepad state
     */
    inline static final GAMEPAD_STORAGE_SIZE:Int = 32;

    /**
     * Triggered when a key from the keyboard is being pressed.
     * This event fires repeatedly while a key is held down.
     * @param key The key being pressed, containing both keyCode and scanCode
     * @event keyDown
     */
    @event function keyDown(key:Key);
    
    /**
     * Triggered when a key from the keyboard is being released.
     * @param key The key being released, containing both keyCode and scanCode
     * @event keyUp
     */
    @event function keyUp(key:Key);

    /**
     * Triggered when a gamepad analog axis value changes.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param axis The axis that changed (e.g., LEFT_X, RIGHT_TRIGGER)
     * @param value The new axis value (-1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers)
     * @event gamepadAxis
     */
    @event function gamepadAxis(gamepadId:Int, axis:GamepadAxis, value:Float);
    
    /**
     * Triggered when a gamepad button is pressed.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param button The button being pressed
     * @event gamepadDown
     */
    @event function gamepadDown(gamepadId:Int, button:GamepadButton);
    
    /**
     * Triggered when a gamepad button is released.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param button The button being released
     * @event gamepadUp
     */
    @event function gamepadUp(gamepadId:Int, button:GamepadButton);
    
    /**
     * Triggered when gamepad gyroscope data is received.
     * @param gamepadId The ID of the gamepad (0-based index)
     * @param dx Angular velocity around X axis (radians/second)
     * @param dy Angular velocity around Y axis (radians/second)
     * @param dz Angular velocity around Z axis (radians/second)
     * @event gamepadGyro
     */
    @event function gamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float);
    
    /**
     * Triggered when a gamepad is connected and enabled.
     * @param gamepadId The ID assigned to the gamepad (0-based index)
     * @param name The name/description of the gamepad device
     * @event gamepadEnable
     */
    @event function gamepadEnable(gamepadId:Int, name:String);
    
    /**
     * Triggered when a gamepad is disconnected or disabled.
     * @param gamepadId The ID of the gamepad being disabled
     * @event gamepadDisable
     */
    @event function gamepadDisable(gamepadId:Int);

    var pressedScanCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedKeyCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedGamepadButtons:IntIntMap = new IntIntMap(16, 0.5, false);

    var gamepadAxisValues:IntFloatMap = new IntFloatMap(16, 0.5, false);

    var gamepadGyroDeltas:IntMap<Array<Float>> = new IntMap();

    var gamepadGyroKeys:Array<Int> = [];

    var gamepadNames:IntMap<String> = new IntMap();

    /**
     * List of currently connected gamepad IDs.
     * Updated automatically when gamepads are connected or disconnected.
     */
    public var activeGamepads:ReadOnlyArray<Int> = [];

    /**
     * Private constructor. Input is managed as a singleton through App.
     */
    private function new() {

        super();

    }

    function resetDeltas() {

        while (gamepadGyroKeys.length > 0) {
            var key = gamepadGyroKeys.pop();
            var deltas = gamepadGyroDeltas.get(key);
            if (deltas != null) {
                deltas[0] = 0;
                deltas[1] = 0;
                deltas[2] = 0;
            }
        }

    }

    #if plugin_elements

    @:plugin('elements')
    static function _elementsImFocused():Bool {

        var context = elements.Context.context;
        return (context != null && context.focusedWindow != null);

    }

    @:plugin('elements')
    inline function canEmitKeyDown(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitKeyUp(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
    inline function canEmitGamepadDown(owner:Entity):Bool {

        return elements.Im.filterEventOwner(owner);

    }

    @:plugin('elements')
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

        var prevScan = pressedScanCodes.get(key.scanCode);

        if (prevScan != 0) {
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

    }

    /**
     * Checks if a key is currently pressed (held down).
     * Returns true for every frame while the key is held.
     * @param keyCode The key code to check
     * @return True if the key is currently pressed
     */
    public extern inline overload function keyPressed(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyPressed(keyCode);

    }

    /**
     * Checks if a key was just pressed this frame.
     * Returns true only on the frame the key was initially pressed.
     * @param keyCode The key code to check
     * @return True if the key was just pressed this frame
     */
    public extern inline overload function keyJustPressed(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyJustPressed(keyCode);

    }

    /**
     * Checks if a key was just released this frame.
     * Returns true only on the frame the key was released.
     * @param keyCode The key code to check
     * @return True if the key was just released this frame
     */
    public extern inline overload function keyJustReleased(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyJustReleased(keyCode);

    }

    /**
     * Checks if a key is currently pressed using scan code.
     * Scan codes represent physical key positions and are layout-independent.
     * @param scanCode The scan code to check
     * @return True if the key is currently pressed
     */
    public extern inline overload function scanPressed(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanPressed(scanCode);

    }

    /**
     * Checks if a key was just pressed this frame using scan code.
     * @param scanCode The scan code to check
     * @return True if the key was just pressed this frame
     */
    public extern inline overload function scanJustPressed(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanJustPressed(scanCode);

    }

    /**
     * Checks if a key was just released this frame using scan code.
     * @param scanCode The scan code to check
     * @return True if the key was just released this frame
     */
    public extern inline overload function scanJustReleased(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanJustReleased(scanCode);

    }

    /**
     * Checks if a key is currently pressed, with UI element filtering.
     * Allows input to pass through when the owner entity has UI focus.
     * @param keyCode The key code to check
     * @param owner The entity that wants to receive input (used for UI focus filtering)
     * @return True if the key is currently pressed and the owner can receive input
     */
    public extern inline overload function keyPressed(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyPressed(keyCode);

    }

    /**
     * Checks if a key was just pressed this frame, with UI element filtering.
     * @param keyCode The key code to check
     * @param owner The entity that wants to receive input
     * @return True if the key was just pressed and the owner can receive input
     */
    public extern inline overload function keyJustPressed(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyJustPressed(keyCode);

    }

    /**
     * Checks if a key was just released this frame, with UI element filtering.
     * @param keyCode The key code to check
     * @param owner The entity that wants to receive input
     * @return True if the key was just released and the owner can receive input
     */
    public extern inline overload function keyJustReleased(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyJustReleased(keyCode);

    }

    /**
     * Checks if a key is currently pressed using scan code, with UI element filtering.
     * @param scanCode The scan code to check
     * @param owner The entity that wants to receive input
     * @return True if the key is currently pressed and the owner can receive input
     */
    public extern inline overload function scanPressed(scanCode:ScanCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _scanPressed(scanCode);

    }

    /**
     * Checks if a key was just pressed this frame using scan code, with UI element filtering.
     * @param scanCode The scan code to check
     * @param owner The entity that wants to receive input
     * @return True if the key was just pressed and the owner can receive input
     */
    public extern inline overload function scanJustPressed(scanCode:ScanCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _scanJustPressed(scanCode);

    }

    /**
     * Checks if a key was just released this frame using scan code, with UI element filtering.
     * @param scanCode The scan code to check
     * @param owner The entity that wants to receive input
     * @return True if the key was just released and the owner can receive input
     */
    public extern inline overload function scanJustReleased(scanCode:ScanCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _scanJustReleased(scanCode);

    }

    function _keyPressed(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) > 0;

    }

    function _keyJustPressed(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) == 1;

    }

    function _keyJustReleased(keyCode:KeyCode):Bool {

        return pressedKeyCodes.get(keyCode) == -1;

    }

    function _scanPressed(scanCode:ScanCode):Bool {

        return pressedScanCodes.get(scanCode) > 0;

    }

    function _scanJustPressed(scanCode:ScanCode):Bool {

        return pressedScanCodes.get(scanCode) == 1;

    }

    function _scanJustReleased(scanCode:ScanCode):Bool {

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

        // Keep gamepad name
        gamepadNames.set(gamepadId, name);

    }

    function willEmitGamepadDisable(gamepadId:Int):Void {

        // Trigger buttons release and axis reset if needed
        var key = gamepadId * GAMEPAD_STORAGE_SIZE;
        for (i in 0...GAMEPAD_STORAGE_SIZE) {
            var k = key + i;
            var pressed = pressedGamepadButtons.get(k);
            if (pressed > 0) {
                emitGamepadUp(gamepadId, i);
            }
            var axis = gamepadAxisValues.get(k);
            if (axis != 0) {
                emitGamepadAxis(gamepadId, i, axis);
            }
        }

        // Remove gamepad from active list
        var index = activeGamepads.indexOf(gamepadId);
        if (index != -1) {
            activeGamepads.original.splice(index, 1);
        }

        // Remove gamepad name
        gamepadNames.remove(gamepadId);

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

    function willEmitGamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float):Void {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas == null) {
            deltas = [0, 0, 0];
            gamepadGyroDeltas.set(key, deltas);
        }
        if (gamepadGyroKeys.indexOf(key) == -1) {
            gamepadGyroKeys.push(key);
        }
        deltas[0] += dx;
        deltas[1] += dy;
        deltas[2] += dz;

    }

    /**
     * Checks if a gamepad button is currently pressed.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @return True if the button is currently pressed
     */
    public extern inline overload function gamepadPressed(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadPressed(gamepadId, button);

    }

    /**
     * Checks if a gamepad button was just pressed this frame.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @return True if the button was just pressed this frame
     */
    public extern inline overload function gamepadJustPressed(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadJustPressed(gamepadId, button);

    }

    /**
     * Checks if a gamepad button was just released this frame.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @return True if the button was just released this frame
     */
    public extern inline overload function gamepadJustReleased(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadJustReleased(gamepadId, button);

    }

    /**
     * Checks if a gamepad button is currently pressed, with UI element filtering.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @param owner The entity that wants to receive input
     * @return True if the button is pressed and the owner can receive input
     */
    public extern inline overload function gamepadPressed(gamepadId:Int, button:GamepadButton, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _gamepadPressed(gamepadId, button);

    }

    /**
     * Checks if a gamepad button was just pressed this frame, with UI element filtering.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @param owner The entity that wants to receive input
     * @return True if the button was just pressed and the owner can receive input
     */
    public extern inline overload function gamepadJustPressed(gamepadId:Int, button:GamepadButton, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _gamepadJustPressed(gamepadId, button);

    }

    /**
     * Checks if a gamepad button was just released this frame, with UI element filtering.
     * @param gamepadId The ID of the gamepad to check
     * @param button The button to check
     * @param owner The entity that wants to receive input
     * @return True if the button was just released and the owner can receive input
     */
    public extern inline overload function gamepadJustReleased(gamepadId:Int, button:GamepadButton, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _gamepadJustReleased(gamepadId, button);

    }

    function _gamepadPressed(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) > 0;

    }

    function _gamepadJustPressed(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) == 1;

    }

    function _gamepadJustReleased(gamepadId:Int, button:GamepadButton):Bool {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + button;
        return pressedGamepadButtons.get(key) == -1;

    }

    inline function willEmitGamepadAxis(gamepadId:Int, axis:GamepadAxis, value:Float):Void {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + axis;
        gamepadAxisValues.set(key, value);

    }

    /**
     * Gets the current value of a gamepad analog axis.
     * @param gamepadId The ID of the gamepad to check
     * @param axis The axis to check (e.g., LEFT_X, RIGHT_TRIGGER)
     * @return The axis value (-1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers)
     */
    public function gamepadAxisValue(gamepadId:Int, axis:GamepadAxis):Float {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + axis;
        return gamepadAxisValues.get(key);

    }

    /**
     * Gets the accumulated gyroscope delta for the X axis since last frame.
     * @param gamepadId The ID of the gamepad
     * @return Angular velocity around X axis (radians/second)
     */
    public function gamepadGyroDeltaX(gamepadId:Int):Float {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas != null) {
            return deltas[0];
        }
        return 0;

    }

    /**
     * Gets the accumulated gyroscope delta for the Y axis since last frame.
     * @param gamepadId The ID of the gamepad
     * @return Angular velocity around Y axis (radians/second)
     */
    public function gamepadGyroDeltaY(gamepadId:Int):Float {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas != null) {
            return deltas[1];
        }
        return 0;

    }

    /**
     * Gets the accumulated gyroscope delta for the Z axis since last frame.
     * @param gamepadId The ID of the gamepad
     * @return Angular velocity around Z axis (radians/second)
     */
    public function gamepadGyroDeltaZ(gamepadId:Int):Float {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas != null) {
            return deltas[2];
        }
        return 0;

    }

    /**
     * Starts a controller rumble.
     * @param gamepadId The id of the gamepad getting rumble
     * @param duration The duration, in seconds
     * @param lowFrequency Low frequency: value between 0 and 1
     * @param highFrequency High frequency: value between 0 and 1
     */
    public function startGamepadRumble(gamepadId:Int, duration:Float, lowFrequency:Float, highFrequency:Float) {

        ceramic.App.app.backend.input.startGamepadRumble(gamepadId, lowFrequency, highFrequency, duration);

    }

    /**
     * Stops any active rumble on the specified gamepad.
     * @param gamepadId The ID of the gamepad
     */
    public function stopGamepadRumble(gamepadId:Int) {

        ceramic.App.app.backend.input.stopGamepadRumble(gamepadId);

    }

    /**
     * Gets the name/description of a connected gamepad.
     * @param gamepadId The ID of the gamepad
     * @return The gamepad name, or null if not connected
     */
    public function gamepadName(gamepadId:Int):String {

        return gamepadNames.get(gamepadId);

    }

}
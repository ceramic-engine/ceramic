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
    @event function gamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float);
    @event function gamepadEnable(gamepadId:Int, name:String);
    @event function gamepadDisable(gamepadId:Int);

    var pressedScanCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedKeyCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedGamepadButtons:IntIntMap = new IntIntMap(16, 0.5, false);

    var gamepadAxisValues:IntFloatMap = new IntFloatMap(16, 0.5, false);

    var gamepadGyroDeltas:IntMap<Array<Float>> = new IntMap();

    var gamepadGyroKeys:Array<Int> = [];

    var gamepadNames:IntMap<String> = new IntMap();

    public var activeGamepads:ReadOnlyArray<Int> = [];

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

    static function _elementsImFocused():Bool {

        var context = elements.Context.context;
        return (context != null && context.focusedWindow != null);

    }

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

    public extern inline overload function keyPressed(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyPressed(keyCode);

    }

    public extern inline overload function keyJustPressed(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyJustPressed(keyCode);

    }

    public extern inline overload function keyJustReleased(keyCode:KeyCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _keyJustReleased(keyCode);

    }

    public extern inline overload function scanPressed(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanPressed(scanCode);

    }

    public extern inline overload function scanJustPressed(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanJustPressed(scanCode);

    }

    public extern inline overload function scanJustReleased(scanCode:ScanCode):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _scanJustReleased(scanCode);

    }

    public extern inline overload function keyPressed(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyPressed(keyCode);

    }

    public extern inline overload function keyJustPressed(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyJustPressed(keyCode);

    }

    public extern inline overload function keyJustReleased(keyCode:KeyCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _keyJustReleased(keyCode);

    }

    public extern inline overload function scanPressed(scanCode:ScanCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _scanPressed(scanCode);

    }

    public extern inline overload function scanJustPressed(scanCode:ScanCode, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _scanJustPressed(scanCode);

    }

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

    public extern inline overload function gamepadPressed(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadPressed(gamepadId, button);

    }

    public extern inline overload function gamepadJustPressed(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadJustPressed(gamepadId, button);

    }

    public extern inline overload function gamepadJustReleased(gamepadId:Int, button:GamepadButton):Bool {

        return #if plugin_elements !_elementsImFocused() && #end _gamepadJustReleased(gamepadId, button);

    }

    public extern inline overload function gamepadPressed(gamepadId:Int, button:GamepadButton, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _gamepadPressed(gamepadId, button);

    }

    public extern inline overload function gamepadJustPressed(gamepadId:Int, button:GamepadButton, owner:Entity):Bool {

        return #if plugin_elements (!_elementsImFocused() || elements.Im.filterEventOwner(owner)) && #end _gamepadJustPressed(gamepadId, button);

    }

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

    public function gamepadAxisValue(gamepadId:Int, axis:GamepadAxis):Float {

        var key = gamepadId * GAMEPAD_STORAGE_SIZE + axis;
        return gamepadAxisValues.get(key);

    }

    public function gamepadGyroDeltaX(gamepadId:Int):Float {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas != null) {
            return deltas[0];
        }
        return 0;

    }

    public function gamepadGyroDeltaY(gamepadId:Int):Float {

        var key = gamepadId;
        var deltas = gamepadGyroDeltas.get(key);
        if (deltas != null) {
            return deltas[1];
        }
        return 0;

    }

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

    public function stopGamepadRumble(gamepadId:Int) {

        ceramic.App.app.backend.input.stopGamepadRumble(gamepadId);

    }

    public function gamepadName(gamepadId:Int):String {

        return gamepadNames.get(gamepadId);

    }

}
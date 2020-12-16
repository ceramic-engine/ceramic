package ceramic;

@:allow(ceramic.App)
class Input extends Entity {

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

    @event function controllerAxis(controllerId:Int, axisId:Int, value:Float);
    @event function controllerDown(controllerId:Int, buttonId:Int);
    @event function controllerUp(controllerId:Int, buttonId:Int);
    @event function controllerEnable(controllerId:Int, name:String);
    @event function controllerDisable(controllerId:Int);

    var pressedScanCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedKeyCodes:IntIntMap = new IntIntMap(16, 0.5, false);

    var pressedControllerButtons:IntIntMap = new IntIntMap(16, 0.5, false);

    public function new() {

        super();

    }

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

/// Controller

    function willEmitControllerDown(controllerId:Int, buttonId:Int):Void {

        var key = controllerId * 1024 + buttonId;
        var prevValue = pressedControllerButtons.get(key);

        if (prevValue == -1) {
            prevValue = 0;
        }

        pressedControllerButtons.set(key, prevValue + 1);

        if (prevValue == 0) {
            // Used to differenciate "pressed" and "just pressed" states
            ceramic.App.app.beginUpdateCallbacks.push(function() {
                if (pressedControllerButtons.get(key) == 1) {
                    pressedControllerButtons.set(key, 2);
                }
            });
        }

    }

    function willEmitControllerUp(controllerId:Int, buttonId:Int):Void {

        var key = controllerId * 1024 + buttonId;
        pressedControllerButtons.set(key, -1);
        // Used to differenciate "released" and "just released" states
        ceramic.App.app.beginUpdateCallbacks.push(function() {
            if (pressedControllerButtons.get(key) == -1) {
                pressedControllerButtons.set(key, 0);
            }
        });

    }

    public function controllerPressed(controllerId:Int, buttonId:Int):Bool {

        var key = controllerId * 1024 + buttonId;
        return pressedControllerButtons.get(key) > 0;

    }

    public function controllerJustPressed(controllerId:Int, buttonId:Int):Bool {

        var key = controllerId * 1024 + buttonId;
        return pressedControllerButtons.get(key) == 1;

    }

    public function controllerJustReleased(controllerId:Int, buttonId:Int):Bool {

        var key = controllerId * 1024 + buttonId;
        return pressedControllerButtons.get(key) == -1;

    }

}
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

    public function new() {

        super();

    }

/// Keyboard

    function willEmitKeyDown(key:Key):Void {

        var prevScan = pressedScanCodes.get(key.scanCode);
        var prevKey = pressedKeyCodes.get(key.keyCode);

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

        pressedScanCodes.set(key.scanCode, 0);
        pressedKeyCodes.set(key.keyCode, 0);

    }

    public function keyCodePressed(keyCode:Int):Bool {

        return pressedKeyCodes.get(keyCode) > 0;

    }

    public function keyCodeJustPressed(keyCode:Int):Bool {

        return pressedKeyCodes.get(keyCode) == 1;

    }

    public function scanCodePressed(scanCode:Int):Bool {

        return pressedScanCodes.get(scanCode) > 0;

    }

    public function scanCodeJustPressed(scanCode:Int):Bool {

        return pressedScanCodes.get(scanCode) == 1;

    }

    public function keyPressed(key:Key):Bool {

        return pressedScanCodes.get(key.scanCode) > 0;

    }

    public function keyJustPressed(key:Key):Bool {

        return pressedScanCodes.get(key.scanCode) == 1;

    }

}
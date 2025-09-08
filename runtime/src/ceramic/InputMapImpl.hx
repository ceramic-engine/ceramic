package ceramic;

import ceramic.ReadOnlyArray;
import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * Implementation class for the InputMap system.
 * 
 * This class provides the actual functionality for mapping physical inputs
 * (keyboard, mouse, gamepad) to logical game actions. It supports complex
 * input scenarios including:
 * 
 * - Multiple inputs bound to a single action
 * - Digital-to-analog conversion (e.g., WASD to movement axis)
 * - Analog-to-digital conversion (e.g., trigger press threshold)
 * - Input state tracking (pressed, just pressed, just released)
 * - Gamepad-specific targeting
 * - UI focus integration
 * 
 * The implementation uses an efficient index-based system to track bindings
 * and input states, minimizing overhead during runtime input processing.
 * 
 * @param T The type representing game actions (typically an enum)
 * @see InputMap
 */
class InputMapImpl<T> extends InputMapBase {

    /**
     * Triggered when a mapped action is pressed (key down, button pressed, etc.).
     * @param key The action that was pressed
     * @event keyDown
     */
    @event function keyDown(key:T);

    /**
     * Triggered when a mapped action is released (key up, button released, etc.).
     * @param key The action that was released
     * @event keyUp
     */
    @event function keyUp(key:T);

    /**
     * Triggered when an analog axis value changes for a mapped action.
     * @param key The action associated with the axis
     * @param value The new axis value (typically -1.0 to 1.0)
     * @event axis
     */
    @event function axis(key:T, value:Float);

    /**
     * Target events of a specific gamepad by setting its gamepad id.
     * If kept to default (`-1`), events from any gamepad will be handled.
     * Useful for multiplayer games where each player has their own controller.
     */
    public var gamepadId:Int = -1;

    /**
     * If set to `true`, when binding a new input, the system will check if
     * the input was just pressed this frame and set the initial state accordingly.
     * This prevents immediate triggering of "just pressed" events when binding
     * an input that's already being held down.
     */
    public var checkJustPressedAtBind:Bool = false;

    /**
     * Set to `false` to disable this input map entirely.
     * When disabled, all input queries will return false/0.0 and no events will be triggered.
     * Useful for pausing input handling or switching between different input schemes.
     */
    public var enabled:Bool = true;

    var nextIndex:Int = 0;

    var keyToIndex:Map<String,Int> = null;

    var indexToKey:Array<T> = null;

    var pressedKeys:Array<Int> = [];

    var axisValues:Array<Float> = [];

    static final EMPTY_ARRAY:ReadOnlyArray<Int> = [];

    /**
     * A way to know from which the pressed key comes from
     */
    var pressedKeyKinds:Array<InputMapKeyKind> = [];

    var _boundKeyCodes:IntMap<Array<Int>> = new IntMap();
    var _indexedKeyCodes:Array<Array<KeyCode>> = [];

    var _boundKeyCodesToAxes:IntMap<Array<InputMapConvertToAxis>> = new IntMap();
    var _indexedKeyCodesToAxes:Array<Array<KeyCode>> = [];

    var _boundScanCodes:IntMap<Array<Int>> = new IntMap();
    var _indexedScanCodes:Array<Array<ScanCode>> = [];

    var _boundScanCodesToAxes:IntMap<Array<InputMapConvertToAxis>> = new IntMap();
    var _indexedScanCodesToAxes:Array<Array<ScanCode>> = [];

    var _boundMouseButtons:IntMap<Array<Int>> = new IntMap();
    var _indexedMouseButtons:Array<Array<Int>> = [];

    var _boundGamepadButtons:IntMap<Array<Int>> = new IntMap();
    var _indexedGamepadButtons:Array<Array<GamepadButton>> = [];

    var _boundGamepadButtonsToAxes:IntMap<Array<InputMapConvertToAxis>> = new IntMap();
    var _indexedGamepadButtonsToAxes:Array<Array<GamepadButton>> = [];

    var _boundGamepadAxes:IntMap<Array<Int>> = new IntMap();
    var _indexedGamepadAxis:Array<Array<GamepadAxis>> = [];

    var _boundGamepadAxesToButtons:IntMap<Array<Int>> = new IntMap();
    var _indexedGamepadAxesToButtons:Array<Array<GamepadAxis>> = [];

    var convertToAxis:Array<Array<InputMapConvertToAxis>> = [];

    public function new() {

        super();

        input.onKeyDown(this, _handleKeyDown);
        input.onKeyUp(this, _handleKeyUp);

        screen.onMouseDown(this, _handleMouseDown);
        screen.onMouseUp(this, _handleMouseUp);

        input.onGamepadDown(this, _handleGamepadDown);
        input.onGamepadUp(this, _handleGamepadUp);
        input.onGamepadAxis(this, _handleGamepadAxis);

    }

    function keyToString(key:T):String {

        var name:Dynamic = key;
        return name.toString();

    }

    function keyForIndex(index:Int):T {

        return indexToKey != null ? indexToKey[index] : InputMapBase.NO_KEY;

    }

    function indexOfKey(key:T):Int {

        if (keyToIndex == null) {
            keyToIndex = new Map();
            indexToKey = [];
        }
        var keyStr = keyToString(key);
        if (keyToIndex.exists(keyStr)) {
            return keyToIndex.get(keyStr);
        }
        else {
            var index = nextIndex++;
            indexToKey[index] = key;
            keyToIndex.set(keyStr, index);
            return index;
        }

    }

/// Internal event handling

    function _handleKeyDown(key:Key) {

        var toEmit:Array<Int> = null;

        // Key code
        var keyCode = key.keyCode;
        var boundList = _boundKeyCodes.get(keyCode);
        if (boundList != null) {
            for (i in 0...boundList.length) {
                var index = boundList.unsafeGet(i);
                _setPressedKeyKind(index, KEY_CODE);
                var prevValue = _pressedKey(index);
                if (prevValue == -1) {
                    prevValue = 0;
                }
                if (prevValue != 1)
                    pressedKeys[index] = prevValue + 1;
                if (prevValue <= 0) {
                    if (toEmit == null)
                        toEmit = [index];
                    else if (toEmit.indexOf(index) == -1)
                        toEmit.push(index);
                }
                if (prevValue == 0) {
                    _scheduleRemoveJustPressed(index);
                }
            }
        }

        // Key code axis
        var boundListToAxis = _boundKeyCodesToAxes.get(keyCode);
        if (boundListToAxis != null) {
            _handleAxisConvertersDown(boundListToAxis);
        }

        // Scan code
        var scanCode = key.scanCode;
        boundList = _boundScanCodes.get(scanCode);
        if (boundList != null) {
            for (i in 0...boundList.length) {
                var index = boundList.unsafeGet(i);
                _setPressedKeyKind(index, SCAN_CODE);
                var prevValue = _pressedKey(index);
                if (prevValue == -1) {
                    prevValue = 0;
                }
                if (prevValue != 1)
                    pressedKeys[index] = prevValue + 1;
                if (prevValue <= 0) {
                    if (toEmit == null)
                        toEmit = [index];
                    else if (toEmit.indexOf(index) == -1)
                        toEmit.push(index);
                }
                if (prevValue == 0) {
                    _scheduleRemoveJustPressed(index);
                }
            }
        }

        // Scan code axis
        boundListToAxis = _boundScanCodesToAxes.get(scanCode);
        if (boundListToAxis != null) {
            _handleAxisConvertersDown(boundListToAxis);
        }

        if (toEmit != null) {
            for (i in 0...toEmit.length) {
                var index = toEmit.unsafeGet(i);
                var k = keyForIndex(index);
                _handleConvertedToAxisDown(index);
                if (enabled)
                    emitKeyDown(k);
            }
        }

    }

    function _handleKeyUp(key:Key) {

        var toEmit:Array<Int> = null;

        // Key code
        var keyCode = key.keyCode;
        var boundList = _boundKeyCodes.get(keyCode);
        if (boundList != null) {
            for (i in 0...boundList.length) {
                var index = boundList.unsafeGet(i);
                var prevValue = _pressedKey(index);
                if (prevValue > 0) {
                    pressedKeys[index] = -1;
                    if (toEmit == null)
                        toEmit = [index];
                    else if (toEmit.indexOf(index) == -1)
                        toEmit.push(index);
                }
                if (prevValue != 0) {
                    _scheduleRemoveJustReleased(index);
                }
            }
        }

        // Key code axis
        var boundListToAxis = _boundKeyCodesToAxes.get(keyCode);
        if (boundListToAxis != null) {
            _handleAxisConvertersUp(boundListToAxis);
        }

        // Scan code
        var scanCode = key.scanCode;
        boundList = _boundScanCodes.get(scanCode);
        if (boundList != null) {
            for (i in 0...boundList.length) {
                var index = boundList.unsafeGet(i);
                var prevValue = _pressedKey(index);
                if (prevValue > 0) {
                    pressedKeys[index] = -1;
                    if (toEmit == null)
                        toEmit = [index];
                    else if (toEmit.indexOf(index) == -1)
                        toEmit.push(index);
                }
                if (prevValue != 0) {
                    _scheduleRemoveJustReleased(index);
                }
            }
        }

        // Scan code axis
        boundListToAxis = _boundScanCodesToAxes.get(scanCode);
        if (boundListToAxis != null) {
            _handleAxisConvertersUp(boundListToAxis);
        }

        if (toEmit != null) {
            for (i in 0...toEmit.length) {
                var index = toEmit.unsafeGet(i);
                var k = keyForIndex(index);
                _handleConvertedToAxisUp(index);
                if (enabled)
                    emitKeyUp(k);
            }
        }

    }

    function _handleGamepadDown(gamepadId:Int, button:GamepadButton) {

        if (this.gamepadId == -1 || gamepadId == this.gamepadId) {

            var toEmit:Array<Int> = null;

            var boundList = _boundGamepadButtons.get(button);
            if (boundList != null) {
                for (i in 0...boundList.length) {
                    var index = boundList.unsafeGet(i);
                    _setPressedKeyKind(index, GAMEPAD_BUTTON);
                    var prevValue = _pressedKey(index);
                    if (prevValue == -1) {
                        prevValue = 0;
                    }
                    if (prevValue != 1)
                        pressedKeys[index] = prevValue + 1;
                    if (prevValue <= 0) {
                        if (toEmit == null)
                            toEmit = [index];
                        else if (toEmit.indexOf(index) == -1)
                            toEmit.push(index);
                    }
                    if (prevValue == 0) {
                        _scheduleRemoveJustPressed(index);
                    }
                }
            }

            // Button to axis
            var boundListToAxis = _boundGamepadButtonsToAxes.get(button);
            if (boundListToAxis != null) {
                _handleAxisConvertersDown(boundListToAxis);
            }

            if (toEmit != null) {
                for (i in 0...toEmit.length) {
                    var index = toEmit.unsafeGet(i);
                    var k = keyForIndex(index);
                    _handleConvertedToAxisDown(index);
                    if (enabled)
                        emitKeyDown(k);
                }
            }

        }

    }

    function _handleGamepadUp(gamepadId:Int, button:GamepadButton) {

        if (this.gamepadId == -1 || gamepadId == this.gamepadId) {

            var toEmit:Array<Int> = null;

            var boundList = _boundGamepadButtons.get(button);
            if (boundList != null) {
                for (i in 0...boundList.length) {
                    var index = boundList.unsafeGet(i);
                    var prevValue = _pressedKey(index);
                    if (prevValue > 0) {
                        pressedKeys[index] = -1;
                        if (toEmit == null)
                            toEmit = [index];
                        else if (toEmit.indexOf(index) == -1)
                            toEmit.push(index);
                    }
                    if (prevValue != 0) {
                        _scheduleRemoveJustReleased(index);
                    }
                }
            }

            // Button to axis
            var boundListToAxis = _boundGamepadButtonsToAxes.get(button);
            if (boundListToAxis != null) {
                _handleAxisConvertersUp(boundListToAxis);
            }

            if (toEmit != null) {
                for (i in 0...toEmit.length) {
                    var index = toEmit.unsafeGet(i);
                    var k = keyForIndex(index);
                    _handleConvertedToAxisUp(index);
                    if (enabled)
                        emitKeyUp(k);
                }
            }
        }

    }

    function _handleMouseDown(buttonId:Int, x:Float, y:Float) {

        #if plugin_elements
        if (elements.Im.hits(x, y)) {
            // Ignore mouse event if immediate UI is in the way
            return;
        }
        #end

        var toEmit:Array<Int> = null;

        var boundList = _boundMouseButtons.get(buttonId);
        if (boundList != null) {
            for (i in 0...boundList.length) {
                var index = boundList.unsafeGet(i);
                _setPressedKeyKind(index, MOUSE_BUTTON);
                var prevValue = _pressedKey(index);
                if (prevValue == -1) {
                    prevValue = 0;
                }
                if (prevValue != 1)
                    pressedKeys[index] = prevValue + 1;
                if (prevValue <= 0) {
                    if (toEmit == null)
                        toEmit = [index];
                    else if (toEmit.indexOf(index) == -1)
                        toEmit.push(index);
                }
                if (prevValue == 0) {
                    _scheduleRemoveJustPressed(index);
                }
            }
        }

        if (toEmit != null) {
            for (i in 0...toEmit.length) {
                var index = toEmit.unsafeGet(i);
                var k = keyForIndex(index);
                _handleConvertedToAxisDown(index);
                if (enabled)
                    emitKeyDown(k);
            }
        }

    }

    function _handleMouseUp(buttonId:Int, x:Float, y:Float) {

        var toEmit:Array<Int> = null;

        var boundList = _boundMouseButtons.get(buttonId);
        if (boundList != null) {
            for (i in 0...boundList.length) {
                var index = boundList.unsafeGet(i);
                var prevValue = _pressedKey(index);
                if (prevValue > 0) {
                    pressedKeys[index] = -1;
                    if (toEmit == null)
                        toEmit = [index];
                    else if (toEmit.indexOf(index) == -1)
                        toEmit.push(index);
                }
                if (prevValue != 0) {
                    _scheduleRemoveJustReleased(index);
                }
            }
        }

        if (toEmit != null) {
            for (i in 0...toEmit.length) {
                var index = toEmit.unsafeGet(i);
                var k = keyForIndex(index);
                _handleConvertedToAxisUp(index);
                if (enabled)
                    emitKeyUp(k);
            }
        }

    }

    function _handleGamepadAxis(gamepadId:Int, axis:GamepadAxis, value:Float) {

        if (this.gamepadId == -1 || gamepadId == this.gamepadId) {

            var toEmit:Array<Int> = null;

            var boundList = _boundGamepadAxes.get(axis);
            if (boundList != null) {
                for (i in 0...boundList.length) {
                    var index = boundList.unsafeGet(i);
                    var prevValue = _axisValue(index);
                    if (prevValue != value) {
                        axisValues[index] = value;
                        if (toEmit == null)
                            toEmit = [index];
                        else if (toEmit.indexOf(index) == -1)
                            toEmit.push(index);
                    }
                }
            }

            var keyDownToEmit:Array<Int> = null;
            var keyUpToEmit:Array<Int> = null;

            // Here, we convert some axis values into actual key down/up events
            var axisButtonBoundList = _boundGamepadAxesToButtons.get(axis);
            if (axisButtonBoundList != null) {
                var i = 0;
                var len = axisButtonBoundList.length;
                while (i < len) {
                    var index = axisButtonBoundList.unsafeGet(i);
                    i++;
                    var startValue = axisButtonBoundList.unsafeGet(i) / 1000.0;
                    i++;
                    var pressed = false;
                    if (startValue > 0) {
                        if (value >= startValue)
                            pressed = true;
                    }
                    else if (startValue < 0) {
                        if (value <= startValue)
                            pressed = true;
                    }
                    var prevValue = _pressedKey(index);
                    if (pressed) {
                        _setPressedKeyKind(index, GAMEPAD_AXIS);
                        var prevValue = _pressedKey(index);
                        if (prevValue == -1) {
                            prevValue = 0;
                        }
                        if (prevValue != 1)
                            pressedKeys[index] = prevValue + 1;
                        if (prevValue <= 0) {
                            if (keyDownToEmit == null)
                                keyDownToEmit = [index];
                            else if (keyDownToEmit.indexOf(index) == -1)
                                keyDownToEmit.push(index);
                        }
                        if (prevValue == 0) {
                            _scheduleRemoveJustPressed(index);
                        }
                    }
                    else if (_pressedKeyKind(index) == GAMEPAD_AXIS) {
                        if (prevValue > 0) {
                            pressedKeys[index] = -1;
                            if (keyUpToEmit == null)
                                keyUpToEmit = [index];
                            else if (keyUpToEmit.indexOf(index) == -1)
                                keyUpToEmit.push(index);
                        }
                        if (prevValue != 0) {
                            _scheduleRemoveJustReleased(index);
                        }
                    }
                }
            }

            if (toEmit != null) {
                for (i in 0...toEmit.length) {
                    var index = toEmit.unsafeGet(i);
                    var k = keyForIndex(index);
                    if (enabled)
                        emitAxis(k, value);
                }
            }

            if (keyDownToEmit != null) {
                for (i in 0...keyDownToEmit.length) {
                    var index = keyDownToEmit.unsafeGet(i);
                    var k = keyForIndex(index);
                    if (enabled)
                        emitKeyDown(k);
                }
            }

            if (keyUpToEmit != null) {
                for (i in 0...keyUpToEmit.length) {
                    var index = keyUpToEmit.unsafeGet(i);
                    var k = keyForIndex(index);
                    if (enabled)
                        emitKeyUp(k);
                }
            }

        }

    }

    inline function _handleConvertedToAxisUp(index:Int):Void {

        var converters = convertToAxis[index];
        if (converters != null) {
            _handleAxisConvertersUp(converters);
        }

    }

    function _handleConvertedToAxisDown(index:Int):Void {

        var converters = convertToAxis[index];
        if (converters != null) {
            _handleAxisConvertersDown(converters);
        }

    }

    inline function _handleAxisConvertersDown(converters:Array<InputMapConvertToAxis>) {

        for (j in 0...converters.length) {
            var converter = converters.unsafeGet(j);
            if (converter != null) {
                var targetIndex = converter.index;
                var prevValue = _axisValue(targetIndex);
                var value = converter.value;
                if (prevValue != value) {
                    axisValues[targetIndex] = value / 1000.0;
                    var k = keyForIndex(targetIndex);
                    if (enabled)
                        emitAxis(k, value);
                }
            }
        }

    }

    inline function _handleAxisConvertersUp(converters:Array<InputMapConvertToAxis>) {

        for (j in 0...converters.length) {
            var converter = converters.unsafeGet(j);
            if (converter != null) {
                var targetIndex = converter.index;
                var prevValue = _axisValue(targetIndex);
                if (prevValue != 0.0) {
                    axisValues[targetIndex] = 0.0;
                    var k = keyForIndex(targetIndex);
                    if (enabled)
                        emitAxis(k, 0.0);
                }
            }
        }

    }

    function _pressedKey(index:Int):Int {

        var value:Int = 0;
        if (pressedKeys.length > index) {
            value = pressedKeys.unsafeGet(index);
        }
        else {
            while (pressedKeys.length <= index)
                pressedKeys.push(0);
        }
        return value;

    }

    inline function _axisValue(index:Int):Float {

        var value:Float = 0;
        if (axisValues.length > index) {
            value = axisValues.unsafeGet(index);
        }
        else {
            while (pressedKeys.length <= index)
                pressedKeys.push(0);
        }
        return value;

    }

    inline function _pressedKeyKind(index:Int):InputMapKeyKind {

        return pressedKeyKinds.length > index ? pressedKeyKinds.unsafeGet(index) : NONE;

    }

    inline function _setPressedKeyKind(index:Int, kind:InputMapKeyKind) {

        pressedKeyKinds[index] = kind;

    }

    function _scheduleRemoveJustPressed(index:Int) {

        // Used to differenciate "pressed" and "just pressed" states
        app.beginUpdateCallbacks.push(function() {
            if (pressedKeys[index] == 1) {
                pressedKeys[index] = 2;
            }
        });

    }

    function _scheduleRemoveJustReleased(index:Int) {

        // Used to differenciate "released" and "just released" states
        app.beginUpdateCallbacks.push(function() {
            if (pressedKeys[index] == -1) {
                pressedKeys[index] = 0;
            }
        });

    }

    function _recomputePressedKey(index:Int):Void {

        var keyCodes = _indexedKeyCodes[index];
        if (keyCodes != null) {
            for (i in 0...keyCodes.length) {
                var keyCode = keyCodes.unsafeGet(i);
                if (input.keyPressed(keyCode, this)) {
                    var justPressed = checkJustPressedAtBind ? input.keyJustPressed(keyCode, this) : false;
                    pressedKeys[index] = justPressed ? 1 : 2;
                    _setPressedKeyKind(index, KEY_CODE);
                    if (justPressed)
                        _scheduleRemoveJustPressed(index);
                    return;
                }
            }
        }

        var scanCodes = _indexedScanCodes[index];
        if (scanCodes != null) {
            for (i in 0...scanCodes.length) {
                var scanCode = scanCodes.unsafeGet(i);
                if (input.scanPressed(scanCode, this)) {
                    var justPressed = checkJustPressedAtBind ? input.scanJustPressed(scanCode, this) : false;
                    pressedKeys[index] = justPressed ? 1 : 2;
                    _setPressedKeyKind(index, SCAN_CODE);
                    if (justPressed)
                        _scheduleRemoveJustPressed(index);
                    return;
                }
            }
        }

        var mouseButtons = _indexedMouseButtons[index];
        if (mouseButtons != null) {
            for (i in 0...mouseButtons.length) {
                var buttonId = mouseButtons.unsafeGet(i);
                if (screen.mousePressed(buttonId, this)) {
                    var justPressed = checkJustPressedAtBind ? screen.mouseJustPressed(buttonId, this) : false;
                    pressedKeys[index] = justPressed ? 1 : 2;
                    _setPressedKeyKind(index, MOUSE_BUTTON);
                    if (justPressed)
                        _scheduleRemoveJustPressed(index);
                    return;
                }
            }
        }

        var gamepadButtons = _indexedGamepadButtons[index];
        if (gamepadButtons != null) {
            for (i in 0...gamepadButtons.length) {
                var button = gamepadButtons.unsafeGet(i);
                var gamepads = input.activeGamepads;
                for (g in 0...gamepads.length) {
                    var gamepadId = gamepads.unsafeGet(g);
                    if (this.gamepadId == -1 || this.gamepadId == gamepadId) {
                        if (input.gamepadPressed(gamepadId, button, this)) {
                            var justPressed = checkJustPressedAtBind ? input.gamepadJustPressed(gamepadId, button, this) : false;
                            pressedKeys[index] = justPressed ? 1 : 2;
                            _setPressedKeyKind(index, GAMEPAD_BUTTON);
                            if (justPressed)
                                _scheduleRemoveJustPressed(index);
                            return;
                        }
                    }
                }
            }
        }

        var gamepadAxisButtons = _indexedGamepadAxesToButtons[index];
        if (gamepadAxisButtons != null) {
            for (i in 0...gamepadAxisButtons.length) {
                var axis = gamepadAxisButtons.unsafeGet(i);
                var axisList = _boundGamepadAxesToButtons.get(axis);
                var startValue = 999.0;
                var v = 0;
                while (v < axisList.length) {
                    var valueIndex = axisList.unsafeGet(v);
                    v++;
                    if (valueIndex == index) {
                        startValue = axisList.unsafeGet(v) / 1000.0;
                        break;
                    }
                    v++;
                }
                var gamepads = input.activeGamepads;
                for (g in 0...gamepads.length) {
                    var gamepadId = gamepads.unsafeGet(g);
                    if (this.gamepadId == -1 || this.gamepadId == gamepadId) {
                        var value = input.gamepadAxisValue(gamepadId, axis);
                        var pressed = false;
                        if (startValue > 0) {
                            if (value >= startValue)
                                pressed = true;
                        }
                        else if (startValue < 0) {
                            if (value <= startValue)
                                pressed = true;
                        }
                        if (pressed) {
                            pressedKeys[index] = 2;
                            _setPressedKeyKind(index, GAMEPAD_AXIS);
                            return;
                        }
                    }
                }
            }
        }

        pressedKeys[index] = 0;

    }

    function _recomputeAxisValue(index:Int):Void {

        var axisValue:Float = 0.0;

        var gamepadAxis = _indexedGamepadAxis[index];
        if (gamepadAxis != null) {
            for (i in 0...gamepadAxis.length) {
                var axis = gamepadAxis.unsafeGet(i);
                var gamepads = input.activeGamepads;
                var absAxisValue = 0.0;
                for (g in 0...gamepads.length) {
                    var gamepadId = gamepads.unsafeGet(g);
                    if (this.gamepadId == -1 || this.gamepadId == gamepadId) {
                        var value = input.gamepadAxisValue(gamepadId, axis);
                        var absValue = value < 0 ? -value : value;
                        if (absValue > absAxisValue) {
                            axisValue = value;
                            absAxisValue = absValue;
                        }
                    }
                }
            }
        }

        for (i in 0...convertToAxis.length) {
            var converters = convertToAxis[i];
            if (converters != null) {
                for (j in 0...converters.length) {
                    var converter = converters.unsafeGet(j);
                    if (converter != null && converter.index == index) {
                        if (_pressedKey(i) > 0) {
                            axisValue = converter.value / 1000.0;
                        }
                    }
                }
            }
        }

        var indexList = _indexedKeyCodesToAxes[index];
        if (indexList != null) {
            for (i in 0...indexList.length) {
                var keyCode = indexList.unsafeGet(i);
                if (input.keyPressed(keyCode, this)) {
                    var converters = _boundKeyCodesToAxes.get(keyCode);
                    if (converters != null) {
                        for (j in 0...converters.length) {
                            var converter = converters.unsafeGet(j);
                            if (converter != null && converter.index == index) {
                                axisValue = converter.value / 1000.0;
                            }
                        }
                    }
                }
            }
        }

        var indexList = _indexedScanCodesToAxes[index];
        if (indexList != null) {
            for (i in 0...indexList.length) {
                var scanCode = indexList.unsafeGet(i);
                if (input.scanPressed(scanCode, this)) {
                    var converters = _boundScanCodesToAxes.get(scanCode);
                    if (converters != null) {
                        for (j in 0...converters.length) {
                            var converter = converters.unsafeGet(j);
                            if (converter != null && converter.index == index) {
                                axisValue = converter.value / 1000.0;
                            }
                        }
                    }
                }
            }
        }

        var indexList = _indexedGamepadButtonsToAxes[index];
        if (indexList != null) {
            for (i in 0...indexList.length) {
                var button = indexList.unsafeGet(i);
                var gamepads = input.activeGamepads;
                for (g in 0...gamepads.length) {
                    var gamepadId = gamepads.unsafeGet(g);
                    if (this.gamepadId == -1 || this.gamepadId == gamepadId) {
                        var pressed = input.gamepadPressed(gamepadId, button, this);
                        if (pressed) {
                            var converters = _boundGamepadButtonsToAxes.get(button);
                            if (converters != null) {
                                for (j in 0...converters.length) {
                                    var converter = converters.unsafeGet(j);
                                    if (converter != null && converter.index == index) {
                                        axisValue = converter.value / 1000.0;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        axisValues[index] = axisValue;

    }

/// Public API

    /**
     * Binds a keyboard key code to an action.
     * Multiple key codes can be bound to the same action.
     * @param key The action to bind to
     * @param keyCode The keyboard key code to bind
     */
    public function bindKeyCode(key:T, keyCode:KeyCode):Void {

        var index = indexOfKey(key);

        var list = _boundKeyCodes.get(keyCode);
        if (list == null) {
            list = [index];
            _boundKeyCodes.set(keyCode, list);
        }
        else {
            list.push(index);
        }

        var indexList = _indexedKeyCodes[index];
        if (indexList == null) {
            indexList = [keyCode];
            _indexedKeyCodes[index] = indexList;
        }
        else {
            indexList.push(keyCode);
        }

        _recomputePressedKey(index);

    }

    /**
     * Gets all key codes currently bound to an action.
     * @param key The action to query
     * @return Array of bound key codes (empty if none)
     */
    public function boundKeyCodes(key:T):ReadOnlyArray<KeyCode> {

        var index = indexOfKey(key);
        var keyCodes = _indexedKeyCodes[index];
        if (keyCodes == null) return cast EMPTY_ARRAY;
        return keyCodes;

    }

    /**
     * Removes a key code binding from an action.
     * @param key The action to unbind from
     * @param keyCode The key code to unbind
     */
    public function unbindKeyCode(key:T, keyCode:KeyCode):Void {

        var index = indexOfKey(key);
        var list = _boundKeyCodes.get(keyCode);
        if (list != null) list.remove(index);

        var indexList = _indexedKeyCodes[index];
        if (indexList != null) indexList.remove(keyCode);

        _recomputePressedKey(index);

    }

    /**
     * Binds a keyboard key to an analog axis action.
     * When the key is pressed, it will set the axis to the specified value.
     * Useful for digital-to-analog conversion (e.g., WASD to movement).
     * @param key The axis action to bind to
     * @param keyCode The keyboard key code to bind
     * @param axisValue The axis value when pressed (typically -1.0 or 1.0)
     */
    public function bindKeyCodeToAxis(key:T, keyCode:KeyCode, axisValue:Float):Void {

        var axisIndex = indexOfKey(key);

        var list = _boundKeyCodesToAxes.get(keyCode);
        if (list == null) {
            list = [];
            _boundKeyCodesToAxes.set(keyCode, list);
        }

        list.push({
            index: axisIndex,
            value: Math.round(axisValue * 1000)
        });

        var indexList = _indexedKeyCodesToAxes[axisIndex];
        if (indexList == null) {
            indexList = [keyCode];
            _indexedKeyCodesToAxes[axisIndex] = indexList;
        }
        else {
            indexList.push(keyCode);
        }

        _recomputeAxisValue(axisIndex);

    }

    /**
     * Gets all key codes bound to an axis action.
     * @param key The axis action to query
     * @return Array of bound key codes (empty if none)
     */
    public function boundKeyCodesToAxis(key:T):ReadOnlyArray<KeyCode> {

        var axisIndex = indexOfKey(key);
        var keyCodes = _indexedKeyCodesToAxes[axisIndex];
        if (keyCodes == null) return cast EMPTY_ARRAY;
        return keyCodes;

    }

    /**
     * Gets the axis value associated with a key code binding.
     * @param key The axis action
     * @param keyCode The key code to check
     * @return The axis value for this binding, or 0 if not bound
     */
    public function boundKeyCodeToAxisValue(key:T, keyCode:KeyCode): Float {

        var index = indexOfKey(key);
        var list = _boundKeyCodesToAxes.get(keyCode);
        if (list == null) return 0;

        var item = list.unsafeGet(index);
        return item.value / 1000.0;

    }

    /**
     * Removes a key code to axis binding.
     * @param key The axis action to unbind from
     * @param keyCode The key code to unbind
     */
    public function unbindKeyCodeToAxis(key:T, keyCode:KeyCode):Void {

        var axisIndex = indexOfKey(key);
        var list = _boundKeyCodesToAxes.get(keyCode);
        if (list != null) {
            for (axisPair in list) {
                if (axisPair.index == axisIndex) {
                    list.remove(axisPair);
                }
            }
        }

        var indexList = _indexedKeyCodesToAxes[axisIndex];
        if (indexList != null) indexList.remove(keyCode);

        _recomputeAxisValue(axisIndex);

    }

    /**
     * Binds a keyboard scan code to an action.
     * Scan codes represent physical key positions and are layout-independent.
     * @param key The action to bind to
     * @param scanCode The scan code to bind
     */
    public function bindScanCode(key:T, scanCode:ScanCode):Void {

        var index = indexOfKey(key);

        var list = _boundScanCodes.get(scanCode);
        if (list == null) {
            list = [index];
            _boundScanCodes.set(scanCode, list);
        }
        else {
            list.push(index);
        }

        var indexList = _indexedScanCodes[index];
        if (indexList == null) {
            indexList = [scanCode];
            _indexedScanCodes[index] = indexList;
        }
        else {
            indexList.push(scanCode);
        }

        _recomputePressedKey(index);

    }

    /**
     * Gets all scan codes currently bound to an action.
     * @param key The action to query
     * @return Array of bound scan codes (empty if none)
     */
    public function boundScanCodes(key:T):ReadOnlyArray<ScanCode> {

        var index = indexOfKey(key);
        var scanCodes = _indexedScanCodes[index];
        if (scanCodes == null) return cast EMPTY_ARRAY;
        return scanCodes;

    }

    /**
     * Removes a scan code binding from an action.
     * @param key The action to unbind from
     * @param scanCode The scan code to unbind
     */
    public function unbindScanCode(key:T, scanCode:ScanCode):Void {

        var index = indexOfKey(key);
        var list = _boundScanCodes.get(scanCode);
        if (list != null) list.remove(index);

        var indexList = _indexedScanCodes[index];
        if (indexList != null) indexList.remove(scanCode);

        _recomputePressedKey(index);
    }

    public function bindScanCodeToAxis(key:T, scanCode:ScanCode, axisValue:Float):Void {

        var axisIndex = indexOfKey(key);

        var list = _boundScanCodesToAxes.get(scanCode);
        if (list == null) {
            list = [];
            _boundScanCodesToAxes.set(scanCode, list);
        }

        list.push({
            index: axisIndex,
            value: Math.round(axisValue * 1000)
        });

        var indexList = _indexedScanCodesToAxes[axisIndex];
        if (indexList == null) {
            indexList = [scanCode];
            _indexedScanCodesToAxes[axisIndex] = indexList;
        }
        else {
            indexList.push(scanCode);
        }

        _recomputeAxisValue(axisIndex);

    }

    public function boundScanCodesToAxis(key:T):ReadOnlyArray<ScanCode> {

        var axisIndex = indexOfKey(key);
        var scanCodes = _indexedScanCodesToAxes[axisIndex];
        if (scanCodes == null) return cast EMPTY_ARRAY;
        return scanCodes;

    }

    public function boundScanCodeToAxisValue(key:T, scanCode:ScanCode): Float {

        var index = indexOfKey(key);
        var list = _boundScanCodesToAxes.get(scanCode);
        if (list == null) return 0;

        var item = list.unsafeGet(index);
        return item.value / 1000.0;

    }

    public function unbindScanCodeToAxis(key:T, scanCode:ScanCode):Void {

        var axisIndex = indexOfKey(key);
        var list = _boundScanCodesToAxes.get(scanCode);
        if (list != null) {
            for (axisPair in list) {
                if (axisPair.index == axisIndex) {
                    list.remove(axisPair);
                }
            }
        }

        var indexList = _indexedScanCodesToAxes[axisIndex];
        if (indexList != null) indexList.remove(scanCode);

        _recomputeAxisValue(axisIndex);

    }

    /**
     * Binds a mouse button to an action.
     * @param key The action to bind to
     * @param buttonId The mouse button ID (0=left, 1=right, 2=middle)
     */
    public function bindMouseButton(key:T, buttonId:Int):Void {

        var index = indexOfKey(key);

        var list = _boundMouseButtons.get(buttonId);
        if (list == null) {
            list = [index];
            _boundMouseButtons.set(buttonId, list);
        }
        else {
            list.push(index);
        }

        var indexList = _indexedMouseButtons[index];
        if (indexList == null) {
            indexList = [buttonId];
            _indexedMouseButtons[index] = indexList;
        }
        else {
            indexList.push(buttonId);
        }

        _recomputePressedKey(index);

    }

    /**
     * Gets all mouse buttons currently bound to an action.
     * @param key The action to query
     * @return Array of bound mouse button IDs (empty if none)
     */
    public function boundMouseButtons(key:T):ReadOnlyArray<Int> {

        var index = indexOfKey(key);
        var buttons = _indexedMouseButtons[index];
        if (buttons == null) return cast EMPTY_ARRAY;
        return buttons;

    }

    /**
     * Removes a mouse button binding from an action.
     * @param key The action to unbind from
     * @param buttonId The mouse button ID to unbind
     */
    public function unbindMouseButton(key:T, buttonId:Int):Void {

        var index = indexOfKey(key);
        var list = _boundMouseButtons.get(buttonId);
        if (list != null) list.remove(index);

        var indexList = _indexedMouseButtons[index];
        if (indexList != null) indexList.remove(buttonId);

        _recomputePressedKey(index);

    }

    /**
     * Binds a gamepad button to an action.
     * @param key The action to bind to
     * @param button The gamepad button to bind
     */
    public function bindGamepadButton(key:T, button:GamepadButton):Void {

        var index = indexOfKey(key);

        var list = _boundGamepadButtons.get(button);
        if (list == null) {
            list = [index];
            _boundGamepadButtons.set(button, list);
        }
        else {
            list.push(index);
        }

        var indexList = _indexedGamepadButtons[index];
        if (indexList == null) {
            indexList = [button];
            _indexedGamepadButtons[index] = indexList;
        }
        else {
            indexList.push(button);
        }

        _recomputePressedKey(index);

    }

    /**
     * Gets all gamepad buttons currently bound to an action.
     * @param key The action to query
     * @return Array of bound gamepad buttons (empty if none)
     */
    public function boundGamepadButtons(key:T):ReadOnlyArray<GamepadButton> {

        var index = indexOfKey(key);
        var buttons = _indexedGamepadButtons[index];
        if (buttons == null) return cast EMPTY_ARRAY;
        return buttons;

    }

    /**
     * Removes a gamepad button binding from an action.
     * @param key The action to unbind from
     * @param button The gamepad button to unbind
     */
    public function unbindGamepadButton(key:T, button:GamepadButton):Void {

        var index = indexOfKey(key);
        var list = _boundGamepadButtons.get(button);
        if (list != null) list.remove(index);

        var indexList = _indexedGamepadButtons[index];
        if (indexList != null) indexList.remove(button);

        _recomputePressedKey(index);

    }

    public function bindGamepadButtonToAxis(key:T, button:GamepadButton, axisValue:Float):Void {

        var axisIndex = indexOfKey(key);

        var list = _boundGamepadButtonsToAxes.get(button);
        if (list == null) {
            list = [];
            _boundGamepadButtonsToAxes.set(button, list);
        }

        list.push({
            index: axisIndex,
            value: Math.round(axisValue * 1000)
        });

        var indexList = _indexedGamepadButtonsToAxes[axisIndex];
        if (indexList == null) {
            indexList = [button];
            _indexedGamepadButtonsToAxes[axisIndex] = indexList;
        }
        else {
            indexList.push(button);
        }

        _recomputeAxisValue(axisIndex);

    }

    public function boundGamepadButtonsToAxis(key:T):ReadOnlyArray<GamepadButton> {

        var axisIndex = indexOfKey(key);
        var buttons = _indexedGamepadButtonsToAxes[axisIndex];
        if (buttons == null) return cast EMPTY_ARRAY;
        return buttons;

    }

    public function boundGamepadButtonToAxisValue(key:T, button:GamepadButton): Float {

        var index = indexOfKey(key);
        var list = _boundGamepadButtonsToAxes.get(button);
        if (list == null) return 0;

        var item = list.unsafeGet(index);
        return item.value / 1000.0;

    }

    public function unbindGamepadButtonToAxis(key:T, button:GamepadButton):Void {

        var axisIndex = indexOfKey(key);
        var list = _boundGamepadButtonsToAxes.get(button);
        if (list != null) {
            for (axisPair in list) {
                if (axisPair.index == axisIndex) {
                    list.remove(axisPair);
                }
            }
        }

        var indexList = _indexedGamepadButtonsToAxes[axisIndex];
        if (indexList != null) indexList.remove(button);

        _recomputeAxisValue(axisIndex);

    }

    /**
     * Binds a gamepad analog axis to an axis action.
     * The axis value will be passed through directly.
     * @param key The axis action to bind to
     * @param axis The gamepad axis to bind
     */
    public function bindGamepadAxis(key:T, axis:GamepadAxis):Void {

        var axisIndex = indexOfKey(key);

        var list = _boundGamepadAxes.get(axis);
        if (list == null) {
            list = [axisIndex];
            _boundGamepadAxes.set(axis, list);
        }
        else {
            list.push(axisIndex);
        }

        var indexList = _indexedGamepadAxis[axisIndex];
        if (indexList == null) {
            indexList = [axis];
            _indexedGamepadAxis[axisIndex] = indexList;
        }
        else {
            indexList.push(axis);
        }

        _recomputeAxisValue(axisIndex);

    }

    /**
     * Gets all gamepad axes currently bound to an axis action.
     * @param key The axis action to query
     * @return Array of bound gamepad axes (empty if none)
     */
    public function boundGamepadAxes(key:T):ReadOnlyArray<GamepadAxis> {

        var axisIndex = indexOfKey(key);
        var axes = _indexedGamepadAxis[axisIndex];
        if (axes == null) return cast EMPTY_ARRAY;
        return axes;

    }

    /**
     * Removes a gamepad axis binding from an axis action.
     * @param key The axis action to unbind from
     * @param axis The gamepad axis to unbind
     */
    public function unbindGamepadAxis(key:T, axis:GamepadAxis):Void {

        var axisIndex = indexOfKey(key);
        var list = _boundGamepadAxes.get(axis);
        if (list != null) list.remove(axisIndex);

        var indexList = _indexedGamepadAxis[axisIndex];
        if (indexList != null) indexList.remove(axis);

        _recomputeAxisValue(axisIndex);

    }

    /**
     * Binds a gamepad axis to a button action with a threshold.
     * The button will be "pressed" when the axis value crosses the threshold.
     * @param key The button action to bind to
     * @param axis The gamepad axis to bind
     * @param startValue The threshold value (positive for > threshold, negative for < threshold)
     */
    public function bindGamepadAxisToButton(key:T, axis:GamepadAxis, startValue:Float):Void {

        var index = indexOfKey(key);

        var list = _boundGamepadAxesToButtons.get(axis);
        if (list == null) {
            list = [index, Math.round(startValue * 1000)];
            _boundGamepadAxesToButtons.set(axis, list);
        }
        else {
            list.push(index);
            list.push(Math.round(startValue * 1000));
        }

        var indexList = _indexedGamepadAxesToButtons[index];
        if (indexList == null) {
            indexList = [axis];
            _indexedGamepadAxesToButtons[index] = indexList;
        }
        else {
            indexList.push(axis);
        }

        _recomputePressedKey(index);

    }

    public function boundGamepadAxesToButton(key:T):ReadOnlyArray<GamepadAxis> {

        var index = indexOfKey(key);
        var axes = _indexedGamepadAxesToButtons[index];
        if (axes == null) return cast EMPTY_ARRAY;
        return axes;

    }

    public function boundGamepadAxisToButtonStartValue(key:T, axis:GamepadAxis): Float {

        var index = indexOfKey(key);
        var list = _boundGamepadAxesToButtons.get(axis);
        if (list == null) return 0;

        var i = 0;
        var len = list.length;
        while (i < len) {
            var itemIndex = list.unsafeGet(i);
            i++;
            if (index == itemIndex) {
                return list.unsafeGet(i) / 1000.0;
            }
            i++;
        }

        return 0;
    }

    public function unbindGamepadAxisToButton(key:T, axis:GamepadAxis):Void {

        var index = indexOfKey(key);
        var list = _boundGamepadAxesToButtons.get(axis);

        if (list != null) {
            var i = 0;
            var len = list.length;
            while (i < len) {
                var itemIndex = list.unsafeGet(i);
                if (index == itemIndex) {
                    _boundGamepadAxesToButtons.set(axis, list.slice(i, i + 2));
                    break;
                }
                i += 2;
            }
        }

        var indexList = _indexedGamepadAxesToButtons[index];
        if (indexList != null) indexList.remove(axis);

        _recomputePressedKey(index);

    }

    /**
     * Binds a button action to trigger an axis action when pressed.
     * This allows button presses to set axis values.
     * @param key The button action that triggers the axis
     * @param axisKey The axis action to trigger
     * @param axisValue The axis value to set when button is pressed
     */
    public function bindConvertedToAxis(key:T, axisKey:T, axisValue:Float):Void {

        var index = indexOfKey(key);
        var axisIndex = indexOfKey(axisKey);

        if (convertToAxis[index] == null) {
            convertToAxis[index] = [];
        }

        convertToAxis[index].push({
            index: axisIndex,
            value: Math.round(axisValue * 1000)
        });

        _recomputeAxisValue(axisIndex);

    }

    /**
     * Checks if an action is currently pressed (held down).
     * Returns true for every frame while the input is held.
     * @param key The action to check
     * @return True if the action is currently pressed
     */
    public function pressed(key:T):Bool {

        return enabled && _pressedKey(indexOfKey(key)) > 0;

    }

    /**
     * Checks if an action was just pressed this frame.
     * Returns true only on the frame the input was initially pressed.
     * @param key The action to check
     * @return True if the action was just pressed this frame
     */
    public function justPressed(key:T):Bool {

        return enabled && _pressedKey(indexOfKey(key)) == 1;

    }

    /**
     * Checks if an action was just released this frame.
     * Returns true only on the frame the input was released.
     * @param key The action to check
     * @return True if the action was just released this frame
     */
    public function justReleased(key:T):Bool {

        return enabled && _pressedKey(indexOfKey(key)) == -1;

    }

    /**
     * Gets the current value of an axis action.
     * Returns 0.0 if the input map is disabled or no axis is active.
     * @param key The axis action to check
     * @return The current axis value (typically -1.0 to 1.0)
     */
    public function axisValue(key:T):Float {

        return enabled ? axisValues[indexOfKey(key)] : 0.0;

    }

}

/**
 * Represents the type of physical input that triggered an action.
 * Used internally to track which input system generated an event.
 */
enum abstract InputMapKeyKind(Int) from Int to Int {

    /** No input type (default state) */
    var NONE = 0;

    /** Input from a keyboard key code */
    var KEY_CODE = 1;

    /** Input from a keyboard scan code */
    var SCAN_CODE = 2;

    /** Input from a mouse button */
    var MOUSE_BUTTON = 3;

    /** Input from a gamepad button */
    var GAMEPAD_BUTTON = 4;

    /** Input from a gamepad analog axis */
    var GAMEPAD_AXIS = 5;

}

/**
 * Helper class for converting digital button inputs to analog axis values.
 * 
 * Used internally by InputMap to simulate analog input from digital buttons,
 * such as using arrow keys to simulate a joystick. Stores the target axis 
 * index and the value to apply when activated.
 */
@:structInit
@:allow(ceramic.InputMapImpl)
class InputMapConvertToAxis {

    /** The index of the target axis action */
    var index:Int;

    /** The axis value to apply (stored as int * 1000 for precision) */
    var value:Int;

}

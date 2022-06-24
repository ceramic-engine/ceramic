package ceramic;

import ceramic.Shortcuts.*;

import ceramic.ReadOnlyArray;

using ceramic.Extensions;

class InputMapImpl<T> extends InputMapBase {

    @event function keyDown(key:T);

    @event function keyUp(key:T);

    @event function axis(key:T, value:Float);

    /**
     * Target events of a specific gamepad by setting its gamepad id.
     * If kept to default (`-1`), events from any gamepad will be handled
     */
    public var gamepadId:Int = -1;

    /**
     * If set to `true`, when binding a new key, will check if the related
     * key was just pressed this frame.
     */
    public var checkJustPressedAtBind:Bool = false;

    /**
     * Set to `false` if you want to disable this input map entirely.
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
                    axisValues[targetIndex] = value;
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

    public function boundKeyCodes(key:T):ReadOnlyArray<KeyCode> {

        var index = indexOfKey(key);
        var keyCodes = _indexedKeyCodes[index];
        if (keyCodes == null) return cast EMPTY_ARRAY;
        return keyCodes;

    }

    public function unbindKeyCode(key:T, keyCode:KeyCode):Void {

        var index = indexOfKey(key);
        var list = _boundKeyCodes.get(keyCode);
        if (list != null) list.remove(index);

        var indexList = _indexedKeyCodes[index];
        if (indexList != null) indexList.remove(keyCode);

        _recomputePressedKey(index);
    }

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

    public function boundKeyCodesToAxis(key:T):ReadOnlyArray<KeyCode> {

        var axisIndex = indexOfKey(key);
        var keyCodes = _indexedKeyCodesToAxes[axisIndex];
        if (keyCodes == null) return cast EMPTY_ARRAY;
        return keyCodes;

    }

    public function getKeyCodeToAxisValue(key:T, keyCode:KeyCode): Null<Float> {

        var index = indexOfKey(key);
        var list = _boundKeyCodesToAxes.get(keyCode);
        if (list == null) return null;

        var item = list.unsafeGet(index);
        return item.value / 1000.0;

    }

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

    public function boundScanCodes(key:T):ReadOnlyArray<ScanCode> {

        var index = indexOfKey(key);
        var scanCodes = _indexedScanCodes[index];
        if (scanCodes == null) return cast EMPTY_ARRAY;
        return scanCodes;

    }

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

    public function getScanCodeToAxisValue(key:T, scanCode:ScanCode): Null<Float> {

        var index = indexOfKey(key);
        var list = _boundScanCodesToAxes.get(scanCode);
        if (list == null) return null;

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

    public function boundMouseButtons(key:T):ReadOnlyArray<Int> {

        var index = indexOfKey(key);
        var buttons = _indexedMouseButtons[index];
        if (buttons == null) return cast EMPTY_ARRAY;
        return buttons;

    }

    public function unbindMouseButton(key:T, buttonId:Int):Void {

        var index = indexOfKey(key);
        var list = _boundMouseButtons.get(buttonId);
        if (list != null) list.remove(index);

        var indexList = _indexedMouseButtons[index];
        if (indexList != null) indexList.remove(buttonId);
        
        _recomputePressedKey(index);

    }

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

    public function boundGamepadButtons(key:T):ReadOnlyArray<GamepadButton> {

        var index = indexOfKey(key);
        var buttons = _indexedGamepadButtons[index];
        if (buttons == null) return cast EMPTY_ARRAY;
        return buttons;

    }

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

    public function getGamepadButtonToAxisValue(key:T, button:GamepadButton): Null<Float> {

        var index = indexOfKey(key);
        var list = _boundGamepadButtonsToAxes.get(button);
        if (list == null) return null;

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

    public function boundGamepadAxes(key:T):ReadOnlyArray<GamepadAxis> {

        var axisIndex = indexOfKey(key);
        var axes = _indexedGamepadAxis[axisIndex];
        if (axes == null) return cast EMPTY_ARRAY;
        return axes;

    }

    public function unbindGamepadAxis(key:T, axis:GamepadAxis):Void {

        var axisIndex = indexOfKey(key);
        var list = _boundGamepadAxes.get(axis);
        if (list != null) list.remove(axisIndex);

        var indexList = _indexedGamepadAxis[axisIndex];
        if (indexList != null) indexList.remove(axis);

        _recomputeAxisValue(axisIndex);

    }

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

    public function getGamepadAxesToButtonStartValue(key:T, axis:GamepadAxis): Null<Float> {

        var index = indexOfKey(key);
        var list = _boundGamepadAxesToButtons.get(axis);
        if (list == null) return null;

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

        return null;
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
                }
                i++;
                i++;
            }
        }

        var indexList = _indexedGamepadAxesToButtons[index];
        if (indexList != null) indexList.remove(axis);

        _recomputePressedKey(index);

    }

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

    public function pressed(key:T):Bool {

        return enabled && _pressedKey(indexOfKey(key)) > 0;

    }

    public function justPressed(key:T):Bool {

        return enabled && _pressedKey(indexOfKey(key)) == 1;

    }

    public function justReleased(key:T):Bool {

        return enabled && _pressedKey(indexOfKey(key)) == -1;

    }

    public function axisValue(key:T):Float {

        return enabled ? axisValues[indexOfKey(key)] : 0.0;

    }

}

enum abstract InputMapKeyKind(Int) from Int to Int {

    var NONE = 0;

    var KEY_CODE = 1;

    var SCAN_CODE = 2;

    var MOUSE_BUTTON = 3;

    var GAMEPAD_BUTTON = 4;

    var GAMEPAD_AXIS = 5;

}

@:structInit
@:allow(ceramic.InputMapImpl)
class InputMapConvertToAxis {

    var index:Int;

    var value:Int;

}

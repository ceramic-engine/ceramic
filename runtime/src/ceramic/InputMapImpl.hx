package ceramic;

import ceramic.Shortcuts.*;

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

    /**
     * A way to know from which the pressed key come from
     */
    var pressedKeyKinds:Array<InputMapKeyKind> = [];

    var boundKeyCodes:IntMap<Array<Int>> = new IntMap();

    var boundKeyCodesToAxis:IntMap<Array<InputMapConvertToAxis>> = new IntMap();

    var boundScanCodes:IntMap<Array<Int>> = new IntMap();

    var boundScanCodesToAxis:IntMap<Array<InputMapConvertToAxis>> = new IntMap();

    var boundMouseButtons:IntMap<Array<Int>> = new IntMap();

    var convertToAxis:Array<Array<InputMapConvertToAxis>> = [];

    var boundGamepadButtons:IntMap<Array<Int>> = new IntMap();

    var boundGamepadButtonsToAxis:IntMap<Array<InputMapConvertToAxis>> = new IntMap();

    var boundGamepadAxis:IntMap<Array<Int>> = new IntMap();

    var boundGamepadAxisButtons:IntMap<Array<Int>> = new IntMap();

    var indexKeyCodes:Array<Array<KeyCode>> = [];

    var axisIndexKeyCodes:Array<Array<KeyCode>> = [];

    var indexScanCodes:Array<Array<ScanCode>> = [];

    var axisIndexScanCodes:Array<Array<ScanCode>> = [];

    var indexMouseButtons:Array<Array<Int>> = [];

    var indexGamepadButtons:Array<Array<GamepadButton>> = [];

    var axisIndexGamepadButtons:Array<Array<GamepadButton>> = [];

    var indexGamepadAxis:Array<Array<GamepadAxis>> = [];

    var indexGamepadAxisButtons:Array<Array<GamepadAxis>> = [];

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
        var boundList = boundKeyCodes.get(keyCode);
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
        var boundListToAxis = boundKeyCodesToAxis.get(keyCode);
        if (boundListToAxis != null) {
            _handleAxisConvertersDown(boundListToAxis);
        }

        // Scan code
        var scanCode = key.scanCode;
        boundList = boundScanCodes.get(scanCode);
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
        boundListToAxis = boundScanCodesToAxis.get(scanCode);
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
        var boundList = boundKeyCodes.get(keyCode);
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
        var boundListToAxis = boundKeyCodesToAxis.get(keyCode);
        if (boundListToAxis != null) {
            _handleAxisConvertersUp(boundListToAxis);
        }

        // Scan code
        var scanCode = key.scanCode;
        boundList = boundScanCodes.get(scanCode);
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
        boundListToAxis = boundScanCodesToAxis.get(scanCode);
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

            var boundList = boundGamepadButtons.get(button);
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
            var boundListToAxis = boundGamepadButtonsToAxis.get(button);
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

            var boundList = boundGamepadButtons.get(button);
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
            var boundListToAxis = boundGamepadButtonsToAxis.get(button);
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

        var boundList = boundMouseButtons.get(buttonId);
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

        var boundList = boundMouseButtons.get(buttonId);
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

            var boundList = boundGamepadAxis.get(axis);
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
            var axisButtonBoundList = boundGamepadAxisButtons.get(axis);
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

        var keyCodes = indexKeyCodes[index];
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

        var scanCodes = indexScanCodes[index];
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

        var mouseButtons = indexMouseButtons[index];
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

        var gamepadButtons = indexGamepadButtons[index];
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

        var gamepadAxisButtons = indexGamepadAxisButtons[index];
        if (gamepadAxisButtons != null) {
            for (i in 0...gamepadAxisButtons.length) {
                var axis = gamepadAxisButtons.unsafeGet(i);
                var axisList = boundGamepadAxisButtons.get(axis);
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

        var gamepadAxis = indexGamepadAxis[index];
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

        var indexList = axisIndexKeyCodes[index];
        if (indexList != null) {
            for (i in 0...indexList.length) {
                var keyCode = indexList.unsafeGet(i);
                if (input.keyPressed(keyCode, this)) {
                    var converters = boundKeyCodesToAxis.get(keyCode);
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

        var indexList = axisIndexScanCodes[index];
        if (indexList != null) {
            for (i in 0...indexList.length) {
                var scanCode = indexList.unsafeGet(i);
                if (input.scanPressed(scanCode, this)) {
                    var converters = boundScanCodesToAxis.get(scanCode);
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

        var indexList = axisIndexGamepadButtons[index];
        if (indexList != null) {
            for (i in 0...indexList.length) {
                var button = indexList.unsafeGet(i);
                var gamepads = input.activeGamepads;
                for (g in 0...gamepads.length) {
                    var gamepadId = gamepads.unsafeGet(g);
                    if (this.gamepadId == -1 || this.gamepadId == gamepadId) {
                        var pressed = input.gamepadPressed(gamepadId, button, this);
                        if (pressed) {
                            var converters = boundGamepadButtonsToAxis.get(button);
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

        var list = boundKeyCodes.get(keyCode);
        if (list == null) {
            list = [index];
            boundKeyCodes.set(keyCode, list);
        }
        else {
            list.push(index);
        }

        var indexList = indexKeyCodes[index];
        if (indexList == null) {
            indexList = [keyCode];
            indexKeyCodes[index] = indexList;
        }
        else {
            indexList.push(keyCode);
        }

        _recomputePressedKey(index);

    }

    public function bindKeyCodeAxis(key:T, keyCode:KeyCode, axisValue:Float):Void {

        var axisIndex = indexOfKey(key);

        var list = boundKeyCodesToAxis.get(keyCode);
        if (list == null) {
            list = [];
            boundKeyCodesToAxis.set(keyCode, list);
        }

        list.push({
            index: axisIndex,
            value: Math.round(axisValue * 1000)
        });

        var indexList = axisIndexKeyCodes[axisIndex];
        if (indexList == null) {
            indexList = [keyCode];
            axisIndexKeyCodes[axisIndex] = indexList;
        }
        else {
            indexList.push(keyCode);
        }

        _recomputeAxisValue(axisIndex);

    }

    public function bindScanCode(key:T, scanCode:ScanCode):Void {

        var index = indexOfKey(key);

        var list = boundScanCodes.get(scanCode);
        if (list == null) {
            list = [index];
            boundScanCodes.set(scanCode, list);
        }
        else {
            list.push(index);
        }

        var indexList = indexScanCodes[index];
        if (indexList == null) {
            indexList = [scanCode];
            indexScanCodes[index] = indexList;
        }
        else {
            indexList.push(scanCode);
        }

        _recomputePressedKey(index);

    }

    public function bindScanCodeAxis(key:T, scanCode:ScanCode, axisValue:Float):Void {

        var axisIndex = indexOfKey(key);

        var list = boundScanCodesToAxis.get(scanCode);
        if (list == null) {
            list = [];
            boundScanCodesToAxis.set(scanCode, list);
        }

        list.push({
            index: axisIndex,
            value: Math.round(axisValue * 1000)
        });

        var indexList = axisIndexScanCodes[axisIndex];
        if (indexList == null) {
            indexList = [scanCode];
            axisIndexScanCodes[axisIndex] = indexList;
        }
        else {
            indexList.push(scanCode);
        }

        _recomputeAxisValue(axisIndex);

    }

    public function bindMouseButton(key:T, buttonId:Int):Void {

        var index = indexOfKey(key);

        var list = boundMouseButtons.get(buttonId);
        if (list == null) {
            list = [index];
            boundMouseButtons.set(buttonId, list);
        }
        else {
            list.push(index);
        }

        var indexList = indexMouseButtons[index];
        if (indexList == null) {
            indexList = [buttonId];
            indexMouseButtons[index] = indexList;
        }
        else {
            indexList.push(buttonId);
        }

        _recomputePressedKey(index);

    }

    public function bindGamepadButton(key:T, button:GamepadButton):Void {

        var index = indexOfKey(key);

        var list = boundGamepadButtons.get(button);
        if (list == null) {
            list = [index];
            boundGamepadButtons.set(button, list);
        }
        else {
            list.push(index);
        }

        var indexList = indexGamepadButtons[index];
        if (indexList == null) {
            indexList = [button];
            indexGamepadButtons[index] = indexList;
        }
        else {
            indexList.push(button);
        }

        _recomputePressedKey(index);

    }

    public function bindGamepadButtonAxis(key:T, button:GamepadButton, axisValue:Float):Void {

        var axisIndex = indexOfKey(key);

        var list = boundGamepadButtonsToAxis.get(button);
        if (list == null) {
            list = [];
            boundGamepadButtonsToAxis.set(button, list);
        }

        list.push({
            index: axisIndex,
            value: Math.round(axisValue * 1000)
        });

        var indexList = axisIndexGamepadButtons[axisIndex];
        if (indexList == null) {
            indexList = [button];
            axisIndexGamepadButtons[axisIndex] = indexList;
        }
        else {
            indexList.push(button);
        }

        _recomputeAxisValue(axisIndex);

    }

    public function bindGamepadAxis(key:T, axis:GamepadAxis):Void {

        var index = indexOfKey(key);

        var list = boundGamepadAxis.get(axis);
        if (list == null) {
            list = [index];
            boundGamepadAxis.set(axis, list);
        }
        else {
            list.push(index);
        }

        var indexList = indexGamepadAxis[index];
        if (indexList == null) {
            indexList = [axis];
            indexGamepadAxis[index] = indexList;
        }
        else {
            indexList.push(axis);
        }

        _recomputeAxisValue(index);

    }

    public function bindGamepadAxisButton(key:T, axis:GamepadAxis, startValue:Float):Void {

        var index = indexOfKey(key);

        var list = boundGamepadAxisButtons.get(axis);
        if (list == null) {
            list = [index, Math.round(startValue * 1000)];
            boundGamepadAxisButtons.set(axis, list);
        }
        else {
            list.push(index);
            list.push(Math.round(startValue * 1000));
        }

        var indexList = indexGamepadAxisButtons[index];
        if (indexList == null) {
            indexList = [axis];
            indexGamepadAxisButtons[index] = indexList;
        }
        else {
            indexList.push(axis);
        }

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

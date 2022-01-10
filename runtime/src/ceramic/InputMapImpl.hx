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

    var boundScanCodes:IntMap<Array<Int>> = new IntMap();

    var boundGamepadButtons:IntMap<Array<Int>> = new IntMap();

    var boundGamepadAxis:IntMap<Array<Int>> = new IntMap();

    var boundGamepadAxisButtons:IntMap<Array<Int>> = new IntMap();

    public function new() {

        super();

        input.onKeyDown(this, _handleKeyDown);
        input.onKeyUp(this, _handleKeyUp);
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

        // Scan code
        var scanCode = key.scanCode;
        var boundList = boundScanCodes.get(scanCode);
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

        if (toEmit != null) {
            for (i in 0...toEmit.length) {
                var index = toEmit.unsafeGet(i);
                var k = keyForIndex(index);
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

        if (toEmit != null) {
            for (i in 0...toEmit.length) {
                var index = toEmit.unsafeGet(i);
                var k = keyForIndex(index);
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

            if (toEmit != null) {
                for (i in 0...toEmit.length) {
                    var index = toEmit.unsafeGet(i);
                    var k = keyForIndex(index);
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

            if (toEmit != null) {
                for (i in 0...toEmit.length) {
                    var index = toEmit.unsafeGet(i);
                    var k = keyForIndex(index);
                    emitKeyUp(k);
                }
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
                    emitAxis(k, value);
                }
            }

            if (keyDownToEmit != null) {
                for (i in 0...keyDownToEmit.length) {
                    var index = keyDownToEmit.unsafeGet(i);
                    var k = keyForIndex(index);
                    emitKeyDown(k);
                }
            }

            if (keyUpToEmit != null) {
                for (i in 0...keyUpToEmit.length) {
                    var index = keyUpToEmit.unsafeGet(i);
                    var k = keyForIndex(index);
                    emitKeyUp(k);
                }
            }

        }

    }

    inline function _pressedKey(index:Int):Int {

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
        pressedKeys[index] = 0;

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
        pressedKeys[index] = 0;

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
        pressedKeys[index] = 0;

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
        axisValues[index] = 0;

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
        pressedKeys[index] = 0;

    }

    public function pressed(key:T):Bool {

        return _pressedKey(indexOfKey(key)) > 0;

    }

    public function justPressed(key:T):Bool {

        return _pressedKey(indexOfKey(key)) == 1;

    }

    public function justReleased(key:T):Bool {

        return _pressedKey(indexOfKey(key)) == -1;

    }

    public function axisValue(key:T):Bool {

        return _pressedKey(indexOfKey(key)) > 0;

    }

}

enum abstract InputMapKeyKind(Int) from Int to Int {

    var NONE = 0;

    var KEY_CODE = 1;

    var SCAN_CODE = 2;

    var GAMEPAD_BUTTON = 3;

    var GAMEPAD_AXIS = 4;

}
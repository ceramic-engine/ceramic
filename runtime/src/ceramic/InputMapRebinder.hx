package ceramic;

import ceramic.App;
import ceramic.KeyCode;
import ceramic.Entity;
import ceramic.GamepadAxis;
import ceramic.GamepadButton;
import ceramic.Key;
import ceramic.InputMap;

class InputMapRebinder<T> extends Entity {

    public var axisToButtonDeadZone(default, set):Float = 0.25;

    private function set_axisToButtonDeadZone(value:Float):Float {

        axisToButtonDeadZone = value;

        return axisToButtonDeadZone;

    }

    public var cancelButton(default, set):GamepadButton = GamepadButton.SELECT;

    private function set_cancelButton(button:GamepadButton):GamepadButton {

        cancelButton = button;

        return cancelButton;

    }

    public var cancelKeyCode(default, set):KeyCode = KeyCode.ESCAPE;

    private function set_cancelKeyCode(keyCode:KeyCode):KeyCode {

        cancelKeyCode = keyCode;

        return cancelKeyCode;

    }

    public var keyCondition(default, set):(action:T, key:Key) -> Bool;

    public function set_keyCondition(condition:(action:T, key:Key) -> Bool):(action:T, key:Key) -> Bool {

        keyCondition = condition;

        return keyCondition;

    }

    public var gamepadButtonCondition(default, set):(action:T, gamepadId:Int, button:GamepadButton) -> Bool;

    public function set_gamepadButtonCondition(condition:(action:T, gamepadId:Int, button:GamepadButton) -> Bool):(action:T, gamepadId:Int, button:GamepadButton) -> Bool {

        gamepadButtonCondition = condition;

        return gamepadButtonCondition;

    }

    public var gamepadAxisCondition(default, set):(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool;

    public function set_gamepadAxisCondition(condition:(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool):(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool {

        gamepadAxisCondition = condition;

        return gamepadAxisCondition;

    }

    public var gamepadAxisToButtonCondition(default, set):(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool;

    public function set_gamepadAxisToButtonCondition(condition:(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool):(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool {

        gamepadAxisToButtonCondition = condition;

        return gamepadAxisToButtonCondition;

    }

    private var keyDownListener:(key:Key) -> Void;

    private var gamepadButtonListener:(gamepadId:Int, button:GamepadButton) -> Void;

    private var gamepadAxisListener:(gamepadId:Int, axis:GamepadAxis, value:Float) -> Void;

    private var gamepadAxisToButtonListener:(gamepadId:Int, axis:GamepadAxis, value:Float) -> Void;

    public function new() {
        super();
    }

    private function cancel():Void {

        App.app.input.offKeyDown(keyDownListener);
        App.app.input.offGamepadDown(gamepadButtonListener);
        App.app.input.offGamepadAxis(gamepadAxisListener);
        App.app.input.offGamepadAxis(gamepadAxisToButtonListener);

    }

    @event function beforeRebindAny(inputMap:InputMap<T>, action:T);

    @event function afterRebindAny(inputMap:InputMap<T>, action:T);

    public function rebind(inputMap:InputMap<T>, action:T, removeExisting:Bool = true):Void {

        registerKeyListener(inputMap, action, removeExisting);
        registerGamepadButtonListener(inputMap, action, removeExisting);
        registerGamepadAxisListener(inputMap, action, removeExisting);
        registerGamepadAxisToButtonListener(inputMap, action, removeExisting);
        
    }

    private function isMatchingGamepad(inputMap:InputMap<T>, gamepadId:Int):Bool {

        if (inputMap.gamepadId == -1) {
            return true;
        }

        return inputMap.gamepadId == gamepadId;

    }
    
    @event function beforeRebindKey(inputMap:InputMap<T>, action:T, key:Key);

    @event function afterRebindKey(inputMap:InputMap<T>, action:T, key:Key);

    private function registerKeyListener(inputMap:InputMap<T>, action:T, removeExisting:Bool = true): Void {
        keyDownListener = (key:Key) -> {

            if (key.keyCode == cancelKeyCode) {
                return cancel();
            }

            if (keyCondition != null) {
                if (!keyCondition(action, key)) {
                    return;
                }
            }

            rebindKey(inputMap, action, key, removeExisting);

        };

        App.app.input.onKeyDown(this, keyDownListener);
    }

    private function removeKey(inputMap:InputMap<T>, action:T):Void {

        var keys = inputMap.boundKeyCodes(action);

        if (keys == null) {
            return;
        }

        for (key in keys) {
            inputMap.unbindKeyCode(action, key);
        }

    }

    private function rebindKey(inputMap:InputMap<T>, action:T, key:Key, removeExisting:Bool = true):Void {

        if (removeExisting) {
            removeKey(inputMap, action);
        }

        emitBeforeRebindAny(inputMap, action);
        emitBeforeRebindKey(inputMap, action, key);

        inputMap.bindKeyCode(action, key.keyCode);

        emitAfterRebindKey(inputMap, action, key);
        emitAfterRebindAny(inputMap, action);

        cancel();

    }

    @event function beforeRebindGamepadButton(inputMap:InputMap<T>, action:T, button:GamepadButton);

    @event function afterRebindGamepadButton(inputMap:InputMap<T>, action:T, button:GamepadButton);

    private function registerGamepadButtonListener(inputMap:InputMap<T>, action:T, removeExisting:Bool = true): Void {

        gamepadButtonListener = (gamepadId:Int, button:GamepadButton) -> {

            if (!isMatchingGamepad(inputMap, gamepadId)) {
                return;
            }

            if (button == cancelButton) {
                return cancel();
            }

            if (gamepadButtonCondition != null) {
                if (!gamepadButtonCondition(action, gamepadId, button)) {
                    return;
                }
            }

            rebindGamepadButton(inputMap, action, button, removeExisting);

        };

        App.app.input.onGamepadDown(this, gamepadButtonListener);

    }

    private function removeGamepadButton(inputMap:InputMap<T>, action:T):Void {

        var buttons = inputMap.boundGamepadButtons(action);

        if (buttons == null) {
            return;
        }

        for (button in buttons) {
            inputMap.unbindGamepadButton(action, button);
        }

    }

    private function rebindGamepadButton(inputMap:InputMap<T>, action:T, button:GamepadButton, removeExisting:Bool = true):Void {

        if (removeExisting) {
            removeGamepadButton(inputMap, action);
        }

        emitBeforeRebindAny(inputMap, action);
        emitBeforeRebindGamepadButton(inputMap, action, button);

        inputMap.bindGamepadButton(action, button);

        emitAfterRebindGamepadButton(inputMap, action, button);
        emitAfterRebindAny(inputMap, action);

        cancel();

    }

    @event function beforeRebindGamepadAxis(inputMap:InputMap<T>, action:T, axis:GamepadAxis);

    @event function afterRebindGamepadAxis(inputMap:InputMap<T>, action:T, axis:GamepadAxis);

    private function registerGamepadAxisListener(inputMap:InputMap<T>, action:T, removeExisting:Bool = true): Void {
        
        gamepadAxisListener = (gamepadId:Int, axis:GamepadAxis, value:Float) -> {

            if (!isMatchingGamepad(inputMap, gamepadId)) {
                return;
            }

            if (gamepadAxisCondition != null) {
                if (!gamepadAxisCondition(action, gamepadId, axis, value)) {
                    return;
                }
            }

            rebindGamepadAxis(inputMap, action, axis, value, removeExisting);

        };

        App.app.input.onGamepadAxis(this, gamepadAxisListener);
        
    }

    private function removeGamepadAxis(inputMap:InputMap<T>, action:T):Void {

        var axes = inputMap.boundGamepadAxes(action);

        if (axes == null) {
            return;
        }

        for (axis in axes) {
            inputMap.unbindGamepadAxis(action, axis);
        }

    }

    private function rebindGamepadAxis(inputMap:InputMap<T>, action:T, axis:GamepadAxis, value:Float, removeExisting:Bool):Void {

        if (removeExisting) {
            removeGamepadAxis(inputMap, action);
        }

        emitBeforeRebindAny(inputMap, action);
        emitBeforeRebindGamepadAxis(inputMap, action, axis);

        inputMap.bindGamepadAxis(action, axis);

        emitAfterRebindGamepadAxis(inputMap, action, axis);
        emitAfterRebindAny(inputMap, action);

        cancel();

    }
    
    @event function beforeRebindGamepadAxisToButton(InputMap:InputMap<T>, action:T, axis:GamepadAxis);

    @event function afterRebindGamepadAxisToButton(InputMap:InputMap<T>, action:T, axis:GamepadAxis);

    private function registerGamepadAxisToButtonListener(inputMap:InputMap<T>, action:T, removeExisting:Bool = true): Void {
        
        gamepadAxisToButtonListener = (gamepadId:Int, axis:GamepadAxis, value:Float) -> {

            if (!isMatchingGamepad(inputMap, gamepadId)) {
                return;
            }

            if (gamepadAxisToButtonCondition != null) {
                if (!gamepadAxisToButtonCondition(action, gamepadId, axis, value)) {
                    return;
                }
            }

            rebindGamepadAxisToButton(inputMap, action, axis, value, removeExisting);

        };
        
        App.app.input.onGamepadAxis(this, gamepadAxisToButtonListener);

    }

    private function removeGamepadAxisToButton(inputMap:InputMap<T>, action:T):Void {

        var buttons = inputMap.boundGamepadButtonsToAxis(action);

        if (buttons == null) {
            return;
        }

        for (button in buttons) {
            inputMap.unbindGamepadButtonToAxis(action, button);
        }

    }

    private function rebindGamepadAxisToButton(inputMap:InputMap<T>, action:T, axis:GamepadAxis, value:Float, removeExisting:Bool):Void {

        if (removeExisting) {
            removeGamepadAxisToButton(inputMap, action);
        }

        emitBeforeRebindAny(inputMap, action);
        emitBeforeRebindGamepadAxisToButton(inputMap, action, axis);

        if (value < 0) {
            inputMap.bindGamepadAxisToButton(action, axis, -axisToButtonDeadZone);
        }

        if (value > 0) {
            inputMap.bindGamepadAxisToButton(action, axis, axisToButtonDeadZone);
        }

        emitAfterRebindGamepadAxisToButton(inputMap, action, axis);
        emitAfterRebindAny(inputMap, action);

        cancel();

    }

}

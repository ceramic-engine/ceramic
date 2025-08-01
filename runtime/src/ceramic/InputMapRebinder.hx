package ceramic;

import ceramic.App;
import ceramic.KeyCode;
import ceramic.Entity;
import ceramic.GamepadAxis;
import ceramic.GamepadButton;
import ceramic.Key;
import ceramic.InputMap;

/**
 * A utility class for rebinding input mappings at runtime.
 * 
 * InputMapRebinder provides a user-friendly way to change input bindings
 * by listening for input and automatically binding it to the specified action.
 * This is commonly used in game settings menus to let players customize controls.
 * 
 * Features:
 * - Listen for any input type (keyboard, gamepad button, gamepad axis)
 * - Support for cancellation (ESC key or SELECT button by default)
 * - Configurable conditions for filtering valid inputs
 * - Events for tracking rebind operations
 * - Option to preserve or replace existing bindings
 * 
 * @param T The type representing game actions (typically an enum)
 * 
 * Example usage:
 * ```haxe
 * var rebinder = new InputMapRebinder<Action>();
 * 
 * // Rebind jump action - will listen for next input
 * rebinder.rebind(inputMap, Action.JUMP);
 * 
 * // Listen for rebind completion
 * rebinder.onAfterRebindAny(this, (map, action) -> {
 *     trace('Rebound action: ' + action);
 * });
 * 
 * // Add conditions to filter inputs
 * rebinder.keyCondition = (action, key) -> {
 *     // Don't allow binding F1-F12 keys
 *     return key.keyCode < KeyCode.F1 || key.keyCode > KeyCode.F12;
 * };
 * ```
 */
class InputMapRebinder<T> extends Entity {

    /**
     * The dead zone threshold for converting analog axis movement to button presses.
     * When binding an axis as a button, the axis must exceed this value to register.
     * Default: 0.25 (25% of axis range)
     */
    public var axisToButtonDeadZone(default, set):Float = 0.25;

    private function set_axisToButtonDeadZone(value:Float):Float {

        axisToButtonDeadZone = value;

        return axisToButtonDeadZone;

    }

    /**
     * The gamepad button that cancels the rebind operation.
     * Default: GamepadButton.SELECT
     */
    public var cancelButton(default, set):GamepadButton = GamepadButton.SELECT;

    private function set_cancelButton(button:GamepadButton):GamepadButton {

        cancelButton = button;

        return cancelButton;

    }

    /**
     * The keyboard key that cancels the rebind operation.
     * Default: KeyCode.ESCAPE
     */
    public var cancelKeyCode(default, set):KeyCode = KeyCode.ESCAPE;

    private function set_cancelKeyCode(keyCode:KeyCode):KeyCode {

        cancelKeyCode = keyCode;

        return cancelKeyCode;

    }

    /**
     * Optional condition function to filter keyboard inputs during rebinding.
     * Return false to reject the input, true to accept it.
     * If null, all keyboard inputs are accepted (except cancel key).
     */
    public var keyCondition(default, set):(action:T, key:Key) -> Bool;

    public function set_keyCondition(condition:(action:T, key:Key) -> Bool):(action:T, key:Key) -> Bool {

        keyCondition = condition;

        return keyCondition;

    }

    /**
     * Optional condition function to filter gamepad button inputs during rebinding.
     * Return false to reject the input, true to accept it.
     * If null, all gamepad buttons are accepted (except cancel button).
     */
    public var gamepadButtonCondition(default, set):(action:T, gamepadId:Int, button:GamepadButton) -> Bool;

    public function set_gamepadButtonCondition(condition:(action:T, gamepadId:Int, button:GamepadButton) -> Bool):(action:T, gamepadId:Int, button:GamepadButton) -> Bool {

        gamepadButtonCondition = condition;

        return gamepadButtonCondition;

    }

    /**
     * Optional condition function to filter gamepad axis inputs during rebinding.
     * Return false to reject the input, true to accept it.
     * If null, all gamepad axes are accepted.
     */
    public var gamepadAxisCondition(default, set):(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool;

    public function set_gamepadAxisCondition(condition:(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool):(action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool {

        gamepadAxisCondition = condition;

        return gamepadAxisCondition;

    }

    /**
     * Optional condition function to filter gamepad axis-to-button conversions during rebinding.
     * Return false to reject the input, true to accept it.
     * If null, all gamepad axis movements exceeding the dead zone are accepted.
     */
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

    /**
     * Triggered before any input is rebound, regardless of input type.
     * @param inputMap The input map being modified
     * @param action The action being rebound
     * @event beforeRebindAny
     */
    @event function beforeRebindAny(inputMap:InputMap<T>, action:T);

    /**
     * Triggered after any input is successfully rebound, regardless of input type.
     * @param inputMap The input map that was modified
     * @param action The action that was rebound
     * @event afterRebindAny
     */
    @event function afterRebindAny(inputMap:InputMap<T>, action:T);

    /**
     * Starts listening for input to rebind the specified action.
     * The rebinder will listen for keyboard, gamepad buttons, and gamepad axes
     * simultaneously and bind the first valid input received.
     * 
     * @param inputMap The input map to modify
     * @param action The action to rebind
     * @param removeExisting If true, removes existing bindings before adding the new one
     */
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
    
    /**
     * Triggered before a keyboard key is bound to an action.
     * @param inputMap The input map being modified
     * @param action The action being rebound
     * @param key The keyboard key being bound
     * @event beforeRebindKey
     */
    @event function beforeRebindKey(inputMap:InputMap<T>, action:T, key:Key);

    /**
     * Triggered after a keyboard key is successfully bound to an action.
     * @param inputMap The input map that was modified
     * @param action The action that was rebound
     * @param key The keyboard key that was bound
     * @event afterRebindKey
     */
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

    /**
     * Triggered before a gamepad button is bound to an action.
     * @param inputMap The input map being modified
     * @param action The action being rebound
     * @param button The gamepad button being bound
     * @event beforeRebindGamepadButton
     */
    @event function beforeRebindGamepadButton(inputMap:InputMap<T>, action:T, button:GamepadButton);

    /**
     * Triggered after a gamepad button is successfully bound to an action.
     * @param inputMap The input map that was modified
     * @param action The action that was rebound
     * @param button The gamepad button that was bound
     * @event afterRebindGamepadButton
     */
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

    /**
     * Triggered before a gamepad axis is bound to an axis action.
     * @param inputMap The input map being modified
     * @param action The axis action being rebound
     * @param axis The gamepad axis being bound
     * @event beforeRebindGamepadAxis
     */
    @event function beforeRebindGamepadAxis(inputMap:InputMap<T>, action:T, axis:GamepadAxis);

    /**
     * Triggered after a gamepad axis is successfully bound to an axis action.
     * @param inputMap The input map that was modified
     * @param action The axis action that was rebound
     * @param axis The gamepad axis that was bound
     * @event afterRebindGamepadAxis
     */
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
    
    /**
     * Triggered before a gamepad axis is bound to a button action (axis-to-button conversion).
     * @param InputMap The input map being modified
     * @param action The button action being rebound
     * @param axis The gamepad axis being bound as a button
     * @event beforeRebindGamepadAxisToButton
     */
    @event function beforeRebindGamepadAxisToButton(InputMap:InputMap<T>, action:T, axis:GamepadAxis);

    /**
     * Triggered after a gamepad axis is successfully bound to a button action.
     * @param InputMap The input map that was modified
     * @param action The button action that was rebound
     * @param axis The gamepad axis that was bound as a button
     * @event afterRebindGamepadAxisToButton
     */
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

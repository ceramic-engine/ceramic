package ceramic;

import ceramic.KeyCode;
import ceramic.Entity;
import ceramic.GamepadAxis;
import ceramic.GamepadButton;
import ceramic.Key;
import ceramic.InputMap;

typedef RebindKeyCondition<T> = (action:T, key:Key) -> Bool;
typedef RebindGamepadButtonCondition<T> = (action:T, gamepadId:Int, button:GamepadButton) -> Bool;
typedef RebindGamepadAxisCondition<T> = (action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool;
typedef RebindGamepadAxisToButtonCondition<T> = (action:T, gamepadId:Int, axis:GamepadAxis, value:Float) -> Bool;

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

	public var keyCondition(default, set):RebindKeyCondition<T>;

	public function set_keyCondition(condition:RebindKeyCondition<T>):RebindKeyCondition<T> {
		keyCondition = condition;
		return keyCondition;
	}

	public var gamepadButtonCondition(default, set):RebindGamepadButtonCondition<T>;

	public function set_gamepadButtonCondition(condition:RebindGamepadButtonCondition<T>):RebindGamepadButtonCondition<T> {
		gamepadButtonCondition = condition;
		return gamepadButtonCondition;
	}

	public var gamepadAxisCondition(default, set):RebindGamepadAxisCondition<T>;

	public function set_gamepadAxisCondition(condition:RebindGamepadAxisCondition<T>):RebindGamepadAxisCondition<T> {
		gamepadAxisCondition = condition;
		return gamepadAxisCondition;
	}

	public var gamepadAxisToButtonCondition(default, set):RebindGamepadAxisToButtonCondition<T>;

	public function set_gamepadAxisToButtonCondition(condition:RebindGamepadAxisToButtonCondition<T>):RebindGamepadAxisToButtonCondition<T> {
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
		app.input.offKeyDown(keyDownListener);
		app.input.offGamepadDown(gamepadButtonListener);
		app.input.offGamepadAxis(gamepadAxisListener);
		app.input.offGamepadAxis(gamepadAxisToButtonListener);
	}

	@event function beforeRebindAny(inputMap:InputMap<T>, action:T);

	@event function afterRebindAny(inputMap:InputMap<T>, action:T);

	@event function beforeRebindKey(inputMap:InputMap<T>, action:T, key:Key);

	@event function afterRebindKey(inputMap:InputMap<T>, action:T, key:Key);

	@event function beforeRebindGamepadButton(inputMap:InputMap<T>, action:T, button:GamepadButton);

	@event function afterRebindGamepadButton(inputMap:InputMap<T>, action:T, button:GamepadButton);

	@event function beforeRebindGamepadAxis(inputMap:InputMap<T>, action:T, axis:GamepadAxis);

	@event function afterRebindGamepadAxis(inputMap:InputMap<T>, action:T, axis:GamepadAxis);

	@event function beforeRebindGamepadAxisToButton(InputMap:InputMap<T>, action:T, axis:GamepadAxis);

	@event function afterRebindGamepadAxisToButton(InputMap:InputMap<T>, action:T, axis:GamepadAxis);

	public function rebind(inputMap:InputMap<T>, action:T, removeExisting:Bool = true):Void {
		keyDownListener = (key:Key) -> {
			if (Key.keyCode == cancelKeyCode) return cancel();
			if (keyCondition != null && !keyCondition(action, key)) return cancel();
			rebindKey(inputMap, action, Key, removeExisting);
		};

		gamepadButtonListener = (gamepadId:Int, button:GamepadButton) -> {
			if (inputMap.gamepadId != -1 && inputMap.gamepadId != gamepadId) return;
			if (button == cancelButton) return cancel();
			if (gamepadButtonCondition != null && !gamepadButtonCondition(action, gamepadId, button)) return cancel();
			rebindGamepadButton(inputMap, Action, button, removeExisting);
		};

		gamepadAxisListener = (gamepadId:Int, axis:GamepadAxis, value:Float) -> {
			if (inputMap.gamepadId != -1 && inputMap.gamepadId != gamepadId) return;
			if (gamepadAxisCondition != null && !gamepadAxisCondition(action, gamepadId, axis, value)) return cancel();
			rebindGamepadAxis(inputMap, action, axis, value, removeExisting);
		};

		gamepadAxisToButtonListener = (gamepadId:Int, axis:GamepadAxis, value:Float) -> {
			if (inputMap.gamepadId != -1 && inputMap.gamepadId != gamepadId) return;
			if (gamepadAxisToButtonCondition != null && !gamepadAxisToButtonCondition(action, gamepadId, axis, value)) return cancel();
			rebindGamepadAxisToButton(inputMap, action, axis, value, removeExisting);
		};

		app.input.onKeyDown(this, keyDownListener);
		app.input.onGamepadDown(this, gamepadButtonListener);
		app.input.onGamepadAxis(this, gamepadAxisListener);
		app.input.onGamepadAxis(this, gamepadAxisToButtonListener);
	}

	private function removeKey(inputMap:InputMap<T>, action:T):Void {
		var keys = inputMap.boundKeyCodes(action);
		if (keys == null) return;
		for (key in keys) {
			inputMap.unbindKeyCode(action, key);
		}
	}

	private function rebindKey(inputMap:InputMap<T>, action:T, key:Key, removeExisting:Bool = true):Void {
		if (removeExisting) removeKey(inputMap, action);

		emitBeforeRebindAny(inputMap, action);
		emitBeforeRebindKey(inputMap, action, key);
		inputMap.bindKeyCode(action, key.keyCode);
		emitAfterRebindKey(inputMap, action, key);
		emitAfterRebindAny(inputMap, action);
		cancel();
	}

	private function removeGamepadButton(inputMap:InputMap<T>, action:T):Void {
		var buttons = inputMap.boundGamepadButtons(action);
		if (buttons == null) return;
		for (button in buttons) {
			inputMap.unbindGamepadButton(action, button);
		}
	}

	private function rebindGamepadButton(inputMap:InputMap<T>, action:T, button:GamepadButton, removeExisting:Bool = true):Void {
		if (removeExisting) removeGamepadButton(inputMap, action);

		emitBeforeRebindAny(inputMap, action);
		emitBeforeRebindGamepadButton(inputMap, action, button);
		inputMap.bindGamepadButton(action, button);
		emitAfterRebindGamepadButton(inputMap, action, button);
		emitAfterRebindAny(inputMap, action);
		cancel();
	}

	private function removeGamepadAxis(inputMap:InputMap<T>, action:T):Void {
		var axes = inputMap.boundGamepadAxes(action);
		if (axes == null) return;
		for (axis in axes) {
			inputMap.unbindGamepadAxis(action, axis);
		}
	}

	private function rebindGamepadAxis(inputMap:InputMap<T>, action:T, axis:GamepadAxis, value:Float, removeExisting:Bool):Void {
		if (removeExisting) removeGamepadAxis(inputMap, action);

		emitBeforeRebindAny(inputMap, action);
		emitBeforeRebindGamepadAxis(inputMap, action, axis);
		inputMap.bindGamepadAxis(action, axis);
		emitAfterRebindGamepadAxis(inputMap, action, axis);
		emitAfterRebindAny(inputMap, action);
		cancel();
	}

	private function removeGamepadButtonFromAxis(inputMap:InputMap<T>, action:T):Void {
		var buttons = inputMap.boundGamepadButtonsToAxis(action);
		if (buttons == null) return;
		for (button in buttons) {
			inputMap.unbindGamepadButtonToAxis(action, button);
		}
	}

	private function rebindGamepadAxisToButton(inputMap:InputMap<T>, action:T, axis:GamepadAxis, value:Float, removeExisting:Bool):Void {
		if (removeExisting) removeGamepadButtonFromAxis(inputMap, action);

		emitBeforeRebindAny(inputMap, action);
		emitBeforeRebindGamepadAxisToButton(inputMap, action, axis);

		if (value < 0) {
			inputMap.bindGamepadAxisToButton(action, axis, -axisToButtonDeadZone);
		} else {
			inputMap.bindGamepadAxisToButton(action, axis, axisToButtonDeadZone);
		}

		emitAfterRebindGamepadAxisToButton(inputMap, action, axis);
		emitAfterRebindAny(inputMap, action);
		cancel();
	}
}

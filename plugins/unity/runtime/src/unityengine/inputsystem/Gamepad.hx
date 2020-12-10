package unityengine.inputsystem;

import unityengine.inputsystem.controls.ButtonControl;
import unityengine.inputsystem.controls.DpadControl;
import unityengine.inputsystem.controls.StickControl;
import unityengine.inputsystem.utilities.ReadOnlyArray;

@:native('UnityEngine.InputSystem.Gamepad')
extern class Gamepad extends InputDevice {

    static var current(default, null):Gamepad;

    static var all(default, null):ReadOnlyArray<Gamepad>;

    var aButton(default, null):ButtonControl;

    var bButton(default, null):ButtonControl;

    var xButton(default, null):ButtonControl;

    var yButton(default, null):ButtonControl;

    var circleButton(default, null):ButtonControl;

    var crossButton(default, null):ButtonControl;

    var triangleButton(default, null):ButtonControl;

    var squareButton(default, null):ButtonControl;

    var buttonNorth(default, null):ButtonControl;

    var buttonEast(default, null):ButtonControl;

    var buttonSouth(default, null):ButtonControl;

    var buttonWest(default, null):ButtonControl;

    var dpad(default, null):DpadControl;

    var leftShoulder(default, null):ButtonControl;

    var rightShoulder(default, null):ButtonControl;

    var leftTrigger(default, null):ButtonControl;

    var rightTrigger(default, null):ButtonControl;

    var leftStick(default, null):StickControl;

    var leftStickButton(default, null):ButtonControl;

    var rightStick(default, null):StickControl;

    var rightStickButton(default, null):ButtonControl;

    var selectButton(default, null):ButtonControl;

    var startButton(default, null):ButtonControl;

}

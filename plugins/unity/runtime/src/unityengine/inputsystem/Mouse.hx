package unityengine.inputsystem;

import unityengine.inputsystem.controls.ButtonControl;
import unityengine.inputsystem.controls.Vector2Control;

@:native('UnityEngine.InputSystem.Mouse')
extern class Mouse extends Pointer {

    static var current(default, null):Mouse;

    var leftButton(default, null):ButtonControl;

    var middleButton(default, null):ButtonControl;

    var rightButton(default, null):ButtonControl;

    var scroll(default, null):Vector2Control;

}

package unityengine.inputsystem.controls;

import unityengine.inputsystem.controls.ButtonControl;

@:native('UnityEngine.InputSystem.Controls.DpadControl')
extern class DpadControl extends Vector2Control {

    var up(default, null):ButtonControl;

    var right(default, null):ButtonControl;

    var down(default, null):ButtonControl;

    var left(default, null):ButtonControl;

}


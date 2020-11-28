package unityengine.inputsystem.controls;

import unityengine.inputsystem.InputControl;

@:native('UnityEngine.InputSystem.Controls.Vector2Control')
extern class Vector2Control extends InputControl<Dynamic> {

    var x(default, null):AxisControl<Single>;

    var y(default, null):AxisControl<Single>;

}


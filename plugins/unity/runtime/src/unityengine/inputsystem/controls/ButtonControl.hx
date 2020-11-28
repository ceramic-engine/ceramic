package unityengine.inputsystem.controls;

@:native('UnityEngine.InputSystem.Controls.ButtonControl')
extern class ButtonControl extends AxisControl<Dynamic> {

    var isPressed(default, null):Bool;

    var wasPressedThisFrame(default, null):Bool;

    var wasReleasedThisFrame(default, null):Bool;

}


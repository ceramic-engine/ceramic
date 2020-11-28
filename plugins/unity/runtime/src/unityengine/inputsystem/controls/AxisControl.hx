package unityengine.inputsystem.controls;

@:native('UnityEngine.InputSystem.Controls.AxisControl')
extern class AxisControl<T> extends InputControl<T> {

    function ReadValue():T;

}


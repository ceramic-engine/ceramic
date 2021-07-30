package unityengine.inputsystem;

@:native('UnityEngine.InputSystem.InputControl')
extern class InputControl<T> {

    var displayName(default, null):String;

    function ReadValue():T;

}

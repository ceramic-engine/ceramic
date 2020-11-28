package unityengine.inputsystem;

import unityengine.inputsystem.controls.Vector2Control;

@:native('UnityEngine.InputSystem.Pointer')
extern class Pointer extends InputDevice {

    var position(default, null):Vector2Control;

}

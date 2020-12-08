package unityengine.inputsystem;

import unityengine.inputsystem.controls.Vector2Control;
import unityengine.inputsystem.controls.TouchControl;
import unityengine.inputsystem.utilities.ReadOnlyArray;

@:native('UnityEngine.InputSystem.Touchscreen')
extern class Touchscreen extends Pointer {

    static var current(default, null):Touchscreen;

    var touches(default, null):ReadOnlyArray<TouchControl>;

}
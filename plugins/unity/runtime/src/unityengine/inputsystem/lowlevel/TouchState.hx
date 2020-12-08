package unityengine.inputsystem.lowlevel;

import unityengine.Vector2;

@:native('UnityEngine.InputSystem.LowLevel')
extern class TouchState {

    var position(default, null):Vector2;

    var delta(default, null):Vector2;

}


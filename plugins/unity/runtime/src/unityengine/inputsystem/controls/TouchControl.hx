package unityengine.inputsystem.controls;

import unityengine.inputsystem.lowlevel.TouchState;

@:native('UnityEngine.InputSystem.Controls.TouchControl')
extern class TouchControl extends InputControl<TouchState> {

    var indirectTouch(default, null):ButtonControl;

    var isInProgress(default, null):Bool;

    var phase(default, null):TouchPhaseControl;

    var position(default, null):Vector2Control;

    var delta(default, null):Vector2Control;

    var press(default, null):TouchPressControl;

    var pressure(default, null):AxisControl<Dynamic>;

    var radius(default, null):Vector2Control;

    var startPosition(default, null):Vector2Control;

    var startTime(default, null):DoubleControl;

    var tap(default, null):ButtonControl;

    var tapCount(default, null):IntegerControl;

    var touchId(default, null):IntegerControl;

}


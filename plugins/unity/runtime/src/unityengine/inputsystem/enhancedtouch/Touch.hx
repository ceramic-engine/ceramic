package unityengine.inputsystem.enhancedtouch;

import unityengine.Object;
import unityengine.Vector2;
import unityengine.inputsystem.Touchscreen;
import unityengine.inputsystem.utilities.ReadOnlyArray;

@:native('UnityEngine.InputSystem.EnhancedTouch.Touch')
extern class Touch {

    static var activeTouches(default, null):ReadOnlyArray<Touch>;

    var delta(default, null):Vector2;

    var isInProgress(default, null):Bool;

    var isTap(default, null):Bool;

    var phase(default, null):TouchPhase;

    var pressure(default, null):Single;

    var radius(default, null):Vector2;

    var screen(default, null):Touchscreen;

    var screenPosition(default, null):Vector2;

    var startScreenPosition(default, null):Vector2;

    var startTime(default, null):Float;

    var tapCount(default, null):Int;

    var time(default, null):Float;

    var touchId(default, null):Int;

    var valid(default, null):Bool;

}
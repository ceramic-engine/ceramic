package unityengine.inputsystem.enhancedtouch;

import unityengine.Object;

@:native('UnityEngine.InputSystem.EnhancedTouch.EnhancedTouchSupport')
extern class EnhancedTouchSupport extends Object {

    static var enabled(default, null):Bool;

    static function Enable():Void;

    static function Disable():Void;

}
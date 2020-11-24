package unityengine;

@:native('UnityEngine.Input')
extern class Input {

    static var mousePosition(default, null):Vector3;

    static var mouseScrollDelta(default, null):Vector2;

    static function GetMouseButton(button:Int):Bool;

}

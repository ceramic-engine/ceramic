package unityengine;

@:native('UnityEngine.GameObject')
extern class GameObject extends Object {

    var activeInHierarchy:Bool;

    var activeSelf(default, null):Bool;

    var isStatic:Bool;

    var layer:Int;

    var tag:String;

}

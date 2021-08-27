package unityengine;

@:native('UnityEngine.ResourceRequest')
extern class ResourceRequest {

    var asset(default,null):Object;

    var allowSceneActivation:Bool;

    var isDone(default,null):Bool;

    var priority:Int;

    var progress(default,null):Single;

}

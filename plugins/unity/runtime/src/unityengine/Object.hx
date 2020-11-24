package unityengine;

@:native('UnityEngine.Object')
extern class Object {

    function GetInstanceID():Int;

    static function Destroy(obj:Object, t:Single = 0.0):Void;

    static function DestroyImmediate(obj:Object, allowDestroyingAssets:Bool = false):Void;

    static function DontDestroyOnLoad(target:Object):Void;

}

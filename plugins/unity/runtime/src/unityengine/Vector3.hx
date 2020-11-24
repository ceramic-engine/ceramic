package unityengine;

@:native('UnityEngine.Vector3')
extern class Vector3 {

    var x(default, null):Single;

    var y(default, null):Single;

    var z(default, null):Single;

    function new(x:Single, y:Single, z:Single);

}

package unityengine;

@:native('UnityEngine.Vector4')
extern class Vector4 {

    var x(default, null):Single;

    var y(default, null):Single;

    var z(default, null):Single;

    var w(default, null):Single;

    function new(x:Single, y:Single, z:Single, w:Single);

}

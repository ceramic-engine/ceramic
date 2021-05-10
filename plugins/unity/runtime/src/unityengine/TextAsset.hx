package unityengine;

import cs.types.UInt8;

@:native('UnityEngine.TextAsset')
extern class TextAsset extends Object {

    var text(default, null):String;

    var bytes(default, null):cs.NativeArray<UInt8>;

}

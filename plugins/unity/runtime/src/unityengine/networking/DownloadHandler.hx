package unityengine.networking;

import cs.NativeArray;
import cs.system.Byte;

@:native('UnityEngine.Networking.DownloadHandler')
extern class DownloadHandler {

    var data(default, null):NativeArray<Byte>;

    var text(default, null):String;

    var isDone(default, null):Bool;

    function Dispose():Void;

}

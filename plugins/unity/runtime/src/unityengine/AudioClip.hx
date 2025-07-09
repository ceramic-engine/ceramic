package unityengine;

@:native('UnityEngine.AudioClip')
extern class AudioClip extends Object {

    var ambisonic(default, null):Bool;

    var channels(default, null):Int;

    var frequency(default, null):Int;

    var length(default, null):Single;

    var loadInBackground:Bool;

    var loadState(default, null):AudioDataLoadState;

    var loadType(default, null):AudioClipLoadType;

    static function Create(name:String, lengthSamples:Int, channels:Int, frequency:Int, stream:Bool):AudioClip;

    function SetData(data:cs.NativeArray<Single>, offsetSamples:Int):Bool;

}

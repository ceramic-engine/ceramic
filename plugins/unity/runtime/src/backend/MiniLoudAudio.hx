package backend;

import backend.Float32Array;

@:native('MiniLoud.MiniLoudAudio')
extern class MiniLoudAudio {

    function new(sampleRate:Int, channels:Int);

    static function CreateFromData(data:Float32Array, channels:Int, sampleRate:Single):MiniLoudAudioResource;

    function GetDuration(audio:MiniLoudAudioResource):Single;

    function Destroy():Void;

    function Mute(audio:MiniLoudAudioResource):MiniLoudAudioHandle;

    function Play(audio:MiniLoudAudioResource, volume:Single, pan:Single, pitch:Single, position:Single, loop:Bool):MiniLoudAudioHandle;

    function Pause(handle:MiniLoudAudioHandle):Void;

    function Resume(handle:MiniLoudAudioHandle):Void;

    function Stop(handle:MiniLoudAudioHandle):Void;

    function GetVolume(handle:MiniLoudAudioHandle):Single;

    function SetVolume(handle:MiniLoudAudioHandle, volume:Single):Void;

    function GetPan(handle:MiniLoudAudioHandle):Single;

    function SetPan(handle:MiniLoudAudioHandle, pan:Single):Void;

    function GetPitch(handle:MiniLoudAudioHandle):Single;

    function SetPitch(handle:MiniLoudAudioHandle, pitch:Single):Void;

    function GetPosition(handle:MiniLoudAudioHandle):Single;

    function SetPosition(handle:MiniLoudAudioHandle, position:Single):Void;

    function ProcessAudio(data:Float32Array, channels:Int):Void;

}

@:native('MiniLoud.AudioResource')
extern class MiniLoudAudioResource {

    var audioData:Float32Array;

    var channels:Int;

    var sampleRate:Single;

    var duration:Single;

}

@:native('MiniLoud.AudioHandle')
extern class MiniLoudAudioHandle {

    var internalHandle:Int;

    var isValid:Bool;

}

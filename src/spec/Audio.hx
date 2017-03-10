package spec;

import backend.Audio;

interface Audio {

    function load(name:String, ?options:LoadAudioOptions, done:AudioResource->Void):Void;

    function destroy(audio:AudioResource):Void;

    function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false):AudioHandle;

    function pause(handle:AudioHandle):Void;

    function resume(handle:AudioHandle):Void;

    function stop(handle:AudioHandle):Void;

    function setVolume(handle:AudioHandle, volume:Float):Void;

    function setPitch(handle:AudioHandle, pitch:Float):Void;

    function setPosition(handle:AudioHandle, position:Float):Void;

} //Audio
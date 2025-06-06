package spec;

import backend.AudioHandle;
import backend.AudioResource;
import backend.LoadAudioOptions;

interface Audio {

    function load(path:String, ?options:LoadAudioOptions, done:AudioResource->Void):Void;

    function supportsHotReloadPath():Bool;

    function getDuration(audio:AudioResource):Float;

    function resumeAudioContext(done:Bool->Void):Void;

    function destroy(audio:AudioResource):Void;

    function mute(audio:AudioResource):AudioHandle;

    function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false, channel:Int = 0):AudioHandle;

    function pause(handle:AudioHandle):Void;

    function resume(handle:AudioHandle):Void;

    function stop(handle:AudioHandle):Void;

    function getVolume(handle:AudioHandle):Float;

    function setVolume(handle:AudioHandle, volume:Float):Void;

    function getPan(handle:AudioHandle):Float;

    function setPan(handle:AudioHandle, pan:Float):Void;

    function getPitch(handle:AudioHandle):Float;

    function setPitch(handle:AudioHandle, pitch:Float):Void;

    function getPosition(handle:AudioHandle):Float;

    function setPosition(handle:AudioHandle, position:Float):Void;

    function addFilter(channel:Int, filter:ceramic.AudioFilter):Void;

    function removeFilter(channel:Int, filterId:Int):Void;

    function filterParamsChanged(channel:Int, filterId:Int):Void;

}

package unityengine;

import unityengine.Component;

@:native('UnityEngine.AudioSource')
extern class AudioSource extends Behaviour {

    var bypassEffects:Bool;

    var bypassListenerEffects:Bool;

    var bypassReverbZones:Bool;

    var clip:AudioClip;

    var dopplerLevel:Single;

    var ignoreListenerPause:Bool;

    var ignoreListenerVolume:Bool;

    var isPlaying(default, null):Bool;

    var isVirtual:Bool;

    var loop:Bool;

    var maxDistance:Single;

    var minDistance:Single;

    var mute:Bool;

    var panStereo:Single;

    var pitch:Single;

    var playOnAwake:Bool;

    var priority:Int;

    var reverbZoneMix:Single;

    var spatialize:Bool;

    var time:Single;

    var timeSamples:Int;

    var volume:Single;

    var outputAudioMixerGroup:AudioMixerGroup;

    function Pause():Void;

    function Play():Void;

    function PlayDelayed(delay:Single):Void;

    function Stop():Void;

    function UnPause():Void;

}

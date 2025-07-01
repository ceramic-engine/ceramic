package backend;

import unityengine.AudioClip;
import unityengine.AudioSource;
import unityengine.MonoBehaviour;

@:native('MiniLoudUnity')
extern class MiniLoudUnity extends MonoBehaviour {

    var miniLoudAudio:MiniLoudAudio;

    var audioSource:AudioSource;

    var channels:Int;

    var sampleRate:Int;

    static function AudioResourceFromAudioClip(clip:AudioClip):MiniLoudAudio.MiniLoudAudioResource;

}

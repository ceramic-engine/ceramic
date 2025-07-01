package backend;

import unityengine.AudioMixerGroup;
import unityengine.AudioSource;

@:structInit
class AudioBus {

    public var mixerGroup:AudioMixerGroup;

    public var busIndex:Int;

    public var audioSources:Array<AudioSource>;

}

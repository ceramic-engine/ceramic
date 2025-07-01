package unityengine;

@:native('UnityEngine.Audio.AudioMixer')
extern class AudioMixer extends Object {

    function FindMatchingGroups(subPath:String):cs.NativeArray<AudioMixerGroup>;

}
